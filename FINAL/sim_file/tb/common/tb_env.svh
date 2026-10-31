// =============================================================================
// tb_env.svh — merge_final_top 공통 TB 환경 (LEAD 작성, 작업자는 수정 금지)
//
// 사용법 : TB 모듈 "안" 에서 include 한다. DUT · 클럭 · BFM · 모니터 · 스코어보드가 전부 들어온다.
//
//   `timescale 1ns / 1ps
//   module tb_G1;
//       `include "tb_env.svh"
//       initial begin
//           env_start("tb_G1", 3 * SEC);         // 이름, 워치독 (시뮬 시간)
//           uart_send_str("/mod dist");
//           ...
//           check("G1-01", led == 16'h0000, "설명");
//           env_finish();
//       end
//   endmodule
//
// 규칙
//   - 시간 단위 ns. 상수 US · MS · SEC 를 곱해서 쓴다 (예 : #(18 * MS)).
//   - defparam · 파라미터 축소 금지 (실시간 기준). force 는 시나리오 문서가 허용한 경로만.
//   - 판정은 check / check_known / info 로만 출력 (결과 취합 스크립트가 이 형식을 읽음).
//   - Verilator 5.032 (--binary --timing) 와 Vivado xsim 둘 다에서 돌아가는 문법만 쓴다.
// =============================================================================

// ---------------------------------------------------------------- 시간 상수 (ns)
localparam longint US  = 1_000;
localparam longint MS  = 1_000_000;
localparam longint SEC = 1_000_000_000;

localparam longint CLK_NS      = 10;          // 100 MHz
localparam longint UART_BIT_NS = 104_160;     // DUT 실제 bit 폭 (651 clk x 16)

// ---------------------------------------------------------------- DUT 핀
reg         clk = 1'b0;
reg         rst = 1'b1;
reg         btn_R = 1'b0, btn_L = 1'b0, btn_U = 1'b0, btn_D = 1'b0;
reg         mode_sw0 = 1'b0, display_mode_sw1 = 1'b0, set_sw2 = 1'b0, hour24_sw3 = 1'b0;
reg         timer_sw4 = 1'b0, dist_sw5 = 1'b0, dht_sw6 = 1'b0, dist_led_sw15 = 1'b0;
reg         rx = 1'b1;
reg         echo = 1'b0;
wire        tx, trig;
wire        dht11_io;
wire [ 3:0] fnd_com;
wire [ 7:0] fnd_font;
wire [15:0] led;

always #(CLK_NS / 2) clk = ~clk;

// DHT11 데이터선 : 보드 풀업 + 센서 모델 (LOW 만 구동)
reg dht_sensor_low = 1'b0;     // 센서 모델이 LOW 구동
reg dht_stuck_low  = 1'b0;     // TB 가 1 로 두면 선 LOW 고착 (J7)
pullup (dht11_io);
assign dht11_io = (dht_sensor_low | dht_stuck_low) ? 1'b0 : 1'bz;

merge_final_top dut (
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
    .dist_sw5        (dist_sw5),
    .dht_sw6         (dht_sw6),
    .dist_led_sw15   (dist_led_sw15),
    .rx              (rx),
    .tx              (tx),
    .trig            (trig),
    .echo            (echo),
    .dht11_io        (dht11_io),
    .fnd_com         (fnd_com),
    .fnd_font        (fnd_font),
    .led             (led)
);

// =============================================================================
// 스코어보드
// =============================================================================
string  tb_name  = "tb";
int     sb_pass  = 0;
int     sb_fail  = 0;
int     sb_known = 0;   // ⚠ 항목 : 예상한 설계 이슈가 재현됨
int     sb_xpass = 0;   // ⚠ 항목 : 이슈가 재현 안 됨 (스펙대로 동작)

function automatic string t_ms();      // 현재 시각 "1234.567890 ms"
    return $sformatf("%0.6f ms", $realtime / 1.0e6);
endfunction

// 일반 판정. id 는 "<시나리오>-<번호>" (예 "G1-03"). cond = 기대대로면 1.
task automatic check(input string id, input bit cond, input string msg);
    if (cond) begin
        sb_pass++;
        $display("[PASS] %s @ %s : %s", id, t_ms(), msg);
    end else begin
        sb_fail++;
        $display("[FAIL] %s @ %s : %s", id, t_ms(), msg);
    end
endtask

// ⚠ 항목 (tb_scenario.md 2 장). spec_ok = 스펙(README)대로 동작하면 1.
//   0 이면 [KNOWN] (예상한 설계 이슈 재현), 1 이면 [XPASS] (이슈 없음 — 원인 확인 필요)
task automatic check_known(input string id, input bit spec_ok, input string msg);
    if (spec_ok) begin
        sb_xpass++;
        $display("[XPASS] %s @ %s : %s", id, t_ms(), msg);
    end else begin
        sb_known++;
        $display("[KNOWN] %s @ %s : %s", id, t_ms(), msg);
    end
endtask

// 판정 없는 기록 (H9 개수, L6 스냅샷 등)
task automatic info(input string id, input string msg);
    $display("[INFO] %s @ %s : %s", id, t_ms(), msg);
endtask

task automatic env_finish();
    $display("[SUMMARY] %s pass=%0d fail=%0d known=%0d xpass=%0d @ %s",
             tb_name, sb_pass, sb_fail, sb_known, sb_xpass, t_ms());
    $finish;
endtask

// =============================================================================
// 시작 · 리셋
// =============================================================================
// 리셋 : rst 를 dur 동안 1 → 0, w_rst 풀릴 때까지 (2 clk) 기다림
task automatic env_reset(input longint dur = 1 * US);
    rst = 1'b1;
    #(dur);
    @(negedge clk);
    rst = 1'b0;
    repeat (3) @(posedge clk);
endtask

// 시작 : 이름 등록, 워치독 (시뮬 시간 timeout 넘으면 [FAIL] WATCHDOG 후 종료), 리셋
task automatic env_start(input string name, input longint timeout);
    tb_name = name;
    $display("[START] %s timeout=%0d ms", name, timeout / MS);
    fork
        begin
            #(timeout);
            sb_fail++;
            $display("[FAIL] %s-WATCHDOG @ %s : 시뮬 시간 초과", name, t_ms());
            env_finish();
        end
    join_none
    env_reset();
endtask

task automatic wait_clk(input int n);
    repeat (n) @(posedge clk);
endtask

// 스위치 7 비트 한 번에 : {sw6, sw5, sw4, sw3, sw2, sw1, sw0}
task automatic set_sw(input [6:0] v);
    {dht_sw6, dist_sw5, timer_sw4, hour24_sw3, set_sw2, display_mode_sw1, mode_sw0} = v;
endtask

// =============================================================================
// 버튼
// =============================================================================
// which : "R" "L" "U" "D"
task automatic btn_set(input byte which, input bit v);
    case (which)
        "R": btn_R = v;
        "L": btn_L = v;
        "U": btn_U = v;
        "D": btn_D = v;
        default: $display("[TBERR] btn_set : 모르는 버튼 %c", which);
    endcase
endtask

// 물리 버튼 dur 동안 누름 (기본 20 ms) + 뗀 뒤 gap (기본 20 ms) 대기
task automatic press(input byte which, input longint dur = 20 * MS, input longint gap = 20 * MS);
    btn_set(which, 1'b1);
    #(dur);
    btn_set(which, 1'b0);
    #(gap);
endtask

// 채터링 : n 번 토글 (간격 step) 뒤 level 로 고정
task automatic bounce(input byte which, input int n, input longint step, input bit level);
    for (int i = 0; i < n; i++) begin
        btn_set(which, ~level);
        #(step);
        btn_set(which, level);
        #(step);
    end
    btn_set(which, level);
endtask

// 디바운서 출력 (w_phy_btn_*) 에 1 clk 펄스를 force — 정밀 타이밍용 (H12, E5, L2)
//   negedge 에서 force → 다음 posedge 에 1 → 그 다음 negedge 에서 release
task automatic pulse_phy(input byte which);
    @(negedge clk);
    case (which)
        "R": force dut.w_phy_btn_R = 1'b1;
        "L": force dut.w_phy_btn_L = 1'b1;
        "U": force dut.w_phy_btn_U = 1'b1;
        "D": force dut.w_phy_btn_D = 1'b1;
        default: ;
    endcase
    @(negedge clk);
    case (which)
        "R": release dut.w_phy_btn_R;
        "L": release dut.w_phy_btn_L;
        "U": release dut.w_phy_btn_U;
        "D": release dut.w_phy_btn_D;
        default: ;
    endcase
endtask

// 실제 버튼 펄스 (게이팅 전, 물리 | UART) 카운터 — 판정에 사용
int  cnt_btn_R = 0, cnt_btn_L = 0, cnt_btn_U = 0, cnt_btn_D = 0;
time t_btn_R = 0, t_btn_L = 0, t_btn_U = 0, t_btn_D = 0;   // 마지막 펄스 시각
always @(posedge clk) begin
    if (dut.w_btn_R) begin cnt_btn_R++; t_btn_R = $time; end
    if (dut.w_btn_L) begin cnt_btn_L++; t_btn_L = $time; end
    if (dut.w_btn_U) begin cnt_btn_U++; t_btn_U = $time; end
    if (dut.w_btn_D) begin cnt_btn_D++; t_btn_D = $time; end
end

// =============================================================================
// UART BFM (PC → FPGA, rx 핀)
// =============================================================================
longint uart_tx_bit_ns = UART_BIT_NS;   // G8 baud 오차 시험 때 바꿈 (예 : UART_BIT_NS * 102 / 100)

// 한 바이트 8N1. stop_bit = 0 이면 stop 자리에 0 (G8 framing)
task automatic uart_send_byte(input byte b, input bit stop_bit = 1'b1);
    rx = 1'b0;                      // start
    #(uart_tx_bit_ns);
    for (int i = 0; i < 8; i++) begin
        rx = b[i];                  // LSB 먼저
        #(uart_tx_bit_ns);
    end
    rx = stop_bit;
    #(uart_tx_bit_ns);
    rx = 1'b1;
endtask

// 문자열 그대로 전송 (줄 끝은 넣지 않음 — 필요하면 "\r" / "\n" 직접 붙일 것)
task automatic uart_send_str(input string s, input longint gap = 0);
    for (int i = 0; i < s.len(); i++) begin
        uart_send_byte(s[i]);
        if (gap > 0) #(gap);
    end
endtask

// rx_done (DUT 수신 완료 펄스) 기록
int  rx_done_cnt = 0;
time rx_done_t   = 0;               // 마지막 rx_done 시각
always @(posedge clk) begin
    if (dut.U_UART.w_rx_done) begin
        rx_done_cnt++;
        rx_done_t = $time;
    end
end

// =============================================================================
// UART 모니터 (FPGA → PC, tx 핀) — 줄 단위 queue
// =============================================================================
//   uart_lines[i]     : 줄 내용 (CR LF 뺀 것). CR 없이 LF 만 오면 끝에 "<noCR>" 붙음
//   uart_line_t0[i]   : 그 줄 첫 바이트 start bit 시작 시각
//   uart_line_t1[i]   : LF 의 stop bit 끝 시각
//   uart_byte_cnt     : 받은 바이트 총수, uart_frame_err : stop bit 0 인 바이트 수
string  uart_lines[$];
time    uart_line_t0[$];
time    uart_line_t1[$];
int     uart_byte_cnt  = 0;
int     uart_frame_err = 0;
time    uart_last_byte_t0 = 0;      // 마지막 바이트 start 시각
string  uart_cur = "";
time    uart_cur_t0 = 0;

initial begin : uart_monitor
    byte b;
    time t0;
    forever begin
        @(negedge tx);
        t0 = $time;
        #(UART_BIT_NS / 2);
        if (tx !== 1'b0) continue;          // 글리치
        for (int i = 0; i < 8; i++) begin
            #(UART_BIT_NS);
            b[i] = tx;
        end
        #(UART_BIT_NS);
        if (tx !== 1'b1) uart_frame_err++;
        uart_byte_cnt++;
        uart_last_byte_t0 = t0;
        if (uart_cur.len() == 0) uart_cur_t0 = t0;
        if (b == 8'h0A) begin
            if (uart_cur.len() > 0 && uart_cur[uart_cur.len()-1] == 8'h0D)
                uart_cur = uart_cur.substr(0, uart_cur.len() - 2);
            else
                uart_cur = {uart_cur, "<noCR>"};
            uart_lines.push_back(uart_cur);
            uart_line_t0.push_back(uart_cur_t0);
            uart_line_t1.push_back($time + UART_BIT_NS / 2);
            $display("[UART] @ %s : \"%s\"", t_ms(), uart_cur);
            uart_cur = "";
        end else begin
            uart_cur = {uart_cur, string'(b)};
        end
    end
end

// 지금까지 받은 줄 비우기
task automatic uart_clear();
    uart_lines.delete();
    uart_line_t0.delete();
    uart_line_t1.delete();
endtask

// 줄이 n 개 이상 쌓일 때까지 대기 (timeout 넘으면 ok = 0)
task automatic uart_wait_lines(input int n, input longint timeout, output bit ok);
    time t_end;
    t_end = $time + timeout;
    ok = 1'b0;
    while ($time < t_end) begin
        if (uart_lines.size() >= n) begin
            ok = 1'b1;
            return;
        end
        #(10 * US);
    end
    ok = (uart_lines.size() >= n);
endtask

// =============================================================================
// SR04 센서 모델 (trig ↓ → sr04_dly_us 뒤 echo 1, sr04_echo_us 유지)
// =============================================================================
//   sr04_mode : 0 = 모델 끔 (TB 가 echo 직접 구동 — 고착 · 글리치 시험)
//               1 = 정상 응답
//               2 = 응답 없음 (echo 0 유지)
int     sr04_mode    = 1;
longint sr04_dly_us  = 500;        // trig ↓ → echo ↑ (0.5 ms)
longint sr04_echo_us = 583;        // echo 폭 (583 us = 10.0 cm)
int     sr04_trig_cnt = 0;
time    sr04_trig_rise_t = 0, sr04_trig_fall_t = 0;   // 마지막 trig ↑ · ↓ 시각
time    sr04_echo_fall_t = 0;                        // 모델이 마지막으로 echo 내린 시각

always @(posedge trig) begin
    sr04_trig_cnt++;
    sr04_trig_rise_t = $time;
end

initial begin : sr04_model
    forever begin
        @(negedge trig);
        sr04_trig_fall_t = $time;
        if (sr04_mode == 1) begin
            #(sr04_dly_us * US);
            echo = 1'b1;
            #(sr04_echo_us * US);
            echo = 1'b0;
            sr04_echo_fall_t = $time;
        end
    end
end

// =============================================================================
// DHT11 센서 모델
// =============================================================================
//   호스트 LOW ≥ dht_start_min 감지 → 선 해제 뒤 응답 :
//     dht_resp_dly_us LOW 대기 → 80 us LOW → 80 us HIGH → 40 비트 (50 us LOW + HIGH) → 50 us LOW → 해제
//   dht_mode : 0 = 모델 끔 (응답 없음 · Err1),  1 = 정상
//   dht_hi0_us / dht_hi1_us : 비트 0 / 1 의 HIGH 길이 (J4 경계 시험은 둘 다 같은 값으로)
//   dht_stop_after : >= 0 이면 그 비트 수만큼 보내고 선 놓고 끝 (J8 중간 끊김)
//   dht_chk_ofs : 체크섬에 더할 값 (J6 = 1)
int     dht_mode        = 1;
int     dht_hum_i = 55, dht_hum_d = 0, dht_tmp_i = 24, dht_tmp_d = 0;
int     dht_chk_ofs     = 0;
int     dht_resp_dly_us = 20;
int     dht_hi0_us      = 26;
int     dht_hi1_us      = 70;
int     dht_stop_after  = -1;
longint dht_start_min   = 17 * MS;
int     dht_start_cnt   = 0;        // 감지한 시작 신호 수
time    dht_start_fall_t = 0;       // 마지막 시작 LOW 시작 시각
time    dht_start_rise_t = 0;       // 마지막 시작 LOW 끝 (선 해제) 시각
time    dht_resp_end_t   = 0;       // 마지막 응답 끝 (선 해제) 시각

function automatic [39:0] dht_frame();
    byte unsigned chk;
    chk = dht_hum_i + dht_hum_d + dht_tmp_i + dht_tmp_d + dht_chk_ofs;
    return {dht_hum_i[7:0], dht_hum_d[7:0], dht_tmp_i[7:0], dht_tmp_d[7:0], chk};
endfunction

initial begin : dht_model
    time t_fall;
    bit [39:0] f;
    forever begin
        @(negedge dht11_io);
        if (dht_sensor_low || dht_stuck_low) continue;   // 내가 내린 것
        t_fall = $time;
        @(posedge dht11_io);
        if (($time - t_fall) < dht_start_min) continue;
        dht_start_cnt++;
        dht_start_fall_t = t_fall;
        dht_start_rise_t = $time;
        if (dht_mode != 1) continue;
        f = dht_frame();
        #(dht_resp_dly_us * US);
        dht_sensor_low = 1'b1;  #(80 * US);
        dht_sensor_low = 1'b0;  #(80 * US);
        for (int i = 0; i < 40; i++) begin
            if (dht_stop_after >= 0 && i == dht_stop_after) break;
            dht_sensor_low = 1'b1;  #(50 * US);
            dht_sensor_low = 1'b0;  #((f[39 - i] ? dht_hi1_us : dht_hi0_us) * US);
        end
        if (!(dht_stop_after >= 0 && dht_stop_after < 40)) begin
            dht_sensor_low = 1'b1;  #(50 * US);
        end
        dht_sensor_low = 1'b0;
        dht_resp_end_t = $time;
    end
end

// =============================================================================
// FND 모니터 — 2 ms (8 칸) 스캔을 모아 "55.24" 같은 문자열로
// =============================================================================
//   글자 : 0~9, E, r, -, ' ' (빈칸), ? (모르는 패턴). 점은 그 자리 글자 뒤에 '.'
//   AN3 → AN0 순 (왼쪽 → 오른쪽). 예 : 시계 초 화면 "05.37", 거리 "352.7", "Err1", "----"
//   값이 바뀐 직후에는 fnd_get 으로 읽을 것 (새로 8 칸 모일 때까지 기다림)
byte fnd_dig [4] = '{" ", " ", " ", " "};
bit  fnd_dot [4] = '{0, 0, 0, 0};
int  fnd_sample_cnt = 0;

function automatic byte fnd_char(input [7:0] f);
    case (f)
        8'hC0: return "0";  8'hF9: return "1";  8'hA4: return "2";  8'hB0: return "3";
        8'h99: return "4";  8'h92: return "5";  8'h82: return "6";  8'hF8: return "7";
        8'h80: return "8";  8'h90: return "9";  8'h86: return "E";  8'hAF: return "r";
        8'hBF: return "-";  8'hFF: return " ";
        default: return "?";
    endcase
endfunction

function automatic int fnd_an(input [3:0] com);
    case (com)
        4'b1110: return 0;
        4'b1101: return 1;
        4'b1011: return 2;
        4'b0111: return 3;
        default: return -1;
    endcase
endfunction

// 지금까지 모인 표시 문자열
function automatic string fnd_text();
    string s;
    s = "";
    for (int an = 3; an >= 0; an--) begin
        s = {s, string'(fnd_dig[an])};
        if (fnd_dot[an]) s = {s, "."};
    end
    return s;
endfunction

// 4 kHz 칸 가운데 (tick 뒤 125 us) 에서 핀 샘플. 숫자 칸 / 점 칸 구분은 내부 scan_sel[2]
initial begin : fnd_monitor
    int an;
    forever begin
        @(posedge dut.w_clk_4khz);
        #(125 * US);
        an = fnd_an(fnd_com);
        if (an >= 0) begin
            if (dut.U_FND_CONTROLLER.w_scan_sel[2] == 1'b0)
                fnd_dig[an] = fnd_char(fnd_font);
            else
                fnd_dot[an] = (fnd_font == 8'h7F);
        end
        fnd_sample_cnt++;
    end
end

// 새로 한 바퀴 (8 칸) 모은 뒤의 표시 문자열
task automatic fnd_get(output string s);
    int c0;
    c0 = fnd_sample_cnt;
    wait (fnd_sample_cnt >= c0 + 9);
    s = fnd_text();
endtask
