`timescale 1ns / 1ps
// 보드 표시용 : dht11_core 결과 → FND 표시값 · LED
//  - FND 표시값 = 습도 x 100 + 온도 (예 : 55 %, 24 ℃ → 5524 → "55.24")
//  - 첫 측정 전 · 오류면 "----"
// (요청 · 간격 관리는 dht11_core 안으로 옮김)
// (merge) clk / rst → i_clk / i_rst (v2 포트 규칙)
module dht11_manager (
    input         i_clk,
    input         i_rst,
    input         i_measuring,
    input         i_done,
    input         i_valid,
    input  [7:0]  i_humidity,
    input  [7:0]  i_temperature,
    output [13:0] o_fnd_data,
    output        o_dashes,      // 1 : "----"
    output [2:0]  o_led          // [0] 측정 중, [1] 오류, [2] 정상값
);
    reg        c_have_result, c_error;
    reg [13:0] c_fnd_data;

    wire [6:0] w_hum  = (i_humidity    > 8'd99) ? 7'd99 : i_humidity[6:0];
    wire [6:0] w_temp = (i_temperature > 8'd99) ? 7'd99 : i_temperature[6:0];

    assign o_fnd_data = c_fnd_data;
    assign o_dashes   = !c_have_result || c_error;
    assign o_led      = {c_have_result && !c_error, c_error, i_measuring};

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            c_have_result <= 1'b0;
            c_error       <= 1'b0;
            c_fnd_data    <= 0;
        end else if (i_done) begin
            c_have_result <= 1'b1;
            c_error       <= !i_valid;
            if (i_valid) c_fnd_data <= w_hum * 7'd100 + w_temp;
        end
    end
endmodule
