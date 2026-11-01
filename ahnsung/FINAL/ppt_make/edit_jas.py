# ppt_정안성.pptx 발표 부분 (부록 앞 1 ~ 7 장) 손보기
# 사용 : python edit_jas.py ppt_정안성.pptx [out.pptx] [--only fonts|p1|p3|p5]
#   1 ~ 3 장 : 아래 회로 · 상태도 영역 (y > 3.3 in) 글자 키우기 — 도형마다 안 넘치는 가장 큰 배율 (1.3 → 1.0)
#   5 장 (P1-A) : Value 열 잘라 파형 키움 · rx 입력 글자 / FND 출력 흰 글씨 · 점선 세로선 + 시각
#   6 장 (P3-A) : 사용자 배치 (늘린 파형 · 아래 그림) 그대로, 표시만 다시 맞춤 · 파란 마커 시각 / Δ / 오차 흰 글씨
#   7 장 (P5-A) : 필요 없는 줄 · Value 열 잘라 파형 키움 · Err FND 그림 아래로 · 값 흰 글씨 · 점선 세로선
#   파형 좌표 = 캡처 png 를 가로 2000 으로 줄여 잰 값 (make_wave_slides.py 와 같음)
import os
import sys
from PIL import Image, ImageFont
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE, MSO_SHAPE_TYPE
from pptx.enum.dml import MSO_LINE_DASH_STYLE

from make_block_diagram import text, shape, set_text, seg
from make_wave_slides import (label, text_w, fnd, check, RED, YEL, ACC, IMG, _KFONT)

E = 914400
FONT_DIR = os.path.dirname(_KFONT) if _KFONT else ""
_FC = {}


def font_obj(bold):
    k = bool(bold)
    if k not in _FC:
        _FC[k] = ImageFont.truetype(os.path.join(FONT_DIR, "malgunbd.ttf" if k else "malgun.ttf"), 100)
    return _FC[k]


# ================================================================ 1 ~ 3 장 글자 키우기
def runs_of(tf):
    return [r for p in tf.paragraphs for r in p.runs]


def fits(sh, scale, sx=1.0, sy=1.0):
    """글자를 scale 배로 키웠을 때 도형 안에 들어가는지 (맑은 고딕 폭, 공백 단위 줄바꿈)"""
    tf = sh.text_frame
    w = sh.width * sx / E
    h = sh.height * sy / E
    ml = (tf.margin_left if tf.margin_left is not None else 91440) / E
    mr = (tf.margin_right if tf.margin_right is not None else 91440) / E
    mt = (tf.margin_top if tf.margin_top is not None else 45720) / E
    mb = (tf.margin_bottom if tf.margin_bottom is not None else 45720) / E
    try:
        kind = sh.auto_shape_type
    except Exception:
        kind = None
    avail = w - ml - mr
    if kind == MSO_SHAPE.OVAL:
        avail = w * 0.74 - ml - mr
    avail = min(avail, 18.75 - sh.left / E - ml)    # 둥근 확대 틀 (오른쪽 끝 약 18.8 in) 밖으로 안 나가게
    tot = 0.0
    for p in tf.paragraphs:
        rs = p.runs
        if not rs:
            tot += 12 / 72 * 1.2
            continue
        pt = max((r.font.size.pt if r.font.size else 18) for r in rs) * scale
        f = font_obj(any(r.font.bold for r in rs))
        words = "".join(r.text for r in rs).split(" ")
        lines, cur = 1, 0.0
        for wd in words:
            ww = f.getlength(wd + " ") / 100 * pt / 72
            if ww > avail + 0.02:
                return False
            if cur + ww > avail + 0.02 and cur > 0:
                lines += 1
                cur = ww
            else:
                cur += ww
        tot += lines * pt / 72 * 1.2
    room = h - mt - mb
    if kind == MSO_SHAPE.OVAL:
        room = h * 0.8
    return tot <= room + 0.04


def grow_fonts(slide, y_min=3.3, y_max=10.5, steps=(1.3, 1.25, 1.2, 1.15, 1.1)):
    n_all = n_grown = 0
    lim = []

    def walk(shapes, sx=1.0, sy=1.0, oy=0):
        nonlocal n_all, n_grown
        for sh in shapes:
            if sh.shape_type == MSO_SHAPE_TYPE.GROUP:
                walk(sh.shapes)
                continue
            top = sh.top / E
            if sh.shape_type == MSO_SHAPE_TYPE.TABLE and y_min < top < y_max:
                for row in sh.table.rows:
                    for c in row.cells:
                        for r in runs_of(c.text_frame):
                            if r.font.size and r.font.size.pt < 13:
                                r.font.size = Pt(round(r.font.size.pt * 1.2 * 2) / 2)
                continue
            if not (sh.has_text_frame and sh.text_frame.text.strip() and y_min < top < y_max):
                continue
            rs = [r for r in runs_of(sh.text_frame) if r.font.size]
            if not rs or max(r.font.size.pt for r in rs) >= 14:
                continue
            n_all += 1
            for k in steps:
                if fits(sh, k):
                    for r in rs:
                        r.font.size = Pt(round(r.font.size.pt * k * 2) / 2)
                    n_grown += 1
                    break
            else:
                lim.append(sh.text_frame.text[:30].replace("\n", " / "))

    walk(slide.shapes)
    return n_all, n_grown, lim


# ================================================================ 파형 조각 (잘라 붙이기)
class Pieces:
    """캡처 한 장을 여러 조각으로 잘라 붙임 (필요 없는 열 · 줄 빼기) — 좌표 = 가로 2000 기준 px
       xcuts = [(x0, x1), …] 왼쪽 → 오른쪽, ycuts = [(y0, y1), …] 위 → 아래"""

    def __init__(self, s, path, disp_w, xcuts, ycuts, x, y, w, gap=0.05):
        iw, ih = Image.open(path).size
        disp_h = ih * disp_w / iw
        span = sum(b - a for a, b in xcuts)
        self.k = (w - gap * (len(xcuts) - 1)) / span
        self.s, self.xs, self.ys = s, [], []
        cx = x
        for a, b in xcuts:
            self.xs.append((a, b, cx))
            cx += (b - a) * self.k + gap
        cy = y
        for a, b in ycuts:
            self.ys.append((a, b, cy))
            cy += (b - a) * self.k + gap
        self.x, self.y, self.w, self.h = x, y, w, cy - gap - y
        for a, b, px in self.xs:
            for c, d, py in self.ys:
                pic = s.shapes.add_picture(path, Inches(px), Inches(py), Inches((b - a) * self.k),
                                           Inches((d - c) * self.k))
                pic.name = "파형"
                pic.crop_left, pic.crop_right = a / disp_w, 1 - b / disp_w
                pic.crop_top, pic.crop_bottom = c / disp_h, 1 - d / disp_h

    def X(self, v):
        for a, b, p in self.xs:
            if v <= b:
                return p + (max(v, a) - a) * self.k
        a, b, p = self.xs[-1]
        return p + (b - a) * self.k

    def Y(self, v):
        for a, b, p in self.ys:
            if v <= b:
                return p + (max(v, a) - a) * self.k
        a, b, p = self.ys[-1]
        return p + (b - a) * self.k

    def ysegs(self, y1, y2):
        """세로선을 조각마다 잘라서 (빠진 줄에는 안 그림)"""
        out = []
        for a, b, p in self.ys:
            lo, hi = max(a, y1), min(b, y2)
            if lo < hi:
                out.append((p + (lo - a) * self.k, p + (hi - a) * self.k))
        return out


class Stretch:
    """사용자가 늘린 그림 (가로 · 세로 비율 다름) 그대로 좌표만"""

    def __init__(self, s, pic, disp_w, disp_h):
        self.s = s
        self.x, self.y = pic.left / E, pic.top / E
        self.kx, self.ky = pic.width / E / disp_w, pic.height / E / disp_h

    def X(self, v):
        return self.x + v * self.kx

    def Y(self, v):
        return self.y + v * self.ky

    def ysegs(self, y1, y2):
        return [(self.Y(y1), self.Y(y2))]


class StretchCut:
    """사용자가 늘린 그림 자리 (x, y, w, h) 그대로, 세로로 필요 없는 줄 (ycuts 밖) 만 빼고 이어 붙임
       — 빠진 만큼 세로 배율을 조금 늘려 전체 높이 유지"""

    def __init__(self, s, path, x, y, w, h, disp_w, disp_h, ycuts):
        self.s, self.x = s, x
        self.kx = w / disp_w
        span = sum(b - a for a, b in ycuts)
        self.ky = h / span
        self.ys = []
        cy = y
        for a, b in ycuts:
            pic = s.shapes.add_picture(path, Inches(x), Inches(cy), Inches(w), Inches((b - a) * self.ky))
            pic.name = "파형"
            pic.crop_top, pic.crop_bottom = a / disp_h, 1 - b / disp_h
            self.ys.append((a, b, cy))
            cy += (b - a) * self.ky

    def X(self, v):
        return self.x + v * self.kx

    def Y(self, v):
        for a, b, p in self.ys:
            if v <= b:
                return p + (max(v, a) - a) * self.ky
        a, b, p = self.ys[-1]
        return p + (b - a) * self.ky

    def ysegs(self, y1, y2):
        out = []
        for a, b, p in self.ys:
            lo, hi = max(a, y1), min(b, y2)
            if lo < hi:
                out.append((p + (lo - a) * self.ky, p + (hi - a) * self.ky))
        return out


# ---------------------------------------------------------------- 표시 도구 (P = Pieces · Stretch)
def dline(P, xd, y1, y2, color="FF3B3B", w=2.0):
    """점선 세로선"""
    for a, b in P.ysegs(y1, y2):
        c = seg(P.s, P.X(xd), a, P.X(xd), b, color, w)
        c.line.dash_style = MSO_LINE_DASH_STYLE.DASH
        c.name = "점선"


def wtext(P, xd, yd, t, pt=14, color="FFFFFF", align="c", bold=True, w=None):
    """흰 글씨 (바탕 없음) : align c = (xd) 가운데, l = 왼쪽 시작"""
    ww = w or (text_w(t, pt) + 0.2)
    h = pt / 72 * 1.45
    x = P.X(xd) - (ww / 2 if align == "c" else 0)
    tb = text(P.s, x, P.Y(yd) - h / 2, ww, h, t, pt, color, bold=bold, align="c" if align == "c" else "l",
              name="흰 글씨")
    return tb


def ttag(P, xd, yd, t, pt=12.5, color="C00000"):
    w = text_w(t, pt) + 0.2
    h = 0.3
    tb = text(P.s, P.X(xd) - w / 2, P.Y(yd) - h / 2, w, h, t, pt, color, bold=True, align="c", name="꼬리표")
    tb.fill.solid()
    tb.fill.fore_color.rgb = RGBColor.from_string("FFFFFF")
    tb.line.color.rgb = RGBColor.from_string(color)
    tb.line.width = Pt(1.0)


def ylabel(P, xd, yd, t, pt=13):
    h = 0.30
    return label(P.s, P.X(xd), P.Y(yd) - h / 2, t, pt, h)


def rbox(P, x1, y1, x2, y2, name="빨간 상자", color=RED, w=2.0):
    b = shape(P.s, MSO_SHAPE.ROUNDED_RECTANGLE, P.X(x1), P.Y(y1), P.X(x2) - P.X(x1), P.Y(y2) - P.Y(y1), None, color, w,
              name=name)
    b.adjustments[0] = 0.3


def oval(P, cx, cy, w, h):
    shape(P.s, MSO_SHAPE.OVAL, P.X(cx - w / 2), P.Y(cy - h / 2), P.X(cx + w / 2) - P.X(cx - w / 2),
          P.Y(cy + h / 2) - P.Y(cy - h / 2), None, RED, 2.0, name="빨간 타원")


def namebox(P, x1, y1, x2, y2):
    rbox(P, x1, y1, x2, y2, name="신호 이름")


def remove(slide, names, inside=None):
    """이름이 names 인 도형 지우기 (inside = (x0, y0, x1, y1) inch 안에 있는 '선' 만)"""
    tree = slide.shapes._spTree
    n = 0
    for sh in list(slide.shapes):
        hit = sh.name in names
        if not hit and inside and sh.name == "선":
            x0, y0, x1, y1 = inside
            hit = x0 - 0.05 <= sh.left / E <= x1 + 0.05 and y0 - 0.05 <= sh.top / E <= y1 + 0.05
        if hit:
            tree.remove(sh._element)
            n += 1
    return n


def by_name(slide, name):
    return [sh for sh in slide.shapes if sh.name == name]


def find_slide(prs, tag):
    for i, sl in enumerate(prs.slides):
        if any(sh.name == "wave:" + tag for sh in sl.shapes):
            return i, sl
    raise SystemExit(f"{tag} 장 없음")


OLD = {"이름표", "빨간 타원", "빨간 상자", "신호 이름", "꼬리표", "번호 1", "번호 2", "번호 3", "번호 4", "번호 5",
       "흰 글씨", "점선"}


# ================================================================ 5 장 P1-A
def edit_p1(prs):
    from make_block_diagram import text_runs
    _, s = find_slide(prs, "P1-A")
    old = by_name(s, "파형")[0]
    box = (old.left / E, old.top / E, (old.left + old.width) / E, (old.top + old.height) / E)
    remove(s, OLD | {"파형", "Figure"}, inside=box)
    # 결론 2 : 마지막 글자 수신 시각 (stop bit 가운데 = 5 ms + 89.5 bit = 14.32 ms)
    c2 = by_name(s, "결론 2")[0]
    x, y, w, h = c2.left / E, c2.top / E, c2.width / E, c2.height / E
    s.shapes._spTree.remove(c2._element)
    text_runs(s, x, y, w, h, [("/mod dist 9 글자 → 마지막 글자 't' 수신 (", "262626", False), ("14.32 ms", ACC, True),
                              (") 에서 disp_sel ", "262626", False), ("2 → 1", ACC, True), (", FND ", "262626", False),
                              ("---- → 000.0", ACC, True)], 20, name="결론 2")
    P = Pieces(s, os.path.join(IMG, "P1-A.png"), 2000, [(0, 200), (303, 2000)], [(0, 636)], 0.45, 3.36, 19.1)
    for y1, y2, x2 in ((125, 141, 72), (193, 213, 122), (310, 327, 98), (380, 397, 134), (426, 443, 128),
                       (564, 581, 150)):
        namebox(P, 46, y1, x2, y2)
    for xd, t in ((468, "2.0 ms"), (1450, "14.32 ms"), (1745, "18.0 ms"), (1905, "20.0 ms")):
        dline(P, xd, 75, 588)
        ttag(P, xd, 14, t)
    rbox(P, 782, 191, 1447, 215)
    oval(P, 1450, 249, 26, 26)
    oval(P, 1729, 411, 92, 24)
    rbox(P, 1744, 307, 1998, 353)
    # rx 로 들어간 글자 (글자 하나 = 1.0417 ms = 83.1 px, 5 ms = x 708 부터)
    wtext(P, 560, 157, "rx 입력 →", 14, align="l", w=1.35)
    for k, ch in enumerate(["/", "m", "o", "d", "SP", "d", "i", "s", "t"]):
        wtext(P, 708 + (k + 0.5) * 83.1, 157, ch, 16)
    # FND 출력 (화면이 바뀌는 순간 = 점선)
    wtext(P, 388, 457, "FND 00.00", 14)
    wtext(P, 959, 457, "FND 출력  ----   (온습도 화면, 측정 전)", 15)
    wtext(P, 1725, 457, "FND 출력  000.0   (거리 화면)", 15)
    ylabel(P, 712, 64, "2. rx 로 /mod dist 9 글자 입력", 12.5)
    ylabel(P, 1460, 64, "3. 't' 수신 → 거리 화면", 12.5)
    ylabel(P, 318, 157, "1. sw6 = 1 → 온습도 화면", 12.5)
    ylabel(P, 1752, 157, "4. 스위치 바꿔도 그대로", 12.5)
    # 스위치 입력 (sw[6:0] = {sw6 … sw0}) — sw 줄 바로 위 MODE 머리 줄
    for xd, t, pt in ((388, "sw 0000000", 13), (1106, "sw 1000000   (sw6 = 1 : 온습도)", 14),
                      (1825, "sw 0000000", 12.5), (1950, "sw 0010000", 11.5)):
        wtext(P, xd, 295, t, pt)
    text(s, 0.45, P.y + P.h + 0.06, 18.0, 0.3,
         "Figure.  /mod dist 0 ~ 21 ms (Value 열은 잘라 냄) — 점선 = 입력이 바뀐 순간, 그 아래 FND 출력이 무엇으로 바뀌는지 보면 됨",
         11.5, "8C8C8C", name="Figure")
    return s


# ================================================================ 6 장 P3-A (사용자 배치 그대로)
def edit_p3(prs):
    _, s = find_slide(prs, "P3-A")
    from make_block_diagram import text_runs
    pic = by_name(s, "파형")[0]
    gx, gy, gw, gh = pic.left / E, pic.top / E, pic.width / E, pic.height / E
    remove(s, OLD | {"파형"})
    # (11/02) GO_GAP_US · GO_GAP_CLK (TB 가 잰 send_go 간격) 두 줄은 빼고 이어 붙임
    P = StretchCut(s, os.path.join(IMG, "P3-A.png"), gx, gy, gw, gh, 2000, 1000, [(0, 440), (490, 1000)])
    for y1, y2, x2 in ((519, 537, 158), (645, 663, 156)):
        namebox(P, 58, y1, x2, y2)
    c1 = by_name(s, "결론 1")[0]
    x, y, w, h = c1.left / E, c1.top / E, c1.width / E, c1.height / E
    s.shapes._spTree.remove(c1._element)
    text_runs(s, x, y, w, h, [("send_go 간격 ", "262626", False), ("100,000,000 clk = 1.000 000 s", ACC, True),
                              (" (정확히 1 Hz), o_send_sel ", "262626", False), ("0 → 1 → 2 → 3 → 4 → 0", ACC, True),
                              (" — 한 바퀴 5 줄 = ", "262626", False), ("5 s", ACC, True)], 20, name="결론 1")
    ylabel(P, 400, 73, "1. /auto all 수신 → 1 s 카운트 시작", 12.5)
    ylabel(P, 545, 376, "2. 1 Hz tick → send_go (간격 1,000,000 us)", 12.5)
    ylabel(P, 800, 73, "3. sel 0 → 1 → 2 → 3 → 4 순서로 한 줄씩", 12.5)
    ylabel(P, 545, 857, "4. DHT11 부팅 1 s 뒤 측정 → 55.24", 12.5)
    # 파란 마커 (줄 끝) : 시각 · 첫 줄 기준 Δ · 오차 = Δ - (k-1) s
    mk = [536, 710, 885, 1059, 1233, 1408, 1582, 1757]
    tops = ["1,122.807", "2,122.808", "3,122.809", "4,116.560", "5,117.603", "6,122.806", "7,122.807", "8,122.808"]
    dlt = ["0 (기준)", "1,000.0011", "2,000.0022", "2,993.7537", "3,994.7964", "4,999.99899", "6,000.00009",
           "7,000.00119"]
    err = ["기준", "+1.1 us", "+2.2 us", "-6.2463 ms", "-5.2036 ms", "-1.01 us", "+0.09 us", "+1.19 us"]
    why = ["", "", "", "6 글자 짧음", "5 글자 짧음", "tick 1 칸 당김", "", ""]
    wtext(P, 383, 205, "줄 끝 = 파란 마커", 10.5, align="l", w=1.32)
    wtext(P, 383, 245, "Δ = 첫 줄 기준", 10.5, align="l", w=1.32)
    wtext(P, 383, 285, "오차 = Δ - (k-1) s", 10.5, align="l", w=1.32)
    for k, x in enumerate(mk):
        wtext(P, x + 8, 205, f"끝 {tops[k]} ms", 12, align="l", w=1.5)
        wtext(P, x + 8, 245, f"Δ {dlt[k]}", 12, align="l", w=1.5)
        wtext(P, x + 8, 285, f"오차 {err[k]}", 12.5, align="l", w=1.5, color="FFD966" if k in (3, 4) else "FFFFFF")
        if why[k]:
            wtext(P, x + 8, 323, why[k], 11, align="l", w=1.5, color="FFD966" if k in (3, 4) else "FFFFFF")
    # PC 가 받은 줄 (W_LINE) — 줄 k 값은 마커 k ~ k+1 사이
    vals = ["00:00:01.09", "00:00:57.94", "12:00:03.10", "123cm", "55%24C", "00:00:06.09", "00:00:52.94",
            "12:00:08.10"]
    mk2 = mk + [1931]
    who = ["SW", "TM", "WH", "DIST", "TEMP", "SW", "TM", "WH"]
    for k, v in enumerate(vals):
        cx = (mk2[k] + mk2[k + 1]) / 2
        t = f"{who[k]} {v}"
        w = text_w(t, 12) + 0.16
        label(s, P.X(cx) - w / 2, P.Y(684) - 0.15, t, 12, 0.30, name="이름표")
        sel = [0, 1, 2, 3, 4, 0, 1, 2][k]
        wtext(P, cx, 553, f"sel {sel} · {who[k]}", 13)
    bottom_diagram(s)
    # 맨 아래 : 실제 측정한 줄 끝 간격 (위 파란 마커 시각의 차)
    gaps = ["1,000.0011", "1,000.0011", "993.7515", "1,001.0427", "1,005.2026", "1,000.0011", "1,000.0011"]
    for k, g in enumerate(gaps):
        x1, x2 = mk[k], mk[k + 1]
        darrow(P, x1 + 3, x2 - 3, 951)
        hot = k in (2, 3, 4)
        wtext(P, (x1 + x2) / 2, 932, f"{g} ms", 12, color="FFD966" if hot else "FFFFFF")
    return s


def arrow_ends(conn, head=True, tail=True):
    """선 (connector) 에 화살촉 달기 — a:ln 안 순서 headEnd → tailEnd"""
    from lxml import etree
    from pptx.oxml.ns import qn
    ln = conn.line._get_or_add_ln()
    for tag in ("a:headEnd", "a:tailEnd"):
        old = ln.find(qn(tag))
        if old is not None:
            ln.remove(old)
    for tag, on in (("a:headEnd", head), ("a:tailEnd", tail)):
        if on:
            e = etree.SubElement(ln, qn(tag))
            e.set("type", "triangle")
            e.set("w", "med")
            e.set("len", "med")


def bottom_diagram(s, lift=0.14):
    """6 장 아래 보조 그림 (사용자가 붙인 그룹) : 파란 세로선 (줄 끝) 사이 간격선에 양쪽 화살촉 +
       send_go +0 ~ +5 s 전체 화살표 (한 바퀴 = 정확히 5 s, 5 줄 모두 이 안에 출력)"""
    from pptx.oxml.ns import qn
    gs = [sh for sh in s.shapes if sh.shape_type == MSO_SHAPE_TYPE.GROUP]
    if not gs:
        return
    g = gs[0]
    off = g._element.grpSpPr.find(qn("a:xfrm")).find(qn("a:off"))
    off.set("y", str(int(off.get("y")) - int(lift * E)))        # 그룹을 조금 위로 (전체 화살표 자리)
    oy = int(off.get("y")) / E
    cy0 = int(g._element.grpSpPr.find(qn("a:xfrm")).find(qn("a:chOff")).get("y")) / E
    gx = int(off.get("x")) / E
    cx0 = int(g._element.grpSpPr.find(qn("a:xfrm")).find(qn("a:chOff")).get("x")) / E
    go_x, go_bot, gap_y = [], 0, 0
    for sh in g.shapes:
        if sh.shape_type != MSO_SHAPE_TYPE.LINE:
            continue
        try:
            col = str(sh.line.color.rgb)
        except Exception:
            continue
        if col == "1F6FD0" and sh.height == 0:                 # 파란 간격선 → 양쪽 화살표
            arrow_ends(sh)
            gap_y = oy + sh.top / E - cy0
        if col == "8C8C8C" and sh.width == 0:                  # 회색 = send_go 출발
            go_x.append(gx + sh.left / E - cx0)
            go_bot = max(go_bot, oy + (sh.top + sh.height) / E - cy0)
    if len(go_x) < 2:
        return
    x1, x2 = min(go_x), max(go_x)
    ya = gap_y + 0.52
    for x in (x1, x2):                          # 간격 글자 (gap_y ~ +0.36) 아래부터
        c = seg(s, x, gap_y + 0.38, x, ya + 0.08, "8C8C8C", 1.25)
        c.line.dash_style = MSO_LINE_DASH_STYLE.DASH
        c.name = "전체 화살표"
    c = seg(s, x1, ya, x2, ya, ACC, 2.25)
    arrow_ends(c)
    c.name = "전체 화살표"
    t = "한 바퀴 = send_go 5 번 = 정확히 5.000 s  —  글자 수 (13 · 7 · 8) 가 달라도 5 줄 모두 이 안에 출력"
    w = text_w(t, 13) + 0.3
    tb = text(s, (x1 + x2) / 2 - w / 2, ya - 0.15, w, 0.3, t, 13, ACC, bold=True, align="c", name="전체 화살표")
    tb.fill.solid()
    tb.fill.fore_color.rgb = RGBColor.from_string("FFFFFF")


# ================================================================ 7 장 P5-A
def edit_p5(prs):
    _, s = find_slide(prs, "P5-A")
    for sh in list(s.shapes):                   # 오른쪽 FND 설명 글 · 화살표 · 세로선 지우기
        if (sh.name == "라벨" and sh.left / E > 14.5 and 3.3 < sh.top / E < 10.3) or \
                (sh.name == "선" and 3.3 < sh.top / E < 10.4):
            s.shapes._spTree.remove(sh._element)
    remove(s, OLD | {"파형", "Figure", "FND 1", "FND 2", "FND 3", "세그먼트", "점", "FND 설명", "각주"})
    P = Pieces(s, os.path.join(IMG, "P5-A.png"), 2000, [(0, 288), (432, 2000)],
               [(0, 145), (325, 508), (622, 840)], 0.45, 3.36, 19.1)
    for y1, y2, x2 in ((351, 367, 86), (374, 390, 93), (442, 458, 156), (488, 504, 150), (625, 641, 154),
                       (648, 664, 90), (809, 825, 142)):
        namebox(P, 44, y1, x2, y2)
    for xd, t in ((727, "약 48 ms  Err1"), (1112, "약 111 ms  Err2"), (1851, "약 233 ms  Err3")):
        dline(P, xd, 40, 832)
        ttag(P, xd, 14, t)
    rbox(P, 970, 370, 1114, 392)
    rbox(P, 1355, 370, 1982, 392)
    ylabel(P, 560, 336, "1. Err1 : echo 안 옴 → 30 ms", 12.5)
    ylabel(P, 975, 336, "2. Err2 : echo 23.25 ms (너무 김)", 12.5)
    ylabel(P, 1395, 336, "3. Err3 : echo 계속 1 (고착)", 12.5)
    ylabel(P, 860, 60, "4. /get 마다 PC 로 Err 1 · Err 2 · Err 3", 12.5)
    # 보여 줄 값 (흰 글씨)
    for xd, t in ((919, "status 1 : 무응답"), (1481, "status 2 : 범위 밖"), (1915, "status 3 : 고착")):
        wtext(P, xd, 473, t, 13)
    for xd, t in ((582, "FND 000.0"), (919, "FND Err1"), (1481, "FND Err2"), (1925, "FND Err3")):
        wtext(P, xd, 680, t, 14)
    for xd, t in ((1065, "PC ← Err 1"), (1626, "PC ← Err 2")):
        wtext(P, xd, 795, t, 13)
    text(s, 0.45, P.y + P.h + 0.05, 19.0, 0.3,
         "Figure.  P5 0 ~ 258 ms — UART RX · FND 스캔 줄과 Value 열은 잘라 냄, 빨간 점선 = 오류 판정 (w_dist_done)",
         11.5, "8C8C8C", name="Figure")
    # Err FND 그림 → 아래 줄
    fy = P.y + P.h + 0.42
    items = [("Err1", "Err1  무응답", "trig↓ + 30 ms 에 판정 · LD9 · PC Err 1"),
             ("Err2", "Err2  범위 밖", "echo↑ + 23.2 ms (400 cm) 에 판정 · PC Err 2"),
             ("Err3", "Err3  echo 고착", "trig↓ + 73.2 ms 에 판정 · 강제 IDLE · PC Err 3")]
    for i, (dg, head, body) in enumerate(items):
        x = 0.45 + i * 6.37
        fnd(s, x, fy, 1.6, dg, name=f"FND {i + 1}")
        text(s, x + 1.8, fy - 0.04, 4.4, 0.34, head, 14, "C53030", bold=True, name="FND 설명")
        text(s, x + 1.8, fy + 0.3, 4.4, 0.34, body, 12, "404040", name="FND 설명")
    # * echo 는 TB 센서 모델이 만든 핀 파형 (각주)
    wtext(P, 106, 382, "*", 16, color="FFD966", align="l", w=0.25)
    text(s, 0.45, 10.16, 17.5, 0.42,
         ["* echo 는 실제 센서 대신 TB 센서 모델 (tb_merge_harness) 이 만든 핀 파형 : trig↓ 뒤 0.5 ms 에 echo = 1 → "
          "거리 × 58 us 동안 유지 (예 : 123 cm = 7,134 us)",
          "   Err1 = echo 를 안 줌 · Err2 = 폭 23,250 us 로 길게 · Err3 = TB 가 trig 전부터 echo = 1 로 고정 (152 ms) → 255 ms 에 풂"],
         11, "595959", anchor="t", name="각주")
    return s


def darrow(P, x1, x2, yd, color="FFFFFF", w=1.75):
    """양쪽 화살표 (가로)"""
    from lxml import etree
    from pptx.oxml.ns import qn
    c = seg(P.s, P.X(x1), P.Y(yd), P.X(x2), P.Y(yd), color, w, arrow=True)
    ln = c.line._get_or_add_ln()
    he = etree.SubElement(ln, qn("a:headEnd"))
    he.set("type", "triangle")
    he.set("w", "med")
    he.set("len", "med")
    ln.remove(he)
    ln.insert(list(ln).index(ln.find(qn("a:tailEnd"))), he)   # headEnd 는 tailEnd 앞
    c.name = "간격 화살표"


# ================================================================ 8 장 P6-A (DHT11) — 7 장과 같은 방식
def edit_p6(prs):
    _, s = find_slide(prs, "P6-A")
    for sh in list(s.shapes):                   # 오른쪽 FND 설명 글 · 화살표 · 세로선 지우기
        if (sh.name == "라벨" and sh.left / E > 14.5 and 3.3 < sh.top / E < 10.3) or \
                (sh.name == "선" and 3.3 < sh.top / E < 10.4):
            s.shapes._spTree.remove(sh._element)
    remove(s, OLD | {"파형", "Figure", "FND 1", "FND 2", "FND 3", "FND 4", "세그먼트", "점", "FND 설명", "각주"})
    # 남길 줄 : 눈금 · TB / DHT11 묶음 / FND · LED / UART TX (send_data · push 빼고), Value 열 빼고
    P = Pieces(s, os.path.join(IMG, "P6-A.png"), 2000, [(0, 193), (280, 2000)],
               [(0, 147), (333, 588), (588, 727), (774, 838)], 1.15, 3.36, 17.7, gap=0.04)
    for y1, y2, x2 in ((359, 375, 100), (382, 398, 108), (475, 491, 146), (614, 630, 146), (800, 816, 130)):
        namebox(P, 38, y1, x2, y2)
    for xd, t in ((644, "1.000 s 측정 → Err1"), (1322, "3.000 s 측정 → Err2")):
        dline(P, xd, 40, 832)
        ttag(P, xd, 14, t)
    ylabel(P, 655, 344, "1. 부팅 1 s → 시작 LOW 18 ms → 응답 없음 → Err1", 12.5)
    ylabel(P, 1335, 344, "2. + 2 s → 20 비트 뒤 끊김 → Err2", 12.5)
    ylabel(P, 292, 65, "3. 측정 전 /get → --%--C", 12.5)
    ylabel(P, 700, 65, "4. 오류마다 /get → PC 로 Err 1 · Err 2", 12.5)
    for xd, t in ((986, "status 1 : 응답 없음"), (1661, "status 2 : 중간 끊김")):
        wtext(P, xd, 507, t, 13)
    for xd, t in ((463, "FND ----"), (986, "FND Err1"), (1661, "FND Err2")):
        wtext(P, xd, 600, t, 14)
    for xd, t in ((470, "PC ← --%--C"), (1015, "PC ← Err 1"), (1692, "PC ← Err 2")):
        wtext(P, xd, 785, t, 13)
    wtext(P, 102, 367, "*", 16, color="FFD966", align="l", w=0.25)
    text(s, P.x, P.y + P.h + 0.05, 17.7, 0.3,
         "Figure.  P6 0 ~ 5 s — UART RX 줄 · Value 열 · send_data / push 줄은 잘라 냄, 빨간 점선 = 측정 시작 (2 s 간격) · Err3 (5.0 s) 는 이 캡처 밖",
         11.5, "8C8C8C", name="Figure")
    fy = P.y + P.h + 0.42
    items = [("----", "측정 전", "0 ~ 1 s · PC --%--C"),
             ("Err1", "Err1  응답 없음", "1.018 s · 선 놓은 뒤 응답 없음 · PC Err 1"),
             ("Err2", "Err2  중간 끊김", "3.020 s · 20 비트 뒤 0.2 ms 끊김 · PC Err 2"),
             ("Err3", "Err3  체크섬", "5.022 s · 40 비트 다 받았지만 체크섬 틀림 · PC Err 3")]
    for i, (dg, head, body) in enumerate(items):
        x = 0.45 + i * 4.8
        fnd(s, x, fy, 1.45, dg, name=f"FND {i + 1}")
        text(s, x + 1.6, fy - 0.04, 3.1, 0.34, head, 14, "404040" if i == 0 else "C53030", bold=True, name="FND 설명")
        text(s, x + 1.6, fy + 0.3, 3.1, 0.6, body, 11.5, "404040", anchor="t", name="FND 설명")
    text(s, 0.45, 10.22, 17.6, 0.4,
         ["* dht11_io 의 센서 응답은 TB 센서 모델 (tb_merge_harness) 이 만든 파형 : FPGA 가 선을 18 ms LOW 로 잡았다 놓으면 "
          "30 us 뒤 LOW 80 · HIGH 80 us + 40 비트 (0 = HIGH 26 us, 1 = 70 us)",
          "   Err1 = 응답 안 함 · Err2 = 20 비트만 보내고 멈춤 · Err3 = 체크섬에 +1"], 10.5, "595959", anchor="t", name="각주")
    return s


# ================================================================ 8 장 : Top 검증 정리 (시나리오 PASS)
def add_pass_slide(prs):
    from make_wave_slides import frame, table, ACC_L
    for sl in list(prs.slides):                 # 다시 돌리면 이전 것 지우기
        if any(sh.name == "wave:PASS" for sh in sl.shapes):
            lst = prs.slides._sldIdLst
            for sid in list(lst):
                if prs.part.related_part(sid.rId) is sl.part:
                    prs.part.drop_rel(sid.rId)
                    lst.remove(sid)
    _, p5 = find_slide(prs, "P5-A")
    pos = list(prs.slides).index(p5) + 1
    s, y0 = frame(prs, "03  Top · 시뮬레이션   검증 정리",
                  "Top 검증 정리 — 시나리오 92 개 · 검사 596 건 모두 PASS",
                  ["파형으로 다 못 보여 준 명령 · 센서 조합을 자동 판정 TB 로 확인한 결과"],
                  [[("그룹 TB 12 개 · 시나리오 92 개 · 검사 ", 0), ("305 건 PASS", 1), (" + 통합 TB (겹치지 않는 검사) ", 0),
                    ("291 건 PASS", 1), ("  →  합계 ", 0), ("PASS 596 · FAIL 0", 1)],
                   [("파형 장 (P1 · P3 · P5) 밖의 조합은 TB 가 기대값과 자동 비교 — 기준 : ", 0),
                    ("결함 8 건 수정한 최종 설계", 1), (" (LUT 1,476 · WNS +1.442 ns)", 0)]],
                  pos + 1, "PASS")
    # 왼쪽 : 그룹 TB 12 개
    text(s, 0.92, y0, 10.6, 0.36, "그룹 TB 12 개 (FINAL/sim_file, 자동 판정)", 15, ACC, bold=True)
    rows = [["TB", "영역", "시나리오", "검사", "결과"],
            ["A", "리셋 · 공통", "2", "14", "PASS"], ["B", "버튼 · 디바운스", "5", "14", "PASS"],
            ["C", "모드 선택 (스위치 ↔ UART)", "8", "30", "PASS"], ["D", "스톱워치", "7", "15", "PASS"],
            ["E", "시계", "6", "23", "PASS"], ["F", "타이머", "6", "16", "PASS"],
            ["G", "UART 수신 · 디코더", "9", "52", "PASS"], ["H", "UART 컨트롤러 · 전송", "12", "31", "PASS"],
            ["I", "SR04 거리", "11", "26", "PASS"], ["J", "DHT11 온습도", "14", "30", "PASS"],
            ["K", "FND · LED", "6", "28", "PASS"], ["L", "통합 · 교차", "6", "26", "PASS"],
            ["합계", "12 / 12 PASS", "92", "305", "FAIL 0"]]
    hl = {(r, 4): ACC for r in range(1, 14)}
    hl.update({(13, c): ACC for c in range(5)})
    rh = min(0.43, (10.25 - (y0 + 0.42)) / len(rows))
    table(s, 0.92, y0 + 0.42, [0.9, 4.6, 1.5, 1.3, 2.3], rows, row_h=rh, pt=13.5, hl=hl)
    # 오른쪽 위 : 큰 숫자
    rx = 12.0
    cw = (19.08 - rx - 0.4) / 3
    for i, (big, small, col) in enumerate((("596", "PASS (검사)", ACC), ("0", "FAIL", "C53030"), ("12 / 12", "그룹 TB PASS", ACC))):
        x = rx + i * (cw + 0.2)
        b = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, x, y0, cw, 1.35, ACC_L, None, name="큰 숫자")
        b.adjustments[0] = 0.12
        text(s, x, y0 + 0.08, cw, 0.8, big, 40, col, bold=True, align="c")
        text(s, x, y0 + 0.88, cw, 0.36, small, 14, "404040", bold=True, align="c")
    # 오른쪽 아래 : UART 명령 · 센서 조합 대표 시나리오
    ty = y0 + 1.6
    text(s, rx, ty, 19.08 - rx, 0.36, "명령 · 센서 조합 → 대표 시나리오 (그룹 TB ID)", 15, ACC, bold=True)
    r2 = [["조합", "ID", "검사", "결과"],
          ["정상 명령 24 종 (/mod /set /off /get /auto /btn)", "G1", "24", "PASS"],
          ["형식 오류 10 종 → ERROR 1 줄", "G2", "10", "PASS"],
          ["/mod 8 종 → 화면 비트", "C4", "8", "PASS"],
          ["/auto 1 Hz 주기 · all 순서", "H4 · H5", "6", "PASS"],
          ["응답 형식 (Err N · --%--C)", "H10", "5", "PASS"],
          ["SR04 Err1 · Err2 · Err3", "I4 · I3 · I5", "5", "PASS"],
          ["DHT11 Err1 · Err2 · Err3", "J7 · J8 · J6", "6", "PASS"],
          ["통합 TB 랜덤 명령 · 송신 MUX", "tb_top_full", "558", "불일치 0"]]
    hl2 = {(r, 3): ACC for r in range(1, 9)}
    rh2 = min(0.42, (9.7 - (ty + 0.42)) / len(r2))
    table(s, rx, ty + 0.42, [3.95, 1.25, 0.85, 1.03], r2, row_h=rh2, pt=12.5, hl=hl2)
    text(s, rx, 9.75, 19.08 - rx, 0.6,
         ["그룹 TB 는 FAST = 1 (시간 축소) 로 돌리고 판정은 실제 시간 비율로 계산",
          "수정 전 설계의 ISSUE 8 건 (D7 · E6 · G3 · G7 · H7 · H9 · J14 · L6) → 수정 후 모두 PASS"], 11, "8C8C8C",
         anchor="t")
    # 부록 앞 자리로
    lst = prs.slides._sldIdLst
    sid = list(lst)[-1]
    lst.remove(sid)
    lst.insert(pos, sid)
    prs.part.rename_slide_parts([x.rId for x in lst])
    return s


# ================================================================ 실행
def main(src, out, only=None):
    prs = Presentation(src)
    if only in (None, "fonts"):
        for idx in (0, 1, 2, 3):
            n, g, lim = grow_fonts(prs.slides[idx])
            print(f"slide {idx + 1} : 글자 키움 {g} / {n}" + (f"  (못 키움 : {lim})" if lim else ""))
            for sh in prs.slides[idx].shapes:          # 맑은 고딕에 없는 글자
                if sh.has_text_frame:
                    for r in runs_of(sh.text_frame):
                        if "⇄" in r.text:
                            r.text = r.text.replace("⇄", "↔")
    for key, fn, tag in (("p1", edit_p1, "P1-A"), ("p3", edit_p3, "P3-A"), ("p5", edit_p5, "P5-A"),
                         ("p6", edit_p6, "P6-A")):
        if only in (None, key) and not (only is None and key == "p6"):
            sl = fn(prs)
            check(prs, sl, tag)
            print(f"{tag} 고침")
    if only in (None, "pass"):
        sl = add_pass_slide(prs)
        check(prs, sl, "PASS")
        print("PASS 장 추가")
    prs.save(out)
    names = __import__("zipfile").ZipFile(out).namelist()
    dup = sorted({n for n in names if names.count(n) > 1})
    if dup:
        raise SystemExit(f"zip 안에 같은 이름 : {dup}")


if __name__ == "__main__":
    a = [x for x in sys.argv[1:] if not x.startswith("--only")]
    only = None
    if "--only" in sys.argv:
        only = sys.argv[sys.argv.index("--only") + 1]
        a = [x for x in a if x != only]
    main(a[0], a[1] if len(a) > 1 else a[0], only)
