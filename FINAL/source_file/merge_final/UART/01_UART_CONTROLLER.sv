`timescale 1ns / 1ps


module UART_CONTROLLER#(
     
        parameter BIT_WIDTH = 8,
        parameter DATA_WIDTH = 32,
        parameter AUTO_FRQ = 5  // auto mode sel 갱신 주기 (tb 에서 빠르게 바꿔서 사용)

        )(
    


	input i_error, // 디코더에서 보내는 에러 시호 
	input [23:0] i_for_sender_data,
	input i_handshake,
	input i_sender_busy,
    input i_clk, i_rst,
    input [DATA_WIDTH-1 :0] i_con_ascii,


    input  i_get, // get mode 
    input  i_btn, //btn 
    input  i_mode, // stopwatch / watch / timer / 거리/ 온습도 
    input  i_auto, // 1-> 유지 다음 1 -> 0

	input i_btn_R, // 물리 버튼 (debounce 후)
	input i_btn_L,
	input i_btn_U,
	input i_btn_D,
    



	input  i_off_set, // set 기능 끄기 switch 역할 
	input  i_set,

	output [6:0] o_module_control_bit, // switch 기능 
	output o_uart_mode,  // (merge) 정상 /mod 를 한 번이라도 받으면 1 -> Top 에서 스위치 대신 o_module_control_bit 사용


	output [2:0] o_send_sel, // sender로 데이터가 무슨 데이터인지
							// auto mode 시 0.25s 간격으로 업데이트 
    

	output [23:0] o_sender_data,
	output o_sender_go, // 


	output o_uart_R,
	output o_uart_L,
	output o_uart_U,
	output o_uart_D

);






reg [DATA_WIDTH -1 :0] c_con_ascii,n_con_ascii;
reg [6:0] c_module_control_bit, n_module_control_bit;
reg c_uart_mode;   // (merge) UART 로 모드 제어 중 (리셋 전까지 유지)
wire w_mode_cmd;


reg [2:0] c_sender_sel,n_sender_sel;
reg c_sender_go, n_sender_go; 
reg c_auto_enable, n_auto_enable;
reg c_err_pend, n_err_pend; // sender busy 중에 들어온 error 저장
reg c_send_pend, n_send_pend; // 아직 못 보낸 데이터 (5hz 차례 / get) 저장
reg scan_tick;                // AUTO_ALL 데이터 실제로 보냈을 때 1 -> scan 카운터 증가



// uart 로 들어온 버튼 저장 (물리 버튼 없는 clk 에 o_uart_* 로 출력)
reg c_btn_R,n_btn_R;
reg c_btn_L,n_btn_L;
reg c_btn_U,n_btn_U;
reg c_btn_D,n_btn_D;


wire w_clk_5hz;
wire w_auto_enable;
wire [2:0] w_scan_sel;
wire w_sender_busy;
wire [2:0] w_mode_sel;
wire w_phy_btn;


// o_send_sel 값 (sender 쪽과 맞출 것)
localparam [2:0] SEL_SW   = 3'd0,
                 SEL_TM   = 3'd1,
                 SEL_WH   = 3'd2,
                 SEL_DIST = 3'd3,
                 SEL_TEMP = 3'd4,
                 SEL_ERR  = 3'd7;


assign o_send_sel = c_sender_sel;
assign w_auto_enable = c_auto_enable;
assign o_sender_go = c_sender_go;
// go 낸 바로 다음 clk 은 sender busy 가 아직 안 올라왔을 수 있어서 같이 막음
assign w_sender_busy = i_sender_busy | c_sender_go;
assign o_sender_data = (o_sender_go)? i_for_sender_data : 0; 
assign o_module_control_bit = c_module_control_bit;
assign o_uart_mode = c_uart_mode;

// /mode 로 정해진 현재 모드 -> get 할 때 보낼 sel
assign w_mode_sel = (c_module_control_bit[6]) ? SEL_TEMP :
                    (c_module_control_bit[5]) ? SEL_DIST :
                    (c_module_control_bit[4]) ? SEL_TM   :
                    (c_module_control_bit[0]) ? SEL_SW   : SEL_WH;


typedef enum{

	IDLE = 0,
	GET  = 1,
	AUTO_ALL = 2,
	AUTO_OFF = 3,
	AUTO_SW  = 4,
	AUTO_TM  = 5,
	AUTO_WH  = 6,
    AUTO_DIST = 7,
    AUTO_TEMP = 8
}state_auto;

state_auto c_auto_state,n_auto_state;




typedef enum{

MODE_IDLE = 0,
MODE = 1

}state_m;

state_m c_mode_state,n_mode_state;

// (merge) mode FSM 이 실제로 받아들이는 /mod 명령 (아래 case 와 같은 목록)
assign w_mode_cmd = (c_mode_state == MODE) && i_handshake && i_mode &&
                    ((i_con_ascii == "w_hm") || (i_con_ascii == "w_ms") ||
                     (i_con_ascii == "t_hm") || (i_con_ascii == "t_ms") ||
                     (i_con_ascii == "s_hm") || (i_con_ascii == "s_ms") ||
                     (i_con_ascii == "dist") || (i_con_ascii == "temp"));



sender_tick_generator #(
        .CLK_FRQ(AUTO_FRQ)
    ) U_CLK_GEN_5HZ (
        .i_clk     (i_clk),
        .i_rst     (i_rst),
		.i_enable  (w_auto_enable),
        .o_clk(w_clk_5hz)
    );

counter#(
    .COUNT_NUM(5), // sw, tm, wh, dist, temp
    .SEL_BIT(3)
        ) U_SEL_CNT
    (

     .i_clk(i_clk),
     .i_rst(i_rst),
     .i_tick(scan_tick),
     .o_scan_sel(w_scan_sel)

    );





// Mode state //
always@(posedge i_clk, posedge i_rst)begin


	if(i_rst)begin
		
		c_mode_state <= MODE_IDLE;
		c_con_ascii <= 0; 
		c_module_control_bit <= 7'b000_0000;
		c_uart_mode <= 0;
//auto 
		c_auto_state <= IDLE;
		c_sender_go <= 0;		
		c_sender_sel <= 0;
        c_auto_enable <=0;
        c_err_pend <= 0;
        c_send_pend <= 0;
//btn
        c_btn_R <= 0;
        c_btn_L <= 0;
        c_btn_U <= 0;
        c_btn_D <= 0;
	end

	else begin

		c_mode_state <=  n_mode_state;
		c_con_ascii  <=  n_con_ascii;
		c_module_control_bit <= n_module_control_bit;
		if(w_mode_cmd) c_uart_mode <= 1;
//auto

		c_auto_state <= n_auto_state;
		c_sender_go <= n_sender_go;		
		c_sender_sel <= n_sender_sel;
        c_auto_enable <= n_auto_enable;
        c_err_pend <= n_err_pend;
        c_send_pend <= n_send_pend;
//btn
        c_btn_R <= n_btn_R;
        c_btn_L <= n_btn_L;
        c_btn_U <= n_btn_U;
        c_btn_D <= n_btn_D;

	end

end

/////////////////////////////////////////////////////// mode //////////////////////////////////////////
always@(*)begin

		
		n_mode_state  =  c_mode_state;
		n_con_ascii   =  c_con_ascii;
		n_module_control_bit  = c_module_control_bit;

		case(c_mode_state)

		MODE_IDLE : begin

			if(i_mode)begin 
				n_mode_state = MODE;
			end
	
		end
	
		MODE : begin

				if(i_handshake)begin
					
					if(i_mode)begin					
					case(i_con_ascii)

					"w_hm" : begin
							n_module_control_bit = 7'b0000_010;
						   end 
					
					"w_ms" : begin
							n_module_control_bit = 7'b0000_000;
						   end
					
					
					"t_hm" : begin
							n_module_control_bit = 7'b0010_010;
						   end
					"t_ms" :  begin
							n_module_control_bit = 7'b0010_000;
							end
					
					"s_hm" :  begin
							n_module_control_bit = 7'b0000_011;
							end
					
					"s_ms"  :  begin
							n_module_control_bit = 7'b0000_001;
							end

					"dist"  :  begin
							n_module_control_bit = 7'b0100_000;
							end

					"temp"  :  begin
							n_module_control_bit = 7'b1000_000;
							end


					endcase

					n_module_control_bit[3] = c_module_control_bit[3]; // (merge) /mod 를 바꿔도 12/24 시간 표시는 유지

					end

					// (merge) /set 24h -> bit3 (hour24_sw3) = 1 : 24 시간 표시, /set 12h -> 0 : 12 시간 표시
					else if(i_set && (i_con_ascii == "24h")) n_module_control_bit[3] = 1'b1;
					else if(i_set && (i_con_ascii == "12h")) n_module_control_bit[3] = 1'b0;

					// 시계 설정 : bit3 (12/24) 은 빼고 비교
					else if(i_set&&((c_module_control_bit & 7'b1110_111) == 7'b0000_010)) n_module_control_bit = c_module_control_bit | 7'b0000_100;
					else if(i_off_set&&((c_module_control_bit & 7'b1110_111) == 7'b0000_110)) n_module_control_bit = c_module_control_bit & 7'b1111_011;

				end

			end

		endcase

end


////////////////////////////////  auto /////////////////////////////////////////////


always@(*)begin 

		n_auto_state  = c_auto_state;
        n_auto_enable = c_auto_enable;
		n_sender_go   = 0;              // go 는 1 clk pulse
        n_sender_sel  = c_sender_sel;   // sel 은 보낼 때만 갱신
        n_err_pend    = c_err_pend | i_error; // error 들어오면 일단 저장
        n_send_pend   = 0;
        scan_tick     = 0;

        case(c_auto_state)



        IDLE,GET     : begin
                        n_auto_enable = 0;
                    
                   if(i_handshake)begin
                   
                       if(i_get)begin
                            n_auto_state = GET;
                       end
                       
                       else if(i_auto)begin
                            
                            case(i_con_ascii)

                             "_tm" : n_auto_state = AUTO_TM;
                             "_wh" : n_auto_state = AUTO_WH;
                             "_sw" : n_auto_state = AUTO_SW;
                             "dis" : n_auto_state = AUTO_DIST;
                             "tem" : n_auto_state = AUTO_TEMP;
                             "all" : n_auto_state = AUTO_ALL;
                             "off" : n_auto_state = AUTO_OFF;
                                           
                            endcase 

                       end

                   end

                   // get 들어오면 저장 -> sender 비고 error 없을 때 현재 모드 sel + go
                   n_send_pend = c_send_pend | (i_handshake && i_get);

                   if(n_send_pend && !w_sender_busy && !n_err_pend)begin
                        n_sender_go  = 1;
                        n_send_pend  = 0;
                        n_sender_sel = w_mode_sel;
                   end

                   end


        AUTO_ALL,AUTO_TM,AUTO_WH,AUTO_DIST,AUTO_TEMP,AUTO_SW
                : begin
                            n_auto_enable = 1; 

                    // 5hz 마다 차례 저장 -> sender 비고 error 없을 때 sel 갱신 + go
                    // (error 랑 겹치면 error 먼저, busy 풀리면 이 차례 데이터 바로 이어서)
                    n_send_pend = c_send_pend | w_clk_5hz;

                    if(n_send_pend && !w_sender_busy && !n_err_pend)begin
                            n_sender_go = 1;
                            n_send_pend = 0;
                            scan_tick   = (c_auto_state == AUTO_ALL);
                            case(c_auto_state)
                             AUTO_SW   : n_sender_sel = SEL_SW;
                             AUTO_TM   : n_sender_sel = SEL_TM;
                             AUTO_WH   : n_sender_sel = SEL_WH;
                             AUTO_DIST : n_sender_sel = SEL_DIST;
                             AUTO_TEMP : n_sender_sel = SEL_TEMP;
                             AUTO_ALL  : n_sender_sel = w_scan_sel;
                            endcase
                    end

                    if(i_handshake)begin
                       if(i_auto)begin
                            case(i_con_ascii)
                             "_tm" : n_auto_state = AUTO_TM;
                             "_wh" : n_auto_state = AUTO_WH;
                             "_sw" : n_auto_state = AUTO_SW;
                             "dis" : n_auto_state = AUTO_DIST;
                             "tem" : n_auto_state = AUTO_TEMP;
                             "all" : n_auto_state = AUTO_ALL;
                             "off" : n_auto_state = AUTO_OFF;
                            endcase
                      end
                    end
                   end

        AUTO_OFF : begin
                        n_auto_enable = 0;
                        n_auto_state = IDLE;                        
                   end

        endcase

        // error 최우선 : sender 가 놀고 있으면 바로 sel = 7 로 쏘고, busy 면 pending 유지
        if(n_err_pend && !w_sender_busy)begin
                n_sender_sel = SEL_ERR;
                n_sender_go  = 1;
                n_err_pend   = 0;
        end

end


////////////////////////////////  btn /////////////////////////////////////////////

// 물리 버튼 우선 : 물리 버튼 들어온 clk 에는 uart 버튼 막고 저장 -> 물리 버튼 끝나면 출력
assign w_phy_btn = i_btn_R | i_btn_L | i_btn_U | i_btn_D;

assign o_uart_R = c_btn_R & ~w_phy_btn;
assign o_uart_L = c_btn_L & ~w_phy_btn;
assign o_uart_U = c_btn_U & ~w_phy_btn;
assign o_uart_D = c_btn_D & ~w_phy_btn;

always@(*)begin

        // 물리 버튼 없으면 이번 clk 에 o_uart_* 로 나가니까 clear, 있으면 유지
        n_btn_R = c_btn_R & w_phy_btn;
        n_btn_L = c_btn_L & w_phy_btn;
        n_btn_U = c_btn_U & w_phy_btn;
        n_btn_D = c_btn_D & w_phy_btn;

        if(i_handshake && i_btn)begin
            case(i_con_ascii[7:0]) // "000R" -> 하위 byte 만 비교
             "R" : n_btn_R = 1;
             "L" : n_btn_L = 1;
             "U" : n_btn_U = 1;
             "D" : n_btn_D = 1;
            endcase
        end

end

















endmodule 


module counter#(
       parameter COUNT_NUM = 4,
       parameter SEL_BIT = 2
    )(
    input            i_clk,
    input            i_rst,
    input            i_tick,
    output reg [SEL_BIT -1 :0] o_scan_sel
);

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) o_scan_sel <= 0;
        else if(i_tick) o_scan_sel <= (o_scan_sel == COUNT_NUM-1) ? 0 : o_scan_sel + 1;
    end

endmodule











module sender_tick_generator #(
    parameter CLK_FRQ = 1000
) (
    input      i_clk,
    input      i_rst,
	input 	   i_enable,
    output reg o_clk
);

    parameter FCOUNT = (100_000_000 / CLK_FRQ);
    reg [$clog2(FCOUNT)-1:0] r_counter;

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            r_counter  <= 0;
            o_clk <= 0;
        end else begin

			if(i_enable)begin 
				r_counter <= r_counter + 1;
				if (r_counter == FCOUNT - 1) begin
					r_counter  <= 0;
					o_clk <= 1;
            	end 

				else begin
                	o_clk <= 0;
            	end
			end
		
			else begin 
				o_clk <= 0;
			end



        end
    end

endmodule







