`timescale 1ns / 1ps
// 공통 환경 스모크 테스트 (LEAD) — BFM · 모니터 · 센서 모델 · force 동작 확인
module tb_smoke;
    `include "tb_env.svh"
    string s;
    bit ok;
    initial begin
        env_start("tb_smoke", 3 * SEC);
        fnd_get(s);
        check("SMK-01", s == "00.00", $sformatf("리셋 직후 FND = \"%s\"", s));
        check("SMK-02", led == 16'h8009, $sformatf("리셋 직후 LED = %h", led));
        // 물리 버튼 (시계 화면 : 설정 아님 → 변화 없음, 펄스 개수만)
        press("R", 20 * MS, 5 * MS);
        check("SMK-03", cnt_btn_R == 1, $sformatf("R 펄스 수 = %0d", cnt_btn_R));
        pulse_phy("L");
        wait_clk(2);
        check("SMK-04", cnt_btn_L == 1, $sformatf("force L 펄스 수 = %0d", cnt_btn_L));
        // UART : /mod dist → 거리 화면, /get
        uart_send_str("/mod dist");
        #(1 * MS);
        check("SMK-05", dut.w_disp_sel == 2'd1, "/mod dist → 거리 화면");
        // SR04 1 회 측정 (583 us = 10.0 cm)
        uart_send_str("/btn R");
        #(20 * MS);
        fnd_get(s);
        check("SMK-06", s == "010.0", $sformatf("거리 FND = \"%s\"", s));
        uart_clear();
        uart_send_str("/get \r");
        uart_wait_lines(1, 20 * MS, ok);
        check("SMK-07", ok && uart_lines[0] == "010cm", $sformatf("/get 응답 = \"%s\"", ok ? uart_lines[0] : "(없음)"));
        // DHT11 : 부팅 1 s 뒤 측정
        uart_send_str("/mod temp");
        #(1 * MS);
        fnd_get(s);
        check("SMK-08", s == "----", $sformatf("측정 전 FND = \"%s\"", s));
        wait ($time > 1100 * MS);
        uart_send_str("/btn R");
        #(30 * MS);
        fnd_get(s);
        check("SMK-09", s == "55.24", $sformatf("온습도 FND = \"%s\" (start %0d 회)", s, dht_start_cnt));
        env_finish();
    end
endmodule
