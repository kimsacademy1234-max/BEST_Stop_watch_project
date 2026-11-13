`timescale 1ns / 1ps


module uart_tx(

    input  logic       clk,
    input  logic       rst,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    output logic       tx,
    output logic       tx_busy

);


logic b_tick;

uart U_UART(
	.*,
   	.b_tick(b_tick)
);





b_tick_gen#(
	.TICK_FRQ(9600*16)
)B_TICK_GEN(
	.*,
	.b_tick(b_tick)
);


endmodule






module uart(
    input  logic       clk,
    input  logic       rst,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    input  logic       b_tick,
    output logic       tx,
    output logic       tx_busy
);

/*    localparam [1:0] IDLE = 0, START = 1, DATA = 2, STOP = 3;
    reg [1:0] c_state, n_state;*/


typedef enum{
IDLE = 1, 
START = 2, 
DATA = 3, 
STOP = 4}
state_t;
state_t c_state, n_state;



    logic tx_reg, tx_next;
    logic tx_busy_reg, tx_busy_next;
    logic [2:0] bit_count_reg, bit_count_next;
    logic [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic [7:0] data_reg, data_next;

    //output
    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    // state SL
    always_ff@(posedge clk, posedge rst) begin
        if (rst) begin
            c_state        <= IDLE;
            bit_count_reg  <= 3'b0;
            b_tick_cnt_reg <= 4'b0;
            data_reg       <= 8'h00;
            tx_reg         <= 1'b1;
            tx_busy_reg    <= 1'b0;  // no busy
        end else begin
            c_state        <= n_state;
            bit_count_reg  <= bit_count_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            data_reg       <= data_next;
            tx_reg         <= tx_next;
            tx_busy_reg    <= tx_busy_next;
        end
    end

    // next , output
    always_comb begin
        n_state         = c_state;
        bit_count_next  = bit_count_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        data_next       = data_reg;
        tx_next         = tx_reg;
        tx_busy_next    = tx_busy_reg;
        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                tx_busy_next = 1'b0;
                if (tx_start) begin
                    bit_count_next  = 3'b0;
                    b_tick_cnt_next = 0;
                    data_next       = tx_data;
                    n_state         = START;
                end
            end
            START: begin
                tx_busy_next = 1'b1;
                tx_next = 1'b0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        n_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        if (bit_count_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            data_next = {1'b0, data_reg[7:1]};
                            bit_count_next = bit_count_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        n_state = IDLE;
						tx_busy_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule


//////////////////////////////////////////////////////////////
module b_tick_gen#( parameter TICK_FRQ =1000 
)(
input logic clk,
input logic rst,
output logic b_tick
);


parameter FCOUNT = (100_000_000/TICK_FRQ); 
logic [$clog2(FCOUNT)-1 :0] r_counter;

always@(posedge clk or posedge rst)begin
	if(rst)begin
		r_counter <= 0;
		b_tick <= 0;
	end
	else begin
			r_counter <= r_counter + 1;
			if(r_counter == FCOUNT -1)begin
				r_counter <= 0;
				b_tick <= 1;
			end
			else begin
				b_tick <= 0;
			end
	end
				 

end


endmodule


















