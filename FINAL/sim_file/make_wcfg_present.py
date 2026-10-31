#!/usr/bin/env python3
"""발표용 TB (tb_P_present) 장면별 파형 설정 — python3 make_wcfg_present.py

- 결과 : wcfg/present/P1.wcfg … P6.wcfg (run_present.bat P3 wave 가 P3.wcfg 를 엶)
- 장면마다 발표에 필요한 신호만, 위 → 아래 = 신호가 흘러가는 순서 (PC 명령 → Top 내부 → 출력)
- 처음 열 때 화면 = 그 장면의 overview 캡처 구간 (ZOOM), 확대 구간은 안내서 표를 보고 Go To Time
- 경로 : 'h/...' = 하네스 (DUT = h/dut), 그 밖 = TB 맨 위 (W_STEP, GO_GAP_US …)
- radix : A ASCII, D 부호 없는 10진, S 부호 10진, H 16진, B 2진 / 비트 수 0 = 1 비트
- 색 : C 명령 (하늘), K 핵심 결과 (노랑), S 센서 핀 (초록), E 오류 (빨강), '' 기본
"""
import os

TB = 'tb_P_present'
RADIX = {'A': 'ASCIIRADIX', 'D': 'UNSIGNEDDECRADIX', 'S': 'SIGNEDDECRADIX', 'H': 'HEXRADIX', 'B': 'BINARYRADIX'}
COLOR = {'C': '#00FFFF', 'K': '#FFFF00', 'S': '#00FF00', 'E': '#FF5050'}

# ---------------------------------------------------------------- 공통 조각
STEP = ('TB : step / PC command (CR = #)', [
    ('W_STEP', 128, 'A', 'K'), ('h/W_CMD', 128, 'A', 'C'), ('h/rx', 0, '', 'C'),
])
# 디코더 : DEC_STATE = c_state 이름 (ASCII), c_state 숫자, w_ascii = 모은 옵션 글자 ("dist")
DEC = [('DEC_STATE', 64, 'A', 'K'), ('h/dut/U_UART/U_ASCII_DECODER/c_state', 4, 'D', ''),
       ('h/dut/U_UART/w_ascii', 40, 'A', '')]
# w_rx_data 는 시프트 중간값이라 rx_done 때 잡은 W_RX
RX = [('h/dut/U_UART/w_rx_done', 0, '', ''), ('W_RX', 8, 'A', 'C')] + DEC + [('h/dut/U_UART/w_handshake', 0, '', 'K')]
TX = ('UART TX : send_go / sel / data -> tx -> line', [
    ('h/dut/U_UART/w_send_go', 0, '', 'K'), ('h/dut/U_UART/o_send_sel', 3, 'D', ''),
    ('h/dut/U_UART/w_send_data', 24, 'H', ''), ('h/dut/U_UART/w_tx_push_data', 8, 'A', ''),
    ('h/tx', 0, '', 'C'), ('h/W_LINE', 128, 'A', 'K'),
])
# FND : 4 kHz tick → scan_sel → fnd_com (→ FND_COM AN0~AN3) / fnd_font (→ FND_FONT 글자), w_fnd_data → FND_DATA
FND_SIG = [('h/dut/w_clk_4khz', 0, '', ''), ('h/dut/U_FND_CONTROLLER/w_scan_sel', 3, 'D', ''),
           ('h/fnd_com', 4, 'B', ''), ('FND_COM', 24, 'A', 'K'), ('h/fnd_font', 8, 'H', ''), ('FND_FONT', 16, 'A', 'K'),
           ('h/dut/w_fnd_data', 25, 'H', ''), ('FND_DATA', 64, 'A', 'K')]


def fnd(extra):
    return ('FND : 4 kHz tick / scan -> com (AN) / font (char) / fnd_data', FND_SIG + extra)


SCENES = {
    # 장면 : (overview 시작 ms, 끝 ms, 묶음)
    'P1': (0, 26, [
        STEP,
        ('UART RX / decoder', RX + [('h/dut/U_UART/w_mode', 0, '', '')]),
        ('MODE : switch vs UART -> ctrl_bit -> screen', [
            ('h/sw', 7, 'B', 'C'), ('h/dut/w_sw_ctrl_bit', 7, 'B', ''), ('h/dut/w_uart_ctrl_bit', 7, 'B', ''),
            ('h/dut/w_uart_mode', 0, '', 'K'), ('h/dut/w_ctrl_bit', 7, 'B', 'K'), ('h/dut/w_disp_sel', 2, 'D', 'K'),
        ]),
        fnd([('h/led', 16, 'H', '')]),
    ]),
    'P2': (11.5, 46.5, [
        STEP,
        ('UART RX / decoder', RX + [('h/dut/U_UART/w_btn', 0, '', ''), ('h/dut/U_UART/w_get', 0, '', '')]),
        ('BUTTON : uart /btn -> merged -> SR04', [
            ('h/dut/w_uart_btn_R', 0, '', 'K'), ('h/dut/w_btn_R', 0, '', ''), ('h/dut/U_SR04/i_btn_R', 0, '', ''),
        ]),
        ('SR04 : trig / echo -> distance', [
            ('h/trig', 0, '', 'S'), ('h/echo', 0, '', 'S'), ('h/dut/U_SR04/w_state', 3, 'D', ''),
            ('h/dut/w_dist_done', 0, '', ''), ('h/dut/w_distance', 9, 'D', 'K'), ('h/dut/w_distance_x10', 12, 'D', ''),
            ('h/dut/w_dist_status', 2, 'D', ''),
        ]),
        fnd([('h/led', 16, 'H', '')]),
        TX,
    ]),
    'P3': (50, 5180, [
        STEP,
        ('UART RX / decoder', RX + [('h/dut/U_UART/w_auto', 0, '', '')]),
        ('AUTO : 1 Hz tick -> send_go (GO_GAP = interval)', [
            ('h/dut/U_UART/U_CONTROL/w_clk_5hz', 0, '', 'K'), ('h/dut/U_UART/w_send_go', 0, '', 'K'),
            ('GO_GAP_US', 32, 'S', 'K'), ('GO_GAP_CLK', 32, 'S', ''), ('N_GO', 32, 'S', ''),
            ('h/dut/U_UART/o_send_sel', 3, 'D', 'K'),
        ]),
        ('UART TX : data -> tx -> line', [
            ('h/dut/U_UART/w_send_data', 24, 'H', ''), ('h/dut/U_UART/w_tx_push_data', 8, 'A', ''),
            ('h/tx', 0, '', 'C'), ('h/W_LINE', 128, 'A', 'K'),
        ]),
        ('DATA sources (send MUX inputs)', [
            ('h/dut/w_sw_time', 24, 'H', ''), ('h/dut/w_tm_time', 24, 'H', ''), ('h/dut/w_wt_time', 24, 'H', ''),
            ('h/dut/w_distance', 9, 'D', ''), ('h/dut/w_humidity', 8, 'D', ''), ('h/dut/w_temperature', 8, 'D', ''),
        ]),
        fnd([('h/dut/w_disp_sel', 2, 'D', '')]),
    ]),
    'P4': (0.5, 34.5, [
        STEP,
        ('UART RX / decoder -> error', RX + [('h/dut/U_UART/w_error', 0, '', 'E')]),
        TX,
    ]),
    'P5': (0, 258, [
        STEP,
        ('UART RX / decoder', RX + [('h/dut/w_uart_btn_R', 0, '', '')]),
        ('SR04 : trig / echo -> status (1 no echo, 2 range, 3 stuck)', [
            ('h/trig', 0, '', 'S'), ('h/echo', 0, '', 'S'), ('h/dut/U_SR04/w_state', 3, 'D', ''),
            ('h/dut/w_dist_done', 0, '', ''), ('h/dut/w_dist_status', 2, 'D', 'E'), ('h/dut/w_dist_err', 0, '', 'E'),
            ('h/dut/w_distance', 9, 'D', ''),
        ]),
        fnd([('LD9', 0, '', 'E')]),
        TX,
    ]),
    'P6': (0, 5045, [
        STEP,
        ('UART RX / decoder', RX + [('h/dut/w_uart_btn_R', 0, '', '')]),
        ('DHT11 : data line -> status (1 no resp, 2 cut, 3 checksum)', [
            ('h/dht11_io', 0, '', 'S'), ('h/dut/U_DHT11/w_dht_oe', 0, '', ''), ('h/dht_drv', 0, '', ''),
            ('h/dut/U_DHT11/w_state', 4, 'D', ''), ('h/dut/w_dht_done', 0, '', ''),
            ('h/dut/w_dht_status', 2, 'D', 'E'), ('h/dut/w_dht_err', 0, '', 'E'), ('h/dut/w_dht_dashes', 0, '', ''),
            ('h/dut/w_humidity', 8, 'D', ''), ('h/dut/w_temperature', 8, 'D', ''),
        ]),
        fnd([('h/dut/w_dht_led', 4, 'B', '')]),
        TX,
    ]),
}


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def obj(path, width, radix, color, ind):
    fp = f'/{TB}/{path}'
    name = path.split('/')[-1]
    sp = ' ' * ind
    col = ''
    if color:
        col = (f'{sp}   <obj_property name="CustomSignalColor">{COLOR[color]}</obj_property>\n'
               f'{sp}   <obj_property name="UseCustomSignalColor">true</obj_property>\n')
    if width == 0:
        return (f'{sp}<wvobject fp_name="{fp}" type="logic">\n'
                f'{sp}   <obj_property name="ElementShortName">{name}</obj_property>\n'
                f'{sp}   <obj_property name="ObjectShortName">{name}</obj_property>\n'
                f'{col}{sp}</wvobject>\n')
    n = f'{name}[{width - 1}:0]'
    return (f'{sp}<wvobject fp_name="{fp}" type="array">\n'
            f'{sp}   <obj_property name="ElementShortName">{n}</obj_property>\n'
            f'{sp}   <obj_property name="ObjectShortName">{n}</obj_property>\n'
            f'{sp}   <obj_property name="Radix">{RADIX[radix]}</obj_property>\n'
            f'{col}{sp}</wvobject>\n')


def wcfg(z0_ms, z1_ms, groups):
    body = ''
    for i, (label, sigs) in enumerate(groups, 1):
        body += (f'   <wvobject fp_name="group{i}" type="group">\n'
                 f'      <obj_property name="label">{esc(label)}</obj_property>\n'
                 f'      <obj_property name="DisplayName">label</obj_property>\n')
        for p, w, r, c in sigs:
            body += obj(p, w, r, c, 6)
        body += '   </wvobject>\n'
    fs = lambda ms: f'{int(round(ms * 1e12))}fs'
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<wave_config>\n   <wave_state>\n   </wave_state>\n'
            '   <db_ref_list>\n'
            f'      <db_ref path="{TB}_behav.wdb" id="1">\n'
            '         <top_modules>\n            <top_module name="glbl" />\n'
            f'            <top_module name="{TB}" />\n'
            '         </top_modules>\n      </db_ref>\n   </db_ref_list>\n'
            f'   <zoom_setting>\n      <ZoomStartTime time="{fs(z0_ms)}"></ZoomStartTime>\n'
            f'      <ZoomEndTime time="{fs(z1_ms)}"></ZoomEndTime>\n'
            '      <Cursor1Time time="0fs"></Cursor1Time>\n   </zoom_setting>\n'
            '   <column_width_setting>\n      <NameColumnWidth column_width="250"></NameColumnWidth>\n'
            '      <ValueColumnWidth column_width="130"></ValueColumnWidth>\n   </column_width_setting>\n'
            f'   <WVObjectSize size="{len(groups)}" />\n' + body + '</wave_config>\n')


if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, 'wcfg', 'present')
    os.makedirs(out, exist_ok=True)
    for sc, (z0, z1, groups) in SCENES.items():
        with open(os.path.join(out, f'{sc}.wcfg'), 'w', encoding='utf-8', newline='\r\n') as f:
            f.write(wcfg(z0, z1, groups))
        print(f'wcfg/present/{sc}.wcfg')
