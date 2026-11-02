`timescale 1ns / 1ps

module ascii_decoder (
    input            clk,
    input            rst,
    input            enable,   // 1 클럭 동안 ascii 가 유효 (uart_fifo_loopback rx_empty)
    input      [7:0] ascii,    // FIFO_RX pop_data (enable 이 지나면 다음 칸 값으로 바뀜)
    output pop,
    output reg [3:0] bin       // fnd_controller 로 (0 ~ f)
);

    reg [7:0] data_reg;   // enable 때 받은 바이트를 저장 → ascii 가 바뀌어도 유지

    assign pop = enable;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            data_reg <= 8'h00;   // 리셋 때 00 → bin 0
        end else begin
            if (enable) begin
                // 0~9 · A~F · a~f 만 저장, 다른 글자는 이전 값 유지
                if ((ascii >= 8'h30 && ascii <= 8'h39) ||
                    (ascii >= 8'h41 && ascii <= 8'h46) ||
                    (ascii >= 8'h61 && ascii <= 8'h66)) begin
                    data_reg <= ascii;
                end
            end
        end
    end

    // 저장한 data_reg 를 풀어서 bin (지금의 ascii 가 아님)
    always @(*) begin
        if (data_reg >= 8'h30 && data_reg <= 8'h39) begin
            bin = data_reg[3:0];
        end else if (data_reg >= 8'h41 && data_reg <= 8'h46) begin
            bin = data_reg[3:0] + 9;
        end else if (data_reg >= 8'h61 && data_reg <= 8'h66) begin
            bin = data_reg[3:0] + 9;
        end else begin
            bin = 4'h0;
        end
    end

endmodule
