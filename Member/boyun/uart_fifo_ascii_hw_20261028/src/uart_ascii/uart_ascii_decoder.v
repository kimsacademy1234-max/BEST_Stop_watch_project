`timescale 1ns / 1ps

module ascii_decoder (
    input clk,
    input rst,
    input            i_enable,   // 1 클럭 동안 i_ascii 가 유효 (uart_fifo_loopback rx_empty)
    input      [7:0] i_ascii,    // FIFO_RX pop_data (i_enable 이 지나면 다음 칸 값으로 바뀜)
    output o_pop,
    output o_key_run_stop,  // 'r' 8'h72
    output o_key_clear,  // 'c' 8'h63
    output o_key_mode,  // 'u' 8'h75
    output o_key_status  // 's' 8'h73
);

    //조합
    assign o_pop = i_enable;

    //순차
    /*
    reg r_pop;
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_pop <= 1'b0;
        end else begin
            r_pop <= i_enable; // 한 클럭 늦게
        end
    end
    assign o_pop = r_pop; 
    */

    assign o_key_run_stop = i_enable & (i_ascii == 8'h72);
    assign o_key_clear = i_enable & (i_ascii == 8'h63);
    assign o_key_mode = i_enable & (i_ascii == 8'h75);
    assign o_key_status = i_enable & (i_ascii == 8'h73);


endmodule
