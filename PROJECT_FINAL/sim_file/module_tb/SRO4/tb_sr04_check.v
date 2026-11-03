`timescale 1ns / 1ps
// =============================================================================
//  tb_sr04_check : SR04 기능 검증 5항목
//   [1] 정상 거리      : echo 5,800us -> distance 100cm 저장
//   [2] Trigger 폭     : 약 11us HIGH (10us 이상 ~ 12us 이하)
//   [3] 반복 측정      : 다른 거리 입력 시 새 값으로 갱신
//   [4] Echo 무응답    : 대기 제한시간(30ms) 후 distance 0, done 발생
//   [5] 결과 유지/완료 : 측정 후 값 유지, done 은 1클록(10ns) 펄스
//
//  (merge) DUT top_sr04 -> sr04_top, 버튼은 1클록 tick (디바운서는 상위 Top)
//  DUT : sr04_top (i_btn_R tick -> sr04_mode_ctrl -> sr04_core)
//  파형 추천 : btnR, trig, echo, state, busy, done, distance(Unsigned Decimal)
//  실행 : Run All (약 110ms, $finish 에서 자동 정지)
// =============================================================================
module tb_sr04_check ();

    reg         clk, rst, btnR, echo;
    wire        trig;
    wire        done, err, auto_en;
    wire [8:0]  distance;
    wire [11:0] distance_x10;
    wire [1:0]  status;
    wire [9:0]  led;

    // 내부 신호 (파형 / 체크용)
    wire       busy  = dut.w_busy;
    wire [2:0] state = dut.w_state;   // 0 IDLE 1 START 2 WAIT 3 DIST 4 STOP

    sr04_top dut (
        .i_clk         (clk),
        .i_rst         (rst),
        .i_btn_R       (btnR),
        .i_btn_U       (1'b0),             // 자동 측정 사용 안 함 (수동 모드)
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

    // -------------------------------------------------------------------------
    //  모니터 : trig 폭 / done 폭 / done 횟수 (시뮬레이션 내내 감시)
    // -------------------------------------------------------------------------
    time    t_trig_rise, trig_width;
    time    t_done_rise;
    integer done_cnt       = 0;
    integer done_width_err = 0;

    always @(posedge trig) t_trig_rise = $time;
    always @(negedge trig) trig_width  = $time - t_trig_rise;

    always @(posedge done) begin
        t_done_rise = $time;
        done_cnt    = done_cnt + 1;
    end
    always @(negedge done) begin
        if (($time - t_done_rise) != 10) begin   // 1클록 = 10ns
            done_width_err = done_width_err + 1;
            $display("[%0t] done width error : %0d ns", $time, $time - t_done_rise);
        end
    end

    // -------------------------------------------------------------------------
    //  Tasks
    // -------------------------------------------------------------------------
    task press_btnR;                 // 버튼 R : 1클록 tick
        begin
            @(negedge clk); btnR = 1'b1;
            @(negedge clk); btnR = 1'b0;
        end
    endtask

    task drive_echo(input integer echo_us);   // 센서 모델 (0 이면 무응답)
        begin
            @(negedge trig);
            #(200_000);                          // 40kHz x 8cycle burst
            if (echo_us > 0) begin
                echo = 1'b1;
                #(echo_us * 1000);
                echo = 1'b0;
            end
        end
    endtask

    // 버튼 누르고 -> echo 응답 -> done 올 때까지 대기
    task measure(input integer echo_us);
        begin
            fork
                press_btnR;
                drive_echo(echo_us);
                @(posedge done);
            join
            @(negedge clk);              // done 직후 값 샘플
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

    // -------------------------------------------------------------------------
    //  Test sequence
    // -------------------------------------------------------------------------
    integer done_before;
    integer prev_dist;
    time    t_trig_fall, t_wait;

    initial begin
        clk = 0; rst = 1; btnR = 0; echo = 0;
        #100;
        rst = 0;
        #100;

        // ---------------- [1] 정상 거리 ----------------
        $display("\n===== [1] Normal distance : echo 5,800us -> 100cm =====");
        done_before = done_cnt;
        measure(5_800);
        check(1, distance == 100, distance, 100);
        check(1, done_cnt == done_before + 1, done_cnt - done_before, 1);   // done 1회

        // ---------------- [2] Trigger 폭 ----------------
        $display("\n===== [2] Trigger width : ~11us =====");
        $display("trig width = %0d ns", trig_width);
        check(2, (trig_width >= 10_000) && (trig_width <= 12_000), trig_width, 11_000);
        wait (!busy);

        // ---------------- [3] 반복 측정 ----------------
        $display("\n===== [3] Repeat measure : 20cm -> 50cm =====");
        measure(1_160);                                   // 20cm
        check(3, distance == 20, distance, 20);
        prev_dist = distance;
        wait (!busy);

        fork
            measure(2_900);                               // 50cm
            begin                                         // 측정 중에는 이전 값 유지?
                wait (echo == 1'b1);
                #(1_000_000);                             // echo 중간쯤
                $display("distance during measure = %0d (must hold prev %0d)", distance, prev_dist);
                check(3, distance == prev_dist, distance, prev_dist);
            end
        join
        check(3, distance == 50, distance, 50);
        check(3, distance != prev_dist, distance, 50);    // 새 값으로 갱신
        wait (!busy);

        // ---------------- [4] Echo 무응답 ----------------
        $display("\n===== [4] No echo : timeout -> 0, done =====");
        done_before = done_cnt;
        fork
            measure(0);
            begin
                @(negedge trig);
                t_trig_fall = $time;
            end
        join
        t_wait = $time - t_trig_fall;
        $display("trig fall -> done = %0d us", t_wait / 1000);
        check(4, distance == 0, distance, 0);
        check(4, done_cnt == done_before + 1, done_cnt - done_before, 1);
        check(4, (t_wait >= 29_000_000) && (t_wait <= 31_000_000), t_wait / 1000, 30_000);
        wait (!busy);

        // ---------------- [5] 결과 유지 / 완료 신호 ----------------
        $display("\n===== [5] Hold result / done 1 clk =====");
        measure(3_480);                                   // 60cm
        check(5, distance == 60, distance, 60);
        done_before = done_cnt;
        wait (!busy);                                     // STOP 끝
        #(5_000_000);                                     // IDLE 에서 5ms 더 대기
        $display("after IDLE 5ms : distance = %0d, state = %0d", distance, state);
        check(5, distance == 60, distance, 60);                          // 값 유지
        check(5, done_cnt == done_before, done_cnt - done_before, 0);    // done 추가 발생 없음
        check(5, done_width_err == 0, done_width_err, 0);                // 모든 done = 10ns

        // ---------------- 결과 ----------------
        #1000;
        $display("\n==================================================");
        $display("  RESULT : PASS %0d / FAIL %0d   (done total %0d)", pass_cnt, fail_cnt, done_cnt);
        $display("==================================================");
        $finish;
    end

endmodule
