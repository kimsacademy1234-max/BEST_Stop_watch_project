`timescale 1ns / 1ps
// =============================================================================
//  tb_sr04_status_led : [12] 상태 구분 / 오류 복귀, [13] 거리 LED 표시
//   [12] status 00 OK / 01 NO_ECHO / 10 OUT_RANGE / 11 ECHO_STUCK
//        echo 고착(계속 1) -> 강제 IDLE 복귀, 센서 정상화 후 다시 정상 측정
//   [13] 정상값 없음 -> 막대 OFF
//        거리별 막대 개수 (LD0 부터), 10cm 이하 8개 점멸, 히스테리시스 10 / 12cm
//        LD8 = 측정 중(START/WAIT/DIST) 만 ON, LD9 = 마지막 측정 실패
//        스위치 OFF -> 막대만 OFF (LD8 / LD9 / 측정은 계속)
//
//  ※ 점멸 주기는 시뮬레이션 단축을 위해 250ms -> 10us 로 바꿔서 확인 (defparam)
//  DUT : top_sr04  /  실행 : Run All (약 1.1s)
//  파형 추천 : trig, echo, state, status, done, distance_x10, led[9:0], sw_led
// =============================================================================
module tb_sr04_status_led ();

    reg        clk, rst, btnR, echo, sw_led;
    wire       trig;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;
    wire [9:0] led;

    wire        done         = dut.w_done;
    wire        busy         = dut.w_busy;
    wire [11:0] distance_x10 = dut.w_distance_x10;
    wire [1:0]  status       = dut.w_status;
    wire [2:0]  state        = dut.w_state;
    wire [7:0]  led_bar      = led[7:0];
    wire        led_meas     = led[8];
    wire        led_err      = led[9];
    wire        fnd_dash     = (fnd_font == 8'b1011_1111);   // "-" 패턴

    top_sr04 dut (
        .clk      (clk),
        .rst      (rst),
        .btnR     (btnR),
        .btnU     (1'b0),
        .sw_led   (sw_led),
        .echo     (echo),
        .trig     (trig),
        .fnd_com  (fnd_com),
        .fnd_font (fnd_font),
        .led      (led)
    );

    defparam dut.U_LED.BLINK_HALF_CYC = 1000;   // 10us (시뮬레이션용)

    always #5 clk = ~clk;   // 100MHz

    integer pass_cnt = 0;
    integer fail_cnt = 0;

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

    task press_btnR;
        begin
            @(negedge clk); btnR = 1'b1; #(30_000); btnR = 1'b0;
        end
    endtask

    // echo_us : 0 = 무응답 / 그 외 echo 폭
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
                press_btnR;
                drive_echo(echo_us);
                @(posedge done);
            join
            @(negedge clk);
            #(100);                                   // LED 레지스터 갱신 후 확인
        end
    endtask

    // 막대 개수 -> 패턴 (LD0 부터)
    function [7:0] bar_pat(input integer n);
        bar_pat = (n == 0) ? 8'h00 : (8'hFF >> (8 - n));
    endfunction

    task check_bar(input integer echo_us, input integer n);
        begin
            measure(echo_us);
            $display("echo %0d us -> %0d.%0d cm, bar=%b (expect %0d LEDs)",
                     echo_us, distance_x10 / 10, distance_x10 % 10, led_bar, n);
            check(13, led_bar == bar_pat(n) && !led_err, led_bar, bar_pat(n));
            wait (!busy);
        end
    endtask

    reg     b0, b1;

    initial begin
        clk = 0; rst = 1; btnR = 0; echo = 0; sw_led = 1'b1;
        #100;
        rst = 0;
        #1000;

        // ===================== [13] 정상값 없음 =====================
        $display("\n===== [13] No valid value yet -> bar OFF =====");
        check(13, led_bar == 8'h00 && !led_err && !led_meas, led, 0);

        // ===================== [12] status OK + LD8 =====================
        $display("\n===== [12] status OK / LD8 measuring =====");
        fork
            press_btnR;
            drive_echo(1160);                         // 20.0cm
            begin
                wait (echo == 1'b1); #(100_000);
                $display("during DIST : state=%0d LD8=%0d", state, led_meas);
                check(12, state == 3 && led_meas == 1, led_meas, 1);
            end
            @(posedge done);
        join
        @(negedge clk); #(100);
        check(12, status == 2'b00, status, 0);
        #(1_000_000);
        $display("in STOP : state=%0d busy=%0d LD8=%0d", state, busy, led_meas);
        check(12, state == 4 && busy && led_meas == 0, led_meas, 0);   // 재측정 대기는 측정 중 아님
        check(13, led_bar == bar_pat(7), led_bar, bar_pat(7));        // 20.0cm -> 7개
        wait (!busy);

        // ===================== [12] NO_ECHO =====================
        $display("\n===== [12] NO_ECHO -> status 01, bar OFF, LD9 ON =====");
        measure(0);
        check(12, status == 2'b01, status, 1);
        check(12, led_bar == 8'h00 && led_err, led[9:0], 10'h200);
        $display("NO_ECHO : FND = %b (dash=%0d)", fnd_font, fnd_dash);
        check(12, fnd_dash, fnd_dash, 1);                 // FND "----"
        wait (!busy);

        // 다음 정상 측정 -> LD9 OFF
        $display("\n===== [12] next OK -> LD9 OFF =====");
        check_bar(2030, 5);                           // 35.0cm -> 5개
        check(12, status == 2'b00 && !led_err, led_err, 0);
        check(12, !fnd_dash, fnd_dash, 0);                // 정상 -> 숫자 복귀

        // ===================== [12] OUT_RANGE =====================
        $display("\n===== [12] OUT_RANGE (no object, echo 36ms) -> status 10 =====");
        measure(36_000);
        check(12, status == 2'b10, status, 2);
        check(12, distance_x10 == 4000 && led_err && led_bar == 0, led_err, 1);
        check(12, fnd_dash, fnd_dash, 1);                 // OUT_RANGE 도 "----"
        wait (!busy);

        // ===================== [12] ECHO_STUCK + recovery =====================
        $display("\n===== [12] ECHO_STUCK -> forced IDLE, then recovery =====");
        fork
            press_btnR;
            begin @(negedge trig); #(200_000); echo = 1'b1; end   // echo 계속 1 (고착)
        join
        @(posedge done); @(negedge clk);
        $display("1st done : status=%0d (OUT_RANGE)", status);
        check(12, status == 2'b10, status, 2);
        @(posedge done); @(negedge clk);
        $display("2nd done : status=%0d state=%0d echo=%0d (stuck)", status, state, echo);
        check(12, status == 2'b11, status, 3);
        #(100);
        check(12, state == 0 && !busy && echo == 1, state, 0);     // echo 가 1 인데도 IDLE 복귀
        check(12, led_err == 1, led_err, 1);
        #(1_000);
        echo = 1'b0;                                  // 센서 정상화
        #(1_000_000);
        check_bar(870, 7);                            // 15.0cm -> 정상 복귀
        check(12, status == 2'b00, status, 0);

        // ===================== [13] bar table =====================
        $display("\n===== [13] bar level table =====");
        check_bar(1450, 6);                           // 25.0cm
        check_bar(2900, 4);                           // 50.0cm
        check_bar(4060, 3);                           // 70.0cm
        check_bar(5220, 2);                           // 90.0cm
        check_bar(8700, 1);                           // 150.0cm
        check_bar(1160, 7);                           // 20.0cm 경계 (이하 -> 7)
        check_bar(2320, 5);                           // 40.0cm 경계 (이하 -> 5)

        // ===================== [13] warning + hysteresis =====================
        $display("\n===== [13] warning blink + hysteresis 10 / 12cm =====");
        measure(464);                                 // 8.0cm -> 경고
        $display("8.0cm : warn=%0d", dut.U_LED.warn_reg);
        check(13, dut.U_LED.warn_reg == 1, dut.U_LED.warn_reg, 1);
        b0 = (led_bar == 8'hFF) || (led_bar == 8'h00);
        @(posedge dut.U_LED.blink_reg or negedge dut.U_LED.blink_reg); #(100);
        b1 = (led_bar == 8'hFF) || (led_bar == 8'h00);
        check(13, b0 && b1, led_bar, 8'hFF);          // 8개가 한꺼번에 ON/OFF
        wait (!busy);

        measure(638);                                 // 11.0cm -> 경고 유지
        $display("11.0cm : warn=%0d", dut.U_LED.warn_reg);
        check(13, dut.U_LED.warn_reg == 1, dut.U_LED.warn_reg, 1);
        wait (!busy);

        measure(754);                                 // 13.0cm -> 경고 해제, 7개
        $display("13.0cm : warn=%0d bar=%b", dut.U_LED.warn_reg, led_bar);
        check(13, dut.U_LED.warn_reg == 0 && led_bar == bar_pat(7), led_bar, bar_pat(7));
        wait (!busy);

        measure(638);                                 // 11.0cm (멀리서 접근) -> 경고 아님, 7개
        $display("11.0cm from far : warn=%0d bar=%b", dut.U_LED.warn_reg, led_bar);
        check(13, dut.U_LED.warn_reg == 0 && led_bar == bar_pat(7), led_bar, bar_pat(7));
        wait (!busy);

        // ===================== [13] switch OFF =====================
        $display("\n===== [13] switch OFF -> bar OFF only =====");
        sw_led = 1'b0;
        #(1_000);
        check(13, led_bar == 8'h00, led_bar, 0);
        measure(0);                                   // 스위치 OFF 여도 측정 / LD9 동작
        check(13, led_bar == 8'h00 && led_err == 1, led_err, 1);
        wait (!busy);
        check_bar_off_on;

        #1000;
        $display("\n==================================================");
        $display("  RESULT : PASS %0d / FAIL %0d", pass_cnt, fail_cnt);
        $display("==================================================");
        $finish;
    end

    // 스위치 OFF 상태에서 정상 측정 -> 막대는 안 보이지만 내부 값은 갱신, ON 하면 바로 보임
    task check_bar_off_on;
        begin
            measure(2900);                            // 50.0cm
            check(13, led_bar == 8'h00 && led_err == 0, led_bar, 0);
            sw_led = 1'b1;
            #(1_000);
            $display("switch ON again : bar=%b", led_bar);
            check(13, led_bar == bar_pat(4), led_bar, bar_pat(4));
            wait (!busy);
        end
    endtask

endmodule
