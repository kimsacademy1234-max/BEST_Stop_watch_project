#!/usr/bin/env python3
"""그룹 TB 12 개의 Vivado 파형 설정 (.wcfg) 생성 — python3 make_wcfg.py

- 결과 : wcfg/tb_A_reset.wcfg … wcfg/tb_L_integration.wcfg
- 모든 wcfg 공통 : ① 시나리오 · 판정 (ASCII)  ② 핀 · UART 줄 · FND 문자열
  그 뒤에 그룹별 내부 신호 묶음.
- 신호 경로 = /<TB 이름>/h/... (하네스 인스턴스 이름 h, DUT = h/dut)
- 신호를 더하려면 아래 GROUPS 표에 (경로, 비트 수, radix) 를 추가하고 다시 실행.
  비트 수 0 = 1 비트 (logic). radix : A ASCII, D 부호 없는 10진, S 부호 10진, H 16진, B 2진
"""
import os

RADIX = {'A': 'ASCIIRADIX', 'D': 'UNSIGNEDDECRADIX', 'S': 'SIGNEDDECRADIX', 'H': 'HEXRADIX', 'B': 'BINARYRADIX'}

TBS = {
    'A': 'tb_A_reset', 'B': 'tb_B_button', 'C': 'tb_C_mode', 'D': 'tb_D_stopwatch',
    'E': 'tb_E_watch', 'F': 'tb_F_timer', 'G': 'tb_G_uart_rx', 'H': 'tb_H_uart_ctrl',
    'I': 'tb_I_sr04', 'J': 'tb_J_dht11', 'K': 'tb_K_display', 'L': 'tb_L_integration',
}

# ---------------------------------------------------------------- 공통 묶음
COMMON = [
    ('TB : scenario / last check / result (ASCII)', [
        ('W_SC', 64, 'A'), ('W_CHK', 64, 'A'), ('W_RES', 64, 'A'),
        ('n_chk', 32, 'S'), ('n_fail', 32, 'S'), ('n_issue', 32, 'S'),
    ]),
    ('PIN : reset / switch / button', [
        ('rst', 0, ''), ('dut/w_rst', 0, ''), ('sw', 7, 'B'), ('sw15', 0, ''),
        ('btn_R', 0, ''), ('btn_L', 0, ''), ('btn_U', 0, ''), ('btn_D', 0, ''),
    ]),
    ('UART : PC cmd (CR=#) / rx / tx / FPGA line (ASCII)', [
        ('W_CMD', 128, 'A'), ('rx', 0, ''), ('tx', 0, ''), ('W_LINE', 128, 'A'),
    ]),
    ('FND / LED', [
        ('W_FND', 64, 'A'), ('fnd_com', 4, 'B'), ('fnd_font', 8, 'H'), ('led', 16, 'H'),
    ]),
    ('MODE : ctrl bit {sw6..sw0} / screen 0 WTS 1 dist 2 temp', [
        ('dut/w_uart_mode', 0, ''), ('dut/w_ctrl_bit', 7, 'B'), ('dut/w_disp_sel', 2, 'D'),
    ]),
]

WTS_DISP = [('dut/w_disp_hour', 6, 'D'), ('dut/w_disp_min', 6, 'D'), ('dut/w_disp_sec', 6, 'D'),
            ('dut/w_disp_msec', 7, 'D'), ('dut/w_disp_mode', 0, ''), ('dut/w_sel_sw', 0, ''),
            ('dut/w_sel_wt', 0, ''), ('dut/w_sel_tm', 0, '')]
BTN_INT = [('dut/w_phy_btn_R', 0, ''), ('dut/w_phy_btn_L', 0, ''), ('dut/w_phy_btn_U', 0, ''), ('dut/w_phy_btn_D', 0, ''),
           ('dut/w_uart_btn_R', 0, ''), ('dut/w_uart_btn_L', 0, ''), ('dut/w_uart_btn_U', 0, ''), ('dut/w_uart_btn_D', 0, ''),
           ('dut/w_btn_R', 0, ''), ('dut/w_btn_L', 0, ''), ('dut/w_btn_U', 0, ''), ('dut/w_btn_D', 0, '')]
UART_RX = [('dut/U_UART/w_rx_done', 0, ''), ('dut/U_UART/w_rx_data', 8, 'A'), ('dut/U_UART/w_rx_full', 0, ''),
           ('dut/U_UART/w_handshake', 0, ''), ('dut/U_UART/w_error', 0, ''), ('dut/U_UART/w_ascii', 40, 'A'),
           ('dut/U_UART/w_get', 0, ''), ('dut/U_UART/w_btn', 0, ''), ('dut/U_UART/w_set', 0, ''),
           ('dut/U_UART/w_off_set', 0, ''), ('dut/U_UART/w_mode', 0, ''), ('dut/U_UART/w_auto', 0, '')]
UART_TX = [('dut/U_UART/o_send_sel', 3, 'D'), ('dut/U_UART/w_send_go', 0, ''), ('dut/U_UART/w_send_data', 24, 'H'),
           ('dut/U_UART/w_send_busy', 0, ''), ('dut/U_UART/w_tx_push', 0, ''), ('dut/U_UART/w_tx_push_data', 8, 'A'),
           ('dut/U_UART/w_tx_full', 0, ''), ('dut/U_UART/w_tx_empty', 0, ''), ('dut/U_UART/w_tx_busy', 0, '')]
SR04 = [('trig', 0, ''), ('echo', 0, ''), ('dut/U_SR04/w_state', 3, 'D'), ('dut/U_SR04/w_busy', 0, ''),
        ('dut/w_dist_done', 0, ''), ('dut/w_distance', 9, 'D'), ('dut/w_distance_x10', 12, 'D'),
        ('dut/w_dist_status', 2, 'D'), ('dut/w_dist_err', 0, ''), ('dut/w_dist_auto', 0, ''), ('dut/w_sr04_led', 10, 'B'),
        ('trig_cnt', 32, 'S')]
DHT = [('dht11_io', 0, ''), ('dht_drv', 0, ''), ('dut/U_DHT11/w_dht_oe', 0, ''), ('dut/U_DHT11/w_state', 4, 'D'),
       ('dut/U_DHT11/w_busy', 0, ''), ('dut/U_DHT11/c_auto_mode', 0, ''), ('dut/w_dht_done', 0, ''),
       ('dut/w_dht_valid', 0, ''), ('dut/w_dht_status', 2, 'D'), ('dut/w_dht_err', 0, ''), ('dut/w_dht_dashes', 0, ''),
       ('dut/w_humidity', 8, 'D'), ('dut/w_temperature', 8, 'D'), ('dut/w_dht_fnd_data', 14, 'D'), ('dut/w_dht_led', 4, 'B'),
       ('dh_start_cnt', 32, 'S')]

GROUPS = {
    'A': [('RESET', [('rst_rel_clk', 32, 'S'), ('trig', 0, ''), ('dht11_io', 0, ''), ('dut/U_DHT11/w_dht_oe', 0, ''),
                     ('dut/U_DHT11/w_state', 4, 'D'), ('dut/U_SR04/w_state', 3, 'D'), ('dut/U_UART/w_tx_busy', 0, ''),
                     ('dut/w_sw_time', 24, 'H'), ('dut/w_tm_time', 24, 'H'), ('dut/w_wt_time', 24, 'H')]),
          ('WTS display', WTS_DISP)],
    'B': [('DEBOUNCE : 4 kHz sample / shift reg', [('dut/w_clk_4khz', 0, ''), ('dut/U_BD_R/q_reg', 8, 'B'),
                                                   ('dut/U_BD_L/q_reg', 8, 'B'), ('dut/U_BD_U/q_reg', 8, 'B'),
                                                   ('dut/U_BD_D/q_reg', 8, 'B')]),
          ('BUTTON : phy / uart / merged', BTN_INT),
          ('WTS display', WTS_DISP),
          ('SENSOR start', [('trig', 0, ''), ('dut/U_DHT11/w_dht_oe', 0, '')])],
    'C': [('MODE detail', [('dut/w_sw_ctrl_bit', 7, 'B'), ('dut/w_uart_ctrl_bit', 7, 'B'), ('dut/w_mode_wts', 0, ''),
                           ('dut/w_mode_dist', 0, ''), ('dut/w_mode_dht', 0, ''), ('dut/w_wt_cursor', 2, 'D')]),
          ('UART RX / decoder', UART_RX),
          ('WTS display', WTS_DISP)],
    'D': [('STOPWATCH', [('dut/U_WTS/w_sw_run_stop', 0, ''), ('dut/U_WTS/w_sw_clear', 0, ''), ('dut/U_WTS/w_sw_down', 0, ''),
                         ('dut/U_WTS/w_sw_tick_10ms', 0, ''), ('dut/U_WTS/w_sw_hour', 6, 'D'), ('dut/U_WTS/w_sw_min', 6, 'D'),
                         ('dut/U_WTS/w_sw_sec', 6, 'D'), ('dut/U_WTS/w_sw_msec', 7, 'D'), ('dut/w_sw_lap', 0, ''),
                         ('dut/w_sw_time', 24, 'H')]),
          ('WTS display', WTS_DISP),
          ('BUTTON : phy / uart / merged', BTN_INT)],
    'E': [('WATCH', [('dut/U_WTS/w_tick_10ms', 0, ''), ('dut/U_WTS/w_wt_hour', 6, 'D'), ('dut/U_WTS/w_wt_hour_disp', 6, 'D'),
                     ('dut/U_WTS/w_wt_min', 6, 'D'), ('dut/U_WTS/w_wt_sec', 6, 'D'), ('dut/w_wt_msec', 7, 'D'),
                     ('dut/w_wt_pm', 0, ''), ('dut/w_wt_cursor', 2, 'D'), ('dut/U_WTS/w_wt_up', 0, ''),
                     ('dut/U_WTS/w_wt_down', 0, ''), ('dut/w_wt_time', 24, 'H')]),
          ('WTS display', WTS_DISP),
          ('BUTTON : phy / uart / merged', BTN_INT)],
    'F': [('TIMER', [('dut/w_tm_run', 0, ''), ('dut/w_tm_alarm', 0, ''), ('dut/U_WTS/w_tm_tick_10ms', 0, ''),
                     ('dut/U_WTS/w_tm_clear', 0, ''), ('dut/U_WTS/w_tm_add', 0, ''), ('dut/U_WTS/w_tm_amount', 2, 'D'),
                     ('dut/U_WTS/w_tm_zero', 0, ''), ('dut/U_WTS/w_tm_min', 6, 'D'), ('dut/U_WTS/w_tm_sec', 6, 'D'),
                     ('dut/U_WTS/w_tm_msec', 7, 'D'), ('dut/w_tm_time', 24, 'H')]),
          ('WTS display', WTS_DISP),
          ('BUTTON : phy / uart / merged', BTN_INT),
          ('SR04 (F6 distance screen)', [('trig', 0, ''), ('trig_cnt', 32, 'S')])],
    'G': [('UART RX / decoder', UART_RX),
          ('UART TX (ERROR line)', UART_TX)],
    'H': [('UART TX / sender', UART_TX),
          ('UART RX / decoder', UART_RX),
          ('BUTTON : phy / uart / merged', BTN_INT),
          ('DATA to send', [('dut/w_sw_time', 24, 'H'), ('dut/w_tm_time', 24, 'H'), ('dut/w_wt_time', 24, 'H'),
                            ('dut/w_distance', 9, 'D'), ('dut/w_dist_status', 2, 'D'), ('dut/w_humidity', 8, 'D'),
                            ('dut/w_temperature', 8, 'D'), ('dut/w_dht_status', 2, 'D')])],
    'I': [('SR04', SR04),
          ('UART TX', UART_TX[:3])],
    'J': [('DHT11', DHT),
          ('UART TX', UART_TX[:3])],
    'K': [('FND scan', [('dut/w_clk_4khz', 0, ''), ('dut/U_FND_CONTROLLER/w_scan_sel', 3, 'D'), ('dut/w_fnd_data', 25, 'H'),
                        ('dut/w_disp_mode', 0, ''), ('dut/w_wt_cursor', 2, 'D'), ('dut/w_sel_wt', 0, '')]),
          ('WTS display', WTS_DISP),
          ('SENSOR value', [('dut/w_distance_x10', 12, 'D'), ('dut/w_dist_status', 2, 'D'), ('dut/w_dist_err', 0, ''),
                            ('dut/w_dht_fnd_data', 14, 'D'), ('dut/w_dht_status', 2, 'D'), ('dut/w_dht_err', 0, ''),
                            ('dut/w_dht_dashes', 0, '')]),
          ('LED source', [('dut/w_tm_alarm', 0, ''), ('dut/w_tm_run', 0, ''), ('dut/w_wt_pm', 0, ''), ('dut/w_sw_lap', 0, ''),
                          ('dut/w_sr04_led', 10, 'B'), ('dut/w_dht_led', 4, 'B')])],
    'L': [('UART TX / sender', UART_TX[:4]),
          ('WTS display', WTS_DISP),
          ('STOPWATCH', [('dut/U_WTS/w_sw_run_stop', 0, ''), ('dut/w_sw_time', 24, 'H')]),
          ('SR04', SR04[:9]),
          ('DHT11', DHT[:11])],
}


def obj(tb, path, width, radix, ind):
    fp = f'/{tb}/h/{path}'
    name = path.split('/')[-1]
    sp = ' ' * ind
    if width == 0:
        return (f'{sp}<wvobject fp_name="{fp}" type="logic">\n'
                f'{sp}   <obj_property name="ElementShortName">{name}</obj_property>\n'
                f'{sp}   <obj_property name="ObjectShortName">{name}</obj_property>\n'
                f'{sp}</wvobject>\n')
    n = f'{name}[{width - 1}:0]'
    return (f'{sp}<wvobject fp_name="{fp}" type="array">\n'
            f'{sp}   <obj_property name="ElementShortName">{n}</obj_property>\n'
            f'{sp}   <obj_property name="ObjectShortName">{n}</obj_property>\n'
            f'{sp}   <obj_property name="Radix">{RADIX[radix]}</obj_property>\n'
            f'{sp}</wvobject>\n')


def wcfg(g):
    tb = TBS[g]
    groups = COMMON + GROUPS[g]
    body = ''
    for i, (label, sigs) in enumerate(groups, 1):
        body += (f'   <wvobject fp_name="group{i}" type="group">\n'
                 f'      <obj_property name="label">{label.replace("&", "&amp;").replace(">", "&gt;").replace("<", "&lt;")}</obj_property>\n'
                 f'      <obj_property name="DisplayName">label</obj_property>\n')
        for p, w, r in sigs:
            body += obj(tb, p, w, r, 6)
        body += '   </wvobject>\n'
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<wave_config>\n   <wave_state>\n   </wave_state>\n'
            '   <db_ref_list>\n'
            f'      <db_ref path="{tb}_behav.wdb" id="1">\n'
            '         <top_modules>\n            <top_module name="glbl" />\n'
            f'            <top_module name="{tb}" />\n'
            '         </top_modules>\n      </db_ref>\n   </db_ref_list>\n'
            '   <zoom_setting>\n      <ZoomStartTime time="0fs"></ZoomStartTime>\n'
            '      <ZoomEndTime time="100000000000000fs"></ZoomEndTime>\n'
            '      <Cursor1Time time="0fs"></Cursor1Time>\n   </zoom_setting>\n'
            '   <column_width_setting>\n      <NameColumnWidth column_width="230"></NameColumnWidth>\n'
            '      <ValueColumnWidth column_width="120"></ValueColumnWidth>\n   </column_width_setting>\n'
            f'   <WVObjectSize size="{len(groups)}" />\n' + body + '</wave_config>\n')


if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(os.path.join(here, 'wcfg'), exist_ok=True)
    for g, tb in TBS.items():
        with open(os.path.join(here, 'wcfg', f'{tb}.wcfg'), 'w', encoding='utf-8', newline='\r\n') as f:
            f.write(wcfg(g))
        print(f'wcfg/{tb}.wcfg')
