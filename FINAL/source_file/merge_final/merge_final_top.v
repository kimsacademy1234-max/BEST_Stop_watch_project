`timescale 1ns / 1ps

// 팀 통합 Top (merge_final)
//   WTS (스톱워치 · 시계 · 타이머) + SR04 (거리) + DHT11 (온습도) + UART (명령 수신 · 데이터 전송)
//
// 모드 선택 = module_control_bit[6:0]
//   [0] mode_sw0  [1] display_mode_sw1  [2] set_sw2  [3] hour24_sw3  [4] timer_sw4  [5] dist_sw5  [6] dht_sw6
//   - UART 로 정상 /mod 명령을 받기 전 : 보드 스위치 sw0 ~ sw6
//   - 첫 /mod 를 받은 뒤 (리셋 전까지) : UART 컨트롤러 값 (스위치 무시)
//   화면 = [6:5] : 00 WTS, 01 거리, 10 온습도 (둘 다 1 이면 온습도)
//
// 버튼 : 공용 디바운서 4개 (물리) | UART /btn  →  지금 화면의 모듈에만 전달
//   WTS    : 원래 버튼 기능 그대로 (화면 선택 w_sel_* 와 AND 는 wts_top 안에서)
//   거리   : R 1회 측정, U 자동 측정 켜기/끄기
//   온습도 : R 1회 측정, U 자동 측정 켜기/끄기
//   물리 버튼과 UART 버튼이 같은 클럭에 겹치면 물리 버튼 먼저 (UART_CONTROLLER 가 UART 버튼을 미뤄 줌)
//
// 이름 규칙 (v2) : 모듈 입력 i_*, 출력 o_*, Top 안 와이어 w_*, 스위치 *_swN, 버튼 *_btn_R·L·U·D
module merge_final_top (
    input         clk,
    input         rst,
    input         btn_R,
    input         btn_L,
    input         btn_U,
    input         btn_D,
    input         mode_sw0,
    input         display_mode_sw1,
    input         set_sw2,
    input         hour24_sw3,
    input         timer_sw4,
    input         dist_sw5,          // 1 = 거리 화면
    input         dht_sw6,           // 1 = 온습도 화면 (sw5 보다 우선)
    input         dist_led_sw15,     // 거리 막대 LED (LD0~7) ON/OFF
    input         rx,                // USB-UART (PC → FPGA)
    output        tx,                // USB-UART (FPGA → PC)
    output        trig,              // SR04 TRIG (JA1)
    input         echo,              // SR04 ECHO (JA2)
    inout         dht11_io,          // DHT11 DATA (JA3)
    output [ 3:0] fnd_com,
    output [ 7:0] fnd_font,
    output [15:0] led
);

    // 리셋 · 클럭
    wire w_rst;          // U_RESET_SYNC.o_rst (모든 모듈 공용)
    wire w_clk_4khz;     // 디바운서 샘플 · FND 스캔
    // 버튼
    wire w_phy_btn_R, w_phy_btn_L, w_phy_btn_U, w_phy_btn_D;      // 디바운서 출력 (물리)
    wire w_uart_btn_R, w_uart_btn_L, w_uart_btn_U, w_uart_btn_D;  // UART /btn (물리 버튼 끝난 뒤)
    wire w_btn_R, w_btn_L, w_btn_U, w_btn_D;                      // 물리 | UART
    // 모드
    wire [6:0] w_sw_ctrl_bit;     // 보드 스위치
    wire [6:0] w_uart_ctrl_bit;   // UART 컨트롤러
    wire       w_uart_mode;       // 1 = 첫 /mod 받음 → UART 값 사용
    wire [6:0] w_ctrl_bit;        // 실제로 쓰는 module_control_bit
    wire [1:0] w_disp_sel;        // 0 WTS, 1 거리, 2 온습도
    wire       w_mode_wts, w_mode_dist, w_mode_dht;
    // WTS
    wire [6:0] w_disp_msec;
    wire [5:0] w_disp_sec, w_disp_min, w_disp_hour;
    wire       w_disp_mode;
    wire [1:0] w_wt_cursor;
    wire       w_sel_sw, w_sel_wt, w_sel_tm;
    wire       w_sw_lap, w_wt_pm, w_tm_run, w_tm_alarm;
    wire [6:0] w_wt_msec;
    wire [23:0] w_sw_time, w_tm_time, w_wt_time;
    // SR04
    wire [ 8:0] w_distance;
    wire [11:0] w_distance_x10;
    wire        w_dist_err, w_dist_auto, w_dist_done;
    wire [ 9:0] w_sr04_led;
    // DHT11
    wire [13:0] w_dht_fnd_data;
    wire        w_dht_dashes;
    wire [ 3:0] w_dht_led;
    wire [ 7:0] w_humidity, w_temperature;
    wire        w_dht_valid, w_dht_done;
    wire [ 1:0] w_dht_status;
    // FND · UART 전송 데이터 MUX
    wire [24:0] w_fnd_data;
    wire [ 2:0] w_send_sel;
    reg  [23:0] w_send_data;


    // ---------------------------------------------------------------- 리셋 · 클럭 · 디바운서 (공용)
    reset_sync U_RESET_SYNC (
        .i_clk    (clk),
        .i_rst_btn(rst),
        .o_rst    (w_rst)
    );

    clock_tick_generator #(
        .CLK_FRQ(4000)
    ) U_CLK_GEN_4KHZ (
        .i_clk     (clk),
        .i_rst     (w_rst),
        .o_clk_4khz(w_clk_4khz)
    );

    btn_debounce U_BD_R (
        .i_clk     (clk),
        .i_rst     (w_rst),
        .i_clk_4khz(w_clk_4khz),
        .i_btn     (btn_R),
        .o_btn     (w_phy_btn_R)
    );
    btn_debounce U_BD_L (
        .i_clk     (clk),
        .i_rst     (w_rst),
        .i_clk_4khz(w_clk_4khz),
        .i_btn     (btn_L),
        .o_btn     (w_phy_btn_L)
    );
    btn_debounce U_BD_U (
        .i_clk     (clk),
        .i_rst     (w_rst),
        .i_clk_4khz(w_clk_4khz),
        .i_btn     (btn_U),
        .o_btn     (w_phy_btn_U)
    );
    btn_debounce U_BD_D (
        .i_clk     (clk),
        .i_rst     (w_rst),
        .i_clk_4khz(w_clk_4khz),
        .i_btn     (btn_D),
        .o_btn     (w_phy_btn_D)
    );

    // ---------------------------------------------------------------- UART (RX · 디코더 · 컨트롤러 · 센더 · TX)
    uart_top U_UART (
        .i_clk               (clk),
        .i_rst               (w_rst),
        .i_rx                (rx),
        .i_btn_R             (w_phy_btn_R),
        .i_btn_L             (w_phy_btn_L),
        .i_btn_U             (w_phy_btn_U),
        .i_btn_D             (w_phy_btn_D),
        .i_send_data         (w_send_data),
        .o_tx                (tx),
        .o_module_control_bit(w_uart_ctrl_bit),
        .o_uart_mode         (w_uart_mode),
        .o_send_sel          (w_send_sel),
        .o_uart_btn_R        (w_uart_btn_R),
        .o_uart_btn_L        (w_uart_btn_L),
        .o_uart_btn_U        (w_uart_btn_U),
        .o_uart_btn_D        (w_uart_btn_D)
    );

    // ---------------------------------------------------------------- 모드 선택 (assign)
    // UART 로 /mod 받기 전에는 스위치, 받은 뒤에는 UART 값 (merge.md 10번)
    assign w_sw_ctrl_bit = {dht_sw6, dist_sw5, timer_sw4, hour24_sw3, set_sw2, display_mode_sw1, mode_sw0};
    assign w_ctrl_bit    = (w_uart_mode) ? w_uart_ctrl_bit : w_sw_ctrl_bit;

    assign w_mode_dht  = w_ctrl_bit[6];
    assign w_mode_dist = w_ctrl_bit[5] & ~w_ctrl_bit[6];
    assign w_mode_wts  = ~w_ctrl_bit[5] & ~w_ctrl_bit[6];
    assign w_disp_sel  = {w_mode_dht, w_mode_dist};

    // ---------------------------------------------------------------- 버튼 (물리 | UART) → 화면 모듈에만
    assign w_btn_R = w_phy_btn_R | w_uart_btn_R;
    assign w_btn_L = w_phy_btn_L | w_uart_btn_L;
    assign w_btn_U = w_phy_btn_U | w_uart_btn_U;
    assign w_btn_D = w_phy_btn_D | w_uart_btn_D;

    // ---------------------------------------------------------------- WTS
    wts_top U_WTS (
        .i_clk             (clk),
        .i_rst             (w_rst),
        .i_btn_R           (w_btn_R & w_mode_wts),
        .i_btn_L           (w_btn_L & w_mode_wts),
        .i_btn_U           (w_btn_U & w_mode_wts),
        .i_btn_D           (w_btn_D & w_mode_wts),
        .i_mode_sw0        (w_ctrl_bit[0]),
        .i_display_mode_sw1(w_ctrl_bit[1]),
        .i_set_sw2         (w_ctrl_bit[2]),
        .i_hour24_sw3      (w_ctrl_bit[3]),
        .i_timer_sw4       (w_ctrl_bit[4]),
        .o_disp_msec       (w_disp_msec),
        .o_disp_sec        (w_disp_sec),
        .o_disp_min        (w_disp_min),
        .o_disp_hour       (w_disp_hour),
        .o_disp_mode       (w_disp_mode),
        .o_wt_cursor       (w_wt_cursor),
        .o_sel_sw          (w_sel_sw),
        .o_sel_wt          (w_sel_wt),
        .o_sel_tm          (w_sel_tm),
        .o_sw_lap          (w_sw_lap),
        .o_wt_msec         (w_wt_msec),
        .o_wt_pm           (w_wt_pm),
        .o_tm_run          (w_tm_run),
        .o_tm_alarm        (w_tm_alarm),
        .o_sw_time         (w_sw_time),
        .o_tm_time         (w_tm_time),
        .o_wt_time         (w_wt_time)
    );

    // ---------------------------------------------------------------- SR04 (거리)
    sr04_top U_SR04 (
        .i_clk         (clk),
        .i_rst         (w_rst),
        .i_btn_R       (w_btn_R & w_mode_dist),
        .i_btn_U       (w_btn_U & w_mode_dist),
        .i_led_sw      (dist_led_sw15),
        .i_echo        (echo),
        .o_trig        (trig),
        .o_distance    (w_distance),
        .o_distance_x10(w_distance_x10),
        .o_err         (w_dist_err),
        .o_auto_en     (w_dist_auto),
        .o_done        (w_dist_done),
        .o_led         (w_sr04_led)
    );

    // ---------------------------------------------------------------- DHT11 (온습도)
    dht11_top U_DHT11 (
        .i_clk        (clk),
        .i_rst        (w_rst),
        .i_btn_R      (w_btn_R & w_mode_dht),
        .i_btn_U      (w_btn_U & w_mode_dht),
        .io_dht11     (dht11_io),
        .o_fnd_data   (w_dht_fnd_data),
        .o_dashes     (w_dht_dashes),
        .o_led        (w_dht_led),
        .o_humidity   (w_humidity),
        .o_temperature(w_temperature),
        .o_valid      (w_dht_valid),
        .o_status     (w_dht_status),
        .o_done       (w_dht_done)
    );

    // ---------------------------------------------------------------- FND 데이터 MUX (그림 2 data_path)
    // module_control_bit[6:5] : 0 WTS, 1 거리, 2 온습도 → U_FND_CONTROLLER 안의 디코더가 다시 나눔
    assign w_fnd_data = (w_disp_sel == 2'd1) ? {12'd0, w_dist_err, w_distance_x10} :
                        (w_disp_sel == 2'd2) ? {10'd0, w_dht_dashes, w_dht_fnd_data} :
                                               {w_disp_hour, w_disp_min, w_disp_sec, w_disp_msec};

    SW2_FND_CONTROLLER U_FND_CONTROLLER (
        .i_rst      (w_rst),
        .i_clk_4khz (w_clk_4khz),
        .i_disp_sel (w_disp_sel),
        .i_disp_data(w_fnd_data),
        .i_disp_mode(w_disp_mode),
        .i_wt_cursor(w_wt_cursor),
        .i_sel_wt   (w_sel_wt),
        .i_set_sw2  (w_ctrl_bit[2]),
        .o_fnd_com  (fnd_com),
        .o_fnd_font (fnd_font)
    );

    // ---------------------------------------------------------------- LED
    led_output U_LED (
        .i_disp_sel        (w_disp_sel),
        .i_tm_alarm        (w_tm_alarm),
        .i_tm_run          (w_tm_run),
        .i_wt_msec         (w_wt_msec),
        .i_wt_pm           (w_wt_pm),
        .i_sel_wt          (w_sel_wt),
        .i_sel_sw          (w_sel_sw),
        .i_sel_tm          (w_sel_tm),
        .i_sw_lap          (w_sw_lap),
        .i_display_mode_sw1(w_ctrl_bit[1]),
        .i_timer_sw4       (w_ctrl_bit[4]),
        .i_hour24_sw3      (w_ctrl_bit[3]),
        .i_sr04_led        (w_sr04_led),
        .i_dht_led         (w_dht_led),
        .o_led             (led)
    );

    // ---------------------------------------------------------------- UART 전송 데이터 MUX (그림 1, o_send_sel)
    // sender_char_mux 형식 : 0 · 1 · 2 = 시간 {hour 5, min 6, sec 6, cs 7}, 3 = 거리 {cm 9}, 4 = 온습도 {hum 8, temp 8}
    always @(*) begin
        case (w_send_sel)
            3'd0:    w_send_data = w_sw_time;                         // 스톱워치
            3'd1:    w_send_data = w_tm_time;                         // 타이머
            3'd2:    w_send_data = w_wt_time;                         // 시계
            3'd3:    w_send_data = {15'd0, w_distance};               // 거리
            3'd4:    w_send_data = {8'd0, w_humidity, w_temperature}; // 온습도
            default: w_send_data = 24'd0;                             // ERROR (7)
        endcase
    end

endmodule
