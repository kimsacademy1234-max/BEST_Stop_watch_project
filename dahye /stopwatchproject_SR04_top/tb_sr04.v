`timescale 1ns / 1ps
// =============================================================================
//  tb_sr04 : top_sr04 (btnR -> debounce -> SR04 -> FND) 검증
//   - btnR 을 실제 버튼처럼 30us 누름 (debounce 1MHz x 8샘플 = 8us 이상 필요)
//   - HC-SR04 동작은 task(sr04_model)로 모델링
//       1) trig 펄스 폭 >= 10us 감시
//       2) burst 시간(200us) 뒤 echo 를 echo_us 동안 high 로 drive
//       3) done 시점의 distance 를 기대값과 비교
// =============================================================================
module tb_sr04 ();

    reg        clk, rst, btnR, echo;
    wire       trig;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;

    // 내부 신호 관찰 (계층 참조)
    wire       done     = dut.w_done;
    wire       busy     = dut.w_busy;
    wire [8:0] distance = dut.w_distance;
    wire [11:0] distance_x10 = dut.w_distance_x10;   // 0.1cm 단위

    integer pass_cnt = 0;
    integer fail_cnt = 0;
    integer trig_cnt = 0;
    time    last_trig_rise = 0;

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

    always @(posedge trig) trig_cnt = trig_cnt + 1;

    // ---------------- 버튼 누름 (30us) ----------------
    task press_btnR;
        begin
            @(negedge clk);
            btnR = 1'b1;
            #(30_000);
            btnR = 1'b0;
        end
    endtask

    // ---------------- HC-SR04 모델 ----------------
    // echo_us = 0 이면 응답 없음(센서 미연결)
    task sr04_model(input integer echo_us, input integer expect_cm);
        time t_rise, t_fall;
        integer expect_x10, fnd_val;
        begin
            // 기대 0.1cm 값 = floor(echo*10/58), 최대 4000, 무응답 0
            expect_x10 = (echo_us == 0) ? 0 : (echo_us * 10) / 58;
            if (expect_x10 > 4000) expect_x10 = 4000;
            @(posedge trig); t_rise = $time;
            if (last_trig_rise != 0)
                $display("[%0t] trigger interval = %0d us", $time, (t_rise - last_trig_rise) / 1000);
            last_trig_rise = t_rise;

            @(negedge trig); t_fall = $time;
            if ((t_fall - t_rise) >= 10_000)
                $display("[%0t] trig width = %0d ns (>=10us OK)", $time, t_fall - t_rise);
            else begin
                $display("[%0t] FAIL trig width = %0d ns (<10us)", $time, t_fall - t_rise);
                fail_cnt = fail_cnt + 1;
            end

            fork
                begin : DRIVE_ECHO
                    #(200_000);                 // 40kHz * 8cycle burst = 200us
                    if (echo_us > 0) begin
                        echo = 1'b1;
                        #(echo_us * 1000);
                        echo = 1'b0;
                    end
                end
                begin : CHECK
                    @(posedge done);
                    @(negedge clk);
                    fnd_val = dut.U_FND_CNTL.w_ds10_high*1000 + dut.U_FND_CNTL.w_ds1_high*100
                            + dut.U_FND_CNTL.w_ds10_low*10 + dut.U_FND_CNTL.w_ds1_low;
                    if (distance == expect_cm && distance_x10 == expect_x10 && fnd_val == expect_x10) begin
                        $display("[%0t] PASS echo=%0d us -> distance=%0d cm, x10=%0d (expect %0d / %0d), FND=%0d%0d%0d.%0d",
                                 $time, echo_us, distance, distance_x10, expect_cm, expect_x10,
                                 dut.U_FND_CNTL.w_ds10_high, dut.U_FND_CNTL.w_ds1_high, dut.U_FND_CNTL.w_ds10_low, dut.U_FND_CNTL.w_ds1_low);
                        pass_cnt = pass_cnt + 1;
                    end else begin
                        $display("[%0t] FAIL echo=%0d us -> distance=%0d cm, x10=%0d, FND=%0d (expect %0d / %0d)",
                                 $time, echo_us, distance, distance_x10, fnd_val, expect_cm, expect_x10);
                        fail_cnt = fail_cnt + 1;
                    end
                end
            join

            wait (!busy);                       // STOP 끝날 때까지 (주기 60ms)
        end
    endtask

    task measure(input integer echo_us, input integer expect_cm);
        begin
            fork
                press_btnR;
                sr04_model(echo_us, expect_cm);
            join
        end
    endtask

    initial begin
        clk = 0; rst = 1; btnR = 0; echo = 0;
        #100;
        rst = 0;
        #100;

        measure(600,     10);   // 10cm  (600/58 = 10.3)
        measure(116,      2);   // 최소 2cm
        measure(3_000,   51);   // 51cm  (3000/58 = 51.7, 소수점 버림)
        measure(5_800,  100);   // 100cm
        measure(23_142, 399);   // 399cm
        measure(36_000, 400);   // 물체 없음 (echo 36ms) -> 400
        measure(0,        0);   // 응답 없음 -> timeout, 0

        // 측정 중 버튼 재입력은 무시되어야 함 (trig 1번만 나가야 함)
        trig_cnt = 0;
        fork
            press_btnR;
            sr04_model(1_160, 20);
            begin #(150_000); press_btnR; end   // 측정 중 재요청
        join
        if (trig_cnt == 1) begin
            $display("PASS re-press during busy ignored (trig %0d time)", trig_cnt);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL re-press during busy -> trig %0d times", trig_cnt);
            fail_cnt = fail_cnt + 1;
        end

        #(1000);
        $display("==== RESULT : PASS %0d / FAIL %0d ====", pass_cnt, fail_cnt);
        $finish;
    end

endmodule
