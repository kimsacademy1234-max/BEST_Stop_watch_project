`timescale 1ns / 1ps
// F6. 다른 화면에서 알람 — P1 · 3 개   (tb_scenario.md 4 장 F6)
// /mod t_hm → U (+10 초) → L (시작) → /mod dist → 알람 대기
// → 거리 화면에서 LED 16 개 점멸 확인 → /btn R (거리 화면 : SR04 1 회 측정, 알람 그대로)
// → /mod t_hm → /btn U → 알람 꺼짐 (SET, 00.00 — U 가 +10 초로 안 들어감)
module tb_F6;
    `include "tb_env.svh"
    string s;
    bit    ok;

    localparam longint T_OBS    = 1200 * MS;   // 점멸 관찰 (0.5 s 반 주기 두 번 이상)
    localparam longint T_SAMPLE = 1 * MS;
    localparam longint T_SETTLE = 1 * MS;      // UART 명령 마지막 바이트 뒤 반영 대기 (rx_done 뒤 < 1 us 이면 충분)
    localparam longint T_SR04   = 40 * MS;     // SR04 1 회 측정 (trig 10 us + 지연 0.5 ms + echo 0.58 ms) 여유

    int     n_bad, n_on, n_off, trig0;
    string  bad_msg;
    bit     cur;

    initial begin
        env_start("tb_F6", 14 * SEC);

        uart_send_str("/mod t_hm");
        #(T_SETTLE);
        pulse_phy("U");                       // +10 초
        wait_clk(2);
        pulse_phy("L");                       // 시작
        wait_clk(2);
        info("F6-run", $sformatf("타이머 시작 run=%0d (t_btn_L=%0d ns)", dut.w_tm_run, t_btn_L));

        uart_send_str("/mod dist");
        #(T_SETTLE);
        info("F6-dist", $sformatf("거리 화면 disp_sel=%0d", dut.w_disp_sel));

        @(posedge dut.w_tm_alarm);
        info("F6-alarm", $sformatf("알람 진입 (t_btn_L 뒤 %0d ns), disp_sel=%0d", $time - t_btn_L, dut.w_disp_sel));

        // 1. 거리 화면에서 LED 16 개 점멸
        n_bad = 0; n_on = 0; n_off = 0; bad_msg = "";
        repeat (T_OBS / T_SAMPLE) begin
            #(T_SAMPLE);
            cur = (dut.w_wt_msec >= 50);
            if (led !== {16{cur}} || dut.w_disp_sel !== 2'd1) begin
                n_bad++;
                if (bad_msg.len() == 0)
                    bad_msg = $sformatf(" 첫 불일치 @ %s led=%h wt_msec=%0d disp_sel=%0d", t_ms(), led, dut.w_wt_msec, dut.w_disp_sel);
            end
            if (led == 16'hFFFF) n_on++;
            if (led == 16'h0000) n_off++;
        end
        check("F6-01", (n_bad == 0) && (n_on > 0) && (n_off > 0),
              $sformatf("거리 화면 알람 LED 기대 16 개 = {시계 1/100 >= 50} (켜짐 · 꺼짐 둘 다) / 실제 %0d 샘플 중 불일치 %0d, 켜짐 %0d, 꺼짐 %0d%s",
                        T_OBS / T_SAMPLE, n_bad, n_on, n_off, bad_msg));

        // 2. 거리 화면 /btn R → SR04 만 측정, 알람 그대로
        trig0 = sr04_trig_cnt;
        uart_send_str("/btn R");
        #(T_SR04);
        check("F6-02", (dut.w_tm_alarm == 1'b1) && (sr04_trig_cnt == trig0 + 1),
              $sformatf("거리 화면 /btn R 기대 알람 1 유지 · trig +1 / 실제 alarm=%0d, trig %0d → %0d, cnt_btn_R=%0d",
                        dut.w_tm_alarm, trig0, sr04_trig_cnt, cnt_btn_R));

        // 3. 타이머 화면 복귀 → /btn U → 알람 꺼짐, SET, 00.00
        uart_send_str("/mod t_hm");
        #(T_SETTLE);
        uart_send_str("/btn U");
        #(T_SETTLE);
        fnd_get(s);
        check("F6-03", (dut.w_tm_alarm == 1'b0) && (dut.w_tm_run == 1'b0) && (s == "00.00") && (led[5] == 1'b1),
              $sformatf("타이머 화면 /btn U 기대 alarm 0 · run 0 · FND \"00.00\" · LED5 1 / 실제 alarm=%0d run=%0d FND \"%s\" led=%h",
                        dut.w_tm_alarm, dut.w_tm_run, s, led));

        env_finish();
    end
endmodule
