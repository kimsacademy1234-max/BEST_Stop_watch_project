`timescale 1ns / 1ps
// F1. 10 초 타이머 — P1 · 3 개   (tb_scenario.md 4 장 F1)
// /mod t_hm → pulse_phy(U) (+10 초) → FND "00.10" 확인 → pulse_phy(L) = t0 (시작)
// → o_tm_alarm 1 이 되는 시각 = t0 + 10.000 s (± 5 clk), 그때 타이머 진행 표시 (LED6 원천 w_tm_run) 0
// → 알람 중 1.2 s 동안 1 ms 마다 LED 16 개 = {16{시계 1/100 >= 50}} 인지, 0.5 s 마다 바뀌는지
module tb_F1;
    `include "tb_env.svh"
    string s;
    bit    ok;

    localparam longint T_TIMER   = 10 * SEC;      // 설정한 타이머 길이 (U 1 번 = +10 초)
    localparam longint TOL_LOGIC = 5 * CLK_NS;    // 3-2 장 : 순수 로직 지연 ± 5 clk
    localparam longint T_OBS     = 1200 * MS;     // 알람 점멸 관찰 길이
    localparam longint T_SAMPLE  = 1 * MS;        // 점멸 샘플 간격
    localparam longint T_HALF    = 500 * MS;      // 점멸 반 주기 (시계 1/100 50 칸)

    time    t0, t_alarm;
    longint d;
    int     n_bad, n_on, n_off, n_edge;
    bit     prev, cur;
    time    t_edge[$];
    string  bad_msg;

    initial begin
        env_start("tb_F1", 14 * SEC);

        uart_send_str("/mod t_hm");
        #(1 * MS);

        pulse_phy("U");                     // +10 초
        fnd_get(s);
        check("F1-01", s == "00.10",
              $sformatf("U 뒤 FND 기대 \"00.10\" / 실제 \"%s\" (disp_sel=%0d, sel_tm=%0d)", s, dut.w_disp_sel, dut.w_sel_tm));

        pulse_phy("L");                     // 시작
        t0 = t_btn_L;                       // w_btn_L 이 1 로 샘플된 posedge
        wait_clk(2);
        info("F1-t0", $sformatf("시작 t0 = %0d ns, w_tm_run=%0d, cnt_btn_L=%0d", t0, dut.w_tm_run, cnt_btn_L));

        @(posedge dut.w_tm_alarm);
        t_alarm = $time;
        d = longint'(t_alarm) - longint'(t0) - T_TIMER;
        #1;
        check("F1-02", (d >= -TOL_LOGIC) && (d <= TOL_LOGIC) && (dut.w_tm_alarm == 1'b1) && (dut.w_tm_run == 1'b0),
              $sformatf("알람 진입 기대 t0 + 10.000 s ± %0d ns, alarm 1, run(LED6 원천) 0 / 실제 t0 + %0d ns (오차 %0d ns), alarm %0d, run %0d, led=%h",
                        TOL_LOGIC, t_alarm - t0, d, dut.w_tm_alarm, dut.w_tm_run, led));

        // 알람 점멸 : 1 ms 마다 LED 와 시계 1/100 비교
        n_bad = 0; n_on = 0; n_off = 0; n_edge = 0; bad_msg = "";
        prev = (led == 16'hFFFF);
        repeat (T_OBS / T_SAMPLE) begin
            #(T_SAMPLE);
            cur = (dut.w_wt_msec >= 50);
            if (led !== {16{cur}} || dut.w_tm_alarm !== 1'b1) begin
                n_bad++;
                if (bad_msg.len() == 0)
                    bad_msg = $sformatf(" 첫 불일치 @ %s led=%h wt_msec=%0d alarm=%0d", t_ms(), led, dut.w_wt_msec, dut.w_tm_alarm);
            end
            if (led == 16'hFFFF) n_on++;
            if (led == 16'h0000) n_off++;
            if ((led == 16'hFFFF) != prev) begin
                n_edge++;
                t_edge.push_back($time);
            end
            prev = (led == 16'hFFFF);
        end
        ok = (n_bad == 0) && (n_on > 0) && (n_off > 0) && (t_edge.size() >= 2);
        for (int i = 1; i < t_edge.size(); i++) begin
            d = longint'(t_edge[i]) - longint'(t_edge[i-1]);
            if (d < T_HALF - T_SAMPLE || d > T_HALF + T_SAMPLE) ok = 0;
        end
        check("F1-03", ok,
              $sformatf("알람 LED 기대 16 개 = {시계 1/100 >= 50}, 0.5 s 마다 바뀜 / 실제 %0d 샘플 중 불일치 %0d, 켜짐 %0d · 꺼짐 %0d, 바뀜 %0d 번 (간격 %s)%s",
                        T_OBS / T_SAMPLE, n_bad, n_on, n_off, n_edge,
                        (t_edge.size() >= 2) ? $sformatf("%0d ms", (t_edge[1] - t_edge[0]) / MS) : "-", bad_msg));

        env_finish();
    end
endmodule
