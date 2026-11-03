`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// [Vivado 에서 실행]  (자세한 것은 같은 폴더 README.md)
//   1) Design Sources : verification_v2/source_file/*.v, *.sv (+ stopwatch_watch.xdc 는 필요 없음)
//   2) Simulation Sources : 이 파일 + 같은 폴더의 fnd_monitor.sv  → 이 파일을 Set as Top
//   3) Run Simulation → Run All.  콘솔의 [FAIL]/[DEFECT] 시각으로 파형 창에서 Go To Time
//   * Phase 하나만 보려면 아래 RUN_PHASE 를 그 번호로 (긴 TB 는 이게 빠름)
//   * 파형에서 clk 는 빼고 보는 것을 권장 (수 초 시뮬이면 파형 파일이 매우 커짐)
//   * 콘솔 읽는 법 (줄 맨 앞 [시각] = 파형 Go To Time 에 넣을 시각)
//       [BEGIN  ] Phase 시작 + plan (TB 가 할 일) / expect (정상 결과)
//       [RESET  ] [SW     ] [BTN    ] [WAIT   ]  TB 가 한 일, 오른쪽은 그 전 -> 후 (지금 화면 값 · FSM 상태)
//       [PRELOAD] TB 가 카운터에 값을 직접 넣음 (버튼 아님, DUT 동작 아님) — 경계값 바로 앞으로 건너뛰기
//       [OK     ] / [FAIL   ] 검사 1 건 (exp = 기대, got = 실제)
// -----------------------------------------------------------------------------
// =============================================================================
// tb_sw_1_run_stop_clear — STOPWATCH (jonghyuk)
//   P1 리셋 · P2 RUN 1 s 실측(SC3, FSM 신호 기준) · P3 STOP 유지 200 ms · P4 STOP 클리어(+랩 해제)
//   P5 RUN 중 L·U 무시 (SB5, SB6) · P6 STOP 에서 R+L 동시 → RUN + 0 (SB7, LIMIT)
//   P7 시계 화면에서 백그라운드 증가 + 시계 버튼 게이팅 (SC5)
// =============================================================================
module tb_sw_1_run_stop_clear;
    // =========================================================================
    // 사용자 설정
    // =========================================================================
    localparam integer RUN_PHASE     = -1;     // -1 = 모든 Phase, N = Phase N 만 실행 (파형 볼 구간만 짧게)
    localparam string  TB_ID         = "SW1";
    localparam integer TB_TIMEOUT_MS = 6000;    // 이 시뮬 시각(ms)이 지나면 TIMEOUT 으로 끝냄

    // =========================================================================
    // DUT : Top (stopwatch_watch) — 보드 핀과 같은 이름 (block_diagram.pdf 의 'Top 입력 / 출력' 과 같음)
    // =========================================================================
    reg clk = 1'b0;
    reg rst = 1'b0;                // btnC. do_reset() 이 0->1 을 만들어야 비동기 리셋이 걸린다
    reg btn_R = 1'b0, btn_L = 1'b0, btn_U = 1'b0, btn_D = 1'b0;
    reg mode_sw0 = 1'b0;           // sw0 : 0 시계 / 1 스톱워치
    reg display_mode_sw1 = 1'b0;   // sw1 : 0 초.1/100 / 1 시.분
    reg set_sw2 = 1'b0;            // sw2 : 시계 설정
    reg hour24_sw3 = 1'b0;         // sw3 : 0 12시간 / 1 24시간
    reg timer_sw4 = 1'b0;          // sw4 : 타이머 화면 (sw0 보다 우선)
    wire [3:0]  fnd_com;
    wire [7:0]  fnd_font;
    wire [15:0] led;

    always #5 clk = ~clk;   // 100 MHz (주파수 줄이지 않음)

    stopwatch_watch dut (
        .clk             (clk),
        .rst             (rst),
        .btn_R           (btn_R),
        .btn_L           (btn_L),
        .btn_U           (btn_U),
        .btn_D           (btn_D),
        .mode_sw0        (mode_sw0),
        .display_mode_sw1(display_mode_sw1),
        .set_sw2         (set_sw2),
        .hour24_sw3      (hour24_sw3),
        .timer_sw4       (timer_sw4),
        .fnd_com         (fnd_com),
        .fnd_font        (fnd_font),
        .led             (led)
    );

    // =========================================================================
    // 파형 : TB 별칭 와이어 없음. 같은 폴더 README.md 의 "단계" 표대로
    //        Scope 창 dut → U_xxx 인스턴스를 골라 o_ 포트를 Wave 에 넣는다
    //        (포트 · 선 이름은 ../../block_diagram.pdf, ../../source_file/PORT_MAP.md 와 같음)
    // =========================================================================

    // FND 해석기 + 참조 모델 (같은 폴더의 fnd_monitor.sv 를 같이 추가할 것)
    //   입력 = U_FND_CONTROLLER 의 입력 포트와 같은 선 + Top 출력 fnd_com / fnd_font
    fnd_monitor mon (
        .i_fnd_com  (fnd_com),
        .i_fnd_font (fnd_font),
        .i_scan_sel (dut.U_FND_CONTROLLER.w_scan_sel),
        .i_disp_mode(dut.w_disp_mode),
        .i_disp_hour(dut.w_disp_hour),
        .i_disp_min (dut.w_disp_min),
        .i_disp_sec (dut.w_disp_sec),
        .i_disp_msec(dut.w_disp_msec),
        .i_wt_cursor(dut.w_wt_cursor),
        .i_set_sw2  (set_sw2),
        .i_sel_wt   (dut.w_sel_wt)
    );

    // =========================================================================
    // 공통 부품 (로그 · 검사 · 버튼/스위치 자극 · 프리로드) — 수정할 필요 없음
    // =========================================================================
    // ---------------------------------------------------------------- 상수
    localparam integer BR = 0, BL = 1, BU = 2, BD = 3;
    localparam longint MS = 64'd1_000_000;  // 1 ms in ns
    localparam longint US = 64'd1_000;      // 1 us in ns

    // ---------------------------------------------------------------- 상태
    integer n_checks = 0, n_fail = 0, n_defect = 0, n_limit = 0;
    integer phase_no = 0, phase_fail0 = 0, phase_chk0 = 0, phase_def0 = 0;
    realtime phase_t0 = 0;
    integer phase_sel = RUN_PHASE;   // 맨 위 RUN_PHASE (또는 +phase=N) 로 Phase 하나만 실행
    bit     wave_en = 0;
    string  wave_path = "";
    string  src_tag = "orig";
    realtime first_bad_t = -1;
    bit     in_reset_seq = 0;   // do_reset() 안에서만 1 (F4 감시용)
    bit     started = 0;        // 첫 리셋 해제 뒤 1 (그 전 X 구간은 검사 안 함)
    bit     mm_is_defect = 0;   // 1 이면 FND 불일치를 DEFECT 로 기록 (F1)
    string  fid [0:63];
    integer fcnt[0:63];
    integer n_fid = 0;

    // 디바운서 출력 펄스 카운터 : 0 R, 1 L, 2 U, 3 D
    integer pc[0:3];
    integer pw_bad = 0;
    reg [3:0] last_pv = 4'b0;   // 마지막 디바운서 펄스의 {D,U,L,R} (동시 펄스 확인용)
    realtime  last_pt = 0;      // 마지막 디바운서 펄스 시각
    initial begin pc[0] = 0; pc[1] = 0; pc[2] = 0; pc[3] = 0; end

    // ---------------------------------------------------------------- 로그
    function automatic string bname(input integer b);
        case (b) 0: bname = "btn_R"; 1: bname = "btn_L"; 2: bname = "btn_U"; default: bname = "btn_D"; endcase
    endfunction

    function automatic string hmsc(input integer h, input integer m, input integer s, input integer c);
        hmsc = $sformatf("%02d:%02d:%02d.%02d", h, m, s, c);
    endfunction

    // [시각] [종류] P번호.검사ID  내용 | exp= got=   (FAIL · DEFECT 만 FND 화면 문자열 덧붙임)
    function automatic void log_line_t(input realtime t, input string lvl, input string cid, input string desc,
                                       input string exp_s, input string got_s);
        string s, tag;
        tag = (cid == "-") ? $sformatf("P%0d", phase_no) : $sformatf("P%0d.%s", phase_no, cid);
        s = $sformatf("[%t] [%-7s] %-9s %s", t, lvl, tag, desc);
        if (exp_s != "" || got_s != "") s = $sformatf("%s | exp=%s got=%s", s, exp_s, got_s);
        if (lvl == "FAIL" || lvl == "DEFECT") s = $sformatf("%s | disp=\"%s\"", s, mon.disp_str);
        $display("%s", s);
        $fflush();   // 중간에 멈춰도 이상 시각이 로그에 남도록
    endfunction

    function automatic void log_line(input string lvl, input string cid, input string desc, input string exp_s, input string got_s);
        log_line_t($realtime, lvl, cid, desc, exp_s, got_s);
    endfunction

    // TB 입력 1 건 : 시각 t 에 한 일 + 그 전 -> 후 상태 (ui_state)
    function automatic void step(input realtime t, input string lvl, input string what, input string s0, input string s1);
        log_line_t(t, lvl, "-", $sformatf("%-44s %s", what, state_diff(s0, s1)), "", "");
    endfunction

    function automatic integer note_id(input string cid);
        integer i;
        for (i = 0; i < n_fid; i = i + 1)
            if (fid[i] == cid) begin
                fcnt[i] = fcnt[i] + 1;
                return fcnt[i];
            end
        if (n_fid < 64) begin
            fid[n_fid]  = cid;
            fcnt[n_fid] = 1;
            n_fid = n_fid + 1;
        end
        return 1;
    endfunction

    // 검사 1건. 통과는 [OK], 실패는 같은 ID 처음 5번만 출력
    function automatic void check(input string cid, input bit ok, input string desc, input string exp_s, input string got_s);
        n_checks = n_checks + 1;
        if (ok) log_line("OK", cid, desc, exp_s, got_s);
        if (!ok) begin
            n_fail = n_fail + 1;
            if (first_bad_t < 0) first_bad_t = $realtime;
            if (note_id(cid) <= 5) log_line("FAIL", cid, desc, exp_s, got_s);
        end
    endfunction

    function automatic void defect_at(input string cid, input realtime t, input string desc, input string exp_s, input string got_s);
        n_defect = n_defect + 1;
        if (first_bad_t < 0 || t < first_bad_t) first_bad_t = t;
        if (note_id({"D:", cid}) <= 5) begin
            log_line("DEFECT", cid, desc, exp_s, got_s);
            $display("    wave window: %t ~ %t", t - 1.0e6, t + 1.0e6);
            $fflush();
        end
    endfunction

    function automatic void defect(input string cid, input string desc, input string exp_s, input string got_s);
        defect_at(cid, $realtime, desc, exp_s, got_s);
    endfunction

    function automatic void limit(input string cid, input string desc);
        n_limit = n_limit + 1;
        log_line("LIMIT", cid, desc, "", "");
    endfunction

    function automatic void info(input string cid, input string desc);
        log_line("INFO", cid, desc, "", "");
    endfunction

    // ---------------------------------------------------------------- Phase
    function automatic bit phase_begin(input integer n, input string name);
        phase_no = n;
        if (phase_sel >= 0 && n != phase_sel) begin
            log_line("PHASE", "-", {"SKIP (+phase) ", name}, "", "");
            return 0;
        end
        phase_t0    = $realtime;
        phase_fail0 = n_fail;
        phase_chk0  = n_checks;
        phase_def0  = n_defect;
        $display("");
        $display("==========================================================================================");
        log_line("BEGIN", "-", name, "", "");
    `ifndef VERILATOR
        if (wave_en && phase_sel >= 0) $dumpon;
    `endif
        return 1;
    endfunction

    task automatic phase_end();
        integer nf, nc, nd;
        nf = n_fail - phase_fail0;
        nc = n_checks - phase_chk0;
        nd = n_defect - phase_def0;
        if (mon.mm && ($realtime - mon.mm_t0) > 1000.0)
            check("FND", 0, "FND output stuck different from reference at phase end", "match", mon.mm_desc);
        log_line(nf == 0 ? "PASS" : "FAIL", "-",
                 $sformatf("END  checks=%0d fail=%0d defect=%0d (%0.3f ms)", nc, nf, nd, ($realtime - phase_t0) / 1.0e6),
                 "", "");
    `ifndef VERILATOR
        if (wave_en && phase_sel >= 0) $dumpoff;
    `endif
    endtask

    // Phase 시작 직후 한 번 : TB 가 할 일 / 정상 결과 (README 'Phase 별로 볼 곳' 표와 같음)
    function automatic void phase_plan(input string plan, input string expect_s);
        $display("              plan   : %s", plan);
        $display("              expect : %s", expect_s);
        $display("------------------------------------------------------------------------------------------");
    endfunction

    task automatic phase_skip(input integer n, input string name, input string why);
        phase_no = n;
        log_line("PHASE", "-", {"SKIP ", name, " : ", why}, "", "");
    endtask

    task automatic tb_finish();
        string res, fb;
        if (first_bad_t < 0) fb = "-";
        else fb = $sformatf("%0.6f ms", first_bad_t / 1.0e6);
        if (n_fail > 0) res = "FAIL";
        else if (n_defect > 0) res = "DETECTED";
        else res = "PASS";
        $display("[%t] [SUMMARY] %s src=%s checks=%0d fail=%0d defect=%0d limit=%0d first_bad=%s => %s",
                 $realtime, TB_ID, src_tag, n_checks, n_fail, n_defect, n_limit,
                 fb, res);
        $finish;
    endtask

    // ---------------------------------------------------------------- 초기화 · watchdog
    initial begin
        $timeformat(-3, 3, " ms", 11);
        if ($value$plusargs("phase=%d", phase_sel)) ;
        if ($value$plusargs("src=%s", src_tag)) ;
    `ifndef VERILATOR
        if ($value$plusargs("wave=%s", wave_path)) begin
            wave_en = 1;
            $dumpfile(wave_path);
            $dumpvars(0);
            if (phase_sel >= 0) $dumpoff;
        end
    `endif
    end

    initial begin
        #(TB_TIMEOUT_MS * MS);   // watchdog
        check("TIMEOUT", 0, $sformatf("watchdog %0d ms expired", TB_TIMEOUT_MS), "finish", "timeout");
        tb_finish();
    end

    // ---------------------------------------------------------------- 펄스 모니터
    // 디바운서 출력 w_btnX 는 정확히 1클럭(10 ns) 펄스여야 한다
    // (트리거 하나로 4 개를 같이 본다)
    wire [3:0] btn_pulse = {dut.w_btn_D, dut.w_btn_U, dut.w_btn_L, dut.w_btn_R};  // U_BD_D/U/L/R.o_btn
    wire       w_btn_any = |btn_pulse;
    always @(posedge w_btn_any) begin : pmon
        realtime t;
        reg [3:0] b;
        integer i;
        t = $realtime;
        #1;              // 같은 클럭의 다른 버튼 펄스가 다음 델타에 올라와도 같이 읽기
        b = btn_pulse;
        last_pv = b;
        last_pt = t;
        for (i = 0; i < 4; i = i + 1) if (b[i]) pc[i] = pc[i] + 1;
        @(negedge w_btn_any);
        if (($realtime - t) < 9.999 || ($realtime - t) > 10.001) begin
            pw_bad = pw_bad + 1;
            check("PW", 0, $sformatf("debouncer pulse width != 1 clk (U_BD_{D,U,L,R}.o_btn=%b)", b), "10.000 ns",
                  $sformatf("%0.3f ns", $realtime - t));
        end
    end

    // FND 참조 비교 불일치 — 구간이 끝날 때마다 로그
    integer mm_seen = 0;
    always @(mon.mm_count) begin
        if (mon.mm_count > mm_seen) begin
            mm_seen = mon.mm_count;
            if (started && !in_reset_seq)
            if (mm_is_defect)
                defect_at("FND", mon.mm_last_t, $sformatf("FND output != reference for %0.3f us from %t (%s)",
                                        mon.mm_last_dur / 1000.0, mon.mm_last_t, mon.mm_desc), "ref", "mismatch");
            else if (started && !in_reset_seq)
                check("FND", 0, $sformatf("FND output != reference for %0.3f us from %t (%s)",
                                          mon.mm_last_dur / 1000.0, mon.mm_last_t, mon.mm_desc), "ref", "mismatch");
        end
    end

    // ---------------------------------------------------------------- 자극 태스크
    task automatic set_btn(input integer b, input bit v);
        case (b)
            0: btn_R = v;
            1: btn_L = v;
            2: btn_U = v;
            default: btn_D = v;
        endcase
    endtask

    task automatic do_reset();
        realtime t;
        string   s0;
        @(negedge clk);
        t  = $realtime;
        s0 = started ? ui_state() : "";   // 첫 리셋 전 값은 의미 없음 (X)
        in_reset_seq = 1;
        rst = 1'b1;
        #(US);
        rst = 1'b0;
        in_reset_seq = 0;
        started = 1;
        #(US);
        step(t, "RESET", "rst 1 us pulse", s0 == "" ? ui_state() : s0, ui_state());
    endtask

    // 누름 hi ns, 뗌 lo ns. 항상 negedge 에 맞춰 시작 (샘플 엣지와 경쟁 없음)
    task automatic press_ns(input integer b, input longint hi, input longint lo);
        realtime t;
        string   s0;
        integer  n0;
        @(negedge clk);
        t  = $realtime;
        s0 = ui_state();
        n0 = pc[b];
        set_btn(b, 1'b1);
        #(hi);
        set_btn(b, 1'b0);
        #(lo);
        step(t, "BTN", {bname(b), " ", pulse_at(pc[b] != n0)}, s0, ui_state());
    endtask

    task automatic press(input integer b);  // 표준: 누름 5 ms + 뗌 5 ms
        press_ns(b, 5 * MS, 5 * MS);
    endtask

    task automatic press_n(input integer b, input integer n);
        integer i;
        for (i = 0; i < n; i = i + 1) press(b);
    endtask

    // 두 버튼을 같은 시각에 누름 (SB7)
    task automatic press2(input integer b1, input integer b2);
        realtime t;
        string   s0;
        integer  n0;
        @(negedge clk);
        t  = $realtime;
        s0 = ui_state();
        n0 = pc[b1];
        set_btn(b1, 1'b1);
        set_btn(b2, 1'b1);
        #(5 * MS);
        set_btn(b1, 1'b0);
        set_btn(b2, 1'b0);
        #(5 * MS);
        step(t, "BTN", {bname(b1), "+", bname(b2), " same time ", pulse_at(pc[b1] != n0)}, s0, ui_state());
    endtask

    // 바운스 패턴 (결정적)
    task automatic press_bounce(input integer b);
        realtime t;
        string   s0;
        integer  n0;
        @(negedge clk);
        t  = $realtime;
        s0 = ui_state();
        n0 = pc[b];
        set_btn(b, 1); #(40 * US);  set_btn(b, 0); #(60 * US);
        set_btn(b, 1); #(120 * US); set_btn(b, 0); #(30 * US);
        set_btn(b, 1); #(300 * US); set_btn(b, 0); #(80 * US);
        set_btn(b, 1); #(20 * MS);
        set_btn(b, 0); #(50 * US);  set_btn(b, 1); #(100 * US);
        set_btn(b, 0); #(70 * US);  set_btn(b, 1); #(400 * US);
        set_btn(b, 0); #(5 * MS);
        step(t, "BTN", {bname(b), " with bounce ", pulse_at(pc[b] != n0)}, s0, ui_state());
    endtask

    // 스위치: {sw4 timer, sw3 24h, sw2 set, sw1 disp, sw0 mode}
    task automatic set_sw(input bit timer, input bit h24, input bit set, input bit disp, input bit mode);
        realtime t;
        string   s0;
        @(negedge clk);
        t  = $realtime;
        s0 = ui_state();
        timer_sw4 = timer;
        hour24_sw3 = h24;
        set_sw2 = set;
        display_mode_sw1 = disp;
        mode_sw0 = mode;
        #(US);
        step(t, "SW", $sformatf("sw4..0=%b%b%b%b%b %s", timer, h24, set, disp, mode, sw_name()), s0, ui_state());
    endtask

    // 100 Hz tick 동기: tick 직후 carry 체인(최대 4클럭)이 다 끝난 negedge
    task automatic tick_sync();
        @(posedge dut.w_tick_10ms);
        repeat (5) @(negedge clk);
    endtask

    task automatic wait_ticks(input integer n);
        realtime t;
        string   s0;
        t  = $realtime;
        s0 = ui_state();
        repeat (n) @(posedge dut.w_tick_10ms);
        repeat (5) @(negedge clk);
        step(t, "WAIT", $sformatf("%0d tick(s) of 10 ms", n), s0, ui_state());
    endtask

    // ---------------------------------------------------------------- 프리로드
    task automatic preload_watch(input integer h, input integer m, input integer s, input integer c);
        tick_sync();
        log_line("PRELOAD", "-", "*** TB writes the watch counters directly (NOT a button, NOT a DUT bug) ***", "", "");
        $display("              o_wt_hour/min/sec/msec  %s -> %s   (wave: values jump here with no U/D tick)",
                 wt_now(), hmsc(h, m, s, c));
        dut.U_WATCH_DATAPATH.U_HOUR_COUNTER.counter_reg = h;
        dut.U_WATCH_DATAPATH.U_MIN_COUNTER.counter_reg  = m;
        dut.U_WATCH_DATAPATH.U_SEC_COUNTER.counter_reg  = s;
        dut.U_WATCH_DATAPATH.U_MSEC_COUNTER.counter_reg = c;
        #1;
    endtask

    task automatic preload_sw(input integer h, input integer m, input integer s, input integer c);
        tick_sync();
        log_line("PRELOAD", "-", "*** TB writes the stopwatch counters directly (NOT a button, NOT a DUT bug) ***", "", "");
        $display("              U_STOPWATCH_DATAPATH count  %s -> %s   (wave: values jump here with no tick/button)",
                 sw_raw(), hmsc(h, m, s, c));
        dut.U_STOPWATCH_DATAPATH.U_HOUR_COUNTER.counter_reg = h;
        dut.U_STOPWATCH_DATAPATH.U_MIN_COUNTER.counter_reg  = m;
        dut.U_STOPWATCH_DATAPATH.U_SEC_COUNTER.counter_reg  = s;
        dut.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.counter_reg = c;
        #1;
    endtask

    task automatic preload_tm(input integer m, input integer s, input integer c);
        tick_sync();
        log_line("PRELOAD", "-", "*** TB writes the timer registers directly (NOT a button, NOT a DUT bug) ***", "", "");
        $display("              o_tm_min/sec/msec  %s -> %02d:%02d.%02d   (wave: values jump here with no tick/button)",
                 tm_now(), m, s, c);
        dut.U_TIMER_DATAPATH.min_reg  = m;
        dut.U_TIMER_DATAPATH.sec_reg  = s;
        dut.U_TIMER_DATAPATH.msec_reg = c;
        #1;
    endtask

    // ---------------------------------------------------------------- 현재 값 문자열
    function automatic string wt_now();
        wt_now = hmsc(dut.w_wt_hour, dut.w_wt_min, dut.w_wt_sec, dut.w_wt_msec);
    endfunction
    function automatic string sw_now();   // 표시값 (랩 적용 후)
        sw_now = hmsc(dut.w_sw_hour, dut.w_sw_min, dut.w_sw_sec, dut.w_sw_msec);
    endfunction
    function automatic string sw_raw();   // 내부 카운터
        sw_raw = hmsc(dut.U_STOPWATCH_DATAPATH.w_cnt_hour, dut.U_STOPWATCH_DATAPATH.w_cnt_min,
                      dut.U_STOPWATCH_DATAPATH.w_cnt_sec, dut.U_STOPWATCH_DATAPATH.w_cnt_msec);
    endfunction
    function automatic string tm_now();
        tm_now = $sformatf("%02d:%02d.%02d", dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
    endfunction
    // 스톱워치 내부 카운트 (1/100 초 단위 총합)
    function automatic longint sw_count();
        sw_count = ((dut.U_STOPWATCH_DATAPATH.w_cnt_hour * 60 + dut.U_STOPWATCH_DATAPATH.w_cnt_min) * 60
                    + dut.U_STOPWATCH_DATAPATH.w_cnt_sec) * 100 + dut.U_STOPWATCH_DATAPATH.w_cnt_msec;
    endfunction

    // ---------------------------------------------------------------- 콘솔 상태 문자열
    // ui_state = "지금 화면 값|FSM 상태" — step() 이 입력 전/후를 칸마다 비교해 바뀐 칸만 "a -> b"
    //   시계 : HH:MM (초는 늘 흐르므로 뺌) + 커서 / 스톱워치 : 표시값 + RUN·STOP(·LAP) / 타이머 : 표시값 + SET·RUN·ALARM
    function automatic string cur_name(input integer c);
        case (c) 0: cur_name = "SET_MIN_1(0)"; 1: cur_name = "SET_MIN_10(1)"; 2: cur_name = "SET_HOUR(2)"; default: cur_name = "NORMAL(3)"; endcase
    endfunction

    function automatic string ui_state();
        if (timer_sw4)
            ui_state = {"timer ", tm_now(), "|", dut.w_tm_alarm ? "ALARM" : (dut.w_tm_run ? "RUN" : "SET")};
        else if (mode_sw0)
            ui_state = {"stopwatch ", sw_now(), "|", dut.w_sw_run_stop ? "RUN" : "STOP", dut.w_sw_lap ? " LAP" : ""};
        else
            ui_state = {"watch ", $sformatf("%02d:%02d", dut.w_wt_hour, dut.w_wt_min), "|cursor ", cur_name(dut.w_wt_cursor)};
    endfunction

    function automatic string state_diff(input string a, input string b);
        string fa[2], fb[2], r;
        integer i, k, n;
        // "x|y" 를 두 칸으로
        fa[0] = a; fa[1] = ""; fb[0] = b; fb[1] = "";
        for (i = 0; i < a.len(); i = i + 1) if (a[i] == "|") begin fa[0] = a.substr(0, i - 1); fa[1] = a.substr(i + 1, a.len() - 1); end
        for (i = 0; i < b.len(); i = i + 1) if (b[i] == "|") begin fb[0] = b.substr(0, i - 1); fb[1] = b.substr(i + 1, b.len() - 1); end
        r = "";
        for (k = 0; k < 2; k = k + 1) begin
            if (k > 0) r = {r, ",  "};
            if (fa[k] == fb[k]) r = {r, fb[k]};
            else begin
                // 앞의 같은 단어 ("watch " / "cursor ") 는 한 번만
                n = 0;
                for (i = 0; i < fa[k].len() && i < fb[k].len(); i = i + 1) begin
                    if (fa[k][i] != fb[k][i]) break;
                    if (fa[k][i] == " ") n = i + 1;
                end
                r = {r, fb[k].substr(0, n - 1), fa[k].substr(n, fa[k].len() - 1), " -> ", fb[k].substr(n, fb[k].len() - 1)};
            end
        end
        state_diff = r;
    endfunction

    function automatic string pulse_at(input bit got);
        if (got) pulse_at = $sformatf("(o_btn @%t)", last_pt);
        else     pulse_at = "(no o_btn)";
    endfunction

    function automatic string sw_name();
        sw_name = timer_sw4 ? "TIMER" : (mode_sw0 ? "STOPWATCH" : "WATCH");
        if (set_sw2) sw_name = {sw_name, " SET"};
        sw_name = {sw_name, display_mode_sw1 ? " HH.MM" : " SS.cc", hour24_sw3 ? " 24h" : " 12h"};
    endfunction

    // FND 화면이 최신 프레임으로 갱신되도록 2 프레임(4 ms) 대기 후 문자열 비교
    task automatic check_disp(input string cid, input string exp_s, input string desc);
        #(5 * MS);
        check(cid, mon.disp_str == exp_s, desc, {"\"", exp_s, "\""}, {"\"", mon.disp_str, "\""});
    endtask

    // 시계 화면 기능 대표 확인 (결함 TB Phase 0 용, tb_wt_1 P1~P4 수준)
    task automatic smoke_check();
        integer m0;
        do_reset();
        set_sw(0, 0, 0, 1, 0);
        check("SMOKE.RST", (dut.w_wt_hour == 12) && (dut.w_wt_min == 0) && (dut.w_wt_sec == 0), "reset value 12:00:00",
              "12:00:00.xx", wt_now());
        check("SMOKE.LED", led == 16'h8005, "LED after reset (watch, HH.MM)", "8005", $sformatf("%h", led));
        press(BU);
        check("SMOKE.NORMAL", dut.w_wt_min == 0, "U ignored in NORMAL", "min=0", $sformatf("min=%0d", dut.w_wt_min));
        set_sw(0, 0, 1, 1, 0);
        check("SMOKE.CUR", dut.w_wt_cursor == 0, "set mode enters cursor 0", "0", $sformatf("%0d", dut.w_wt_cursor));
        m0 = dut.w_wt_min;
        press(BU);
        check("SMOKE.UP", dut.w_wt_min == (m0 + 1) % 60, "U +1 min", $sformatf("%0d", (m0 + 1) % 60), $sformatf("%0d", dut.w_wt_min));
        press(BD); press(BD);
        check("SMOKE.DN", dut.w_wt_min == (m0 + 59) % 60, "D -1 min twice (wrap)", $sformatf("%0d", (m0 + 59) % 60), $sformatf("%0d", dut.w_wt_min));
        press(BL);
        check("SMOKE.L", dut.w_wt_cursor == 1, "L moves cursor 0->1", "1", $sformatf("%0d", dut.w_wt_cursor));
        press(BR);
        check("SMOKE.R", dut.w_wt_cursor == 0, "R moves cursor 1->0", "0", $sformatf("%0d", dut.w_wt_cursor));
        set_sw(0, 0, 0, 1, 0);
        check_disp("SMOKE.FND", "12.59", "FND HH.MM after setting");
    endtask

    // =========================================================================
    // 시나리오
    // =========================================================================

    realtime t_run_rise = 0, t_run_fall = 0;
    always @(posedge dut.w_sw_run_stop) t_run_rise = $realtime;
    always @(negedge dut.w_sw_run_stop) t_run_fall = $realtime;

    initial begin
        realtime win, t_target;
        longint c1, c2;
        integer pv, m0;
        #1;
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "reset -> 0, STOP, LED")) begin
            phase_plan("reset", "STOP, o_sw_run_stop 0, o_sw_* 0, led 000A, FND 00.00");
            do_reset();
            set_sw(0, 0, 0, 0, 1);  // 스톱워치, 초.1/100
            check("SC1", sw_count() == 0 && dut.w_sw_run_stop == 0, "reset -> 00:00:00.00 STOP", "0 STOP",
                  $sformatf("%s run=%b", sw_raw(), dut.w_sw_run_stop));
            check("SC6", led == 16'h000A, "LED stopwatch SS.CC (led1, led3)", "000a", $sformatf("%h", led));
            check_disp("SC7", "00.00", "FND SS.CC");
            phase_end();
        end
        // ------------------------------------------------------------------ P2
        if (phase_begin(2, "RUN window exactly 1.000 s (U_STOPWATCH_CONTROL_UNIT.o_sw_run_stop) -> count 99..100 (SC3, SB3)")) begin
            phase_plan("R -> exactly 1.000 s later R", "STOP -> RUN -> STOP, RUN window 1000.000 ms +-20 us, 99..100 ticks -> 1.00 s");
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            check("SC2", dut.w_sw_run_stop == 1, "R -> RUN", "1", $sformatf("%b", dut.w_sw_run_stop));
            // 두 번째 R: 8 번째 샘플이 (첫 RUN 상승 - 1clk) + 1 s 에 오도록 1.875 ms 앞서 누름
            t_target = t_run_rise - 10.0 + 1.0e9 - 1.875e6;
            #(t_target - $realtime);
            press(BR);
            win = t_run_fall - t_run_rise;
            info("SC3", $sformatf("RUN window (o_sw_run_stop high) = %0.6f ms, count = %0d (%s)", win / 1.0e6, sw_count(), sw_raw()));
            check("SC3", win > 1.0e9 - 20.0e3 && win < 1.0e9 + 20.0e3, "RUN window length", "1000.000000 ms +-20us",
                  $sformatf("%0.6f ms", win / 1.0e6));
            check("SC3", sw_count() >= 99 && sw_count() <= 100, "count after 1.000 s RUN", "99..100", $sformatf("%0d", sw_count()));
            check("SC2", dut.w_sw_run_stop == 0, "2nd R -> STOP", "0", $sformatf("%b", dut.w_sw_run_stop));
            phase_end();
        end
        // ------------------------------------------------------------------ P3
        if (phase_begin(3, "STOP holds value for 200 ms")) begin
            phase_plan("run 120 ms, R, wait 200 ms", "value does not change while STOP");
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            #(120 * MS);
            press(BR);
            c1 = sw_count();
            #(200 * MS);
            check("SC2", sw_count() == c1 && c1 > 0, "value held in STOP", $sformatf("%0d", c1), $sformatf("%0d", sw_count()));
            phase_end();
        end
        // ------------------------------------------------------------------ P4
        if (phase_begin(4, "STOP: L -> 0 and lap released (SC4)")) begin
            phase_plan("STOP: D (lap) -> L", "stays STOP, o_sw_lap 0->1, L clear pulse -> o_sw_* 0 and o_sw_lap 0, FND 00.00");
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            #(150 * MS);
            press(BR);  // STOP, 값 있음
            press(BD);  // 랩 켜기
            check("SC4", dut.w_sw_lap == 1, "lap on before clear", "1", $sformatf("%b", dut.w_sw_lap));
            check("SC6", led[7] == 1, "led7 = lap", "1", $sformatf("%b", led[7]));
            press(BL);
            check("SC4", sw_count() == 0 && dut.w_sw_lap == 0, "L in STOP -> 0, lap off", "0 lap=0",
                  $sformatf("%0d lap=%b", sw_count(), dut.w_sw_lap));
            check_disp("SC4", "00.00", "FND after clear");
            phase_end();
        end
        // ------------------------------------------------------------------ P5
        if (phase_begin(5, "RUN: L ignored (value kept, keeps counting), U ignored (direction kept) (SB5, SB6)")) begin
            phase_plan("RUN: L, then U", "stays RUN, no o_sw_clear pulse, o_sw_down stays 0, o_sw_msec keeps counting");
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            #(300 * MS);
            c1 = sw_count();
            press(BL);
            c2 = sw_count();
            check("SB5", c2 > c1 && dut.w_sw_run_stop == 1, "L during RUN ignored: not cleared, still RUN",
                  $sformatf(">%0d RUN", c1), $sformatf("%0d run=%b", c2, dut.w_sw_run_stop));
            m0 = dut.w_sw_down;
            press(BU);
            check("SB6", dut.w_sw_down == m0, "U during RUN ignored: direction unchanged", $sformatf("%0d", m0), $sformatf("%0d", dut.w_sw_down));
            c1 = sw_count();
            #(50 * MS);
            check("SB6", sw_count() > c1, "still counting up after U", $sformatf(">%0d", c1), $sformatf("%0d", sw_count()));
            phase_end();
        end
        // ------------------------------------------------------------------ P6
        if (phase_begin(6, "STOP: R and L pressed at the same instant -> RUN and cleared to 0 (SB7, LIMIT)")) begin
            phase_plan("STOP: R and L at the same instant", "both o_btn in the same clock -> RUN + o_sw_clear -> counts from 0 ([LIMIT] logged)");
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            #(250 * MS);
            press(BR);
            c1 = sw_count();
            check("SB7", c1 > 0 && dut.w_sw_run_stop == 0, "STOP with a value before R+L", ">0 STOP",
                  $sformatf("%0d run=%b", c1, dut.w_sw_run_stop));
            press2(BR, BL);
            pv = last_pv;
            check("SB7", pv == 4'b0011, "R and L debounced pulses in the same clock", "{D,U,L,R}=0011", $sformatf("%b", pv));
            check("SB7", dut.w_sw_run_stop == 1 && sw_count() <= 1, "R+L same clock in STOP -> RUN from 0",
                  "RUN count<=1", $sformatf("run=%b count=%0d (was %0d)", dut.w_sw_run_stop, sw_count(), c1));
            if (dut.w_sw_run_stop == 1 && sw_count() <= 1)
                limit("SB7", $sformatf("R+L same clock in STOP: RUN starts AND measured %0d counts are cleared (board FSM spec: R wins, no clear)", c1));
            phase_end();
        end
        // ------------------------------------------------------------------ P7
        if (phase_begin(7, "background: stopwatch keeps running on watch screen, watch buttons not routed (SC5)")) begin
            phase_plan("RUN, go to watch screen (mode_sw0=0), press R L U D", "w_sw_btn_* stay 0 -> still RUN, value increases, led 8009");
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            set_sw(0, 0, 0, 0, 0);  // 시계 화면
            check("SC6", led == 16'h8009, "LED on watch screen", "8009", $sformatf("%h", led));
            c1 = sw_count();
            press(BR); press(BL); press(BU); press(BD);
            c2 = sw_count();
            check("SC5", dut.w_sw_run_stop == 1 && dut.w_sw_lap == 0 && dut.w_sw_down == 0,
                  "watch-screen R/L/U/D do not reach stopwatch", "RUN lap=0 mode=0",
                  $sformatf("run=%b lap=%b mode=%b", dut.w_sw_run_stop, dut.w_sw_lap, dut.w_sw_down));
            check("SC5", c2 >= c1 + 3, "stopwatch counted in background (40 ms of presses)", $sformatf(">=%0d", c1 + 3), $sformatf("%0d", c2));
            check("SC5", dut.w_wt_hour == 12 && dut.w_wt_min == 0, "watch not changed by buttons in NORMAL", "12:00", wt_now());
            set_sw(0, 0, 0, 0, 1);
            #(30 * MS);
            check("SC5", sw_count() > c2 && dut.w_sw_run_stop == 1, "back on stopwatch screen, still running (30 ms later)",
                  $sformatf(">%0d", c2), $sformatf("%0d", sw_count()));
            phase_end();
        end
        tb_finish();
    end
endmodule
