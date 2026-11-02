"""merge_final 블록 다이어그램 — 쪽별 블록 · 선 좌표 (bd_pages)

waypoint 규칙 (bd_core.path_points) : 출발 핀에서 x, y, x, ... 순서로 꺾음.
  마지막이 x 이면 그 x 에서 도착 핀 y 로 내려가/올라가 도착, 마지막이 y 이면 그 y 로 도착 핀 x 까지.
"""
from bd_core import Block, Page



def legend(pg, y, extra=""):
    pg.H += 20
    pg.note(30, y, "회색 깃발 clk · rst = 같은 이름 선 직결 / 주황 깃발 = 보드 핀 · 스위치 직결 / 청록 깃발 bitN = w_ctrl_bit[N] (Top) / "
            "점선 깃발 = 연결만 있고 안 쓰는 선 / 회색 깃발 4'hf · 24'd0 = 상수", 13, "#333")
    pg.note(30, y + 20, "보라 선 = 4 kHz · FND 스캔 / 분홍 선 = tick / 굵은 선 = 버스 / 점선 블록 · MUX · OR · NOT = assign (모듈 아님) / "
            "초록 굵은 테두리 = 하위 Top (내부는 다른 쪽)" + extra, 13, "#333")


# =========================================================================== 1 쪽 : Top
def page_top():
    pg = Page("top", "merge_final_top (Top) — 전체 블록 다이어그램 · 포트 이름 = 선 이름", 3780, 1720)
    F = "merge_final_top.v"
    B = pg.add
    pg.flagmap = {"clk": "clk", "w_rst": "w_rst", "rx": "rx", "echo": "echo", "dht11_io": "dht11_io",
                  "sw15": "dist_led_sw15", "24'd0": "24'd0"}
    for i in range(7):
        pg.flagmap[f"bit{i}"] = f"w_ctrl_bit[{i}]"

    # ---------------- 블록
    rs = B(Block("RSTSYNC", 260, 110, 210, ["i_clk", "i_rst_btn"], ["o_rst"], inst="U_RESET_SYNC",
                 module="reset_sync", parent=F, note="o_rst = w_rst : 모든 모듈 공용 리셋 (2-FF 동기화)"))
    cg = B(Block("CLKGEN", 260, 250, 210, ["i_clk", "i_rst"], ["o_clk_4khz"], inst="U_CLK_GEN_4KHZ",
                 module="clock_tick_generator", parent=F, note="o_clk_4khz : 250 us 마다 10 ns 펄스"))
    bds = {}
    for i, k in enumerate("RLUD"):
        bds[k] = B(Block("BD_" + k, 560, 400 + i * 170, 200, ["i_clk", "i_rst", "i_clk_4khz", "i_btn"], ["o_btn"],
                         inst="U_BD_" + k, module="btn_debounce", parent=F))
    uart = B(Block("UART", 880, 110, 320,
                   ["i_clk", "i_rst", "i_rx", "i_btn_R", "i_btn_L", "i_btn_U", "i_btn_D", ("i_send_data", "[23:0]")],
                   ["o_tx", "o_uart_btn_R", "o_uart_btn_L", "o_uart_btn_U", "o_uart_btn_D",
                    ("o_module_control_bit", "[6:0]"), "o_uart_mode", ("o_send_sel", "[2:0]")],
                   inst="U_UART", module="uart_top", parent=F, sub="2 쪽",
                   note="rx → 명령 해석 → 모드 · 버튼 · 전송 / 전송 MUX 값 → tx"))
    mode = B(Block("MODE", 880, 1100, 320,
                   ["w_uart_mode", ("w_uart_ctrl_bit", "[6:0]"), "mode_sw0", "display_mode_sw1", "set_sw2",
                    "hour24_sw3", "timer_sw4", "dist_sw5", "dht_sw6"],
                   [("w_ctrl_bit", "[6:0]"), "w_mode_wts", "w_mode_dist", "w_mode_dht", ("w_disp_sel", "[1:0]")],
                   kind="assign", title="모드 선택 (module_control_bit)", parent=F,
                   note="w_ctrl_bit = w_uart_mode ? w_uart_ctrl_bit : {dht_sw6 … mode_sw0}  (첫 정상 /mod 뒤엔 UART 값)\n"
                        "w_mode_dht = bit6 · w_mode_dist = bit5 & ~bit6 · w_mode_wts = ~bit5 & ~bit6\n"
                        "w_disp_sel = {w_mode_dht, w_mode_dist} : 0 WTS · 1 거리 · 2 온습도"))
    bor = B(Block("BTN_OR", 1430, 440, 250,
                  [f"w_phy_btn_{k}" for k in "RLUD"] + [f"w_uart_btn_{k}" for k in "RLUD"],
                  [f"w_btn_{k}" for k in "RLUD"], kind="assign", title="버튼 합치기", title2="(물리 | UART)",
                  parent=F, note="w_btn_X = w_phy_btn_X | w_uart_btn_X\n(같은 클럭이면 물리 먼저, UART 는 U_UART 가 미룸)"))
    gate_out = ["w_btn_R & w_mode_wts", "w_btn_L & w_mode_wts", "w_btn_U & w_mode_wts", "w_btn_D & w_mode_wts",
                "w_btn_R & w_mode_dist", "w_btn_U & w_mode_dist", "w_btn_R & w_mode_dht", "w_btn_U & w_mode_dht"]
    gate = B(Block("GATE", 1780, 440, 330, [f"w_btn_{k}" for k in "RLUD"] + ["w_mode_wts", "w_mode_dist", "w_mode_dht"],
                   gate_out, kind="assign", title="버튼 → 지금 화면 모듈만", title2="(AND, 인스턴스 포트 식)",
                   parent=F, note="거리 · 온습도 : R 1 회 측정, U 자동 측정 켜기/끄기"))
    wts = B(Block("WTS", 2250, 110, 340,
                  ["i_clk", "i_rst", "i_btn_R", "i_btn_L", "i_btn_U", "i_btn_D", "i_mode_sw0", "i_display_mode_sw1",
                   "i_set_sw2", "i_hour24_sw3", "i_timer_sw4"],
                  ["o_sel_wt", "o_sel_sw", "o_sel_tm", "o_sw_lap", ("o_wt_msec", "[6:0]"), "o_wt_pm", "o_tm_run",
                   "o_tm_alarm", "o_disp_mode", ("o_wt_cursor", "[1:0]"), ("o_disp_msec", "[6:0]"),
                   ("o_disp_sec", "[5:0]"), ("o_disp_min", "[5:0]"), ("o_disp_hour", "[5:0]"),
                   ("o_sw_time", "[23:0]"), ("o_tm_time", "[23:0]"), ("o_wt_time", "[23:0]")],
                  inst="U_WTS", module="wts_top", parent=F, sub="3 쪽"))
    sr = B(Block("SR04", 2250, 660, 340, ["i_clk", "i_rst", "i_btn_R", "i_btn_U", "i_led_sw", "i_echo"],
                 [("o_led", "[9:0]"), ("o_status", "[1:0]"), "o_err", ("o_distance_x10", "[11:0]"),
                  ("o_distance", "[8:0]"), "o_trig", "o_auto_en", "o_done"],
                 inst="U_SR04", module="sr04_top", parent=F, sub="4 쪽"))
    dht = B(Block("DHT11", 2250, 980, 340, ["i_clk", "i_rst", "i_btn_R", "i_btn_U", "io_dht11"],
                  [("o_led", "[3:0]"), ("o_fnd_data", "[13:0]"), "o_dashes", ("o_status", "[1:0]"),
                   ("o_humidity", "[7:0]"), ("o_temperature", "[7:0]"), "o_valid", "o_done"],
                  inst="U_DHT11", module="dht11_top", parent=F, sub="4 쪽", note="io_dht11 = inout (3 상태 버퍼는 안쪽)"))
    derr = B(Block("DHT_ERR", 2630, 1280, 190, [("w_dht_led", "[3:0]")], ["w_dht_err"], kind="assign",
                   title="w_dht_err", parent=F, note="w_dht_err = w_dht_led[1] (마지막 측정 실패)"))
    fm = B(Block("FNDMUX", 2920, 560, 90,
                 ["w_disp_msec", "w_disp_sec", "w_disp_min", "w_disp_hour",
                  "w_dist_status", "w_dist_err", "w_distance_x10",
                  "w_dht_fnd_data", "w_dht_dashes", "w_dht_status", "w_dht_err"],
                 [("w_fnd_data", "[24:0]")], kind="mux", title="w_fnd_data[24:0]", title2="FND 데이터 MUX", sel=["w_disp_sel"],
                 groups=[("0", 4), ("1", 3), ("2", 4)], parent=F))
    sm = B(Block("SENDMUX", 2920, 1000, 90,
                 ["w_sw_time", "w_tm_time", "w_wt_time", "w_dist_status", "w_distance",
                  "w_dht_err", "w_dht_dashes", "w_dht_status", "w_humidity", "w_temperature", "c_zero"],
                 [("w_send_data", "[23:0]")], kind="mux", title="w_send_data[23:0]", title2="전송 데이터 MUX (always case)",
                 sel=["w_send_sel"], groups=[("0", 1), ("1", 1), ("2", 1), ("3", 2), ("4", 5), ("7", 1)], parent=F))
    led = B(Block("LED", 3160, 110, 330,
                  ["i_sel_wt", "i_sel_sw", "i_sel_tm", "i_sw_lap", ("i_wt_msec", "[6:0]"), "i_wt_pm", "i_tm_run",
                   "i_tm_alarm", "i_display_mode_sw1", "i_timer_sw4", "i_hour24_sw3", ("i_disp_sel", "[1:0]"),
                   ("i_sr04_led", "[9:0]"), ("i_dht_led", "[3:0]")],
                  [("o_led", "[15:0]")], inst="U_LED", module="led_output", parent=F, sub="6 쪽"))
    fnd = B(Block("FND", 3160, 652, 330,
                  [("i_disp_data", "[24:0]"), "i_disp_mode", ("i_wt_cursor", "[1:0]"), "i_sel_wt", "i_clk_4khz",
                   ("i_disp_sel", "[1:0]"), "i_set_sw2", "i_rst"],
                  [("o_fnd_com", "[3:0]"), ("o_fnd_font", "[7:0]")],
                  inst="U_FND_CONTROLLER", module="SW2_FND_CONTROLLER", parent=F, sub="5 쪽"))

    pin_in = ["clk", "rst", "btn_R", "btn_L", "btn_U", "btn_D", "mode_sw0", "display_mode_sw1", "set_sw2",
              "hour24_sw3", "timer_sw4", "dist_sw5", "dht_sw6", "dist_led_sw15", "rx", "echo", "dht11_io"]
    pins = B(Block("PIN_IN", 20, 100, 170, [], pin_in, kind="pins_in", title="Top 입력 (보드)", h=1480))
    py = {"clk": 150, "rst": rs.py("i_rst_btn")}
    for k in "RLUD":
        py["btn_" + k] = bds[k].py("i_btn")
    for s in ["mode_sw0", "display_mode_sw1", "set_sw2", "hour24_sw3", "timer_sw4", "dist_sw5", "dht_sw6"]:
        py[s] = mode.py(s)
    for i, s in enumerate(["dist_led_sw15", "rx", "echo", "dht11_io"]):
        py[s] = 1440 + i * 30
    pins.pin_y = py
    pout = B(Block("PIN_OUT", 3580, 100, 150, [("led", "[15:0]"), "tx", ("fnd_com", "[3:0]"), ("fnd_font", "[7:0]"), "trig"],
                   [], kind="pins_out", title="Top 출력 (보드)", h=900,
                   pin_y={"led": led.py("o_led"), "tx": 260, "fnd_com": fnd.py("o_fnd_com"),
                          "fnd_font": fnd.py("o_fnd_font"), "trig": 950}))
    pg.boundaries = [("merge_final_top", "PIN_IN", "PIN_OUT")]

    # ---------------- 깃발
    pg.flag("PIN_IN", "clk", "clk", "clk")
    for s in ["dist_led_sw15", "rx", "echo", "dht11_io"]:
        pg.flag("PIN_IN", s, s, "sw")
    for b in pg.blocks.values():
        if not b.module:
            continue
        for p in b.all_inputs():
            if p == "i_clk":
                pg.flag(b.id, p, "clk", "clk")
            elif p == "i_rst":
                pg.flag(b.id, p, "w_rst", "clk")
    pg.flag("RSTSYNC", "o_rst", "w_rst", "clk")
    pg.flag("UART", "i_rx", "rx", "sw")
    pg.flag("SR04", "i_led_sw", "sw15", "sw")
    pg.flag("SR04", "i_echo", "echo", "sw")
    pg.flag("DHT11", "io_dht11", "dht11_io", "sw")
    pg.flag("MODE", "w_ctrl_bit", "bit[6:0] → 청록 깃발", "ctrl")
    pg.flagmap["bit[6:0] → 청록 깃발"] = "w_ctrl_bit"
    for i, p in enumerate(["i_mode_sw0", "i_display_mode_sw1", "i_set_sw2", "i_hour24_sw3", "i_timer_sw4"]):
        pg.flag("WTS", p, f"bit{i}", "ctrl")
    pg.flag("FND", "i_set_sw2", "bit2", "ctrl")
    pg.flag("LED", "i_display_mode_sw1", "bit1", "ctrl")
    pg.flag("LED", "i_timer_sw4", "bit4", "ctrl")
    pg.flag("LED", "i_hour24_sw3", "bit3", "ctrl")
    pg.flag("SENDMUX", "c_zero", "24'd0", "clk")
    for b, p, n in [("SR04", "o_auto_en", "w_dist_auto"), ("SR04", "o_done", "w_dist_done"),
                    ("DHT11", "o_valid", "w_dht_valid"), ("DHT11", "o_done", "w_dht_done")]:
        pg.flag(b, p, n, "nc")

    # ---------------- 선
    pg.net("rst", ("PIN_IN", "rst"), [("RSTSYNC", "i_rst_btn", [])])
    for k in "RLUD":
        pg.net("btn_" + k, ("PIN_IN", "btn_" + k), [("BD_" + k, "i_btn", [])])
    pg.net("w_clk_4khz", ("CLKGEN", "o_clk_4khz"),
           [("BD_" + k, "i_clk_4khz", [500]) for k in "RLUD"] + [("FND", "i_clk_4khz", [500, 90, 3032])], kind="clk4k")
    for i, k in enumerate("RLUD"):
        x = 780 + i * 14
        pg.net("w_phy_btn_" + k, ("BD_" + k, "o_btn"),
               [("UART", "i_btn_" + k, [x]), ("BTN_OR", "w_phy_btn_" + k, [x])])
        pg.net("w_uart_btn_" + k, ("UART", "o_uart_btn_" + k), [("BTN_OR", "w_uart_btn_" + k, [1392 - i * 14])])
        pg.net("w_btn_" + k, ("BTN_OR", "w_btn_" + k), [("GATE", "w_btn_" + k, [])])
    pg.net("w_uart_mode", ("UART", "o_uart_mode"), [("MODE", "w_uart_mode", [1312, 1070, 862])])
    pg.net("w_uart_ctrl_bit", ("UART", "o_module_control_bit"), [("MODE", "w_uart_ctrl_bit", [1326, 1080, 850])])
    pg.net("tx", ("UART", "o_tx"), [("PIN_OUT", "tx", [1306, 76, 3550])])
    pg.net("w_send_sel", ("UART", "o_send_sel"), [("SENDMUX", "w_send_sel", [1306, 1640])])
    for i, s in enumerate(["mode_sw0", "display_mode_sw1", "set_sw2", "hour24_sw3", "timer_sw4", "dist_sw5", "dht_sw6"]):
        pg.net(s, ("PIN_IN", s), [("MODE", s, [])])
    for i, m in enumerate(["wts", "dist", "dht"]):
        pg.net("w_mode_" + m, ("MODE", "w_mode_" + m), [("GATE", "w_mode_" + m, [1720 + i * 14])])
    pg.net("w_disp_sel", ("MODE", "w_disp_sel"),
           [("FNDMUX", "w_disp_sel", [1340, 1600, 3086]), ("FND", "i_disp_sel", [1340, 1600, 3086]),
            ("LED", "i_disp_sel", [1340, 1600, 3086])])
    # 버튼 → 화면 모듈
    G = 2110
    for x, o, b, p in [(G + 30, gate_out[0], "WTS", "i_btn_R"), (G + 44, gate_out[1], "WTS", "i_btn_L"),
                       (G + 58, gate_out[2], "WTS", "i_btn_U"), (G + 72, gate_out[3], "WTS", "i_btn_D"),
                       (G + 58, gate_out[4], "SR04", "i_btn_R"), (G + 44, gate_out[5], "SR04", "i_btn_U"),
                       (G + 30, gate_out[6], "DHT11", "i_btn_R"), (G + 16, gate_out[7], "DHT11", "i_btn_U")]:
        pg.net(o, ("GATE", o), [(b, p, [x])])
    # WTS → LED (곧은 선) · FND
    pg.net("w_sel_wt", ("WTS", "o_sel_wt"), [("LED", "i_sel_wt", []), ("FND", "i_sel_wt", [3046])])
    for o, i in [("o_sel_sw", "i_sel_sw"), ("o_sel_tm", "i_sel_tm"), ("o_sw_lap", "i_sw_lap"),
                 ("o_wt_msec", "i_wt_msec"), ("o_wt_pm", "i_wt_pm"), ("o_tm_run", "i_tm_run"),
                 ("o_tm_alarm", "i_tm_alarm")]:
        pg.net("w_" + o[2:], ("WTS", o), [("LED", i, [])])
    pg.net("w_disp_mode", ("WTS", "o_disp_mode"), [("FND", "i_disp_mode", [3074])])
    pg.net("w_wt_cursor", ("WTS", "o_wt_cursor"), [("FND", "i_wt_cursor", [3060])])
    for x, k in [(2652, "msec"), (2638, "sec"), (2624, "min"), (2610, "hour")]:
        pg.net("w_disp_" + k, ("WTS", "o_disp_" + k), [("FNDMUX", "w_disp_" + k, [x])])
    for x, k in [(2680, "sw"), (2670, "tm"), (2660, "wt")]:
        pg.net(f"w_{k}_time", ("WTS", f"o_{k}_time"), [("SENDMUX", f"w_{k}_time", [x])])
    # SR04
    pg.net("w_sr04_led", ("SR04", "o_led"), [("LED", "i_sr04_led", [2700])])
    pg.net("w_dist_status", ("SR04", "o_status"),
           [("FNDMUX", "w_dist_status", [2780]), ("SENDMUX", "w_dist_status", [2740])])
    pg.net("w_dist_err", ("SR04", "o_err"), [("FNDMUX", "w_dist_err", [2790])])
    pg.net("w_distance_x10", ("SR04", "o_distance_x10"), [("FNDMUX", "w_distance_x10", [2800])])
    pg.net("w_distance", ("SR04", "o_distance"), [("SENDMUX", "w_distance", [2730])])
    pg.net("trig", ("SR04", "o_trig"), [("PIN_OUT", "trig", [2720, 950])])
    # DHT11
    pg.net("w_dht_led", ("DHT11", "o_led"),
           [("LED", "i_dht_led", [2714]), ("DHT_ERR", "w_dht_led", [2610])])
    pg.net("w_dht_fnd_data", ("DHT11", "o_fnd_data"), [("FNDMUX", "w_dht_fnd_data", [2840])])
    pg.net("w_dht_dashes", ("DHT11", "o_dashes"),
           [("FNDMUX", "w_dht_dashes", [2850]), ("SENDMUX", "w_dht_dashes", [2850])])
    pg.net("w_dht_status", ("DHT11", "o_status"),
           [("FNDMUX", "w_dht_status", [2860]), ("SENDMUX", "w_dht_status", [2830])])
    pg.net("w_humidity", ("DHT11", "o_humidity"), [("SENDMUX", "w_humidity", [2820])])
    pg.net("w_temperature", ("DHT11", "o_temperature"), [("SENDMUX", "w_temperature", [2810])])
    pg.net("w_dht_err", ("DHT_ERR", "w_dht_err"),
           [("FNDMUX", "w_dht_err", [2890]), ("SENDMUX", "w_dht_err", [2890])])
    # MUX → FND · UART
    pg.net("w_fnd_data", ("FNDMUX", "w_fnd_data"), [("FND", "i_disp_data", [])])
    pg.net("w_send_data", ("SENDMUX", "w_send_data"), [("UART", "i_send_data", [3030, 1660, 840])])
    pg.net("fnd_com", ("FND", "o_fnd_com"), [("PIN_OUT", "fnd_com", [])])
    pg.net("fnd_font", ("FND", "o_fnd_font"), [("PIN_OUT", "fnd_font", [])])
    pg.net("led", ("LED", "o_led"), [("PIN_OUT", "led", [])])

    # ---------------- 설명
    pg.note(3160, 1020, "FND MUX 입력 번호 = w_disp_sel", 12.5, "#7a4d00", "bold")
    for i, s in enumerate(["0 WTS : {hour 6, min 6, sec 6, msec 7}",
                           "1 거리 : {10'd0, status 2, err 1, x10 12}",
                           "2 온습도 : {7'd0, status 2, err 1, dashes 1, data 14}"]):
        pg.note(3160, 1038 + i * 16, s, 11.5, "#7a4d00")
    pg.note(3160, 1120, "전송 MUX 입력 번호 = w_send_sel (U_UART 가 고름)", 12.5, "#7a4d00", "bold")
    for i, s in enumerate(["0 스톱워치 · 1 타이머 · 2 시계 : {hour 5, min 6, sec 6, cs 7}",
                           "3 거리 : {13'd0, status 2, cm 9}",
                           "4 온습도 : {4'd0, err, dashes, status 2, hum 8, temp 8}",
                           "7 (그 밖) ERROR : 24'd0"]):
        pg.note(3160, 1138 + i * 16, s, 11.5, "#7a4d00")
    legend(pg, 1705)
    return pg


def not_gate(pg, bid, dst_block, dst_port, inp, parent, x_gap=60):
    """도착 핀 바로 왼쪽에 NOT 게이트 (출력 = '~입력')"""
    xd, yd, _ = pg.blocks[dst_block].pin(dst_port)
    return pg.add(Block(bid, xd - x_gap, yd - 15, 46, [inp], ["~" + inp], kind="not", parent=parent))


# =========================================================================== 2 쪽 : U_UART
def page_uart():
    pg = Page("uart", "U_UART (uart_top) 내부 — 명령 받기 (RX) · 제어 · 데이터 보내기 (TX)", 3420, 1000)
    F = "uart_top.v"
    B = pg.add
    pg.flagmap = {"clk": "i_clk", "rst": "i_rst"}
    baud = B(Block("BAUD", 260, 120, 230, ["i_clk", "i_rst"], ["o_b_tick"], inst="U_BAUD_TICK_GEN",
                   module="baud_tick_gen", parent=F, note="9600 bps x 16 배 샘플링 tick (RX · TX 같이 씀)"))
    rx = B(Block("RX", 260, 280, 230, ["i_clk", "i_rst", "i_b_tick", "i_rx"], [("o_rx_data", "[7:0]"), "o_rx_done"],
                 inst="U_UART_RX", module="uart_rx", parent=F))
    frx = B(Block("FIFO_RX", 640, 280, 250, ["i_clk", "i_rst", "i_push", "i_pop", ("i_push_data", "[7:0]")],
                  [("o_pop_data", "[7:0]"), "o_empty", "o_full"], inst="U_FIFO_RX", module="fifo", parent=F))
    dec = B(Block("DEC", 1020, 174, 290, ["i_clk", "i_rst", ("i_ascii", "[7:0]"), "i_enable"],
                  ["o_pop", "o_error", "o_handshake", "o_get", "o_btn", "o_set", "o_off_set", "o_mode", "o_auto",
                   ("o_ascii", "[39:0]")], inst="U_ASCII_DECODER", module="UART_ASCII_DECODER", parent=F, h=290))
    ctl = B(Block("CTL", 1440, 150, 360,
                  ["i_clk", "i_rst", "i_error", "i_handshake", "i_get", "i_btn", "i_set", "i_off_set", "i_mode",
                   "i_auto", ("i_con_ascii", "[39:0]"), "i_btn_R", "i_btn_L", "i_btn_U", "i_btn_D",
                   ("i_for_sender_data", "[23:0]"), "i_sender_busy"],
                  [("o_module_control_bit", "[6:0]"), "o_uart_mode", "o_sender_go", ("o_send_sel", "[2:0]"),
                   ("o_sender_data", "[23:0]"), "o_uart_R", "o_uart_L", "o_uart_U", "o_uart_D"],
                  inst="U_CONTROL", module="UART_CONTROLLER", parent=F,
                  note="mode FSM (/mod · /set · /off) · auto FSM (/auto · /get) · btn (/btn, 물리 버튼 먼저)\n"
                       "안쪽 : sender_tick_generator (AUTO_FRQ 1 Hz) · counter (auto 차례 0~4)"))
    snd = B(Block("SND", 1990, 150, 300, ["i_clk", "i_rst", "i_send_go", ("i_send_sel", "[2:0]"),
                                          ("i_send_data", "[23:0]"), "i_tx_full"],
                  ["o_tx_push", ("o_tx_push_data", "[7:0]"), "o_send_busy"],
                  inst="U_ASCII_SENDER", module="uart_sender", parent=F,
                  note="안쪽 sender_char_mux : sel · 숫자 → ASCII 한 줄\n(예 \"12:34:56.78\" · \"045cm\" · \"55%24C\" · \"Err 2\")"))
    ftx = B(Block("FIFO_TX", 2420, 150, 260, ["i_push", ("i_push_data", "[7:0]"), "i_pop", "i_clk", "i_rst"],
                  [("o_pop_data", "[7:0]"), "o_empty", "o_full"], inst="U_FIFO_TX", module="fifo", parent=F,
                  note="깊이 64 (RX FIFO 는 깊이 8)"))
    tx = B(Block("TX", 2840, 150, 230, [("i_tx_data", "[7:0]"), "i_tx_start", "i_b_tick", "i_clk", "i_rst"],
                 ["o_tx", "o_tx_busy"], inst="U_UART_TX", module="uart_tx", parent=F))
    not_gate(pg, "N_RX", "DEC", "i_enable", "w_rx_empty", F)
    not_gate(pg, "N_POP", "FIFO_TX", "i_pop", "w_tx_busy", F)
    not_gate(pg, "N_START", "TX", "i_tx_start", "w_tx_empty", F, x_gap=70)

    uin = B(Block("UIN", 20, 100, 170, [], ["i_clk", "i_rst", "i_rx", "i_btn_R", "i_btn_L", "i_btn_U", "i_btn_D",
                                            ("i_send_data", "[23:0]")], kind="pins_in", title="uart_top 입력", h=520))
    uin.pin_y = {"i_clk": 150, "i_rst": 175, "i_rx": rx.py("i_rx"), "i_btn_R": ctl.py("i_btn_R"),
                 "i_btn_L": ctl.py("i_btn_L"), "i_btn_U": ctl.py("i_btn_U"), "i_btn_D": ctl.py("i_btn_D"),
                 "i_send_data": ctl.py("i_for_sender_data")}
    bottoms = {"o_module_control_bit": 640, "o_uart_mode": 664, "o_send_sel": 688, "o_uart_R": 712,
               "o_uart_L": 736, "o_uart_U": 760, "o_uart_D": 784}
    uout = B(Block("UOUT", 3210, 100, 180, ["o_tx", ("o_module_control_bit", "[6:0]"), "o_uart_mode",
                                            ("o_send_sel", "[2:0]"), "o_uart_btn_R", "o_uart_btn_L", "o_uart_btn_U",
                                            "o_uart_btn_D"], [], kind="pins_out", title="uart_top 출력", h=720))
    uout.pin_y = {"o_tx": tx.py("o_tx"), "o_module_control_bit": 640, "o_uart_mode": 664, "o_send_sel": 688,
                  "o_uart_btn_R": 712, "o_uart_btn_L": 736, "o_uart_btn_U": 760, "o_uart_btn_D": 784}
    pg.boundaries = [("uart_top", "UIN", "UOUT")]

    pg.flag("UIN", "i_clk", "clk", "clk")
    pg.flag("UIN", "i_rst", "rst", "clk")
    for b in pg.blocks.values():
        if b.module:
            pg.flag(b.id, "i_clk", "clk", "clk")
            pg.flag(b.id, "i_rst", "rst", "clk")
    pg.flag("FIFO_RX", "o_full", "w_rx_full", "nc")

    pg.net("w_b_tick", ("BAUD", "o_b_tick"), [("RX", "i_b_tick", [510, 240, 200]), ("TX", "i_b_tick", [510, 86, 2800])],
           kind="tick")
    pg.net("i_rx", ("UIN", "i_rx"), [("RX", "i_rx", [])])
    pg.net("w_rx_data", ("RX", "o_rx_data"), [("FIFO_RX", "i_push_data", [540])])
    pg.net("w_rx_done", ("RX", "o_rx_done"), [("FIFO_RX", "i_push", [520])])
    pg.net("w_rx_pop_data", ("FIFO_RX", "o_pop_data"), [("DEC", "i_ascii", [910])])
    pg.net("w_rx_empty", ("FIFO_RX", "o_empty"), [("N_RX", "w_rx_empty", [926])])
    pg.net("~w_rx_empty", ("N_RX", "~w_rx_empty"), [("DEC", "i_enable", [])])
    pg.net("w_rx_pop", ("DEC", "o_pop"), [("FIFO_RX", "i_pop", [1330, 160, 570])])
    for o, i in [("o_error", "i_error"), ("o_handshake", "i_handshake"), ("o_get", "i_get"), ("o_btn", "i_btn"),
                 ("o_set", "i_set"), ("o_off_set", "i_off_set"), ("o_mode", "i_mode"), ("o_auto", "i_auto"),
                 ("o_ascii", "i_con_ascii")]:
        pg.net("w_" + ("ascii" if o == "o_ascii" else o[2:]), ("DEC", o), [("CTL", i, [])])
    for k in "RLUD":
        pg.net("i_btn_" + k, ("UIN", "i_btn_" + k), [("CTL", "i_btn_" + k, [])])
    pg.net("i_send_data", ("UIN", "i_send_data"), [("CTL", "i_for_sender_data", [])])
    pg.net("w_send_go", ("CTL", "o_sender_go"), [("SND", "i_send_go", [])])
    pg.net("w_send_data", ("CTL", "o_sender_data"), [("SND", "i_send_data", [])])
    xs = {"o_module_control_bit": 1892, "o_uart_mode": 1880, "o_send_sel": 1868, "o_uart_R": 1856,
          "o_uart_L": 1844, "o_uart_U": 1832, "o_uart_D": 1820}
    pg.net("o_send_sel", ("CTL", "o_send_sel"),
           [("SND", "i_send_sel", []), ("UOUT", "o_send_sel", [xs["o_send_sel"], bottoms["o_send_sel"]])])
    pg.net("o_module_control_bit", ("CTL", "o_module_control_bit"),
           [("UOUT", "o_module_control_bit", [xs["o_module_control_bit"], bottoms["o_module_control_bit"]])])
    pg.net("o_uart_mode", ("CTL", "o_uart_mode"), [("UOUT", "o_uart_mode", [xs["o_uart_mode"], bottoms["o_uart_mode"]])])
    for k in "RLUD":
        o = "o_uart_" + k
        pg.net("o_uart_btn_" + k, ("CTL", o), [("UOUT", "o_uart_btn_" + k, [xs[o], bottoms[o]])])
    pg.net("w_send_busy", ("SND", "o_send_busy"), [("CTL", "i_sender_busy", [2310, 870, 1420])])
    pg.net("w_tx_push", ("SND", "o_tx_push"), [("FIFO_TX", "i_push", [])])
    pg.net("w_tx_push_data", ("SND", "o_tx_push_data"), [("FIFO_TX", "i_push_data", [])])
    pg.net("w_tx_full", ("FIFO_TX", "o_full"), [("SND", "i_tx_full", [2700, 470, 1976])])
    pg.net("w_tx_pop_data", ("FIFO_TX", "o_pop_data"), [("TX", "i_tx_data", [])])
    pg.net("w_tx_empty", ("FIFO_TX", "o_empty"), [("N_START", "w_tx_empty", [])])
    pg.net("~w_tx_empty", ("N_START", "~w_tx_empty"), [("TX", "i_tx_start", [])])
    pg.net("w_tx_busy", ("TX", "o_tx_busy"), [("N_POP", "w_tx_busy", [3090, 840, 2340])])
    pg.net("~w_tx_busy", ("N_POP", "~w_tx_busy"), [("FIFO_TX", "i_pop", [])])
    pg.net("o_tx", ("TX", "o_tx"), [("UOUT", "o_tx", [])])

    pg.note(30, 930, "흐름 : rx → U_UART_RX (비트 → 글자) → U_FIFO_RX → U_ASCII_DECODER (\"/mod w_hm\" 같은 명령 → 펄스 + 글자 40 비트) → "
            "U_CONTROL → (go · sel · 데이터) → U_ASCII_SENDER (숫자 → ASCII) → U_FIFO_TX → U_UART_TX → tx", 13, "#333")
    pg.note(30, 952, "o_send_sel : 0 스톱워치 · 1 타이머 · 2 시계 · 3 거리 · 4 온습도 · 7 ERROR  → Top 의 전송 MUX 가 고른 값이 i_send_data 로 돌아옴 / "
            "o_uart_mode = 정상 /mod 를 한 번이라도 받으면 1 (Top 이 스위치 대신 o_module_control_bit 사용)", 13, "#333")
    legend(pg, 980)
    return pg


# =========================================================================== 3 쪽 : U_WTS
SW_FLAG = {"sw0": "i_mode_sw0", "sw1": "i_display_mode_sw1", "sw2": "i_set_sw2", "sw3": "i_hour24_sw3",
           "sw4": "i_timer_sw4"}


def page_wts():
    pg = Page("wts", "U_WTS (wts_top) 내부 — 스톱워치 · 시계 · 타이머", 2440, 1580)
    F = "wts_top.v"
    B = pg.add
    pg.flagmap = dict(SW_FLAG, clk="i_clk", rst="i_rst")
    XA, XC, XD, XE, XF, XH = 280, 600, 900, 1290, 1780, 2230
    WA, WC, WD, WE = 210, 190, 250, 260

    B(Block("TICKGEN", XA, 130, WA, ["i_clk", "i_rst"], ["o_tick_10ms"], inst="U_TICK_GEN_100HZ",
            module="tick_gen_100hz", parent=F, note="10 ms 마다 1 클럭 (시계 전용, 항상 흐름)"))
    B(Block("SEL", XA, 1130, 200, ["i_mode_sw0", "i_timer_sw4"], ["w_sel_sw", "w_sel_wt", "w_sel_tm"],
            kind="assign", title="화면 선택", parent=F,
            note="w_sel_tm = i_timer_sw4\nw_sel_sw = ~i_timer_sw4 & i_mode_sw0\nw_sel_wt = ~i_timer_sw4 & ~i_mode_sw0\n(o_sel_* = w_sel_*)"))
    for i, (dom, nm) in enumerate([("sw", "스톱워치"), ("wt", "시계"), ("tm", "타이머")]):
        B(Block("GATE_" + dom.upper(), XC, 420 + i * 230, WC,
                ["i_btn_R", "i_btn_L", "i_btn_U", "i_btn_D", "w_sel_" + dom],
                [f"w_{dom}_btn_{k}" for k in "RLUD"], kind="assign", title=f"버튼 게이팅 ({nm})", parent=F,
                note=f"w_{dom}_btn_X = i_btn_X & w_sel_{dom}"))
    B(Block("SCU", XD, 400, WD, ["i_clk", "i_rst", "i_sw_btn_R", "i_sw_btn_L", "i_sw_btn_U"],
            ["o_sw_run_stop", "o_sw_clear", "o_sw_down"],
            inst="U_STOPWATCH_CONTROL_UNIT", module="stopwatch_control_unit", parent=F))
    B(Block("TICKGEN_SW", XD, 150, WD, ["i_clk", "i_rst", "i_run_stop", "i_clear"], ["o_tick_10ms"],
            inst="U_TICK_GEN_SW", module="tick_gen_100hz_run", parent=F, note="시작 순간부터 10 ms 셈 (스톱워치)"))
    B(Block("TICKGEN_TM", XD, 1150, WD, ["i_run_stop", "i_clear", "i_clk", "i_rst"], ["o_tick_10ms"],
            inst="U_TICK_GEN_TM", module="tick_gen_100hz_run", parent=F))
    B(Block("OR_TMCLR", 720, 1195, 80, ["w_tm_clear", "o_tm_alarm"], ["w_tm_tick_clear"], kind="or",
            title="w_tm_tick_clear", parent=F))
    B(Block("WCU", XD, 640, WD, ["i_clk", "i_rst", "i_wt_btn_R", "i_wt_btn_L", "i_wt_btn_U", "i_wt_btn_D", "i_set_sw2"],
            [("o_wt_cursor", "[1:0]"), "o_wt_up", "o_wt_down"],
            inst="U_WATCH_CONTROL_UNIT", module="watch_control_unit", parent=F))
    B(Block("TCU", XD, 900, WD, ["i_clk", "i_rst", "i_tm_btn_R", "i_tm_btn_L", "i_tm_btn_U", "i_tm_btn_D", "i_tm_zero"],
            ["o_tm_run", "o_tm_alarm", "o_tm_clear", "o_tm_add", ("o_tm_amount", "[1:0]")],
            inst="U_TIMER_CONTROL_UNIT", module="timer_control_unit", parent=F))
    B(Block("SDP", XE, 380, WE, ["i_clk", "i_rst", "i_tick_10ms", "i_sw_clear", "i_sw_down", "i_sw_btn_D"],
            [("o_sw_msec", "[6:0]"), ("o_sw_sec", "[5:0]"), ("o_sw_min", "[5:0]"), ("o_sw_hour", "[4:0]"), "o_sw_lap"],
            inst="U_STOPWATCH_DATAPATH", module="stopwatch_datapath", parent=F))
    B(Block("WDP", XE, 670, WE, ["i_clk", "i_rst", "i_tick_10ms", ("i_wt_cursor", "[1:0]"), "i_wt_up", "i_wt_down"],
            [("o_wt_msec", "[6:0]"), ("o_wt_sec", "[5:0]"), ("o_wt_min", "[5:0]"), ("o_wt_hour", "[4:0]")],
            inst="U_WATCH_DATAPATH", module="watch_datapath", parent=F))
    B(Block("H1224", XE, 905, WE, [("i_wt_hour", "[4:0]"), "i_hour24_sw3"], [("o_wt_hour_disp", "[4:0]"), "o_wt_pm"],
            inst="U_HOUR_12_24", module="hour_12_24", parent=F))
    B(Block("TDP", XE, 1050, WE, ["i_clk", "i_rst", "i_tick_10ms", "i_tm_run", "i_tm_clear", "i_tm_add",
                                  ("i_tm_amount", "[1:0]")],
            [("o_tm_msec", "[6:0]"), ("o_tm_sec", "[5:0]"), ("o_tm_min", "[5:0]"), "o_tm_zero"],
            inst="U_TIMER_DATAPATH", module="timer_datapath", parent=F))
    for i, (bid, ins, out) in enumerate([
            ("M_MSEC", ["w_tm_msec", "w_sw_msec", "o_wt_msec"], "o_disp_msec"),
            ("M_SEC", ["w_tm_sec", "w_sw_sec", "w_wt_sec"], "o_disp_sec"),
            ("M_MIN", ["w_tm_sec", "w_sw_min", "w_wt_min"], "o_disp_min"),
            ("M_HOUR", ["w_tm_min", "w_sw_hour", "w_wt_hour_disp"], "o_disp_hour")]):
        B(Block(bid, XF, 300 + i * 190, 80, ins, [(out, "[6:0]" if bid == "M_MSEC" else "[5:0]")], kind="mux", title=out, sel=["i_timer_sw4", "i_mode_sw0"],
                parent=F))
    B(Block("OR_MODE", XF, 150, 80, ["i_timer_sw4", "i_display_mode_sw1"], ["o_disp_mode"], kind="or",
            title="o_disp_mode", parent=F))
    tin = ["w_sw_hour", "w_sw_min", "w_sw_sec", "w_sw_msec", "w_tm_min", "w_tm_sec", "w_tm_msec",
           "w_wt_hour", "w_wt_min", "w_wt_sec", "o_wt_msec"]
    tc = B(Block("TIMECAT", 1740, 1020, 230, tin, [("o_sw_time", "[23:0]"), ("o_tm_time", "[23:0]"), ("o_wt_time", "[23:0]")],
                 kind="assign", title="UART 전송 묶음", title2="{hour 5, min 6, sec 6, cs 7}", parent=F))

    pin_in = ["i_clk", "i_rst", "i_btn_R", "i_btn_L", "i_btn_U", "i_btn_D", "i_mode_sw0", "i_display_mode_sw1",
              "i_set_sw2", "i_hour24_sw3", "i_timer_sw4"]
    pin = B(Block("PIN_IN", 20, 110, 170, [], pin_in, kind="pins_in", title="wts_top 입력", h=1300))
    py = {"i_clk": 160, "i_rst": 190}
    for i, k in enumerate("RLUD"):
        py["i_btn_" + k] = 300 + i * 30
    for i, s_ in enumerate(["i_mode_sw0", "i_display_mode_sw1", "i_set_sw2", "i_hour24_sw3", "i_timer_sw4"]):
        py[s_] = 1220 + i * 36
    pin.pin_y = py
    b = pg.blocks
    oy = {"o_disp_mode": b["OR_MODE"].py("o_disp_mode"), "o_disp_msec": b["M_MSEC"].py("o_disp_msec"),
          "o_sw_lap": 460, "o_disp_sec": b["M_SEC"].py("o_disp_sec"), "o_wt_msec": 626, "o_wt_cursor": 646,
          "o_disp_min": b["M_MIN"].py("o_disp_min"), "o_wt_pm": 845, "o_disp_hour": b["M_HOUR"].py("o_disp_hour"),
          "o_sw_time": tc.py("o_sw_time"), "o_tm_time": tc.py("o_tm_time"), "o_wt_time": tc.py("o_wt_time"),
          "o_tm_run": 1380, "o_tm_alarm": 1404, "o_sel_sw": 1440, "o_sel_wt": 1464, "o_sel_tm": 1488}
    W = {"o_disp_msec": "[6:0]", "o_disp_sec": "[5:0]", "o_disp_min": "[5:0]", "o_disp_hour": "[5:0]",
         "o_wt_msec": "[6:0]", "o_wt_cursor": "[1:0]", "o_sw_time": "[23:0]", "o_tm_time": "[23:0]", "o_wt_time": "[23:0]"}
    B(Block("PIN_OUT", XH, 110, 180, [(k, W.get(k, "")) for k in oy], [], kind="pins_out", title="wts_top 출력",
            h=1400, pin_y=oy))
    pg.boundaries = [("wts_top", "PIN_IN", "PIN_OUT")]

    # 깃발
    pg.flag("PIN_IN", "i_clk", "clk", "clk")
    pg.flag("PIN_IN", "i_rst", "rst", "clk")
    for s_ in SW_FLAG.values():
        pg.flag("PIN_IN", s_, s_, "sw")
    for bb in pg.blocks.values():
        if bb.module:
            for p in bb.all_inputs():
                if p in ("i_clk", "i_rst"):
                    pg.flag(bb.id, p, p[2:], "clk")
    for bid, p, t in [("SEL", "i_mode_sw0", "sw0"), ("SEL", "i_timer_sw4", "sw4"), ("WCU", "i_set_sw2", "sw2"),
                      ("H1224", "i_hour24_sw3", "sw3"), ("OR_MODE", "i_timer_sw4", "sw4"),
                      ("OR_MODE", "i_display_mode_sw1", "sw1")]:
        pg.flag(bid, p, t, "sw")
    for m in ["M_MSEC", "M_SEC", "M_MIN", "M_HOUR"]:
        pg.flag(m, "i_timer_sw4", "sw4", "sw")
        pg.flag(m, "i_mode_sw0", "sw0", "sw")

    # 선
    gAB, gBC, gCD, gDE, gEF = XA + WA, XA + 200, XC + WC, XD + WD, XE + WE
    for i, k in enumerate("RLUD"):
        pg.net("i_btn_" + k, ("PIN_IN", "i_btn_" + k),
               [(g, "i_btn_" + k, [520 + i * 14]) for g in ["GATE_SW", "GATE_WT", "GATE_TM"]])
    pg.net("w_tick_10ms", ("TICKGEN", "o_tick_10ms"), [("WDP", "i_tick_10ms", [506, 110, XE - 22])], kind="tick")
    pg.net("w_sw_tick_10ms", ("TICKGEN_SW", "o_tick_10ms"), [("SDP", "i_tick_10ms", [XE - 34])], kind="tick")
    pg.net("w_tm_tick_10ms", ("TICKGEN_TM", "o_tick_10ms"), [("TDP", "i_tick_10ms", [XE - 34])], kind="tick")
    pg.net("w_sel_sw", ("SEL", "w_sel_sw"), [("GATE_SW", "w_sel_sw", [500]), ("PIN_OUT", "o_sel_sw", [500, oy["o_sel_sw"]])])
    pg.net("w_sel_wt", ("SEL", "w_sel_wt"), [("GATE_WT", "w_sel_wt", [576]), ("PIN_OUT", "o_sel_wt", [576, oy["o_sel_wt"]])])
    pg.net("w_sel_tm", ("SEL", "w_sel_tm"), [("GATE_TM", "w_sel_tm", [590]), ("PIN_OUT", "o_sel_tm", [590, oy["o_sel_tm"]])])
    for i, k in enumerate("RLU"):
        pg.net(f"w_sw_btn_{k}", ("GATE_SW", f"w_sw_btn_{k}"), [("SCU", f"i_sw_btn_{k}", [gCD + 22 + i * 16])])
    pg.net("w_sw_btn_D", ("GATE_SW", "w_sw_btn_D"), [("SDP", "i_sw_btn_D", [gCD + 70, 370, gDE + 22])])
    for dom, cu in [("wt", "WCU"), ("tm", "TCU")]:
        for i, k in enumerate("RLUD"):
            pg.net(f"w_{dom}_btn_{k}", (f"GATE_{dom.upper()}", f"w_{dom}_btn_{k}"),
                   [(cu, f"i_{dom}_btn_{k}", [gCD + 22 + i * 16])])
    c1, c2, c3, c4 = gDE + 40, gDE + 56, gDE + 72, gDE + 88
    pg.net("w_sw_run_stop", ("SCU", "o_sw_run_stop"), [("TICKGEN_SW", "i_run_stop", [c2, 352, XD - 30])])
    pg.net("w_sw_clear", ("SCU", "o_sw_clear"), [("SDP", "i_sw_clear", [c3]), ("TICKGEN_SW", "i_clear", [c3, 340, XD - 18])])
    pg.net("w_sw_down", ("SCU", "o_sw_down"), [("SDP", "i_sw_down", [c4])])
    pg.net("o_wt_cursor", ("WCU", "o_wt_cursor"), [("WDP", "i_wt_cursor", [c2]), ("PIN_OUT", "o_wt_cursor", [c2, oy["o_wt_cursor"]])])
    pg.net("w_wt_up", ("WCU", "o_wt_up"), [("WDP", "i_wt_up", [c3])])
    pg.net("w_wt_down", ("WCU", "o_wt_down"), [("WDP", "i_wt_down", [c4])])
    pg.net("o_tm_run", ("TCU", "o_tm_run"), [("TDP", "i_tm_run", [c1]), ("TICKGEN_TM", "i_run_stop", [c1, 1136, XD - 30]),
                                            ("PIN_OUT", "o_tm_run", [c1, oy["o_tm_run"]])])
    pg.net("o_tm_alarm", ("TCU", "o_tm_alarm"), [("OR_TMCLR", "o_tm_alarm", [gDE + 24, 1130, 693]),
                                                ("PIN_OUT", "o_tm_alarm", [gDE + 24, oy["o_tm_alarm"]])])
    pg.net("w_tm_clear", ("TCU", "o_tm_clear"), [("TDP", "i_tm_clear", [c2]), ("OR_TMCLR", "w_tm_clear", [c2, 1142, 705])])
    pg.net("w_tm_tick_clear", ("OR_TMCLR", "w_tm_tick_clear"), [("TICKGEN_TM", "i_clear", [XD - 18])])
    pg.net("w_tm_add", ("TCU", "o_tm_add"), [("TDP", "i_tm_add", [c3])])
    pg.net("w_tm_amount", ("TCU", "o_tm_amount"), [("TDP", "i_tm_amount", [c4])])
    pg.net("w_tm_zero", ("TDP", "o_tm_zero"), [("TCU", "i_tm_zero", [gEF + 20, 1336, XD - 64])])
    # 데이터패스 → 화면 MUX · 전송 묶음 · 출력
    ch = iter(range(gEF + 44, gEF + 400, 12))
    def dp(name, src, muxes, tcat=True, extra=()):
        x = next(ch)
        d = [(m, p, [x]) for m, p in muxes]
        if tcat:
            d.append(("TIMECAT", name, [x]))
        d += list(extra)
        pg.net(name, src, d)
    dp("w_sw_msec", ("SDP", "o_sw_msec"), [("M_MSEC", "w_sw_msec")])
    dp("w_sw_sec", ("SDP", "o_sw_sec"), [("M_SEC", "w_sw_sec")])
    dp("w_sw_min", ("SDP", "o_sw_min"), [("M_MIN", "w_sw_min")])
    dp("w_sw_hour", ("SDP", "o_sw_hour"), [("M_HOUR", "w_sw_hour")])
    pg.net("o_sw_lap", ("SDP", "o_sw_lap"), [("PIN_OUT", "o_sw_lap", [gEF + 26, oy["o_sw_lap"]])])
    x = next(ch)
    pg.net("o_wt_msec", ("WDP", "o_wt_msec"), [("M_MSEC", "o_wt_msec", [x]), ("TIMECAT", "o_wt_msec", [x]),
                                              ("PIN_OUT", "o_wt_msec", [x, oy["o_wt_msec"]])])
    dp("w_wt_sec", ("WDP", "o_wt_sec"), [("M_SEC", "w_wt_sec")])
    dp("w_wt_min", ("WDP", "o_wt_min"), [("M_MIN", "w_wt_min")])
    pg.net("w_wt_hour", ("WDP", "o_wt_hour"), [("H1224", "i_wt_hour", [gEF + 14, 885, XE - 10]),
                                              ("TIMECAT", "w_wt_hour", [gEF + 32])])
    dp("w_wt_hour_disp", ("H1224", "o_wt_hour_disp"), [("M_HOUR", "w_wt_hour_disp")], tcat=False)
    pg.net("o_wt_pm", ("H1224", "o_wt_pm"), [("PIN_OUT", "o_wt_pm", [gEF + 26, oy["o_wt_pm"]])])
    dp("w_tm_msec", ("TDP", "o_tm_msec"), [("M_MSEC", "w_tm_msec")])
    dp("w_tm_sec", ("TDP", "o_tm_sec"), [("M_SEC", "w_tm_sec"), ("M_MIN", "w_tm_sec")])
    dp("w_tm_min", ("TDP", "o_tm_min"), [("M_HOUR", "w_tm_min")])
    for m in ["M_MSEC", "M_SEC", "M_MIN", "M_HOUR"]:
        o = pg.blocks[m].outs[0][0]
        pg.net(o, (m, o), [("PIN_OUT", o, [])])
    pg.net("o_disp_mode", ("OR_MODE", "o_disp_mode"), [("PIN_OUT", "o_disp_mode", [])])
    for k in ["sw", "tm", "wt"]:
        pg.net(f"o_{k}_time", ("TIMECAT", f"o_{k}_time"), [("PIN_OUT", f"o_{k}_time", [])])

    pg.note(1960, 236, "화면 MUX 입력 번호", 12.5, "#7a4d00", "bold")
    for i, line in enumerate(["sw4 = 1 → 0 (타이머)", "sw4 = 0, sw0 = 1 → 1 (스톱워치)", "sw4 = 0, sw0 = 0 → 2 (시계)",
                              "타이머는 시.분 칸에 분 · 초 (M_MIN ← 초, M_HOUR ← 분)",
                              "M_HOUR 의 스톱워치 · 시계 입력은 {1'b0, 5 비트}"]):
        pg.note(1960, 254 + i * 17, line, 11.5, "#7a4d00")
    pg.note(30, 1530, "깃발 swN = wts_top 입력 핀 직결 (sw0 i_mode_sw0 · sw1 i_display_mode_sw1 · sw2 i_set_sw2 · sw3 i_hour24_sw3 · "
            "sw4 i_timer_sw4) — Top 에서는 w_ctrl_bit[N] (스위치 또는 UART /mod) / i_btn_* 는 Top 에서 이미 WTS 화면일 때만 들어옴", 13, "#333")
    legend(pg, 1556)
    return pg


# =========================================================================== 4 쪽 : U_SR04 · U_DHT11
def page_sensor():
    pg = Page("sensor", "U_SR04 (sr04_top) · U_DHT11 (dht11_top) 내부 — 거리 · 온습도 센서", 2140, 1200)
    B = pg.add
    pg.flagmap = {"clk": "i_clk", "rst": "i_rst"}
    pg.frames += [(10, 66, 2110, 508, "U_SR04 (sr04_top) — 버튼 R 1 회 측정 · U 자동 측정 (60 ms 주기) 켜기/끄기"),
                  (10, 590, 2110, 540, "U_DHT11 (dht11_top) — 버튼 R 1 회 측정 · U 자동 측정 (2 s 주기) 켜기/끄기")]
    # ---------------- SR04
    F = "sr04_top.v"
    B(Block("S_MODE", 280, 130, 230, ["i_clk", "i_rst", "i_btn_R", "i_btn_U"], ["o_auto_en", "o_start"],
            inst="U_MODE", module="sr04_mode_ctrl", parent=F))
    core = B(Block("S_CORE", 640, 130, 310, ["i_clk", "i_rst", "i_auto_en", "i_start", "i_echo"],
                   ["o_trig", ("o_distance", "[8:0]"), "o_done", ("o_status", "[1:0]"), ("o_distance_x10", "[11:0]"),
                    "o_measuring", "o_busy", ("o_state", "[2:0]")], inst="U_SR04", module="sr04_core", parent=F))
    bar = B(Block("S_BAR", 1180, 130, 280, ["i_clk", "i_rst", "i_en", "i_done", ("i_status", "[1:0]"),
                                            ("i_dist_x10", "[11:0]"), "i_measuring"],
                  [("o_bar", "[7:0]"), "o_meas", "o_err"], inst="U_LED", module="sr04_led_bar", parent=F))
    cat = B(Block("S_CAT", 1560, 130, 190, [("o_led[7:0]", ""), ("o_led[8]", ""), "o_err"], [("o_led", "[9:0]")],
                  kind="assign", title="o_led 묶기", title2="(포트 연결 + assign)", parent=F, check=False,
                  note="o_led[9] = o_err"))
    sin = B(Block("S_IN", 20, 110, 160, [], ["i_clk", "i_rst", "i_btn_R", "i_btn_U", "i_led_sw", "i_echo"],
                  kind="pins_in", title="sr04_top 입력", h=440))
    sin.pin_y = {"i_clk": 150, "i_rst": 175, "i_btn_R": 236, "i_btn_U": 260, "i_led_sw": 470, "i_echo": 500}
    so = {"o_trig": 140, "o_distance": 164, "o_led": cat.py("o_led"), "o_err": 290, "o_done": 410, "o_status": 434,
          "o_distance_x10": 458, "o_auto_en": 482}
    SW = {"o_distance": "[8:0]", "o_led": "[9:0]", "o_status": "[1:0]", "o_distance_x10": "[11:0]"}
    B(Block("S_OUT", 1870, 100, 200, [(k, SW.get(k, "")) for k in so], [], kind="pins_out", title="sr04_top 출력",
            h=440, pin_y=so))
    for bb in ["S_MODE", "S_CORE", "S_BAR"]:
        pg.flag(bb, "i_clk", "clk", "clk")
        pg.flag(bb, "i_rst", "rst", "clk")
    pg.flag("S_IN", "i_clk", "clk", "clk")
    pg.flag("S_IN", "i_rst", "rst", "clk")
    pg.flag("S_CORE", "o_busy", "w_busy", "nc")
    pg.flag("S_CORE", "o_state", "w_state", "nc")
    pg.net("i_btn_R", ("S_IN", "i_btn_R"), [("S_MODE", "i_btn_R", [])])
    pg.net("i_btn_U", ("S_IN", "i_btn_U"), [("S_MODE", "i_btn_U", [])])
    pg.net("o_auto_en", ("S_MODE", "o_auto_en"), [("S_CORE", "i_auto_en", [590]), ("S_OUT", "o_auto_en", [590, 482])])
    pg.net("w_start", ("S_MODE", "o_start"), [("S_CORE", "i_start", [570])])
    pg.net("i_echo", ("S_IN", "i_echo"), [("S_CORE", "i_echo", [620])])
    pg.net("i_led_sw", ("S_IN", "i_led_sw"), [("S_BAR", "i_en", [1166])])
    pg.net("o_trig", ("S_CORE", "o_trig"), [("S_OUT", "o_trig", [970, 100, 1840])])
    pg.net("o_distance", ("S_CORE", "o_distance"), [("S_OUT", "o_distance", [984, 112, 1852])])
    pg.net("o_done", ("S_CORE", "o_done"), [("S_BAR", "i_done", [1150]), ("S_OUT", "o_done", [1150, 410])])
    pg.net("o_status", ("S_CORE", "o_status"), [("S_BAR", "i_status", [1136]), ("S_OUT", "o_status", [1136, 434])])
    pg.net("o_distance_x10", ("S_CORE", "o_distance_x10"),
           [("S_BAR", "i_dist_x10", [1122]), ("S_OUT", "o_distance_x10", [1122, 458])])
    pg.net("w_measuring", ("S_CORE", "o_measuring"), [("S_BAR", "i_measuring", [1108])])
    pg.net("o_led[7:0]", ("S_BAR", "o_bar"), [("S_CAT", "o_led[7:0]", [])])
    pg.net("o_led[8]", ("S_BAR", "o_meas"), [("S_CAT", "o_led[8]", [])])
    pg.net("o_err", ("S_BAR", "o_err"), [("S_CAT", "o_err", []), ("S_OUT", "o_err", [1500, 290])])
    pg.net("o_led", ("S_CAT", "o_led"), [("S_OUT", "o_led", [])])
    pg.note(280, 312, "U_MODE : R → o_start 1 클럭", 11.5, "#555")
    pg.note(280, 328, "U → o_auto_en 켜기/끄기 (토글)", 11.5, "#555")
    pg.note(640, 404, "sr04_core 안쪽 : synchronizer (echo 2-FF) · tick_gen_us (1 us) · sr04_controller (FSM)", 11.5, "#555")
    pg.note(640, 420, "o_status 00 정상 · 01 echo 없음 (Err1) · 10 범위 밖 (Err2) · 11 echo 고착 (Err3)", 11.5, "#555")
    pg.note(1180, 380, "o_bar = 거리 막대 (i_en = 0 이면 끔), 10 cm 이하 점멸 경고", 11.5, "#555")
    pg.note(1180, 396, "o_meas = 측정 중 / o_err = 마지막 측정 실패", 11.5, "#555")

    # ---------------- DHT11
    F = "dht11_top.v"
    tog = B(Block("D_TOG", 280, 640, 230, ["i_btn_U"], ["c_auto_mode"], kind="assign", title="자동 측정 토글",
                  title2="(always @(posedge i_clk))", parent=F, check=False, note="i_btn_U 마다 c_auto_mode 반전 (리셋 0)"))
    tri = B(Block("D_TRI", 280, 820, 230, ["io_dht11", "w_dht_oe"], ["w_dht_in"], kind="assign", title="3 상태 버퍼",
                  parent=F, also=["io_dht11"], note="io_dht11 = w_dht_oe ? 1'b0 : 1'bz (LOW 만 구동)\nw_dht_in = io_dht11"))
    dcore = B(Block("D_CORE", 640, 640, 310, ["i_clk", "i_rst", "i_start", "i_auto_en", "i_dht11"],
                    ["o_dht_oe", "o_measuring", "o_done", "o_valid", ("o_humidity", "[7:0]"), ("o_temperature", "[7:0]"),
                     ("o_status", "[1:0]"), "o_busy", ("o_state", "[3:0]")],
                    inst="U_DHT11_CORE", module="dht11_core", parent=F))
    mgr = B(Block("D_MGR", 1240, 640, 280, ["i_clk", "i_rst", "i_measuring", "i_done", "i_valid", ("i_humidity", "[7:0]"),
                                            ("i_temperature", "[7:0]")],
                  [("o_fnd_data", "[13:0]"), "o_dashes", ("o_led", "[2:0]")], inst="U_DHT11_MGR",
                  module="dht11_manager", parent=F))
    dcat = B(Block("D_CAT", 1610, 800, 190, [("o_led[2:0]", ""), "c_auto_mode"], [("o_led", "[3:0]")], kind="assign",
                   title="o_led 묶기", title2="(포트 연결 + assign)", parent=F, check=False, note="o_led[3] = c_auto_mode"))
    din = B(Block("D_IN", 20, 620, 160, [], ["i_clk", "i_rst", "i_btn_R", "i_btn_U", "io_dht11"], kind="pins_in",
                  title="dht11_top 입력", h=480))
    din.pin_y = {"i_clk": 652, "i_rst": 674, "i_btn_R": dcore.py("i_start"), "i_btn_U": tog.py("i_btn_U"),
                 "io_dht11": tri.py("io_dht11")}
    do = {"o_fnd_data": mgr.py("o_fnd_data"), "o_dashes": mgr.py("o_dashes"), "o_led": dcat.py("o_led"),
          "o_done": 960, "o_valid": 984, "o_humidity": 1008, "o_temperature": 1032, "o_status": 1056}
    DW = {"o_fnd_data": "[13:0]", "o_led": "[3:0]", "o_humidity": "[7:0]", "o_temperature": "[7:0]", "o_status": "[1:0]"}
    B(Block("D_OUT", 1920, 620, 190, [(k, DW.get(k, "")) for k in do], [], kind="pins_out", title="dht11_top 출력",
            h=480, pin_y=do))
    pg.boundaries = [("sr04_top", "S_IN", "S_OUT"), ("dht11_top", "D_IN", "D_OUT")]
    for bb in ["D_CORE", "D_MGR"]:
        pg.flag(bb, "i_clk", "clk", "clk")
        pg.flag(bb, "i_rst", "rst", "clk")
    pg.flag("D_IN", "i_clk", "clk", "clk")
    pg.flag("D_IN", "i_rst", "rst", "clk")
    pg.flag("D_CORE", "o_busy", "w_busy", "nc")
    pg.flag("D_CORE", "o_state", "w_state", "nc")
    pg.net("i_btn_U", ("D_IN", "i_btn_U"), [("D_TOG", "i_btn_U", [])])
    pg.net("i_btn_R", ("D_IN", "i_btn_R"), [("D_CORE", "i_start", [])])
    pg.net("io_dht11", ("D_IN", "io_dht11"), [("D_TRI", "io_dht11", [])], kind="bidir")
    pg.net("c_auto_mode", ("D_TOG", "c_auto_mode"), [("D_CORE", "i_auto_en", [580]), ("D_CAT", "c_auto_mode", [580, 628, 1570])])
    pg.net("w_dht_in", ("D_TRI", "w_dht_in"), [("D_CORE", "i_dht11", [596])])
    pg.net("w_dht_oe", ("D_CORE", "o_dht_oe"), [("D_TRI", "w_dht_oe", [970, 985, 250])])
    pg.net("w_measuring", ("D_CORE", "o_measuring"), [("D_MGR", "i_measuring", [1150])])
    pg.net("o_done", ("D_CORE", "o_done"), [("D_MGR", "i_done", [1136]), ("D_OUT", "o_done", [1136, 960])])
    pg.net("o_valid", ("D_CORE", "o_valid"), [("D_MGR", "i_valid", [1122]), ("D_OUT", "o_valid", [1122, 984])])
    pg.net("o_humidity", ("D_CORE", "o_humidity"), [("D_MGR", "i_humidity", [1108]), ("D_OUT", "o_humidity", [1108, 1008])])
    pg.net("o_temperature", ("D_CORE", "o_temperature"),
           [("D_MGR", "i_temperature", [1094]), ("D_OUT", "o_temperature", [1094, 1032])])
    pg.net("o_status", ("D_CORE", "o_status"), [("D_OUT", "o_status", [1080, 1056])])
    pg.net("o_fnd_data", ("D_MGR", "o_fnd_data"), [("D_OUT", "o_fnd_data", [])])
    pg.net("o_dashes", ("D_MGR", "o_dashes"), [("D_OUT", "o_dashes", [])])
    pg.net("o_led[2:0]", ("D_MGR", "o_led"), [("D_CAT", "o_led[2:0]", [1550])])
    pg.net("o_led", ("D_CAT", "o_led"), [("D_OUT", "o_led", [])])
    pg.note(640, 1100, "dht11_core 안쪽 : 요청 관리 (부팅 1 s · 간격 2 s, 간격 안 요청은 기억) · tick_gen_us (1 us) · dht11_controller (FSM)",
            11.5, "#555")
    pg.note(640, 1080, "o_status 00 정상 · 01 응답 없음 (Err1) · 10 중간 끊김 (Err2) · 11 체크섬 (Err3)", 11.5, "#555")
    pg.note(1240, 888, "o_fnd_data = 습도 x 100 + 온도 (5524 → \"55.24\")", 11.5, "#555")
    pg.note(1240, 904, "o_dashes = 정상값 없음 · 오류 → \"----\"", 11.5, "#555")
    pg.note(1240, 920, "o_led [0] 측정 중 [1] 오류 [2] 정상값", 11.5, "#555")
    legend(pg, 1170, " / 청록 양쪽 화살표 = inout")
    return pg


# =========================================================================== 5 쪽 : U_FND_CONTROLLER
def page_fnd():
    pg = Page("fnd", "U_FND_CONTROLLER (SW2_FND_CONTROLLER) 내부 — FND 자리별 출력이 만들어지는 길", 2760, 1700)
    F = "SW2_FND_CONTROLLER.v"
    B = pg.add
    dec_out = [("w_disp_msec", "[6:0]"), ("w_disp_sec", "[5:0]"), ("w_disp_min", "[5:0]"), ("w_disp_hour", "[5:0]"),
               "w_dist_data[11:0]", "w_dist_data[12]", "w_dist_data[14:13]",
               "w_dht_data[13:0]", "w_dht_data[14]", "w_dht_data[15]", "w_dht_data[17:16]"]
    dec = B(Block("DEC", 240, 120, 270, [("i_disp_data", "[24:0]"), ("i_disp_sel", "[1:0]")], dec_out, kind="assign",
                  title="① 데이터 나누기", title2="(i_disp_sel 이 아닌 쪽은 0)", parent=F,
                  note="0 WTS : {hour 6, min 6, sec 6, msec 7}\n1 거리 : {status 2, err 1, x10 12}\n"
                       "2 온습도 : {status 2, err 1, dashes 1, data 14}"))
    XS = 700
    sp = {}
    for i, (nm, w) in enumerate([("MSEC", 7), ("SEC", 6), ("MIN", 6), ("HOUR", 6)]):
        sp[nm] = B(Block("U_" + nm, XS, 120 + i * 150, 250, [("i_value", f"[{w-1}:0]")],
                         [("o_digit1", "[3:0]"), ("o_digit10", "[3:0]")], inst="U_" + nm, module="digit_splitter",
                         parent=F))
    cnt = B(Block("CNT", XS, 720, 250, ["i_clk_4khz", "i_rst"], [("o_scan_sel", "[2:0]")], inst="U_COUNTER8",
                  module="counter8", parent=F, note="i_clk_4khz 마다 +1 → 0~7, 한 칸 250 us (WTS · 거리 · 온습도 같이 씀)"))
    dot = B(Block("DOT", XS, 870, 250, [("i_disp_msec", "[6:0]")], ["o_blink_off"], inst="U_DOT", module="dot",
                  parent=F, note="o_blink_off = (i_disp_msec ≥ 50)"))
    fdist = B(Block("FDIST", XS, 1060, 250, [("i_value", "[11:0]"), "i_err", ("i_status", "[1:0]"), ("i_scan_sel", "[2:0]")],
                    [("o_bcd", "[3:0]")], inst="U_FND_DIST", module="fnd_dist", parent=F,
                    note="\"352.7\" (AN1 점) / 오류 \"ErrN\" (N = i_status)"))
    fdht = B(Block("FDHT", XS, 1250, 250, [("i_value", "[13:0]"), "i_dashes", "i_err", ("i_status", "[1:0]"),
                                          ("i_scan_sel", "[2:0]")], [("o_bcd", "[3:0]")], inst="U_FND_DHT",
                   module="fnd_dht", parent=F, note="\"55.24\" (AN2 점) / 측정 전 \"----\" / 오류 \"ErrN\""))
    XA = 1090
    ac_in = ["i_set_sw2", "i_disp_mode", "i_sel_wt", ("i_wt_cursor", "[1:0]"), "i_blink_off",
             ("i_an0", "[3:0]"), ("i_an1", "[3:0]"), ("i_an2", "[3:0]"), ("i_an3", "[3:0]")]
    ac_out = [("o_an0", "[3:0]"), ("o_an1", "[3:0]"), ("o_an2", "[3:0]"), ("o_an3", "[3:0]")]
    B(Block("AC2", XA, 470, 270, ac_in, ac_out, inst="U_ANODE_CHOICE_TO_MUX2", module="SW2_ANODE_CHOICE", parent=F,
            note="시.분 쪽 : set_sw2 & disp_mode & sel_wt & blink_off 이면 커서 자리 = 4'hd (빈칸)"))
    XM = 1510
    m8 = [f"i_d{i}" for i in range(8)]
    for bid, inst, y in [("SECMUX", "U_SEC_MUXER", 160), ("MINMUX", "U_MIN_MUXER", 520)]:
        bb = B(Block(bid, XM, y, 110, m8, [("o_data", "[3:0]")], kind="mux", title=f"{inst} (mux_8x1)", sel=["i_sel"], parent=F))
        bb.module, bb.inst = "mux_8x1", inst
    B(Block("M2", 1770, 380, 80, ["w_sec_mux_bcd", "w_min_mux_bcd"], [("w_wts_bcd", "[3:0]")], kind="mux", title="2:1 (assign)",
            sel=["i_disp_mode"], parent=F))
    m3 = B(Block("M3", 1990, 392, 80, ["w_wts_bcd", "w_dist_bcd", "w_dht_bcd"], [("w_bcd", "[3:0]")], kind="mux",
                 title="③ 3:1 (assign)", sel=["i_disp_sel"], parent=F))
    fdec = B(Block("FDEC", 2190, 388, 260, [("i_bcd", "[3:0]")], [("o_fnd_font", "[7:0]")], inst="U_FND_DEC",
                   module="fnd_decoder", parent=F, note="0~9 숫자 · a E · b r · c - · d,f 빈칸 · e 점"))
    d24 = B(Block("D24", 2190, 900, 260, [("i_sel", "[1:0]")], [("o_fnd_com", "[3:0]")], inst="U_DECODER",
                  module="decoder_2x4", parent=F, note="i_sel = w_scan_sel[1:0] : 00→AN0 … 11→AN3 (active low)"))
    fin_p = [("i_disp_data", "[24:0]"), ("i_disp_sel", "[1:0]"), "i_clk_4khz", "i_rst", "i_disp_mode",
             ("i_wt_cursor", "[1:0]"), "i_sel_wt", "i_set_sw2"]
    fin = B(Block("FIN", 20, 100, 170, [], fin_p, kind="pins_in", title="입력 포트", h=1460))
    fin.pin_y = {"i_disp_data": dec.py("i_disp_data"), "i_disp_sel": dec.py("i_disp_sel"),
                 "i_clk_4khz": cnt.py("i_clk_4khz"), "i_rst": cnt.py("i_rst"),
                 "i_disp_mode": 1450, "i_wt_cursor": 1475, "i_sel_wt": 1500, "i_set_sw2": 1525}
    B(Block("FOUT", 2570, 330, 170, [("o_fnd_font", "[7:0]"), ("o_fnd_com", "[3:0]")], [], kind="pins_out",
            title="출력 포트", h=700, pin_y={"o_fnd_font": fdec.py("o_fnd_font"), "o_fnd_com": d24.py("o_fnd_com")}))
    pg.boundaries = [("SW2_FND_CONTROLLER", "FIN", "FOUT")]

    pg.net("i_disp_data", ("FIN", "i_disp_data"), [("DEC", "i_disp_data", [])])
    pg.net("i_disp_sel", ("FIN", "i_disp_sel"), [("DEC", "i_disp_sel", []), ("M3", "i_disp_sel", [216, 1580])])
    pg.net("i_clk_4khz", ("FIN", "i_clk_4khz"), [("CNT", "i_clk_4khz", [])], kind="clk4k")
    pg.net("i_rst", ("FIN", "i_rst"), [("CNT", "i_rst", [])])
    pg.net("w_disp_msec", ("DEC", "w_disp_msec"), [("U_MSEC", "i_value", []), ("DOT", "i_disp_msec", [690])])
    for x, k in [(664, "sec"), (650, "min"), (636, "hour")]:
        pg.net("w_disp_" + k, ("DEC", "w_disp_" + k), [("U_" + k.upper(), "i_value", [x])])
    for x, (o, b, p) in zip(range(600, 520, -12), [
            ("w_dist_data[11:0]", "FDIST", "i_value"), ("w_dist_data[12]", "FDIST", "i_err"),
            ("w_dist_data[14:13]", "FDIST", "i_status"), ("w_dht_data[13:0]", "FDHT", "i_value"),
            ("w_dht_data[14]", "FDHT", "i_dashes"), ("w_dht_data[15]", "FDHT", "i_err"),
            ("w_dht_data[17:16]", "FDHT", "i_status")]):
        pg.net(o, ("DEC", o), [(b, p, [x])])
    for j, (p, x) in enumerate([("i_set_sw2", 1010), ("i_disp_mode", 1022), ("i_sel_wt", 1034), ("i_wt_cursor", 1046)]):
        pg.net(p, ("FIN", p), [("AC2", p, [x])] + ([("M2", "i_disp_mode", [])] if p == "i_disp_mode" else []))
    pg.net("w_blink_off", ("DOT", "o_blink_off"),
           [("AC2", "i_blink_off", [1058]), ("SECMUX", "i_d6", [1058, 1000, 1436]), ("MINMUX", "i_d6", [1058, 1000, 1436])])
    for k, base in [("MSEC", 0), ("SEC", 2)]:
        pg.net(f"w_{k.lower()}_digit1", ("U_" + k, "o_digit1"), [("SECMUX", f"i_d{base}", [1370 + base * 14])])
        pg.net(f"w_{k.lower()}_digit10", ("U_" + k, "o_digit10"), [("SECMUX", f"i_d{base + 1}", [1384 + base * 14])])
    for k, base in [("MIN", 0), ("HOUR", 2)]:
        pg.net(f"w_{k.lower()}_digit1", ("U_" + k, "o_digit1"), [("AC2", f"i_an{base}", [970 + base * 10])])
        pg.net(f"w_{k.lower()}_digit10", ("U_" + k, "o_digit10"), [("AC2", f"i_an{base + 1}", [985 + base * 10])])
    for i in range(4):
        pg.net(f"w_mux2_an{i}", ("AC2", f"o_an{i}"), [("MINMUX", f"i_d{i}", [1380 + i * 14])])
    for m in ["SECMUX", "MINMUX"]:
        for d in ["i_d4", "i_d5", "i_d7"]:
            pg.flag(m, d, "4'hf", "clk")
    pg.net("w_scan_sel", ("CNT", "o_scan_sel"),
           [("SECMUX", "i_sel", [975, 1020, 1660, 440]), ("MINMUX", "i_sel", [975, 1020]),
            ("D24", "i_sel", [975, 1020, 2150]), ("FDIST", "i_scan_sel", [975, 1020, 690]),
            ("FDHT", "i_scan_sel", [975, 1020, 690])], kind="clk4k")
    pg.net("w_sec_mux_bcd", ("SECMUX", "o_data"), [("M2", "w_sec_mux_bcd", [1700])])
    pg.net("w_min_mux_bcd", ("MINMUX", "o_data"), [("M2", "w_min_mux_bcd", [1715])])
    pg.net("w_wts_bcd", ("M2", "w_wts_bcd"), [("M3", "w_wts_bcd", [])])
    pg.net("w_dist_bcd", ("FDIST", "o_bcd"), [("M3", "w_dist_bcd", [1940])])
    pg.net("w_dht_bcd", ("FDHT", "o_bcd"), [("M3", "w_dht_bcd", [1955])])
    pg.net("w_bcd", ("M3", "w_bcd"), [("FDEC", "i_bcd", [])])
    pg.net("o_fnd_font", ("FDEC", "o_fnd_font"), [("FOUT", "o_fnd_font", [])])
    pg.net("o_fnd_com", ("D24", "o_fnd_com"), [("FOUT", "o_fnd_com", [])])

    pg.note(XA, 262, "초.1/100초 쪽 : 설정 점멸 없음 (시.분 화면만)", 12.5, "#7a4d00")
    pg.note(XA, 280, "digit 을 U_SEC_MUXER 에 바로 연결", 12.5, "#7a4d00")
    pg.note(1990, 540, "③ 3:1 MUX : i_disp_sel 0 → w_wts_bcd · 1 → w_dist_bcd · 2 → w_dht_bcd", 12, "#7a4d00")
    pg.note(30, 1620, "스캔 순서 (w_scan_sel 0→7, 2 ms 한 바퀴) : 0 AN0 → 1 AN1 → 2 AN2 → 3 AN3 (숫자) → 4 · 5 · 6 · 7 AN0~AN3 빈칸 · 점 "
            "(WTS 6 = AN2 점, 거리 5 = AN1 점, 온습도 6 = AN2 점).  U_SEC_MUXER · U_MIN_MUXER i_d6 = {3'b111, w_blink_off}", 13, "#333")
    pg.note(30, 1642, "2:1 MUX : i_disp_mode 0 → w_sec_mux_bcd (초.1/100초), 1 → w_min_mux_bcd (시.분) / "
            "U_FND_DIST · U_FND_DHT 안쪽 = digit_splitter 2 개 + mux_8x1 (같은 w_scan_sel 로 자리 고르기)", 13, "#333")
    legend(pg, 1670)
    return pg


# =========================================================================== 6 쪽 : U_LED
def page_led():
    pg = Page("led", "U_LED (led_output) 내부 — 모드별 LED · 타이머 알람 점멸", 1440, 930)
    F = "led_output.v"
    B = pg.add
    wl_in = ["i_sel_wt", "i_sel_sw", "i_display_mode_sw1", "i_timer_sw4", "i_sel_tm", "i_tm_run", "i_sw_lap",
             "i_hour24_sw3", "i_wt_pm"]
    wl = B(Block("WLED", 330, 110, 300, wl_in, [("w_wts_led", "[15:0]")], kind="assign", title="WTS LED 비트",
                 title2="(assign w_wts_led[n])", parent=F))
    bl = B(Block("BLINK", 330, 470, 300, [("i_wt_msec", "[6:0]")], ["w_alarm_blink"], kind="assign",
                 title="알람 점멸 박자", parent=F, note="w_alarm_blink = (i_wt_msec ≥ 50) : 0.5 초 켜짐 · 0.5 초 꺼짐"))
    m3 = B(Block("M3", 760, 150, 90, ["w_wts_led", "i_sr04_led", "i_dht_led"], [("w_mode_led", "[15:0]")], kind="mux",
                 title="w_mode_led[15:0]", sel=["i_disp_sel"], parent=F))
    m2 = B(Block("M2", 990, 170, 90, ["w_mode_led", "w_alarm_blink"], [("o_led", "[15:0]")], kind="mux",
                 title="o_led[15:0]", sel=["i_tm_alarm"], parent=F))
    lp = wl_in + [("i_wt_msec", "[6:0]"), ("i_sr04_led", "[9:0]"), ("i_dht_led", "[3:0]"), ("i_disp_sel", "[1:0]"),
                  "i_tm_alarm"]
    lin = B(Block("LIN", 20, 100, 200, [], lp, kind="pins_in", title="led_output 입력", h=620))
    py = {p: wl.py(p) for p in wl_in}
    py.update({"i_wt_msec": bl.py("i_wt_msec"), "i_sr04_led": 600, "i_dht_led": 630, "i_disp_sel": 660, "i_tm_alarm": 690})
    lin.pin_y = py
    B(Block("LOUT", 1220, 100, 170, [("o_led", "[15:0]")], [], kind="pins_out", title="led_output 출력", h=300,
            pin_y={"o_led": m2.py("o_led")}))
    pg.boundaries = [("led_output", "LIN", "LOUT")]
    for p in wl_in:
        pg.net(p, ("LIN", p), [("WLED", p, [])])
    pg.net("i_wt_msec", ("LIN", "i_wt_msec"), [("BLINK", "i_wt_msec", [])])
    pg.net("i_sr04_led", ("LIN", "i_sr04_led"), [("M3", "i_sr04_led", [700])])
    pg.net("i_dht_led", ("LIN", "i_dht_led"), [("M3", "i_dht_led", [715])])
    pg.net("i_disp_sel", ("LIN", "i_disp_sel"), [("M3", "i_disp_sel", [])])
    pg.net("i_tm_alarm", ("LIN", "i_tm_alarm"), [("M2", "i_tm_alarm", [])])
    pg.net("w_wts_led", ("WLED", "w_wts_led"), [("M3", "w_wts_led", [690])])
    pg.net("w_mode_led", ("M3", "w_mode_led"), [("M2", "w_mode_led", [920])])
    pg.net("w_alarm_blink", ("BLINK", "w_alarm_blink"), [("M2", "w_alarm_blink", [960])])
    pg.net("o_led", ("M2", "o_led"), [("LOUT", "o_led", [])])
    rows = ["w_wts_led (i_disp_sel = 0, WTS) :",
            "  [0] i_sel_wt 시계 · [1] i_sel_sw 스톱워치 · [2] ~i_timer_sw4 & i_display_mode_sw1 시.분 · [3] ~i_timer_sw4 & ~i_display_mode_sw1 초.1/100초",
            "  [5] i_sel_tm 타이머 · [6] i_tm_run 타이머 진행 중 · [7] i_sel_sw & i_sw_lap 랩 · [15] i_sel_wt & ~i_hour24_sw3 & i_wt_pm 오후 · [4] · [14:8] = 0",
            "i_disp_sel = 1 (거리) : {6'd0, i_sr04_led} → [7:0] 거리 막대 · [8] 측정 중 · [9] 측정 오류",
            "i_disp_sel = 2 (온습도) : {12'd0, i_dht_led} → [0] 측정 중 · [1] 오류 · [2] 정상값 · [3] 자동 측정",
            "i_tm_alarm = 1 : 어느 화면이든 16 개 전부 w_alarm_blink 로 점멸 (타이머는 다른 화면에서도 계속 돌기 때문)"]
    for i, r in enumerate(rows):
        pg.note(30, 770 + i * 20, r, 13, "#333", "bold" if i == 0 else "normal")
    legend(pg, 905)
    return pg
