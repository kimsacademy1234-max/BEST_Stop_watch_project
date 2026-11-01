# Top 시뮬레이션 파형 장표 (wave_img/*.png) 를 블록도 덱 뒤에 붙임 — reference.pptx (시계 시뮬레이션 장) 형식
# 사용 : python make_wave_slides.py merge_final_block_diagram.pptx [out.pptx]
#   - out 을 안 주면 입력 파일에 그대로 저장
#   - 다시 돌려도 됨 : 이전에 붙인 파형 장 (제목 이름 "wave:<ID>") 은 지우고 새로 붙임
#   - 형식 (reference.pptx) : 판별 칩 + 결론 상자 / 파형 위 노란 이름표 "1. …" · 빨간 세로선 · 빨간 타원 · 빨간 둥근 상자 ·
#                            Name 열 신호 이름 빨간 테두리 / 오른쪽에 FND 7 세그먼트 그림 · 단계 설명
#   - 파형 위 표시 좌표 = 캡처 png 의 픽셀 좌표 (P1-A · P2-A 는 가로 2000 으로 줄여 잰 값 → disp_w=2000)
#   - 캡처 안내 : top_파형_캡처_안내.md (장면 P1 ~ P6, 캡처 ID)
import os
import sys
from PIL import Image, ImageFont
from pptx import Presentation
from pptx.util import Inches
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE

from make_block_diagram import text, text_runs, shape, set_text, seg, HEADER, FONT_TITLE, DOM

HERE = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(HERE, "wave_img")

ACC = DOM["uart"][0]        # 2C7A7B  판별 칩 · 머리말 · 결론 강조 글자
ACC_D = "1D5354"            # 결론 칩
ACC_L = DOM["uart"][1]      # E6F4F3  결론 상자
RED = "FF0000"              # 파형 위 빨간 표시 (reference 와 같은 색)
YEL = "FFC000"              # 노란 이름표 · 번호
SEG_ON, SEG_OFF, SEG_BG = "FF2A2A", "2A2A2A", "0B0B0B"   # FND 그림 (reference FND 그룹 색)

_KFONT = None
for _p in ("/mnt/c/Windows/Fonts/malgunbd.ttf", "C:/Windows/Fonts/malgunbd.ttf"):
    if os.path.exists(_p):
        _KFONT = _p
        break


def text_w(s, pt):
    """맑은 고딕 굵게 글자 폭 (inch) — 노란 이름표 크기 맞추기"""
    if _KFONT:
        f = ImageFont.truetype(_KFONT, 200)
        return f.getlength(s) / 200 * pt / 72
    return sum(0.0105 if ord(c) < 128 else 0.0145 for c in s) * pt


# ---------------------------------------------------------------- 그리기 도구
class Pic:
    """그림 위 좌표 (캡처 픽셀) → 슬라이드 inch"""

    def __init__(self, s, path, x, y, h, crop_h=None, disp_w=None):
        iw, ih = Image.open(path).size
        ch = crop_h or ih
        self.w = h * iw / ch
        self.h = h
        self.x, self.y = x, y
        pic = s.shapes.add_picture(path, Inches(x), Inches(y), Inches(self.w), Inches(h))
        pic.name = "파형"
        if crop_h and crop_h < ih:
            pic.crop_bottom = 1 - crop_h / ih
        dw = disp_w or iw                       # 좌표를 잰 그림 폭 (줄여 본 값이면 2000)
        self.k = self.w / dw                    # inch / px  (가로 · 세로 같은 비율)
        self.s = s

    def X(self, px):
        return self.x + px * self.k

    def Y(self, py):
        return self.y + py * self.k


def label(s, x, y, t, pt=13.5, h=0.30, name="이름표"):
    w = text_w(t, pt) + 0.16
    tb = text(s, x, y, w, h, t, pt, "000000", bold=True, align="c", name=name)
    tb.fill.solid()
    tb.fill.fore_color.rgb = RGBColor.from_string(YEL)
    return tb


def wlabel(p, xp, yp, t, pt=13.5):
    """그림 위 노란 이름표 : (xp, yp) = 왼쪽 · 세로 가운데 (px)"""
    h = 0.30
    return label(p.s, p.X(xp), p.Y(yp) - h / 2, t, pt, h)


def vline(p, xp, y1, y2, color=RED, w=1.75):
    seg(p.s, p.X(xp), p.Y(y1), p.X(xp), p.Y(y2), color, w)


def hline(p, x1, x2, yp, color=RED, w=1.75):
    seg(p.s, p.X(x1), p.Y(yp), p.X(x2), p.Y(yp), color, w)


def oval(p, cx, cy, w, h):
    shape(p.s, MSO_SHAPE.OVAL, p.X(cx - w / 2), p.Y(cy - h / 2), w * p.k, h * p.k, None, RED, 2.0, name="빨간 타원")


def rbox(p, x1, y1, x2, y2, name="빨간 상자"):
    b = shape(p.s, MSO_SHAPE.ROUNDED_RECTANGLE, p.X(x1), p.Y(y1), (x2 - x1) * p.k, (y2 - y1) * p.k, None, RED, 2.0,
              name=name)
    b.adjustments[0] = 0.3
    return b


def namebox(p, x1, y1, x2, y2):
    rbox(p, x1, y1, x2, y2, name="신호 이름")


def ycircle(s, x, y, n, d=0.38, pt=15):
    c = shape(s, MSO_SHAPE.OVAL, x, y, d, d, YEL, None, name=f"번호 {n}")
    set_text(c, [str(n)], "000000", [pt])
    return c


def wcircle(p, cx, cy, n, d=0.36):
    ycircle(p.s, p.X(cx) - d / 2, p.Y(cy) - d / 2, n, d, 14)


# 7 세그먼트 : a b c d e f g
SEGS = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc",
        "8": "abcdefg", "9": "abfgcd", "-": "g", " ": "", "E": "afged", "r": "eg"}


def fnd(s, x, y, w, digits, dot=None, mark=None, name="FND"):
    """digits = 4 글자 (왼쪽 AN3 → 오른쪽 AN0), dot = 점 찍을 자리 (0 = 맨 왼쪽), mark = 노란 테두리 자리"""
    h = w * 0.37
    bg = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, x, y, w, h, SEG_BG, None, name=name)
    bg.adjustments[0] = 0.18
    pad = w * 0.06
    cw = (w - 2 * pad) / 4                     # 한 자리 칸
    dw, dh = cw * 0.62, h * 0.70               # 숫자 크기
    t = dw * 0.17
    oy = y + (h - dh) / 2
    for i, ch in enumerate(digits):
        ox = x + pad + i * cw + (cw - dw) / 2 - cw * 0.06
        on = SEGS.get(ch, "")
        hv = (dh - 3 * t) / 2
        rects = {"a": (ox + t, oy, dw - 2 * t, t), "g": (ox + t, oy + t + hv, dw - 2 * t, t),
                 "d": (ox + t, oy + dh - t, dw - 2 * t, t),
                 "f": (ox, oy + t, t, hv), "b": (ox + dw - t, oy + t, t, hv),
                 "e": (ox, oy + 2 * t + hv, t, hv), "c": (ox + dw - t, oy + 2 * t + hv, t, hv)}
        for k, (rx, ry, rw, rh) in rects.items():
            shape(s, MSO_SHAPE.RECTANGLE, rx, ry, rw, rh, SEG_ON if k in on else SEG_OFF, None, name="세그먼트")
        if dot == i:
            shape(s, MSO_SHAPE.OVAL, ox + dw + t * 0.6, oy + dh - t, t, t, SEG_ON, None, name="점")
        if mark == i:
            m = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, ox - t * 1.2, oy - t * 0.9, dw + t * 2.4, dh + t * 1.8, None, YEL,
                      1.75, name="지금 자리")
            m.adjustments[0] = 0.2
    return h


def arrow(s, x1, y1, x2, y2, color="4A5568", w=2.5):
    seg(s, x1, y1, x2, y2, color, w, arrow=True)


def steps(s, x, y, w, rows, row_h=0.92, head_w=2.3, pt=15):
    """번호 · 굵은 머리 · 설명 줄 (번호 = 파형 위 이름표 번호)"""
    for i, (head, body) in enumerate(rows):
        yy = y + i * row_h
        ycircle(s, x, yy + 0.02, i + 1)
        text(s, x + 0.55, yy, head_w, 0.42, head, pt + 1, "262626", bold=True, name=f"단계 {i + 1} 머리")
        text(s, x + 0.55 + head_w, yy + 0.02, w - 0.55 - head_w, row_h - 0.1, body, pt, "404040", anchor="t",
             name=f"단계 {i + 1}")


def chain(s, x, y, blocks, bw=2.05, bh=0.95, gap=0.6, gaps=()):
    """블록 줄 : blocks = [(이름, 신호, dom)], gaps = 블록 사이 글자 (+20 ns …)"""
    for i, (nm, sig, dom) in enumerate(blocks):
        bx = x + i * (bw + gap)
        ln, lt = DOM[dom]
        b = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, bx, y, bw, bh, lt, ln, 1.75, name=f"블록 {nm}")
        set_text(b, [nm, sig], "1A202C", [13, 11.5])
        ycircle(s, bx - 0.16, y - 0.16, i + 1, 0.34, 13)
        if i < len(blocks) - 1:
            arrow(s, bx + bw + 0.06, y + bh / 2, bx + bw + gap - 0.06, y + bh / 2)
            if i < len(gaps):
                text(s, bx + bw - 0.2, y - 0.36, gap + 0.4, 0.3, gaps[i], 12, "C53030", bold=True, align="c")


# ---------------------------------------------------------------- 틀 (reference 판별 · 결론)
def frame(prs, section, title, judge, concl, page, tag):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    text(s, 13.6, 0.22, 6.0, 0.3, HEADER, 10.5, "8C8C8C", align="r")
    shape(s, MSO_SHAPE.OVAL, 0.92, 0.55, 0.14, 0.14, ACC, None, name="shape")
    text(s, 1.14, 0.44, 12.0, 0.34, section, 12.5, ACC, bold=True)
    t = text(s, 0.92, 0.78, 18.2, 0.72, title, 30, "262626", font=FONT_TITLE)
    t.name = "wave:" + tag
    two = len(judge) > 1
    jy = 1.79 if two else 1.55
    c = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, 0.92, jy, 1.15, 0.50, ACC, None, name="판별 칩")
    c.adjustments[0] = 0.3
    set_text(c, ["판별"], "FFFFFF", [16])
    text(s, 2.30, 1.56, 16.78, 0.96 if two else 0.48, judge, 20, "262626", name="판별 글")
    by = 2.66 if two else 2.18
    nl = len(concl)
    bh = 0.42 + 0.38 * nl
    b = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, 2.15, by, 16.93, bh, ACC_L, None, name="결론 상자")
    b.adjustments[0] = 0.3
    c = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, 0.92, by + (bh - 0.5) / 2, 1.15, 0.50, ACC_D, None, name="결론 칩")
    c.adjustments[0] = 0.3
    set_text(c, ["결론"], "FFFFFF", [16])
    for i, runs in enumerate(concl):          # runs = [(글자, 강조?)]
        text_runs(s, 2.40, by + 0.21 + i * 0.38, 16.6, 0.38,
                  [(r, ACC if k else "262626", bool(k)) for r, k in runs], 20, name=f"결론 {i + 1}")
    text(s, 18.2, 10.62, 0.9, 0.35, f"{page:02d}", 11, "8C8C8C", align="r")
    return s, by + bh + 0.22                  # 그림 시작 y


SEC1 = "03  Top · 시뮬레이션   ① 화면 제어  /mod"
SEC3 = "03  Top · 시뮬레이션   ③ 버튼  /btn"


# ---------------------------------------------------------------- 장별
def p1_a(prs, page):
    s, y0 = frame(prs, SEC1, "P1  /mod dist — 스위치에서 UART 로 화면 제어권 전환",
                  ["/mod 받기 전 · 후 화면 (disp_sel) 을 누가 정하는지", "마지막 글자를 받은 순간 화면 · FND 가 바뀌는지"],
                  [[("첫 /mod 뒤 ", 0), ("w_uart_mode 0 → 1", 1), (" → w_ctrl_bit = UART 값 ", 0), ("0100000", 1),
                    (" (거리 화면)", 0)],
                   [("/mod dist 9 글자 (", 0), ("약 9.4 ms", 1), (") → 마지막 글자 handshake 에서 disp_sel ", 0),
                    ("2 → 1", 1), (", FND ", 0), ("---- → 000.0", 1)],
                   [("그 뒤 스위치를 바꿔도 ", 0), ("w_ctrl_bit · disp_sel 그대로", 1), (" → 리셋 전까지 UART 가 화면 결정", 0)]],
                  page, "P1-A")
    p = Pic(s, os.path.join(IMG, "P1-A.png"), 0.92, y0, (19.08 - 0.92) * 797 / 2506, disp_w=2000)
    # Name 열 신호 이름
    for y1, y2, x2 in ((193, 213, 122), (310, 327, 98), (403, 420, 128), (426, 443, 128), (564, 581, 150)):
        namebox(p, 48, y1, x2, y2)
    # 2. 디코더 상태 진행
    rbox(p, 782, 191, 1447, 215)
    # 3. 마지막 글자 → handshake → 화면 전환
    vline(p, 1450, 236, 588)
    oval(p, 1450, 249, 26, 26)
    oval(p, 1729, 411, 92, 24)
    oval(p, 1737, 572, 84, 24)
    # 4. 스위치 바꿔도 그대로
    rbox(p, 1744, 307, 1998, 353)
    wlabel(p, 472, 295, "1. /mod 전 : 스위치가 화면 결정 (disp_sel 2)", 13)
    wlabel(p, 712, 157, "2. /mod dist 9 글자 → 디코더 state SLASH · m · o · d · SPACE", 13)
    wlabel(p, 1462, 457, "3. 마지막 글자 handshake → 화면 전환", 13)
    wlabel(p, 1748, 295, "4. 스위치 변경 무시", 13)
    text(s, 0.92, p.y + p.h + 0.1, 16.0, 0.32, "Figure.  /mod dist 전체 0 ~ 21 ms — Vivado xsim, tb_P_present P1 (실제 시간)",
         11.5, "8C8C8C", name="Figure")


def p1_b(prs, page):
    s, y0 = frame(prs, SEC1, "P1  확대 — 마지막 글자 수신 → 다음 clk 에 화면 전환",
                  ["마지막 글자 't' 를 받은 뒤 화면 선택 신호 · FND 가 바뀌는 시점"],
                  [[("rx_done → 디코더 handshake (w_ascii = ", 0), ("\"dist\"", 1), (") → ", 0),
                    ("다음 clk", 1), (" 에 w_ctrl_bit · disp_sel · FND 동시에 변경", 0)],
                   [("sw 는 ", 0), ("1000000", 1), (" (온습도) 그대로인데 화면은 ", 0), ("거리 000.0", 1),
                    (" → 스위치 대신 UART 값", 0)]],
                  page, "P1-B")
    p = Pic(s, os.path.join(IMG, "P1-B.png"), 0.92, y0, 10.3 - y0)
    for y1, y2, x2 in ((146, 166, 152), (233, 252, 168), (435, 455, 178), (464, 484, 180), (638, 658, 182)):
        namebox(p, 50, y1, x2, y2)
    oval(p, 438, 156, 72, 26)
    oval(p, 540, 213, 62, 26)
    vline(p, 563, 228, 666)
    oval(p, 705, 445, 104, 26)
    oval(p, 705, 648, 86, 26)
    wlabel(p, 395, 126, "1. 't' 수신 완료", 13)
    wlabel(p, 592, 126, "2. handshake", 13)
    wlabel(p, 575, 299, "3. 다음 clk : 화면 전환", 13)
    wlabel(p, 575, 503, "4. FND 도 같은 clk", 13)
    # 오른쪽 : FND 전 · 후 + 단계
    rx = p.x + p.w + 0.6
    fw = 3.25
    fy = y0 + 0.15
    fh = fnd(s, rx, fy, fw, "----", name="FND 전")
    arrow(s, rx + fw + 0.15, fy + fh / 2, rx + fw + 1.0, fy + fh / 2, RED, 3.0)
    fnd(s, rx + fw + 1.15, fy, fw, "0000", dot=2, name="FND 후")
    text(s, rx, fy + fh + 0.08, fw, 0.32, "disp_sel 2 · 온습도 (sw6 = 1)", 12, "404040", bold=True, align="c")
    text(s, rx + fw + 1.15, fy + fh + 0.08, fw, 0.32, "disp_sel 1 · 거리 (/mod dist)", 12, ACC, bold=True, align="c")
    steps(s, rx, fy + fh + 0.75, 19.08 - rx,
          [("w_rx_done", "마지막 글자 't' 수신 완료 → RX FIFO → 디코더"),
           ("handshake", "c_state SPACE → IDLE, w_ascii = \"dist\", w_handshake 1 clk 펄스"),
           ("다음 clk", "w_uart_ctrl_bit 0100000 · w_uart_mode 1 → w_ctrl_bit 1000000 → 0100000, disp_sel 2 → 1"),
           ("FND", "FND_FONT '-' → '0', FND_DATA ---- → 000.0 (같은 clk)")], row_h=0.98, head_w=1.75)


def p2_a(prs, page):
    s, y0 = frame(prs, SEC3, "P2  /btn R — UART 버튼으로 SR04 거리 측정",
                  ["UART /btn R 이 물리 버튼과 같은 경로로 지금 화면 모듈 (SR04) 에 들어가는지", "측정한 거리가 FND 까지 오는지"],
                  [[("/btn R handshake → ", 0), ("w_uart_btn_R → w_btn_R → SR04 i_btn_R", 1), (" → ", 0), ("trig", 1),
                    (" (약 18.2 ms)", 0)],
                   [("echo ", 0), ("7.134 ms", 1), (" → distance ", 0), ("123", 1), (" · x10 ", 0), ("1230", 1),
                    (" → FND ", 0), ("123.0", 1)]],
                  page, "P2-A")
    p = Pic(s, os.path.join(IMG, "P2-A.png"), 0.92, y0, 10.3 - y0, crop_h=975, disp_w=2000)
    for y1, y2, x2 in ((358, 375, 134), (450, 467, 82), (473, 490, 88), (542, 559, 144), (726, 743, 152)):
        namebox(p, 50, y1, x2, y2)
    rbox(p, 1110, 216, 1433, 239)
    vline(p, 1436, 262, 468)
    oval(p, 1436, 273, 24, 24)
    rbox(p, 1462, 471, 1913, 493)
    oval(p, 1957, 550, 62, 24)
    oval(p, 1957, 573, 70, 24)
    oval(p, 1953, 734, 80, 24)
    wlabel(p, 375, 158, "1. /mod dist → 거리 화면", 12.5)
    wlabel(p, 1112, 158, "2. /btn R 6 글자", 12.5)
    wlabel(p, 1450, 343, "3. handshake → 버튼 펄스 → trig", 12.5)
    wlabel(p, 1480, 435, "4. echo 7.134 ms → 123 cm", 12.5)
    # 오른쪽 : FND 전 · 후
    rx = p.x + p.w + 0.45
    fw = 19.08 - rx
    fy = y0 + 0.3
    fh = fnd(s, rx, fy, fw, "0000", dot=2, name="FND 전")
    text(s, rx, fy + fh + 0.06, fw, 0.3, "/btn R 전  000.0", 12, "404040", bold=True, align="c")
    arrow(s, rx + fw / 2, fy + fh + 0.45, rx + fw / 2, fy + fh + 1.25, RED, 3.0)
    fy2 = fy + fh + 1.4
    fh2 = fnd(s, rx, fy2, fw, "1230", dot=2, name="FND 후")
    text(s, rx, fy2 + fh2 + 0.06, fw, 0.3, "측정 뒤  123.0 cm", 12, ACC, bold=True, align="c")
    text(s, rx, fy2 + fh2 + 0.55, fw, 0.9, ["echo 7,134 us", "÷ 58 us = 123 cm"], 12, "404040", align="c", anchor="t")
    text(s, 0.92, p.y + p.h + 0.08, 14.0, 0.3, "Figure.  /btn R 전체 0 ~ 27 ms — 아래 UART TX 줄은 이 구간에 변화가 없어 잘라 냄",
         11.5, "8C8C8C", name="Figure")


def p2_b(prs, page):
    s, y0 = frame(prs, SEC3, "P2  확대 — /btn R 수신에서 trig 상승까지",
                  ["마지막 글자 'R' 을 받은 뒤 SR04 trig 가 올라가기까지 몇 clk 인지"],
                  [[("rx_done → handshake ", 0), ("+2 clk", 1), (" → 버튼 펄스 ", 0), ("+1 clk", 1), (" → trig ", 0),
                    ("+1 clk", 1), (" : 합계 ", 0), ("4 clk (40 ns)", 1)],
                   [("UART 버튼도 물리 버튼과 같은 ", 0), ("OR → 화면 AND", 1), (" 경로 → 지금 화면 (거리) 의 SR04 에만 들어감", 0)]],
                  page, "P2-B")
    p = Pic(s, os.path.join(IMG, "P2-B.png"), 0.92, y0, 10.3 - y0, crop_h=965)
    for y1, y2, x2 in ((212, 232, 152), (327, 347, 168), (443, 464, 166), (559, 579, 98)):
        namebox(p, 52, y1, x2, y2)
    # 번호 + 노란 세로선 (reference P3-2 형식)
    for n, cx, cy, y1, y2 in ((1, 465, 192, 210, 236), (2, 563, 192, 210, 352), (3, 613, 424, 442, 526),
                              (4, 660, 540, 558, 640)):
        vline(p, cx if n != 4 else 638, y1, y2, YEL, 1.75)
        wcircle(p, cx, cy, n)
    # 40 ns 길이 표시
    hline(p, 440, 638, 76)
    vline(p, 440, 66, 86)
    vline(p, 638, 66, 86)
    wlabel(p, 652, 76, "40 ns (4 clk)", 12.5)
    # 오른쪽 : 블록 줄 + 단계
    rx = p.x + p.w + 0.75
    chain(s, rx, y0 + 0.5, [("uart_rx", "rx_done", "uart"), ("디코더", "handshake", "uart"),
                            ("버튼 OR · AND", "btn_R", "com"), ("sr04_core", "trig", "sr04")],
          bw=2.0, gap=(19.08 - rx - 4 * 2.0) / 3, gaps=("+20 ns", "+10 ns", "+10 ns"))
    steps(s, rx, y0 + 2.0, 19.08 - rx,
          [("t + 0 ns", "w_rx_done — 마지막 글자 'R' 수신 완료 (W_RX = R)"),
           ("t + 20 ns", "c_state SPACE → IDLE, w_ascii = \"R\", w_handshake 1 clk"),
           ("t + 30 ns", "w_uart_btn_R → w_btn_R (물리 버튼과 OR) → U_SR04 i_btn_R, 1 clk 펄스"),
           ("t + 40 ns", "trig 1 · w_state 0 → 1 (START), trig 는 11 us 유지")], row_h=1.0, head_w=1.55)
    text(s, rx, 9.95, 19.08 - rx, 0.32, "1 clk = 10 ns (100 MHz)  ·  t = rx_done 이 뜬 clk", 12, "8C8C8C")


SLIDES = [("P1-A", p1_a), ("P1-B", p1_b), ("P2-A", p2_a), ("P2-B", p2_b)]


def drop_old(prs):
    """이전에 붙인 파형 장 (제목 이름 wave:*) 지우기"""
    lst = prs.slides._sldIdLst
    for sid, sl in list(zip(list(lst), list(prs.slides))):
        if any(sh.name.startswith("wave:") for sh in sl.shapes):
            prs.part.drop_rel(sid.rId)
            lst.remove(sid)


def build(src, out):
    prs = Presentation(src)
    drop_old(prs)
    page = len(prs.slides)
    for tag, fn in SLIDES:
        if not os.path.exists(os.path.join(IMG, tag + ".png")):
            print("skip (no image)", tag)
            continue
        page += 1
        fn(prs, page)
        print(f"slide {page:02d}  {tag}")
    prs.save(out)


if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else sys.argv[1])
