`timescale 1ns / 1ps
// =============================================================================
//  거리 표시용 FND 컨트롤러 (Fnd_Controller_dot 에서 min / hour 제거)
//   i_value : 0 ~ 4000 (0.1cm 단위) -> 4자리 표시
//   i_dot   : 1 이면 둘째 자리(오른쪽에서 두 번째)에 소수점 -> 3527 => "352.7"
//             0 이면 소수점 없음 (cm 정수 값을 넣을 때)
//  사용 하위 모듈(기존 파일 그대로): digit_splitter, clock_tick_generator,
//                                    counter8, mux_8x1, decoder_2x4, fnd_decoder
//   i_err   : 1 이면 4자리 모두 "-" 표시 (측정 오류, LD9 와 동시)
//  * fnd_decoder 출력 = {dp, g, f, e, d, c, b, a} active-low (Basys3) 라고 가정
// =============================================================================
module fnd_controller_dist (
    input         i_clk,
    input         i_reset,
    input  [11:0] i_value,
    input         i_dot,
    input         i_err,
    output [3:0]  o_fnd_com,
    output [7:0]  o_fnd_data
);

    wire [6:0] w_low  = i_value % 100;   // 하위 두 자리 (0~99)
    wire [5:0] w_high = i_value / 100;   // 상위 두 자리 (0~40)

    wire [3:0] w_ds1_low,  w_ds10_low;
    wire [3:0] w_ds1_high, w_ds10_high;
    wire [2:0] w_sel;
    wire [3:0] w_bcd;
    wire [7:0] w_seg;
    wire       w_clk_1kHz;

    digit_splitter #(.WIDTH(7)) U_LOW (
        .i_din (w_low),
        .o_ds1 (w_ds1_low),
        .o_ds10(w_ds10_low)
    );

    digit_splitter #(.WIDTH(6)) U_HIGH (
        .i_din (w_high),
        .o_ds1 (w_ds1_high),
        .o_ds10(w_ds10_high)
    );

    clock_tick_generator #(
        .CLK_FRQ(2000)
    ) U_CLK_GEN_1KHZ (
        .i_clk  (i_clk),
        .i_reset(i_reset),
        .o_clk  (w_clk_1kHz)
    );

    counter8 U_COUNTER8 (
        .i_clk  (w_clk_1kHz),
        .i_reset(i_reset),
        .o_sel  (w_sel)
    );

    // sel 0~3 : 숫자 4자리 / sel 4~7 : 꺼짐(4'hf)
    mux_8x1 U_MUX (
        .i_sel (w_sel),
        .i_d0  (w_ds1_low),
        .i_d1  (w_ds10_low),
        .i_d2  (w_ds1_high),
        .i_d3  (w_ds10_high),
        .i_d4  (4'hf),
        .i_d5  (4'hf),
        .i_d6  (4'hf),
        .i_d7  (4'hf),
        .o_data(w_bcd)
    );

    decoder_2x4 U_DECODER (
        .i_sel  (w_sel[1:0]),
        .o_dec_n(o_fnd_com)
    );

    fnd_decoder U_FND_DEC (
        .i_hex     (w_bcd),
        .o_fnd_data(w_seg)
    );

    // 소수점 : sel == 1 (오른쪽에서 두 번째 자리) 일 때만 dp ON (active-low -> 0)
    wire w_dp_on = i_dot && (w_sel == 3'd1);
    wire [7:0] w_num_seg = {~w_dp_on & w_seg[7], w_seg[6:0]};

    // 오류 : g 세그먼트만 ON -> "-" (active-low : dp=1, g=0, f~a=1)
    localparam [7:0] SEG_DASH = 8'b1011_1111;
    assign o_fnd_data = i_err ? SEG_DASH : w_num_seg;

endmodule
