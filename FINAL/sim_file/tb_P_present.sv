`timescale 1ns / 1ps
// =============================================================================
// tb_P_present — Top 발표용 대표 파형 (UART 명령 경로별 대표 1 개 + 센서 오류)
//   P1 /mod dist        : 스위치 → UART 로 화면 제어권 넘어감         (경로 ① 화면 제어)
//   P2 /btn R → /get    : UART 버튼 → SR04 측정 → 123cm 응답          (경로 ③ 버튼 + ② 송신)
//   P3 /auto all        : 실제 1 Hz 로 SW → TM → WH → DIST → TEMP     (경로 ② 송신, 5 입력)
//   P4 /gxt             : 형식 오류 → ERROR 1 줄 → 뒤 명령 정상        (경로 ④ 오류)
//   P5 SR04 Err1~3      : 무응답 / 범위 밖 / echo 고착 → FND · PC 둘 다 오류
//   P6 DHT11 Err1~3     : 측정 전 --%--C / 응답 없음 / 중간 끊김 / 체크섬
//
//   ★ 시간 줄이기 없음 : 100 MHz, 9600 baud, /auto 1 Hz, 센서 1 us tick, DHT11 부팅 1 s · 간격 2 s
//     → 파형의 시간 간격 = 보드 실제 시간 그대로 (발표 캡처용)
//   ★ 장면은 하나씩 돌릴 것 : run_present.bat P3 wave  (그러면 장면 시작 = 0 ms, 안내서 시각 그대로)
//   콘솔 [MARK] = 단계 시작, [CAPTURE] = 캡처 구간 (실제 이벤트 시각으로 계산한 값)
//   안내서 : ahnsung/FINAL/ppt_make/top_파형_캡처_안내.md
// =============================================================================
module tb_P_present;

    localparam string ONLY = "P2";

    tb_merge_harness #(
        .TICK_F    (1_000_000),
        .AUTO_FRQ  (1),
        .DHT_BOOT  (100_000_000),
        .DHT_INTV  (200_000_000),
        .BLINK_HALF(25_000_000),
        .BAUD      (9_600),
        .SR_TICK   (100),
        .DHT_TICK  (100),
        .TB_ID     ("P_present"),
        .ONLY      (ONLY),
        .TIMEOUT_MS(12_000)
    ) h ();

    localparam integer BR = 0, BL = 1, BU = 2, BD = 3;
    localparam real    MSN = 1.0e6;     // 1 ms (ns)
    localparam real    USN = 1.0e3;     // 1 us (ns)

    // ---------------------------------------------------------------- 파형용 (wcfg)
    reg [8*16-1:0] W_STEP = 0;          // 지금 단계 (ASCII)
    wire           LD9 = h.led[9];      // SR04 오류 LED
    integer        GO_GAP_CLK = 0;      // 직전 send_go 와의 간격 (clk) — 1 Hz 면 100,000,000
    integer        GO_GAP_US  = 0;      // 같은 값 (us) — 1 Hz 면 1,000,000
    integer        N_GO = 0;            // send_go 개수 (= 보낸 줄 수)

    // ---------------------------------------------------------------- 모니터
    integer  clk_cnt = 0, clk_go_last = 0;
    realtime t0 = 0;                    // 장면 시작 (혼자 돌리면 0)
    realtime t_go_q[$];
    realtime t_err = 0;
    string   caps[$];

    always @(posedge h.clk) begin
        clk_cnt++;
        if (h.started && h.dut.U_UART.w_send_go) begin
            if (clk_go_last != 0) begin
                GO_GAP_CLK = clk_cnt - clk_go_last;
                GO_GAP_US  = GO_GAP_CLK / 100;
            end
            clk_go_last = clk_cnt;
            N_GO++;
            t_go_q.push_back($realtime);
        end
        if (h.started && h.dut.U_UART.w_error) t_err = $realtime;
    end

    // ---------------------------------------------------------------- 도우미
    function automatic real rel(input realtime t);      // 장면 시작 기준 ms
        return (t - t0) / MSN;
    endfunction

    task automatic at(input real ms);                    // 장면 시작 + ms 까지 기다림
        h.wait_until(t0 + ms * MSN);
    endtask

    task automatic step(input string s);
        W_STEP = h.s2v(s);
        h.log("MARK", $sformatf("%s  @ %0.4f ms", s, rel($realtime)));
    endtask

    task automatic cap(input string id, input realtime a, input realtime b, input string what);
        string s;
        s = $sformatf("%s  %10.4f ~ %10.4f ms  (%0.3f ms)  %s", h.padn(id, 6), rel(a), rel(b), (b - a) / MSN, what);
        caps.push_back(s);
        h.log("CAPTURE", s);
    endtask

    task automatic scene_start(input string id, input string title, input string plan, input string expect_s);
        h.begin_sc(id, title, plan, expect_s);
        t0 = $realtime;
        h.sw        = 7'd0;
        h.sw15      = 1'b0;
        h.sr_mode   = h.SR_NORMAL;
        h.sr_dly_us = 500.0;
        h.sr_w_us   = 1000.0;
        h.echo      = 1'b0;
        h.dh_default();
        h.do_reset();
        clk_go_last = 0;
        GO_GAP_CLK  = 0;
        GO_GAP_US   = 0;
        N_GO        = 0;
        t_go_q.delete();
        W_STEP = h.s2v("reset");
    endtask

    // "/get " + CR 보내고 응답 1 줄 (t_a = 첫 start 비트, t_b = 마지막 stop 끝)
    task automatic get_line(output string s, output realtime t_cmd, output realtime t_a, output realtime t_b);
        h.flush_lines();
        t_cmd = $realtime;
        h.uart_send("/get ");
        h.uart_cr();
        h.next_line(s, t_a, 40 * MSN);
        t_b = h.last_t1;
    endtask

    task automatic fnd_now(output string s);
        string f;
        h.fnd_read_stable(f);
        s = h.strip_dot(f);
    endtask

    function automatic bit near(input realtime d, input real target_ns, input real tol_ns);
        return (d >= target_ns - tol_ns) && (d <= target_ns + tol_ns);
    endfunction

    // =========================================================================
    initial begin
        string   s, s1, s2, s3, f, f1, f2, f3, ls[5];
        bit      ok, ok_a, ok_b, gap_ok, lgap_ok;
        realtime tc, ta, tb, t_cmd, t_hs1, t_last_b, tr, tf, er, ef, dn, dn_a, oe_r, oe_f;
        realtime lt0[5], lt1[5];
        integer  st, st_a;
        real     g;

        // ============================================================ P1 /mod
        if (h.run("P1")) begin
            scene_start("P1", "/mod dist : switch -> UART control",
                        "sw6=1 @2 ms, /mod dist @5 ms, switches toggled @18/20/22 ms",
                        "before: switch picks screen (temp) ; after last byte: uart_mode 1, ctrl_bit 010_0000, switches ignored");
            at(2.0);  step("sw6=1 (temp)");    h.sw = 7'b100_0000;
            at(4.0);
            h.check("P1-1", (h.dut.w_uart_mode == 0) && (h.dut.w_disp_sel == 2), "before /mod : switch decides",
                    "uart_mode 0, disp_sel 2", $sformatf("uart_mode %b, disp_sel %0d", h.dut.w_uart_mode, h.dut.w_disp_sel));
            at(5.0);  step("/mod dist");       tc = $realtime;
            h.mod("dist");
            t_last_b = tc + 8 * 10 * h.BIT_NS;  // 9 번째 글자 't' 의 start 비트
            h.wait_us(50);
            t_hs1 = h.t_hs;
            h.check("P1-2", (h.dut.w_uart_mode == 1) && (h.dut.w_disp_sel == 1) && (h.dut.w_ctrl_bit == 7'b010_0000),
                    "after /mod dist", "uart_mode 1, disp_sel 1, ctrl_bit 0100000",
                    $sformatf("uart_mode %b, disp_sel %0d, ctrl_bit %b (handshake %0.4f ms, ctrl change %0.4f ms)",
                              h.dut.w_uart_mode, h.dut.w_disp_sel, h.dut.w_ctrl_bit, rel(t_hs1), rel(h.t_ctrl_chg)));
            tb = h.t_ctrl_chg;
            at(18.0); step("sw=0");            h.sw = 7'b000_0000;
            at(20.0); step("sw4=1 (timer)");   h.sw = 7'b001_0000;
            at(22.0); step("sw6=1 (temp)");    h.sw = 7'b100_0000;
            at(25.0);
            h.check("P1-3", (h.dut.w_disp_sel == 1) && (h.dut.w_ctrl_bit == 7'b010_0000), "switches after /mod",
                    "still disp_sel 1, ctrl_bit 0100000", $sformatf("disp_sel %0d, ctrl_bit %b", h.dut.w_disp_sel, h.dut.w_ctrl_bit));
            fnd_now(f);
            h.note($sformatf("FND now \"%s\"", f));
            cap("P1-A", t0, t0 + 26 * MSN, "overview : switch -> /mod dist -> switches ignored");
            cap("P1-B", t_last_b - 0.1 * MSN, tb + 0.1 * MSN, "zoom : last byte 't' -> handshake -> ctrl_bit / disp_sel");
            at(26.0);
        end

        // ============================================================ P2 /btn R -> SR04 -> /get
        if (h.run("P2")) begin
            scene_start("P2", "/btn R -> SR04 measure -> /get",
                        "/mod dist @1 ms, /btn R @12 ms (echo 7,134 us = 123.0 cm), /get @32 ms",
                        "uart btn pulse -> trig 11 us -> echo -> 123.0 on FND -> line 123cm");
            h.sr_w_us = 7134;
            at(1.0);  step("/mod dist");  h.mod("dist");
            at(12.0); step("/btn R");     tc = $realtime;
            h.ubtn("R");
            h.wait_us(20);
            t_hs1 = h.t_hs;
            h.wait_dist_done(40, ok);
            tr = h.t_trig_r; tf = h.t_trig_f; er = h.t_echo_r; ef = h.t_echo_f; dn = h.t_dist_done;
            h.wait_ms(1);
            fnd_now(f);
            h.check("P2-1", ok && (h.dist_st == 0) && (h.dut.w_distance == 123) && (h.dut.w_distance_x10 == 1230)
                    && (f == "1230") && near(h.trig_w, 11 * USN, 20),
                    "/btn R -> measure", "status 0, 123 cm, x10 1230, FND 123.0, trig 11 us",
                    $sformatf("status %0d, %0d cm, x10 %0d, FND %s, trig %0.3f us", h.dist_st, h.dut.w_distance,
                              h.dut.w_distance_x10, f, h.trig_w / USN));
            h.note($sformatf("handshake %0.4f | uart_btn_R %0.4f | trig %0.4f ~ %0.4f | echo %0.4f ~ %0.4f | done %0.4f ms",
                             rel(t_hs1), rel(h.t_uc[BR]), rel(tr), rel(tf), rel(er), rel(ef), rel(dn)));
            at(32.0); step("/get");
            get_line(s, t_cmd, ta, tb);
            h.check("P2-2", (s == "123cm") && (ta - h.t_hs < 0.1 * MSN), "/get on distance screen", "123cm, first byte < 0.1 ms",
                    $sformatf("\"%s\", first byte %0.1f us after handshake, line %0.4f ~ %0.4f ms", s, (ta - h.t_hs) / USN,
                              rel(ta), rel(tb)));
            cap("P2-A", tc - 0.5 * MSN, dn + 1.5 * MSN, "/btn R -> trig -> echo 7.134 ms -> 123.0");
            cap("P2-B", t_hs1 - 5 * USN, tf + 5 * USN, "zoom : handshake -> uart_btn_R -> btn_R -> trig 11 us");
            cap("P2-C", t_cmd - 0.5 * MSN, tb + 0.5 * MSN, "/get -> send_go -> tx 123cm");
            at(48.0);
        end

        // ============================================================ P3 /auto all (1 Hz)
        if (h.run("P3")) begin
            scene_start("P3", "/auto all at real 1 Hz",
                        "SW run, timer 1 min run, SR04 123 cm, DHT 55/24, then /auto all @100 ms",
                        "5 lines SW TM WH DIST TEMP, send_go exactly 1.000 000 s apart, first = handshake + 1 s");
            h.sr_w_us = 7134;
            at(1.0);   step("/mod s_ms");  h.mod("s_ms");
            at(12.0);  step("/btn R sw");  h.ubtn("R");      // 스톱워치 RUN
            at(20.0);  step("/mod t_ms");  h.mod("t_ms");
            at(31.0);  step("/btn R tm");  h.ubtn("R");      // 타이머 +1 분
            at(39.0);  step("/btn L tm");  h.ubtn("L");      // 타이머 시작
            at(47.0);  step("/mod dist");  h.mod("dist");
            at(58.0);  step("/btn R dist"); h.ubtn("R");     // SR04 측정 123 cm
            at(74.0);  step("/mod temp");  h.mod("temp");
            at(85.0);  step("/btn R temp"); h.ubtn("R");     // DHT11 : 부팅 1 s 뒤 측정
            at(100.0); step("/auto all");  tc = $realtime;
            h.flush_lines();
            h.uart_send("/auto all");
            h.wait_us(20);
            t_hs1 = h.t_hs;
            clk_go_last = 0;
            t_go_q.delete();
            for (int i = 0; i < 5; i++) begin
                h.next_line(ls[i], lt0[i], 1500 * MSN);
                lt1[i] = h.last_t1;
                h.note($sformatf("auto line %0d \"%s\"  %0.4f ~ %0.4f ms", i + 1, ls[i], rel(lt0[i]), rel(lt1[i])));
            end
            h.check("P3-1", h.is_time(ls[0]) && h.is_time(ls[1]) && h.is_time(ls[2]) && (ls[3] == "123cm")
                    && (ls[4] == "55%24C"), "order / format", "SW time, TM time, WH time, 123cm, 55%24C",
                    $sformatf("%s | %s | %s | %s | %s", ls[0], ls[1], ls[2], ls[3], ls[4]));
            h.check("P3-2", (t_go_q.size() >= 1) && near(t_go_q[0] - t_hs1, 1000 * MSN, 1 * USN), "first send_go",
                    "handshake + 1.000 000 s (+- 1 us)",
                    $sformatf("%0.6f ms after handshake (%0.4f ms)", (t_go_q[0] - t_hs1) / MSN, rel(t_hs1)));
            gap_ok = (t_go_q.size() == 5);
            for (int i = 0; i < 4; i++) if (gap_ok) gap_ok = near(t_go_q[i + 1] - t_go_q[i], 1000 * MSN, 10.5);
            h.check("P3-3", gap_ok, "send_go interval", "1.000 000 s (+- 1 clk) x 4",
                    $sformatf("n %0d, last GO_GAP_CLK %0d", t_go_q.size(), GO_GAP_CLK));
            lgap_ok = 1;
            for (int i = 0; i < 4; i++) begin
                g = lt0[i + 1] - lt0[i];
                lgap_ok = lgap_ok && near(g, 1000 * MSN, 10 * USN);
                h.note($sformatf("line %0d -> %0d start gap %0.6f ms", i + 1, i + 2, g / MSN));
            end
            h.check("P3-4", lgap_ok, "tx line start interval", "1.000 s +- 10 us (tx bit alignment)", "see NOTE");
            cap("P3-A", tc - 50 * MSN, lt1[4] + 50 * MSN, "overview : /auto all -> 5 lines, 1.000 s apart");
            cap("P3-B", t0, tc + 15 * MSN, "setup : /mod + /btn commands before /auto");
            for (int i = 0; i < 5; i++)
                cap($sformatf("P3-L%0d", i + 1), lt0[i] - 1 * MSN, lt1[i] + 1 * MSN, $sformatf("zoom line %0d \"%s\"", i + 1, ls[i]));
            cap("P3-G", lt0[0] - 50 * MSN, lt1[1] + 50 * MSN, "line 1 -> line 2 : measure 1.000 s with 2 cursors");
            h.wait_until(lt1[4] + 60 * MSN);
        end

        // ============================================================ P4 ERROR
        if (h.run("P4")) begin
            scene_start("P4", "format error /gxt -> ERROR",
                        "/gxt @1 ms, /get @14 ms",
                        "ERROR exactly 1 line within 0.1 ms of the bad byte, then /get answers normally");
            at(1.0);  step("/gxt");  tc = $realtime;
            h.flush_lines();
            h.uart_send("/gxt");
            h.next_line(s, ta, 40 * MSN);
            tb = h.last_t1;
            at(13.0);
            h.check("P4-1", (s == "ERROR") && (h.lines_pending() == 0) && (ta - t_err >= 0) && (ta - t_err < 0.1 * MSN),
                    "/gxt", "1 line ERROR, starts < 0.1 ms after error",
                    $sformatf("\"%s\", extra %0d, error %0.4f ms, line %0.4f ~ %0.4f ms", s, h.lines_pending(), rel(t_err),
                              rel(ta), rel(tb)));
            cap("P4-A", tc - 0.5 * MSN, tb + 0.5 * MSN, "/gxt -> error -> ERROR line");
            cap("P4-B", t_err - 1.1 * MSN, ta + 1.2 * MSN, "zoom : bad byte 'x' -> w_error -> send_go(sel 7) -> 'E'");
            at(14.0); step("/get");
            get_line(s, t_cmd, ta, tb);
            h.check("P4-2", h.is_time(s), "/get after ERROR", "normal time line (switch mode = watch)",
                    $sformatf("\"%s\" %0.4f ~ %0.4f ms", s, rel(ta), rel(tb)));
            cap("P4-C", t_cmd - 0.5 * MSN, tb + 0.5 * MSN, "/get after ERROR -> normal line");
            at(36.0);
        end

        // ============================================================ P5 SR04 Err1~3
        if (h.run("P5")) begin
            scene_start("P5", "SR04 Err1 / Err2 / Err3",
                        "/mod dist ; Err1 no echo @12 ms ; Err2 echo 23,250 us @82 ms ; Err3 echo stuck @152 ms ; /get after each",
                        "FND Err1/Err2/Err3 and PC Err 1/Err 2/Err 3, LD9 on");
            at(1.0);  step("/mod dist");  h.mod("dist");
            // ---- Err1 : echo 없음 → trig↓ + 30 ms
            at(12.0); step("Err1 no echo");  tc = $realtime;
            h.sr_mode = h.SR_NONE;
            h.ubtn("R");
            h.wait_dist_done(60, ok);
            tr = h.t_trig_r; tf = h.t_trig_f; dn = h.t_dist_done; st = h.dist_st;
            h.wait_ms(1);
            fnd_now(f1);
            at(55.0); step("/get Err1");
            get_line(s1, t_cmd, ta, tb);
            h.check("P5-1", ok && (st == 1) && near(dn - tf, 30 * MSN, 3 * USN) && (f1 == "Err1") && (s1 == "Err 1") && (LD9 == 1),
                    "Err1 no echo", "status 1 at trig fall + 30.000 ms, FND Err1, PC Err 1, LD9",
                    $sformatf("status %0d at +%0.4f ms (trig %0.4f, done %0.4f), FND %s, \"%s\", LD9 %b",
                              st, (dn - tf) / MSN, rel(tr), rel(dn), f1, s1, LD9));
            cap("P5-B1", tc - 0.5 * MSN, tb + 0.5 * MSN, "Err1 : /btn R -> trig -> 30 ms no echo -> Err1 -> /get Err 1");
            cap("P5-B2", tf - 1 * MSN, dn + 1 * MSN, "Err1 timing : trig fall -> done (cursor 30.000 ms)");
            // ---- Err2 : echo 23.25 ms (400 cm 초과) → echo↑ + 23.2 ms
            at(82.0); step("Err2 long echo");  tc = $realtime;
            h.sr_mode = h.SR_NORMAL;
            h.sr_w_us = 23250;
            h.ubtn("R");
            h.wait_dist_done(60, ok);
            er = h.t_echo_r; dn = h.t_dist_done; st = h.dist_st;
            h.wait_ms(1);
            fnd_now(f2);
            at(118.0); step("/get Err2");
            get_line(s2, t_cmd, ta, tb);
            h.check("P5-2", ok && (st == 2) && near(dn - er, 23.2 * MSN, 3 * USN) && (f2 == "Err2") && (s2 == "Err 2"),
                    "Err2 out of range", "status 2 at echo rise + 23.200 ms, FND Err2, PC Err 2",
                    $sformatf("status %0d at +%0.4f ms (echo %0.4f, done %0.4f), FND %s, \"%s\"",
                              st, (dn - er) / MSN, rel(er), rel(dn), f2, s2));
            cap("P5-C1", tc - 0.5 * MSN, tb + 0.5 * MSN, "Err2 : /btn R -> echo too long -> Err2 -> /get Err 2");
            cap("P5-C2", er - 1 * MSN, dn + 1 * MSN, "Err2 timing : echo rise -> done (cursor 23.200 ms)");
            // ---- Err3 : echo 가 계속 1 → 23.2 ms Err2 → 73.2 ms Err3 → IDLE
            at(152.0); step("Err3 echo stuck");
            h.sr_mode = h.SR_MANUAL;
            h.echo = 1'b1;
            at(154.0); step("/btn R (stuck)");  tc = $realtime;
            h.ubtn("R");
            h.wait_dist_done(60, ok_a);
            dn_a = h.t_dist_done; st_a = h.dist_st; tf = h.t_trig_f;
            h.wait_dist_done(80, ok_b);
            dn = h.t_dist_done; st = h.dist_st;
            h.wait_ms(1);
            fnd_now(f3);
            at(240.0); step("/get Err3");
            get_line(s3, t_cmd, ta, tb);
            at(255.0); step("echo released");
            h.echo = 1'b0;
            h.check("P5-3", ok_a && ok_b && (st_a == 2) && (st == 3) && near(dn - tf, 73.2 * MSN, 5 * USN) && (f3 == "Err3")
                    && (s3 == "Err 3"), "Err3 echo stuck",
                    "Err2 at trig fall + 23.2 ms, Err3 at + 73.200 ms, FND Err3, PC Err 3",
                    $sformatf("1st status %0d at +%0.4f, 2nd status %0d at +%0.4f ms (done %0.4f), FND %s, \"%s\"",
                              st_a, (dn_a - tf) / MSN, st, (dn - tf) / MSN, rel(dn), f3, s3));
            cap("P5-D1", tc - 3 * MSN, tb + 0.5 * MSN, "Err3 : echo stuck -> Err2 (23.2) -> Err3 (73.2) -> /get Err 3");
            cap("P5-D2", tf - 1 * MSN, dn + 1 * MSN, "Err3 timing : trig fall -> Err2 -> Err3 (cursors 23.2 / 73.2 ms)");
            cap("P5-A", t0, t0 + 258 * MSN, "overview : Err1 -> Err2 -> Err3 (FND + PC + LD9)");
            at(258.0);
        end

        // ============================================================ P6 DHT11 Err1~3
        if (h.run("P6")) begin
            scene_start("P6", "DHT11 --%--C / Err1 / Err2 / Err3",
                        "/mod temp ; /get before first measure ; Err1 no response (1 s) ; Err2 20 bits (3 s) ; Err3 checksum (5 s)",
                        "PC --%--C then Err 1 / Err 2 / Err 3, FND ---- then Err1 / Err2 / Err3");
            at(1.0);  step("/mod temp");  h.mod("temp");
            at(12.0); step("/get no data");
            get_line(s, t_cmd, ta, tb);
            fnd_now(f);
            h.check("P6-0", (s == "--%--C") && (f == "----"), "before first measure", "PC --%--C, FND ----",
                    $sformatf("\"%s\", FND %s", s, f));
            cap("P6-B", t_cmd - 0.5 * MSN, tb + 0.5 * MSN, "/get before measure -> --%--C");
            // ---- Err1 : 응답 없음 (부팅 1 s 뒤 첫 측정)
            at(30.0); step("Err1 no response");
            h.dh_mode = h.DH_NONE;
            h.ubtn("R");
            h.wait_dht_done(1500, ok);
            oe_r = h.t_oe_r; oe_f = h.t_oe_f; dn = h.t_dht_done; st = h.dht_st;
            h.wait_ms(1);
            fnd_now(f1);
            at(1030.0); step("/get Err1");
            get_line(s1, t_cmd, ta, tb);
            h.check("P6-1", ok && (st == 1) && (f1 == "Err1") && (s1 == "Err 1"), "Err1 no response",
                    "status 1, FND Err1, PC Err 1",
                    $sformatf("status %0d, start LOW %0.4f ~ %0.4f, done %0.4f ms (+%0.1f us after release), FND %s, \"%s\"",
                              st, rel(oe_r), rel(oe_f), rel(dn), (dn - oe_f) / USN, f1, s1));
            cap("P6-C1", oe_r - 1 * MSN, dn + 1 * MSN, "Err1 : start LOW 18 ms -> no response -> Err1");
            cap("P6-C2", t_cmd - 0.5 * MSN, tb + 0.5 * MSN, "/get -> Err 1");
            // ---- Err2 : 20 비트 뒤 끊김 (이전 시작 + 2 s)
            at(1050.0); step("Err2 cut 20 bits");
            h.dh_default();
            h.dh_nbits = 20;
            h.ubtn("R");
            h.wait_dht_done(2500, ok);
            oe_r = h.t_oe_r; oe_f = h.t_oe_f; dn = h.t_dht_done; st = h.dht_st;
            h.wait_ms(1);
            fnd_now(f2);
            at(3030.0); step("/get Err2");
            get_line(s2, t_cmd, ta, tb);
            h.check("P6-2", ok && (st == 2) && (f2 == "Err2") && (s2 == "Err 2"), "Err2 cut", "status 2, FND Err2, PC Err 2",
                    $sformatf("status %0d, start LOW %0.4f ~ %0.4f, done %0.4f ms, FND %s, \"%s\"",
                              st, rel(oe_r), rel(oe_f), rel(dn), f2, s2));
            cap("P6-D1", oe_r - 1 * MSN, dn + 1 * MSN, "Err2 : start -> 20 bits -> line stops -> Err2");
            cap("P6-D2", oe_f - 0.1 * MSN, dn + 0.3 * MSN, "Err2 zoom : response + 20 bits -> 0.2 ms timeout");
            cap("P6-D3", t_cmd - 0.5 * MSN, tb + 0.5 * MSN, "/get -> Err 2");
            // ---- Err3 : 체크섬 +1
            at(3050.0); step("Err3 checksum+1");
            h.dh_default();
            h.dh_chk_off = 1;
            h.ubtn("R");
            h.wait_dht_done(2500, ok);
            oe_r = h.t_oe_r; oe_f = h.t_oe_f; dn = h.t_dht_done; st = h.dht_st;
            h.wait_ms(1);
            fnd_now(f3);
            at(5030.0); step("/get Err3");
            get_line(s3, t_cmd, ta, tb);
            h.check("P6-3", ok && (st == 3) && (f3 == "Err3") && (s3 == "Err 3"), "Err3 checksum", "status 3, FND Err3, PC Err 3",
                    $sformatf("status %0d, start LOW %0.4f ~ %0.4f, done %0.4f ms, FND %s, \"%s\"",
                              st, rel(oe_r), rel(oe_f), rel(dn), f3, s3));
            cap("P6-E1", oe_r - 1 * MSN, dn + 1 * MSN, "Err3 : start -> 40 bits -> checksum mismatch -> Err3");
            cap("P6-E2", t_cmd - 0.5 * MSN, tb + 0.5 * MSN, "/get -> Err 3");
            cap("P6-A", t0, tb + 3 * MSN, "overview : --%--C -> Err1 (1 s) -> Err2 (3 s) -> Err3 (5 s)");
            h.wait_until(tb + 3 * MSN);
        end

        // ---------------------------------------------------------------- 캡처 구간 모음
        $display("");
        $display("==========================================================================================");
        $display("  CAPTURE windows (scene time ms ; run one scene alone => scene time = sim time)");
        foreach (caps[i]) $display("  %s", caps[i]);
        h.finish_tb();
    end

endmodule
