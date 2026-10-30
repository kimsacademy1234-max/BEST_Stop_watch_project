`timescale 1ns / 1ps
// =============================================================================
//  tb_sr04_corner : 추가 코너 케이스 검증
//   [6]  측정 중 리셋     : DIST 도중 rst -> 즉시 IDLE, trig 0, distance 0, 이후 정상 복귀
//   [7]  버튼 길게 누름   : 150ms 계속 누름 -> 측정 1회만 (디바운서 엣지 검출)
//   [8]  1cm / 0.1cm 경계 : 57us -> 0cm(0.9) / 58us -> 1cm(1.0) / 5us -> 0.0 / 6us -> 0.1
//   [9]  echo 노이즈      : (a) 틱 사이 50ns 글리치 -> 무시
//                           (b) 틱 순간 50ns 글리치 -> 오측정 0 (알려진 한계, INFO)
//   [10] 측정 주기        : 연속 측정 trig 간격 >= 60ms
//
//  DUT : top_sr04  /  실행 : Run All (약 0.75s)
//  파형 추천 : btnR, sr04_start, trig, echo, state, busy, done, distance, distance_x10
// =============================================================================
module tb_sr04_corner ();

    reg        clk, rst, btnR, echo;
    wire       trig;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;

    wire        done         = dut.w_done;
    wire        busy         = dut.w_busy;
    wire [8:0]  distance     = dut.w_distance;
    wire [11:0] distance_x10 = dut.w_distance_x10;
    wire [2:0]  state        = dut.w_state;
    wire        sr04_start   = dut.w_sr04_start;
    wire        us_tick      = dut.U_SR04.w_us_tick;

    top_sr04 dut (
        .clk      (clk),
        .rst      (rst),
        .btnR     (btnR),
        .btnU     (1'b0),          // 자동 명령 없음 (수동 모드)
        .sw_led   (1'b0),
        .led      (),
        .echo     (echo),
        .trig     (trig),
        .fnd_com  (fnd_com),
        .fnd_font (fnd_font)
    );

    always #5 clk = ~clk;   // 100MHz

    integer pass_cnt = 0;
    integer fail_cnt = 0;
    integer trig_cnt = 0;
    time    t_trig_rise, t_prev_rise;

    always @(posedge trig) begin
        trig_cnt    = trig_cnt + 1;
        t_prev_rise = t_trig_rise;
        t_trig_rise = $time;
    end

    // ------------------------------------------------------------------ tasks
    task press_btnR(input integer press_ns);
        begin
            @(negedge clk);
            btnR = 1'b1;
            #(press_ns);
            btnR = 1'b0;
        end
    endtask

    task drive_echo(input integer echo_us);
        begin
            @(negedge trig);
            #(200_000);
            if (echo_us > 0) begin
                echo = 1'b1;
                #(echo_us * 1000);
                echo = 1'b0;
            end
        end
    endtask

    task measure(input integer echo_us);
        begin
            fork
                press_btnR(30_000);
                drive_echo(echo_us);
                @(posedge done);
            join
            @(negedge clk);
        end
    endtask

    task check(input integer no, input cond, input integer got, input integer exp);
        begin
            if (cond) begin
                pass_cnt = pass_cnt + 1;
                $display("[%0t] [%0d] PASS  got=%0d  expect=%0d", $time, no, got, exp);
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("[%0t] [%0d] FAIL  got=%0d  expect=%0d", $time, no, got, exp);
            end
        end
    endtask

    // ------------------------------------------------------------------ test
    integer t1, interval_us;

    initial begin
        clk = 0; rst = 1; btnR = 0; echo = 0;
        t_trig_rise = 0; t_prev_rise = 0;
        #100;
        rst = 0;
        #100;

        // ===================== [6] reset during measurement =====================
        $display("\n===== [6] Reset during measurement =====");
        fork
            press_btnR(30_000);
            begin
                @(negedge trig);
                #(200_000);
                echo = 1'b1;                       // echo 들어오는 중 (DIST)
            end
        join
        #(1_000_000);                              // DIST 1ms 진행
        $display("before reset : state=%0d busy=%0d", state, busy);
        check(6, state == 3, state, 3);            // DIST 확인
        rst = 1'b1;
        #(1);                                      // 비동기 리셋 -> 즉시 반영
        $display("in reset     : state=%0d trig=%0d busy=%0d distance=%0d", state, trig, busy, distance);
        check(6, state == 0, state, 0);
        check(6, trig == 0, trig, 0);
        check(6, busy == 0, busy, 0);
        check(6, distance == 0 && distance_x10 == 0, distance, 0);
        #(1_000);
        echo = 1'b0;
        rst  = 1'b0;
        #(1_000);
        measure(600);                              // 복귀 후 정상 측정
        $display("after reset measure : distance=%0d x10=%0d", distance, distance_x10);
        check(6, distance == 10 && distance_x10 == 103, distance_x10, 103);
        wait (!busy);

        // ===================== [7] long button press =====================
        $display("\n===== [7] Long press 150ms -> 1 measurement =====");
        trig_cnt = 0;
        fork
            press_btnR(150_000_000);               // 150ms 누르고 있음 (주기 60ms 보다 김)
            drive_echo(1160);
        join
        wait (!busy);
        $display("trig count during 150ms press = %0d", trig_cnt);
        check(7, trig_cnt == 1, trig_cnt, 1);
        check(7, distance == 20, distance, 20);
        #(1_000_000);                              // 손 떼고 1ms 후 다음 시험 (같은 순간 다시 누르면 엣지가 안 생김)

        // ===================== [8] 1cm / 0.1cm boundary =====================
        $display("\n===== [8] Boundary : 57us / 58us / 5us / 6us =====");
        measure(57);
        $display("57us -> %0d cm, x10=%0d", distance, distance_x10);
        check(8, distance == 0 && distance_x10 == 9, distance_x10, 9);
        wait (!busy);
        measure(58);
        $display("58us -> %0d cm, x10=%0d", distance, distance_x10);
        check(8, distance == 1 && distance_x10 == 10, distance_x10, 10);
        wait (!busy);
        measure(5);
        $display(" 5us -> %0d cm, x10=%0d", distance, distance_x10);
        check(8, distance_x10 == 0, distance_x10, 0);
        wait (!busy);
        measure(6);
        $display(" 6us -> %0d cm, x10=%0d", distance, distance_x10);
        check(8, distance_x10 == 1, distance_x10, 1);
        wait (!busy);

        // ===================== [9] echo glitch =====================
        $display("\n===== [9] Echo glitch 50ns during WAIT =====");
        // (a) 틱과 틱 사이 글리치 -> 무시되어야 함
        fork
            press_btnR(30_000);
            begin
                @(negedge trig);
                #(50_000);
                @(posedge us_tick); #(300);        // 틱 직후 300ns -> 다음 틱까지 멀리 떨어짐
                echo = 1'b1; #(50); echo = 1'b0;   // 50ns 글리치
                #(150_000);
                echo = 1'b1; #(600_000); echo = 1'b0;  // 진짜 echo 600us
            end
            @(posedge done);
        join
        @(negedge clk);
        $display("(a) glitch between ticks -> distance=%0d x10=%0d", distance, distance_x10);
        check(9, distance == 10 && distance_x10 == 103, distance_x10, 103);
        wait (!busy);

        // (b) 틱 순간 글리치 -> FSM 이 echo=1 로 판단 -> 다음 틱 echo=0 -> 0cm 로 종료 (알려진 한계)
        fork
            press_btnR(30_000);
            begin
                @(negedge trig);
                #(50_000);
                @(posedge us_tick); #(1000 - 40);  // 다음 틱 40ns 전
                echo = 1'b1; #(50); echo = 1'b0;   // 동기화 2clk 후 틱과 겹침
                #(150_000);
                echo = 1'b1; #(600_000); echo = 1'b0;  // 진짜 echo (STOP 중이라 무시됨)
            end
            @(posedge done);
        join
        @(negedge clk);
        $display("(b) glitch on tick -> distance=%0d x10=%0d  [INFO] known limit",
                 distance, distance_x10);
        if (distance == 0) $display("[9] INFO  false measure 0 as expected (fix: deglitch filter)");
        else               $display("[9] INFO  no false measure this time (distance=%0d)", distance);
        wait (!busy);

        // ===================== [10] measurement period =====================
        $display("\n===== [10] Measurement period >= 60ms =====");
        measure(600);
        t1 = t_trig_rise;
        wait (!busy);                               // busy 풀리자마자 바로 다음 측정
        measure(600);
        interval_us = (t_trig_rise - t1) / 1000;
        $display("trig to trig interval = %0d us", interval_us);
        check(10, interval_us >= 60_000 && interval_us < 60_100, interval_us, 60_000);
        wait (!busy);

        #1000;
        $display("\n==================================================");
        $display("  RESULT : PASS %0d / FAIL %0d   ([9]b is INFO only)", pass_cnt, fail_cnt);
        $display("==================================================");
        $finish;
    end

endmodule
