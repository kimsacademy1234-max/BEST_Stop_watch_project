`timescale 1ns / 1ps

// 클로드코드 참고 구현 자동 검사 TB (Icarus / xsim)
// 시뮬 시간을 줄이려고 100Hz tick_gen 두 개만 F_COUNT = 100 으로 줄임 (1 "초" = 10_000 클럭 = 100 us).
// 디바운서는 실제 값 그대로 (1 MHz 샘플 8칸).
module tb_stopwatch_watch ();
    reg clk, rst;
    reg btnR, btnL, btnU, btnD;
    reg sw_mode, sw_display_mode, sw_set, sw_12h, sw_timer, sw_alt;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;
    wire [15:0] led;

    integer err;
    time t_run, t_alarm;
    integer i;
    reg [5:0] m0;

    parameter PUSH = 20_000;  // 버튼 누름/뗌 각각 20 us

    defparam dut.U_WATCH_DATAPATH.U_TICK_GEN_100HZ.F_COUNT = 100;
    defparam dut.U_STOPWATCH_DATAPATH.U_TICK_GEN_100HZ.F_COUNT = 100;
    defparam dut.U_TIMER_DATAPATH.U_TICK_GEN_100HZ.F_COUNT = 100;

    stopwatch_watch dut (
        .clk(clk),
        .rst(rst),
        .btnR(btnR),
        .btnL(btnL),
        .btnU(btnU),
        .btnD(btnD),
        .sw_mode(sw_mode),
        .sw_display_mode(sw_display_mode),
        .sw_set(sw_set),
        .sw_12h(sw_12h),
        .sw_timer(sw_timer),
        .sw_alt(sw_alt),
        .fnd_com(fnd_com),
        .fnd_font(fnd_font),
        .led(led)
    );

    // 보기 쉽게 내부 신호 이름 붙이기
    wire [6:0] wt_msec = dut.w_wt_msec;
    wire [5:0] wt_sec = dut.w_wt_sec;
    wire [5:0] wt_min = dut.w_wt_min;
    wire [4:0] wt_hour = dut.w_wt_hour;
    wire [1:0] cursor = dut.w_cursor;
    wire set_mode = dut.w_set_mode;
    wire sw_run = dut.w_run_stop;

    always #5 clk = ~clk;

    // 시간 제한: 정상이면 약 7.5 ms 에 끝남. 20 ms 넘으면 bug 로 보고 멈춤 (wait 가 안 끝나는 경우 대비)
    initial begin
        #40_000_000;
        $display("TIMEOUT (40 ms) - TOTAL MISMATCH = %0d + timeout", err);
        $finish;
    end

    initial begin
        clk = 0; rst = 1; err = 0;
        btnR = 0; btnL = 0; btnU = 0; btnD = 0;
        sw_mode = 0; sw_display_mode = 0; sw_set = 0; sw_12h = 0; sw_timer = 0; sw_alt = 0;
        #100 rst = 0;
        #100;

        // T1 리셋 직후: 시계 12:00:00:00, LED = 시계 + 초.1/100초
        if ({wt_hour, wt_min, wt_sec} !== {5'd12, 6'd0, 6'd0}) begin err = err + 1; $display("T1 FAIL time %0d:%0d:%0d", wt_hour, wt_min, wt_sec); end
        if (led !== 16'h0009) begin err = err + 1; $display("T1 FAIL led %b", led); end
        if (cursor !== 2'd3 || set_mode !== 1'b0) begin err = err + 1; $display("T1 FAIL cursor %0d set %b", cursor, set_mode); end

        // T2 normal(sw_set = 0) 에서 U 는 무시
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (wt_hour !== 5'd12) begin err = err + 1; $display("T2 FAIL hour %0d", wt_hour); end

        // T3 설정 들어가면 시 칸부터, U +1, D -1
        sw_set = 1; #100;
        if (cursor !== 2'd2 || set_mode !== 1'b1) begin err = err + 1; $display("T3 FAIL cursor %0d set %b", cursor, set_mode); end
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (wt_hour !== 5'd13) begin err = err + 1; $display("T3 FAIL U hour %0d", wt_hour); end
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if (wt_hour !== 5'd11) begin err = err + 1; $display("T3 FAIL D hour %0d", wt_hour); end

        // T4 커서 이동: R 시->분->초->시(돌아감), L 시->초(돌아감)->분
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (cursor !== 2'd1) begin err = err + 1; $display("T4 FAIL R1 cursor %0d", cursor); end
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (cursor !== 2'd0) begin err = err + 1; $display("T4 FAIL R2 cursor %0d", cursor); end
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (cursor !== 2'd2) begin err = err + 1; $display("T4 FAIL R3 wrap cursor %0d", cursor); end
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        if (cursor !== 2'd0) begin err = err + 1; $display("T4 FAIL L1 wrap cursor %0d", cursor); end
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        if (cursor !== 2'd1) begin err = err + 1; $display("T4 FAIL L2 cursor %0d", cursor); end

        // T5 분 칸 0 에서 D -> 59, 시는 그대로 (내림 없음)
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if (wt_min !== 6'd59 || wt_hour !== 5'd11) begin err = err + 1; $display("T5 FAIL %0d:%0d", wt_hour, wt_min); end
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (wt_min !== 6'd0 || wt_hour !== 5'd11) begin err = err + 1; $display("T5 FAIL up wrap %0d:%0d", wt_hour, wt_min); end

        // T6 sw_set = 0 -> NORMAL, 버튼 무시, 다시 들어가면 시 칸부터
        sw_set = 0; #100;
        if (cursor !== 2'd3 || set_mode !== 1'b0) begin err = err + 1; $display("T6 FAIL cursor %0d set %b", cursor, set_mode); end
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if (wt_hour !== 5'd11 || wt_min !== 6'd0) begin err = err + 1; $display("T6 FAIL %0d:%0d", wt_hour, wt_min); end

        // T7 게이팅: 시계 모드에서 R 은 스톱워치를 안 돌림
        sw_set = 1; #100;   // 시계 쪽 SET_HOUR
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (sw_run !== 1'b0) begin err = err + 1; $display("T7 FAIL stopwatch ran in watch mode"); end
        if (cursor !== 2'd1) begin err = err + 1; $display("T7 FAIL watch R cursor %0d", cursor); end
        //    스톱워치 모드: R 은 스톱워치 RUN, 시계 커서는 안 움직임, LED 바뀜
        sw_mode = 1; sw_display_mode = 1; #100;
        if (led !== 16'h0006) begin err = err + 1; $display("T7 FAIL led %b", led); end
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (sw_run !== 1'b1) begin err = err + 1; $display("T7 FAIL stopwatch not running"); end
        if (cursor !== 2'd1) begin err = err + 1; $display("T7 FAIL watch cursor moved %0d", cursor); end
        btnU = 1; #PUSH; btnU = 0; #PUSH;    // 스톱워치 RUN 중 U 는 무시, 시계 분도 안 바뀜
        if (wt_min !== 6'd0) begin err = err + 1; $display("T7 FAIL watch min changed %0d", wt_min); end
        //    스톱워치 화면에서는 점멸 꺼짐
        if (dut.U_FND_CNTL.blink_en !== 1'b0) begin err = err + 1; $display("T7 FAIL blink_en in stopwatch"); end
        btnR = 1; #PUSH; btnR = 0; #PUSH;    // 스톱워치 STOP
        sw_mode = 0; #100;

        // T8 점멸: 분 칸 설정 중, msec >= 50 이면 분 두 자리 끔, < 50 이면 켬. 다른 칸은 안 끔
        for (i = 0; i < 300; i = i + 1) begin
            #337;
            if (dut.U_FND_CNTL.w_blank_min !== (wt_msec >= 50)) begin err = err + 1; $display("T8 FAIL blank_min msec %0d", wt_msec); end
            if (dut.U_FND_CNTL.w_blank_hour !== 1'b0 || dut.U_FND_CNTL.w_blank_sec !== 1'b0) begin err = err + 1; $display("T8 FAIL other blank"); end
        end

        // T9 23:59 로 맞추고 자정 넘어감 확인: 23:59:59.99 -> 00:00:00.00
        btnL = 1; #PUSH; btnL = 0; #PUSH;    // 시 칸
        for (i = 0; i < 12; i = i + 1) begin
            btnU = 1; #PUSH; btnU = 0; #PUSH;   // 11 -> 23
        end
        btnR = 1; #PUSH; btnR = 0; #PUSH;    // 분 칸
        btnD = 1; #PUSH; btnD = 0; #PUSH;    // 0 -> 59
        if (wt_hour !== 5'd23 || wt_min !== 6'd59) begin err = err + 1; $display("T9 FAIL set %0d:%0d", wt_hour, wt_min); end
        sw_set = 0;
        wait (wt_hour == 5'd0);
        if ({wt_min, wt_sec, wt_msec} !== {6'd0, 6'd0, 7'd0}) begin err = err + 1; $display("T9 FAIL midnight %0d:%0d:%0d.%0d", wt_hour, wt_min, wt_sec, wt_msec); end
        else $display("T9 midnight 00:00:00.00 at %0t ps (1 \"초\" = 100 us 로 줄인 시뮬)", $time);

        // T10 12/24 시간 표시 (sw_12h): 내부는 24시간 그대로, 화면 값(w_hour)과 PM LED 만 바뀜
        //     지금 시계 00시 -> 24h 화면 0, 12h 화면 12(오전)
        #100;   // wait 직후 같은 시각에는 조합회로(w_hour)가 아직 안 바뀌어 있으므로 잠깐 기다림
        if (dut.w_hour !== 5'd0) begin err = err + 1; $display("T10 FAIL 24h 0 -> %0d", dut.w_hour); end
        sw_12h = 1; #100;
        if (dut.w_hour !== 5'd12 || led[4] !== 1'b0) begin err = err + 1; $display("T10 FAIL 12h 0 -> %0d pm %b", dut.w_hour, led[4]); end
        //     시 칸을 U 로 12시(정오) -> 화면 12, PM
        sw_set = 1; #100;
        for (i = 0; i < 12; i = i + 1) begin
            btnU = 1; #PUSH; btnU = 0; #PUSH;
        end
        if (wt_hour !== 5'd12 || dut.w_hour !== 5'd12 || led[4] !== 1'b1) begin err = err + 1; $display("T10 FAIL 12h 12 -> %0d pm %b", dut.w_hour, led[4]); end
        //     13시 -> 화면 1, PM / 23시 -> 화면 11, PM
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (wt_hour !== 5'd13 || dut.w_hour !== 5'd1 || led[4] !== 1'b1) begin err = err + 1; $display("T10 FAIL 12h 13 -> %0d pm %b", dut.w_hour, led[4]); end
        for (i = 0; i < 10; i = i + 1) begin
            btnU = 1; #PUSH; btnU = 0; #PUSH;
        end
        if (wt_hour !== 5'd23 || dut.w_hour !== 5'd11 || led[4] !== 1'b1) begin err = err + 1; $display("T10 FAIL 12h 23 -> %0d pm %b", dut.w_hour, led[4]); end
        //     11시 -> 화면 11, 오전
        for (i = 0; i < 12; i = i + 1) begin
            btnD = 1; #PUSH; btnD = 0; #PUSH;
        end
        if (wt_hour !== 5'd11 || dut.w_hour !== 5'd11 || led[4] !== 1'b0) begin err = err + 1; $display("T10 FAIL 12h 11 -> %0d pm %b", dut.w_hour, led[4]); end
        //     24h 로 되돌리면 23시 그대로 23
        btnU = 1; #PUSH; btnU = 0; #PUSH;    // 12
        btnU = 1; #PUSH; btnU = 0; #PUSH;    // 13
        sw_12h = 0; #100;
        if (dut.w_hour !== 5'd13 || led[4] !== 1'b0) begin err = err + 1; $display("T10 FAIL 24h 13 -> %0d pm %b", dut.w_hour, led[4]); end
        //     스톱워치 화면은 12h 영향 없음, PM LED 꺼짐
        sw_12h = 1; sw_mode = 1; #100;
        if (dut.w_hour !== dut.w_sw_hour || led[4] !== 1'b0) begin err = err + 1; $display("T10 FAIL stopwatch hour %0d pm %b", dut.w_hour, led[4]); end
        sw_mode = 0; sw_set = 0;

        // T11 타이머 (sw_timer): 더하기 · 12시간 상한 · 시작 · 취소 · 0 까지 줄어듦 · 알람 · 끄기
        sw_12h = 0; sw_display_mode = 0; sw_timer = 1; #100;
        if (led !== 16'h0028) begin err = err + 1; $display("T11 FAIL led %h", led); end
        if (dut.w_hour !== 5'd0 || dut.w_min !== 6'd0) begin err = err + 1; $display("T11 FAIL display not timer"); end
        //     0 에서 L → 시작 안 함
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        if (dut.w_tm_run !== 1'b0) begin err = err + 1; $display("T11 FAIL started at zero"); end
        //     U +1 → 0:01, R +10 → 0:11, (alt) U +4 → 0:15, (alt) R +30 → 0:45, D +60 → 1:45
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (dut.w_tm_hour !== 5'd0 || dut.w_tm_min !== 6'd1) begin err = err + 1; $display("T11 FAIL +1 %0d:%0d", dut.w_tm_hour, dut.w_tm_min); end
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (dut.w_tm_min !== 6'd11) begin err = err + 1; $display("T11 FAIL +10 %0d", dut.w_tm_min); end
        sw_alt = 1;
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (dut.w_tm_min !== 6'd15) begin err = err + 1; $display("T11 FAIL +4 %0d", dut.w_tm_min); end
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (dut.w_tm_min !== 6'd45) begin err = err + 1; $display("T11 FAIL +30 %0d", dut.w_tm_min); end
        sw_alt = 0;
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if (dut.w_tm_hour !== 5'd1 || dut.w_tm_min !== 6'd45) begin err = err + 1; $display("T11 FAIL +60 %0d:%0d", dut.w_tm_hour, dut.w_tm_min); end
        //     분 넘김: 1:45 + 30 → 2:15
        sw_alt = 1; btnR = 1; #PUSH; btnR = 0; #PUSH; sw_alt = 0;
        if (dut.w_tm_hour !== 5'd2 || dut.w_tm_min !== 6'd15) begin err = err + 1; $display("T11 FAIL carry %0d:%0d", dut.w_tm_hour, dut.w_tm_min); end
        //     D 를 10번 → 12:15 는 넘으므로 12:00:00.00 에서 멈춤
        for (i = 0; i < 10; i = i + 1) begin
            btnD = 1; #PUSH; btnD = 0; #PUSH;
        end
        if ({dut.w_tm_hour, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {5'd12, 6'd0, 6'd0, 7'd0}) begin err = err + 1; $display("T11 FAIL cap %0d:%0d:%0d", dut.w_tm_hour, dut.w_tm_min, dut.w_tm_sec); end
        //     시작 → 조금 뒤 11:59:59.xx → 취소 → 0
        btnL = 1; #PUSH; btnL = 0; #PUSH; #PUSH;
        if (dut.w_tm_run !== 1'b1 || dut.w_tm_hour !== 5'd11 || dut.w_tm_min !== 6'd59) begin err = err + 1; $display("T11 FAIL run %b %0d:%0d", dut.w_tm_run, dut.w_tm_hour, dut.w_tm_min); end
        if (led[6] !== 1'b1) begin err = err + 1; $display("T11 FAIL led6 run"); end
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        if (dut.w_tm_run !== 1'b0 || dut.w_tm_zero !== 1'b1) begin err = err + 1; $display("T11 FAIL cancel"); end
        //     +1 분 → 시작 → 시계 화면으로 가도 계속 줄어듦 → 정확히 60 "초" 뒤 알람
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        btnL = 1;
        @(posedge dut.w_tm_run); t_run = $time;
        #PUSH; btnL = 0; #PUSH;
        sw_timer = 0; #100;
        btnU = 1; #PUSH; btnU = 0; #PUSH;   // 시계 normal 이라 무시, 타이머에도 안 감
        if (dut.w_tm_run !== 1'b1) begin err = err + 1; $display("T11 FAIL timer stopped in watch view"); end
        @(posedge dut.w_tm_alarm); t_alarm = $time;
        if ((t_alarm - t_run) < 64'd6_000_000 || (t_alarm - t_run) > 64'd6_000_100) begin err = err + 1; $display("T11 FAIL 1 min = %0d ns (expect 6,000,000 + a few clk)", t_alarm - t_run); end
        else $display("T11 timer 1 min (scaled) = %0d ns", t_alarm - t_run);
        //     알람: 시계 화면에 있어도 16개 LED 가 0.5 "초" 마다 같이 점멸
        for (i = 0; i < 300; i = i + 1) begin
            #337;
            if (led !== ((dut.w_blink) ? 16'hffff : 16'h0000)) begin err = err + 1; $display("T11 FAIL alarm led %h", led); end
        end
        //     시계 화면 버튼으로는 안 꺼짐
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (dut.w_tm_alarm !== 1'b1) begin err = err + 1; $display("T11 FAIL alarm off by watch button"); end
        //     타이머 화면에서 아무 버튼(D) → 끄기, 시간은 그대로 0 (D 로 60분이 더해지지 않음)
        sw_timer = 1; #100;
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if (dut.w_tm_alarm !== 1'b0 || dut.w_tm_zero !== 1'b1 || led !== 16'h0028) begin err = err + 1; $display("T11 FAIL alarm off %b %b %h", dut.w_tm_alarm, dut.w_tm_zero, led); end
        sw_timer = 0;

        if (err == 0) $display("TOTAL MISMATCH = 0  (PASS)");
        else $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
