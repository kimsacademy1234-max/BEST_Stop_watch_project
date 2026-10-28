`timescale 1ns / 1ps


module tb_uart_decoder();


parameter BAUD_RATE = 100_000_000/9600*10;



reg clk,rst;
reg rx;
reg [7:0] DATA_8BIT;          // Ïß?Í∏? Î≥¥ÎÇ¥?äî 1Í∏??ûê (?åå?òï Radix: ASCII)
reg [8*16-1:0] TX_TEXT;       // Ïß?Í∏àÍπåÏß? Î≥¥ÎÇ∏ Î™ÖÎ†π Î¨∏Ïûê?ó¥ (?åå?òï Radix: ASCII)
reg sender_busy;

     wire w_b_tick;
     wire w_error;         
   
     wire w_handshake;
     wire w_get;
     wire w_btn;
     wire w_mode;
     wire w_auto;
     wire [39:0] w_ascii;
     wire w_rx_empty;
     wire w_rx_full;
     wire w_rx_done;
     wire [7:0] w_rx_data;
     wire [7:0] w_pop_data;
     wire w_pop; 


uart_rx U_UART_RX (
        .clk    (clk),
        .rst    (rst),
        .b_tick (w_b_tick),
        .rx     (rx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );


fifo#(
    .DEPTH(16),
    .BIT_WIDTH(8)

    )DUT_FIFO_RX(
.i_clk(clk), 
.i_reset(rst),
.push(w_rx_done),
.pop(w_pop),
.push_data(w_rx_data),
.pop_data(w_pop_data),
.full(w_rx_full),
.empty(w_rx_empty)
);

UART_ASCII_DECODER#(

    .BIT_WIDTH(8),
    .DATA_WIDTH(40)

)U_UART_ASCII_DECODER(
     
     .i_clk(clk),
     .i_reset(rst),
     .i_ascii(w_pop_data),
     .i_enable(~w_rx_empty),
     .i_rx_done(w_rx_done),
     .i_sender_busy(sender_busy),
     .o_error(w_error),
     .o_pop(w_pop),
     .o_handshake(w_handshake),
     .o_get(w_get),
     .o_btn(w_btn),
     .o_mode(w_mode),
     .o_auto(w_auto),
     .o_ascii(w_ascii)
  );










    baud_tick_gen#(
        .BAUD_RATE(9600),
        .SAMPLING_RATE(16)

            )U_BAUD_TICK_GEN (
        .clk   (clk),
        .rst   (rst),
        .b_tick(w_b_tick)
    );






////////////////////////////////////////////////////////////////////////////////////
task sender( string txt);

	integer i,j;

begin

	$display("[%0t] TX : \"%s\"", $time, txt);
	TX_TEXT = 0;

	for(j=0; j <txt.len();j=j+1)begin
		DATA_8BIT = txt[j];
		TX_TEXT = {TX_TEXT[8*15-1:0], txt[j]};
		rx = 0;
		#(BAUD_RATE);
		for(i=0; i <8; i=i+1)begin
			
			rx = txt[j][i];
			#(BAUD_RATE);
		end 

		rx = 1;
		#(BAUD_RATE);
	end
	#(BAUD_RATE*10);

end
endtask


always #5 clk = ~clk;


// Î¨¥Ïûë?úÑ sender_busy : Î∞îÏù¥?ä∏ ?ã®?úÑ (TXÍ∞? 1Î∞îÏù¥?ä∏ Î≥¥ÎÇ¥?äî ?ãúÍ∞? = 10bit)
// busy ?èô?ïà?? ?îîÏΩîÎçîÍ∞? pop?ùÑ ?ïà ?ïòÎØ?Î°? FIFO?óê Í∏??ûêÍ∞? ?åì???ã§Í∞? busyÍ∞? ??Î¶¨Î©¥ Îπ†Ïßê
// ON = 1~3 Î∞îÏù¥?ä∏ ?Üí FIFO(DEPTH 4)Í∞? ?ÑòÏπòÏ? ?ïä?äî Î≤îÏúÑ
localparam BYTE_CLK = BAUD_RATE*10/10;   // 1Î∞îÏù¥?ä∏ ?†Ñ?Ü° ?ãúÍ∞? (clk Í∞úÏàò)

integer busy_on, busy_off;

initial begin : RAND_BUSY
	@(negedge rst);
	forever begin
		busy_off = $urandom_range(1, 2);         // ?â¨?äî ?ãúÍ∞? : 1~2 Î∞îÏù¥?ä∏
		repeat(busy_off*BYTE_CLK) @(negedge clk);
		sender_busy = 1;

		busy_on  = $urandom_range(1, 3);         // busy ?ãúÍ∞? : 1~3 Î∞îÏù¥?ä∏
		repeat(busy_on*BYTE_CLK)  @(negedge clk);
		sender_busy = 0;
	end
end

initial	begin

clk = 0;
rst = 1;
rx = 1;
sender_busy = 0;

#10 rst = 0;

sender("/get sw_hm");
sender("/get sw_ms");
sender("/btn R");
sender("/auto f");
sender("/mod sw_hm");
sender("/mod sw_ms");

// ---- sender_busy Í≥ÑÏÜç 0 ?ù∏ ?ÉÅ?Éú?óê?Ñú ?ç∞?ù¥?Ñ∞ ?Ñ£Í∏? ----
// Í∏??ûêÍ∞? ?ì§?ñ¥?ò§?äî Ï¶âÏãú pop ?Üí FIFO?äî Í±∞Ïùò ?ï≠?ÉÅ empty, Î™ÖÎ†π ?†ÑÎ∂? ?†ï?ÉÅ handshake
disable RAND_BUSY;
@(negedge clk) sender_busy = 0;
sender("/get sw_hm");
sender("/btn L");
sender("/auto f");
sender("/mod sw_ms");

// ---- sender_busy Í≥ÑÏÜç 1 ?ù∏ ?ÉÅ?Éú?óê?Ñú ?ç∞?ù¥?Ñ∞ ?Ñ£Í∏? ----
// ?îîÏΩîÎçîÍ∞? pop?ùÑ Î™? ?ïòÎØ?Î°? FIFO(DEPTH 4)?óê 4Í∏??ûêÎß? ?åì?ù¥Í≥? (w_rx_full = 1)
// ?ÇòÎ®∏Ï? Í∏??ûê?äî Î≤ÑÎ†§Ïß? ?Üí busy ??Î¶¨Î©¥ "/get" 4Í∏??ûêÎß? pop ?ê®
@(negedge clk) sender_busy = 1;
sender("/get sw_hm");
#(BAUD_RATE*3);
@(negedge clk) sender_busy = 0;
#(BAUD_RATE*3);

// Î≥µÍµ¨ ?ôï?ù∏ : ?ïû Î™ÖÎ†π?ù¥ ?çú ?Åù?Çú ?ÉÅ?Éú?ùº "/" ?óê?Ñú error 1Î≤? ?ú®Í≥? ?ã§?ãú ?†ï?ÉÅ ?èô?ûë?ï¥?ïº ?ï®
sender("/get sw_ms");

sender("gxt ");





$finish;



end






endmodule
