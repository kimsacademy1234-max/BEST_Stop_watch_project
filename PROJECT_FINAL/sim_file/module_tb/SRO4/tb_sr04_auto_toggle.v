`timescale 1ns / 1ps
// =============================================================================
//  tb_sr04_auto_toggle : [11] 자동 / 수동 측정 모드 검증  (tb_sr04_auto_hold 대체)
//   (merge) 버튼 U 동작 변경 : 누르고 있는 동안 자동 -> 누를 때마다 자동 켜기 / 끄기 (토글)
//           버튼은 상위 Top 공용 디바운서를 거친 1클록 tick 으로 들어옴
//   [11-1] btnU tick 1회 -> 자동 측정 ON, 60ms 마다 자동 측정, 값 매번 갱신
//   [11-2] btnU tick 1회 더 -> 자동 OFF, 진행 중 측정만 끝나고 멈춤
//   [11-3] 수동 모드에서 btnR -> 누를 때마다 1회 측정
//   [11-4] 자동 모드 중 btnR -> 자동 모드 유지, 추가 trig 없음 (측정 중이라 무시)
//          (이전 버전 : 자동 모드 중 btnR 은 자동 해제였음)
//
//  DUT : sr04_top  /  실행 : Run All (약 0.6s)
//  파형 추천 : btnU, btnR, auto_en, sr04_start, trig, echo, state, busy, done, distance_x10
// =============================================================================
module tb_sr04_auto_toggle ();
    reg         clk, rst, btnR, btnU, echo;
    wire        trig;
    wire        done, err, auto_en;
    wire [8:0]  distance;
    wire [11:0] distance_x10;
    wire [1:0]  status;
    wire [9:0]  led;

    wire        busy       = dut.w_busy;
    wire [2:0]  state      = dut.w_state;
    wire        sr04_start = dut.w_start;

    sr04_top dut (
        .i_clk         (clk),
        .i_rst         (rst),
        .i_btn_R       (btnR),
        .i_btn_U       (btnU),
        .i_led_sw      (1'b0),
        .i_echo        (echo),
        .o_trig        (trig),
        .o_distance    (distance),
        .o_distance_x10(distance_x10),
        .o_err         (err),
        .o_status      (status),
        .o_auto_en     (auto_en),
        .o_done        (done),
        .o_led         (led)
    );

    always #5 clk = ~clk;   // 100MHz

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    // ---------------- 센서 모델 : trig 마다 목록 순서대로 echo 응답 ----------------
    integer echo_list [0:7];
    integer exp_x10   [0:7];
    integer trig_cnt = 0;
    time    t_rise [0:7];

    always @(posedge trig) begin
        if (trig_cnt < 8) t_rise[trig_cnt] = $time;
        trig_cnt = trig_cnt + 1;
    end

    always @(negedge trig) begin
        #(200_000);
        echo = 1'b1;
        #(echo_list[(trig_cnt - 1) % 8] * 1000);
        echo = 1'b0;
    end

    // 버튼 : 1클록 tick (task 인자는 끝날 때 복사되므로 버튼별로 task 를 따로 둠)
    task press_btnR;
        begin
            @(negedge clk); btnR = 1'b1;
            @(negedge clk); btnR = 1'b0;
        end
    endtask

    task press_btnU;
        begin
            @(negedge clk); btnU = 1'b1;
            @(negedge clk); btnU = 1'b0;
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

    integer i, interval_us, cnt_before;

    // Vivado 에서 옛 사본(import 된 파일)과 구분하기 위한 버전 표시
    initial $display("TB_VERSION: AUTO_TOGGLE_20261031_V1");
    // 감시 타이머 : auto_en / done / busy 변화가 안 오면 무한 대기하지 않도록
    initial begin
        #1_000_000_000;
        $display("FAIL: watchdog at 1s; auto_en=%b state=%0d trig_cnt=%0d PASS=%0d FAIL=%0d",
                 auto_en, state, trig_cnt, pass_cnt, fail_cnt);
        $fatal(1, "Automatic measurement test did not finish");
    end

    initial begin
        echo_list[0] =  600; exp_x10[0] =  103;   // 10.3cm
        echo_list[1] = 1160; exp_x10[1] =  200;   // 20.0cm
        echo_list[2] = 2900; exp_x10[2] =  500;   // 50.0cm
        echo_list[3] = 5800; exp_x10[3] = 1000;   // 100.0cm
        echo_list[4] = 3480; exp_x10[4] =  600;   // 60.0cm (수동 측정)
        echo_list[5] = 1450; exp_x10[5] =  250;   // 25.0cm ([11-4] 자동)
        echo_list[6] = 2030; exp_x10[6] =  350;   // 35.0cm ([11-4] 자동)
        echo_list[7] =  600; exp_x10[7] =  103;

        clk = 0; rst = 1; btnR = 0; btnU = 0; echo = 0;
        #100;
        rst = 0;
        #1000;

        // ---------------- [11-1] btnU 1회 -> 자동 측정 ON ----------------
        $display("\n===== [11-1] btnU tick -> auto ON =====");
        check(11, auto_en == 0, auto_en, 0);      // 리셋 후 수동 모드
        press_btnU;
        check(11, auto_en == 1, auto_en, 1);      // 동기화기 없음 -> tick 다음 클록에 바로 1
        #(1_000);
        check(11, auto_en == 1, auto_en, 1);      // tick 1번 = 토글 1번 (다시 꺼지지 않음)

        for (i = 0; i < 4; i = i + 1) begin
            @(posedge done);
            @(negedge clk);
            $display("auto #%0d : echo=%0d us -> x10=%0d (%0d.%0d cm)",
                     i + 1, echo_list[i], distance_x10, distance_x10 / 10, distance_x10 % 10);
            check(11, distance_x10 == exp_x10[i], distance_x10, exp_x10[i]);
        end
        for (i = 1; i < 4; i = i + 1) begin
            interval_us = (t_rise[i] - t_rise[i-1]) / 1000;
            $display("interval #%0d -> #%0d = %0d us", i, i + 1, interval_us);
            check(11, interval_us >= 60_000 && interval_us < 60_100, interval_us, 60_000);
        end

        // ---------------- [11-2] btnU 1회 더 -> 자동 OFF ----------------
        $display("\n===== [11-2] btnU tick again -> auto OFF =====");
        cnt_before = trig_cnt;                    // 4 (4번째 측정 STOP 중)
        press_btnU;
        check(11, auto_en == 0, auto_en, 0);
        wait (!busy);                             // 진행 중 측정(STOP)은 끝까지
        #(100_000_000);                           // 100ms 동안 추가 측정 없어야 함
        $display("after auto OFF : trig +%0d in 100ms", trig_cnt - cnt_before);
        check(11, trig_cnt == cnt_before, trig_cnt - cnt_before, 0);

        // ---------------- [11-3] 수동 모드 btnR -> 1회 측정 ----------------
        $display("\n===== [11-3] btnR in manual mode -> 1 measurement =====");
        cnt_before = trig_cnt;
        fork
            press_btnR;
            @(posedge done);
        join
        @(negedge clk);
        $display("manual : x10=%0d", distance_x10);
        check(11, distance_x10 == exp_x10[4], distance_x10, exp_x10[4]);
        wait (!busy);
        #(10_000_000);
        check(11, trig_cnt == cnt_before + 1, trig_cnt - cnt_before, 1);

        // ---------------- [11-4] 자동 모드 중 btnR -> 자동 유지 ----------------
        $display("\n===== [11-4] btnR during auto -> auto stays ON, no extra trig =====");
        cnt_before = trig_cnt;                    // 5
        press_btnU;                               // 자동 다시 ON
        check(11, auto_en == 1, auto_en, 1);
        @(posedge done); @(negedge clk);          // 자동 #1 (25.0cm)
        check(11, distance_x10 == exp_x10[5], distance_x10, exp_x10[5]);
        press_btnR;                               // STOP 중 btnR -> 무시되어야 함
        $display("after btnR in auto : auto_en=%0d state=%0d", auto_en, state);
        check(11, auto_en == 1, auto_en, 1);      // 자동 모드 안 꺼짐 (이전 버전과 다름)
        @(posedge done); @(negedge clk);          // 자동 #2 (35.0cm)
        check(11, distance_x10 == exp_x10[6], distance_x10, exp_x10[6]);
        interval_us = (t_rise[6] - t_rise[5]) / 1000;
        $display("auto interval with btnR in between = %0d us", interval_us);
        check(11, interval_us >= 60_000 && interval_us < 60_100, interval_us, 60_000);   // btnR 로 앞당겨지지 않음
        check(11, trig_cnt == cnt_before + 2, trig_cnt - cnt_before, 2);
        press_btnU;                               // 자동 OFF
        wait (!busy);
        check(11, auto_en == 0, auto_en, 0);

        #1000;
        $display("\n==================================================");
        $display("  RESULT : PASS %0d / FAIL %0d", pass_cnt, fail_cnt);
        $display("==================================================");
        if (fail_cnt != 0) $fatal(1, "Test checks failed");
        $finish;
    end

endmodule
