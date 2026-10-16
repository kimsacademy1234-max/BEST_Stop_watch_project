`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// [Vivado 에서 실행]  (자세한 것은 같은 폴더 README.md)
//   1) Design Sources : ../../source_file/*.v, *.sv (이 결함은 소스 변경 없음)
//   2) Simulation Sources : 이 파일 + 같은 폴더의 fnd_monitor.sv  → 이 파일을 Set as Top
//   3) Run Simulation → Run All.  콘솔의 [FAIL]/[DEFECT] 시각으로 파형 창에서 Go To Time
//   * Phase 하나만 보려면 아래 RUN_PHASE 를 그 번호로 (긴 TB 는 이게 빠름)
//   * 파형에서 clk 는 빼고 보는 것을 권장 (수 초 시뮬이면 파형 파일이 매우 커짐)
// -----------------------------------------------------------------------------
// =============================================================================
// tb_f3_press_timing — F3: 버튼 입력 시점 오차 (RTL 변경 없음 · TB 자극만)
//   100 Hz tick 이 Top 에 하나(공용, 항상 흐름) → RUN 시작 시점이 tick 사이 어디든 될 수 있다
//   또 디바운서 샘플(4 kHz) 과 tick 이 같은 카운터 기준이라 tick 엣지 = 샘플 엣지 (1e6 = 40 x 25,000)
//   P1 스톱워치: RUN 시작 위상 φ = 0..9 ms (tick 기준), RUN 구간 1.005 s (FSM 기준) → count 표
//      이상적 스톱워치(시작 때 tick 0 맞춤)는 항상 100 (1.00 s, 버림). 공용 tick 은 φ 에 따라 100 / 101
//   P2 타이머: 프리로드 00:01.00, 시작 위상 φ = 0..9 ms → run↑ → alarm↑ 간격 ∈ (0.99 s, 1.00 s + 1 clk]
//   P3 짧은 탭 1.5 / 1.8 / 1.9 / 2.0 ms x 샘플 위상 4 개 → 인식/무시 표 (1.75~2.0 ms 회색 구간)
// =============================================================================
module tb_f3_press_timing;
    // =========================================================================
    // 사용자 설정
    // =========================================================================
    localparam integer RUN_PHASE     = -1;     // -1 = 모든 Phase, N = Phase N 만 실행 (파형 볼 구간만 짧게)
    localparam string  TB_ID         = "F3";
    localparam integer TB_TIMEOUT_MS = 40000;    // 이 시뮬 시각(ms)이 지나면 TIMEOUT 으로 끝냄

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

    function automatic void log_line(input string lvl, input string cid, input string desc, input string exp_s, input string got_s);
        string s;
        s = $sformatf("[%t] [%-5s] [%s.P%0d.%s] %s", $realtime, lvl, TB_ID, phase_no, cid, desc);
        if (exp_s != "" || got_s != "") s = $sformatf("%s | exp=%s got=%s", s, exp_s, got_s);
        s = $sformatf("%s | disp=\"%s\"", s, mon.disp_str);
        $display("%s", s);
        $fflush();   // 중간에 멈춰도 이상 시각이 로그에 남도록
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

    // 검사 1건. 같은 ID 는 처음 5번만 출력
    function automatic void check(input string cid, input bit ok, input string desc, input string exp_s, input string got_s);
        n_checks = n_checks + 1;
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
        log_line("PHASE", "-", {"BEGIN ", name}, "", "");
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
        if (nf == 0)
            log_line("PASS", "-", $sformatf("P%0d checks=%0d all passed (defect=%0d)", phase_no, nc, nd), "", "");
        log_line("PHASE", "-", $sformatf("END   %0.3f ms elapsed, checks=%0d fail=%0d defect=%0d",
                                          ($realtime - phase_t0) / 1.0e6, nc, nf, nd), "", "");
    `ifndef VERILATOR
        if (wave_en && phase_sel >= 0) $dumpoff;
    `endif
    endtask

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
        $timeformat(-3, 6, " ms", 14);
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
        @(negedge clk);
        in_reset_seq = 1;
        rst = 1'b1;
        #(US);
        rst = 1'b0;
        in_reset_seq = 0;
        started = 1;
        #(US);
    endtask

    // 누름 hi ns, 뗌 lo ns. 항상 negedge 에 맞춰 시작 (샘플 엣지와 경쟁 없음)
    task automatic press_ns(input integer b, input longint hi, input longint lo);
        @(negedge clk);
        set_btn(b, 1'b1);
        #(hi);
        set_btn(b, 1'b0);
        #(lo);
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
        @(negedge clk);
        set_btn(b1, 1'b1);
        set_btn(b2, 1'b1);
        #(5 * MS);
        set_btn(b1, 1'b0);
        set_btn(b2, 1'b0);
        #(5 * MS);
    endtask

    // 바운스 패턴 (결정적)
    task automatic press_bounce(input integer b);
        @(negedge clk);
        set_btn(b, 1); #(40 * US);  set_btn(b, 0); #(60 * US);
        set_btn(b, 1); #(120 * US); set_btn(b, 0); #(30 * US);
        set_btn(b, 1); #(300 * US); set_btn(b, 0); #(80 * US);
        set_btn(b, 1); #(20 * MS);
        set_btn(b, 0); #(50 * US);  set_btn(b, 1); #(100 * US);
        set_btn(b, 0); #(70 * US);  set_btn(b, 1); #(400 * US);
        set_btn(b, 0); #(5 * MS);
    endtask

    // 스위치: {sw4 timer, sw3 24h, sw2 set, sw1 disp, sw0 mode}
    task automatic set_sw(input bit timer, input bit h24, input bit set, input bit disp, input bit mode);
        @(negedge clk);
        timer_sw4 = timer;
        hour24_sw3 = h24;
        set_sw2 = set;
        display_mode_sw1 = disp;
        mode_sw0 = mode;
        #(US);
    endtask

    // 100 Hz tick 동기: tick 직후 carry 체인(최대 4클럭)이 다 끝난 negedge
    task automatic tick_sync();
        @(posedge dut.w_tick_10ms);
        repeat (5) @(negedge clk);
    endtask

    task automatic wait_ticks(input integer n);
        repeat (n) @(posedge dut.w_tick_10ms);
        repeat (5) @(negedge clk);
    endtask

    // ---------------------------------------------------------------- 프리로드
    task automatic preload_watch(input integer h, input integer m, input integer s, input integer c);
        tick_sync();
        dut.U_WATCH_DATAPATH.U_HOUR_COUNTER.counter_reg = h;
        dut.U_WATCH_DATAPATH.U_MIN_COUNTER.counter_reg  = m;
        dut.U_WATCH_DATAPATH.U_SEC_COUNTER.counter_reg  = s;
        dut.U_WATCH_DATAPATH.U_MSEC_COUNTER.counter_reg = c;
        info("PRELOAD", $sformatf("dut.U_WATCH_DATAPATH.U_{HOUR,MIN,SEC,MSEC}_COUNTER.counter_reg = %s", hmsc(h, m, s, c)));
        #1;
    endtask

    task automatic preload_sw(input integer h, input integer m, input integer s, input integer c);
        tick_sync();
        dut.U_STOPWATCH_DATAPATH.U_HOUR_COUNTER.counter_reg = h;
        dut.U_STOPWATCH_DATAPATH.U_MIN_COUNTER.counter_reg  = m;
        dut.U_STOPWATCH_DATAPATH.U_SEC_COUNTER.counter_reg  = s;
        dut.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.counter_reg = c;
        info("PRELOAD", $sformatf("dut.U_STOPWATCH_DATAPATH.U_{HOUR,MIN,SEC,MSEC}_COUNTER.counter_reg = %s", hmsc(h, m, s, c)));
        #1;
    endtask

    task automatic preload_tm(input integer m, input integer s, input integer c);
        tick_sync();
        dut.U_TIMER_DATAPATH.min_reg  = m;
        dut.U_TIMER_DATAPATH.sec_reg  = s;
        dut.U_TIMER_DATAPATH.msec_reg = c;
        info("PRELOAD", $sformatf("dut.U_TIMER_DATAPATH.{min,sec,msec}_reg = %02d:%02d.%02d", m, s, c));
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

    realtime t_run_rise = 0, t_run_fall = 0, t_tm_run = 0, t_tm_alarm = 0;
    always @(posedge dut.w_sw_run_stop) t_run_rise = $realtime;
    always @(negedge dut.w_sw_run_stop) t_run_fall = $realtime;
    always @(posedge dut.w_tm_run)   t_tm_run   = $realtime;
    always @(posedge dut.w_tm_alarm) t_tm_alarm = $realtime;

    // 다음 tick 엣지(T) 를 잡고, 디바운서 8 번째 샘플이 T + 20 ms + phi 에 오도록 1.875 ms 앞서 누름
    task automatic press_at_phase(input integer b, input longint phi_us, output realtime e1);
        realtime T;
        @(posedge dut.w_tick_10ms);
        T  = $realtime;               // tick 이 올라간 클럭 엣지 = 샘플 엣지
        e1 = T + 20.0e6 + phi_us * 1000.0;
        #(e1 - 1.875e6 - $realtime);
        press_ns(b, 5 * MS, 5 * MS);
    endtask

    initial begin
        integer phi, i, j, n100, n101, cnt, got, expn, p0;
        realtime e1, win, dt;
        longint tap[0:3];
        longint offs[0:3];
        string row;
        #1;
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "stopwatch: RUN start phase 0..9 ms vs shared tick, window 1.005 s -> count table")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            n100 = 0;
            n101 = 0;
            for (phi = 0; phi < 10; phi = phi + 1) begin
                press(BL);  // STOP 에서 클리어
                press_at_phase(BR, phi * 1000, e1);
                check("F3.SW.START", (t_run_rise - e1) > 9.999 && (t_run_rise - e1) < 10.001,
                      $sformatf("RUN starts exactly at the targeted sample edge (phi=%0d ms)", phi), "e1+10ns",
                      $sformatf("e1+%0.3fns", t_run_rise - e1));
                // 두 번째 R: 8 번째 샘플 = e1 + 1.005 s
                #(e1 + 1.005e9 - 1.875e6 - $realtime);
                press(BR);
                win = t_run_fall - t_run_rise;
                cnt = sw_count();
                check("F3.SW.WIN", win > 1.005e9 - 0.001 && win < 1.005e9 + 0.001, "RUN window", "1005.000000 ms",
                      $sformatf("%0.6f ms", win / 1.0e6));
                check("F3.SW.CNT", cnt == 100 || cnt == 101, "count for 1.005 s", "100 or 101", $sformatf("%0d", cnt));
                if (cnt == 100) n100 = n100 + 1;
                if (cnt == 101) n101 = n101 + 1;
                limit("F3.SW", $sformatf("phase=%0dms window=1.005s count=%0d (shows %0d.%02d s, ideal 1.00 s, err %0d ms vs true 1.005 s)",
                                         phi, cnt, cnt / 100, cnt % 100, cnt * 10 - 1005));
            end
            limit("F3.SW", $sformatf("same 1.005 s measured 10 times: %0d x 1.00 s, %0d x 1.01 s -> result depends on press phase vs shared tick (+-1 count)",
                                     n100, n101));
            check("F3.SW.DIST", n100 > 0 && n101 > 0, "both 100 and 101 occur across phases (shared-tick effect visible)",
                  "both", $sformatf("100:%0d 101:%0d", n100, n101));
            phase_end();
        end
        // ------------------------------------------------------------------ P2
        if (phase_begin(2, "timer: preload 00:01.00, start phase 0..9 ms -> run->alarm interval table")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            for (phi = 0; phi < 10; phi = phi + 1) begin
                preload_tm(0, 1, 0);
                press_at_phase(BL, phi * 1000, e1);
                @(posedge dut.w_tm_alarm);
                dt = t_tm_alarm - t_tm_run;
                check("F3.TM", dt > 0.99e9 && dt <= 1.0e9 + 10.001, $sformatf("1.00 s timer duration (phi=%0d ms)", phi),
                      "(990 ms, 1000 ms + 1 clk]", $sformatf("%0.6f ms", dt / 1.0e6));
                limit("F3.TM", $sformatf("phase=%0dms run->alarm = %0.6f ms (err %0.3f ms)", phi, dt / 1.0e6, (dt - 1.0e9) / 1.0e6));
                press(BU);  // 알람 끄기 (더하기 아님 → 0 유지)
            end
            phase_end();
        end
        // ------------------------------------------------------------------ P3
        if (phase_begin(3, "short taps 1.5/1.8/1.9/2.0 ms x sample phase 30/90/160/220 us -> recognized?")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            tap[0] = 1500; tap[1] = 1800; tap[2] = 1900; tap[3] = 2000;
            offs[0] = 30; offs[1] = 90; offs[2] = 160; offs[3] = 220;
            for (i = 0; i < 4; i = i + 1) begin
                row = "";
                for (j = 0; j < 4; j = j + 1) begin
                    p0 = pc[BU];
                    @(posedge dut.w_clk_4khz);   // 샘플 시각
                    #(offs[j] * US + 5);
                    btn_U = 1;
                    #(tap[i] * US);
                    btn_U = 0;
                    #(5 * MS);
                    got  = pc[BU] - p0;
                    expn = (offs[j] + tap[i] >= 2000) ? 1 : 0;  // 8 번째 샘플이 누름 안에 들어오는가
                    check("F3.TAP", got == expn, $sformatf("tap %0d us at phase +%0d us", tap[i], offs[j]),
                          $sformatf("%0d", expn), $sformatf("%0d", got));
                    row = $sformatf("%s  +%0dus:%s", row, offs[j], got ? "HIT " : "miss");
                end
                limit("F3.TAP", $sformatf("tap %0d us ->%s", tap[i], row));
            end
            phase_end();
        end
        tb_finish();
    end
endmodule
