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
from pptx.util import Inches, Pt
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
    # (11/01) 판별 칩 · 글은 슬라이드에서 빼고 발표자 노트로 → 결론을 제목 바로 아래로, 파형 자리 확보
    s.notes_slide.notes_text_frame.text = "판별 : " + " / ".join(judge)
    by = 1.62
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
    p = Pic(s, os.path.join(IMG, "P2-A.png"), 0.92, y0, min(10.3 - y0, 14.3 * 975 / 2516), crop_h=975, disp_w=2000)
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


SEC2 = "03  Top · 시뮬레이션   ② 송신  /auto"
MONO = "Consolas"


def terminal(s, x, y, w, rows, title="PC 터미널  ·  9600 bps 8N1", pt=14, row_h=0.46):
    """PC 가 받은 줄 그림 : rows = [(시각, 줄, 설명)]"""
    hh = 0.42
    h = hh + 0.2 + row_h * len(rows) + 0.15
    bg = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, x, y, w, h, "1E1E1E", None, name="터미널")
    bg.adjustments[0] = 0.04
    bar = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, x, y, w, hh, "3C3C3C", None, name="터미널 제목")
    bar.adjustments[0] = 0.25
    text(s, x + 0.2, y, w - 0.3, hh, title, 12, "D4D4D4", bold=True)
    for i, (t, line, note) in enumerate(rows):
        yy = y + hh + 0.15 + i * row_h
        text(s, x + 0.2, yy, 1.35, row_h, t, pt - 2, "8C8C8C", font=MONO)
        text(s, x + 1.55, yy, 2.1, row_h, line, pt, "9CDCFE" if line.startswith(">") else "7CFC9A", bold=True,
             font=MONO)
        text(s, x + 3.6, yy, w - 3.7, row_h, note, pt - 2.5, "FFC000", bold=True)
    return h


def p3_a(prs, page):
    s, y0 = frame(prs, SEC2, "P3  /auto all — 1 Hz 마다 전송 MUX 입력 5 개를 차례로",
                  ["/auto all 뒤 1 초마다 전송 MUX (o_send_sel) 가 0 → 4 를 차례로 골라 한 줄씩 보내는지",
                   "줄 간격이 정확히 1 s (100,000,000 clk) 인지"],
                  [[("send_go 간격 GO_GAP_CLK = ", 0), ("100,000,000 clk = 1.000 000 s", 1), (", o_send_sel ", 0),
                    ("0 → 1 → 2 → 3 → 4 → 0", 1), (" 반복", 0)],
                   [("SW ", 0), ("00:00:01.09", 1), (" → TM ", 0), ("00:00:57.94", 1), (" → WH ", 0), ("12:00:03.10", 1),
                    (" → ", 0), ("123cm", 1), (" → ", 0), ("55%24C", 1), (" : 줄마다 1 s 흐른 값", 0)]],
                  page, "P3-A")
    p = Pic(s, os.path.join(IMG, "P3-A.png"), 0.92, y0, min(10.3 - y0, 12.4 * 1146 / 2292), disp_w=2000)
    for y1, y2, x2 in ((443, 461, 172), (468, 486, 176), (519, 537, 158), (645, 663, 156)):
        namebox(p, 58, y1, x2, y2)
    oval(p, 1364, 451, 112, 22)
    oval(p, 1364, 476, 132, 22)
    rbox(p, 343, 516, 1408, 539)
    for cx, w in ((637, 112), (812, 112), (986, 112), (1176, 70), (1347, 82)):
        oval(p, cx, 653, w, 24)
    wlabel(p, 365, 174, "1. /auto all 수신 → 1 s 카운트 시작", 12.5)
    wlabel(p, 545, 376, "2. 1 Hz tick → send_go (간격 1,000,000 us)", 12.5)
    wlabel(p, 545, 553, "3. sel 0 → 1 → 2 → 3 → 4 순서로 한 줄씩", 12.5)
    wlabel(p, 545, 857, "4. DHT11 부팅 1 s 뒤 측정 → 55.24", 12.5)
    text(s, 0.92, p.y + p.h + 0.06, 12.0, 0.3, "Figure.  /auto all 0 ~ 9.1 s — 파란 마커 = 줄 끝 시각 (실제 시간)",
         11.5, "8C8C8C", name="Figure")
    # 오른쪽 : PC 가 받은 줄 (마커 시각 = 줄 끝)
    rx = p.x + p.w + 0.5
    rw = 19.08 - rx
    th = terminal(s, rx, y0 + 0.1, rw,
                  [("1.123 s", "00:00:01.09", "sel 0  스톱워치"), ("2.123 s", "00:00:57.94", "sel 1  타이머"),
                   ("3.123 s", "12:00:03.10", "sel 2  시계"), ("4.117 s", "123cm", "sel 3  거리"),
                   ("5.118 s", "55%24C", "sel 4  온습도"), ("6.123 s", "00:00:06.09", "sel 0  다시 처음")])
    ny = y0 + 0.1 + th + 0.3
    text(s, rx, ny, rw, 0.36, "줄 끝 시각 = 파형의 파란 마커", 13, "262626", bold=True)
    text(s, rx, ny + 0.4, rw, 2.0,
         ["send_go 는 정확히 1 s 간격,", "줄 끝은 줄 길이 (시간 13 · 거리 7 · 온습도 8 글자,", "1 글자 = 1.04 ms) 만큼 앞뒤로 :",
          "시간 → 거리  1 s - 6 글자 = 993.75 ms", "거리 → 온습도  1 s + 1 글자 = 1,001.04 ms"],
         12.5, "404040", anchor="t")


# ---------------------------------------------------------------- 글자 표시 (캡처 글씨가 작아서 값 · 시각을 슬라이드 글자로)
def ttag(p, xp, yp, t, pt=12, color="C00000"):
    """시각 · 값 꼬리표 : 흰 바탕 · 색 글자 · 테두리, (xp, yp) = 가운데"""
    w = text_w(t, pt) + 0.18
    h = 0.28
    tb = text(p.s, p.X(xp) - w / 2, p.Y(yp) - h / 2, w, h, t, pt, color, bold=True, align="c", name="꼬리표")
    tb.fill.solid()
    tb.fill.fore_color.rgb = RGBColor.from_string("FFFFFF")
    tb.line.color.rgb = RGBColor.from_string(color)
    tb.line.width = Pt(1.0)
    return tb


def tlist(s, x, y, w, rows, head_w=2.0, row_h=0.62, pt=14, title=None):
    """시간 순서 목록 : rows = [(시각, 설명)]"""
    if title:
        text(s, x, y, w, 0.36, title, 14, "262626", bold=True)
        y += 0.45
    for i, (t, body) in enumerate(rows):
        yy = y + i * row_h
        text(s, x, yy, head_w, 0.4, t, pt, ACC, bold=True, name=f"시각 {i + 1}")
        text(s, x + head_w, yy, w - head_w, row_h, body, pt, "404040", anchor="t", name=f"시각 설명 {i + 1}")


def fnd_col(s, x, y, w, items, gap, fw=1.9):
    """FND 그림 세로 줄 : items = [(4 글자, 점 자리, 머리, 설명, 머리 색)] — 사이에 빨간 화살표"""
    for i, (dg, dot, head, body, col) in enumerate(items):
        yy = y + i * gap
        fh = fnd(s, x, yy, fw, dg, dot=dot, name=f"FND {i + 1}")
        text(s, x + fw + 0.2, yy - 0.02, w - fw - 0.2, 0.36, head, 14, col, bold=True)
        text(s, x + fw + 0.2, yy + 0.36, w - fw - 0.2, gap - 0.4, body.split("\n"), 12, "404040", anchor="t")
        if i < len(items) - 1:
            arrow(s, x + fw / 2, yy + fh + 0.06, x + fw / 2, yy + gap - 0.06, RED, 2.5)


SEC4 = "03  Top · 시뮬레이션   ④ 오류  ERROR"
SEC5 = "03  Top · 시뮬레이션   센서 오류  SR04"
SEC6 = "03  Top · 시뮬레이션   센서 오류  DHT11"


def p4_a(prs, page):
    s, y0 = frame(prs, SEC4, "P4  /gxt — 형식 오류 → ERROR 한 줄, 다음 명령은 정상",
                  ["형식이 틀린 명령에서 ERROR 가 정확히 한 줄 나가는지", "오류 뒤 명령이 정상 처리되는지"],
                  [[("/gxt 의 3 번째 글자 ", 0), ("x", 1), (" 에서 w_error (약 ", 0), ("4.07 ms", 1),
                    (") → 전송 MUX sel ", 0), ("7", 1), (" → ", 0), ("ERROR", 1), (" 한 줄", 0)],
                   [("남은 글자 t 는 무시 (c_state IDLE), 이어진 /get 은 정상 → sel ", 0), ("2", 1), (" 시계 줄 ", 0),
                    ("12:00:00.02", 1), (" (약 20.2 ms)", 0)]],
                  page, "P4-A")
    p = Pic(s, os.path.join(IMG, "P4-A.png"), 0.92, y0, (19.08 - 0.92) * 596 / 2522, disp_w=2000)
    for y1, y2, x2 in ((215, 233, 126), (285, 301, 106), (354, 370, 142), (446, 462, 140)):
        namebox(p, 44, y1, x2, y2)
    rbox(p, 414, 212, 562, 234)
    vline(p, 511, 175, 445)
    vline(p, 1265, 175, 445)
    oval(p, 511, 293, 24, 24)
    oval(p, 887, 361, 44, 22)
    oval(p, 1633, 361, 44, 22)
    oval(p, 1398, 454, 90, 22)
    oval(p, 1958, 454, 84, 22)
    wlabel(p, 520, 155, "1. 'x' 에서 형식 오류 → w_error", 12.5)
    wlabel(p, 860, 155, "2. 남은 't' 무시", 12.5)
    wlabel(p, 520, 316, "3. sel 7 → ERROR 한 줄", 12.5)
    wlabel(p, 1275, 316, "4. /get → sel 2 → 시계 줄", 12.5)
    for xp, t in ((511, "4.07 ms"), (850, "11.3 ms"), (1265, "20.2 ms"), (1893, "33.7 ms")):
        ttag(p, xp, 63, t)
    by = p.y + p.h + 0.3
    terminal(s, 0.92, by, 8.6, [("1.0 ms", "> /gxt", "보냄 · 형식 오류"), ("11.3 ms", "ERROR", "받음 · sel 7"),
                                 ("14.0 ms", "> /get", "보냄"), ("33.7 ms", "12:00:00.02", "받음 · sel 2 시계")])
    tlist(s, 10.2, by, 8.88, [("4.07 ms", "'x' rx_done → w_error → send_go (sel 7)"),
                              ("4.1 ~ 11.3 ms", "tx ERROR 7 글자 — 줄 하나만"),
                              ("14.0 ~ 20.2 ms", "/get 6 글자 → handshake"),
                              ("20.2 ~ 33.7 ms", "tx 시계 줄 13 글자")], head_w=2.4, title="시간 순서")


def p4_b(prs, page):
    s, y0 = frame(prs, SEC4, "P4  확대 — 'x' 수신에서 ERROR 송신 시작까지",
                  ["틀린 글자를 받은 뒤 ERROR 송신이 몇 clk 만에 시작되는지"],
                  [[("rx_done ('x') → ", 0), ("+2 clk", 1), (" w_error → ", 0), ("+1 clk", 1),
                    (" send_go · sel 0 → 7 → 글자 E R R O R 를 TX FIFO 로", 0)],
                   [("tx start bit 까지 ", 0), ("70 ns (7 clk)", 1), (" — 오류는 다른 전송보다 먼저 (sender 가 비어 있으면 바로)", 0)]],
                  page, "P4-B")
    p = Pic(s, os.path.join(IMG, "P4-B.png"), 0.92, y0, 11.6 * 607 / 1197)
    for y1, y2, x2 in ((206, 226, 140), (351, 371, 122), (409, 429, 130), (437, 457, 150), (495, 515, 176),
                       (525, 545, 82)):
        namebox(p, 44, y1, x2, y2)
    for n, cx, cy, y1, y2 in ((1, 548, 187, 204, 216), (2, 648, 187, 204, 361), (3, 690, 389, 406, 420),
                              (4, 748, 389, 406, 506), (5, 873, 389, 406, 535)):
        vline(p, cx if n != 3 else 698, y1, y2, YEL, 1.75)
        wcircle(p, cx, cy, n)
    hline(p, 523, 873, 72)
    vline(p, 523, 62, 82)
    vline(p, 873, 62, 82)
    wlabel(p, 885, 72, "70 ns (7 clk)", 12.5)
    oval(p, 1063, 447, 30, 20)
    text(s, 0.92, p.y + p.h + 0.08, 11.6, 0.3, "Figure.  4,076,285 ns (= 약 4.0763 ms) 부근 확대 — 1 clk = 10 ns",
         11.5, "8C8C8C", name="Figure")
    rx = p.x + p.w + 0.6
    steps(s, rx, y0 + 0.1, 19.08 - rx,
          [("t + 0 ns", "w_rx_done — 'x' 수신 완료 (W_RX = x)"),
           ("t + 20 ns", "c_state g → IDLE, w_error 1 clk"),
           ("t + 30 ns", "w_send_go · o_send_sel 0 → 7 (ERROR)"),
           ("t + 40 ns", "w_tx_push_data E → R → R → O → R"),
           ("t + 70 ns", "tx 1 → 0 (start bit) — 송신 시작")], row_h=1.05, head_w=1.6)


def p4_c(prs, page):
    s, y0 = frame(prs, SEC4, "P4  ERROR 뒤 /get — 다음 명령은 정상 처리",
                  ["오류가 난 뒤 다음 명령이 정상으로 처리되는지"],
                  [[("디코더는 IDLE 에서 다시 시작 → /get 6 글자 ", 0), ("SLASH → g → e → t → SPACE", 1),
                    (" → handshake (약 ", 0), ("20.2 ms", 1), (")", 0)],
                   [("/mod 전 (스위치 모드) 이라 sel ", 0), ("2", 1), (" 시계 → ", 0), ("12:00:00.02", 1),
                    (" 13 글자 송신 (20.2 ~ 33.6 ms)", 0)]],
                  page, "P4-C")
    p = Pic(s, os.path.join(IMG, "P4-C.png"), 0.92, y0, (19.08 - 0.92) * 605 / 2250, disp_w=2000)
    for y1, y2, x2 in ((238, 254, 128), (290, 306, 140), (393, 409, 150), (496, 512, 140)):
        namebox(p, 44, y1, x2, y2)
    rbox(p, 537, 235, 902, 257)
    vline(p, 902, 180, 515)
    oval(p, 902, 298, 24, 24)
    oval(p, 624, 400, 40, 20)
    oval(p, 1452, 400, 40, 20)
    oval(p, 1937, 503, 100, 20)
    wlabel(p, 540, 169, "1. /get 6 글자 → 디코더 정상 진행", 12.5)
    wlabel(p, 912, 349, "2. handshake → send_go (sel 7 → 2)", 12.5)
    wlabel(p, 1300, 169, "3. 시계 줄 13 글자 → 12:00:00.02", 12.5)
    for xp, t in ((468, "14.0 ms"), (902, "20.2 ms"), (1843, "33.6 ms")):
        ttag(p, xp, 66, t)
    by = p.y + p.h + 0.3
    terminal(s, 0.92, by, 8.6, [("11.3 ms", "ERROR", "앞 명령 /gxt 의 오류"), ("14.0 ms", "> /get", "보냄"),
                                 ("33.6 ms", "12:00:00.02", "받음 · sel 2 시계")])
    tlist(s, 10.2, by, 8.88, [("14.0 ms", "/get 수신 시작 (6 글자 × 1.04 ms)"),
                              ("20.2 ms", "handshake → send_go · sel 7 → 2"),
                              ("20.2 ~ 33.6 ms", "tx 13 글자 → W_LINE 12:00:00.02")], head_w=2.4, title="시간 순서")


def p5_a(prs, page):
    s, y0 = frame(prs, SEC5, "P5  SR04 Err1 · Err2 · Err3 — FND · LED · PC 가 같은 오류 번호",
                  ["SR04 오류 3 종류가 FND · LD9 · PC 줄에 같은 번호로 나오는지", "오류마다 판정 시간"],
                  [[("Err1 무응답 : trig↓ + ", 0), ("30 ms", 1), (" → status ", 0), ("1", 1), (" · FND ", 0), ("Err1", 1),
                    (" · LD9 → /get ", 0), ("Err 1", 1)],
                   [("Err2 범위 밖 : echo 23.25 ms > ", 0), ("23.2 ms (400 cm)", 1), (" → status ", 0), ("2", 1),
                    (" · distance 400 · FND ", 0), ("Err2", 1), (" → /get ", 0), ("Err 2", 1)],
                   [("Err3 echo 고착 : 23.2 ms 에 Err2 → ", 0), ("73.2 ms", 1), (" 에 status ", 0), ("3", 1),
                    (" · 강제 IDLE (w_state 0) → FND ", 0), ("Err3", 1)]],
                  page, "P5-A")
    p = Pic(s, os.path.join(IMG, "P5-A.png"), 0.92, y0, 13.4 * 1062 / 2530, disp_w=2000)
    for y1, y2, x2 in ((374, 390, 93), (442, 458, 156), (625, 641, 154), (648, 664, 90), (809, 825, 142)):
        namebox(p, 44, y1, x2, y2)
    for xp in (727, 1112, 1851):
        vline(p, xp, 395, 668)
    rbox(p, 970, 370, 1114, 392)
    rbox(p, 1355, 370, 1982, 392)
    for xp in (919, 1481, 1925):
        oval(p, xp, 450, 30, 20)
    for xp in (928, 1491, 1934):
        oval(p, xp, 633, 64, 20)
    for xp in (1065, 1626):
        oval(p, xp, 817, 64, 20)
    wlabel(p, 560, 336, "1. Err1 : echo 없음", 12.5)
    wlabel(p, 980, 336, "2. Err2 : echo 23.25 ms", 12.5)
    wlabel(p, 1400, 336, "3. Err3 : echo 고착", 12.5)
    wlabel(p, 860, 680, "4. /get 마다 PC 도 Err 1 · Err 2", 12.5)
    for xp, t in ((727, "약 48 ms"), (1112, "약 111 ms"), (1851, "약 233 ms")):
        ttag(p, xp, 152, t)
    text(s, 0.92, p.y + p.h + 0.08, 13.4, 0.3, "Figure.  P5 전체 0 ~ 258 ms — 빨간 세로선 = 오류 판정 (w_dist_done)",
         11.5, "8C8C8C", name="Figure")
    rx = p.x + p.w + 0.5
    fnd_col(s, rx, y0 + 0.15, 19.08 - rx,
            [("Err1", None, "Err1  무응답", "trig↓ + 30 ms 에 판정\necho 없음 · LD9 켜짐", "C53030"),
             ("Err2", None, "Err2  범위 밖", "echo↑ + 23.2 ms 에 판정\n400 cm 넘음 · distance 400", "C53030"),
             ("Err3", None, "Err3  echo 고착", "trig↓ + 73.2 ms 에 판정\necho 고착 → 강제 IDLE", "C53030")],
            gap=1.85)


def p6_a(prs, page):
    s, y0 = frame(prs, SEC6, "P6  DHT11 Err1 · Err2 · Err3 — 2 s 간격 측정, 오류 번호 그대로 PC 로",
                  ["DHT11 오류 3 종류가 FND · PC 에 같은 번호로 나오는지", "측정 간격 2 s 가 지켜지는지"],
                  [[("부팅 ", 0), ("1 s", 1), (" 뒤 첫 측정, 이후 이전 시작 + ", 0), ("2 s", 1),
                    (" 마다 (1.0 · 3.0 · 5.0 s) 시작 LOW 18 ms", 0)],
                   [("응답 없음 → status ", 0), ("1", 1), (" · 20 비트 뒤 끊김 → ", 0), ("2", 1), (" · 체크섬 틀림 → ", 0),
                    ("3", 1), ("  :  FND ", 0), ("Err1 → Err2 → Err3", 1)],
                   [("PC 도 ", 0), ("--%--C → Err 1 → Err 2 → Err 3", 1), (" (측정 전 · 오류 때 숫자 대신)", 0)]],
                  page, "P6-A")
    p = Pic(s, os.path.join(IMG, "P6-A.png"), 0.92, y0, 13.4 * 1046 / 2497, disp_w=2000)
    for y1, y2, x2 in ((359, 375, 100), (475, 491, 146), (614, 630, 146), (800, 816, 130)):
        namebox(p, 38, y1, x2, y2)
    for xp in (644, 1322):
        vline(p, xp, 352, 820)
    for xp in (987, 1664):
        oval(p, xp, 483, 30, 20)
    for xp, w in ((486, 50), (996, 50), (1674, 50)):
        oval(p, xp, 622, w, 20)
    for xp in (509, 1015, 1692):
        oval(p, xp, 808, 66, 20)
    wlabel(p, 655, 344, "1. 부팅 1 s → 첫 측정 · 응답 없음 → Err1", 12.5)
    wlabel(p, 1335, 344, "2. + 2 s → 20 비트 뒤 끊김 → Err2", 12.5)
    wlabel(p, 315, 668, "3. 측정 전 /get → --%--C", 12.5)
    wlabel(p, 720, 668, "4. 오류마다 /get → Err 1 · Err 2", 12.5)
    for xp, t in ((644, "1.000 s"), (1322, "3.000 s")):
        ttag(p, xp, 158, t)
    text(s, 0.92, p.y + p.h + 0.08, 13.4, 0.3, "Figure.  P6 전체 0 ~ 5 s — Err3 (5.0 s) 는 P6-E1 장",
         11.5, "8C8C8C", name="Figure")
    rx = p.x + p.w + 0.5
    fnd_col(s, rx, y0 + 0.1, 19.08 - rx,
            [("----", None, "측정 전", "0 ~ 1 s  ·  PC : --%--C", "404040"),
             ("Err1", None, "Err1  응답 없음", "1.018 s  ·  PC : Err 1", "C53030"),
             ("Err2", None, "Err2  중간 끊김", "3.020 s  ·  PC : Err 2", "C53030"),
             ("Err3", None, "Err3  체크섬", "5.022 s  ·  PC : Err 3", "C53030")],
            gap=1.38, fw=1.75)


def p6_b(prs, page):
    s, y0 = frame(prs, SEC6, "P6  측정 전 /get — 숫자 대신 --%--C",
                  ["DHT11 이 아직 측정하지 않았을 때 PC 에 무엇을 보내는지"],
                  [[("측정 전 w_dht_dashes = ", 0), ("1", 1), (" → FND ", 0), ("----", 1), (" · PC 도 숫자 대신 ", 0),
                    ("--%--C", 1), (" (v1 은 00%00C)", 0)],
                   [("/get handshake (약 ", 0), ("18.2 ms", 1), (") → sel ", 0), ("4", 1),
                    (" 온습도 → 8 글자 송신 (18.2 ~ 26.5 ms)", 0)]],
                  page, "P6-B")
    p = Pic(s, os.path.join(IMG, "P6-B.png"), 0.92, y0, 13.4 * 1017 / 2432, disp_w=2000)
    for y1, y2, x2 in ((520, 536, 140), (614, 632, 158), (710, 726, 150), (806, 822, 142)):
        namebox(p, 40, y1, x2, y2)
    rbox(p, 853, 232, 1068, 250)
    vline(p, 1068, 180, 820)
    oval(p, 1068, 289, 24, 24)
    oval(p, 1418, 622, 60, 20)
    oval(p, 1570, 718, 30, 20)
    oval(p, 1766, 813, 70, 20)
    wlabel(p, 330, 170, "1. /mod temp → 온습도 화면", 12.5)
    wlabel(p, 880, 170, "2. /get → handshake", 12.5)
    wlabel(p, 1080, 670, "3. sel 4 → --%--C 8 글자", 12.5)
    wlabel(p, 1420, 337, "4. /btn R → 부팅 1 s 까지 대기", 12.5)
    for xp, t in ((745, "10.3 ms"), (1068, "18.2 ms"), (1408, "26.5 ms"), (1818, "36.5 ms")):
        ttag(p, xp, 75, t)
    text(s, 0.92, p.y + p.h + 0.08, 13.4, 0.3, "Figure.  P6 시작 0 ~ 40 ms", 11.5, "8C8C8C", name="Figure")
    rx = p.x + p.w + 0.5
    rw = 19.08 - rx
    fh = fnd(s, rx, y0 + 0.15, 2.6, "----", name="FND 측정 전")
    text(s, rx, y0 + 0.2 + fh, 2.6, 0.32, "FND  ----  (dashes 1)", 12, "404040", bold=True, align="c")
    th = terminal(s, rx, y0 + 1.75, rw, [("12.0 ms", "> /get", "보냄"), ("26.5 ms", "--%--C", "sel 4")])
    tlist(s, rx, y0 + 1.95 + th, rw, [("10.3 ms", "/mod temp → 화면 온습도"), ("18.2 ms", "/get handshake"),
                                      ("26.5 ms", "--%--C 도착"), ("36.5 ms", "/btn R → 1 s 에 측정")],
          head_w=1.3, row_h=0.5, pt=13)


def p6_c1(prs, page):
    s, y0 = frame(prs, SEC6, "P6  Err1 — 시작 LOW 18 ms 뒤 센서 응답 없음",
                  ["센서가 응답하지 않을 때 언제 Err1 로 판정하는지"],
                  [[("부팅 1 s 에 w_dht_oe 1 (선 LOW) → ", 0), ("18.0 ms", 1), (" 뒤 선 놓음 → 응답 없음 → 약 ", 0),
                    ("0.2 ms", 1), (" 안에 status ", 0), ("1", 1)],
                   [("FND ---- → ", 0), ("Err1", 1), (" · LED 0001 → 0010 → /get (약 1,036 ms) → PC ", 0), ("Err 1", 1)]],
                  page, "P6-C1")
    p = Pic(s, os.path.join(IMG, "P6-C1.png"), 0.92, y0, 13.4 * 1046 / 2336, disp_w=2000)
    for y1, y2, x2 in ((383, 399, 116), (408, 424, 121), (507, 523, 161), (656, 672, 160), (854, 870, 148)):
        namebox(p, 44, y1, x2, y2)
    rbox(p, 333, 404, 530, 426)
    oval(p, 540, 490, 22, 22)
    vline(p, 540, 500, 680)
    vline(p, 1308, 310, 845)
    oval(p, 1350, 514, 30, 20)
    oval(p, 1360, 663, 50, 20)
    oval(p, 1924, 862, 60, 20)
    wlabel(p, 560, 366, "1. 시작 LOW 끝 → 응답 없음", 12.5)
    wlabel(p, 560, 639, "2. Err1 · FND Err1", 12.5)
    wlabel(p, 1320, 713, "3. /get → PC Err 1", 12.5)
    for xp, t in ((530, "1,018.0 ms"), (1308, "1,036.2 ms"), (1618, "1,043.5 ms")):
        ttag(p, xp, 167, t)
    text(s, 0.92, p.y + p.h + 0.08, 13.4, 0.3, "Figure.  1,013 ~ 1,052 ms 확대", 11.5, "8C8C8C", name="Figure")
    rx = p.x + p.w + 0.5
    fnd_col(s, rx, y0 + 0.15, 19.08 - rx,
            [("----", None, "측정 전", "LED 0001 (측정 중)", "404040"),
             ("Err1", None, "Err1  응답 없음", "1,018.2 ms  ·  LED 0010", "C53030")], gap=1.85)
    terminal(s, rx, y0 + 4.0, 19.08 - rx, [("1,030 ms", "> /get", "보냄"), ("1,043.5 ms", "Err 1", "sel 4")])


def p6_d1(prs, page):
    s, y0 = frame(prs, SEC6, "P6  Err2 — 20 비트 뒤 데이터가 끊김",
                  ["데이터를 받다가 끊겼을 때 멈추지 않고 Err2 로 판정하는지"],
                  [[("이전 시작 + ", 0), ("2 s", 1), (" (3,000 ms) 시작 LOW → 3,018 ms 응답 + 20 비트 → 끊김 → 약 ", 0),
                    ("0.2 ms", 1), (" 뒤 status ", 0), ("2", 1)],
                   [("FND Err1 → ", 0), ("Err2", 1), (" · LED 0011 (측정 중) → 0010, w_state 0 복귀 → 다음 측정 가능", 0)]],
                  page, "P6-D1")
    p = Pic(s, os.path.join(IMG, "P6-D1.png"), 0.92, y0, 10.3 - y0)
    for y1, y2, x2 in ((441, 459, 132), (470, 488, 141), (499, 517, 128), (586, 604, 182), (760, 778, 186)):
        namebox(p, 54, y1, x2, y2)
    rbox(p, 742, 466, 997, 490)
    rbox(p, 995, 436, 1029, 520)
    for n, cx, cy, y1, y2 in ((1, 742, 421, 438, 480), (2, 1011, 421, 438, 520), (3, 1027, 740, 756, 778)):
        vline(p, cx, y1, y2, YEL, 1.75)
        wcircle(p, cx, cy, n)
    oval(p, 1100, 594, 30, 20)
    oval(p, 1100, 769, 56, 20)
    for xp, t in ((742, "3,000.0 ms"), (1027, "3,020.1 ms")):
        ttag(p, xp, 189, t)
    rx = p.x + p.w + 0.6
    fw = 3.0
    fh = fnd(s, rx, y0 + 0.15, fw, "Err1", name="FND 전")
    arrow(s, rx + fw + 0.15, y0 + 0.15 + fh / 2, rx + fw + 0.9, y0 + 0.15 + fh / 2, RED, 3.0)
    fnd(s, rx + fw + 1.05, y0 + 0.15, fw, "Err2", name="FND 후")
    text(s, rx, y0 + 0.2 + fh, fw, 0.32, "1 s 의 Err1", 12, "404040", bold=True, align="c")
    text(s, rx + fw + 1.05, y0 + 0.2 + fh, fw, 0.32, "3.020 s  Err2", 12, "C53030", bold=True, align="c")
    steps(s, rx, y0 + fh + 0.9, 19.08 - rx,
          [("3,000 ms", "이전 시작 + 2 s → w_dht_oe 1, 선 LOW 18 ms (LED 0011)"),
           ("3,018 ms", "선 놓음 → 센서 응답 + 20 비트 (dht_drv 토글)"),
           ("약 3,020 ms", "마지막 엣지 + 0.2 ms → w_dht_done, status 1 → 2, FND Err2")], row_h=1.05, head_w=1.9)


def p6_e1(prs, page):
    s, y0 = frame(prs, SEC6, "P6  Err3 — 40 비트를 다 받았지만 체크섬이 틀림",
                  ["값을 다 받았어도 체크섬이 틀리면 버리고 Err3 로 판정하는지"],
                  [[("5,000 ms 시작 LOW → 5,018 ms 부터 40 비트 → 체크섬 불일치 → 약 ", 0), ("5,021.6 ms", 1),
                    (" 에 status ", 0), ("3", 1)],
                   [("습도 · 온도는 갱신 안 함 (", 0), ("0 · 0", 1), (" 그대로) → FND ", 0), ("Err3", 1),
                    (" → /get (약 5,036 ms) → PC ", 0), ("Err 3", 1)]],
                  page, "P6-E1")
    p = Pic(s, os.path.join(IMG, "P6-E1.png"), 0.92, y0, 13.4 * 1041 / 2340, disp_w=2000)
    for y1, y2, x2 in ((381, 397, 126), (406, 422, 131), (505, 521, 173), (580, 596, 161), (604, 620, 180),
                       (653, 669, 171), (852, 868, 156)):
        namebox(p, 54, y1, x2, y2)
    rbox(p, 890, 404, 1198, 426)
    rbox(p, 1196, 378, 1262, 450)
    vline(p, 1260, 455, 680)
    vline(p, 1509, 300, 845)
    oval(p, 1712, 512, 30, 20)
    oval(p, 1722, 661, 56, 20)
    rbox(p, 1228, 577, 1274, 621)
    oval(p, 1925, 860, 60, 20)
    wlabel(p, 895, 364, "1. 5,000 ms 시작 LOW 18 ms", 12.5)
    wlabel(p, 1300, 364, "2. 40 비트 → 체크섬 틀림 → Err3", 12.5)
    wlabel(p, 1290, 637, "3. 값은 버림 (0 · 0)", 12.5)
    wlabel(p, 1520, 711, "4. /get → PC Err 3", 12.5)
    for xp, t in ((890, "5,000.0 ms"), (1260, "5,021.6 ms"), (1509, "5,036.3 ms")):
        ttag(p, xp, 166, t)
    text(s, 0.92, p.y + p.h + 0.08, 13.4, 0.3, "Figure.  4,966 ~ 5,063 ms 확대", 11.5, "8C8C8C", name="Figure")
    rx = p.x + p.w + 0.5
    fnd_col(s, rx, y0 + 0.15, 19.08 - rx,
            [("Err2", None, "3 s 의 Err2", "LED 0011 (측정 중)", "404040"),
             ("Err3", None, "Err3  체크섬", "5,021.6 ms  ·  LED 0010", "C53030")], gap=1.85)
    terminal(s, rx, y0 + 4.0, 19.08 - rx, [("5,030 ms", "> /get", "보냄"), ("5,043.5 ms", "Err 3", "sel 4")])



def table(s, x, y, col_w, rows, row_h=0.4, pt=13, hl=None, name="표"):
    """표 : rows[0] = 머리 줄. hl = {(행, 열): 색} 글자 색 강조"""
    hl = hl or {}
    t = s.shapes.add_table(len(rows), len(col_w), Inches(x), Inches(y), Inches(sum(col_w)),
                           Inches(row_h * len(rows))).table
    t.first_row = True
    for j, w in enumerate(col_w):
        t.columns[j].width = Inches(w)
    for i, row in enumerate(rows):
        t.rows[i].height = Inches(row_h)
        for j, v in enumerate(row):
            c = t.cell(i, j)
            c.fill.solid()
            c.fill.fore_color.rgb = RGBColor.from_string(ACC if i == 0 else ("FFFFFF" if i % 2 else "F2F8F8"))
            c.margin_left = c.margin_right = Inches(0.08)
            c.margin_top = c.margin_bottom = Inches(0.02)
            c.vertical_anchor = __import__("pptx").enum.text.MSO_ANCHOR.MIDDLE
            tf = c.text_frame
            tf.text = ""
            r = tf.paragraphs[0].add_run()
            r.text = str(v)
            tf.paragraphs[0].alignment = __import__("pptx").enum.text.PP_ALIGN.CENTER
            r.font.size = __import__("pptx").util.Pt(pt)
            r.font.name = "Malgun Gothic"
            r.font.bold = (i == 0) or (i, j) in hl
            r.font.color.rgb = RGBColor.from_string("FFFFFF" if i == 0 else hl.get((i, j), "262626"))
    return t


def card(s, x, y, w, h, head, lines, col=ACC, pt=13.5):
    b = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, x, y, w, h, ACC_L, None, name="설명 상자")
    b.adjustments[0] = 0.08
    text(s, x + 0.25, y + 0.12, w - 0.5, 0.38, head, 16, col, bold=True)
    text(s, x + 0.25, y + 0.55, w - 0.5, h - 0.65, lines, pt, "262626", anchor="t")


def eqcard(s, x, y, w, h, blocks, pt=13.5):
    """수식 상자 : blocks = [(머리, [줄, …])] — 줄 앞 '=' 이면 강조 색"""
    b = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, x, y, w, h, ACC_L, None, name="수식 상자")
    b.adjustments[0] = 0.05
    yy = y + 0.15
    for head, lines in blocks:
        text(s, x + 0.25, yy, w - 0.5, 0.36, head, 15, ACC, bold=True)
        yy += 0.42
        for ln in lines:
            hl = ln.startswith("=")
            text(s, x + 0.45, yy, w - 0.7, 0.3, ln.lstrip("="), pt, ACC_D if hl else "262626", bold=hl)
            yy += 0.31
        yy += 0.12


MATH_NOTE = ("clk 계산 (발표자 참고) : P = 651 clk (baud tick), 1 글자 = 160P = 104,160 clk = 1.0416 ms, "
             "T = 100,000,000 clk (send_go). 마커 Mk = Gk + wk + (Nk - 1)·160P + K. "
             "T = 153,609 × 651 + 541 → T ≡ -110 (mod 651) → wk = (w1 + 110(k-1)) mod 651. "
             "→ 줄마다 tx 출발이 첫 tick 까지 110 clk (1.10 us) 더 기다리고, 651 clk 가 차면 한 tick 당겨짐. "
             "측정상 101 ≤ w1 < 211 clk. 8 개 마커 모두 clk 단위까지 일치 (예 : 4 번째 = 299,375,370 clk = 2,993.7537 ms).")


def p3_b(prs, page):
    s, y0 = frame(prs, SEC2, "P3  보충 — 줄 끝 간격이 1 s 가 아닌 이유 : 데이터마다 글자 수가 다름",
                  ["마커 (줄 끝) 간격이 1,000.0011 · 993.75 ms 처럼 1 s 에서 어긋나는 이유"],
                  [[("sender 는 1 s 마다 정확히 출발 (send_go), 그런데 줄 길이가 sel 마다 다름 : 시간 ", 0), ("13", 1),
                    (" 글자 · 거리 ", 0), ("7", 1), (" · 온습도 ", 0), ("8", 1), (" 글자", 0)],
                   [("마커는 줄 '끝' → ", 0), ("간격 = 1 s + (다음 줄 - 앞 줄) 글자 수 × 1.0416 ms", 1),
                    ("   예) 시계 → 거리 = 1 s - 6 글자 = ", 0), ("993.75 ms", 1)]],
                  page, "P3-B")
    s.notes_slide.notes_text_frame.text += "\n" + MATH_NOTE
    R = "C53030"
    # ---- 위 왼쪽 : sender 가 보내는 줄 (sender_char_mux)
    text(s, 0.92, y0, 10.6, 0.36, "sender_char_mux 가 sel 마다 만드는 줄", 15, ACC, bold=True)
    fr = [["sel", "데이터", "보내는 줄 (예)", "글자 수", "o_last_idx", "줄 길이"],
          ["0 · 1 · 2", "스톱워치 · 타이머 · 시계", "00:00:01.09 + CR LF", "13", "12", "13.54 ms"],
          ["3", "거리", "123cm + CR LF", "7", "6", "7.29 ms"],
          ["4", "온습도", "55%24C + CR LF", "8", "7", "8.33 ms"]]
    table(s, 0.92, y0 + 0.42, [1.3, 2.6, 2.6, 1.1, 1.3, 1.5], fr, row_h=0.42, pt=13,
          hl={(1, 3): ACC, (2, 3): R, (3, 3): R})
    text(s, 0.92, y0 + 0.42 + 4 * 0.42 + 0.06, 10.4, 0.32, "1 글자 = start 1 + data 8 + stop 1 = 10 bit × 104.16 us = 1.0416 ms",
         12, "595959")
    # ---- 위 오른쪽 : 측정 마커 캡처
    p = Pic(s, os.path.join(IMG, "P3-B.png"), 11.9, y0 + 0.05, (19.08 - 11.9) * 295 / 1019)
    text(s, 11.9, p.y + p.h + 0.04, 7.2, 0.3, "Figure.  줄 끝 마커 (아래 = 첫 마커 기준 시각)", 11, "8C8C8C", name="Figure")
    # ---- 가운데 : 1 s 마다 출발, 줄 길이만 다름 (막대 길이 = 글자 수, 크게 그림)
    ly = y0 + 2.75
    text(s, 0.92, ly, 18.0, 0.34, "send_go 는 1 s 마다 같은 자리에서 출발 → 막대 (= 줄) 길이만 달라서 끝 (마커) 이 앞뒤로 움직임"
         "   (막대 길이 = 글자 수, 크게 그림)", 13.5, "262626", bold=True)
    seq = [("SW", 13), ("TM", 13), ("WH", 13), ("DIST", 7), ("TEMP", 8), ("SW", 13)]
    colw, u = 3.03, 0.15
    by = ly + 0.85
    ends = []
    for k, (nm, n) in enumerate(seq):
        x0 = 0.92 + k * colw
        seg(s, x0, by - 0.18, x0, by + 0.6, "8C8C8C", 1.5)
        text(s, x0, by - 0.46, 2.0, 0.28, f"send_go  +{k} s", 11, "595959", bold=True)
        col = "E6F4F3" if n == 13 else "FDECEC"
        b = shape(s, MSO_SHAPE.RECTANGLE, x0, by, n * u, 0.42, col, ACC if n == 13 else R, 1.25, name=f"줄 {k + 1}")
        set_text(b, [f"{nm} {n} 글자"], "262626", [11.5])
        xe = x0 + n * u
        seg(s, xe, by - 0.12, xe, by + 0.62, "1F6FD0", 2.5)
        ends.append(xe)

    gaps = ["1,000.00", "1,000.00", "993.75", "1,001.04", "1,005.21"]
    for k, g in enumerate(gaps):
        x1, x2 = ends[k], ends[k + 1]
        yy = by + 0.62
        seg(s, x1, yy, x2, yy, "1F6FD0", 1.25)
        hot = g != "1,000.00"
        text(s, (x1 + x2) / 2 - 0.9, yy + 0.04, 1.8, 0.32, g + " ms", 13, R if hot else "1F6FD0", bold=True, align="c")
    # ---- 아래 : 구간별 계산 = 측정
    gy = by + 1.12
    gr = [["구간", "앞 줄 → 다음 줄", "글자 수", "글자 차", "계산 : 1 s + 글자 차 × 1.0416 ms", "측정 (마커 간격)", "남는 차"],
          ["1 → 2", "SW → TM", "13 → 13", "0", "1,000.0000 ms", "1,000.0011 ms", "+1.1 us"],
          ["2 → 3", "TM → WH", "13 → 13", "0", "1,000.0000 ms", "1,000.0011 ms", "+1.1 us"],
          ["3 → 4", "WH → DIST", "13 → 7", "-6", "993.7504 ms", "993.7515 ms", "+1.1 us"],
          ["4 → 5", "DIST → TEMP", "7 → 8", "+1", "1,001.0416 ms", "1,001.0427 ms", "+1.1 us"],
          ["5 → 6", "TEMP → SW", "8 → 13", "+5", "1,005.2080 ms", "1,005.2026 ms", "-5.4 us"]]
    hl = {(3, 3): R, (4, 3): R, (5, 3): R, (3, 4): R, (4, 4): R, (5, 4): R}
    for r in range(1, 6):
        hl[(r, 5)] = ACC
    rh = min(0.36, (10.0 - gy) / len(gr))
    table(s, 0.92, gy, [1.0, 2.2, 1.5, 1.2, 4.3, 3.1, 1.6], gr, row_h=rh, pt=12.5, hl=hl)
    nx = 0.92 + 14.9 + 0.25
    text(s, nx, gy, 19.08 - nx, rh * 6 + 0.1,
         ["남는 수 us = baud tick 흔들림", "tx 는 6.51 us 간격 tick 에 맞춰", "출발 → 줄마다 +1.1 us 씩 밀리다",
          "한 칸 (6.51 us) 차면 당겨짐", "(+1.1 - 6.51 = -5.4 us)"], 11.5, "595959", anchor="t")


SLIDES = [("P1-A", p1_a), ("P1-B", p1_b), ("P2-A", p2_a), ("P2-B", p2_b), ("P3-A", p3_a), ("P3-B", p3_b),
          ("P4-A", p4_a), ("P4-B", p4_b), ("P4-C", p4_c), ("P5-A", p5_a),
          ("P6-A", p6_a), ("P6-B", p6_b), ("P6-C1", p6_c1), ("P6-D1", p6_d1), ("P6-E1", p6_e1)]


def drop_old(prs, prefix="wave:"):
    """이전에 붙인 파형 장 (제목 이름 wave:<ID>, prefix 로 시작) 지우기"""
    lst = prs.slides._sldIdLst
    for sid, sl in list(zip(list(lst), list(prs.slides))):
        if any(sh.name.startswith(prefix) for sh in sl.shapes):
            prs.part.drop_rel(sid.rId)
            lst.remove(sid)


def last_page(prs):
    """마지막 장의 쪽 번호 (오른쪽 아래 숫자) — 없으면 장 수"""
    if not len(prs.slides):
        return 0
    for sh in prs.slides[-1].shapes:
        if sh.has_text_frame and sh.text_frame.text.strip().isdigit() and abs(sh.left - Inches(18.2)) < Inches(0.05):
            return int(sh.text_frame.text)
    return len(prs.slides)


def page_of(sl, default):
    nums = [int(sh.text_frame.text) for sh in sl.shapes if sh.has_text_frame
            and sh.text_frame.text.strip().isdigit() and abs(sh.left - Inches(18.2)) < Inches(0.05)]
    return nums[0] if nums else default


def build(src, out, only=None):
    """only = None : 파형 장 전부 다시 / "P3-B" · "P3" : 그 장만 다시 만들어 원래 자리에 (없으면 맨 뒤)"""
    prs = Presentation(src)
    lst = prs.slides._sldIdLst
    pos = None                                  # 다시 넣을 자리 (sldIdLst 순번)
    if only:
        hit = [i for i, sl in enumerate(prs.slides)
               if any(sh.name.startswith("wave:" + only) for sh in sl.shapes)]
        if hit:
            pos = hit[0]
            page = page_of(prs.slides[pos], pos + 1) - 1
        drop_old(prs, "wave:" + only)
        if not hit:
            page = last_page(prs)
    else:                                       # 전부 다시 : 첫 파형 장의 쪽 번호부터 이어서
        page = len(prs.slides)
        for i, sl in enumerate(prs.slides):
            if any(sh.name.startswith("wave:") for sh in sl.shapes):
                page = page_of(sl, i + 1) - 1
                break
        drop_old(prs)
    # (11/01) 가운데 장을 지운 뒤 새 장을 붙이면 python-pptx 가 이미 있는 slideN.xml 이름을 다시 써서
    #         zip 안에 같은 이름이 2 개 생김 (파일 손상) → 지운 직후 남은 장 파일 이름을 순서대로 다시 매김
    prs.part.rename_slide_parts([sid.rId for sid in lst])
    n0 = len(lst)
    for tag, fn in SLIDES:
        if only and not tag.startswith(only):
            continue
        if not os.path.exists(os.path.join(IMG, tag + ".png")):
            print("skip (no image)", tag)
            continue
        page += 1
        fn(prs, page)
        check(prs, prs.slides[-1], tag)
        print(f"slide {page:02d}  {tag}")
    if pos is not None:                         # 새로 붙인 장을 원래 자리로
        new = list(lst)[n0:]
        for k, sid in enumerate(new):
            lst.remove(sid)
            lst.insert(pos + k, sid)
        prs.part.rename_slide_parts([sid.rId for sid in lst])
    prs.save(out)
    names = __import__("zipfile").ZipFile(out).namelist()
    dup = sorted({n for n in names if names.count(n) > 1})
    if dup:
        raise SystemExit(f"zip 안에 같은 이름 : {dup}")


def check(prs, sl, tag):
    """저장 전 검사 : 크기 음수 (PowerPoint 가 '복구' 띄움) · 슬라이드 밖으로 나간 도형 → 멈춤"""
    W, H, tol = prs.slide_width, prs.slide_height, Inches(0.05)
    bad = []
    for sh in sl.shapes:
        if sh.width < 0 or sh.height < 0:
            bad.append(f"음수 크기 {sh.name} w={sh.width / 914400:.2f} h={sh.height / 914400:.2f}")
        elif sh.left < -tol or sh.top < -tol or sh.left + sh.width > W + tol or sh.top + sh.height > H + tol:
            bad.append(f"슬라이드 밖 {sh.name} x={sh.left / 914400:.2f} y={sh.top / 914400:.2f} "
                       f"w={sh.width / 914400:.2f} h={sh.height / 914400:.2f}")
    if bad:
        raise SystemExit(f"[{tag}] 저장 안 함 :\n  " + "\n  ".join(bad))


if __name__ == "__main__":
    # python make_wave_slides.py deck.pptx [out.pptx] [--only P3]
    args = [a for a in sys.argv[1:] if not a.startswith("--only")]
    only = None
    if "--only" in sys.argv:
        only = sys.argv[sys.argv.index("--only") + 1]
        args = [a for a in args if a != only]
    build(args[0], args[1] if len(args) > 1 else args[0], only)
