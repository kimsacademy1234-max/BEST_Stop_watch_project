`timescale 1ns / 1ps
// L4. 동시 부하 (soak) — P2 · 1 개   (tb_scenario.md 4 장 L4)
// 스티뮬러스 : /auto all + SR04 auto (W 랜덤) + DHT auto (값 랜덤) + 타이머 RUN (20 s → 알람)
//              + 랜덤 물리 버튼 + 랜덤 UART 명령 (/mod 8 종 · /btn · /get · /gxt), 실시간 30 s
// 확인 (L4-01 하나로 묶음) :
//   ① 줄 형식 오류 0 (시간 / 거리 / 온습도 / ERROR 형식 외 0, <noCR> 0, frame err 0)
//   ② auto 줄 누락 0 (1 Hz tick 수 = scan 전송 수 = 받은 데이터 줄 수, 순서 SW TM WH DIST TEMP)
//   ③ hang 0 (SR04 FSM 비-IDLE ≤ 100 ms, DHT FSM ≤ 25 ms, sender busy ≤ 20 ms)
//   ④ x 0 (출력 핀), 센서 값 일치 (DHT 정상 done = 모델값, SR04 OK done = W/5.8 ± 0.2 cm)
module tb_L4;
    `include "tb_env.svh"
    localparam int     SEED       = 20261031;
    localparam longint SOAK_T     = 30 * SEC;
    localparam longint SR04_HANG  = 100 * MS;
    localparam longint DHT_HANG   = 25 * MS;
    localparam longint SEND_HANG  = 20 * MS;

    string s;
    bit    ok;
    bit    soak_on = 0;

    // ------------------------------------------------------------ 1 Hz tick · scan 전송 · go 카운트
    int  n_tick = 0, n_scan = 0, n_go = 0, n_go_err = 0;
    int  scan_seq_err = 0;
    int  exp_scan_sel = 0;
    always @(posedge clk) begin
        if (dut.U_UART.U_CONTROL.w_clk_5hz) n_tick++;
        if (dut.U_UART.U_CONTROL.scan_tick) begin
            n_scan++;
        end
        if (dut.U_UART.w_send_go) begin
            n_go++;
            if (dut.U_UART.U_CONTROL.c_sender_sel == 3'd7) n_go_err++;
            else if (dut.U_UART.U_CONTROL.c_auto_state == 2) begin   // AUTO_ALL
                if (dut.U_UART.U_CONTROL.c_sender_sel != exp_scan_sel[2:0]) scan_seq_err++;
                exp_scan_sel = (exp_scan_sel + 1) % 5;
            end
        end
    end

    // ------------------------------------------------------------ hang 감시
    time sr04_idle_t = 0, dht_idle_t = 0, send_idle_t = 0;
    time sr04_max = 0, dht_max = 0, send_max = 0;
    always @(posedge clk) begin
        if (dut.U_SR04.U_SR04.U_SR04_CNTL.c_state == 0) sr04_idle_t = $time;
        else if ($time - sr04_idle_t > sr04_max) sr04_max = $time - sr04_idle_t;
        if (dut.U_DHT11.U_DHT11_CORE.U_DHT11_CTRL.c_state == 0) dht_idle_t = $time;
        else if ($time - dht_idle_t > dht_max) dht_max = $time - dht_idle_t;
        if (dut.U_UART.U_ASCII_SENDER.c_state == 0) send_idle_t = $time;
        else if ($time - send_idle_t > send_max) send_max = $time - send_idle_t;
    end

    // ------------------------------------------------------------ x 감시 (1 ms 마다)
    int n_x = 0;
    initial begin
        forever begin
            #(1 * MS);
            if ($isunknown({led, fnd_com, fnd_font, tx, trig, dht11_io})) n_x++;
        end
    end

    // ------------------------------------------------------------ SR04 : W 랜덤 + done 값 확인
    longint cur_w = 583;
    int n_sr_done = 0, n_sr_ok = 0, n_sr_err2 = 0, n_sr_bad = 0;
    always @(posedge trig) begin
        if (soak_on) begin
            if ($urandom % 4 == 0) sr04_echo_us = 23_400 + $urandom % 6_000;   // 범위 초과
            else                   sr04_echo_us = 100 + $urandom % 22_900;     // 정상 1.7 ~ 396 cm
        end
        cur_w = sr04_echo_us;
    end
    always @(posedge clk) begin
        if (dut.w_dist_done) begin
            longint exp_x10;
            int     d;
            n_sr_done++;
            exp_x10 = (cur_w * 10 + 29) / 58;
            if (cur_w <= 23_000) begin
                d = int'(dut.w_distance_x10) - int'(exp_x10);
                if (dut.w_dist_status == 2'b00 && d >= -2 && d <= 2) n_sr_ok++;
                else begin
                    n_sr_bad++;
                    $display("[INFO] L4-SR @ %s : W=%0d us 기대 x10=%0d (OK) / 실제 x10=%0d status=%0d",
                             t_ms(), cur_w, exp_x10, dut.w_distance_x10, dut.w_dist_status);
                end
            end else begin
                if (dut.w_dist_status == 2'b10) n_sr_err2++;
                else begin
                    n_sr_bad++;
                    $display("[INFO] L4-SR @ %s : W=%0d us 기대 Err2 / 실제 status=%0d",
                             t_ms(), cur_w, dut.w_dist_status);
                end
            end
        end
    end

    // ------------------------------------------------------------ DHT : 값 랜덤 + done 값 확인
    int n_dht_done = 0, n_dht_ok = 0, n_dht_bad = 0;
    always @(posedge clk) begin
        if (dut.w_dht_done) begin
            n_dht_done++;
            if (dut.w_dht_status == 2'b00 && dut.w_humidity == dht_hum_i[7:0] && dut.w_temperature == dht_tmp_i[7:0])
                n_dht_ok++;
            else begin
                n_dht_bad++;
                $display("[INFO] L4-DHT @ %s : 기대 %0d%%%0dC OK / 실제 %0d%%%0dC status=%0d",
                         t_ms(), dht_hum_i, dht_tmp_i, dut.w_humidity, dut.w_temperature, dut.w_dht_status);
            end
            if (soak_on) begin
                dht_hum_i = 20 + $urandom % 71;   // 20 ~ 90 %
                dht_tmp_i = $urandom % 51;        // 0 ~ 50 ℃
            end
        end
    end

    // ------------------------------------------------------------ 줄 형식
    function automatic bit is_dig(input byte c);
        return (c >= "0" && c <= "9");
    endfunction
    // 0 = 형식 오류, 1 = 시간, 2 = 거리, 3 = 온습도, 4 = ERROR
    function automatic int line_kind(input string l);
        if (l.len() == 11 && l[2] == ":" && l[5] == ":" && l[8] == "." &&
            is_dig(l[0]) && is_dig(l[1]) && is_dig(l[3]) && is_dig(l[4]) &&
            is_dig(l[6]) && is_dig(l[7]) && is_dig(l[9]) && is_dig(l[10])) return 1;
        if (l.len() == 5 && is_dig(l[0]) && is_dig(l[1]) && is_dig(l[2]) && l[3] == "c" && l[4] == "m") return 2;
        if (l.len() == 6 && is_dig(l[0]) && is_dig(l[1]) && l[2] == "%" &&
            is_dig(l[3]) && is_dig(l[4]) && l[5] == "C") return 3;
        if (l == "ERROR") return 4;
        return 0;
    endfunction

    // ------------------------------------------------------------ 랜덤 물리 버튼
    int n_phy = 0;
    initial begin : phy_proc
        byte bn [4] = '{"R", "L", "U", "D"};
        wait (soak_on);
        while (soak_on) begin
            #((150 + $urandom % 750) * MS);
            if (!soak_on) break;
            press(bn[$urandom % 4], 25 * MS, 0);
            n_phy++;
        end
    end

    // ------------------------------------------------------------ 본문
    string mods [8] = '{"w_hm", "w_ms", "t_hm", "t_ms", "s_hm", "s_ms", "dist", "temp"};
    string btns [4] = '{"R", "L", "U", "D"};
    int    n_cmd = 0, n_gxt = 0;
    time   t_auto_on, t_auto_off, t_end;
    int    kinds [5];
    int    n_fmt_err, n_seq_err, n_data_lines, n_err_lines, k, exp_k, r;
    int    exp_tick;
    bit    pass;

    initial begin
        env_start("tb_L4", 40 * SEC);
        void'($urandom(SEED));
        info("L4-SEED", $sformatf("seed = %0d", SEED));

        // 준비 : 타이머 20 s 시작, SR04 auto, DHT auto, /auto all
        uart_send_str("/mod t_ms");
        uart_send_str("/btn U");
        uart_send_str("/btn U");
        uart_send_str("/btn L");
        #(2 * MS);
        info("L4-SETUP", $sformatf("타이머 run=%0d (20 s)", dut.w_tm_run));
        uart_send_str("/mod dist");
        uart_send_str("/btn U");
        uart_send_str("/mod temp");
        uart_send_str("/btn U");
        #(2 * MS);
        info("L4-SETUP", $sformatf("SR04 auto=%0d, DHT auto=%0d", dut.w_dist_auto, dut.w_dht_led[3]));
        uart_clear();
        uart_send_str("/auto all");
        t_auto_on = $time;
        soak_on = 1;

        // 랜덤 UART 명령 (SOAK_T 동안)
        t_end = $time + SOAK_T;
        while ($time < t_end) begin
            #((100 + $urandom % 500) * MS);
            if ($time >= t_end) break;
            r = $urandom % 16;
            if (r < 8)       uart_send_str({"/mod ", mods[r]});
            else if (r < 12) uart_send_str({"/btn ", btns[r - 8]});
            else if (r < 15) uart_send_str("/get \r");
            else begin
                uart_send_str("/gxt");
                n_gxt++;
            end
            n_cmd++;
        end
        soak_on = 0;
        #(100 * MS);                          // 버튼 · 측정 정리
        uart_send_str("/auto off");
        t_auto_off = $time;
        #(50 * MS);                           // 마지막 줄 전송 끝

        // ---------------- 판정
        n_fmt_err = 0; n_seq_err = 0; n_data_lines = 0; n_err_lines = 0;
        foreach (kinds[i]) kinds[i] = 0;
        for (int i = 0; i < uart_lines.size(); i++) begin
            k = line_kind(uart_lines[i]);
            kinds[k]++;
            if (k == 0) begin
                n_fmt_err++;
                info("L4-FMT", $sformatf("형식 오류 줄 %0d : \"%s\"", i, uart_lines[i]));
            end else if (k == 4) begin
                n_err_lines++;
            end else begin
                exp_k = (n_data_lines % 5 < 3) ? 1 : (n_data_lines % 5 == 3) ? 2 : 3;
                if (k != exp_k) begin
                    n_seq_err++;
                    info("L4-SEQ", $sformatf("데이터 줄 %0d 기대 형식 %0d / 실제 %0d \"%s\"", n_data_lines, exp_k, k, uart_lines[i]));
                end
                n_data_lines++;
            end
        end
        exp_tick = (t_auto_off - t_auto_on) / SEC;

        info("L4-STAT", $sformatf("명령 %0d (/gxt %0d), 물리 버튼 %0d, 줄 %0d (시간 %0d 거리 %0d 온습도 %0d ERROR %0d 오류 %0d)",
                                  n_cmd, n_gxt, n_phy, uart_lines.size(), kinds[1], kinds[2], kinds[3], kinds[4], kinds[0]));
        info("L4-STAT", $sformatf("1 Hz tick %0d (기대 %0d ± 1), scan 전송 %0d, go %0d (ERROR %0d), frame err %0d",
                                  n_tick, exp_tick, n_scan, n_go, n_go_err, uart_frame_err));
        info("L4-STAT", $sformatf("SR04 done %0d (OK 일치 %0d, Err2 %0d, 불일치 %0d), DHT done %0d (일치 %0d, 불일치 %0d)",
                                  n_sr_done, n_sr_ok, n_sr_err2, n_sr_bad, n_dht_done, n_dht_ok, n_dht_bad));
        info("L4-STAT", $sformatf("최장 busy : SR04 %0.3f ms (≤ %0d), DHT %0.3f ms (≤ %0d), sender %0.3f ms (≤ %0d), x 샘플 %0d",
                                  sr04_max / 1.0e6, SR04_HANG / MS, dht_max / 1.0e6, DHT_HANG / MS,
                                  send_max / 1.0e6, SEND_HANG / MS, n_x));
        info("L4-STAT", $sformatf("타이머 알람=%0d run=%0d, SR04 auto=%0d, DHT auto=%0d",
                                  dut.w_tm_alarm, dut.w_tm_run, dut.w_dist_auto, dut.w_dht_led[3]));

        pass = (n_fmt_err == 0) && (uart_frame_err == 0) && (n_seq_err == 0) && (scan_seq_err == 0) &&
               (n_tick == n_scan) && (n_data_lines == n_scan) && (n_err_lines == n_go_err) &&
               (uart_lines.size() == n_go) && (n_tick >= exp_tick - 1) && (n_tick <= exp_tick + 1) &&
               (sr04_max <= SR04_HANG) && (dht_max <= DHT_HANG) && (send_max <= SEND_HANG) &&
               (n_x == 0) && (n_sr_bad == 0) && (n_dht_bad == 0) && (n_dht_done > 0) && (n_sr_done > 0);
        check("L4-01", pass,
              $sformatf("기대 : 형식 오류 0 · 누락 0 · hang 0 · x 0 / 실제 : 형식 오류 %0d, frame err %0d, 순서 오류 %0d+%0d, tick %0d = scan %0d = 데이터 줄 %0d, ERROR 줄 %0d = ERROR go %0d, 줄 %0d = go %0d, busy SR04 %0.1f ms DHT %0.1f ms sender %0.3f ms, x %0d, 센서 불일치 %0d+%0d",
                        n_fmt_err, uart_frame_err, n_seq_err, scan_seq_err, n_tick, n_scan, n_data_lines,
                        n_err_lines, n_go_err, uart_lines.size(), n_go, sr04_max / 1.0e6, dht_max / 1.0e6,
                        send_max / 1.0e6, n_x, n_sr_bad, n_dht_bad));
        env_finish();
    end
endmodule
