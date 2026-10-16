`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// [Vivado 에서 실행]  (자세한 것은 verification/verification_plan.md §7)
//   1) Design Sources : ../boyun/merged_v4/src/*.v, *.sv
//   2) Simulation Sources : 이 파일 + tb/common/fnd_monitor.sv  → 이 파일을 Set as Top
//   3) Run Simulation → Run All.  콘솔의 [FAIL]/[DEFECT] 시각으로 파형 창에서 Go To Time
//   * Phase 하나만 보려면 아래 RUN_PHASE 를 그 번호로 (긴 TB 는 이게 빠름)
//   * 파형에서 clk 는 빼고 보는 것을 권장 (수 초 시뮬이면 파형 파일이 매우 커짐)
// -----------------------------------------------------------------------------
// =============================================================================
// tb_tm_3_cancel_background — TIMER (boyun): 취소 · 백그라운드 · 게이팅 (verification_plan.md)
//   P1 RUN 중 U/R/D 무시 (TC2) · P2 RUN 중 L → 0, SET · P3 시작 → 시계 화면 → 프리로드 00:00.30 → 시계 화면에서 ALARM LED (TC3)
//   P4 시계 화면 버튼으로 안 꺼짐 (TC4) · P5 sw4+sw0 → 타이머 우선, 버튼으로 끄기 (TC5)
// =============================================================================
module tb_tm_3_cancel_background;
    // =========================================================================
    // 사용자 설정
    // =========================================================================
    localparam integer RUN_PHASE     = -1;     // -1 = 모든 Phase, N = Phase N 만 실행 (파형 볼 구간만 짧게)
    localparam string  TB_ID         = "TM3";
    localparam integer TB_TIMEOUT_MS = 3000;    // 이 시뮬 시각(ms)이 지나면 TIMEOUT 으로 끝냄

    // =========================================================================
    // DUT : Top (stopwatch_watch) — 보드 핀과 같은 이름
    // =========================================================================
    reg clk = 1'b0;
    reg rst = 1'b0;    // btnC. do_reset() 이 0->1 을 만들어야 비동기 리셋이 걸린다
    reg btnR = 1'b0, btnL = 1'b0, btnU = 1'b0, btnD = 1'b0;
    reg sw_mode = 1'b0;           // sw0 : 0 시계 / 1 스톱워치
    reg sw_display_mode = 1'b0;   // sw1 : 0 초.1/100 / 1 시.분
    reg sw_set = 1'b0;            // sw2 : 시계 설정
    reg sw_24h = 1'b0;            // sw3 : 0 12시간 / 1 24시간
    reg sw_timer = 1'b0;          // sw4 : 타이머 화면 (sw0 보다 우선)
    reg sw15 = 1'b0;   // 결함 주입 스위치 (보드 R2). 이 TB 에서는 안 씀
    wire [3:0]  fnd_com;
    wire [7:0]  fnd_font;
    wire [15:0] led;

    always #5 clk = ~clk;   // 100 MHz (주파수 줄이지 않음)

    stopwatch_watch dut (
        .clk            (clk),
        .rst            (rst),
        .btnR           (btnR),
        .btnL           (btnL),
        .btnU           (btnU),
        .btnD           (btnD),
        .sw_mode        (sw_mode),
        .sw_display_mode(sw_display_mode),
        .sw_set         (sw_set),
        .sw_24h         (sw_24h),
        .sw_timer       (sw_timer),
        .fnd_com        (fnd_com),
        .fnd_font       (fnd_font),
        .led            (led)
    );

    // =========================================================================
    // 파형용 신호 — 파형 창에 바로 보이도록 내부 신호를 TB 로 끌어올림 (dut 를 펼칠 필요 없음)
    //   시간 값은 Radix = Unsigned Decimal 로 보면 된다
    // =========================================================================
    wire        wv_tick_10ms = dut.w_tick_10ms;    // 100 Hz 공용 tick (10 ms 마다 1 클럭 펄스)
    wire        wv_clk_4khz  = dut.w_clk_4Khz;     // 4 kHz 샘플 펄스 (디바운서 · FND 스캔)
    wire [3:0]  wv_btn_pulse = {dut.w_btnD, dut.w_btnU, dut.w_btnL, dut.w_btnR};  // 디바운서 출력 {D,U,L,R}
    // 시계
    wire [4:0]  wv_wt_hour   = dut.w_wt_hour;
    wire [5:0]  wv_wt_min    = dut.w_wt_min;
    wire [5:0]  wv_wt_sec    = dut.w_wt_sec;
    wire [6:0]  wv_wt_msec   = dut.w_wt_msec;
    wire        wv_wt_set    = dut.w_set_mode;     // 1 = 설정 중
    wire [1:0]  wv_wt_cursor = dut.w_cursor;       // 0 분 일 · 1 분 십 · 2 시 · 3 없음
    // 스톱워치 (표시값 = 랩 적용 후)
    wire        wv_sw_run    = dut.w_run_stop;     // 1 = RUN
    wire        wv_sw_down   = dut.w_mode;         // 1 = 다운 카운트
    wire        wv_sw_lap    = dut.w_lap_active;
    wire [4:0]  wv_sw_hour   = dut.w_sw_hour;
    wire [5:0]  wv_sw_min    = dut.w_sw_min;
    wire [5:0]  wv_sw_sec    = dut.w_sw_sec;
    wire [6:0]  wv_sw_msec   = dut.w_sw_msec;
    // 타이머
    wire        wv_tm_run    = dut.w_tm_run;
    wire        wv_tm_alarm  = dut.w_tm_alarm;
    wire [5:0]  wv_tm_min    = dut.w_tm_min;
    wire [5:0]  wv_tm_sec    = dut.w_tm_sec;
    wire [6:0]  wv_tm_msec   = dut.w_tm_msec;
    // FND
    wire [2:0]  wv_fnd_slot  = dut.FND_CON.w_sel;  // 0~3 자리 AN0~AN3, 4~7 빈칸/DP

    // FND 해석기 + 참조 모델 (tb/common/fnd_monitor.sv 를 같이 추가할 것)
    fnd_monitor mon (
        .com      (fnd_com),
        .font     (fnd_font),
        .sel      (dut.FND_CON.w_sel),
        .disp_mode(dut.w_disp_mode),
        .hour     (dut.w_hour),
        .min      (dut.w_min),
        .sec      (dut.w_sec),
        .msec     (dut.w_msec),
        .cursor   (dut.w_cursor),
        .sw_set   (sw_set),
        .sw_scr   (sw_mode | sw_timer)
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

    // 디바운서 출력 펄스 카운터 (§1.4) : 0 R, 1 L, 2 U, 3 D
    integer pc[0:3];
    integer pw_bad = 0;
    reg [3:0] last_pv = 4'b0;   // 마지막 디바운서 펄스의 {D,U,L,R} (동시 펄스 확인용)
    realtime  last_pt = 0;      // 마지막 디바운서 펄스 시각
    initial begin pc[0] = 0; pc[1] = 0; pc[2] = 0; pc[3] = 0; end

    // ---------------------------------------------------------------- 로그 (§8)
    function automatic string bname(input integer b);
        case (b) 0: bname = "btnR"; 1: bname = "btnL"; 2: bname = "btnU"; default: bname = "btnD"; endcase
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

    // ---------------------------------------------------------------- 펄스 모니터 (§1.4)
    // 디바운서 출력 w_btnX 는 정확히 1클럭(10 ns) 펄스여야 한다
    // (트리거 하나로 4 개를 같이 본다)
    wire       w_btn_any = |wv_btn_pulse;
    always @(posedge w_btn_any) begin : pmon
        realtime t;
        reg [3:0] b;
        integer i;
        t = $realtime;
        #1;              // 같은 클럭의 다른 버튼 펄스가 다음 델타에 올라와도 같이 읽기
        b = wv_btn_pulse;
        last_pv = b;
        last_pt = t;
        for (i = 0; i < 4; i = i + 1) if (b[i]) pc[i] = pc[i] + 1;
        @(negedge w_btn_any);
        if (($realtime - t) < 9.999 || ($realtime - t) > 10.001) begin
            pw_bad = pw_bad + 1;
            check("PW", 0, $sformatf("debouncer pulse width != 1 clk (w_btn{D,U,L,R}=%b)", b), "10.000 ns",
                  $sformatf("%0.3f ns", $realtime - t));
        end
    end

    // FND 참조 비교 불일치 (§5.2) — 구간이 끝날 때마다 로그
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
            0: btnR = v;
            1: btnL = v;
            2: btnU = v;
            default: btnD = v;
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

    // 바운스 패턴 (§5.1, 결정적)
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
        sw_timer = timer;
        sw_24h = h24;
        sw_set = set;
        sw_display_mode = disp;
        sw_mode = mode;
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

    // ---------------------------------------------------------------- 프리로드 (§1.3)
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
        sw_raw = hmsc(dut.U_STOPWATCH_DATAPATH.w_hour, dut.U_STOPWATCH_DATAPATH.w_min,
                      dut.U_STOPWATCH_DATAPATH.w_sec, dut.U_STOPWATCH_DATAPATH.w_msec);
    endfunction
    function automatic string tm_now();
        tm_now = $sformatf("%02d:%02d.%02d", dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec);
    endfunction
    // 스톱워치 내부 카운트 (1/100 초 단위 총합)
    function automatic longint sw_count();
        sw_count = ((dut.U_STOPWATCH_DATAPATH.w_hour * 60 + dut.U_STOPWATCH_DATAPATH.w_min) * 60
                    + dut.U_STOPWATCH_DATAPATH.w_sec) * 100 + dut.U_STOPWATCH_DATAPATH.w_msec;
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
        check("SMOKE.CUR", dut.w_cursor == 0, "set mode enters cursor 0", "0", $sformatf("%0d", dut.w_cursor));
        m0 = dut.w_wt_min;
        press(BU);
        check("SMOKE.UP", dut.w_wt_min == (m0 + 1) % 60, "U +1 min", $sformatf("%0d", (m0 + 1) % 60), $sformatf("%0d", dut.w_wt_min));
        press(BD); press(BD);
        check("SMOKE.DN", dut.w_wt_min == (m0 + 59) % 60, "D -1 min twice (wrap)", $sformatf("%0d", (m0 + 59) % 60), $sformatf("%0d", dut.w_wt_min));
        press(BL);
        check("SMOKE.L", dut.w_cursor == 1, "L moves cursor 0->1", "1", $sformatf("%0d", dut.w_cursor));
        press(BR);
        check("SMOKE.R", dut.w_cursor == 0, "R moves cursor 1->0", "0", $sformatf("%0d", dut.w_cursor));
        set_sw(0, 0, 0, 1, 0);
        check_disp("SMOKE.FND", "12.59", "FND HH.MM after setting");
    endtask

    // =========================================================================
    // 시나리오
    // =========================================================================

    function automatic integer tm_cs();  // 남은 시간 (1/100 초)
        tm_cs = (dut.w_tm_min * 60 + dut.w_tm_sec) * 100 + dut.w_tm_msec;
    endfunction

    initial begin
        integer c1;
        reg [15:0] exp_led;
        #1;
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "RUN: U/R/D ignored (TC2)")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            press(BR);   // 01:00
            press(BL);   // RUN
            c1 = tm_cs();
            press(BU); press(BR); press(BD);
            check("TC2", tm_cs() < c1 && tm_cs() > c1 - 10, "U/R/D during RUN add nothing (only ~30 ms elapsed)",
                  $sformatf("(%0d,%0d)", c1 - 10, c1), $sformatf("%0d (%s)", tm_cs(), tm_now()));
            check("TC2", dut.w_tm_run == 1, "still running", "1", $sformatf("%b", dut.w_tm_run));
            phase_end();
        end
        // ------------------------------------------------------------------ P2
        if (phase_begin(2, "RUN: L -> cancel to 00:00, SET")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            press(BR);
            press(BL);
            #(50 * MS);
            press(BL);
            check("TC2", tm_now() == "00:00.00" && dut.w_tm_run == 0 && dut.w_tm_alarm == 0, "L during RUN cancels (0, SET, no alarm)",
                  "00:00.00 SET", $sformatf("%s run=%b alarm=%b", tm_now(), dut.w_tm_run, dut.w_tm_alarm));
            phase_end();
        end
        // ------------------------------------------------------------------ P3~P4 (연속)
        if (phase_begin(3, "background: start, go to watch screen, preload 00:00.30 -> ALARM LED on watch screen (TC3)")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            press(BR);
            press(BL);
            set_sw(0, 0, 0, 1, 0);  // 시계 화면
            check("TC3", dut.w_tm_run == 1, "timer runs in background", "1", $sformatf("%b", dut.w_tm_run));
            preload_tm(0, 0, 30);
            @(posedge dut.w_tm_alarm);
            info("TC3", "ALARM reached while watch screen is shown");
            #(20 * MS);
            exp_led = (dut.w_wt_msec >= 50) ? 16'hFFFF : 16'h0000;
            check("TC3", led == exp_led, "alarm LED pattern on watch screen", $sformatf("%h", exp_led), $sformatf("%h", led));
            check_disp("TC3", "12.00", "FND still shows the watch (12.00)");
            phase_end();

            void'(phase_begin(4, "watch-screen buttons do not stop the alarm (TC4)"));
            press(BU); press(BD); press(BL); press(BR);
            check("TC4", dut.w_tm_alarm == 1, "alarm still on after watch-screen U/D/L/R", "1", $sformatf("%b", dut.w_tm_alarm));
            set_sw(0, 0, 0, 0, 1);  // 스톱워치 화면
            press(BD);
            check("TC4", dut.w_tm_alarm == 1, "alarm still on after stopwatch-screen D", "1", $sformatf("%b", dut.w_tm_alarm));
            press(BD);  // 랩 원복
            phase_end();
        end
        // ------------------------------------------------------------------ P5
        if (phase_begin(5, "sw4=1 & sw0=1 -> timer has priority; timer-screen button turns alarm off (TC5)")) begin
            if (dut.w_tm_alarm == 0) begin  // +phase=5 단독 실행 대비
                do_reset();
                set_sw(1, 0, 0, 0, 0);
                press(BU);
                press(BL);
                preload_tm(0, 0, 30);
                @(posedge dut.w_tm_alarm);
            end
            set_sw(1, 0, 0, 0, 1);
            check("TC5", dut.w_sel_tm == 1 && dut.w_sel_sw == 0, "timer selected over stopwatch", "sel_tm=1 sel_sw=0",
                  $sformatf("sel_tm=%b sel_sw=%b", dut.w_sel_tm, dut.w_sel_sw));
            press(BR);
            check("TC5", dut.w_tm_alarm == 0 && tm_now() == "00:00.00", "R on timer screen turns alarm off, no +1 min",
                  "alarm=0 00:00.00", $sformatf("alarm=%b %s", dut.w_tm_alarm, tm_now()));
            check("TC6", led == 16'h0020, "LED timer screen with sw0=1: led5 only (led1 off, timer has priority)", "0020", $sformatf("%h", led));
            phase_end();
        end
        tb_finish();
    end
endmodule
