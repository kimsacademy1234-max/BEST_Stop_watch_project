`timescale 1ns / 1ps
// sr04_controller 단위 TB (상태 Idle · Start · Wait · Dist · Stop, tick enable · clear)
//  TB 가 HC-SR04 역할 : trig 가 내려가고 300 us 뒤 echo 를 거리만큼 High
//  (1) trig 폭 11 us 이상 (11.1 us 미만)   (2) 10 · 100 · 400 cm → distance 오차 ±1   (3) done 1 클럭
//  (4) 측정 중 start 다시 → 무시 (trig 1 번)   (5) (선택) echo 안 옴 → timeout 뒤 distance 0
//  (6) echo 36 ms (물체 없음) → distance 0   (7) Stop 중 start 무시
//  (8) 매 trig 마다 : echo 가 0 이고, 앞 echo 가 끝난 뒤 10 ms 이상 지났는지
module tb_sr2_ctrl ();
    reg clk, rst, start, echo;
    wire w_tick, w_tick_en, w_tick_clr, trig, done, busy;
    wire [8:0] dist;
    integer err, cnt_trig, cnt_done, echo_us;
    reg echo_en, fall_seen;
    time t_rise, w_trig, t_fall;

    tick_gen_1us #(.F_COUNT(100)) U_TICK (
        .clk     (clk),
        .rst     (rst),
        .i_enable(w_tick_en),
        .i_clear (w_tick_clr),
        .o_tick  (w_tick)
    );

    // 시뮬 시간을 줄이려고 TIMEOUT 만 짧게 (Stop 10 ms 는 실제 값)
    sr04_controller #(
        .TRIG_US   (11),
        .CM_US     (58),
        .MAX_CM    (400),
        .STOP_US   (10000),
        .TIMEOUT_US(5000)
    ) dut (
        .clk       (clk),
        .rst       (rst),
        .i_start   (start),
        .i_us_tick (w_tick),
        .i_echo    (echo),
        .o_tick_en (w_tick_en),
        .o_tick_clr(w_tick_clr),
        .o_trig    (trig),
        .o_distance(dist),
        .o_done    (done),
        .o_busy    (busy)
    );

    always #5 clk = ~clk;

    // trig 폭 재기 · 개수 세기 · (8) 재측정 간격 검사
    always @(posedge trig) begin
        t_rise = $time; cnt_trig = cnt_trig + 1;
        if (echo === 1'b1) begin err = err + 1; $display("%t (8) MISMATCH echo 가 아직 1 인데 trig", $time); end
        else if (fall_seen && ($time - t_fall < 10_000_000)) begin
            err = err + 1; $display("%t (8) MISMATCH echo 끝난 뒤 %0d ns 만에 trig (expect 10 ms 이상)", $time, $time - t_fall);
        end
    end
    always @(negedge trig) w_trig = $time - t_rise;
    always @(negedge echo) if ($time > 0) begin t_fall = $time; fall_seen = 1; end   // 0 ns 의 x → 0 은 제외
    always @(posedge clk) if (done === 1'b1) cnt_done = cnt_done + 1;

    // HC-SR04 흉내 : trig 가 내려가고 300 us 뒤 echo 를 echo_us 동안 High (클럭과 안 맞게 +3 ns)
    always @(negedge trig) begin
        if (echo_en) begin
            #(300_000 + 3);
            echo = 1'b1;
            #(echo_us * 1000);
            echo = 1'b0;
        end
    end

    task press_start;
        begin
            @(negedge clk); start = 1'b1;
            @(negedge clk); start = 1'b0;
        end
    endtask

    task measure(input integer cm);
        begin
            echo_en = 1; echo_us = cm * 58;
            cnt_done = 0;
            press_start;
            @(posedge done); @(negedge clk);
            if (w_trig < 11000 || w_trig >= 11100) begin err = err + 1; $display("%t (1) MISMATCH trig 폭 %0d ns", $time, w_trig); end
            if (dist < cm - 1 || dist > cm + 1) begin err = err + 1; $display("%t (2) MISMATCH %0d cm → distance %0d", $time, cm, dist); end
            else $display("%t (2) %0d cm (echo %0d us) → distance %0d, trig %0d ns", $time, cm, echo_us, dist, w_trig);
            @(negedge clk);
            if (cnt_done !== 1) begin err = err + 1; $display("%t (3) MISMATCH done %0d 클럭", $time, cnt_done); end
            wait (busy == 1'b0); #2000;
        end
    endtask

    initial begin
        clk = 0; rst = 1; start = 0; echo = 0; echo_en = 1; echo_us = 0; fall_seen = 0;
        err = 0; cnt_trig = 0; cnt_done = 0; t_rise = 0; w_trig = 0; t_fall = 0;
        #20 rst = 0;
        #3000;

        measure(10);
        measure(100);
        measure(400);

        // (4) 측정 중 start 다시 → 무시
        cnt_trig = 0; echo_en = 1; echo_us = 50 * 58;
        press_start;
        #1_000_000;                 // 1 ms 뒤 (echo 세는 중)
        press_start;
        @(posedge done); wait (busy == 1'b0); #2000;
        if (cnt_trig !== 1) begin err = err + 1; $display("%t (4) MISMATCH 측정 중 start 로 trig %0d 번", $time, cnt_trig); end
        else $display("%t (4) 측정 중 start 무시 (trig %0d 번), distance %0d", $time, cnt_trig, dist);

        // (5) (선택) echo 안 옴 → timeout
        echo_en = 0;
        press_start;
        @(posedge done); @(negedge clk);
        if (dist !== 0) begin err = err + 1; $display("%t (5) MISMATCH echo 없음 → distance %0d (expect 0)", $time, dist); end
        else $display("%t (5) echo 없음 → timeout, distance 0", $time);
        wait (busy == 1'b0); #2000;

        // (6) echo 36 ms (물체 없음) → 범위 밖. busy 가 내려가자마자 다시 start → (8) 이 간격 검사
        echo_en = 1; echo_us = 36000;
        press_start;
        @(posedge done); @(negedge clk);
        if (dist !== 0) begin err = err + 1; $display("%t (6) MISMATCH echo 36 ms → distance %0d (expect 0)", $time, dist); end
        else $display("%t (6) echo 36 ms → 범위 밖, distance 0", $time);
        wait (busy == 1'b0);
        echo_us = 30 * 58;
        press_start;                // 바로 다음 측정
        @(posedge done); @(negedge clk);
        $display("%t (8) 범위 밖 직후 측정 : echo 끝 → 다음 trig 간격 검사 통과 시 MISMATCH 없음, distance %0d", $time, dist);
        wait (busy == 1'b0); #2000;

        // (7) Stop 중 start 무시
        echo_us = 20 * 58; cnt_trig = 0;
        press_start;
        @(posedge done);
        #100_000;                   // Stop (10 ms) 안
        press_start;
        wait (busy == 1'b0); #2000;
        if (cnt_trig !== 1) begin err = err + 1; $display("%t (7) MISMATCH Stop 중 start 로 trig %0d 번", $time, cnt_trig); end
        else $display("%t (7) Stop 중 start 무시", $time);
        measure(20);

        $display("TOTAL MISMATCH = %0d", err);
        $stop;
    end
endmodule
