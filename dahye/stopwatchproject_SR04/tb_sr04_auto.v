`timescale 1ns / 1ps
// =============================================================================
//  tb_sr04_auto : [11] 자동 / 수동 측정 모드 검증
//   - btnU 를 누르고 있는 동안 -> 60ms 마다 자동 측정, 값 매번 갱신
//   - btnU 를 떼면 -> 진행 중 측정만 끝나고 자동 측정 멈춤
//   - 수동 모드에서 btnR -> 누를 때마다 1회 측정
//
//  DUT : top_sr04  /  실행 : Run All (약 0.5s)
//  파형 추천 : btnU, btnR, auto_en, sr04_start, trig, echo, state, busy, done, distance_x10
// =============================================================================
module tb_sr04_auto ();

    reg        clk, rst, btnR, btnU, echo;
    wire       trig;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;
    wire [9:0] led;

    wire        done         = dut.w_done;
    wire        busy         = dut.w_busy;
    wire [11:0] distance_x10 = dut.w_distance_x10;
    wire [2:0]  state        = dut.w_state;
    wire        auto_en      = dut.w_auto_en;
    wire        sr04_start   = dut.w_sr04_start;

    top_sr04 dut (
        .clk      (clk),
        .rst      (rst),
        .btnR     (btnR),
        .btnU     (btnU),
        .sw_led   (1'b0),
        .echo     (echo),
        .trig     (trig),
        .fnd_com  (fnd_com),
        .fnd_font (fnd_font),
        .led      (led)
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

    // (task 인자는 끝날 때 복사되므로 버튼별로 task 를 따로 둠)
    task press_btnR;
        begin
            @(negedge clk); btnR = 1'b1; #(30_000); btnR = 1'b0; #(1_000);
        end
    endtask

    task press_btnU;
        begin
            @(negedge clk); btnU = 1'b1; #(30_000); btnU = 1'b0; #(1_000);
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

    initial begin
        echo_list[0] =  600; exp_x10[0] =  103;   // 10.3cm
        echo_list[1] = 1160; exp_x10[1] =  200;   // 20.0cm
        echo_list[2] = 2900; exp_x10[2] =  500;   // 50.0cm
        echo_list[3] = 5800; exp_x10[3] = 1000;   // 100.0cm
        echo_list[4] = 3480; exp_x10[4] =  600;   // 60.0cm (수동 측정)
        for (i = 5; i < 8; i = i + 1) begin echo_list[i] = 600; exp_x10[i] = 103; end

        clk = 0; rst = 1; btnR = 0; btnU = 0; echo = 0;
        #100;
        rst = 0;
        #1000;

        // ---------------- btnU 누르고 있기 -> 자동 측정 ----------------
        $display("\n===== [11] Hold btnU -> auto measure =====");
        @(negedge clk); btnU = 1'b1;              // 누르기 시작 (계속 누름)
        wait (auto_en == 1'b1);                   // 2-FF 동기화 후 (약 20ns) 자동 모드
        $display("auto_en ON after %0d ns", $time - 1100);
        check(11, auto_en == 1, auto_en, 1);

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

        // ---------------- btnU 떼기 -> 자동 측정 멈춤 ----------------
        $display("\n===== [11] Release btnU -> auto OFF =====");
        cnt_before = trig_cnt;                    // 4 (4번째 측정 STOP 중)
        @(negedge clk); btnU = 1'b0;              // 손 뗌
        wait (auto_en == 1'b0);                   // 동기화 후 바로 해제
        check(11, auto_en == 0, auto_en, 0);
        wait (!busy);
        #(100_000_000);                           // 100ms 동안 추가 측정 없어야 함
        $display("after release : trig +%0d in 100ms", trig_cnt - cnt_before);
        check(11, trig_cnt == cnt_before, trig_cnt - cnt_before, 0);

        // ---------------- 수동 모드 버튼 -> 1회 측정 ----------------
        $display("\n===== [11] btnR in manual mode -> 1 measurement =====");
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

        #1000;
        $display("\n==================================================");
        $display("  RESULT : PASS %0d / FAIL %0d", pass_cnt, fail_cnt);
        $display("==================================================");
        $finish;
    end

endmodule
