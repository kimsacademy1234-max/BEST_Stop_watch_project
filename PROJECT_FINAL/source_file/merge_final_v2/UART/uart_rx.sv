
// 설계한 tx의 시뮬레이션은 리시버를 만들었고, 설계한 rx의 시뮬레이션은 sender 만듬
`timescale 1ns / 1ps

// (merge) 포트 이름 v2 규칙 (i_ / o_) : clk rst b_tick rx rx_data rx_done → i_clk i_rst i_b_tick i_rx o_rx_data o_rx_done
module uart_rx (
    input        i_clk,
    input        i_rst,
    input        i_b_tick,
    input        i_rx,
    output [7:0] o_rx_data,
    output       o_rx_done
);
  /*localparam [1:0] IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
    reg [1:0] c_state, n_state;*/


typedef enum{
IDLE = 1, 
START = 2, 
DATA = 3, 
STOP = 4}
state_t;
state_t c_state, n_state;




    reg [3:0] b_tick_cnt, b_tick_cnt_next;
    reg [2:0] bit_cnt, bit_cnt_next;
    reg [7:0] data_reg, data_next;

    reg rx_done_reg, rx_done_next;


    assign o_rx_done = rx_done_reg;
    assign o_rx_data = data_reg;
  
     
    // 상태 업데이트
    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            c_state     <= IDLE;
            b_tick_cnt  <= 4'h0;
            bit_cnt     <= 3'b000;
            data_reg    <= 8'h00;
            rx_done_reg <= 1'b0;
        end else begin
            c_state <= n_state;
            b_tick_cnt <= b_tick_cnt_next;
            bit_cnt <= bit_cnt_next;
            data_reg <= data_next;
            rx_done_reg <= rx_done_next;
        end
    end

    // next, output
    always @(*) begin
        //초기값 설정
        n_state         = c_state;
        b_tick_cnt_next = b_tick_cnt;
        bit_cnt_next    = bit_cnt;
        data_next       = data_reg;
        rx_done_next    = rx_done_reg;
        case (c_state)
            IDLE: begin
                b_tick_cnt_next   = 0;
                rx_done_next = 1'b0;
                if (i_b_tick) begin // 이중 if 안써도 되긴 함. 먹서를 쓸 거냐 게이트를 쓸 거냐의 차이. 여기서는 아주 쪼오금의 차이가 있음. 
                    if (!i_rx) begin
                        n_state = START;
                    end
                end
            end
            START: begin
               if(!i_rx)begin
                 if (i_b_tick) begin
                    
                    if (b_tick_cnt == 7 ) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next    = 0;
                        data_next       = 8'h00;
                        n_state         = DATA;
                    end 

                    else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end

               end
               end
               else begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next    = 0;
                        data_next       = 8'h00;
                        n_state         = IDLE;

               end

            end
            
            /*   if (i_b_tick) begin
                    if (b_tick_cnt == 7) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next    = 0;
                        data_next       = 8'h00;
                        n_state         = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end
                end
            end*/
            DATA: begin
                    if (i_b_tick) begin
                        
                        if (b_tick_cnt == 15) begin
                            b_tick_cnt_next = 0;
                            data_next = {i_rx, data_reg[7:1]};
                            
                            if (bit_cnt == 7) begin
                                n_state = STOP;
                            end 

                            else begin
                                // DATA state
                                bit_cnt_next = bit_cnt + 1;
                            end
         
                        end
                    
                        else begin
                            b_tick_cnt_next = b_tick_cnt + 1;
                        end
                    
                    end
               end

            
            STOP: begin
                if (i_b_tick) begin
                    if (b_tick_cnt == 15) begin
                        rx_done_next = 1'b1;
                        n_state = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end
                end
            end
        endcase
    end



endmodule

