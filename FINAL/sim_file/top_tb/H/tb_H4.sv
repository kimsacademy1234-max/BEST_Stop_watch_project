`timescale 1ns / 1ps
// H4. /auto 주기 — P1 · 5 개   (tb_scenario.md 4 장 H4)
// /auto <opt> (_sw _tm _wh dis tem) → 3.2 s 관찰 → /auto off, 옵션마다 반복
//   확인 : 줄 3 개, 첫 줄 start = handshake + 1.000 s (+ < 0.1 ms), 줄 간격 1.000 s ± 10 us, 형식 맞음
//   ※ 옵션 사이에 env_reset — /auto off 가 tick 카운터를 안 지우는 H7 이슈 (⚠ 3) 가 첫 줄 시각에 섞이지 않게
module tb_H4;
    `include "tb_env.svh"
    localparam longint T_OBS     = 3200 * MS;   // 관찰 시간
    localparam longint T_PERIOD  = 1 * SEC;     // AUTO_FRQ = 1 Hz
    localparam longint TOL_START = 100 * US;    // 응답 시작 허용 (3-2 장)
    localparam longint TOL_INT   = 10 * US;     // 간격 허용

    time t_hs = 0;
    always @(posedge clk) if (dut.U_UART.w_handshake) t_hs = $time;

    function automatic bit is_dig(byte c);
        return (c >= "0" && c <= "9");
    endfunction
    function automatic bit fmt_time(string s);   // HH:MM:SS.CC
        if (s.len() != 11) return 0;
        foreach (s[i]) begin
            if (i == 2 || i == 5) begin if (s[i] != ":") return 0; end
            else if (i == 8) begin if (s[i] != ".") return 0; end
            else if (!is_dig(s[i])) return 0;
        end
        return 1;
    endfunction
    function automatic bit fmt_dist(string s);   // NNNcm
        return s.len() == 5 && is_dig(s[0]) && is_dig(s[1]) && is_dig(s[2]) && s.substr(3, 4) == "cm";
    endfunction
    function automatic bit fmt_temp(string s);   // HH%TTC
        return s.len() == 6 && is_dig(s[0]) && is_dig(s[1]) && s[2] == "%" &&
               is_dig(s[3]) && is_dig(s[4]) && s[5] == "C";
    endfunction
    function automatic bit fmt_ok(int k, string s);
        case (k)
            0, 1, 2: return fmt_time(s) && (k != 1 || s.substr(0, 2) == "00:");
            3:       return fmt_dist(s);
            default: return fmt_temp(s);
        endcase
    endfunction

    string opts[5] = '{"_sw", "_tm", "_wh", "dis", "tem"};
    string s;
    bit    ok;
    initial begin
        time    ts, d0;
        longint di;
        bit     good;
        env_start("tb_H4", 20 * SEC);
        for (int k = 0; k < 5; k++) begin
            if (k > 0) env_reset();
            uart_clear();
            uart_send_str({"/auto ", opts[k]});
            ts = t_hs;
            wait ($time >= ts + T_OBS);
            good = (uart_lines.size() == 3);
            s = $sformatf("줄 %0d 개 (기대 3)", uart_lines.size());
            if (uart_lines.size() >= 1) begin
                d0 = uart_line_t0[0] - ts;
                good &= (d0 >= T_PERIOD) && (d0 < T_PERIOD + TOL_START);
                s = {s, $sformatf(" | 첫 줄 = hs + %0.6f ms (기대 1000.000 ~ 1000.100)", d0 / 1.0e6)};
            end
            for (int i = 0; i < uart_lines.size(); i++) begin
                good &= fmt_ok(k, uart_lines[i]);
                s = {s, $sformatf(" | \"%s\"", uart_lines[i])};
                if (i > 0) begin
                    di = longint'(uart_line_t0[i] - uart_line_t0[i-1]) - T_PERIOD;
                    good &= (di <= TOL_INT) && (di >= -TOL_INT);
                    s = {s, $sformatf(" 간격 1 s %+0d ns (± 10 us)", di)};
                end
            end
            check($sformatf("H4-%02d", k + 1), good, {"/auto ", opts[k], " : ", s});
            uart_send_str("/auto off");
            #(2 * MS);
        end
        env_finish();
    end
endmodule
