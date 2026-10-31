`timescale 1ns / 1ps
// =============================================================================
// tb_G_uart_rx — G. UART 수신 · 디코더 (tb_scenario.md G1 ~ G9)
//   G1 정상 명령 24 개  G2 형식 오류 10 종  G3 형식 OK · 모르는 옵션  G4 '/' 로 복구
//   G3-3 (⚠ issue 9)  G5 쓰레기 · 꼬리 문자  G6 짧은 옵션  G7 /off 오타 뒤 /off (⚠)  G8 RX 물리층  G9 바이트 연속
//   시간 : 응답 시작 기준 0.1 ms 는 9600 bps 기준 → FAST (115200) 에서는 bit 시간 비율로 줄임
// =============================================================================
module tb_G_uart_rx;
    localparam string ONLY = "";
    localparam bit    FAST = 1;    // 1 = 시간 줄임 (tb_scenario.md 3-3), 0 = 실제 시간

    tb_merge_harness #(
        .TICK_F    (FAST ? 1_000 : 1_000_000),
        .AUTO_FRQ  (FAST ? 200 : 1),
        .DHT_BOOT  (FAST ? 300_000 : 100_000_000),
        .DHT_INTV  (FAST ? 500_000 : 200_000_000),
        .BLINK_HALF(FAST ? 25_000 : 25_000_000),
        .BAUD      (FAST ? 115_200 : 9_600),
        .SR_TICK   (FAST ? 10 : 100),
        .DHT_TICK  (FAST ? 10 : 100),
        .TB_ID     ("G_uart_rx"),
        .ONLY      (ONLY),
        .TIMEOUT_MS(FAST ? 300 : 5_000)
    ) h ();

    localparam [6:0] B_DIST = 7'b010_0000, B_TEMP = 7'b100_0000, B_WHM = 7'b000_0010;
    real T_RESP;   // 응답 시작 허용 (9600 : 0.1 ms ≈ 1 bit)
    string CR, LF;

    initial begin
        string   s, s2, pre, rest, cmds[24];
        bit      crs[24];
        realtime t0, t_bad;
        integer  e0, hs0, rx0, u0, n0;
        reg [6:0] c0;
        integer  st0;

        T_RESP = h.BIT_NS;
        CR = $sformatf("%c", 8'h0D);
        LF = $sformatf("%c", 8'h0A);

        // ---------------------------------------------------------------- G1
        if (h.run("G1")) begin
            h.begin_sc("G1", "every valid command", "24 commands (mod 8, set 3, off 1, btn 4, auto 7, get 1)",
                       "1 handshake each, no ERROR");
            h.do_reset();
            cmds = '{"/mod w_hm", "/mod w_ms", "/mod s_hm", "/mod s_ms", "/mod t_hm", "/mod t_ms", "/mod dist", "/mod w_hm",
                     "/set w_hm", "/set 24h", "/set 12h", "/off w_h",
                     "/btn R", "/btn L", "/btn U", "/btn D",
                     "/auto all", "/auto _sw", "/auto _tm", "/auto _wh", "/auto dis", "/auto tem", "/auto off",
                     "/get "};
            crs  = '{0, 0, 0, 0, 0, 0, 0, 0,  0, 1, 1, 0,  0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0,  1};
            // /mod temp 는 8 번째 대신 G4/G5 에서 (여기선 /set w_hm 이 되도록 w_hm 로 끝냄)
            for (int i = 0; i < 24; i++) begin
                hs0 = h.n_hs;
                e0  = h.n_err;
                if (crs[i]) h.uart_line(cmds[i]);
                else        h.uart_send(cmds[i]);
                h.check($sformatf("G1-%0d", i + 1), (h.n_hs == hs0 + 1) && (h.n_err == e0),
                        {"\"", cmds[i], h.pick(crs[i], "<CR>", ""), "\""}, "1 handshake, 0 error",
                        $sformatf("%0d handshake, %0d error", h.n_hs - hs0, h.n_err - e0));
            end
            hs0 = h.n_hs;
            h.mod("temp");
            h.note($sformatf("/mod temp : handshake %0d, ctrl %b", h.n_hs - hs0, h.dut.w_ctrl_bit));
        end

        // ---------------------------------------------------------------- G2
        if (h.run("G2")) begin
            h.begin_sc("G2", "format errors", "10 bad commands (prefix up to the bad byte, then the rest)",
                       "exactly 1 ERROR line, starts within ~1 bit after the bad byte rx_done");
            h.do_reset();
            for (int i = 0; i < 10; i++) begin
                case (i)
                    0: begin pre = "/gx";         rest = "t";            end
                    1: begin pre = "/modw";       rest = "_hm";          end
                    2: begin pre = {"/mod ", CR}; rest = "";             end
                    3: begin pre = "/get x";      rest = "";             end
                    4: begin pre = "/btn X";      rest = "";             end
                    5: begin pre = "/btn r";      rest = "";             end
                    6: begin pre = "/G";          rest = {"ET ", CR};    end
                    7: begin pre = {"/auto ", CR}; rest = "";            end
                    8: begin pre = "/x";          rest = "";             end
                    default: begin pre = {"/set", CR}; rest = "";        end
                endcase
                h.flush_lines();
                e0 = h.n_err;
                h.uart_send(pre);
                t_bad = h.t_rx_done;
                if (rest.len() > 0) h.uart_send(rest);
                h.next_line(s, t0, 30 * T_RESP * 10);
                h.wait_us(20 * T_RESP / 1000.0 * 10);   // 뒤에 줄이 더 오는지
                h.check($sformatf("G2-%0d", i + 1), (s == "ERROR") && (t0 - t_bad < T_RESP) && (h.n_err == e0 + 1)
                        && (h.lines_pending() == 0),
                        $sformatf("bad command #%0d", i + 1), $sformatf("1 ERROR, start < %0.1f us", T_RESP / 1000.0),
                        $sformatf("\"%s\" at %0.1f us, %0d error, %0d extra line", s, (t0 - t_bad) / 1000.0,
                                  h.n_err - e0, h.lines_pending()));
            end
        end

        // ---------------------------------------------------------------- G3
        if (h.run("G3")) begin
            h.begin_sc("G3", "valid format, unknown option", "/mod abcd, /auto xyz, /set abcd",
                       "no ERROR, nothing changes");
            h.do_reset();
            h.mod("w_hm");
            c0 = h.dut.w_ctrl_bit;
            e0 = h.n_err;
            h.uart_send("/mod abcd");
            h.check("G3-1", (h.dut.w_ctrl_bit == c0) && (h.n_err == e0), "/mod abcd", $sformatf("ctrl %b, 0 error", c0),
                    $sformatf("ctrl %b, %0d error", h.dut.w_ctrl_bit, h.n_err - e0));
            st0 = h.dut.U_UART.U_CONTROL.c_auto_state;
            h.uart_send("/auto xyz");
            h.check("G3-2", (h.dut.U_UART.U_CONTROL.c_auto_state == st0) && (h.n_err == e0), "/auto xyz",
                    $sformatf("auto state %0d, 0 error", st0),
                    $sformatf("auto state %0d, %0d error", h.dut.U_UART.U_CONTROL.c_auto_state, h.n_err - e0));
            h.uart_send("/set abcd");
            // (issue 9) 시계 시.분 화면에서는 /set 의 옵션 글자를 안 보고 설정을 켬
            h.spec("G3-3", (h.dut.w_ctrl_bit == c0) && (h.n_err == e0), "/set abcd (on w_hm screen)", $sformatf("ctrl %b, 0 error", c0),
                   $sformatf("ctrl %b, %0d error", h.dut.w_ctrl_bit, h.n_err - e0));
        end

        // ---------------------------------------------------------------- G4
        if (h.run("G4")) begin
            h.begin_sc("G4", "'/' restarts a command", "\"/ge/get <CR>\" ; \"//mod dist\"",
                       "ERROR then the command still runs");
            h.do_reset();
            h.flush_lines();
            h.uart_line("/ge/get ");
            h.next_line(s, t0, 50 * T_RESP * 10);
            h.next_line(s2, t0, 50 * T_RESP * 10);
            h.check("G4-1", (s == "ERROR") && h.is_time(s2), "/ge/get <CR>", "ERROR, then time line",
                    $sformatf("\"%s\", \"%s\"", s, s2));
            h.flush_lines();
            h.uart_send("//mod dist");
            h.next_line(s, t0, 50 * T_RESP * 10);
            h.check("G4-2", (s == "ERROR") && (h.dut.w_ctrl_bit == B_DIST), "//mod dist", "ERROR, distance screen",
                    $sformatf("\"%s\", ctrl %b", s, h.dut.w_ctrl_bit));
        end

        // ---------------------------------------------------------------- G5
        if (h.run("G5")) begin
            h.begin_sc("G5", "garbage and trailing characters", "abc CR LF /mod dist ; /off w_hm ; /mod w_hm CR LF",
                       "ignored, no ERROR");
            h.do_reset();
            e0 = h.n_err;
            h.uart_send({"abc", CR, LF, "/mod dist"});
            h.check("G5-1", (h.n_err == e0) && (h.dut.w_ctrl_bit == B_DIST), "garbage before /mod dist", "0 error, distance",
                    $sformatf("%0d error, ctrl %b", h.n_err - e0, h.dut.w_ctrl_bit));
            h.mod("w_hm");
            h.uart_send("/set w_hm");
            h.uart_send("/off w_hm");
            h.check("G5-2", (h.n_err == e0) && (h.dut.w_ctrl_bit[2] == 0), "/off w_hm (extra m)", "0 error, set off",
                    $sformatf("%0d error, bit2 %b", h.n_err - e0, h.dut.w_ctrl_bit[2]));
            h.mod("dist");
            h.uart_send({"/mod w_hm", CR, LF});
            h.check("G5-3", (h.n_err == e0) && (h.dut.w_ctrl_bit == B_WHM), "/mod w_hm CR LF", "0 error, w_hm",
                    $sformatf("%0d error, ctrl %b", h.n_err - e0, h.dut.w_ctrl_bit));
        end

        // ---------------------------------------------------------------- G6
        if (h.run("G6")) begin
            h.begin_sc("G6", "short option", "/mod w_h CR ; /set 24h without Enter",
                       "handshake but no change ; waits (no handshake) until Enter");
            h.do_reset();
            h.mod("w_hm");
            c0  = h.dut.w_ctrl_bit;
            hs0 = h.n_hs;
            e0  = h.n_err;
            h.uart_line("/mod w_h");
            h.check("G6-1", (h.n_hs == hs0 + 1) && (h.dut.w_ctrl_bit == c0) && (h.n_err == e0), "/mod w_h <CR>",
                    "1 handshake, ctrl same, 0 error", $sformatf("%0d handshake, ctrl %b, %0d error", h.n_hs - hs0,
                    h.dut.w_ctrl_bit, h.n_err - e0));
            hs0 = h.n_hs;
            h.uart_send("/set 24h");
            h.wait_us(50 * T_RESP / 1000.0 * 10);
            h.check("G6-2", (h.n_hs == hs0) && (h.dut.w_ctrl_bit[3] == 0), "/set 24h (no Enter)", "0 handshake, bit3 0",
                    $sformatf("%0d handshake, bit3 %b", h.n_hs - hs0, h.dut.w_ctrl_bit[3]));
            h.uart_cr();
            h.note($sformatf("after Enter : bit3 %b", h.dut.w_ctrl_bit[3]));
        end

        // ---------------------------------------------------------------- G7
        if (h.run("G7")) begin
            h.begin_sc("G7", "/off typo then /off", "/mod w_hm -> /set w_hm -> /off <CR> -> /off w_h",
                       "ERROR ; spec: set off - code: ERROR again (issue 2)");
            h.do_reset();
            h.mod("w_hm");
            h.uart_send("/set w_hm");
            h.flush_lines();
            h.uart_line("/off");
            h.next_line(s, t0, 50 * T_RESP * 10);
            h.check("G7-1", s == "ERROR", "/off <CR>", "ERROR", {"\"", s, "\""});
            e0 = h.n_err;
            h.uart_send("/off w_h");
            h.spec("G7-2", (h.dut.w_ctrl_bit[2] == 0) && (h.n_err == e0), "/off w_h after the typo", "set off, 0 error",
                   $sformatf("bit2 %b, %0d error", h.dut.w_ctrl_bit[2], h.n_err - e0));
        end

        // ---------------------------------------------------------------- G8
        if (h.run("G8")) begin
            h.begin_sc("G8", "RX physical layer", "baud +-2 %, 0.3 bit glitch, stop bit 0, 20-byte break",
                       "ok / ok / no byte / byte accepted / 0x00 ignored");
            h.do_reset();
            e0 = h.n_err;
            h.uart_err = 0.02;
            h.mod("dist");
            h.uart_err = 0.0;
            h.check("G8-1", (h.dut.w_ctrl_bit == B_DIST) && (h.n_err == e0), "PC baud +2 %", "distance, 0 error",
                    $sformatf("ctrl %b, %0d error", h.dut.w_ctrl_bit, h.n_err - e0));
            h.uart_err = -0.02;
            h.mod("temp");
            h.uart_err = 0.0;
            h.check("G8-2", (h.dut.w_ctrl_bit == B_TEMP) && (h.n_err == e0), "PC baud -2 %", "temp, 0 error",
                    $sformatf("ctrl %b, %0d error", h.dut.w_ctrl_bit, h.n_err - e0));
            rx0 = h.n_rx;
            h.rx = 1'b0;
            #(0.3 * h.BIT_NS);
            h.rx = 1'b1;
            #(20 * h.BIT_NS);
            h.check("G8-3", h.n_rx == rx0, "0.3 bit LOW glitch", "no byte", $sformatf("%0d byte", h.n_rx - rx0));
            rx0 = h.n_rx;
            h.uart_byte("/", 1'b0);
            #(3 * h.BIT_NS);
            h.check("G8-4", (h.n_rx >= rx0 + 1) && (h.rx_last == "/" || h.n_rx > rx0 + 1), "'/' with stop bit 0",
                    "accepted (no framing check)", $sformatf("%0d byte, first after = 0x%h", h.n_rx - rx0, h.rx_last));
            h.do_reset();
            e0 = h.n_err;
            h.rx = 1'b0;
            #(20 * 10 * h.BIT_NS);       // 20 바이트 시간
            h.rx = 1'b1;
            #(30 * h.BIT_NS);
            h.mod("dist");
            h.check("G8-5", (h.dut.w_ctrl_bit == B_DIST) && (h.n_err == e0), "break then /mod dist", "distance, 0 error",
                    $sformatf("ctrl %b, %0d error", h.dut.w_ctrl_bit, h.n_err - e0));
        end

        // ---------------------------------------------------------------- G9
        if (h.run("G9")) begin
            h.begin_sc("G9", "back-to-back bytes", "30 x /btn U|D without idle (watch screen, not set)",
                       "30 UART button pulses, RX FIFO never full");
            h.do_reset();
            u0  = h.uc[2] + h.uc[3];
            hs0 = h.n_hs;
            h.rx_full_seen = 0;
            s = "";
            for (int i = 0; i < 30; i++) s = {s, h.pick(i % 2 == 0, "/btn U", "/btn D")};
            h.uart_send(s);
            h.wait_us(10);
            h.check("G9-1", (h.uc[2] + h.uc[3] == u0 + 30) && (h.n_hs == hs0 + 30) && !h.rx_full_seen, "30 commands",
                    "30 btn, 30 handshake, full 0", $sformatf("%0d btn, %0d handshake, full %b", h.uc[2] + h.uc[3] - u0,
                    h.n_hs - hs0, h.rx_full_seen));
        end

        h.finish_tb();
    end
endmodule
