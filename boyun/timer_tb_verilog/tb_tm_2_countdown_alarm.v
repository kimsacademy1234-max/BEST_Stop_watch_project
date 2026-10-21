`timescale 1ns / 1ps
// =============================================================================
// tb_tm_2_countdown_alarm (Verilog 판) — 실제 10 초 카운트다운 · 알람 · 빌림
//   원본: verification_v2/tb/02_timer/tb_tm_2_countdown_alarm.sv (정안성, SystemVerilog)
//   이 파일: 같은 시나리오 · 같은 판정을 수업 Verilog 문법으로 옮김 (10/17)
//     - task · function · string · bit · longint · $sformatf 없음
//     - 검사: if (값 !== 기대값) → err + 1, 끝에 TOTAL MISMATCH
//     - 새로 나온 것 하나: dut.w_tm_min 처럼 "dut.안쪽 선 이름" 으로 Top 안 신호를 읽음 (계층 이름)
//   P1 U → 00:10, L 시작 → 알람까지 실제 시간 (10 s 기준) · P2 알람 LED 1.5 s 동안 30번
//   P3 D 로 알람 끄기 (값 그대로) · P4 빌림 01:00.00 → 00:59.99, 10:00.00 → 09:59.99
//   원본과 다른 점: P4 는 프리로드(동작 중 레지스터에 값 쓰기) 대신 R(01:00) · D(10:00) 로 만든 뒤
//                   L 로 시작하고 첫 tick 뒤 값을 본다
// =============================================================================
module tb_tm_2_countdown_alarm;

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
    integer n_chk = 0;    // 검사 수 (원본 TM2 = 41)
    integer i;
    integer nbad;
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

    // ------------------------------------------------------------ RUN 시작 · 알람 시각 기록 (ns)
    reg [63:0] t_run = 0, t_alarm = 0, dt = 0;
    always @(posedge dut.w_tm_run)   t_run   = $time;
    always @(posedge dut.w_tm_alarm) t_alarm = $time;

    // ------------------------------------------------------------ 시간 초과 감시 (25 s)
    initial begin
        repeat (25000) #1_000_000;
        err = err + 1;
        $display("[%0d ns] FAIL TIMEOUT : 25000 ms", $time);
        $display("TM2 checks = %0d, TOTAL MISMATCH = %0d", n_chk, err);
        $finish;
    end

    // ------------------------------------------------------------ 시나리오
    initial begin
        #1;
        // ============================================================ P1
        $display("[%0d ns] P1 00:10 real countdown, run -> alarm interval", $time);
        @(negedge clk); rst = 1; #1000; rst = 0; #1000;
        @(negedge clk); timer_sw4 = 1; hour24_sw3 = 0; set_sw2 = 0; display_mode_sw1 = 0; mode_sw0 = 0; #1000;
        @(negedge clk); btn_U = 1; #5_000_000; btn_U = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd0, 6'd10, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P1 TB5 U exp 00:10.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        @(negedge clk); btn_L = 1; #5_000_000; btn_L = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_run, led[6]} !== 2'b11) begin
            err = err + 1; $display("[%0d ns] FAIL P1 TC6 running led6 exp 1 1 got %b %b", $time, dut.w_tm_run, led[6]);
        end
        @(posedge dut.w_tm_alarm);
        #1;
        dt = t_alarm - t_run;
        $display("[%0d ns] P1 run -> alarm = %0d ns (set 10 s)", $time, dt);
        // 기준 (10/17 ④ 타이머 전용 tick): 정확히 10,000 ms + 파이프라인 2클럭 → (10,000 ms - 1클럭, 10,000 ms + 3클럭]
        //   (그 전 공용 tick 판은 9,990 ms 초과 ~ 10,000 ms + 1클럭)
        n_chk = n_chk + 1;
        if (!(dt > 64'd9_999_999_990 && dt <= 64'd10_000_000_030)) begin
            err = err + 1; $display("[%0d ns] FAIL P1 TB5 duration exp (10000 ms - 1 clk, 10000 ms + 3 clk] got %0d ns", $time, dt);
        end
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec, dut.w_tm_run} !== {6'd0, 6'd0, 7'd0, 1'b0}) begin
            err = err + 1; $display("[%0d ns] FAIL P1 TB5 at alarm exp 00:00.00 run 0 got %0d:%0d.%0d run %b", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec, dut.w_tm_run);
        end

        // ============================================================ P2 (P1 의 알람을 그대로 씀)
        $display("[%0d ns] P2 alarm LED 1.5 s: all 16 = FFFF while watch msec >= 50, else 0000", $time);
        nbad = 0;
        for (i = 0; i < 30; i = i + 1) begin
            #50_000_000;
            if (dut.w_wt_msec >= 50) exp_led = 16'hFFFF;
            else                     exp_led = 16'h0000;
            n_chk = n_chk + 1;
            if (led !== exp_led) begin
                err = err + 1; nbad = nbad + 1;
                $display("[%0d ns] FAIL P2 TC6 sample %0d (watch msec=%0d) exp %h got %h", $time, i, dut.w_wt_msec, exp_led, led);
            end
        end
        $display("[%0d ns] P2 30 samples over 1.5 s, %0d mismatches", $time, nbad);
        n_chk = n_chk + 1;
        if (dut.w_tm_alarm !== 1'b1) begin
            err = err + 1; $display("[%0d ns] FAIL P2 TC6 still alarming exp 1 got %b", $time, dut.w_tm_alarm);
        end

        // ============================================================ P3
        $display("[%0d ns] P3 D turns alarm off -> SET, value stays 0", $time);
        @(negedge clk); btn_D = 1; #5_000_000; btn_D = 0; #5_000_000;
        n_chk = n_chk + 1;
        if ({dut.w_tm_alarm, dut.w_tm_run} !== 2'b00) begin
            err = err + 1; $display("[%0d ns] FAIL P3 TB6 alarm run exp 0 0 got %b %b", $time, dut.w_tm_alarm, dut.w_tm_run);
        end
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd0, 6'd0, 7'd0}) begin
            err = err + 1; $display("[%0d ns] FAIL P3 TB6 exp 00:00.00 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        n_chk = n_chk + 1;
        if (led !== 16'h0020) begin
            err = err + 1; $display("[%0d ns] FAIL P3 TC6 LED exp 0020 got %h", $time, led);
        end

        // ============================================================ P4
        // 원본: 00:10 으로 RUN 중에 레지스터에 01:00.00 / 10:00.00 을 써 넣고 1 tick 뒤 확인
        // 여기: R 로 01:00 을 만든 뒤 L 을 누르고, RUN 이 된 뒤 첫 tick 이 지나면 확인
        $display("[%0d ns] P4 borrow: 01:00.00 -> 00:59.99, 10:00.00 -> 09:59.99", $time);
        @(negedge clk); rst = 1; #1000; rst = 0; #1000;
        @(negedge clk); timer_sw4 = 1; hour24_sw3 = 0; set_sw2 = 0; display_mode_sw1 = 0; mode_sw0 = 0; #1000;
        @(negedge clk); btn_R = 1; #5_000_000; btn_R = 0; #5_000_000;          // 01:00
        @(negedge clk); btn_L = 1;
        @(posedge dut.w_tm_run);                                                 // RUN 시작
        @(posedge dut.w_tm_tick_10ms); repeat (5) @(negedge clk);                // 타이머 전용 tick 첫 펄스 뒤 (10/17 ④)
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd0, 6'd59, 7'd99}) begin
            err = err + 1; $display("[%0d ns] FAIL P4 TB4 01:00.00 - 1 tick exp 00:59.99 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        #5_000_000; btn_L = 0; #5_000_000;
        @(negedge clk); btn_L = 1; #5_000_000; btn_L = 0; #5_000_000;          // L = 취소 → 00:00

        @(negedge clk); btn_D = 1; #5_000_000; btn_D = 0; #5_000_000;          // 10:00
        @(negedge clk); btn_L = 1;
        @(posedge dut.w_tm_run);
        @(posedge dut.w_tm_tick_10ms); repeat (5) @(negedge clk);
        n_chk = n_chk + 1;
        if ({dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {6'd9, 6'd59, 7'd99}) begin
            err = err + 1; $display("[%0d ns] FAIL P4 TB4 10:00.00 - 1 tick exp 09:59.99 got %0d:%0d.%0d", $time, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
        end
        #5_000_000; btn_L = 0;
        #5_000_000;
        // 화면은 분.초 = 09.59 (원본 check_disp 와 같이 5 ms 뒤)
        n_chk = n_chk + 1;
        if ({seg_an3, seg_an2, seg_an1, seg_an0} !== {F0, F9, F5, F9}) begin
            err = err + 1; $display("[%0d ns] FAIL P4 TB4 FND exp 09.59 got %h %h %h %h", $time, seg_an3, seg_an2, seg_an1, seg_an0);
        end
        @(negedge clk); btn_L = 1; #5_000_000; btn_L = 0; #5_000_000;          // 취소

        $display("[%0d ns] TM2 checks = %0d, TOTAL MISMATCH = %0d", $time, n_chk, err);
        $finish;
    end

endmodule
