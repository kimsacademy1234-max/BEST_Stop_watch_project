`timescale 1ns / 1ps
// =============================================================================
// tb_tm_3_cancel_background (Verilog 판) — RUN 중 버튼 · 취소 · 백그라운드 알람 · 화면 우선순위
//   원본: verification_v2/tb/02_timer/tb_tm_3_cancel_background.sv (정안성, SystemVerilog)
//   이 파일: 같은 시나리오 · 같은 판정을 수업 Verilog 문법으로 옮김 (클로드코드, 10/17)
//     - task · function · string · bit · $sformatf 없음
//     - 검사: if (값 !== 기대값) → err + 1, 끝에 TOTAL MISMATCH
//     - 새로 나온 것 하나: dut.w_tm_min 처럼 "dut.안쪽 선 이름" 으로 Top 안 신호를 읽음 (계층 이름)
//   P1 RUN 중 U/R/D 무시 · P2 RUN 중 L = 취소 · P3 시계 화면에서 알람 (백그라운드)
//   P4 시계 · 스톱워치 화면 버튼은 알람을 안 끔 · P5 sw4 · sw0 둘 다 1 → 타이머 우선, R 로 알람 끄기
//   원본과 다른 점: P3 은 프리로드(00:00.30 을 레지스터에 쓰기) 대신 U(00:10) 로 시작해 실제 10 초를 기다림
//                   → 시뮬 시간이 원본 555 ms 보다 약 10 초 길다
// =============================================================================
module tb_tm_3_cancel_background;

    reg clk = 1'b0;
    reg rst = 1'b0;
    reg btn_R = 1'b0, btn_L = 1'b0, btn_U = 1'b0, btn_D = 1'b0;
    reg mode_sw0 = 1'b0;
    reg display_mode_sw1 = 1'b0;
    reg set_sw2 = 1'b0;
    reg hour24_sw3 = 1'b0;
    reg timer_sw4 = 1'b0;
    wire [3:0]  fnd_com;
    wire [7:0]  fnd_font;
    wire [15:0] led;

    always #5 clk = ~clk;   // 100 MHz

    stopwatch_watch dut (
        .clk             (clk),
        .rst             (rst),
        .btn_R           (btn_R),
        .btn_L           (btn_L),
        .btn_U           (btn_U),
        .btn_D           (btn_D),
        .mode_sw0        (mode_sw0),
        .display_mode_sw1(display_mode_sw1),
        .set_sw2         (set_sw2),
        .hour24_sw3      (hour24_sw3),
        .timer_sw4       (timer_sw4),
        .fnd_com         (fnd_com),
        .fnd_font        (fnd_font),
        .led             (led)
    );

    parameter F0 = 8'hC0, F1 = 8'hF9, F2 = 8'hA4, F3 = 8'hB0, F4 = 8'h99,
              F5 = 8'h92, F6 = 8'h82, F7 = 8'hF8, F8 = 8'h80, F9 = 8'h90;

    integer err = 0;      // 틀린 검사 수
    integer n_chk = 0;    // 검사 수 (원본 TM3 = 11)
    integer c1;           // 남은 시간 (1/100 초)
    integer c2;
    reg [15:0] exp_led;

    // ------------------------------------------------------------ FND 화면 읽기
    reg [7:0] seg_an0 = 8'hFF, seg_an1 = 8'hFF, seg_an2 = 8'hFF, seg_an3 = 8'hFF;
    always @(posedge clk) begin
        if (dut.U_FND_CONTROLLER.w_scan_sel[2] == 1'b0) begin
            if (fnd_com == 4'b1110) seg_an0 <= fnd_font;
            if (fnd_com == 4'b1101) seg_an1 <= fnd_font;
            if (fnd_com == 4'b1011) seg_an2 <= fnd_font;
            if (fnd_com == 4'b0111) seg_an3 <= fnd_font;
        end
    end

    // ------------------------------------------------------------ 디바운서 펄스 폭 감시
    reg [3:0] btn_prev = 4'b0;
    always @(posedge clk) begin
        btn_prev <= {dut.w_btn_D, dut.w_btn_U, dut.w_btn_L, dut.w_btn_R};
        if ((btn_prev & {dut.w_btn_D, dut.w_btn_U, dut.w_btn_L, dut.w_btn_R}) != 4'b0) begin
            err = err + 1;
            $display("[%0d ns] FAIL PW : debouncer pulse longer than 1 clk", $time);
        end
    end

    // ------------------------------------------------------------ 시간 초과 감시 (15 s)
    initial begin
        repeat (15000) #1_000_000;
        err = err + 1;
        $display("[%0d ns] FAIL TIMEOUT : 15000 ms", $time);
        $display("TM3 checks = %0d, TOTAL MISMATCH = %0d", n_chk, err);
        $finish;
    end

    // ------------------------------------------------------------ 시나리오
    initial begin
        #1;
        // ============================================================ P1
        $display("[%0d ns] P1 RUN: U/R/D ignored", $time);
        @(negedge clk); rst = 1; #1000; rst = 0; #1000;
        @(negedge clk); timer_sw4 = 1; hour24_sw3 = 0; set_sw2 = 0; display_mode_sw1 = 0; mode_sw0 = 0; #1000;
        @(negedge clk); btn_R = 1; #5_000_000; btn_R = 0; #5_000_000;          // 01:00
        @(negedge clk); btn_L = 1; #5_000_000; btn_L = 0; #5_000_000;          // RUN
        c1 = (dut.w_tm_min * 60 + dut.w_tm_sec) * 100 + dut.w_tm_msec;
        @(negedge clk); btn_U = 1; #5_000_000; btn_U = 0; #5_000_000;
        @(negedge clk); btn_R = 1; #5_000_000; btn_R = 0; #5_000_000;
        @(negedge clk); btn_D = 1; #5_000_000; btn_D = 0; #5_000_000;
        c2 = (dut.w_tm_min * 60 + dut.w_tm_sec) * 100 + dut.w_tm_msec;
        // 30 ms 동안 3칸 줄었어야 함 (더해졌으면 c2 > c1)
        n_chk = n_chk + 1;
        if (!(c2 < c1 && c2 > c1 - 10)) begin
            err = err + 1; $display("[%0d ns] FAIL P1 TC2 U/R/D during RUN exp (%0d,%0d) got %0d", $time, c1 - 10, c1, c2);
        end
        n_chk = n_chk + 1;
        if (dut.w_tm_run !== 1'b1) begin
            err = err + 1; $display("[%0d ns] FAIL P1 TC2 still running exp 1 got %b", $time, dut.w_tm_run);
        end

        // ============================================================ P2
        $display("[%0d ns] P2 RUN: L -> cancel to 00:00, SET", $time);
        @(negedge clk); rst = 1; #1000; rst = 0; #1000;
        @(negedge clk); timer_sw4 = 1; hour24_sw3 = 0; set_sw2 = 0; display_mode_sw1 = 0; mode_sw0 = 0; #1000;
        @(negedge clk); btn_R = 1; #5_000_000; btn_R = 0; #5_000_000;
        @(negedge clk); btn_L = 1; #5_000_000; btn_L = 0; #5_000_000;
        #50_000_000;
        @(negedge clk); btn_L = 1; #5_000_000; btn_L = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec, dut.w_tm_run, dut.w_tm_alarm} !== {6'd0, 6'd0, 7'd0, 1'b0, 1'b0}) begin
            err = err + 1; $display("[%0d ns] FAIL P2 TC2 cancel exp 00:00.00 run 0 alarm 0 got %0d:%0d.%0d run %b alarm %b",
                                    $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec, dut.w_tm_run, dut.w_tm_alarm);
        end

        // ============================================================ P3
        $display("[%0d ns] P3 background: start 00:10, go to watch screen, ALARM on watch screen", $time);
        @(negedge clk); rst = 1; #1000; rst = 0; #1000;
        @(negedge clk); timer_sw4 = 1; hour24_sw3 = 0; set_sw2 = 0; display_mode_sw1 = 0; mode_sw0 = 0; #1000;
        @(negedge clk); btn_U = 1; #5_000_000; btn_U = 0; #5_000_000;          // 00:10 (원본: R 01:00 + 프리로드 00:00.30)
        @(negedge clk); btn_L = 1; #5_000_000; btn_L = 0; #5_000_000;          // RUN
        @(negedge clk); timer_sw4 = 0; hour24_sw3 = 0; set_sw2 = 0; display_mode_sw1 = 1; mode_sw0 = 0; #1000;   // 시계 화면 (시.분)
        n_chk = n_chk + 1;
        if (dut.w_tm_run !== 1'b1) begin
            err = err + 1; $display("[%0d ns] FAIL P3 TC3 runs in background exp 1 got %b", $time, dut.w_tm_run);
        end
        @(posedge dut.w_tm_alarm);
        $display("[%0d ns] P3 ALARM reached while watch screen is shown", $time);
        #20_000_000;
        if (dut.w_wt_msec >= 50) exp_led = 16'hFFFF;
        else                     exp_led = 16'h0000;
        n_chk = n_chk + 1;
        if (led !== exp_led) begin
            err = err + 1; $display("[%0d ns] FAIL P3 TC3 alarm LED on watch screen exp %h got %h", $time, exp_led, led);
        end
        // 시계 화면은 그대로 = 시.분. 리셋 뒤 12:00 에서 약 10 초 지났으므로 12.00
        #5_000_000;
        n_chk = n_chk + 1;
        if ({seg_an3, seg_an2, seg_an1, seg_an0} !== {F1, F2, F0, F0}) begin
            err = err + 1; $display("[%0d ns] FAIL P3 TC3 FND exp 12.00 got %h %h %h %h", $time, seg_an3, seg_an2, seg_an1, seg_an0);
        end

        // ============================================================ P4 (P3 의 알람을 그대로 씀)
        $display("[%0d ns] P4 watch-screen buttons do not stop the alarm", $time);
        @(negedge clk); btn_U = 1; #5_000_000; btn_U = 0; #5_000_000;
        @(negedge clk); btn_D = 1; #5_000_000; btn_D = 0; #5_000_000;
        @(negedge clk); btn_L = 1; #5_000_000; btn_L = 0; #5_000_000;
        @(negedge clk); btn_R = 1; #5_000_000; btn_R = 0; #5_000_000;
        n_chk = n_chk + 1;
        if (dut.w_tm_alarm !== 1'b1) begin
            err = err + 1; $display("[%0d ns] FAIL P4 TC4 alarm after watch-screen U/D/L/R exp 1 got %b", $time, dut.w_tm_alarm);
        end
        @(negedge clk); timer_sw4 = 0; hour24_sw3 = 0; set_sw2 = 0; display_mode_sw1 = 0; mode_sw0 = 1; #1000;   // 스톱워치 화면
        @(negedge clk); btn_D = 1; #5_000_000; btn_D = 0; #5_000_000;
        n_chk = n_chk + 1;
        if (dut.w_tm_alarm !== 1'b1) begin
            err = err + 1; $display("[%0d ns] FAIL P4 TC4 alarm after stopwatch-screen D exp 1 got %b", $time, dut.w_tm_alarm);
        end
        @(negedge clk); btn_D = 1; #5_000_000; btn_D = 0; #5_000_000;          // 랩 원복

        // ============================================================ P5 (P4 의 알람을 그대로 씀)
        $display("[%0d ns] P5 sw4=1 & sw0=1 -> timer has priority; R turns alarm off", $time);
        @(negedge clk); timer_sw4 = 1; hour24_sw3 = 0; set_sw2 = 0; display_mode_sw1 = 0; mode_sw0 = 1; #1000;
        n_chk = n_chk + 1;
        if ({dut.w_sel_tm, dut.w_sel_sw} !== 2'b10) begin
            err = err + 1; $display("[%0d ns] FAIL P5 TC5 sel_tm sel_sw exp 1 0 got %b %b", $time, dut.w_sel_tm, dut.w_sel_sw);
        end
        @(negedge clk); btn_R = 1; #5_000_000; btn_R = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_alarm, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {1'b0, 6'd0, 6'd0, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P5 TC5 R alarm off exp alarm 0 00:00.00 got alarm %b %0d:%0d.%0d",
                                    $time, dut.w_tm_alarm, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        n_chk = n_chk + 1;
        if (led !== 16'h0020) begin
            err = err + 1; $display("[%0d ns] FAIL P5 TC6 LED exp 0020 got %h", $time, led);
        end

        $display("[%0d ns] TM3 checks = %0d, TOTAL MISMATCH = %0d", $time, n_chk, err);
        $finish;
    end

endmodule
