`timescale 1ns / 1ps
// L5. 랜덤 리셋 — P3 · 20 개   (tb_scenario.md 4 장 L5)
// 스티뮬러스 : 동작 하나를 걸어 놓고 (랜덤) 랜덤 시점에 rst 1 us → 해제, 20 회 반복
//   종류 0 DHT START LOW · 센서 응답 중 / 1 UART 송신 중 (/get 응답) / 2 UART 수신 중 (/mod dist 바이트 도중)
//        3 SR04 auto 측정 중 / 4 스톱워치 RUN + 스위치 모드 화면
// 확인 : 매 리셋 뒤 A1 의 7 항목 (L5-01 ~ L5-20, 한 번에 하나)
//   ① w_rst 해제 = rst 하강 뒤 2 번째 상승 엣지  ② 해제 + 2 ms FND "00.00"  ③ 해제 직후 LED 0x8009
//   ④ 1.2 s 동안 tx 1  ⑤ 1.2 s 동안 trig 0  ⑥ 1.0 s 동안 FPGA 가 DHT 선 안 내림 (oe 0, START 0 회)
//   ⑦ 해제 + 1 clk 부터 출력 핀 x/z 없음
//   ⑥ : 리셋 직전 START LOW 가 17 ms 넘었으면 TB 센서 모델이 리셋 뒤 응답을 보내므로 (실제 센서와 같음)
//       "선 = 1" 대신 "FPGA 구동 없음 (c_oe 0) + 센서 아닌 LOW 없음" 으로 판정
module tb_L5;
    `include "tb_env.svh"
    localparam int     SEED     = 5150;
    localparam int     N_RESET  = 20;
    localparam longint OBS_T    = 1200 * MS;   // A1 관찰 1.2 s
    localparam longint DHT_T    = 1000 * MS;   // A1 ⑥ 1.0 s

    string s;
    bit    ok;

    // ------------------------------------------------------------ 끊을 수 있는 UART 송신 (리셋 순간 rx 1 로)
    bit abort_tx = 0;
    task automatic send_byte_ab(input byte b);
        if (abort_tx) return;
        rx = 1'b0;
        #(UART_BIT_NS);
        for (int i = 0; i < 8; i++) begin
            if (abort_tx) begin rx = 1'b1; return; end
            rx = b[i];
            #(UART_BIT_NS);
        end
        if (abort_tx) begin rx = 1'b1; return; end
        rx = 1'b1;
        #(UART_BIT_NS);
    endtask
    task automatic send_str_ab(input string str);
        for (int i = 0; i < str.len(); i++) begin
            if (abort_tx) return;
            send_byte_ab(str[i]);
        end
    endtask

    // ------------------------------------------------------------ 관찰 창 감시
    bit  obs_on = 0, dht_obs_on = 0;
    int  n_tx0 = 0, n_trig1 = 0, n_oe = 0, n_line_low = 0, n_x = 0;
    always @(negedge tx)    if (obs_on) n_tx0++;
    always @(posedge trig)  if (obs_on) n_trig1++;
    always @(posedge dut.U_DHT11.w_dht_oe) if (dht_obs_on) n_oe++;
    always @(negedge dht11_io) if (dht_obs_on && !dht_sensor_low && !dht_stuck_low) n_line_low++;
    always @(led or fnd_com or fnd_font or tx or trig)
        if (obs_on && $isunknown({led, fnd_com, fnd_font, tx, trig})) n_x++;

    // ------------------------------------------------------------ 본문
    int     kind, r1, r2, start0;
    longint dly;
    time    t_rel;
    bit     c1, c2, c3, c4, c5, c6, c7;
    string  kname [5] = '{"DHT START/응답", "UART 송신", "UART 수신", "SR04 측정", "스톱워치 RUN"};

    initial begin
        env_start("tb_L5", 40 * SEC);
        void'($urandom(SEED));
        info("L5-SEED", $sformatf("seed = %0d", SEED));
        #(OBS_T);                                 // 첫 부팅 (DHT 1 s) 끝내고 시작

        for (int n = 1; n <= N_RESET; n++) begin
            // ---------- 동작 걸기
            kind = $urandom % 5;
            abort_tx = 0;
            case (kind)
                0: begin
                    send_str_ab("/mod temp");
                    send_str_ab("/btn R");
                    wait (dut.U_DHT11.w_dht_oe == 1'b1);
                    dly = $urandom % 22_000;          // START LOW 0 ~ 18 ms + 응답 0 ~ 4 ms
                    #(dly * US);
                end
                1: begin
                    send_str_ab("/mod s_ms");
                    send_str_ab("/btn R");
                    send_str_ab("/get \r");
                    wait (dut.U_UART.U_ASCII_SENDER.c_state == 1'b1);
                    dly = $urandom % 13_000;          // 응답 13 바이트 (13.5 ms) 안
                    #(dly * US);
                end
                2: begin
                    send_str_ab("/mod w_ms");
                    dly = $urandom % 9_000;           // /mod dist 9 바이트 (9.4 ms) 안
                    fork
                        send_str_ab("/mod dist");
                    join_none
                    #(dly * US);
                end
                3: begin
                    sr04_echo_us = 100 + $urandom % 23_000;
                    send_str_ab("/mod dist");
                    send_str_ab("/btn U");
                    dly = 30_000 + $urandom % 90_000; // 측정 1 ~ 2 번째 도중
                    #(dly * US);
                end
                default: begin
                    set_sw(7'b0000001);               // 스위치 : 스톱워치 초
                    press("R", 20 * MS, 0);
                    dly = $urandom % 100_000;
                    #(dly * US);
                end
            endcase
            start0 = dht_start_cnt;

            // ---------- 리셋 (랜덤 시점, clk 와 비동기)
            #($urandom % 10);
            rst = 1'b1;
            abort_tx = 1;
            rx = 1'b1;
            set_sw(7'b0000000);
            btn_R = 0; btn_L = 0; btn_U = 0; btn_D = 0;
            #(1 * US);
            @(negedge clk);
            rst = 1'b0;
            @(posedge clk); #1; r1 = dut.w_rst;
            @(posedge clk); #1; r2 = dut.w_rst;
            t_rel = $time;
            c1 = (r1 == 1) && (r2 == 0);
            // 관찰 시작
            n_tx0 = 0; n_trig1 = 0; n_oe = 0; n_line_low = 0; n_x = 0;
            obs_on = 1; dht_obs_on = 1;
            if ($isunknown({led, fnd_com, fnd_font, tx, trig})) n_x++;
            c3 = (led == 16'h8009);
            #(2 * MS);
            fnd_get(s);
            c2 = (s == "00.00");
            #(DHT_T - ($time - t_rel));
            dht_obs_on = 0;
            c6 = (n_oe == 0) && (n_line_low == 0) && (dht_start_cnt == start0) &&
                 (dut.U_DHT11.w_dht_oe == 1'b0);
            #(OBS_T - ($time - t_rel));
            obs_on = 0;
            c4 = (n_tx0 == 0) && (tx == 1'b1);
            c5 = (n_trig1 == 0) && (trig == 1'b0);
            c7 = (n_x == 0);
            check($sformatf("L5-%02d", n), c1 && c2 && c3 && c4 && c5 && c6 && c7,
                  $sformatf("종류 %0d (%s, +%0d us) → 기대 7 항목 1 / 실제 ①w_rst %0d→%0d ②FND \"%s\" ③LED %h ④tx 하강 %0d ⑤trig 상승 %0d ⑥oe %0d·센서아닌 LOW %0d·START %0d ⑦x %0d",
                            kind, kname[kind], dly, r1, r2, s, led, n_tx0, n_trig1, n_oe, n_line_low,
                            dht_start_cnt - start0, n_x));
        end
        env_finish();
    end
endmodule
