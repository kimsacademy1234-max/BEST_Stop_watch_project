`timescale 1ns / 1ps

// UART TX (TS-44 고친 판 : IDLE 에서 tx_start 받는 클럭에 바로 busy = 1, STOP 끝에서 busy = 0)
//   → TX FIFO pop = ~busy 로 연결해도 한 글자를 두 번 꺼내지 않음
// (merge) boyun/uart_fifo_ascii_hw_20261028 의 uart_tx.v, 포트 이름 v2 규칙 (i_ / o_)
module uart_tx (
    input        i_clk,
    input        i_rst,
    input        i_tx_start,
    input  [7:0] i_tx_data,
    input        i_b_tick,
    output       o_tx,
    output       o_tx_busy
);

    localparam [1:0] IDLE = 0, START = 1, DATA = 2, STOP = 3;
    reg [1:0] c_state, n_state;
    reg tx_reg, tx_next;
    reg tx_busy_reg, tx_busy_next;
    reg [2:0] bit_count_reg, bit_count_next;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [7:0] data_reg, data_next;

    //output
    assign o_tx = tx_reg;
    assign o_tx_busy = tx_busy_reg;

    // state SL
    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
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
    always @(*) begin
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
                if (i_tx_start) begin
                    bit_count_next  = 3'b0;
                    b_tick_cnt_next = 0;
                    data_next       = i_tx_data;
                    n_state         = START;
                    tx_busy_next    = 1'b1;
                end
            end
            START: begin
                tx_busy_next = 1'b1;
                tx_next = 1'b0;
                if (i_b_tick) begin
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
                if (i_b_tick) begin
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
                if (i_b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        n_state = IDLE;
                        tx_busy_next = 1'b0; // 추가
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule
