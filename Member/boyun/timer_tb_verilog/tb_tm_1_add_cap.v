`timescale 1ns / 1ps
// =============================================================================
// tb_tm_1_add_cap (Verilog 판) — 타이머 더하기 · 상한 59:59
//   원본: verification_v2/tb/02_timer/tb_tm_1_add_cap.sv (정안성, SystemVerilog)
//   이 파일: 같은 시나리오 · 같은 판정을 수업 Verilog 문법으로 옮김 (10/17)
//     - task · function · string · bit · $sformatf 없음
//     - 검사: if (값 !== 기대값) → err + 1, 끝에 TOTAL MISMATCH
//     - 새로 나온 것 하나: dut.w_tm_min 처럼 "dut.안쪽 선 이름" 으로 Top 안 신호를 읽음 (계층 이름)
//   P1 화면/LED · P2 0 에서 L 무시 · P3 U×6 → 01:00 · P4 R, D, U
//   P5 상한 D×5 R×9 U×5 → 59:50, U → 59:59 · P6 59:59 에서 U/R/D · P7 52:10 + D → 59:59
//   원본과 다른 점: P6 은 프리로드(레지스터에 59:59 직접 쓰기) 대신 버튼으로 59:59 를 만든 뒤 시작
// =============================================================================
module tb_tm_1_add_cap;

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

    // ------------------------------------------------------------ 숫자 → 세그먼트 (fnd_decoder 표와 같음)
    parameter F0 = 8'hC0, F1 = 8'hF9, F2 = 8'hA4, F3 = 8'hB0, F4 = 8'h99,
              F5 = 8'h92, F6 = 8'h82, F7 = 8'hF8, F8 = 8'h80, F9 = 8'h90;

    // ------------------------------------------------------------ 검사 카운터
    integer err = 0;      // 틀린 검사 수
    integer n_chk = 0;    // 검사 수 (원본 TM1 = 21)

    // ------------------------------------------------------------ FND 화면 읽기
    // 스캔 칸 0~3 (w_scan_sel[2] = 0) 에서 켜진 자리의 세그먼트를 자리별로 저장
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
    // w_btn_* 는 정확히 1클럭 펄스여야 함 → 2클럭 연속 1 이면 err
    reg [3:0] btn_prev = 4'b0;
    always @(posedge clk) begin
        btn_prev <= {dut.w_btn_D, dut.w_btn_U, dut.w_btn_L, dut.w_btn_R};
        if ((btn_prev & {dut.w_btn_D, dut.w_btn_U, dut.w_btn_L, dut.w_btn_R}) != 4'b0) begin
            err = err + 1;
            $display("[%0d ns] FAIL PW : debouncer pulse longer than 1 clk", $time);
        end
    end

    // ------------------------------------------------------------ 시간 초과 감시 (3 s)
    initial begin
        repeat (3000) #1_000_000;
        err = err + 1;
        $display("[%0d ns] FAIL TIMEOUT : 3000 ms", $time);
        $display("TM1 checks = %0d, TOTAL MISMATCH = %0d", n_chk, err);
        $finish;
    end

    // ------------------------------------------------------------ 시나리오
    // 버튼 한 번 = negedge 에 맞춰 5 ms 누름 + 5 ms 뗌 (원본 press() 와 같음)
    // 리셋 = 1 us, 스위치 바꾼 뒤 1 us 기다림 (원본 do_reset() · set_sw() 와 같음)
    initial begin
        #1;
        // ============================================================ P1
        $display("[%0d ns] P1 timer screen: disp_mode=1, LED led5 only, FND 00.00", $time);
        @(negedge clk); rst = 1; #1000; rst = 0; #1000;
        @(negedge clk); timer_sw4 = 1; hour24_sw3 = 0; set_sw2 = 0; display_mode_sw1 = 0; mode_sw0 = 0; #1000;
        n_chk = n_chk + 1;
        if (dut.w_disp_mode !== 1'b1) begin
            err = err + 1; $display("[%0d ns] FAIL P1 TC1 disp_mode exp 1 got %b", $time, dut.w_disp_mode);
        end
        n_chk = n_chk + 1;
        if (led !== 16'h0020) begin
            err = err + 1; $display("[%0d ns] FAIL P1 TC6 LED exp 0020 got %h", $time, led);
        end
        #5_000_000;
        n_chk = n_chk + 1;
        if ({seg_an3, seg_an2, seg_an1, seg_an0} !== {F0, F0, F0, F0}) begin
            err = err + 1; $display("[%0d ns] FAIL P1 TC1 FND exp 00.00 got %h %h %h %h", $time, seg_an3, seg_an2, seg_an1, seg_an0);
        end

        // ============================================================ P2
        $display("[%0d ns] P2 L at 00:00 does not start", $time);
        @(negedge clk); rst = 1; #1000; rst = 0; #1000;
        @(negedge clk); timer_sw4 = 1; hour24_sw3 = 0; set_sw2 = 0; display_mode_sw1 = 0; mode_sw0 = 0; #1000;
        @(negedge clk); btn_L = 1; #5_000_000; btn_L = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_run, dut.w_tm_alarm} !== 2'b00) begin
            err = err + 1; $display("[%0d ns] FAIL P2 TB3 run alarm exp 0 0 got %b %b", $time, dut.w_tm_run, dut.w_tm_alarm);
        end

        // ============================================================ P3
        $display("[%0d ns] P3 U x6 -> 01:00 (sec carry into min)", $time);
        @(negedge clk); rst = 1; #1000; rst = 0; #1000;
        @(negedge clk); timer_sw4 = 1; hour24_sw3 = 0; set_sw2 = 0; display_mode_sw1 = 0; mode_sw0 = 0; #1000;
        repeat (5) begin @(negedge clk); btn_U = 1; #5_000_000; btn_U = 0; #5_000_000; end
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd0, 6'd50, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P3 TB2 U x5 exp 00:50.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        @(negedge clk); btn_U = 1; #5_000_000; btn_U = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd1, 6'd0, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P3 TB2 00:50 + U exp 01:00.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        #5_000_000;
        n_chk = n_chk + 1;
        if ({seg_an3, seg_an2, seg_an1, seg_an0} !== {F0, F1, F0, F0}) begin
            err = err + 1; $display("[%0d ns] FAIL P3 TB2 FND exp 01.00 got %h %h %h %h", $time, seg_an3, seg_an2, seg_an1, seg_an0);
        end

        // ============================================================ P4
        $display("[%0d ns] P4 R +1 min, D +10 min, U +10 s", $time);
        @(negedge clk); rst = 1; #1000; rst = 0; #1000;
        @(negedge clk); timer_sw4 = 1; hour24_sw3 = 0; set_sw2 = 0; display_mode_sw1 = 0; mode_sw0 = 0; #1000;
        @(negedge clk); btn_R = 1; #5_000_000; btn_R = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd1, 6'd0, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P4 TB2 R exp 01:00.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        @(negedge clk); btn_D = 1; #5_000_000; btn_D = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd11, 6'd0, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P4 TB2 D exp 11:00.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        @(negedge clk); btn_U = 1; #5_000_000; btn_U = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd11, 6'd10, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P4 TB2 U exp 11:10.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end

        // ============================================================ P5
        $display("[%0d ns] P5 cap: D x5 -> 50:00, R x9 -> 59:00, U x5 -> 59:50, U -> 59:59", $time);
        @(negedge clk); rst = 1; #1000; rst = 0; #1000;
        @(negedge clk); timer_sw4 = 1; hour24_sw3 = 0; set_sw2 = 0; display_mode_sw1 = 0; mode_sw0 = 0; #1000;
        repeat (5) begin @(negedge clk); btn_D = 1; #5_000_000; btn_D = 0; #5_000_000; end
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd50, 6'd0, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P5 TB1 D x5 exp 50:00.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        repeat (9) begin @(negedge clk); btn_R = 1; #5_000_000; btn_R = 0; #5_000_000; end
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd59, 6'd0, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P5 TB1 R x9 exp 59:00.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        repeat (5) begin @(negedge clk); btn_U = 1; #5_000_000; btn_U = 0; #5_000_000; end
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd59, 6'd50, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P5 TB1 U x5 exp 59:50.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        @(negedge clk); btn_U = 1; #5_000_000; btn_U = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd59, 6'd59, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P5 TB1 59:50 + U exp 59:59.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        #5_000_000;
        n_chk = n_chk + 1;
        if ({seg_an3, seg_an2, seg_an1, seg_an0} !== {F5, F9, F5, F9}) begin
            err = err + 1; $display("[%0d ns] FAIL P5 TB1 FND exp 59.59 got %h %h %h %h", $time, seg_an3, seg_an2, seg_an1, seg_an0);
        end

        // ============================================================ P6
        // 원본은 59:59 를 레지스터에 직접 씀(프리로드). 여기서는 P5 와 같은 버튼으로 59:59 를 만든다
        $display("[%0d ns] P6 at 59:59: U / R / D each -> 59:59", $time);
        @(negedge clk); rst = 1; #1000; rst = 0; #1000;
        @(negedge clk); timer_sw4 = 1; hour24_sw3 = 0; set_sw2 = 0; display_mode_sw1 = 0; mode_sw0 = 0; #1000;
        repeat (5) begin @(negedge clk); btn_D = 1; #5_000_000; btn_D = 0; #5_000_000; end
        repeat (9) begin @(negedge clk); btn_R = 1; #5_000_000; btn_R = 0; #5_000_000; end
        repeat (6) begin @(negedge clk); btn_U = 1; #5_000_000; btn_U = 0; #5_000_000; end
        @(negedge clk); btn_U = 1; #5_000_000; btn_U = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd59, 6'd59, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P6 TB1 59:59 + U exp 59:59.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        @(negedge clk); btn_R = 1; #5_000_000; btn_R = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd59, 6'd59, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P6 TB1 59:59 + R exp 59:59.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        @(negedge clk); btn_D = 1; #5_000_000; btn_D = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd59, 6'd59, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P6 TB1 59:59 + D exp 59:59.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end

        // ============================================================ P7
        $display("[%0d ns] P7 52:10 + D (+10 min = 62:10) -> 59:59", $time);
        @(negedge clk); rst = 1; #1000; rst = 0; #1000;
        @(negedge clk); timer_sw4 = 1; hour24_sw3 = 0; set_sw2 = 0; display_mode_sw1 = 0; mode_sw0 = 0; #1000;
        repeat (5) begin @(negedge clk); btn_D = 1; #5_000_000; btn_D = 0; #5_000_000; end
        repeat (2) begin @(negedge clk); btn_R = 1; #5_000_000; btn_R = 0; #5_000_000; end
        @(negedge clk); btn_U = 1; #5_000_000; btn_U = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd52, 6'd10, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P7 TB1 built exp 52:10.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        @(negedge clk); btn_D = 1; #5_000_000; btn_D = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd59, 6'd59, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P7 TB1 52:10 + D exp 59:59.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        @(negedge clk); btn_R = 1; #5_000_000; btn_R = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd59, 6'd59, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P7 TB1 59:59 + R exp 59:59.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end

        // ============================================================ 끝
        $display("[%0d ns] TM1 checks = %0d, TOTAL MISMATCH = %0d", $time, n_chk, err);
        $finish;
    end

endmodule
