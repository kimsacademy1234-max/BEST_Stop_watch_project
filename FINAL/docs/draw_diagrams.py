# merge_final 블록 다이어그램 SVG 생성기
# 사용 : python3 draw_diagrams.py <출력 폴더>   (예 : python3 draw_diagrams.py .)
# 좌표를 고친 뒤 다시 돌리면 *.svg 가 새로 생김 (PNG 는 SVG 를 브라우저 · resvg 등으로 변환)
import os, sys
from xml.sax.saxutils import escape

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)

FONT = "'Malgun Gothic','Apple SD Gothic Neo','Noto Sans KR',sans-serif"
C = {
    'uart': ('#e8f5e9', '#2e7d32'),
    'wts':  ('#fff3e0', '#e65100'),
    'sr04': ('#f3e5f5', '#6a1b9a'),
    'dht':  ('#fffde7', '#f9a825'),
    'fnd':  ('#e3f2fd', '#1565c0'),
    'ip':   ('#eceff1', '#455a64'),
    'led':  ('#fce4ec', '#ad1457'),
    'mux':  ('#c8e6c9', '#1b5e20'),
    'pin':  ('#f5f5f5', '#616161'),
    'gate': ('#e0f7fa', '#00838f'),
}


class Svg:
    def __init__(self, w, h, title, sub=None, dy=0):
        self.w, self.h, self.dy = w, h, dy
        self.o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" font-family="{FONT}">',
                  '<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerUnits="userSpaceOnUse" markerWidth="10" markerHeight="10" orient="auto-start-reverse">'
                  '<path d="M0,0 L10,5 L0,10 z" fill="#37474f"/></marker></defs>',
                  f'<rect x="0" y="0" width="{w}" height="{h}" fill="#ffffff"/>']
        self.text(20, 30, title, 20, weight='bold')
        if sub:
            self.text(20, 52, sub, 13, color='#546e7a')
        self.o.append(f'<g transform="translate(0,{dy})">')

    def text(self, x, y, s, size=12, anchor='start', color='#263238', weight='normal', italic=False):
        st = ' font-style="italic"' if italic else ''
        self.o.append(f'<text x="{x}" y="{y}" font-size="{size}" text-anchor="{anchor}" fill="{color}" font-weight="{weight}"{st}>{escape(s)}</text>')

    def box(self, x, y, w, h, title, lines=(), kind='ip', dashed=False, tsize=14, lsize=11, title_top=None):
        f, s = C[kind]
        da = ' stroke-dasharray="6,4"' if dashed else ''
        fill = 'none' if dashed else f
        self.o.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="{fill}" stroke="{s}" stroke-width="2"{da}/>')
        n = len(lines)
        if title_top is not None:
            ty = y + title_top
        else:
            ty = y + h / 2 - (n * (lsize + 3)) / 2 + tsize / 2 - 1
        self.text(x + w / 2, ty, title, tsize, 'middle', s, 'bold')
        for i, l in enumerate(lines):
            self.text(x + w / 2, ty + (i + 1) * (lsize + 4) + 1, l, lsize, 'middle', '#37474f')

    def pin(self, x, y, w, h, s, out=False):
        f, st = C['pin']
        # 핀 : 화살표 모양 (입력은 오른쪽 뾰족, 출력은 왼쪽 뾰족)
        if not out:
            pts = f'{x},{y} {x+w-10},{y} {x+w},{y+h/2} {x+w-10},{y+h} {x},{y+h}'
        else:
            pts = f'{x+10},{y} {x+w},{y} {x+w},{y+h} {x+10},{y+h} {x},{y+h/2}'
        self.o.append(f'<polygon points="{pts}" fill="{f}" stroke="{st}" stroke-width="1.5"/>')
        self.text(x + w / 2 + (3 if out else -3), y + h / 2 + 4, s, 12, 'middle', '#212121', 'bold')

    def mux(self, x, y, w, h, inset, title='', point='right', labels=(), kind='mux', ty=None):
        f, s = C[kind]
        if point == 'right':
            pts = f'{x},{y} {x+w},{y+inset} {x+w},{y+h-inset} {x},{y+h}'
        else:
            pts = f'{x},{y+inset} {x+w},{y} {x+w},{y+h} {x},{y+h-inset}'
        self.o.append(f'<polygon points="{pts}" fill="{f}" stroke="{s}" stroke-width="2"/>')
        if title:
            for i, t in enumerate(title.split('\n')):
                cy = (y + h / 2) if ty is None else ty
                self.text(x + w / 2, cy + i * 15 - (len(title.split('\n')) - 1) * 7, t, 12, 'middle', s, 'bold')
        for (ly, l) in labels:
            lx = x + 13 if point == 'right' else x + w - 13
            self.text(lx, ly - 5, l, 10, 'start' if point == 'right' else 'end', '#1b5e20', 'bold')

    def wire(self, pts, label=None, lp=None, anchor='start', arrow=True, both=False, bus=False, color='#37474f', lcolor='#0d47a1', lsize=11):
        d = ' '.join(f'{x},{y}' for x, y in pts)
        me = ' marker-end="url(#a)"' if arrow else ''
        ms = ' marker-start="url(#a)"' if both else ''
        sw = 3 if bus else 1.6
        self.o.append(f'<polyline points="{d}" fill="none" stroke="{color}" stroke-width="{sw}"{me}{ms}/>')
        if label:
            if lp is None:
                (x1, y1), (x2, y2) = pts[0], pts[1]
                lp = ((x1 + x2) / 2, (y1 + y2) / 2 - 5)
                anchor = 'middle'
            self.text(lp[0], lp[1], label, lsize, anchor, lcolor)

    def dot(self, x, y):
        self.o.append(f'<circle cx="{x}" cy="{y}" r="4" fill="#37474f"/>')

    def orgate(self, cx, cy, r, s='OR'):
        self.o.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#ffffff" stroke="#37474f" stroke-width="2"/>')
        self.text(cx, cy + 4, s, 11, 'middle', '#37474f', 'bold')

    def note(self, x, y, lines, size=11, color='#546e7a'):
        for i, l in enumerate(lines):
            self.text(x, y + i * (size + 5), l, size, 'start', color)

    def save(self, name):
        self.o.append('</g></svg>')
        with open(os.path.join(OUT, name), 'w', encoding='utf-8') as fp:
            fp.write('\n'.join(self.o))


# =====================================================================================
# 1. Top
# =====================================================================================
s = Svg(1640, 990, 'merge_final_top — 전체 블록 다이어그램',
        '굵은 선 = 버스 · 점(●) = 분기 · 회색 화살표 칸 = 보드 핀')

# 보드 입력 핀
s.pin(20, 70, 110, 28, 'rst')
s.pin(20, 210, 110, 28, 'btn_R/L/U/D')
s.pin(20, 290, 110, 28, 'rx')
s.pin(20, 330, 110, 28, 'tx', out=True)
s.pin(20, 466, 110, 28, 'sw0 ~ sw6')
s.pin(20, 846, 110, 28, 'dist_led_sw15')
s.pin(20, 876, 110, 28, 'echo')
s.pin(20, 906, 110, 28, 'trig', out=True)
s.pin(20, 936, 110, 28, 'dht11_io', out=True)

# 리셋 · 클럭 · 디바운서
s.box(170, 60, 150, 48, 'U_RESET_SYNC', ['reset_sync'], 'ip', tsize=12)
s.wire([(130, 84), (170, 84)])
s.wire([(320, 84), (360, 84)], arrow=True)
s.text(366, 88, 'w_rst → 모든 모듈의 i_rst', 11, color='#0d47a1')
s.box(170, 130, 150, 48, 'U_CLK_GEN_4KHZ', ['clock_tick_generator'], 'ip', tsize=12)
s.box(170, 196, 150, 56, 'U_BD_R/L/U/D', ['btn_debounce x4'], 'ip', tsize=12)
s.wire([(245, 178), (245, 196)])
s.wire([(130, 224), (170, 224)])
s.wire([(320, 154), (345, 154), (345, 120), (1385, 120), (1385, 420)], 'w_clk_4khz (4 kHz)', (700, 114), 'middle')

# UART
s.box(380, 270, 200, 140, 'U_UART', ['uart_top', 'RX · FIFO · DECODER', 'UART_CONTROLLER', 'SENDER · FIFO · TX'], 'uart')
s.wire([(130, 304), (380, 304)], 'i_rx', (300, 299), 'middle')
s.wire([(380, 344), (130, 344)], 'o_tx', (300, 339), 'middle')

# 물리 버튼 → UART / OR
s.wire([(320, 224), (609, 224)], 'w_phy_btn_* (물리)', (470, 218), 'middle', bus=True)
s.dot(350, 224)
s.wire([(350, 224), (350, 380), (380, 380)], 'i_btn_*', (283, 376), 'start')
s.orgate(625, 224, 16)
s.wire([(580, 300), (625, 300), (625, 240)], 'o_uart_btn_*', (585, 318), 'start')
s.wire([(641, 224), (680, 224)], bus=True)
s.box(680, 190, 140, 68, '버튼 게이팅', ['w_btn & w_mode_*', '지금 화면에만'], 'gate', tsize=13)

# 모드 선택 MUX
s.mux(420, 450, 70, 120, 20, '', 'right', [(480, '0 스위치'), (540, '1 UART')])
s.text(455, 590, '모드 선택', 12, 'middle', '#1b5e20', 'bold')
s.wire([(130, 480), (420, 480)], 'w_sw_ctrl_bit[6:0]', (200, 474), 'start', bus=True)
s.wire([(400, 410), (400, 540), (420, 540)], 'o_module_control_bit', (300, 560), 'start', bus=True)
s.wire([(455, 410), (455, 460)], 'o_uart_mode', (460, 436), 'start')
s.wire([(490, 510), (600, 510)], 'w_ctrl_bit[6:0]', (545, 504), 'middle', bus=True, arrow=False)
s.dot(600, 510)
s.wire([(600, 510), (600, 272), (750, 272), (750, 258)], 'w_mode_wts / dist / dht', (612, 288), 'start')
s.wire([(600, 510), (815, 510), (815, 340), (920, 340)], '[4:0] 스위치 기능', (700, 526), 'middle', bus=True)
s.wire([(600, 510), (600, 690), (1340, 690), (1340, 720)], None, bus=True)
s.text(610, 684, 'w_disp_sel = w_ctrl_bit[6:5]  (0 WTS · 1 거리 · 2 온습도)', 11, color='#0d47a1')
s.dot(1195, 690)
s.wire([(1195, 690), (1195, 655)])

# 버튼 → 모듈
s.wire([(820, 224), (850, 224), (850, 595)], bus=True, arrow=False)
s.wire([(850, 290), (920, 290)], 'R/L/U/D', (856, 284), 'start')
s.wire([(850, 452), (920, 452)], 'R / U', (856, 446), 'start')
s.wire([(850, 595), (920, 595)], 'R / U', (856, 589), 'start')
s.dot(850, 290); s.dot(850, 452)

# 모듈
s.box(920, 250, 180, 130, 'U_WTS', ['wts_top', '스톱워치 · 시계 · 타이머'], 'wts')
s.box(920, 425, 180, 105, 'U_SR04', ['sr04_top', '초음파 거리'], 'sr04')
s.box(920, 560, 180, 100, 'U_DHT11', ['dht11_top', '온습도'], 'dht')

# 센서 핀
s.wire([(130, 860), (860, 860), (860, 470), (920, 470)])
s.wire([(130, 890), (872, 890), (872, 492), (920, 492)])
s.wire([(920, 512), (886, 512), (886, 920), (130, 920)])
s.wire([(920, 635), (900, 635), (900, 950), (130, 950)], both=True)

# FND 데이터 MUX → FND
s.mux(1165, 270, 60, 400, 30, 'FND\n데이터\nMUX', 'right', [(300, '0'), (470, '1'), (610, '2')], ty=390)
s.wire([(1100, 300), (1165, 300)], 'w_disp_*', (1132, 293), 'middle', bus=True, lsize=10)
s.wire([(1100, 470), (1165, 470)], 'x10 · err', (1132, 463), 'middle', bus=True, lsize=10)
s.wire([(1100, 610), (1165, 610)], 'data · dash', (1132, 603), 'middle', bus=True, lsize=10)
s.wire([(1225, 470), (1300, 470)], 'w_fnd_data', (1262, 463), 'middle', bus=True, lsize=10)
s.box(1300, 420, 170, 100, 'U_FND_CONTROLLER', ['SW2_FND_CONTROLLER', 'WTS + 거리 + 온습도'], 'fnd', tsize=12)
s.note(1302, 540, ['+ disp_mode · wt_cursor', '   sel_wt · set_sw2 (U_WTS)'], 10)
s.pin(1510, 436, 110, 28, 'fnd_com[3:0]', out=True)
s.pin(1510, 476, 110, 28, 'fnd_font[7:0]', out=True)
s.wire([(1470, 450), (1510, 450)])
s.wire([(1470, 490), (1510, 490)])

# LED
s.box(1300, 720, 170, 80, 'U_LED', ['led_output'], 'led')
s.note(1150, 816, ['← U_WTS : sel · tm_run · tm_alarm · lap · pm', '← U_SR04 o_led[9:0]  ·  U_DHT11 o_led[3:0]'], 10)
s.wire([(1270, 760), (1300, 760)])
s.text(1266, 764, 'LED 신호', 10, 'end', '#0d47a1')
s.pin(1510, 746, 110, 28, 'led[15:0]', out=True)
s.wire([(1470, 760), (1510, 760)])

# 전송 데이터 MUX → UART
s.mux(640, 720, 56, 110, 20, '', 'left', [(745, '0~2'), (785, '3'), (815, '4')])
s.text(668, 850, '전송 데이터 MUX', 11, 'middle', '#1b5e20', 'bold')
s.wire([(845, 745), (696, 745)], '← U_WTS *_time', (708, 739), 'start', lsize=10)
s.wire([(845, 785), (696, 785)], '← U_SR04 distance', (708, 779), 'start', lsize=10)
s.wire([(845, 815), (696, 815)], '← U_DHT11 hum·temp', (708, 809), 'start', lsize=10)
s.wire([(640, 775), (540, 775), (540, 410)], 'w_send_data[23:0]', (534, 760), 'end', bus=True)
s.wire([(562, 410), (562, 705), (668, 705), (668, 729)], 'o_send_sel', (572, 722), 'start')
s.save('01_top.svg')

# =====================================================================================
# 2. UART
# =====================================================================================
s = Svg(1460, 560, 'U_UART (uart_top) — 수신 · 해석 · 제어 · 전송', 'RX 와 TX 는 baud tick 하나를 같이 씀')
s.pin(20, 86, 110, 28, 'i_rx')
s.pin(20, 426, 110, 28, 'o_tx', out=True)
s.box(160, 70, 150, 60, 'U_UART_RX', ['uart_rx'], 'uart', tsize=13)
s.box(370, 70, 150, 60, 'U_FIFO_RX', ['fifo (8 칸)'], 'ip', tsize=13)
s.box(580, 70, 170, 60, 'U_ASCII_DECODER', ['UART_ASCII_DECODER'], 'dht', tsize=12)
s.box(160, 230, 150, 54, 'U_BAUD_TICK_GEN', ['9600 x 16'], 'ip', tsize=12)
s.box(160, 410, 150, 60, 'U_UART_TX', ['uart_tx'], 'uart', tsize=13)
s.box(370, 410, 150, 60, 'U_FIFO_TX', ['fifo (64 칸)'], 'ip', tsize=13)
s.box(580, 410, 170, 60, 'U_ASCII_SENDER', ['uart_sender', '+ sender_char_mux'], 'dht', tsize=12)
s.box(820, 60, 260, 330, 'U_CONTROL', ['UART_CONTROLLER', '', 'mode FSM : /mod /set /off', 'auto FSM : /auto /get', 'error : 최우선 전송', 'send pend : 바쁠 때 저장', 'btn : 물리 먼저, /btn 나중'], 'uart', tsize=15)

s.wire([(130, 100), (160, 100)])
s.wire([(310, 100), (370, 100)], 'rx_data·done', (340, 94), 'middle', lsize=10)
s.wire([(520, 88), (580, 88)], 'pop_data', (550, 82), 'middle', lsize=10)
s.wire([(580, 115), (520, 115)], 'pop', (550, 128), 'middle', lsize=10)
s.wire([(750, 100), (820, 100)], 'cmd', (785, 94), 'middle', lsize=10)
s.note(585, 155, ['handshake · error · get · btn', 'mode · auto · set · off · ascii[39:0]'], 10, '#0d47a1')
s.wire([(235, 230), (235, 130)], 'b_tick', (240, 190), 'start', lsize=10)
s.wire([(235, 284), (235, 410)], 'b_tick', (240, 350), 'start', lsize=10)
s.wire([(920, 390), (920, 430), (750, 430)], 'go · sel · data', (760, 424), 'start', lsize=10)
s.wire([(750, 455), (960, 455), (960, 390)], 'send_busy', (760, 470), 'start', lsize=10)
s.wire([(580, 430), (520, 430)], 'push', (550, 424), 'middle', lsize=10)
s.wire([(520, 455), (580, 455)], 'full', (550, 470), 'middle', lsize=10)
s.wire([(370, 430), (310, 430)], 'pop_data', (340, 424), 'middle', lsize=10)
s.wire([(310, 455), (370, 455)], '~busy=pop', (340, 470), 'middle', lsize=10)
s.wire([(160, 440), (130, 440)])

s.pin(1200, 86, 230, 28, 'o_module_control_bit[6:0]', out=True)
s.pin(1200, 126, 230, 28, 'o_uart_mode', out=True)
s.pin(1200, 176, 230, 28, 'o_uart_btn_R/L/U/D', out=True)
s.pin(1200, 226, 230, 28, 'o_send_sel[2:0]', out=True)
s.pin(1200, 276, 230, 28, 'i_send_data[23:0]')
s.pin(1200, 326, 230, 28, 'i_btn_R/L/U/D (물리)')
for y in (100, 140, 190, 240):
    s.wire([(1080, y), (1200, y)])
s.wire([(1200, 290), (1080, 290)])
s.wire([(1200, 340), (1080, 340)])
s.save('02_uart.svg')

# =====================================================================================
# 3. WTS
# =====================================================================================
s = Svg(1560, 600, 'U_WTS (wts_top) — 스톱워치 · 시계 · 타이머', '원래 stopwatch_watch 에서 디바운서 · FND · LED 를 Top 으로 뺀 것')
s.pin(20, 106, 120, 28, 'i_btn_R/L/U/D')
s.pin(20, 166, 120, 28, 'i_*_sw0~4')
s.box(170, 90, 140, 120, '버튼 게이팅', ['w_sel_tm = sw4', 'w_sel_sw = ~sw4 & sw0', 'w_sel_wt = ~sw4 & ~sw0'], 'gate', tsize=13, lsize=10)
s.wire([(140, 120), (170, 120)])
s.wire([(140, 180), (170, 180)])
s.wire([(310, 150), (340, 150), (340, 460)], bus=True, arrow=False)
s.wire([(340, 90), (380, 90)], 'sw_btn', (344, 84), 'start', lsize=10)
s.wire([(340, 280), (380, 280)], 'wt_btn', (344, 274), 'start', lsize=10)
s.wire([(340, 460), (380, 460)], 'tm_btn', (344, 454), 'start', lsize=10)
s.wire([(340, 150), (340, 90)], arrow=False, bus=True)
s.dot(340, 150); s.dot(340, 280)

# 스톱워치
s.box(380, 60, 190, 60, 'U_STOPWATCH_CONTROL_UNIT', ['R 시작/정지 · L 지우기 · U 업다운'], 'wts', tsize=11, lsize=10)
s.box(630, 60, 170, 60, 'U_TICK_GEN_SW', ['tick_gen_100hz_run'], 'ip', tsize=12)
s.box(860, 60, 200, 60, 'U_STOPWATCH_DATAPATH', ['+ lap_controller (D 랩)'], 'wts', tsize=11, lsize=10)
s.wire([(570, 90), (630, 90)], 'run·clear', (600, 84), 'middle', lsize=10)
s.wire([(800, 90), (860, 90)], '10 ms', (830, 84), 'middle', lsize=10)
s.wire([(475, 60), (475, 44), (960, 44), (960, 60)], 'clear · down', (700, 38), 'middle', lsize=10)

# 시계
s.box(380, 250, 190, 60, 'U_WATCH_CONTROL_UNIT', ['R/L 커서 · U/D ± · set_sw2'], 'wts', tsize=11, lsize=10)
s.box(630, 340, 170, 54, 'U_TICK_GEN_100HZ', ['항상 10 ms'], 'ip', tsize=12)
s.box(860, 250, 200, 60, 'U_WATCH_DATAPATH', ['시 · 분 · 초 · 1/100초'], 'wts', tsize=12, lsize=10)
s.box(1100, 250, 140, 60, 'U_HOUR_12_24', ['hour24_sw3'], 'wts', tsize=12, lsize=10)
s.wire([(570, 280), (860, 280)], 'cursor · up · down', (715, 274), 'middle', lsize=10)
s.wire([(800, 367), (960, 367), (960, 310)], '10 ms', (880, 361), 'middle', lsize=10)
s.wire([(1060, 280), (1100, 280)])

# 타이머
s.box(380, 430, 190, 60, 'U_TIMER_CONTROL_UNIT', ['R +1분 · L 시작/취소 · U +10초 · D +10분'], 'wts', tsize=11, lsize=9)
s.box(630, 430, 170, 60, 'U_TICK_GEN_TM', ['tick_gen_100hz_run'], 'ip', tsize=12)
s.box(860, 430, 200, 60, 'U_TIMER_DATAPATH', ['분 · 초 · 1/100초'], 'wts', tsize=12, lsize=10)
s.wire([(570, 460), (630, 460)], 'run·clear', (600, 454), 'middle', lsize=10)
s.wire([(800, 460), (860, 460)], '10 ms', (830, 454), 'middle', lsize=10)
s.wire([(475, 430), (475, 414), (960, 414), (960, 430)], 'run · clear · add · amount', (700, 408), 'middle', lsize=10)
s.wire([(960, 490), (960, 520), (475, 520), (475, 490)], 'tm_zero', (700, 514), 'middle', lsize=10)
s.text(475, 545, '알람 중 : 아무 버튼 = 알람 끄기', 10, 'middle', '#546e7a')

# 화면 MUX
s.mux(1290, 60, 60, 450, 40, '화면\nMUX', 'right', [(90, 'SW'), (280, 'WT'), (460, 'TM')], ty=390)
s.wire([(1060, 90), (1290, 90)], 'sw msec·sec·min·hour', (1070, 84), 'start', bus=True, lsize=10)
s.wire([(1240, 280), (1290, 280)], bus=True)
s.wire([(1060, 300), (1080, 300), (1080, 330), (1270, 330), (1270, 300), (1290, 300)], 'wt msec·sec·min', (1100, 346), 'start', bus=True, lsize=10)
s.wire([(1060, 460), (1290, 460)], 'tm min·sec·msec (분.초)', (1070, 454), 'start', bus=True, lsize=10)
s.wire([(1320, 535), (1320, 480)])
s.text(1320, 552, 'timer_sw4 > mode_sw0', 11, 'middle', '#0d47a1')
s.pin(1390, 256, 160, 28, 'o_disp_* · mode', out=True)
s.wire([(1350, 270), (1390, 270)], bus=True)
s.note(1100, 575, ['UART 전송용 : o_sw_time · o_wt_time · o_tm_time  {hour5, min6, sec6, cs7}'], 11, '#0d47a1')
s.save('03_wts.svg')

# =====================================================================================
# 4. SR04
# =====================================================================================
s = Svg(1420, 420, 'U_SR04 (sr04_top) — 초음파 거리', 'R = 1회 측정 · U = 자동 측정 켜기/끄기 (DHT11 과 같은 동작)')
s.pin(20, 81, 110, 28, 'i_btn_R')
s.pin(20, 131, 110, 28, 'i_btn_U')
s.pin(20, 266, 110, 28, 'i_echo')
s.pin(20, 350, 110, 28, 'i_led_sw')
s.box(170, 70, 160, 100, 'U_MODE', ['sr04_mode_ctrl', 'U → auto 토글', 'R → start'], 'sr04', tsize=13, lsize=10)
s.wire([(130, 95), (170, 95)])
s.wire([(130, 145), (170, 145)])
s.box(400, 40, 560, 290, 'U_SR04 (sr04_core)', [], 'sr04', dashed=True, tsize=12, title_top=18)
s.box(430, 250, 150, 60, 'U_ECHO_SYNC', ['synchronizer (IP)'], 'ip', tsize=12)
s.box(430, 160, 150, 60, 'U_TICK_GEN_US', ['tick_gen_us (IP)'], 'ip', tsize=12)
s.box(680, 80, 250, 220, 'U_SR04_CNTL', ['sr04_controller FSM', '', 'IDLE → START (trig 11us)', '→ WAIT (echo↑)', '→ DIST (echo 길이)', '→ STOP (10 ms, 주기 60 ms)', '→ IDLE'], 'sr04', tsize=14, lsize=10)
s.wire([(330, 105), (680, 105)], 'start', (500, 99), 'middle')
s.wire([(330, 140), (680, 140)], 'auto_en  (w_start = start | auto & ~busy)', (440, 134), 'start', lsize=10)
s.wire([(130, 280), (430, 280)])
s.wire([(580, 280), (680, 280)], 'echo (동기화)', (630, 274), 'middle', lsize=10)
s.wire([(580, 182), (680, 182)], 'us_tick', (630, 176), 'middle', lsize=10)
s.wire([(680, 205), (580, 205)], 'en · clr', (630, 218), 'middle', lsize=10)
s.pin(1230, 82, 170, 28, 'o_trig', out=True)
s.wire([(930, 96), (1230, 96)])
s.pin(1230, 132, 170, 28, 'o_distance · x10', out=True)
s.wire([(930, 146), (1230, 146)], bus=True)
s.box(1010, 200, 170, 100, 'U_LED', ['sr04_led_bar', 'LD0~7 막대 · LD8 · LD9'], 'sr04', tsize=13, lsize=10)
s.wire([(930, 240), (1010, 240)], 'x10·status·done', (970, 234), 'middle', lsize=9)
s.wire([(130, 364), (1095, 364), (1095, 300)])
s.pin(1230, 216, 170, 28, 'o_led[9:0]', out=True)
s.pin(1230, 256, 170, 28, 'o_err (FND ----)', out=True)
s.wire([(1180, 230), (1230, 230)], bus=True)
s.wire([(1180, 270), (1230, 270)])
s.save('04_sr04.svg')

# =====================================================================================
# 5. DHT11
# =====================================================================================
s = Svg(1440, 460, 'U_DHT11 (dht11_top) — 온습도', 'R = 1회 측정 · U = 자동 측정 켜기/끄기 (2 s 마다)', dy=30)
s.pin(20, 71, 110, 28, 'i_btn_U')
s.pin(20, 170, 110, 28, 'i_btn_R')
s.pin(20, 360, 110, 28, 'io_dht11', out=True)
s.box(170, 60, 160, 50, 'c_auto_mode', ['U 누를 때마다 토글'], 'dht', tsize=12, lsize=10)
s.wire([(130, 85), (170, 85)])
s.box(400, 40, 520, 260, 'U_DHT11_CORE (dht11_core)', [], 'dht', dashed=True, tsize=12, title_top=18)
s.box(430, 70, 170, 90, '요청 관리', ['부팅 1 s 대기', '측정 간격 2 s', '간격 안 요청은 기억'], 'dht', tsize=12, lsize=10)
s.box(430, 200, 170, 60, 'U_TICK_1US', ['tick_gen_us (IP)'], 'ip', tsize=12)
s.box(660, 70, 230, 200, 'U_DHT11_CTRL', ['dht11_controller FSM', '', 'START (LOW 18 ms) → WAIT', '→ SYNC_L → SYNC_H', '→ {DATA_SYNC → DATA_BIT', '    → BIT_DEC} x 40', '→ STOP → IDLE'], 'dht', tsize=14, lsize=10)
s.wire([(330, 95), (430, 95)], 'auto_en', (380, 89), 'middle', lsize=10)
s.wire([(130, 184), (390, 184), (390, 135), (430, 135)], 'start', (260, 178), 'middle', lsize=10)
s.wire([(600, 115), (660, 115)], 'start', (630, 109), 'middle', lsize=10)
s.wire([(600, 222), (660, 222)], 'us_tick', (630, 216), 'middle', lsize=10)
s.wire([(660, 245), (600, 245)], 'en·clr', (630, 258), 'middle', lsize=10)
s.box(220, 335, 160, 70, '3상태 버퍼', ['oe ? 0 : Z', '(풀업이 HIGH)'], 'ip', tsize=12, lsize=10)
s.wire([(220, 374), (130, 374)], both=True)
s.wire([(760, 270), (760, 355), (380, 355)], 'o_dht_oe', (560, 349), 'middle', lsize=10)
s.wire([(380, 390), (820, 390), (820, 270)], 'w_dht_in (안에서 2-FF 동기화)', (560, 405), 'middle', lsize=10)
s.box(990, 80, 180, 120, 'U_DHT11_MGR', ['dht11_manager', 'FND = 습도x100 + 온도', '첫 측정 전·오류 = ----'], 'dht', tsize=13, lsize=10)
s.wire([(890, 130), (990, 130)], 'hum·temp·valid·done', (940, 124), 'middle', lsize=9)
s.pin(1230, 86, 190, 28, 'o_fnd_data[13:0]', out=True)
s.pin(1230, 126, 190, 28, 'o_dashes', out=True)
s.pin(1230, 166, 190, 28, 'o_led[2:0]', out=True)
for y in (100, 140, 180):
    s.wire([(1170, y), (1230, y)])
s.pin(1230, 236, 190, 28, 'o_humidity · temp', out=True)
s.pin(1230, 276, 190, 28, 'o_valid·status·done', out=True)
s.wire([(890, 250), (1230, 250)], bus=True)
s.wire([(890, 262), (950, 262), (950, 290), (1230, 290)])
s.pin(1230, 30, 190, 28, 'o_led[3] (자동 중)', out=True)
s.wire([(250, 60), (250, 44), (1230, 44)])
s.save('05_dht11.svg')

# =====================================================================================
# 6. FND
# =====================================================================================
s = Svg(1460, 600, 'U_FND_CONTROLLER (SW2_FND_CONTROLLER) — WTS 기본 + 거리 · 온습도',
        '① 디코더로 나누고 → ② 모듈별로 4자리 + 점을 만들고 → ③ 3:1 MUX 로 골라 fnd_decoder 로')
s.pin(20, 96, 130, 28, 'i_disp_data[24:0]')
s.pin(20, 446, 130, 28, 'i_clk_4khz')
s.pin(20, 526, 130, 28, 'i_disp_sel[1:0]')
s.box(180, 70, 110, 330, '① 디코더', ['(demux)', '', 'sel 0 → WTS', 'sel 1 → 거리', 'sel 2 → 온습도', '', '고르지 않은', '쪽은 0'], 'fnd', tsize=13, lsize=10)
s.wire([(150, 110), (180, 110)], bus=True)
s.wire([(235, 540), (235, 400)])
s.dot(235, 540)
s.wire([(150, 540), (1000, 540), (1000, 416)], bus=True)

# WTS 경로
s.box(340, 60, 560, 160, 'WTS 경로 (원래 SW2_FND_CONTROLLER 그대로)', [], 'fnd', dashed=True, tsize=12, title_top=18)
s.box(360, 90, 120, 100, 'U_MSEC/SEC', ['U_MIN/HOUR', 'digit_splitter', '(10진 2자리)'], 'ip', tsize=11, lsize=10)
s.box(510, 90, 130, 100, 'U_ANODE_', ['CHOICE_TO_MUX2', '설정 커서 점멸', '(시.분 쪽)'], 'wts', tsize=11, lsize=10)
s.box(670, 90, 110, 100, 'U_SEC_MUXER', ['U_MIN_MUXER', 'mux_8x1', 'scan 6 = 점'], 'mux', tsize=11, lsize=10)
s.mux(810, 105, 50, 70, 12, '2:1', 'right')
s.wire([(480, 140), (510, 140)])
s.wire([(640, 140), (670, 140)])
s.wire([(780, 140), (810, 140)])
s.text(835, 200, 'disp_mode', 10, 'middle', '#0d47a1')
s.pin(360, 236, 300, 26, 'i_disp_mode · i_wt_cursor · i_sel_wt · i_set_sw2')
s.wire([(660, 249), (700, 249), (700, 220)])
s.wire([(290, 140), (360, 140)], 'WTS', (325, 134), 'middle', lsize=10, bus=True)

# 거리 / 온습도
s.box(340, 290, 250, 56, '② U_FND_DIST', ['fnd_dist : "352.7" (AN1 점) / "----"'], 'sr04', tsize=12, lsize=10)
s.box(340, 360, 250, 56, '② U_FND_DHT', ['fnd_dht : "55.24" (AN2 점) / "----"'], 'dht', tsize=12, lsize=10)
s.wire([(290, 318), (340, 318)], 'DIST', (315, 312), 'middle', lsize=10, bus=True)
s.wire([(290, 388), (340, 388)], 'DHT', (315, 382), 'middle', lsize=10, bus=True)

# 스캔 카운터
s.box(340, 440, 170, 50, 'U_COUNTER8', ['scan_sel 0~7 (4 kHz)'], 'ip', tsize=12, lsize=10)
s.wire([(150, 460), (340, 460)])
s.wire([(510, 465), (640, 465), (640, 270), (725, 270), (725, 190)], 'scan_sel', (646, 430), 'start', lsize=10)
s.dot(640, 465); s.dot(640, 318); s.dot(640, 388)
s.wire([(640, 318), (590, 318)])
s.wire([(640, 388), (590, 388)])

# 3:1 MUX
s.mux(970, 90, 60, 340, 30, '③\n3:1\nMUX', 'right', [(140, '0'), (318, '1'), (388, '2')], ty=240)
s.wire([(860, 140), (970, 140)], 'w_wts_bcd', (915, 134), 'middle', lsize=10)
s.wire([(590, 305), (900, 305), (900, 318), (970, 318)], 'w_dist_bcd', (790, 299), 'middle', lsize=10)
s.wire([(590, 375), (900, 375), (900, 388), (970, 388)], 'w_dht_bcd', (790, 369), 'middle', lsize=10)
s.box(1080, 210, 150, 60, 'U_FND_DEC', ['fnd_decoder', '4\'hc = "-"'], 'ip', tsize=13, lsize=10)
s.wire([(1030, 240), (1080, 240)], 'w_bcd', (1055, 234), 'middle', lsize=10)
s.box(1080, 440, 150, 50, 'U_DECODER', ['decoder_2x4'], 'ip', tsize=13, lsize=10)
s.wire([(640, 465), (640, 500), (1060, 500), (1060, 465), (1080, 465)], 'scan_sel[1:0]', (700, 494), 'start', lsize=10)
s.pin(1280, 226, 160, 28, 'o_fnd_font[7:0]', out=True)
s.pin(1280, 451, 160, 28, 'o_fnd_com[3:0]', out=True)
s.wire([(1230, 240), (1280, 240)])
s.wire([(1230, 465), (1280, 465)])
s.save('06_fnd.svg')

# =====================================================================================
# 7. LED
# =====================================================================================
s = Svg(1060, 440, 'U_LED (led_output) — 화면별 LED', '타이머 알람이면 어느 화면이든 16개 전부 0.5 초 점멸')
s.pin(20, 76, 150, 28, 'WTS 신호들')
s.pin(20, 186, 150, 28, 'i_sr04_led[9:0]')
s.pin(20, 236, 150, 28, 'i_dht_led[3:0]')
s.pin(20, 316, 150, 28, 'i_wt_msec[6:0]')
s.pin(20, 376, 150, 28, 'i_tm_alarm')
s.pin(20, 140, 150, 28, 'i_disp_sel[1:0]')
s.box(210, 60, 200, 60, 'w_wts_led', ['원래 WTS LED (0~7, 15)'], 'wts', tsize=12, lsize=10)
s.wire([(170, 90), (210, 90)], bus=True)
s.mux(470, 60, 60, 230, 30, '3:1', 'right', [(90, '0'), (200, '1'), (250, '2')])
s.wire([(410, 90), (470, 90)], bus=True)
s.wire([(170, 200), (470, 200)], '{6\'d0, sr04}', (300, 194), 'middle', lsize=10, bus=True)
s.wire([(170, 250), (470, 250)], '{12\'d0, dht}', (300, 244), 'middle', lsize=10, bus=True)
s.wire([(170, 154), (440, 154), (440, 300), (500, 300), (500, 276)])
s.box(210, 300, 200, 60, 'w_alarm_blink', ['wt_msec >= 50 (0.5 초)'], 'ip', tsize=12, lsize=10)
s.wire([(170, 330), (210, 330)])
s.mux(650, 110, 50, 200, 25, '2:1', 'right', [(175, '0'), (270, '1')])
s.wire([(530, 175), (650, 175)], 'w_mode_led', (590, 169), 'middle', lsize=10, bus=True)
s.wire([(410, 330), (600, 330), (600, 270), (650, 270)], '{16{blink}}', (605, 345), 'start', lsize=10, bus=True)
s.wire([(170, 390), (675, 390), (675, 297)], 'tm_alarm', (500, 384), 'middle', lsize=10)
s.pin(760, 196, 140, 28, 'o_led[15:0]', out=True)
s.wire([(700, 210), (760, 210)], bus=True)
s.save('07_led.svg')
print('ok')
