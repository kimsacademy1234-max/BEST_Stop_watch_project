`timescale 1ns / 1ps
// D6. 랩 — P1 · 3 개   (tb_scenario.md 4 장 D6)
// 스톱워치 초.1/100 화면 : R (RUN, t0) → t0 + 0.305 s 에 D (랩, tick 경계와 겹치지 않게 +5 ms) → 1 s 동안 FND 고정 · LED7 1, 내부 카운터 계속 증가
// → t0 + 1.305 s 에 D → FND = 현재 카운터 값 (01.30 근처), LED7 0
module tb_D6;
    `include "tb_env.svh"
    string s, s_a, s_b;

    localparam longint T_LAP1 = 300 * MS;
    localparam longint T_LAP2 = 1300 * MS;
    localparam longint T_SAMPLE = 100 * MS;   // 랩 중 FND 를 이 간격으로 다시 읽음
    localparam int     CS_PER_S = 100;
    localparam longint T_OFS  = 5 * MS;     // tick 경계 (t0 + k x 10 ms + 1 clk) 와 D 가 같은 clk 에 겹치지 않게 5 ms 비킴

    time t0;
    int  n_diff, cnt_a, cnt_b, cnt_now, shown;
    bit  led7_all;
    string sb;

    // 내부 카운터 (랩 컨트롤러 입력) 를 1/100 초 단위 정수로
    function automatic int sw_cnt_cs();
        return int'(dut.U_WTS.U_STOPWATCH_DATAPATH.U_LAP_CONTROLLER.i_cnt_sec) * CS_PER_S
             + int'(dut.U_WTS.U_STOPWATCH_DATAPATH.U_LAP_CONTROLLER.i_cnt_msec);
    endfunction

    initial begin
        env_start("tb_D6", 2 * SEC);
        set_sw(7'b000_0001);
        wait_clk(2);

        pulse_phy("R");
        t0 = t_btn_R;
        #(longint'(t0) + T_LAP1 + T_OFS - longint'($time));
        pulse_phy("D");
        wait_clk(2);
        cnt_a = sw_cnt_cs();
        fnd_get(s_a);

        // 1 s 동안 FND · LED7 관찰
        n_diff = 0; led7_all = 1; sb = "";
        while ($time < longint'(t0) + T_LAP2 - 5 * MS) begin
            fnd_get(s);
            if (s != s_a) begin n_diff++; if (sb.len() == 0) sb = $sformatf(" (첫 다름 @ %s \"%s\")", t_ms(), s); end
            if (led[7] !== 1'b1) led7_all = 0;
            #(T_SAMPLE);
        end
        cnt_b = sw_cnt_cs();
        check("D6-01", (n_diff == 0) && led7_all && (s_a == "00.30") && (led == 16'h008A),
              $sformatf("랩 중 기대 FND \"00.30\" 고정 · LED7 1 (led 008a) / 실제 첫 FND \"%s\", 바뀐 횟수 %0d%s, LED7 내내 %0d, led=%h",
                        s_a, n_diff, sb, led7_all, led));
        check("D6-02", (cnt_b - cnt_a) >= 95,
              $sformatf("랩 중 내부 카운터 기대 계속 증가 (약 +100) / 실제 %0d → %0d (+%0d, 1/100 초)", cnt_a, cnt_b, cnt_b - cnt_a));

        #(longint'(t0) + T_LAP2 + T_OFS - longint'($time));
        pulse_phy("D");
        fnd_get(s);
        cnt_now = sw_cnt_cs();
        shown = (s.substr(0,0).atoi() * 10 + s.substr(1,1).atoi()) * CS_PER_S + s.substr(3,4).atoi();
        check("D6-03", (led[7] == 1'b0) && (dut.w_sw_lap == 1'b0) && (shown >= cnt_now - 1) && (shown <= cnt_now) && (shown >= 129) && (shown <= 131),
              $sformatf("둘째 D 뒤 기대 FND = 현재값 (01.30 근처) · LED7 0 / 실제 FND \"%s\", 내부 %0d.%02d, LED7 %0d, lap %0d",
                        s, cnt_now / CS_PER_S, cnt_now % CS_PER_S, led[7], dut.w_sw_lap));
        env_finish();
    end
endmodule
