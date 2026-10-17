`timescale 1ns / 1ps
// =============================================================================
// tb_timer_simple — 타이머 자동 검증 (발표용 간단판, HW2 tb_adder_fnd.v 와 같은 틀)
//   ① 더하기 30번 : U(+10초) R(+1분) D(+10분) 을 번갈아 누르고, 매번 기대값을 계산해 비교
//                   (초 → 분 올림, 59:59 상한 포함)
//   ② 0 에서 L    : 시작 안 함
//   ③ 10초 카운트다운 : U → L 시작 → 알람까지 걸린 시간 · 알람 때 값 · D 로 알람 끄기
//   ④ 취소        : 1분 넣고 시작 → L → 00:00 으로 돌아감
//   틀리면 FAIL 한 줄, 끝에 "TOTAL 검사수, MISMATCH = 틀린수"
// =============================================================================
module tb_timer_simple ();
    reg clk = 0, rst = 0;
    reg btn_R = 0, btn_L = 0, btn_U = 0, btn_D = 0;
    reg mode_sw0 = 0, display_mode_sw1 = 0, set_sw2 = 0, hour24_sw3 = 0;
    reg timer_sw4 = 1;                      // 처음부터 타이머 화면
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;
    wire [15:0] led;

    stopwatch_watch DUT (
        .clk(clk), .rst(rst),
        .btn_R(btn_R), .btn_L(btn_L), .btn_U(btn_U), .btn_D(btn_D),
        .mode_sw0(mode_sw0), .display_mode_sw1(display_mode_sw1),
        .set_sw2(set_sw2), .hour24_sw3(hour24_sw3), .timer_sw4(timer_sw4),
        .fnd_com(fnd_com), .fnd_font(fnd_font), .led(led)
    );

    always #5 clk = ~clk;                   // 100 MHz

    // 타이머 남은 시간은 보드 핀으로 안 나오므로 Top 안의 선을 읽는다
    wire [5:0] tm_min  = DUT.w_tm_min;
    wire [5:0] tm_sec  = DUT.w_tm_sec;
    wire [6:0] tm_msec = DUT.w_tm_msec;
    wire       tm_run  = DUT.w_tm_run;
    wire       tm_alarm = DUT.w_tm_alarm;

    integer i;
    integer err, total;
    integer exp_time;                       // 기대 남은 시간 (초)
    reg [5:0] exp_min, exp_sec;             // 기대 분 · 초
    reg [63:0] t_start, t_alarm;            // ns

    initial begin
        err = 0;
        total = 0;

        #1;                                     // 클럭 엣지와 겹치지 않게 1 ns 비켜 시작
        // 리셋
        rst = 1; #1000; rst = 0; #1000;

        // ------------------------------------------------ ① 더하기 30번 (U R D U R D …)
        exp_time = 0;
        for (i = 0; i < 30; i = i + 1) begin
            if (i % 3 == 0) begin
                btn_U = 1; #5_000_000; btn_U = 0; #5_000_000;   // 5 ms 누르고 5 ms 뗌
                exp_time = exp_time + 10;
            end else if (i % 3 == 1) begin
                btn_R = 1; #5_000_000; btn_R = 0; #5_000_000;
                exp_time = exp_time + 60;
            end else begin
                btn_D = 1; #5_000_000; btn_D = 0; #5_000_000;
                exp_time = exp_time + 600;
            end
            if (exp_time > 3599) exp_time = 3599;              // 상한 59:59
            exp_min = exp_time / 60;
            exp_sec = exp_time % 60;

            total = total + 1;
            if ({tm_min, tm_sec, tm_msec} !== {exp_min, exp_sec, 7'd0}) begin
                err = err + 1;
                $display("FAIL: add #%0d -> %0d:%0d.%0d (expect %0d:%0d.00)",
                         i, tm_min, tm_sec, tm_msec, exp_min, exp_sec);
            end
        end
        $display("[1] add x30 done: %0d:%0d (expect 59:59)", tm_min, tm_sec);

        // ------------------------------------------------ ② 0 에서 L : 시작 안 함
        rst = 1; #1000; rst = 0; #1000;
        btn_L = 1; #5_000_000; btn_L = 0; #5_000_000;
        total = total + 1;
        if (tm_run !== 1'b0) begin
            err = err + 1;
            $display("FAIL: L at 00:00 started the timer");
        end

        // ------------------------------------------------ ③ 10초 카운트다운 → 알람
        btn_U = 1; #5_000_000; btn_U = 0; #5_000_000;           // 00:10
        btn_L = 1;
        @(posedge tm_run);   t_start = $time;  #1;              // 시작 순간
        #5_000_000; btn_L = 0;
        @(posedge tm_alarm); t_alarm = $time;  #1;              // 알람 순간
        $display("[3] run -> alarm = %0d ns", t_alarm - t_start);

        total = total + 1;                                       // 10초 (팀 판은 tick 공유라 최대 10 ms 짧을 수 있음)
        if (t_alarm - t_start < 64'd9_990_000_000 || t_alarm - t_start > 64'd10_000_000_010) begin
            err = err + 1;
            $display("FAIL: 10 s timer took %0d ns", t_alarm - t_start);
        end
        total = total + 1;
        if ({tm_min, tm_sec, tm_msec, tm_run} !== {6'd0, 6'd0, 7'd0, 1'b0}) begin
            err = err + 1;
            $display("FAIL: at alarm %0d:%0d.%0d run=%b (expect 00:00.00 run=0)", tm_min, tm_sec, tm_msec, tm_run);
        end
        btn_D = 1; #5_000_000; btn_D = 0; #5_000_000;            // 아무 버튼 = 알람 끄기
        total = total + 1;
        if ({tm_alarm, tm_min, tm_sec} !== {1'b0, 6'd0, 6'd0}) begin
            err = err + 1;
            $display("FAIL: D did not just turn the alarm off (alarm=%b %0d:%0d)", tm_alarm, tm_min, tm_sec);
        end

        // ------------------------------------------------ ④ 취소
        btn_R = 1; #5_000_000; btn_R = 0; #5_000_000;            // 01:00
        btn_L = 1; #5_000_000; btn_L = 0; #5_000_000;            // 시작
        #50_000_000;                                             // 50 ms 흐름
        btn_L = 1; #5_000_000; btn_L = 0; #5_000_000;            // 취소
        total = total + 1;
        if ({tm_min, tm_sec, tm_msec, tm_run} !== {6'd0, 6'd0, 7'd0, 1'b0}) begin
            err = err + 1;
            $display("FAIL: cancel -> %0d:%0d.%0d run=%b (expect 00:00.00 run=0)", tm_min, tm_sec, tm_msec, tm_run);
        end

        $display("TOTAL %0d, MISMATCH = %0d", total, err);
        $finish;
    end

endmodule
