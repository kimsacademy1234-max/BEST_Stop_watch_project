`timescale 1ns / 1ps
// =============================================================================
// tb_merge_harness — merge_final_top TB 공통 하네스
//   DUT + 100 MHz 클럭 + 핀 모델 (버튼 · 스위치 · PC UART · SR04 센서 · DHT11 센서)
//   + 모니터 (디바운서 펄스 · UART 줄 · FND 글자 · 센서 측정) + 스코어보드
//
//   그룹 TB (tb_A_reset.sv ~ tb_L_integration.sv) 가 이 모듈을 h 로 두고 h.task() 로 부린다.
//   시나리오 표 = tb_scenario.md, 실행 방법 = README.md
//
//   콘솔 읽는 법 (줄 맨 앞 [시각 ms] = 파형 Go To Time)
//     [BEGIN  ] 시나리오 시작 + plan / expect
//     [OK     ] [FAIL   ] 검사 1 건 (exp = 기대, got = 실제)
//     [ISSUE  ] tb_scenario.md 2 장 의 ⚠ 항목 : 스펙과 다르게 동작 (FAIL 과 따로 셈)
//     [NOTE   ] TB 가 한 일 · 참고 값
// =============================================================================
module tb_merge_harness #(
    parameter integer TICK_F     = 1_000_000,    // WTS 10 ms tick F_COUNT (시계 · 스톱워치 · 타이머 공통)
    parameter integer AUTO_FRQ   = 1,            // /auto 전송 주기 (Hz)
    parameter integer DHT_BOOT   = 100_000_000,  // DHT11 전원 뒤 대기 (clk)
    parameter integer DHT_INTV   = 200_000_000,  // DHT11 측정 간격 (clk)
    parameter integer BLINK_HALF = 25_000_000,   // SR04 근접 경고 점멸 반 주기 (clk)
    parameter integer BAUD       = 9600,         // UART (DUT baud tick + PC 모델 같이)
    parameter integer SR_TICK    = 100,          // SR04 1 us tick F_COUNT (10 = 10 배 빠르게)
    parameter integer DHT_TICK   = 100,          // DHT11 1 us tick F_COUNT (10 = 10 배 빠르게)
    parameter string  TB_ID      = "TB",
    parameter string  ONLY       = "",           // "" = 전부, "D3" = D3 만 (+only=D3 · +only_D3 로도 가능)
    parameter integer TIMEOUT_MS = 10_000        // 시뮬 시각이 이만큼 지나면 TIMEOUT 으로 끝냄
) ();

    // =========================================================================
    // 시간 상수 (ns) — 판정은 전부 이 값으로 계산 (시간을 줄여도 판정 코드는 그대로)
    // =========================================================================
    localparam real US        = 1_000.0;
    localparam real MS        = 1_000_000.0;
    localparam real CLK       = 10.0;
    localparam real T_CS      = TICK_F * 10.0;                  // 1/100 초
    localparam real T_SEC     = T_CS * 100.0;                   // 1 초
    localparam real T_AUTO    = (100_000_000 / AUTO_FRQ) * 10.0; // /auto 한 박자
    localparam real T_BOOT    = DHT_BOOT * 10.0;
    localparam real T_INTV    = DHT_INTV * 10.0;
    localparam integer BAUD_F = 100_000_000 / (BAUD * 16);      // DUT baud tick F_COUNT (9600 → 651)
    localparam real BIT_NS    = 1.0e9 / BAUD;                   // PC 송신 1 bit (9600 : 104,166.7 ns)
    localparam real TX_BIT_NS = BAUD_F * 16.0 * 10.0;           // DUT 송신 1 bit (9600 : 104,160 ns)
    localparam real SR_US     = SR_TICK * 10.0;                 // SR04 의 "1 us" (줄이면 센서 시간도 같이)
    localparam real DH_US     = DHT_TICK * 10.0;                // DHT11 의 "1 us"
    localparam integer BR = 0, BL = 1, BU = 2, BD = 3;
    localparam integer SR_NORMAL = 0, SR_NONE = 1, SR_MANUAL = 2;  // SR04 모델
    localparam integer DH_NORMAL = 0, DH_NONE = 1, DH_STUCK = 2;   // DHT11 모델

    // =========================================================================
    // DUT 핀
    // =========================================================================
    reg        clk = 1'b0;
    reg        rst = 1'b0;
    reg        btn_R = 1'b0, btn_L = 1'b0, btn_U = 1'b0, btn_D = 1'b0;
    reg  [6:0] sw = 7'd0;          // {dht_sw6, dist_sw5, timer_sw4, hour24_sw3, set_sw2, display_mode_sw1, mode_sw0}
    reg        sw15 = 1'b0;        // dist_led_sw15
    reg        rx = 1'b1;
    reg        echo = 1'b0;
    reg        dht_drv = 1'b0;     // 1 = 센서 모델이 DATA 선을 LOW 로
    wire       tx, trig;
    wire       dht11_io;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;
    wire [15:0] led;

    always #5 clk = ~clk;          // 100 MHz

    assign dht11_io = dht_drv ? 1'b0 : 1'bz;
    pullup (dht11_io);             // xdc 의 PULLUP

    merge_final_top dut (
        .clk             (clk),
        .rst             (rst),
        .btn_R           (btn_R),
        .btn_L           (btn_L),
        .btn_U           (btn_U),
        .btn_D           (btn_D),
        .mode_sw0        (sw[0]),
        .display_mode_sw1(sw[1]),
        .set_sw2         (sw[2]),
        .hour24_sw3      (sw[3]),
        .timer_sw4       (sw[4]),
        .dist_sw5        (sw[5]),
        .dht_sw6         (sw[6]),
        .dist_led_sw15   (sw15),
        .rx              (rx),
        .tx              (tx),
        .trig            (trig),
        .echo            (echo),
        .dht11_io        (dht11_io),
        .fnd_com         (fnd_com),
        .fnd_font        (fnd_font),
        .led             (led)
    );

    // 시뮬 시간 단축 (tb_scenario.md 3-3). 원래 값이면 그대로
    defparam dut.U_WTS.U_TICK_GEN_100HZ.F_COUNT = TICK_F;
    defparam dut.U_WTS.U_TICK_GEN_SW.F_COUNT    = TICK_F;
    defparam dut.U_WTS.U_TICK_GEN_TM.F_COUNT    = TICK_F;
    defparam dut.U_UART.AUTO_FRQ                = AUTO_FRQ;
    defparam dut.U_DHT11.BOOT_CYCLES            = DHT_BOOT;
    defparam dut.U_DHT11.INTERVAL_CYCLES        = DHT_INTV;
    defparam dut.U_SR04.U_LED.BLINK_HALF_CYC    = BLINK_HALF;
    defparam dut.U_UART.U_BAUD_TICK_GEN.BAUD_RATE = BAUD;           // F_COUNT = 1e8 / (BAUD * 16) = BAUD_F
    defparam dut.U_SR04.U_SR04.U_TICK_GEN_US.F_COUNT = SR_TICK;   // (xsim : defparam 이 인스턴스 #() 보다 우선)
    defparam dut.U_DHT11.TICK_F_COUNT           = DHT_TICK;

    // =========================================================================
    // 모니터 변수 (아래 여러 곳에서 씀)
    // =========================================================================
    string   lines[$];                  // FPGA → PC 로 받은 줄 (CR LF 뺀 것)
    realtime line_t0[$], line_t1[$];    // 줄 첫 start 비트 · 마지막 stop 비트 끝
    integer  line_rd = 0;               // next_line() 이 읽을 위치
    realtime last_t1 = 0;
    string   cur_line = "";
    bit      in_line = 0;
    realtime cur_t0 = 0;
    integer  n_tx_bytes = 0, tx_frame_err = 0;
    integer  n_line_mis = 0, n_line_unexp = 0, n_bad_line = 0;
    string   exp_q[$];                  // send_go 순간 스냅샷 → 이 줄이 나와야 함
    bit      xz_seen = 0;
    realtime t_xz = 0;
    real     uart_err = 0.0;            // +0.02 = PC 쪽 baud 2 % 빠름

    // =========================================================================
    // 스코어보드 · 로그
    // =========================================================================
    integer n_chk = 0, n_fail = 0, n_issue = 0;
    string  fail_ids[$], issue_ids[$];
    string  cur_sc = "";
    integer sc_fail0 = 0, sc_chk0 = 0;
    string  sc_result[$];

    // 파형용 ASCII 레지스터 (wcfg 에서 ASCII radix 로 보임) — 시뮬 동작에는 영향 없음
    reg [8*8-1:0]  W_SC   = 0;   // 지금 시나리오 ID ("D3")
    reg [8*8-1:0]  W_CHK  = 0;   // 마지막 검사 ID ("D3-1")
    reg [8*8-1:0]  W_RES  = 0;   // 마지막 검사 결과 ("OK" / "FAIL" / "ISSUE")
    reg [8*16-1:0] W_CMD  = 0;   // PC → FPGA 로 마지막에 보낸 문자열 (CR = '#')
    reg [8*16-1:0] W_LINE = 0;   // FPGA → PC 로 마지막에 받은 줄 (CR LF 뺌)
    reg [8*8-1:0]  W_FND  = 0;   // FND 표시 문자열 (2 ms 마다 갱신, "12.34" · "Err1" · "----")

    function automatic [8*16-1:0] s2v(input string s);   // 오른쪽 정렬, 넘치면 앞 글자 잘림
        reg [8*16-1:0] v;
        v = 0;
        for (int i = 0; i < s.len(); i++) v = {v[8*15-1:0], s[i]};
        return v;
    endfunction

    function automatic string ts();
        return $sformatf("[%12.6f ms]", $realtime / 1.0e6);
    endfunction

    function automatic string padn(input string s, input integer n);
        string r;
        r = s;
        while (r.len() < n) r = {r, " "};
        return r;
    endfunction

    function automatic string pad7(input string s);
        return padn(s, 7);
    endfunction

    // 문자열 고르기 (xsim 2020.2 는 string ? : 에서 죽는 경우가 있어서 함수로)
    function automatic string pick(input bit c, input string a, input string b);
        if (c) return a;
        return b;
    endfunction

    function automatic string xz_str();
        if (xz_seen) return $sformatf("at %0.3f ms", t_xz / 1.0e6);
        return "none";
    endfunction

    task automatic log(input string tag, input string msg);
        $display("%s [%s] %s", ts(), pad7(tag), msg);
    endtask

    task automatic note(input string msg);
        log("NOTE", msg);
    endtask

    function automatic bit run(input string id);
        string o;
        o = ONLY;
        void'($value$plusargs("only=%s", o));
        void'($value$plusargs("only_%s", o));   // run_xsim.bat 용 (cmd 가 '=' 를 쪼개서)
        return (o == "") || (o == id) || (o == id.substr(0, 0));
    endfunction

    initial begin
        string o;
        o = ONLY;
        void'($value$plusargs("only=%s", o));
        void'($value$plusargs("only_%s", o));
        if (o != "") log("NOTE", {"only scenario / group : ", o});
    end

    task automatic end_sc();
        if (cur_sc != "") begin
            sc_result.push_back($sformatf("%s checks %0d  %s", padn(cur_sc, 4), n_chk - sc_chk0,
                                          pick(n_fail == sc_fail0, "PASS", "FAIL")));
            cur_sc = "";
        end
    endtask

    task automatic begin_sc(input string id, input string title, input string plan, input string expect_s);
        end_sc();
        cur_sc   = id;
        W_SC     = s2v(id);
        sc_fail0 = n_fail;
        sc_chk0  = n_chk;
        $display("");
        $display("==========================================================================================");
        log("BEGIN", {id, "  ", title});
        $display("              plan   : %s", plan);
        $display("              expect : %s", expect_s);
        $display("------------------------------------------------------------------------------------------");
    endtask

    task automatic check(input string id, input bit ok, input string desc, input string exp_s, input string got_s);
        n_chk++;
        W_CHK = s2v(id);
        W_RES = s2v(ok ? "OK" : "FAIL");
        if (ok) begin
            log("OK", $sformatf("%s %s | exp %s | got %s", padn(id, 6), desc, exp_s, got_s));
        end else begin
            n_fail++;
            fail_ids.push_back(id);
            log("FAIL", $sformatf("%s %s | exp %s | got %s", padn(id, 6), desc, exp_s, got_s));
        end
    endtask

    // ⚠ 항목 : ok = 스펙대로 동작. 아니면 ISSUE (FAIL 과 따로 셈)
    task automatic spec(input string id, input bit ok, input string desc, input string exp_s, input string got_s);
        n_chk++;
        W_CHK = s2v(id);
        W_RES = s2v(ok ? "OK" : "ISSUE");
        if (ok) begin
            log("OK", $sformatf("%s %s | exp %s | got %s", padn(id, 6), desc, exp_s, got_s));
        end else begin
            n_issue++;
            issue_ids.push_back(id);
            log("ISSUE", $sformatf("%s %s | spec %s | got %s  (tb_scenario.md 2 jang)", padn(id, 6), desc, exp_s, got_s));
        end
    endtask

    task automatic finish_tb();
        end_sc();
        $display("");
        $display("==========================================================================================");
        foreach (sc_result[i]) $display("  %s", sc_result[i]);
        $display("------------------------------------------------------------------------------------------");
        $display("  UART lines : %0d received, snapshot mismatch %0d, unexpected %0d, no CR %0d, frame err %0d",
                 lines.size(), n_line_mis, n_line_unexp, n_bad_line, tx_frame_err);
        $display("  x/z on outputs : %s", xz_str());
        if (fail_ids.size() > 0) begin
            $write("  FAIL ids  :");
            foreach (fail_ids[i]) $write(" %s", fail_ids[i]);
            $display("");
        end
        if (issue_ids.size() > 0) begin
            $write("  ISSUE ids :");
            foreach (issue_ids[i]) $write(" %s", issue_ids[i]);
            $display("");
        end
        $display("%s [SUMMARY] %s checks=%0d fail=%0d issue=%0d => %s", ts(), TB_ID, n_chk, n_fail, n_issue,
                 pick(n_fail == 0, "PASS", "FAIL"));
        $display("==========================================================================================");
        $finish;
    endtask

    initial begin
        #(TIMEOUT_MS * MS);
        n_fail++;
        fail_ids.push_back({"TIMEOUT@", cur_sc});
        log("FAIL", $sformatf("TIMEOUT : %0d ms 지남 (scenario %s)", TIMEOUT_MS, cur_sc));
        finish_tb();
    end

    // =========================================================================
    // 시간 · 리셋
    // =========================================================================
    bit      started = 0;      // 첫 리셋 해제 뒤 1
    realtime t_rel = 0;        // 마지막 리셋 해제 (w_rst 0 이 된 클럭 엣지)
    integer  rst_rel_clk = 0;  // rst 하강 뒤 w_rst 해제까지 클럭 수

    task automatic wait_us(input real t); #(t * US); endtask
    task automatic wait_ms(input real t); #(t * MS); endtask
    task automatic wait_clk(input integer n); repeat (n) @(posedge clk); endtask
    task automatic wait_until(input realtime t); if (t > $realtime) #(t - $realtime); endtask

    task automatic rst_assert();
        rst = 1'b1;
    endtask

    task automatic rst_release();
        integer n;
        rst = 1'b0;
        n = 0;
        while (dut.w_rst !== 1'b0) begin
            @(posedge clk);
            #1;
            n++;
        end
        rst_rel_clk = n;
        t_rel       = $realtime - 1;
        started     = 1;
        line_rd     = lines.size();
    endtask

    task automatic do_reset();
        btn_R = 0; btn_L = 0; btn_U = 0; btn_D = 0;
        rx = 1'b1;
        uart_err = 0.0;
        rst_assert();
        #(1 * US);
        rst_release();
        #(1 * US);
    endtask

    // =========================================================================
    // 버튼 · 스위치
    // =========================================================================
    task automatic set_sw(input [6:0] v);
        sw = v;
        #(1 * US);
    endtask

    task automatic set_btn(input integer b, input bit v);
        case (b)
            BR: btn_R = v;
            BL: btn_L = v;
            BU: btn_U = v;
            default: btn_D = v;
        endcase
    endtask

    // 물리 핀을 ms 동안 누름 (디바운서 통과)
    task automatic press(input integer b, input real ms_hold);
        set_btn(b, 1'b1);
        #(ms_hold * MS);
        set_btn(b, 1'b0);
    endtask

    // n 번 토글 (us_per 간격) 뒤 final_v 유지. 마지막 엣지 시각을 돌려줌
    task automatic bounce(input integer b, input integer n, input real us_per, input bit final_v, output realtime t_last);
        for (int i = 0; i < n; i++) begin
            set_btn(b, (i % 2 == 0) ? final_v : ~final_v);
            #(us_per * US);
        end
        set_btn(b, final_v);
        t_last = $realtime;
    endtask

    // 디바운서 출력 (w_phy_btn_*) 에 1 clk 펄스 : t_edge 클럭 엣지에서 보임 (정밀 타이밍용)
    realtime t_last_pulse = 0;

    task automatic phy_force(input integer b, input bit v);
        if (v) begin
            case (b)
                BR: force dut.w_phy_btn_R = 1'b1;
                BL: force dut.w_phy_btn_L = 1'b1;
                BU: force dut.w_phy_btn_U = 1'b1;
                default: force dut.w_phy_btn_D = 1'b1;
            endcase
        end else begin
            case (b)
                BR: release dut.w_phy_btn_R;
                BL: release dut.w_phy_btn_L;
                BU: release dut.w_phy_btn_U;
                default: release dut.w_phy_btn_D;
            endcase
        end
    endtask

    task automatic pulse_phy_at(input integer b, input realtime t_edge);
        wait_until(t_edge - 4.0);
        phy_force(b, 1'b1);
        @(posedge clk);
        t_last_pulse = $realtime;
        #1;
        phy_force(b, 1'b0);
    endtask

    task automatic pulse_phy(input integer b);
        @(posedge clk);
        pulse_phy_at(b, $realtime + 10.0);
        repeat (3) @(posedge clk);
    endtask

    // 두 버튼을 같은 클럭에
    task automatic pulse_phy2(input integer b1, input integer b2);
        @(posedge clk);
        #6;
        phy_force(b1, 1'b1);
        phy_force(b2, 1'b1);
        @(posedge clk);
        t_last_pulse = $realtime;
        #1;
        phy_force(b1, 1'b0);
        phy_force(b2, 1'b0);
        repeat (3) @(posedge clk);
    endtask

    // 펄스 카운터 : pc = 디바운서 출력, bc = 물리 | UART (화면 게이팅 전), uc = UART /btn
    wire [3:0] w_pc = {dut.w_phy_btn_D, dut.w_phy_btn_U, dut.w_phy_btn_L, dut.w_phy_btn_R};
    wire [3:0] w_bc = {dut.w_btn_D, dut.w_btn_U, dut.w_btn_L, dut.w_btn_R};
    wire [3:0] w_uc = {dut.w_uart_btn_D, dut.w_uart_btn_U, dut.w_uart_btn_L, dut.w_uart_btn_R};
    integer  pc[4] = '{0, 0, 0, 0};
    integer  bc[4] = '{0, 0, 0, 0};
    integer  uc[4] = '{0, 0, 0, 0};
    realtime t_pc[4], t_bc[4], t_bc_prev[4], t_uc[4];
    integer  pw_long = 0;          // 디바운서 펄스가 2 clk 이상 이어진 횟수
    reg [3:0] pc_prev = 4'd0;
    integer  sr_btnR_cnt = 0, dh_btnR_cnt = 0;   // 게이팅 뒤 센서 모듈에 실제로 들어간 R

    always @(posedge clk) if (started) begin
        for (int i = 0; i < 4; i++) begin
            if (w_pc[i]) begin pc[i]++; t_pc[i] = $realtime; end
            if (w_pc[i] && pc_prev[i]) pw_long++;
            if (w_bc[i]) begin bc[i]++; t_bc_prev[i] = t_bc[i]; t_bc[i] = $realtime; end
            if (w_uc[i]) begin uc[i]++; t_uc[i] = $realtime; end
        end
        pc_prev = w_pc;
        if (dut.U_SR04.i_btn_R) sr_btnR_cnt++;
        if (dut.U_DHT11.i_btn_R) dh_btnR_cnt++;
    end

    // =========================================================================
    // PC → FPGA UART (9600 8N1)
    // =========================================================================

    task automatic uart_byte(input [7:0] b, input bit stop = 1'b1);
        real bt;
        bt = BIT_NS / (1.0 + uart_err);
        rx = 1'b0;
        #(bt);
        for (int i = 0; i < 8; i++) begin
            rx = b[i];
            #(bt);
        end
        rx = stop;
        #(bt);
        rx = 1'b1;
    endtask

    task automatic uart_send(input string s);
        W_CMD = s2v(s);
        for (int i = 0; i < s.len(); i++) uart_byte(s[i]);
        #(2 * US);
    endtask

    task automatic uart_cr();
        W_CMD = {W_CMD[8*15-1:0], "#"};
        uart_byte(8'h0D);
        #(2 * US);
    endtask

    task automatic uart_line(input string s);   // s + CR
        for (int i = 0; i < s.len(); i++) uart_byte(s[i]);
        uart_byte(8'h0D);
        #(2 * US);
    endtask

    task automatic mod(input string m);  uart_send({"/mod ", m}); endtask
    task automatic ubtn(input string c); uart_send({"/btn ", c}); endtask
    task automatic uget();               uart_line("/get ");      endtask

    // 수신 쪽 모니터 (DUT 안)
    realtime t_rx_done = 0, t_hs = 0, t_ctrl_chg = 0;
    integer  n_rx = 0, n_hs = 0, n_err = 0;
    reg [7:0] rx_last = 8'd0;
    bit      rx_full_seen = 0;

    always @(posedge clk) if (started) begin
        if (dut.U_UART.w_rx_done)   begin n_rx++; t_rx_done = $realtime; rx_last = dut.U_UART.w_rx_data; end
        if (dut.U_UART.w_handshake) begin n_hs++; t_hs = $realtime; end
        if (dut.U_UART.w_error)     n_err++;
        if (dut.U_UART.w_rx_full)   rx_full_seen = 1;
    end

    always @(dut.w_ctrl_bit) t_ctrl_chg = $realtime;

    // =========================================================================
    // FPGA → PC UART 모니터 : 줄 단위 + go 스냅샷과 비교
    // =========================================================================

    // sender_char_mux 와 같은 글자 계산 (8'h30 + 값, 8 비트로 자름)
    function automatic [7:0] dg(input integer v);
        return 8'h30 + v;
    endfunction

    // (v2, 10/31) 거리 d[10:9] = 상태 (00 정상) → "Err N" / 온습도 d[19] err → "Err N", d[18] dashes → "--%--C"
    function automatic string fmt_line(input [2:0] sel, input [23:0] d);
        integer hh, mi, se, cs, cm, hu, te;
        hh = d[23:19]; mi = d[18:13]; se = d[12:7]; cs = d[6:0];
        cm = d[8:0];   hu = d[15:8];  te = d[7:0];
        if (sel == 3'd3 && d[10:9] != 2'b00) return $sformatf("Err %0d", d[10:9]);
        if (sel == 3'd4 && d[19])            return $sformatf("Err %0d", d[17:16]);
        if (sel == 3'd4 && d[18])            return "--%--C";
        case (sel)
            3'd0, 3'd1, 3'd2:
                return $sformatf("%c%c:%c%c:%c%c.%c%c", dg(hh / 10), dg(hh % 10), dg(mi / 10), dg(mi % 10),
                                 dg(se / 10), dg(se % 10), dg(cs / 10), dg(cs % 10));
            3'd3:    return $sformatf("%c%c%ccm", dg(cm / 100), dg((cm / 10) % 10), dg(cm % 10));
            3'd4:    return $sformatf("%c%c%%%c%cC", dg(hu / 10), dg(hu % 10), dg(te / 10), dg(te % 10));
            default: return "ERROR";
        endcase
    endfunction

    // sender 가 go 를 받는 클럭에 잡는 sel · data → 이 줄이 나와야 함
    always @(posedge clk) if (started) begin
        if (dut.U_UART.w_send_go && (dut.U_UART.U_ASCII_SENDER.c_state == 1'b0))
            exp_q.push_back(fmt_line(dut.U_UART.o_send_sel, dut.U_UART.w_send_data));
    end

    always begin : TXMON
        reg [7:0] c;
        realtime  tb;
        string    s, e;
        @(negedge tx);
        tb = $realtime;
        #(TX_BIT_NS / 2);
        if (tx == 1'b0) begin
            for (int i = 0; i < 8; i++) begin
                #(TX_BIT_NS);
                c[i] = tx;
            end
            #(TX_BIT_NS);
            if (tx !== 1'b1) tx_frame_err++;
            n_tx_bytes++;
            if (!in_line) begin
                in_line = 1;
                cur_t0  = tb;
            end
            if (c == 8'h0A) begin
                s = cur_line;
                if (s.len() > 0 && s[s.len() - 1] == 8'h0D) s = s.substr(0, s.len() - 2);
                else n_bad_line++;
                lines.push_back(s);
                W_LINE = s2v(s);
                line_t0.push_back(cur_t0);
                line_t1.push_back($realtime + TX_BIT_NS / 2);
                if (exp_q.size() > 0) begin
                    e = exp_q.pop_front();
                    if (e != s) begin
                        n_line_mis++;
                        log("WARN", $sformatf("tx line \"%s\" != go snapshot \"%s\"", s, e));
                    end
                end else begin
                    n_line_unexp++;
                    log("WARN", $sformatf("tx line \"%s\" without send_go", s));
                end
                cur_line = "";
                in_line  = 0;
            end else begin
                cur_line = $sformatf("%s%c", cur_line, c);
            end
        end
    end

    // 다음 줄 (없으면 tmo_ns 까지 기다림). 못 받으면 s = "<none>"
    task automatic next_line(output string s, output realtime t0, input real tmo_ns);
        realtime tend;
        tend = $realtime + tmo_ns;
        while ((line_rd >= lines.size()) && ($realtime < tend)) #(1 * US);
        if (line_rd < lines.size()) begin
            s       = lines[line_rd];
            t0      = line_t0[line_rd];
            last_t1 = line_t1[line_rd];
            line_rd++;
        end else begin
            s  = "<none>";
            t0 = -1;
        end
    endtask

    function automatic integer lines_pending();
        return lines.size() - line_rd;
    endfunction

    task automatic flush_lines();
        line_rd = lines.size();
    endtask

    // tx 가 quiet_ms 동안 조용할 때까지
    task automatic wait_tx_quiet(input real quiet_ms);
        integer n0;
        do begin
            n0 = n_tx_bytes;
            #(quiet_ms * MS);
        end while ((n_tx_bytes != n0) || (tx !== 1'b1) || in_line);
    endtask

    function automatic bit is_dig(input [7:0] c);
        return (c >= "0") && (c <= "9");
    endfunction

    function automatic bit is_time(input string s);
        if (s.len() != 11) return 0;
        return is_dig(s[0]) && is_dig(s[1]) && (s[2] == ":") && is_dig(s[3]) && is_dig(s[4]) && (s[5] == ":")
            && is_dig(s[6]) && is_dig(s[7]) && (s[8] == ".") && is_dig(s[9]) && is_dig(s[10]);
    endfunction

    function automatic bit is_dist(input string s);
        if (s.len() != 5) return 0;
        return is_dig(s[0]) && is_dig(s[1]) && is_dig(s[2]) && (s[3] == "c") && (s[4] == "m");
    endfunction

    // (v2) 센서 오류 줄 "Err 1" ~ "Err 3"
    function automatic bit is_err(input string s);
        if (s.len() != 5) return 0;
        return (s.substr(0, 3) == "Err ") && (s[4] >= "1") && (s[4] <= "3");
    endfunction

    function automatic bit is_temp(input string s);
        if (s.len() != 6) return 0;
        return is_dig(s[0]) && is_dig(s[1]) && (s[2] == "%") && is_dig(s[3]) && is_dig(s[4]) && (s[5] == "C");
    endfunction

    // =========================================================================
    // FND 읽기 : 8 칸 (2 ms) 모아서 "12.34" · "Err1" · "----" · "000.0"
    // =========================================================================
    function automatic [7:0] seg2ch(input [6:0] seg);
        case (seg)
            7'h40: return "0";
            7'h79: return "1";
            7'h24: return "2";
            7'h30: return "3";
            7'h19: return "4";
            7'h12: return "5";
            7'h02: return "6";
            7'h78: return "7";
            7'h00: return "8";
            7'h10: return "9";
            7'h06: return "E";
            7'h2F: return "r";
            7'h3F: return "-";
            7'h7F: return " ";
            default: return "?";
        endcase
    endfunction

    function automatic integer com2an(input [3:0] com);
        case (com)
            4'b1110: return 0;
            4'b1101: return 1;
            4'b1011: return 2;
            4'b0111: return 3;
            default: return -1;
        endcase
    endfunction

    task automatic fnd_read(output string s);
        reg [7:0] ch[4];
        bit       dp[4];
        integer   an;
        reg [2:0] sel;
        for (int i = 0; i < 4; i++) begin ch[i] = "?"; dp[i] = 0; end
        for (int k = 0; k < 8; k++) begin
            @(posedge dut.w_clk_4khz);
            repeat (3) @(posedge clk);
            #1;
            sel = dut.U_FND_CONTROLLER.w_scan_sel;
            an  = com2an(fnd_com);
            if (an >= 0) begin
                if (sel < 4) ch[an] = seg2ch(fnd_font[6:0]);
                else         dp[an] = ~fnd_font[7];
            end
        end
        s = "";
        for (int a = 3; a >= 0; a--) begin
            s = $sformatf("%s%c", s, ch[a]);
            if (dp[a]) s = {s, "."};
        end
    endtask

    // 파형용 FND 문자열 (fnd_read 와 같은 방법으로 2 ms 마다 W_FND 갱신)
    always begin : FNDMON
        reg [7:0] ch[4];
        bit       dp[4];
        integer   an;
        reg [2:0] sel;
        string    t;
        for (int i = 0; i < 4; i++) begin ch[i] = " "; dp[i] = 0; end
        for (int k = 0; k < 8; k++) begin
            @(posedge dut.w_clk_4khz);
            repeat (3) @(posedge clk);
            #1;
            sel = dut.U_FND_CONTROLLER.w_scan_sel;
            an  = com2an(fnd_com);
            if (an >= 0) begin
                if (sel < 4) ch[an] = seg2ch(fnd_font[6:0]);
                else         dp[an] = ~fnd_font[7];
            end
        end
        t = "";
        for (int a = 3; a >= 0; a--) begin
            t = $sformatf("%s%c", t, ch[a]);
            if (dp[a]) t = {t, "."};
        end
        W_FND = s2v(t);
    end

    // 두 번 연속 같은 글자가 나올 때까지 (값이 바뀌는 중에 읽는 경우 대비)
    task automatic fnd_read_stable(output string s);
        string a, b;
        fnd_read(a);
        for (int i = 0; i < 6; i++) begin
            fnd_read(b);
            if (a == b) break;
            a = b;
        end
        s = b;
    endtask

    function automatic string strip_dot(input string s);
        string r;
        r = "";
        for (int i = 0; i < s.len(); i++) if (s[i] != ".") r = $sformatf("%s%c", r, s[i]);
        return r;
    endfunction

    // =========================================================================
    // WTS 값 읽기 · 프리로드 (경계 바로 앞으로 건너뛰기, 카운터 레지스터 force 1 clk)
    // =========================================================================
    function automatic integer hms2cs(input integer hh, input integer mi, input integer se, input integer cs);
        return ((hh * 60 + mi) * 60 + se) * 100 + cs;
    endfunction

    function automatic string cs2str(input integer v);
        return $sformatf("%02d:%02d:%02d.%02d", v / 360000, (v / 6000) % 60, (v / 100) % 60, v % 100);
    endfunction

    function automatic integer sw_cnt_cs();   // 스톱워치 카운터 실제 값
        return hms2cs(dut.U_WTS.U_STOPWATCH_DATAPATH.w_cnt_hour, dut.U_WTS.U_STOPWATCH_DATAPATH.w_cnt_min,
                      dut.U_WTS.U_STOPWATCH_DATAPATH.w_cnt_sec, dut.U_WTS.U_STOPWATCH_DATAPATH.w_cnt_msec);
    endfunction

    function automatic integer sw_disp_cs();  // 랩 반영 값 (화면 · UART)
        return hms2cs(dut.U_WTS.w_sw_hour, dut.U_WTS.w_sw_min, dut.U_WTS.w_sw_sec, dut.U_WTS.w_sw_msec);
    endfunction

    function automatic integer wt_cs();       // 시계 (24 h 값)
        return hms2cs(dut.U_WTS.w_wt_hour, dut.U_WTS.w_wt_min, dut.U_WTS.w_wt_sec, dut.w_wt_msec);
    endfunction

    function automatic integer tm_cs();       // 타이머 남은 시간
        return hms2cs(0, dut.U_WTS.w_tm_min, dut.U_WTS.w_tm_sec, dut.U_WTS.w_tm_msec);
    endfunction

    task preload_sw(input integer hh, input integer mi, input integer se, input integer cs);
        @(negedge clk);
        force dut.U_WTS.U_STOPWATCH_DATAPATH.U_HOUR_COUNTER.counter_reg = hh;
        force dut.U_WTS.U_STOPWATCH_DATAPATH.U_MIN_COUNTER.counter_reg  = mi;
        force dut.U_WTS.U_STOPWATCH_DATAPATH.U_SEC_COUNTER.counter_reg  = se;
        force dut.U_WTS.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.counter_reg = cs;
        @(negedge clk);
        release dut.U_WTS.U_STOPWATCH_DATAPATH.U_HOUR_COUNTER.counter_reg;
        release dut.U_WTS.U_STOPWATCH_DATAPATH.U_MIN_COUNTER.counter_reg;
        release dut.U_WTS.U_STOPWATCH_DATAPATH.U_SEC_COUNTER.counter_reg;
        release dut.U_WTS.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.counter_reg;
        log("PRELOAD", $sformatf("stopwatch <- %02d:%02d:%02d.%02d", hh, mi, se, cs));
    endtask

    task preload_wt(input integer hh, input integer mi, input integer se, input integer cs);
        @(negedge clk);
        force dut.U_WTS.U_WATCH_DATAPATH.U_HOUR_COUNTER.counter_reg = hh;
        force dut.U_WTS.U_WATCH_DATAPATH.U_MIN_COUNTER.counter_reg  = mi;
        force dut.U_WTS.U_WATCH_DATAPATH.U_SEC_COUNTER.counter_reg  = se;
        force dut.U_WTS.U_WATCH_DATAPATH.U_MSEC_COUNTER.counter_reg = cs;
        @(negedge clk);
        release dut.U_WTS.U_WATCH_DATAPATH.U_HOUR_COUNTER.counter_reg;
        release dut.U_WTS.U_WATCH_DATAPATH.U_MIN_COUNTER.counter_reg;
        release dut.U_WTS.U_WATCH_DATAPATH.U_SEC_COUNTER.counter_reg;
        release dut.U_WTS.U_WATCH_DATAPATH.U_MSEC_COUNTER.counter_reg;
        log("PRELOAD", $sformatf("watch <- %02d:%02d:%02d.%02d", hh, mi, se, cs));
    endtask

    // WTS 값이 바뀐 시각 (tick 타이밍 판정용)
    realtime t_sw_ms_chg = 0, t_wt_sec_chg = 0, t_alarm = 0;
    always @(dut.U_WTS.U_STOPWATCH_DATAPATH.w_cnt_msec) t_sw_ms_chg = $realtime;
    always @(dut.U_WTS.w_wt_sec) t_wt_sec_chg = $realtime;
    always @(posedge dut.w_tm_alarm) t_alarm = $realtime;

    // =========================================================================
    // SR04 센서 모델 : trig ↓ + sr_dly_us 뒤 echo 를 sr_w_us 동안 1  (단위 = SR04 의 "us" = SR_US ns)
    //   SR_NONE = echo 안 줌, SR_MANUAL = TB 가 echo 를 직접 움직임
    // =========================================================================
    integer  sr_mode = SR_NORMAL;
    real     sr_dly_us = 500.0;
    real     sr_w_us = 1000.0;
    integer  trig_cnt = 0;
    realtime t_trig_r = 0, t_trig_f = 0, trig_w = 0, t_echo_r = 0, t_echo_f = 0;
    realtime trig_r_q[$];

    always begin : SRMODEL
        @(posedge trig);
        t_trig_r = $realtime;
        trig_cnt++;
        trig_r_q.push_back(t_trig_r);
        @(negedge trig);
        t_trig_f = $realtime;
        trig_w   = t_trig_f - t_trig_r;
        if (sr_mode == SR_NORMAL) begin
            #(sr_dly_us * SR_US);
            echo = 1'b1;
            t_echo_r = $realtime;
            #(sr_w_us * SR_US);
            echo = 1'b0;
            t_echo_f = $realtime;
        end
    end

    // 측정 완료 (o_done) 모니터
    integer  n_dist_done = 0;
    realtime t_dist_done = 0;
    reg [1:0] dist_st = 2'd0;
    always @(posedge clk) if (started && dut.w_dist_done) begin
        n_dist_done++;
        t_dist_done = $realtime;
        dist_st     = dut.w_dist_status;
    end

    task automatic wait_dist_done(input real tmo_ms, output bit ok);
        integer  n0;
        realtime tend;
        n0   = n_dist_done;
        tend = $realtime + tmo_ms * MS;
        while ((n_dist_done == n0) && ($realtime < tend)) #(1 * US);
        ok = (n_dist_done != n0);
        #(1 * US);
    endtask

    task automatic wait_sr_idle(input real tmo_ms);
        realtime tend;
        tend = $realtime + tmo_ms * MS;
        while ((dut.U_SR04.w_busy !== 1'b0) && ($realtime < tend)) #(1 * US);
    endtask

    // =========================================================================
    // DHT11 센서 모델 : FPGA 가 선을 LOW 로 (≥ 시작 LOW 의 절반) 잡았다가 놓으면 응답  (단위 = DH_US)
    //   해제 → 30 us → LOW 80 → HIGH 80 → {LOW 50, HIGH hi0 / hi1} × nbits → LOW 50 → 해제
    // =========================================================================
    integer   dh_mode = DH_NORMAL;
    reg [7:0] dh_data[4] = '{8'd55, 8'd0, 8'd24, 8'd0};   // 습도 · 습도 소수 · 온도 · 온도 소수
    integer   dh_chk_off = 0;                               // 체크섬에 더할 값 (오류 주입)
    real      dh_hi0 = 26.0, dh_hi1 = 70.0;                 // 비트 HIGH 길이 (us)
    integer   dh_nbits = 40;                                // 이만큼 보내고 끊기 (40 = 정상)
    real      dh_start_det_us = 9_000.0;                    // 시작 LOW 판정 (START_US 18 ms 의 절반)
    integer   dh_start_cnt = 0;
    realtime  t_oe_r = 0, t_oe_f = 0, dh_start_w = 0, t_dh_last_rise = 0;
    realtime  dh_start_q[$];
    bit       dh_contention = 0;

    task automatic dh_frame();
        reg [7:0]  chk;
        reg [39:0] f;
        chk = dh_data[0] + dh_data[1] + dh_data[2] + dh_data[3] + dh_chk_off;
        f   = {dh_data[0], dh_data[1], dh_data[2], dh_data[3], chk};
        #(30 * DH_US);
        dht_drv = 1'b1;
        #(80 * DH_US);
        dht_drv = 1'b0;
        t_dh_last_rise = $realtime;
        #(80 * DH_US);
        for (int i = 0; i < dh_nbits; i++) begin
            dht_drv = 1'b1;
            #(50 * DH_US);
            dht_drv = 1'b0;
            t_dh_last_rise = $realtime;
            #((f[39 - i] ? dh_hi1 : dh_hi0) * DH_US);
        end
        if (dh_nbits == 40) begin
            dht_drv = 1'b1;
            #(50 * DH_US);
            dht_drv = 1'b0;
        end
    endtask

    always begin : DHMODEL
        @(posedge dut.U_DHT11.w_dht_oe);
        t_oe_r = $realtime;
        dh_start_cnt++;
        dh_start_q.push_back(t_oe_r);
        @(negedge dut.U_DHT11.w_dht_oe);
        t_oe_f     = $realtime;
        dh_start_w = t_oe_f - t_oe_r;
        if (dh_start_w >= dh_start_det_us * DH_US) begin
            if (dh_mode == DH_STUCK)       dht_drv = 1'b1;   // TB 가 풀 때까지 LOW
            else if (dh_mode == DH_NORMAL) dh_frame();
        end
    end

    always @(posedge clk) if (dut.U_DHT11.w_dht_oe && dht_drv) dh_contention = 1;

    integer  n_dht_done = 0;
    realtime t_dht_done = 0;
    reg [1:0] dht_st = 2'd0;
    always @(posedge clk) if (started && dut.w_dht_done) begin
        n_dht_done++;
        t_dht_done = $realtime;
        dht_st     = dut.w_dht_status;
    end

    task automatic wait_dht_done(input real tmo_ms, output bit ok);
        integer  n0;
        realtime tend;
        n0   = n_dht_done;
        tend = $realtime + tmo_ms * MS;
        while ((n_dht_done == n0) && ($realtime < tend)) #(1 * US);
        ok = (n_dht_done != n0);
        #(1 * US);
    endtask

    task automatic dh_default();
        dh_mode = DH_NORMAL;
        dh_data = '{8'd55, 8'd0, 8'd24, 8'd0};
        dh_chk_off = 0;
        dh_hi0 = 26.0;
        dh_hi1 = 70.0;
        dh_nbits = 40;
        dht_drv = 1'b0;
    endtask

    // =========================================================================
    // 리셋이 들어오면 모델 · 모니터를 처음 상태로
    // =========================================================================
    always @(posedge rst) begin
        disable TXMON;
        disable SRMODEL;
        disable DHMODEL;
        if (sr_mode != SR_MANUAL) echo = 1'b0;
        dht_drv  = 1'b0;
        cur_line = "";
        in_line  = 0;
        exp_q.delete();
    end

    // 출력 핀 x / z 감시 (리셋 해제 뒤)
    always @(posedge clk) if (started && !rst && (dut.w_rst === 1'b0)) begin
        if (!xz_seen && $isunknown({led, fnd_com, fnd_font, tx, trig})) begin
            xz_seen = 1;
            t_xz    = $realtime;
            log("WARN", "x/z on output pins");
        end
    end

endmodule
