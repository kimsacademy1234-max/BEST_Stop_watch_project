`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// [Vivado 에서 실행]  (자세한 것은 같은 폴더 README.md)
//   1) Design Sources : 결함 src = 이 폴더의 src/*.v, *.sv  /  원본 = ../../source_file/*.v, *.sv
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
// 이 TB 는 결함 src(Top 에 fault_sw15 포트가 있는 판)용이다.
// 원본 src(../../source_file)로 돌릴 때는 NO_SW_FAULT 를 define 하거나 아래 3 줄을 지운다
// (Vivado: Simulation Settings → xsim.compile.xvlog.more_options = -d NO_SW_FAULT)
`ifndef NO_SW_FAULT
`define HAS_SW_FAULT
`endif
// =============================================================================
// tb_f1_com_skew — F1: FND com/data 위상 차이 → 고스팅
//   P0 fault_sw15 = 0 기능 대표 확인 (주입기 bypass = 원본과 동일)
//   P1 TB 모델 sweep: com 지연 N = 0 / 500 / 3,000 / 12,500 clk 를 4 개 모니터로 동시에 측정 (원본 src 에서도 실행)
//      → 자리별 "틀린 숫자가 켜진 시간" 표. N = 0 은 PASS, N > 0 은 DEFECT
//   P2 RTL 주입기 (defect src 만): fault_sw15 = 0 → 참조와 일치 / fault_sw15 = 1 → DEFECT (고스트 시각) / 다시 0 → 회복
// =============================================================================
module tb_f1_com_skew;
    // =========================================================================
    // 사용자 설정
    // =========================================================================
    localparam integer RUN_PHASE     = -1;     // -1 = 모든 Phase, N = Phase N 만 실행 (파형 볼 구간만 짧게)
    localparam string  TB_ID         = "F1";
    localparam integer TB_TIMEOUT_MS = 2000;    // 이 시뮬 시각(ms)이 지나면 TIMEOUT 으로 끝냄

    // =========================================================================
    // DUT : Top (stopwatch_watch) — 보드 핀과 같은 이름 (block_diagram.pdf 의 'Top 입력 / 출력' + 결함 스위치 fault_sw15)
    // =========================================================================
    reg clk = 1'b0;
    reg rst = 1'b0;                // btnC. do_reset() 이 0->1 을 만들어야 비동기 리셋이 걸린다
    reg btn_R = 1'b0, btn_L = 1'b0, btn_U = 1'b0, btn_D = 1'b0;
    reg mode_sw0 = 1'b0;           // sw0 : 0 시계 / 1 스톱워치
    reg display_mode_sw1 = 1'b0;   // sw1 : 0 초.1/100 / 1 시.분
    reg set_sw2 = 1'b0;            // sw2 : 시계 설정
    reg hour24_sw3 = 1'b0;         // sw3 : 0 12시간 / 1 24시간
    reg timer_sw4 = 1'b0;          // sw4 : 타이머 화면 (sw0 보다 우선)
    reg fault_sw15 = 1'b0;         // fault_sw15 (R2) : 결함 주입 스위치. 결함 src Top 의 fault_sw15 에 연결
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
`ifdef HAS_SW_FAULT
        .fault_sw15      (fault_sw15),      // 결함 src Top 에만 있음
`endif
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

    // TB 쪽 지연 모델 (RTL 주입기 fault_com_skew 와 같은 동작) — 원본 src 의 com 에 붙인다
    wire [3:0] com_raw = dut.U_FND_CONTROLLER.o_fnd_com;
    wire [3:0] c_n0, c_n500, c_n3000, c_n12500;
    com_skew_tbmodel #(.N(0))     M0    (.i_clk(clk), .i_rst(rst), .i_fnd_com(com_raw), .o_fnd_com(c_n0));
    com_skew_tbmodel #(.N(500))   M500  (.i_clk(clk), .i_rst(rst), .i_fnd_com(com_raw), .o_fnd_com(c_n500));
    com_skew_tbmodel #(.N(3000))  M3000 (.i_clk(clk), .i_rst(rst), .i_fnd_com(com_raw), .o_fnd_com(c_n3000));
    com_skew_tbmodel #(.N(12500)) M12500(.i_clk(clk), .i_rst(rst), .i_fnd_com(com_raw), .o_fnd_com(c_n12500));

`define SKEW_MON(NAME, COM) \
    fnd_monitor NAME (.i_fnd_com(COM), .i_fnd_font(fnd_font), .i_scan_sel(dut.U_FND_CONTROLLER.w_scan_sel), \
                      .i_disp_mode(dut.w_disp_mode), .i_disp_hour(dut.w_disp_hour), .i_disp_min(dut.w_disp_min), \
                      .i_disp_sec(dut.w_disp_sec), .i_disp_msec(dut.w_disp_msec), .i_wt_cursor(dut.w_wt_cursor), \
                      .i_set_sw2(set_sw2), .i_sel_wt(dut.w_sel_wt));
    `SKEW_MON(mon_n0, c_n0)
    `SKEW_MON(mon_n500, c_n500)
    `SKEW_MON(mon_n3000, c_n3000)
    `SKEW_MON(mon_n12500, c_n12500)

    function automatic string fch(input [7:0] f);
        case (f)
            8'hC0: fch = "0"; 8'hF9: fch = "1"; 8'hA4: fch = "2"; 8'hB0: fch = "3"; 8'h99: fch = "4";
            8'h92: fch = "5"; 8'h82: fch = "6"; 8'hF8: fch = "7"; 8'h80: fch = "8"; 8'h90: fch = "9";
            8'hFF: fch = "_"; 8'h7F: fch = "."; default: fch = "?";
        endcase
    endfunction

    // 자리별 고스트 표 (frames = 측정 프레임 수, 프레임 = 2 ms = 자리마다 숫자 슬롯 1 개)
    task automatic report(input string cid, input integer n, input integer nfr, input realtime tfirst,
                          input realtime g0, input realtime g1, input realtime g2, input realtime g3,
                          input [7:0] f0, input [7:0] f1, input [7:0] f2, input [7:0] f3);
        realtime tot;
        tot = g0 + g1 + g2 + g3;
        info(cid, $sformatf("N=%0d (%0.3f us skew): ghost per frame  AN0 %0.3f us '%s' | AN1 %0.3f us '%s' | AN2 %0.3f us '%s' | AN3 %0.3f us '%s'",
                            n, n * 0.01, g0 / nfr / 1000.0, fch(f0), g1 / nfr / 1000.0, fch(f1),
                            g2 / nfr / 1000.0, fch(f2), g3 / nfr / 1000.0, fch(f3)));
        if (n == 0)
            check(cid, tot == 0, "no skew -> no ghost digit", "0 us", $sformatf("%0.3f us", tot / 1000.0));
        else if (tot > 0)
            defect_at(cid, tfirst, $sformatf("first ghost at %t, N=%0d: AN0 shows '%s'(AN1 digit) for %0.3f us per slot (%0.1f %% duty), AN3 shows '%s'(AN0 digit) %0.3f us",
                                  tfirst, n, fch(f0), g0 / nfr / 1000.0, 100.0 * g0 / nfr / 250000.0, fch(f3), g3 / nfr / 1000.0),
                   "0 us ghost", $sformatf("%0.3f us/frame total", tot / nfr / 1000.0));
        else
            check(cid, 0, $sformatf("N=%0d skew should produce ghost", n), ">0 us", "0 us");
    endtask

    initial begin
        #1;
        // ------------------------------------------------------------------ P0
        if (phase_begin(0, "fault_sw15 = 0: functional smoke (injector bypass == original)")) begin
            phase_plan("fault_sw15=0, functional smoke", "same as original (injector bypassed), all checks pass");
            fault_sw15 = 0;
            smoke_check();
            phase_end();
        end
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "TB-model sweep: com delay N = 0 / 500 / 3000 / 12500 clk, screen 12.34, 20 ms")) begin
            phase_plan("TB model: com delay N = 0 / 500 / 3000 / 12500 clk, screen 12.34, 20 ms", "N=0 PASS, N>0 DEFECT (wrong digit on-time table per digit)");
            do_reset();
            set_sw(0, 0, 0, 1, 0);
            preload_watch(12, 34, 0, 0);
            @(posedge dut.U_FND_CONTROLLER.w_scan_sel[2]);  // 프레임 경계(슬롯 4)에서 시작
            mon_n0.clear_stats(); mon_n500.clear_stats(); mon_n3000.clear_stats(); mon_n12500.clear_stats();
            #(20 * MS);
            report("F1.N0", 0, 10, mon_n0.ghost_first_t, mon_n0.ghost_time[0], mon_n0.ghost_time[1], mon_n0.ghost_time[2], mon_n0.ghost_time[3],
                   mon_n0.ghost_font[0], mon_n0.ghost_font[1], mon_n0.ghost_font[2], mon_n0.ghost_font[3]);
            report("F1.N500", 500, 10, mon_n500.ghost_first_t, mon_n500.ghost_time[0], mon_n500.ghost_time[1], mon_n500.ghost_time[2], mon_n500.ghost_time[3],
                   mon_n500.ghost_font[0], mon_n500.ghost_font[1], mon_n500.ghost_font[2], mon_n500.ghost_font[3]);
            report("F1.N3000", 3000, 10, mon_n3000.ghost_first_t, mon_n3000.ghost_time[0], mon_n3000.ghost_time[1], mon_n3000.ghost_time[2], mon_n3000.ghost_time[3],
                   mon_n3000.ghost_font[0], mon_n3000.ghost_font[1], mon_n3000.ghost_font[2], mon_n3000.ghost_font[3]);
            report("F1.N12500", 12500, 10, mon_n12500.ghost_first_t, mon_n12500.ghost_time[0], mon_n12500.ghost_time[1], mon_n12500.ghost_time[2], mon_n12500.ghost_time[3],
                   mon_n12500.ghost_font[0], mon_n12500.ghost_font[1], mon_n12500.ghost_font[2], mon_n12500.ghost_font[3]);
            check("F1.DISP", mon.disp_str == "12.34", "pin FND (no injection) still reads 12.34", "\"12.34\"", {"\"", mon.disp_str, "\""});
            phase_end();
        end
        // ------------------------------------------------------------------ P2
`ifdef HAS_SW_FAULT
        if (phase_begin(2, "RTL injector fault_com_skew (N=12500) via fault_sw15: off -> on -> off, 20 ms each")) begin
            phase_plan("RTL injector: fault_sw15 0 -> 1 -> 0, 20 ms each", "0: matches reference / 1: DEFECT (ghost time) / back to 0: recovers");
            do_reset();
            set_sw(0, 0, 0, 1, 0);
            preload_watch(12, 34, 0, 0);
            fault_sw15 = 0;
            mm_seen = mon.mm_count;
            #(20 * MS);
            check("F1.OFF", mon.mm_count == mm_seen, "fault_sw15=0: pin FND == reference", "0 mismatch",
                  $sformatf("%0d", mon.mm_count - mm_seen));
            @(posedge dut.U_FND_CONTROLLER.w_scan_sel[2]);
            @(negedge clk);
            fault_sw15 = 1;
            mm_is_defect = 1;
            info("F1.ON", "fault_sw15 -> 1 : com skew 125 us injected at the pins");
            mon.clear_stats();
            #(20 * MS);
            report("F1.ON", 12500, 10, mon.ghost_first_t, mon.ghost_time[0], mon.ghost_time[1], mon.ghost_time[2], mon.ghost_time[3],
                   mon.ghost_font[0], mon.ghost_font[1], mon.ghost_font[2], mon.ghost_font[3]);
            @(negedge clk);
            fault_sw15 = 0;
            #(300 * US);
            mm_is_defect = 0;
            mm_seen = mon.mm_count;
            #(20 * MS);
            check("F1.OFF2", mon.mm_count == mm_seen, "fault_sw15 back to 0: pin FND == reference again", "0 mismatch",
                  $sformatf("%0d", mon.mm_count - mm_seen));
            phase_end();
        end
`else
        phase_skip(2, "RTL injector via fault_sw15", "original src has no fault_com_skew (run with --src defect_1_fnd_com_skew/src)");
`endif
        tb_finish();
    end
endmodule

// TB 모델: RTL fault_com_skew 와 같은 동작 (i_fault_sw15 항상 1)
module com_skew_tbmodel #(   // RTL 주입기 fault_com_skew 와 같은 포트 이름 (i_fault_sw15 대신 N > 0)
    parameter N = 0
) (
    input            i_clk,
    input            i_rst,
    input      [3:0] i_fnd_com,
    output     [3:0] o_fnd_com
);
    reg [3:0]  com_d;
    reg [15:0] cnt;
    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            com_d <= 4'b1110;
            cnt   <= 16'd0;
        end else if (i_fnd_com != com_d) begin
            if (cnt >= N - 1) begin
                com_d <= i_fnd_com;
                cnt   <= 16'd0;
            end else cnt <= cnt + 16'd1;
        end else cnt <= 16'd0;
    end
    assign o_fnd_com = (N > 0) ? com_d : i_fnd_com;
endmodule
