# UART 동작 구조 장표 (파형 장 앞) : 블록도 ↔ 상태도 연결, RX → 디코더 → 컨트롤러 → 송신 → TX 와 모듈 안쪽까지
# 사용 : python make_uart_slides.py merge_final_block_diagram_wave_v2.pptx [out.pptx]
#   - 첫 파형 장 (제목 이름 "wave:…") 바로 앞에 끼움, 뒤 장 쪽 번호는 밀어서 다시 매김
#   - 다시 돌려도 됨 : 이전에 끼운 장 (제목 이름 "uart:<ID>") 은 지우고 새로
#   - 형식 : make_wave_slides.py 와 같은 틀 (청록 머리말 · 제목 30 pt · 핵심 상자) + Vivado 회로도처럼
#            맨 위 작은 지도 (지금 보는 모듈 칸 진하게) → 점선 확대 틀 → 안쪽 회로 · 상태도
#   - 근거 RTL : merge_final_v2 (UART 폴더) + sender_char_mux J14 수정본 (Err · --%--C · 99 고정)
import os
import sys
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.dml import MSO_LINE_DASH_STYLE

from make_block_diagram import text, text_runs, shape, set_text, seg, trap, HEADER, FONT_TITLE, DOM
from make_wave_slides import text_w, table, check

U, UL = DOM["uart"]                 # 2C7A7B · E6F4F3
UD = "1D5354"
INK = "262626"
G, GL, GM = "4A5568", "F3F4F6", "A0A7B0"
OFF_LN, OFF_FILL, OFF_TXT = "D5D9DE", "F7F8F9", "A0A7B0"
RED, REDL = DOM["err"]
AMB, AMBL = "B7791F", "FFF4DC"      # 디코더 : 같이 쓰는 상태 (e · t · o)
PUR, PURL = DOM["disp"]             # Top (uart_top 밖)
ZOOM_BG = "F8FBFB"
SEC = "02  시스템 구조 · UART 동작"


# ---------------------------------------------------------------- 기본 도구
def T(s, x, y, w, h, t, sz=12, c=INK, b=False, al="l", anchor="m", name="라벨"):
    return text(s, x, y, w, h, t, sz, c, bold=b, align=al, anchor=anchor, name=name)


def box(s, x, y, w, h, lines, sizes, fill="FFFFFF", line=U, tc=INK, lw=1.25, rounded=True, bold=True, al="c",
        name="상자"):
    sh = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE if rounded else MSO_SHAPE.RECTANGLE, x, y, w, h, fill, line, lw,
               name=name)
    if lines:
        set_text(sh, lines if isinstance(lines, list) else [lines], tc,
                 sizes if isinstance(sizes, list) else [sizes], bold=bold, align=al)
    return sh


def state(s, x, y, w, h, name, sub=None, fill="FFFFFF", line=U, tc=INK, sz=14, ssz=10.5, lw=2.0):
    sh = shape(s, MSO_SHAPE.OVAL, x, y, w, h, fill, line, lw, name=f"상태 {name}")
    lines, sizes = [name], [sz]
    if sub:
        lines.append(sub)
        sizes.append(ssz)
    set_text(sh, lines, tc, sizes)
    sh.text_frame.margin_left = sh.text_frame.margin_right = 0
    return sh


def poly(s, pts, c=G, w=1.75, arrow=True, dash=False):
    for i in range(len(pts) - 1):
        (x1, y1), (x2, y2) = pts[i], pts[i + 1]
        seg(s, x1, y1, x2, y2, c, w, arrow=(arrow and i == len(pts) - 2), dash=dash)


def pill(s, x, y, t, fill=U, tc="FFFFFF", sz=11, h=0.3, pad=0.2, name="태그"):
    w = text_w(t, sz) + pad
    b = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, x, y, w, h, fill, None, name=name)
    b.adjustments[0] = 0.5
    set_text(b, [t], tc, [sz])
    return w


def gate(s, x, y, sym, w=0.55, h=0.5, line=G, fill="FFFFFF", tc=INK):
    g = shape(s, MSO_SHAPE.FLOWCHART_DELAY, x, y, w, h, fill, line, 1.5, name=f"게이트 {sym}")
    set_text(g, [sym], tc, [11])
    return g


def inv(s, x, y, c=G):
    """입력 쪽 NOT 동그라미 (가운데 x, y)"""
    r = 0.06
    shape(s, MSO_SHAPE.OVAL, x - r, y - r, 2 * r, 2 * r, "FFFFFF", c, 1.25, name="NOT")


def dot(s, x, y, c=G):
    r = 0.045
    shape(s, MSO_SHAPE.OVAL, x - r, y - r, 2 * r, 2 * r, c, None, name="접점")


def ff(s, x, y, w, h, lines, sizes, line=G, fill="FFFFFF", tc=INK):
    """레지스터 (FF) : 사각형 + 왼쪽 아래 클럭 삼각"""
    b = box(s, x, y, w, h, lines, sizes, fill, line, tc, rounded=False, name="레지스터")
    tri = shape(s, MSO_SHAPE.ISOSCELES_TRIANGLE, x, y + h - 0.2, 0.14, 0.16, None, line, 1.0, name="클럭")
    tri.rotation = 90
    return b


def cell(s, x, y, w, h, inst, mod, on=True, sz=12.5):
    """Vivado 회로도 셀 : 위에 인스턴스 이름, 사각 테두리 (모듈 이름은 안쪽 왼쪽 위)"""
    ln = U if on else OFF_LN
    tc = U if on else OFF_TXT
    shape(s, MSO_SHAPE.RECTANGLE, x, y, w, h, "FFFFFF" if on else OFF_FILL, ln, 2.0 if on else 1.25,
          name=f"셀 {inst}")
    T(s, x, y - 0.3, w, 0.28, inst, 11, tc, True, name=f"인스턴스 {inst}")
    T(s, x + 0.1, y + 0.06, w - 0.2, 0.3, mod, sz, INK if on else OFF_TXT, True, name=f"모듈 {mod}")


def sub(s, x, y, w, h, lines, sizes, on=True, hl=False):
    """셀 안 하위 블록 : hl = 이 장에서 확대해 보는 부분"""
    if hl:
        return box(s, x, y, w, h, lines, sizes, UL, U, INK, 1.75)
    if on:
        return box(s, x, y, w, h, lines, sizes, GL, "8A94A3", INK, 1.0)
    return box(s, x, y, w, h, lines, sizes, OFF_FILL, OFF_LN, OFF_TXT, 1.0)


def note(s, x, y, w, h, lines, sz=12, c=INK, fill=UL, name="설명"):
    b = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, x, y, w, h, fill, None, name=name)
    b.adjustments[0] = 0.12
    T(s, x + 0.15, y + 0.06, w - 0.3, h - 0.12, lines, sz, c, anchor="m")
    return b


def runs(s, x, y, w, h, parts, sz=12, al="l"):
    """parts = [(글자, 색, 굵게)]"""
    return text_runs(s, x, y, w, h, parts, sz, align=al)


# ---------------------------------------------------------------- 틀
def frame(prs, title, concl, page, tag, notes):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    T(s, 13.6, 0.22, 6.0, 0.3, HEADER, 10.5, "8C8C8C", al="r")
    shape(s, MSO_SHAPE.OVAL, 0.92, 0.55, 0.14, 0.14, U, None, name="shape")
    T(s, 1.14, 0.44, 12.0, 0.34, SEC, 12.5, U, True)
    t = T(s, 0.92, 0.78, 18.2, 0.72, title, 30, INK)
    t.text_frame.paragraphs[0].runs[0].font.name = FONT_TITLE
    t.name = "uart:" + tag
    by = 1.62
    bh = 0.42 + 0.38 * len(concl)
    b = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, 2.15, by, 16.93, bh, UL, None, name="핵심 상자")
    b.adjustments[0] = 0.3
    c = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, 0.92, by + (bh - 0.5) / 2, 1.15, 0.50, UD, None, name="핵심 칩")
    c.adjustments[0] = 0.3
    set_text(c, ["핵심"], "FFFFFF", [16])
    for i, rr in enumerate(concl):
        text_runs(s, 2.40, by + 0.21 + i * 0.38, 16.6, 0.38,
                  [(r, U if k else INK, bool(k)) for r, k in rr], 18, name=f"핵심 {i + 1}")
    T(s, 18.2, 10.62, 0.9, 0.35, f"{page:02d}", 11, "8C8C8C", al="r")
    s.notes_slide.notes_text_frame.text = notes
    return s, by + bh


# 작은 지도 : uart_top 안 순서 그대로 (Vivado 에서 위 계층을 보는 것처럼)
MAP = [("pc", "PC rx"), ("rx", "uart_rx"), ("frx", "FIFO RX"), ("dec", "DECODER"), ("ctl", "CONTROLLER"),
       ("snd", "SENDER"), ("ftx", "FIFO TX"), ("tx", "uart_tx"), ("pc2", "PC tx")]


def minimap(s, y, on, zoom_y, zoom_h=None):
    """y : 지도 줄 위쪽. on : 진하게 칠할 칸. 확대 틀 (zoom_y ~ 10.45) 과 점선 깔때기로 이음 → 틀 좌표"""
    x0, x1, h = 0.92, 19.08, 0.4
    ws = [1.1 if k.startswith("pc") else (1.75 if k in ("ftx", "frx") else 2.05) for k, _ in MAP]
    gap = (x1 - x0 - sum(ws)) / (len(MAP) - 1)
    pos, x = {}, x0
    for (k, nm), w in zip(MAP, ws):
        if k in on:
            b = box(s, x, y, w, h, nm, 12, U, U, "FFFFFF", 1.5, name=f"지도 {nm}")
        elif k.startswith("pc"):
            b = box(s, x, y, w, h, nm, 11, "FFFFFF", GM, G, 1.0, name=f"지도 {nm}")
        else:
            b = box(s, x, y, w, h, nm, 11, OFF_FILL, OFF_LN, OFF_TXT, 1.0, name=f"지도 {nm}")
        pos[k] = (x, w)
        x += w + gap
    for i in range(len(MAP) - 1):
        xa = pos[MAP[i][0]][0] + pos[MAP[i][0]][1]
        xb = pos[MAP[i + 1][0]][0]
        hot = MAP[i][0] in on and MAP[i + 1][0] in on
        seg(s, xa + 0.03, y + h / 2, xb - 0.03, y + h / 2, U if hot else GM, 1.75 if hot else 1.0, arrow=True)
    ks = [k for k, _ in MAP if k in on]
    lx = pos[ks[0]][0]
    rx = pos[ks[-1]][0] + pos[ks[-1]][1]
    zh = zoom_h or (10.45 - zoom_y)
    fr = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, x0, zoom_y, x1 - x0, zh, ZOOM_BG, U, 1.0, name="확대 틀")
    fr.adjustments[0] = 0.02
    fr.line.dash_style = MSO_LINE_DASH_STYLE.DASH
    seg(s, lx, y + h, x0 + 0.1, zoom_y, U, 1.0, dash=True)
    seg(s, rx, y + h, x1 - 0.1, zoom_y, U, 1.0, dash=True)
    return pos


def zoom_tag(s, x, y, page):
    pill(s, x, y, f"확대 ▶ {page:02d}", UD, "FFFFFF", 10.5, 0.27, 0.18, name="확대 표시")


# ---------------------------------------------------------------- U0 개요
def u0(prs, page, P):
    s, yb = frame(prs, "UART 내부 — PC 명령이 RX → 디코더 → 컨트롤러 → 송신 → TX 로 도는 길",
                  [[("rx 한 글자 = ", 0), ("10 비트 ≈ 1.04 ms", 1), (" → FIFO → 디코더가 ", 0), ("글자마다 상태 이동", 1),
                    (" → 명령 끝에 ", 0), ("handshake 1 clk", 1), (" → 컨트롤러가 모드 · 버튼 · 전송을 결정", 0)],
                   [("전송은 ", 0), ("send_sel", 1), (" 로 Top 의 데이터 MUX 를 고르고 ", 0), ("send_go 1 clk", 1),
                    (" → sender 가 한 clk 에 한 글자씩 TX FIFO → uart_tx → PC", 0)]],
                  page, "U0",
                  "uart_top 한 장 지도. 상자 안 작은 칸 = 그 모듈 안의 하위 블록 (Vivado 회로도에서 셀을 펼친 모양). "
                  "오른쪽 아래 '확대 ▶ 쪽' 은 그 모듈을 확대한 장. 위쪽 줄 = 수신, 아래쪽 줄 = 송신, 가운데 컨트롤러가 둘을 잇는다.")
    ya, yb2, h = 3.55, 6.95, 2.3          # 수신 줄 · 송신 줄 위쪽, 높이
    C = {"pc": (0.92, 1.2), "c1": (2.72, 2.9), "c2": (6.47, 1.6), "c3": (8.92, 3.2), "c4": (13.32, 3.2), "c5": (17.27, 1.81)}

    def X(k):
        return C[k][0]

    def R(k):
        return C[k][0] + C[k][1]
    # PC
    pcb = box(s, 0.92, ya, 1.2, yb2 + h - ya, ["PC", "터미널", "", "9600", "8N1"], [15, 12, 8, 11, 11], "FFFFFF", G,
              INK, 1.5, name="PC")
    # 수신 줄 ---------------------------------------------------------
    cell(s, X("c1"), ya, C["c1"][1], h, "U_UART_RX", "uart_rx")
    sub(s, X("c1") + 0.15, ya + 0.45, 2.6, 0.55, ["FSM", "IDLE → START → DATA → STOP"], [11, 10], hl=True)
    sub(s, X("c1") + 0.15, ya + 1.1, 1.25, 0.5, ["b_tick_cnt", "0 ~ 15"], [10.5, 10])
    sub(s, X("c1") + 1.5, ya + 1.1, 1.25, 0.5, ["bit_cnt", "0 ~ 7"], [10.5, 10])
    sub(s, X("c1") + 0.15, ya + 1.7, 1.6, 0.45, ["data_reg [7:0]"], [10.5])
    zoom_tag(s, R("c1") - 1.02, ya + h - 0.35, P["U1"])

    cell(s, X("c2"), ya, C["c2"][1], h, "U_FIFO_RX", "fifo")
    sub(s, X("c2") + 0.15, ya + 0.45, 1.3, 0.6, ["control", "wptr · rptr"], [10.5, 10])
    sub(s, X("c2") + 0.15, ya + 1.15, 1.3, 0.6, ["reg file", "8 × 8 bit"], [10.5, 10])
    zoom_tag(s, R("c2") - 1.02, ya + h - 0.35, P["U1"])

    cell(s, X("c3"), ya, C["c3"][1], h, "U_ASCII_DECODER", "UART_ASCII_DECODER", sz=12)
    sub(s, X("c3") + 0.15, ya + 0.45, 2.9, 0.55, ["FSM  IDLE → / → 명령 글자 → SPACE"], [11], hl=True)
    sub(s, X("c3") + 0.15, ya + 1.1, 1.4, 0.5, ["깃발 6 개", "get · mod · btn …"], [10.5, 9.5])
    sub(s, X("c3") + 1.65, ya + 1.1, 1.4, 0.5, ["data_reg", "40 bit (5 글자)"], [10.5, 9.5])
    sub(s, X("c3") + 0.15, ya + 1.7, 1.9, 0.45, ["handshake · error"], [10.5])
    zoom_tag(s, R("c3") - 1.02, ya + h - 0.35, P["U2"])

    # 컨트롤러 (가운데 세로로 김)
    cell(s, X("c4"), ya, C["c4"][1], yb2 + h - ya, "U_CONTROL", "UART_CONTROLLER")
    cx, cw = X("c4") + 0.15, C["c4"][1] - 0.3
    sub(s, cx, ya + 0.45, cw, 0.85, ["모드 FSM", "MODE_IDLE → MODE", "→ module_control_bit · uart_mode"],
        [11.5, 10, 10], hl=True)
    zoom_tag(s, cx + cw - 1.0, ya + 1.32, P["U3"])
    sub(s, cx, ya + 1.75, cw, 1.15, ["송신 FSM", "IDLE · GET ⇄ AUTO_* 6 → AUTO_OFF", "pend · error 우선 · busy 막기"],
        [11.5, 10, 10], hl=True)
    zoom_tag(s, cx + cw - 1.0, ya + 2.92, P["U4"])
    sub(s, cx, ya + 3.4, cw * 0.48, 0.6, ["sender_tick", "1 Hz"], [10.5, 10])
    sub(s, cx + cw * 0.52, ya + 3.4, cw * 0.48, 0.6, ["scan 카운터", "0 → 4"], [10.5, 10])
    sub(s, cx, ya + 4.15, cw, 0.6, ["버튼 래치 R · L · U · D", "물리 버튼 먼저"], [10.5, 10])
    sub(s, cx, ya + 4.9, cw, 0.5, ["sender_data = go ? i_send_data : 0"], [10])

    # 송신 줄 (오른쪽 → 왼쪽) -----------------------------------------
    cell(s, X("c3"), yb2, C["c3"][1], h, "U_ASCII_SENDER", "uart_sender")
    sub(s, X("c3") + 0.15, yb2 + 0.45, 2.9, 0.55, ["FSM  IDLE ⇄ SEND"], [11], hl=True)
    sub(s, X("c3") + 0.15, yb2 + 1.1, 1.4, 0.5, ["sel · data 잡기", "go 순간"], [10.5, 9.5])
    sub(s, X("c3") + 1.65, yb2 + 1.1, 1.4, 0.5, ["c_idx", "몇 번째 글자"], [10.5, 9.5])
    sub(s, X("c3") + 0.15, yb2 + 1.7, 1.9, 0.45, ["sender_char_mux"], [10.5])
    zoom_tag(s, R("c3") - 1.02, yb2 + h - 0.35, P["U5"])

    cell(s, X("c2"), yb2, C["c2"][1], h, "U_FIFO_TX", "fifo")
    sub(s, X("c2") + 0.15, yb2 + 0.45, 1.3, 0.6, ["control", "wptr · rptr"], [10.5, 10])
    sub(s, X("c2") + 0.15, yb2 + 1.15, 1.3, 0.6, ["reg file", "64 × 8 bit"], [10.5, 10])
    zoom_tag(s, R("c2") - 1.02, yb2 + h - 0.35, P["U5"])

    cell(s, X("c1"), yb2, C["c1"][1], h, "U_UART_TX", "uart_tx")
    sub(s, X("c1") + 0.15, yb2 + 0.45, 2.6, 0.55, ["FSM", "IDLE → START → DATA → STOP"], [11, 10], hl=True)
    sub(s, X("c1") + 0.15, yb2 + 1.1, 1.25, 0.5, ["b_tick_cnt", "0 ~ 15"], [10.5, 10])
    sub(s, X("c1") + 1.5, yb2 + 1.1, 1.25, 0.5, ["bit_cnt", "0 ~ 7"], [10.5, 10])
    sub(s, X("c1") + 0.15, yb2 + 1.7, 1.6, 0.45, ["data_reg ▶ tx"], [10.5])
    zoom_tag(s, R("c1") - 1.02, yb2 + h - 0.35, P["U5"])

    # baud (가운데)
    bx, by_, bw, bh = X("c1") + 0.35, ya + h + 0.14, 2.2, 0.56
    cell(s, bx, by_, bw, bh, "", "", sz=1)
    T(s, bx + 0.08, by_ + 0.01, bw - 0.16, 0.54, ["U_BAUD_TICK_GEN", "651 clk 마다 b_tick"], 10.5, INK, True, al="c")
    poly(s, [(bx + bw / 2, by_), (bx + bw / 2, ya + h + 0.02)], U, 1.75)
    poly(s, [(bx + bw / 2, by_ + bh), (bx + bw / 2, yb2 - 0.02)], U, 1.75)
    T(s, bx + bw + 0.1, by_ + 0.07, 3.4, 0.42, "RX · TX 같이 씀 (9600 × 16)", 10.5, U, True)

    # 선 : 수신 줄 -------------------------------------------------------
    W = 2.0

    def lab(x1, x2, y, t, up=True, c=U):
        T(s, x1, y - 0.3 if up else y + 0.04, x2 - x1, 0.26, t, 10, c, True, al="c")

    yr = ya + 1.0
    poly(s, [(R("pc"), yr), (X("c1"), yr)], U, W)
    lab(R("pc"), X("c1"), yr, "rx")
    poly(s, [(R("c1"), ya + 0.8), (X("c2"), ya + 0.8)], U, W)
    lab(R("c1") - 0.05, X("c2") + 0.05, ya + 0.8, "rx_data")
    poly(s, [(R("c1"), ya + 1.5), (X("c2"), ya + 1.5)], U, W)
    lab(R("c1") - 0.05, X("c2") + 0.05, ya + 1.5, "rx_done")
    T(s, R("c1") - 0.05, ya + 1.53, X("c2") - R("c1") + 0.1, 0.26, "= push", 10, G, al="c")
    poly(s, [(R("c2"), ya + 0.8), (X("c3"), ya + 0.8)], U, W)
    lab(R("c2") - 0.1, X("c3") + 0.1, ya + 0.8, "pop_data")
    poly(s, [(R("c2"), ya + 1.5), (X("c3"), ya + 1.5)], U, W)
    lab(R("c2") - 0.1, X("c3") + 0.1, ya + 1.5, "~empty")
    poly(s, [(X("c3"), ya + 1.95), (R("c2"), ya + 1.95)], U, 1.25)
    lab(R("c2") - 0.1, X("c3") + 0.1, ya + 1.95, "pop", up=False)
    # 디코더 → 컨트롤러
    for i, (t_, yy) in enumerate([("handshake", 0.6), ("ascii[39:0]", 1.05), ("깃발 6", 1.5), ("error", 1.95)]):
        c = RED if t_ == "error" else U
        poly(s, [(R("c3"), ya + yy), (X("c4"), ya + yy)], c, W)
        lab(R("c3"), X("c4"), ya + yy, t_, c=c)
    # 컨트롤러 → 송신
    for t_, yy, dirr in [("send_go", 0.55, -1), ("send_sel", 1.0, -1), ("send_data", 1.45, -1), ("send_busy", 1.95, 1)]:
        if dirr < 0:
            poly(s, [(X("c4"), yb2 + yy), (R("c3"), yb2 + yy)], U, W)
        else:
            poly(s, [(R("c3"), yb2 + yy), (X("c4"), yb2 + yy)], U, 1.25)
        lab(R("c3"), X("c4"), yb2 + yy, t_, up=(dirr < 0 or True))
    # 송신 → FIFO TX → uart_tx → PC
    poly(s, [(X("c3"), yb2 + 0.8), (R("c2"), yb2 + 0.8)], U, W)
    lab(R("c2") - 0.1, X("c3") + 0.1, yb2 + 0.8, "push_data")
    poly(s, [(X("c3"), yb2 + 1.5), (R("c2"), yb2 + 1.5)], U, W)
    lab(R("c2") - 0.1, X("c3") + 0.1, yb2 + 1.5, "push")
    poly(s, [(R("c2"), yb2 + 1.95), (X("c3"), yb2 + 1.95)], U, 1.25)
    lab(R("c2") - 0.1, X("c3") + 0.1, yb2 + 1.95, "full", up=False)
    poly(s, [(X("c2"), yb2 + 0.8), (R("c1"), yb2 + 0.8)], U, W)
    lab(R("c1") - 0.05, X("c2") + 0.05, yb2 + 0.8, "pop_data")
    poly(s, [(X("c2"), yb2 + 1.5), (R("c1"), yb2 + 1.5)], U, W)
    lab(R("c1") - 0.05, X("c2") + 0.05, yb2 + 1.5, "~empty")
    T(s, R("c1") - 0.05, yb2 + 1.53, X("c2") - R("c1") + 0.1, 0.26, "= start", 10, G, al="c")
    poly(s, [(R("c1"), yb2 + 1.95), (X("c2"), yb2 + 1.95)], U, 1.25)
    T(s, R("c1") - 0.3, yb2 + 1.99, X("c2") - R("c1") + 0.6, 0.26, "~busy = pop", 10, U, True, al="c")
    poly(s, [(X("c1"), yb2 + 1.0), (R("pc"), yb2 + 1.0)], U, W)
    lab(R("pc"), X("c1"), yb2 + 1.0, "tx")

    # 오른쪽 : Top 으로 (uart_top 밖)
    tx5 = X("c5")
    outs = [(ya + 0.35, ["module_control_bit", "+ uart_mode"], "Top : 스위치 대신 모드"),
            (ya + 1.9, ["uart_btn", "R · L · U · D"], "Top : 물리 버튼과 OR"),
            (ya + 3.55, ["send_sel [2:0]"], "Top 전송 MUX")]
    for yy, nm, dst in outs:
        poly(s, [(R("c4"), yy + 0.3), (tx5, yy + 0.3)], PUR, W)
        b = box(s, tx5, yy, C["c5"][1], 0.6 if len(nm) == 1 else 0.75, nm + [dst], [10.5] * len(nm) + [10],
                PURL, PUR, INK, 1.25, name=f"Top {dst}")
    # 전송 MUX 가 고른 데이터가 돌아옴
    my = ya + 4.45
    poly(s, [(tx5 + 0.9, ya + 3.55 + 0.6), (tx5 + 0.9, my + 0.3), (R("c4"), my + 0.3)], PUR, W)
    T(s, tx5 - 0.05, my + 0.36, 1.9, 0.5, ["i_send_data [23:0]", "시간 · 거리 · 온습도"], 10, PUR, True)
    T(s, tx5, ya - 0.3, 1.81, 0.28, "uart_top 밖 (Top)", 10.5, PUR, True)

    # 아래 숫자 띠 -------------------------------------------------------
    yy = 9.6
    stats = [("9600 bps · 8N1", "시작 1 + 데이터 8 + 정지 1 = 10 비트"),
             ("651 clk = b_tick", "100 MHz ÷ (9600 × 16) · 16 tick = 1 비트 104 µs"),
             ("1 글자 ≈ 1.04 ms", "/mod dist CR 10 글자 ≈ 10.4 ms 동안 받음"),
             ("rx_done → tx 0 : 7 clk", f"모듈 지날 때마다 1 ~ 2 clk · 합 70 ns ({P['U6']:02d} 쪽)")]
    w = (19.08 - 0.92 - 0.3 * 3) / 4
    for i, (big, small) in enumerate(stats):
        x = 0.92 + i * (w + 0.3)
        b = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, x, yy, w, 0.85, UL, None, name="숫자 상자")
        b.adjustments[0] = 0.2
        T(s, x + 0.2, yy + 0.06, w - 0.4, 0.42, big, 17, UD, True)
        T(s, x + 0.2, yy + 0.47, w - 0.4, 0.32, small, 11, G)
    return s


# ---------------------------------------------------------------- U1 수신 (baud · uart_rx · FIFO RX)
def u1(prs, page, P):
    s, yb = frame(prs, "확대 ① 수신 — uart_rx 는 16 배로 쪼개 보고 비트 가운데에서 읽음",
                  [[("b_tick", 1), (" (651 clk) 16 번 = 1 비트 · START 에서 ", 0), ("8 번째 tick (cnt = 7)", 1),
                    (" = 시작 비트 가운데 → DATA 는 그 뒤 ", 0), ("16 tick 마다", 1), (" 한 비트 (LSB 먼저)", 0)],
                   [("STOP 끝에 ", 0), ("rx_done 1 clk", 1), (" = FIFO push · 디코더는 FIFO 가 비지 않으면 ", 0),
                    ("그 clk 에 바로 pop", 1), (" (pop = ~empty)", 0)]],
                  page, "U1",
                  "START 에서 rx 가 다시 1 이 되면 (짧은 잡음) IDLE 로 돌아감. 가운데에서 읽으니 baud 오차가 조금 있어도 비트 경계에서 멀다. "
                  "FIFO 는 8 칸이지만 디코더가 매 clk 꺼내므로 실제로는 1 칸만 잠깐 찼다가 빈다.")
    my = yb + 0.2
    zy = my + 0.75
    minimap(s, my, {"rx", "frx"}, zy)
    T(s, 10.9, zy + 0.08, 8.0, 0.3, "uart_rx 상태도 (c_state)", 11.5, U, True)

    # 회로 -----------------------------------------------------------------
    y0 = zy + 0.62
    # baud
    cell(s, 1.15, y0 + 0.05, 1.75, 1.2, "U_BAUD_TICK_GEN", "baud_tick_gen", sz=10.5)
    T(s, 1.2, y0 + 0.4, 1.65, 0.8, ["counter", "0 → 650", "→ b_tick 1 clk"], 10.5, INK, al="c")
    # uart_rx 셀
    rx_x, rx_w, rx_h = 3.45, 4.15, 3.95
    cell(s, rx_x, y0, rx_w, rx_h, "U_UART_RX", "uart_rx")
    fsm = sub(s, rx_x + 0.2, y0 + 0.45, 1.75, 0.95, ["c_state", "IDLE · START", "DATA · STOP"], [12, 10, 10], hl=True)
    sub(s, rx_x + 2.2, y0 + 0.45, 1.75, 0.6, ["b_tick_cnt [3:0]", "tick 마다 +1"], [10.5, 9.5])
    sub(s, rx_x + 2.2, y0 + 1.15, 1.75, 0.6, ["bit_cnt [2:0]", "비트마다 +1"], [10.5, 9.5])
    # data_reg 시프트
    T(s, rx_x + 0.2, y0 + 1.95, 3.7, 0.28, "data_reg [7:0]  ← {rx, data[7:1]}  (오른쪽으로 밀기)", 10.5, INK, True)
    cw = 0.42
    dx0 = rx_x + 0.45
    for i in range(8):
        box(s, dx0 + i * cw, y0 + 2.3, cw, 0.42, str(7 - i), 10.5, "FFFFFF", G, INK, 1.0, rounded=False, bold=False)
    poly(s, [(dx0 + 8 * cw + 0.05, y0 + 2.51), (dx0 + 8 * cw + 0.3, y0 + 2.51)], GM, 1.25, arrow=True)
    T(s, dx0 + 8 * cw - 0.02, y0 + 2.6, 0.45, 0.22, "버림", 9.5, G, al="c")
    ff(s, rx_x + 2.2, y0 + 3.2, 1.75, 0.6, ["rx_done_reg", "STOP 끝 1 clk"], [10.5, 9.5])
    # 입력
    poly(s, [(2.9, y0 + 0.65), (rx_x, y0 + 0.65)], U, 1.75)
    T(s, 2.92, y0 + 0.33, 0.6, 0.28, "b_tick", 10, U, True)
    poly(s, [(rx_x - 0.35, y0 + 2.51), (dx0, y0 + 2.51)], U, 1.75)
    poly(s, [(rx_x - 0.12, y0 + 2.51), (rx_x - 0.12, y0 + 1.1), (rx_x + 0.2, y0 + 1.1)], U, 1.25)
    dot(s, rx_x - 0.12, y0 + 2.51, U)
    T(s, 1.15, y0 + 2.36, 1.9, 0.3, "i_rx (PC)", 11, U, True, al="r")
    # 출력 → FIFO
    fx, fw = 8.25, 2.25
    poly(s, [(dx0 + 4 * cw, y0 + 2.72), (dx0 + 4 * cw, y0 + 3.05), (rx_x + rx_w, y0 + 3.05), (fx, y0 + 3.05)], U, 1.75)
    T(s, rx_x + rx_w + 0.02, y0 + 2.75, fx - rx_x - rx_w, 0.28, "rx_data", 10, U, True, al="c")
    poly(s, [(rx_x + 3.95, y0 + 3.5), (fx, y0 + 3.5)], U, 1.75)
    T(s, rx_x + rx_w + 0.02, y0 + 3.55, fx - rx_x - rx_w, 0.28, "rx_done", 10, U, True, al="c")
    # FIFO
    cell(s, fx, y0, fw, rx_h, "U_FIFO_RX", "fifo  (8 × 8)")
    sub(s, fx + 0.15, y0 + 0.45, fw - 0.3, 1.0, ["control", "wptr · rptr", "full · empty"], [11, 10, 10])
    sub(s, fx + 0.15, y0 + 1.6, fw - 0.3, 1.05, ["register_file", "8 칸 × 8 bit", "we = push & ~full"], [11, 10, 10])
    T(s, fx + 0.1, y0 + 2.72, fw - 0.2, 0.24, "← push_data · push", 10, G, al="l")
    box(s, fx + 0.15, y0 + 3.0, fw - 0.3, 0.55, ["pop = ~empty", "(디코더가 바로 꺼냄)"], [10.5, 9.5], UL, U, INK, 1.0)
    T(s, fx + 0.1, y0 + 3.6, fw - 0.2, 0.3, "→ 디코더 : pop_data", 10, U, True)

    # 상태도 -----------------------------------------------------------------
    sx0, sx1 = 11.25, 16.75
    sy0, sy1 = y0 + 0.15, y0 + 2.6
    sw_, sh_ = 1.85, 0.8
    st_i = state(s, sx0, sy0, sw_, sh_, "IDLE", "rx_done = 0")
    st_s = state(s, sx1, sy0, sw_, sh_, "START", "가운데 찾기")
    st_d = state(s, sx1, sy1, sw_, sh_, "DATA", "8 비트 받기")
    st_p = state(s, sx0, sy1, sw_, sh_, "STOP", "정지 비트")
    # IDLE → START
    poly(s, [(sx0 + sw_, sy0 + 0.28), (sx1, sy0 + 0.28)], U, 2.0)
    T(s, sx0 + sw_ + 0.1, sy0 - 0.08, sx1 - sx0 - sw_ - 0.2, 0.3, "b_tick & rx = 0  (하강)", 11.5, U, True, al="c")
    # START → IDLE
    poly(s, [(sx1, sy0 + 0.6), (sx0 + sw_, sy0 + 0.6)], RED, 1.5)
    T(s, sx0 + sw_ + 0.1, sy0 + 0.64, sx1 - sx0 - sw_ - 0.2, 0.3, "rx = 1 이 되면 잡음 → 처음으로", 10.5, RED, al="c")
    # START → DATA
    xm = sx1 + sw_ / 2
    poly(s, [(xm, sy0 + sh_), (xm, sy1)], U, 2.0)
    T(s, xm - 3.3, sy0 + 1.05, 3.2, 0.9, ["b_tick & cnt = 7", "8 번째 tick = 시작 비트 가운데", "cnt · bit · data ← 0"],
      10.5, U, True, al="r")
    # DATA → STOP
    poly(s, [(sx1, sy1 + 0.43), (sx0 + sw_, sy1 + 0.43)], U, 2.0)
    T(s, sx0 + sw_ + 0.1, sy1 + 0.08, sx1 - sx0 - sw_ - 0.2, 0.3, "cnt = 15 & bit = 7", 11.5, U, True, al="c")
    # STOP → IDLE
    xi = sx0 + sw_ / 2
    poly(s, [(xi, sy1), (xi, sy0 + sh_)], U, 2.0)
    T(s, xi + 0.12, sy0 + 1.05, 3.0, 0.9, ["cnt = 15", "→ rx_done = 1 (1 clk)", "→ FIFO push"], 10.5, U, True)
    # DATA 자기 고리 (아래)
    lx1, lx2, ly = xm - 0.45, xm + 0.45, sy1 + sh_ + 0.25
    poly(s, [(lx2, sy1 + sh_ - 0.05), (lx2, ly), (lx1, ly), (lx1, sy1 + sh_ - 0.05)], U, 1.5)
    T(s, sx0 + sw_ + 0.1, sy1 + sh_ + 0.05, xm - 0.55 - sx0 - sw_ - 0.1, 0.48,
      ["cnt = 15 & bit < 7 → data ← {rx, data[7:1]} · bit + 1", "그 밖 : b_tick 마다 cnt + 1"], 10.5, U, True, al="r")

    # 비트 시간 그림 ----------------------------------------------------------
    ty = y0 + 4.22
    T(s, 1.15, ty, 1.0, 0.36, "rx", 13, U, True)
    x0, x1 = 2.0, 18.85
    idle = 0.55
    bw = (x1 - x0 - 2 * idle) / 10
    hi, lo = ty + 0.05, ty + 0.5
    xs = x0 + idle
    seg(s, x0, hi, xs, hi, INK, 2.0)
    seg(s, xs, hi, xs, lo, INK, 2.0)
    seg(s, xs, lo, xs + bw, lo, INK, 2.0)
    for i in range(8):
        a = xs + (i + 1) * bw
        b = a + bw
        seg(s, a + 0.06, hi, b - 0.06, hi, INK, 2.0)
        seg(s, a + 0.06, lo, b - 0.06, lo, INK, 2.0)
        seg(s, a - 0.06, hi, a + 0.06, lo, INK, 1.5)
        seg(s, a - 0.06, lo, a + 0.06, hi, INK, 1.5)
        T(s, a, hi, bw, lo - hi, f"D{i}", 11, INK, True, al="c")
    a = xs + 9 * bw
    seg(s, a - 0.06, lo, a + 0.06, hi, INK, 1.5)
    seg(s, a - 0.06, hi, a + 0.06, lo, INK, 1.5)
    seg(s, a + 0.06, hi, x1, hi, INK, 2.0)
    T(s, xs, lo + 0.02, bw, 0.26, "START", 10, G, True, al="c")
    T(s, a, lo + 0.02, bw, 0.26, "STOP", 10, G, True, al="c")
    # 샘플 위치 (가운데)
    for i in range(10):
        cxp = xs + (i + 0.5) * bw
        tri = shape(s, MSO_SHAPE.ISOSCELES_TRIANGLE, cxp - 0.08, lo + 0.3, 0.16, 0.14, RED, None, name="샘플")
    T(s, xs - 0.1, lo + 0.45, bw + 0.2, 0.26, "cnt = 7", 10, RED, True, al="c")
    for i in range(1, 9):
        T(s, xs + (i + 0.5) * bw - 0.5, lo + 0.45, 1.0, 0.26, "+16 tick", 10, RED, True, al="c")
    T(s, a, lo + 0.45, bw, 0.26, "+16 → done", 10, RED, True, al="c")
    # 1 비트 = 16 tick 자
    yk = lo + 0.8
    for k in range(17):
        xx = xs + bw + k * bw / 16
        seg(s, xx, yk, xx, yk + (0.16 if k % 8 == 0 else 0.09), G, 1.0, arrow=False)
    T(s, xs + 2 * bw + 0.1, yk - 0.06, 6.0, 0.3, "← 1 비트 = b_tick 16 번 = 16 × 651 clk = 104.2 µs  (9600 bps)", 10.5,
      G, True)
    return s


# ---------------------------------------------------------------- U2 디코더
def u2(prs, page, P):
    s, yb = frame(prs, "확대 ② 디코더 — 글자 하나에 상태 하나, '/' 부터 옵션까지 따라가며 명령을 판별",
                  [[("'/' → 명령 첫 글자 (g · m · b · a · s · o) 에서 ", 0), ("깃발", 1),
                    (" 1 개를 세움 → e · t · o 는 상태 하나를 같이 쓰고 깃발로 다음 갈래 결정", 0)],
                   [("SPACE 에서 옵션 글자를 ", 0), ("data_reg 에 밀어 넣음", 1), (" → 끝나면 ", 0),
                    ("handshake 1 clk", 1), (" (ascii 도 그 clk 만) · 틀린 글자면 ", 0), ("error 1 clk", 1)]],
                  page, "U2",
                  "상태 이름은 RTL enum 그대로 (IDLE SLASH g e t m o d b n a u s f SPACE). 같은 노란 칸은 실제로는 하나의 상태. "
                  "옵션 길이 : /mod 4 글자 (4 번째 글자에서 바로 끝, CR 안 기다림), /auto · /off 3 글자, /btn 1 글자, /get · /set 은 CR (LF).")
    my = yb + 0.2
    zy = my + 0.75
    minimap(s, my, {"dec"}, zy)
    T(s, 1.1, zy + 0.08, 9.0, 0.3, "UART_ASCII_DECODER 상태도 (c_state) — 줄 = 명령별 길", 11.5, U, True)
    T(s, 13.55, zy + 0.08, 5.4, 0.3, "U_ASCII_DECODER 출력 쪽 회로", 11.5, U, True)

    y0 = zy + 0.6
    rows = [("get", "g e t", "/get", "CR 또는 LF"),
            ("mode", "m o d", "/mod", "4 글자 → 바로 끝"),
            ("btn", "b t n", "/btn", "1 글자 R · L · U · D"),
            ("auto", "a u t o", "/auto", "3 글자 all · _sw …"),
            ("set", "s e t", "/set", "글자 + CR (24h · 12h)"),
            ("off", "o f f", "/off", "3 글자 set")]
    shared = {"e", "t", "o"}
    rh = 0.62
    ry = [y0 + 0.35 + i * rh for i in range(6)]
    # IDLE · SLASH
    ycen = (ry[0] + ry[-1]) / 2
    state(s, 1.15, ycen - 0.4, 1.35, 0.8, "IDLE", sz=13)
    state(s, 2.95, ycen - 0.4, 1.4, 0.8, "SLASH", sz=13)
    poly(s, [(2.5, ycen), (2.95, ycen)], U, 2.0)
    T(s, 2.45, ycen - 0.36, 0.55, 0.3, "'/'", 12, U, True, al="c")
    ox0, ow, og = 5.1, 0.62, 0.2
    sp_x, sp_w = 8.85, 1.25
    for i, (flag, seq, cmd, opt) in enumerate(rows):
        yy = ry[i]
        letters = seq.split()
        # SLASH → 첫 글자
        poly(s, [(4.35, ycen), (ox0 - 0.02, yy)], U, 1.5)
        for j, L in enumerate(letters):
            xx = ox0 + j * (ow + og)
            if j > 0 and L in shared or (j > 0 and flag == "off" and L == "o"):
                pass
            sh = L in shared and j > 0
            if flag in ("auto",) and L == "o":
                sh = True
            if flag == "off" and j == 0:
                sh = True
            state(s, xx, yy - 0.24, ow, 0.48, L, fill=AMBL if sh else "FFFFFF", line=AMB if sh else U, sz=13, lw=1.5)
            nx = xx + ow
            if j < len(letters) - 1:
                poly(s, [(nx, yy), (nx + og, yy)], U, 1.5)
        lastx = ox0 + len(letters) * (ow + og) - og
        poly(s, [(lastx, yy), (sp_x, yy)], U, 1.5)
        T(s, lastx + 0.05, yy - 0.28, 0.5, 0.26, "' '", 10.5, U, True, al="c")
        # 깃발 · 옵션
        runs(s, sp_x + sp_w + 0.12, yy - 0.15, 3.0, 0.3, [(cmd + "  ", U, True), (opt, INK, False)], 11)
    # f 자기 고리 표시 (off)
    T(s, ox0 + 2 * (ow + og) - 0.1, ry[5] + 0.22, 0.85, 0.22, "f = f 고리", 9.5, AMB, True, al="c")
    sp = state(s, sp_x, ry[0] - 0.3, sp_w, ry[-1] - ry[0] + 0.6, "SPACE", "옵션 모으기", sz=13)
    # done → IDLE
    yd = ry[-1] + 0.52
    poly(s, [(sp_x + sp_w / 2, ry[-1] + 0.3), (sp_x + sp_w / 2, yd), (1.82, yd), (1.82, ycen + 0.4)], U, 2.0)
    runs(s, 2.0, yd + 0.02, 7.0, 0.3, [("done", U, True), (" → IDLE  +  ", INK, False), ("handshake = 1 (1 clk)", U, True)],
         11.5)
    # bad
    yb_ = yd + 0.38
    note(s, 1.15, yb_, 11.6, 0.6,
         ["틀린 글자 (bad) → error = 1 (1 clk) · 깃발 · data_reg 지움 → 그 글자가 '/' 면 SLASH (바로 새 명령), 아니면 IDLE",
          "IDLE 에서는 '/' 아닌 글자 (CR · LF 포함) 를 무시 — error 안 냄"], 10.5, RED, REDL, name="bad")
    # 범례
    shape(s, MSO_SHAPE.OVAL, 10.95, y0 + 0.02, 0.3, 0.22, AMBL, AMB, 1.25, name="범례")
    T(s, 11.3, y0 - 0.02, 2.2, 0.3, "= 같은 상태 하나", 10, AMB, True)

    # 출력 회로 ---------------------------------------------------------------
    cx, cy, cw, ch = 13.55, y0 + 0.3, 5.3, 4.5
    cell(s, cx, cy, cw, ch, "U_ASCII_DECODER", "출력 레지스터")
    T(s, cx + cw - 2.0, cy - 0.3, 2.0, 0.28, "→ 컨트롤러", 11, U, True, al="r")
    # 입력
    T(s, cx + 2.2, cy + 0.08, 3.0, 0.26, "i_ascii ← pop_data", 10, U, True, al="r")
    T(s, cx + 1.6, cy + 0.34, 3.6, 0.26, "i_enable = ~empty  ·  o_pop = i_enable", 10, U, True, al="r")
    # data_reg 5 바이트
    T(s, cx + 0.15, cy + 0.7, 5.0, 0.28, "data_reg [39:0] ← {data_reg[31:0], 글자}", 10.5, INK, True)
    for i, ch_ in enumerate(["0", "d", "i", "s", "t"]):
        box(s, cx + 0.3 + i * 0.62, cy + 1.0, 0.62, 0.42, ch_, 12, "FFFFFF", G, INK, 1.0, rounded=False)
    poly(s, [(cx + 0.3 + 5 * 0.62 + 0.45, cy + 1.21), (cx + 0.3 + 5 * 0.62 + 0.05, cy + 1.21)], U, 1.5)
    T(s, cx + 0.3 + 5 * 0.62 + 0.5, cy + 1.08, 0.9, 0.26, "새 글자", 10, U, True)
    T(s, cx + 0.3, cy + 1.45, 3.6, 0.24, "← 한 칸씩 왼쪽으로 (예 : /mod dist)", 9.5, G)
    # handshake AND
    ff(s, cx + 0.3, cy + 1.85, 1.45, 0.55, ["handshake", "done 다음 clk"], [10.5, 9])
    gate(s, cx + 2.45, cy + 2.05, "&", 0.55, 0.5)
    poly(s, [(cx + 1.75, cy + 2.12), (cx + 2.45, cy + 2.12)], G, 1.25)
    poly(s, [(cx + 2.2, cy + 1.42), (cx + 2.2, cy + 1.7), (cx + 2.3, cy + 1.7), (cx + 2.3, cy + 2.42),
             (cx + 2.45, cy + 2.42)], G, 1.25)
    poly(s, [(cx + 3.0, cy + 2.3), (cx + cw + 0.15, cy + 2.3)], U, 1.75)
    T(s, cx + 3.05, cy + 2.0, 2.2, 0.28, "o_ascii (그 clk 만)", 10.5, U, True)
    poly(s, [(cx + 1.02, cy + 2.4), (cx + 1.02, cy + 2.68), (cx + cw + 0.15, cy + 2.68)], U, 1.75)
    T(s, cx + 3.05, cy + 2.7, 2.2, 0.26, "o_handshake", 10.5, U, True)
    # 깃발
    ff(s, cx + 0.3, cy + 3.05, 1.45, 0.55, ["깃발 × 6", "IDLE 에서 0"], [10.5, 9])
    poly(s, [(cx + 1.75, cy + 3.32), (cx + cw + 0.15, cy + 3.32)], U, 1.75)
    T(s, cx + 1.85, cy + 3.03, 3.4, 0.28, "o_get · btn · mode · auto · set · off_set", 10, U, True)
    ff(s, cx + 0.3, cy + 3.8, 1.45, 0.55, ["error", "bad 다음 clk"], [10.5, 9], line=RED)
    poly(s, [(cx + 1.75, cy + 4.07), (cx + cw + 0.15, cy + 4.07)], RED, 1.75)
    T(s, cx + 1.85, cy + 3.78, 2.5, 0.28, "o_error", 10.5, RED, True)

    # 아래 : /mod dist 글자별 -----------------------------------------------
    ey = 9.42
    T(s, 1.15, ey + 0.08, 1.5, 0.34, "예  /mod dist", 11.5, U, True)
    chars = [("/", "SLASH"), ("m", "m · mode=1"), ("o", "o"), ("d", "d"), ("SP", "SPACE"), ("d", "cnt 1"), ("i", "cnt 2"),
             ("s", "cnt 3"), ("t", "done")]
    ew = (19.0 - 2.7) / len(chars)
    for i, (c_, st_) in enumerate(chars):
        x = 2.7 + i * ew
        last = i == len(chars) - 1
        box(s, x, ey, 0.42, 0.42, c_, 13, U if last else "FFFFFF", U, "FFFFFF" if last else INK, 1.25, rounded=False)
        T(s, x + 0.47, ey + 0.06, ew - 0.5, 0.3, "→ " + st_, 10.5, U if last else INK, last)
    T(s, 2.7, ey + 0.52, 16.3, 0.3, "→ 't' 다음 clk : handshake = 1, ascii = \"dist\" → 컨트롤러 모드 FSM (파형 P1 확대 장과 같은 순간)", 10.5,
      U, True)
    return s


# ---------------------------------------------------------------- 컨트롤러 회로 (U3 · U4 같이 씀)
def ctl_cell(s, x, y, w, h, focus):
    cell(s, x, y, w, h, "U_CONTROL", "UART_CONTROLLER")
    ix = x + 0.2
    iw = w - 0.4
    m = sub(s, ix, y + 0.42, iw, 0.75, ["모드 FSM", "MODE_IDLE → MODE · /mod · /set · /off"], [12, 10],
            hl=(focus == "mode"))
    a = sub(s, ix, y + 1.27, iw, 0.75, ["송신 FSM", "IDLE · GET ⇄ AUTO_* 6 개 · AUTO_OFF"], [12, 10],
            hl=(focus == "send"))
    sub(s, ix, y + 2.12, iw * 0.48, 0.55, ["sender_tick", "1 Hz (AUTO 때만)"], [10.5, 9.5], hl=(focus == "send"))
    sub(s, ix + iw * 0.52, y + 2.12, iw * 0.48, 0.55, ["scan 카운터", "0 → 4 (ALL)"], [10.5, 9.5], hl=(focus == "send"))
    sub(s, ix, y + 2.77, iw, 0.55, ["버튼 래치 R · L · U · D", "물리 버튼 먼저"], [10.5, 9.5], hl=(focus == "btn"))
    return m, a


# ---------------------------------------------------------------- U3 컨트롤러 : 모드 FSM
def u3(prs, page, P):
    s, yb = frame(prs, "확대 ③ 컨트롤러 · 모드 FSM — /mod 4 글자를 스위치 7 개 값으로 바꿈",
                  [[("'/m' 을 받는 순간 ", 0), ("MODE_IDLE → MODE", 1), (" (리셋 전까지 유지) · MODE 에서 handshake 마다 ascii 를 보고 ", 0),
                    ("module_control_bit[6:0]", 1), (" 를 정함", 0)],
                   [("올바른 /mod 를 한 번 받으면 ", 0), ("uart_mode = 1", 1), (" → Top 이 스위치 대신 이 값을 씀 · ", 0),
                    ("bit3 (12/24 h) 는 /mod 로 안 바뀌고", 1), (" /set 24h · 12h 만", 0)]],
                  page, "U3",
                  "/set · /off 도 MODE 상태에서만 처리 → 첫 /mod 를 받기 전에는 무시된다. "
                  "/set (24h · 12h 가 아닌 옵션) 은 시계 화면 (bit 를 bit3 빼고 0000010) 일 때만 bit2 = 1 (시계 설정), /off set 은 설정 중일 때 bit2 = 0.")
    my = yb + 0.2
    zy = my + 0.75
    minimap(s, my, {"ctl"}, zy)
    y0 = zy + 0.55
    # 왼쪽 : 컨트롤러 셀
    ins = [("i_handshake", U), ("i_con_ascii [39:0]", U), ("i_mode · i_set · i_off_set", U),
           ("i_get · i_auto · i_btn", G), ("i_error · i_sender_busy", G), ("i_btn_R·L·U·D (물리)", G)]
    cx, cy, cw, ch = 3.75, y0 + 0.3, 3.75, 3.55
    m, a = ctl_cell(s, cx, cy, cw, ch, "mode")
    for i, (t_, c) in enumerate(ins):
        yy = cy + 0.55 + i * 0.5
        poly(s, [(1.1, yy), (cx, yy)], c, 1.5)
        T(s, 1.1, yy - 0.28, 2.6, 0.26, t_, 10, c, True)
    outs = [("module_control_bit [6:0]", U, cy + 0.62), ("uart_mode", U, cy + 1.0), ("send_sel · send_go", G, cy + 1.65),
            ("uart_btn R·L·U·D", G, cy + 3.05)]
    for t_, c, yy in outs:
        poly(s, [(cx + cw, yy), (cx + cw + 2.3, yy)], c, 1.5)
        T(s, cx + cw + 0.08, yy - 0.28, 2.3, 0.26, t_, 10, c, True)
    # Top 2:1 MUX
    mx, my_ = 8.15, cy + ch + 0.25
    T(s, 1.1, my_ - 0.05, 6.8, 0.3, "Top (merge_final_top) : 실제로 쓰는 모드 값", 11, PUR, True)
    trap(s, mx - 1.2, my_ + 0.35, 0.7, 1.05, 0.2, PURL, PUR, 1.5, "MUX 모드")
    T(s, mx - 1.15, my_ + 0.42, 0.3, 0.25, "1", 10, PUR, True)
    T(s, mx - 1.15, my_ + 1.05, 0.3, 0.25, "0", 10, PUR, True)
    poly(s, [(3.0, my_ + 0.55), (mx - 1.2, my_ + 0.55)], U, 1.5)
    T(s, 1.1, my_ + 0.4, 2.0, 0.28, "uart ctrl_bit", 10.5, U, True)
    poly(s, [(3.0, my_ + 1.18), (mx - 1.2, my_ + 1.18)], G, 1.5)
    T(s, 1.1, my_ + 1.03, 2.0, 0.28, "sw[6:0] 보드 스위치", 10.5, G, True)
    poly(s, [(mx - 0.85, my_ + 1.62), (mx - 0.85, my_ + 1.32)], U, 1.5)
    T(s, mx - 2.75, my_ + 1.5, 1.8, 0.26, "sel = uart_mode", 10, U, True, al="r")
    poly(s, [(mx - 0.5, my_ + 0.87), (mx + 0.3, my_ + 0.87)], PUR, 1.75)
    T(s, mx - 0.48, my_ + 0.57, 1.8, 0.28, "w_ctrl_bit", 10.5, PUR, True)
    T(s, 3.1, my_ + 0.66, 3.7, 0.42, ["첫 /mod 뒤엔 스위치를 바꿔도 화면 그대로 (파형 P1)"], 10, G, al="c")

    # 오른쪽 : 상태도 + 표
    rx0 = 10.0
    T(s, rx0, zy + 0.08, 8.0, 0.3, "모드 FSM 상태도 (c_mode_state)", 11.5, U, True)
    st1 = state(s, rx0 + 0.2, y0 + 0.15, 2.2, 0.85, "MODE_IDLE", "handshake 무시", sz=13)
    st2 = state(s, rx0 + 5.3, y0 + 0.15, 2.0, 0.85, "MODE", "표대로 bit 결정", sz=13)
    poly(s, [(rx0 + 2.4, y0 + 0.57), (rx0 + 5.3, y0 + 0.57)], U, 2.0)
    T(s, rx0 + 2.45, y0 + 0.2, 2.8, 0.3, "i_mode = 1  ('/m' 받음)", 11, U, True, al="c")
    T(s, rx0 + 2.45, y0 + 0.62, 2.8, 0.3, "돌아오는 길 없음 (리셋만)", 10, G, al="c")
    lx = rx0 + 7.3
    poly(s, [(lx - 0.05, y0 + 0.35), (lx + 0.35, y0 + 0.35), (lx + 0.35, y0 + 0.8), (lx - 0.05, y0 + 0.8)], U, 1.5)
    T(s, lx + 0.4, y0 + 0.43, 1.3, 0.3, "handshake", 10, U, True)
    # 표
    hdr = ["명령 · 옵션", "6 온습도", "5 거리", "4 타이머", "3 24h", "2 설정", "1 시:분", "0 스톱", "화면"]
    rows_ = [hdr,
             ["/mod w_hm", "0", "0", "0", "유지", "0", "1", "0", "시계 시:분"],
             ["/mod w_ms", "0", "0", "0", "유지", "0", "0", "0", "시계 분:초"],
             ["/mod t_hm", "0", "0", "1", "유지", "0", "1", "0", "타이머 시:분"],
             ["/mod t_ms", "0", "0", "1", "유지", "0", "0", "0", "타이머 분:초"],
             ["/mod s_hm", "0", "0", "0", "유지", "0", "1", "1", "스톱워치 시:분"],
             ["/mod s_ms", "0", "0", "0", "유지", "0", "0", "1", "스톱워치 분:초"],
             ["/mod dist", "0", "1", "0", "유지", "0", "0", "0", "거리"],
             ["/mod temp", "1", "0", "0", "유지", "0", "0", "0", "온습도"],
             ["/set 24h · 12h", "", "", "", "1 · 0", "", "", "", "그 bit 만"],
             ["/set (시계 화면)", "", "", "", "", "1", "", "", "시계 설정"],
             ["/off set (설정 중)", "", "", "", "", "0", "", "", "설정 끝"]]
    hl = {}
    for i in range(1, 9):
        hl[(i, 4)] = AMB
    for i in (9, 10, 11):
        for j in (4, 5):
            hl[(i, j)] = U
    hl[(7, 2)] = U
    hl[(8, 1)] = U
    table(s, rx0, y0 + 1.35, [1.9, 0.8, 0.7, 0.8, 0.72, 0.72, 0.72, 0.72, 1.7], rows_, row_h=0.355, pt=10.5, hl=hl,
          name="모드 표")
    T(s, rx0, y0 + 1.35 + 12 * 0.355 + 0.05, 8.9, 0.3,
      "module_control_bit = {dht_sw6, dist_sw5, timer_sw4, hour24_sw3, set_sw2, display_mode_sw1, mode_sw0}  — 스위치 순서 그대로",
      9.5, G)
    return s


# ---------------------------------------------------------------- U4 컨트롤러 : 송신 FSM
def u4(prs, page, P):
    s, yb = frame(prs, "확대 ④ 컨트롤러 · 송신 FSM — 무엇을 언제 보낼지, 겹치면 error 먼저",
                  [[("상태는 ", 0), ("무엇을", 1), (" 보낼지 (IDLE · GET = 지금 화면, AUTO_* = 정한 데이터) · ", 0),
                    ("pend 레지스터", 1), (" 는 보낼 차례를 기억 · sender 가 비면 ", 0), ("send_go 1 clk", 1)],
                   [("error 가 최우선", 1), (" (sel = 7, 데이터 차례는 pend 에 남음) · ", 0), ("busy = sender_busy | go", 1),
                    (" — go 다음 clk 에 한 번 더 쏘는 것을 막음", 0)]],
                  page, "U4",
                  "AUTO_* 상태에서는 /get 을 받지 않는다 (pend 에 /get 을 더하는 식이 IDLE · GET 쪽에만 있음). "
                  "AUTO_OFF 는 1 clk 만 머물고 IDLE 로. sender_tick 은 auto_enable 일 때만 셈 (멈추면 카운터는 그 값에서 멈춤).")
    my = yb + 0.2
    zy = my + 0.75
    minimap(s, my, {"ctl"}, zy)
    y0 = zy + 0.55
    T(s, 1.1, zy + 0.08, 8.0, 0.3, "송신 FSM 상태도 (c_auto_state)", 11.5, U, True)
    T(s, 10.25, zy + 0.08, 8.6, 0.3, "보낼지 판단 회로 (comb → c_sender_go · c_sender_sel FF)", 11.5, U, True)

    # 상태도 -----------------------------------------------------------------
    ix, iy = 1.2, y0 + 0.25
    state(s, ix, iy, 1.75, 0.8, "IDLE", sz=13)
    state(s, ix, iy + 1.55, 1.75, 0.8, "GET", sz=13)
    poly(s, [(ix + 0.6, iy + 0.8), (ix + 0.6, iy + 1.55)], U, 1.75)
    T(s, ix - 0.05, iy + 0.98, 0.62, 0.3, "/get", 10.5, U, True, al="r")
    note(s, ix + 0.05, iy + 2.5, 1.95, 0.95, ["둘 다 같은 동작", "sel = 지금 화면", "(w_mode_sel)"], 10, INK, GL)
    # AUTO 묶음
    gx, gy, gw, gh = 4.05, y0 + 0.05, 5.5, 3.0
    g = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, gx, gy, gw, gh, UL, U, 1.25, name="AUTO 묶음")
    g.adjustments[0] = 0.06
    T(s, gx + 0.15, gy + 0.06, gw - 0.3, 0.3, "AUTO_*  — auto_enable = 1 → 1 Hz tick 마다 보낼 차례", 10.5, U, True)
    autos = [("AUTO_SW", "sel 0"), ("AUTO_TM", "sel 1"), ("AUTO_WH", "sel 2"), ("AUTO_DIST", "sel 3"), ("AUTO_TEMP", "sel 4"),
             ("AUTO_ALL", "0→1→2→3→4")]
    aw, ah = 1.62, 0.78
    for k, (nm, sl) in enumerate(autos):
        r, c = divmod(k, 3)
        state(s, gx + 0.18 + c * (aw + 0.1), gy + 0.5 + r * (ah + 0.18), aw, ah, nm, sl, sz=11, ssz=9.5, lw=1.5,
              fill="FFFFFF" if nm != "AUTO_ALL" else "FFFFFF")
    T(s, gx + 0.15, gy + gh - 0.62, gw - 0.3, 0.55, ["/auto 다른 옵션 → 바로 그 상태로", "AUTO_ALL : 보낼 때마다 scan +1"],
      10, INK, al="c")
    # IDLE → AUTO
    poly(s, [(ix + 1.75, iy + 0.4), (gx, iy + 0.4)], U, 2.0)
    T(s, ix + 1.75, iy - 0.02, gx - ix - 1.75, 0.3, "/auto 옵션", 10.5, U, True, al="c")
    poly(s, [(ix + 1.75, iy + 1.95), (gx, iy + 1.95)], U, 1.5)
    T(s, ix + 1.75, iy + 1.95, gx - ix - 1.75, 0.3, "/auto 옵션", 10, U, al="c")
    # AUTO → OFF → IDLE
    ox, oy = gx + 1.9, gy + gh + 0.55
    state(s, ox, oy, 1.85, 0.75, "AUTO_OFF", "1 clk", sz=12)
    poly(s, [(ox + 0.92, gy + gh), (ox + 0.92, oy)], U, 1.75)
    T(s, ox + 1.0, gy + gh + 0.1, 1.6, 0.3, "/auto off", 10.5, U, True)
    poly(s, [(ox, oy + 0.38), (ix - 0.13, oy + 0.38), (ix - 0.13, iy + 0.4), (ix, iy + 0.4)], U, 1.75)
    T(s, ix + 0.1, oy + 0.42, 2.8, 0.3, "→ IDLE (enable 0)", 10.5, U, True)

    # 판단 회로 --------------------------------------------------------------
    X0 = 10.25
    # 입력 이름
    inp = [("/get handshake (IDLE·GET)", 0.35), ("1 Hz tick (AUTO_*)", 0.7), ("c_send_pend", 1.05),
           ("i_error", 1.75), ("c_err_pend", 2.1),
           ("i_sender_busy", 2.85), ("c_sender_go", 3.2)]
    for t_, dy in inp:
        c = RED if "err" in t_ else (G if "busy" in t_ or "sender_go" in t_ else U)
        T(s, X0, y0 + dy - 0.14, 2.25, 0.28, t_, 9.5, c, True, al="r")
        poly(s, [(X0 + 2.3, y0 + dy), (X0 + 2.75, y0 + dy)], c, 1.25, arrow=False)
    gx1 = X0 + 2.75
    gate(s, gx1, y0 + 0.22, "≥1", 0.6, 1.0)
    gate(s, gx1, y0 + 1.6, "≥1", 0.6, 0.65, line=RED)
    gate(s, gx1, y0 + 2.7, "≥1", 0.6, 0.65)
    T(s, gx1 + 0.62, y0 + 0.42, 1.4, 0.26, "send_pend", 10, U, True)
    T(s, gx1 + 0.62, y0 + 1.62, 1.4, 0.26, "err_pend", 10, RED, True)
    T(s, gx1 + 0.62, y0 + 2.72, 1.4, 0.26, "busy", 10, G, True)
    ys, ye, yu = y0 + 0.72, y0 + 1.92, y0 + 3.02
    a1x, a2x = X0 + 4.55, X0 + 4.55
    gate(s, a1x, y0 + 0.55, "&", 0.6, 0.85, line=U)
    gate(s, a2x, y0 + 2.0, "&", 0.6, 0.65, line=RED)
    # send_pend → AND1
    poly(s, [(gx1 + 0.6, ys), (a1x, ys)], U, 1.5, arrow=False)
    # err_pend → AND1 (NOT) · AND2
    poly(s, [(gx1 + 0.6, ye), (gx1 + 1.0, ye), (gx1 + 1.0, y0 + 1.15), (a1x - 0.12, y0 + 1.15)], RED, 1.25,
         arrow=False)
    inv(s, a1x - 0.06, y0 + 1.15, RED)
    poly(s, [(gx1 + 1.0, ye), (gx1 + 1.0, y0 + 2.15), (a2x, y0 + 2.15)], RED, 1.25, arrow=False)
    dot(s, gx1 + 1.0, ye, RED)
    # busy → AND1 (NOT) · AND2 (NOT)
    poly(s, [(gx1 + 0.6, yu), (gx1 + 1.25, yu), (gx1 + 1.25, y0 + 0.97), (a1x - 0.12, y0 + 0.97)], G, 1.25,
         arrow=False)
    inv(s, a1x - 0.06, y0 + 0.97, G)
    poly(s, [(gx1 + 1.25, y0 + 2.48), (a2x - 0.12, y0 + 2.48)], G, 1.25, arrow=False)
    dot(s, gx1 + 1.25, y0 + 2.48, G)
    inv(s, a2x - 0.06, y0 + 2.48, G)
    T(s, a1x + 0.62, y0 + 0.62, 1.2, 0.26, "data_go", 10, U, True)
    T(s, a2x + 0.62, y0 + 2.05, 1.2, 0.26, "err_go", 10, RED, True)
    # sel MUX · go OR
    mx = X0 + 6.3
    trap(s, mx, y0 + 0.05, 0.6, 1.15, 0.2, "FFFFFF", G, 1.5, "MUX sel")
    T(s, mx + 0.04, y0 + 0.12, 0.3, 0.24, "0", 9.5, G, True)
    T(s, mx + 0.04, y0 + 0.85, 0.3, 0.24, "1", 9.5, RED, True)
    T(s, X0 + 4.4, y0 - 0.16, 1.9, 0.26, "상태별 sel", 9.5, U, True, al="r")
    poly(s, [(X0 + 5.6, y0 + 0.24), (mx, y0 + 0.24)], U, 1.25)
    T(s, X0 + 5.62, y0 + 0.83, 0.42, 0.26, "7", 11, RED, True, al="r")
    poly(s, [(X0 + 6.05, y0 + 0.97), (mx, y0 + 0.97)], RED, 1.25)
    poly(s, [(a2x + 0.6, y0 + 2.32), (mx + 0.3, y0 + 2.32), (mx + 0.3, y0 + 1.12)], RED, 1.25)
    gate(s, mx, y0 + 1.75, "≥1", 0.6, 0.85)
    poly(s, [(a1x + 0.6, y0 + 0.97), (a1x + 0.95, y0 + 0.97), (a1x + 0.95, y0 + 1.95), (mx, y0 + 1.95)], U, 1.25)
    poly(s, [(a2x + 0.6, y0 + 2.32), (a2x + 0.95, y0 + 2.32), (a2x + 0.95, y0 + 2.4), (mx, y0 + 2.4)], RED, 1.25)
    dot(s, a2x + 0.95, y0 + 2.32, RED)
    # FF
    fx = X0 + 7.3
    ff(s, fx, y0 + 0.28, 1.25, 0.6, ["c_sender_sel"], [10])
    ff(s, fx, y0 + 1.88, 1.25, 0.6, ["c_sender_go"], [10])
    poly(s, [(mx + 0.6, y0 + 0.62), (fx, y0 + 0.62)], G, 1.5)
    poly(s, [(mx + 0.6, y0 + 2.17), (fx, y0 + 2.17)], G, 1.5)
    poly(s, [(fx + 1.25, y0 + 0.58), (18.95, y0 + 0.58)], U, 1.75)
    T(s, fx + 0.05, y0 + 0.92, 1.6, 0.26, "o_send_sel", 10, U, True)
    poly(s, [(fx + 1.25, y0 + 2.18), (18.95, y0 + 2.18)], U, 1.75)
    T(s, fx + 0.05, y0 + 2.52, 1.6, 0.26, "o_sender_go (1 clk)", 10, U, True)
    # go 되먹임 → busy
    poly(s, [(18.75, y0 + 2.18), (18.75, y0 + 3.6), (X0 + 2.5, y0 + 3.6), (X0 + 2.5, y0 + 3.2)], G, 1.25, dash=True)
    dot(s, 18.75, y0 + 2.18, G)
    T(s, X0 + 4.0, y0 + 3.62, 5.5, 0.26, "go 를 낸 다음 clk 은 sender busy 가 아직 0 → go 자체를 busy 로", 9.5, G)
    T(s, X0, y0 + 3.95, 8.7, 0.26, "보낸 clk 에 그 pend 는 0 으로 · 못 보내면 (busy) pend 유지 → busy 풀린 clk 에 바로", 9.5, G)

    # 아래 규칙 카드 -----------------------------------------------------------
    ky = 8.95
    cards = [("① error 최우선", ["data_go 조건에 ~err_pend", "→ 같은 clk 이면 ERROR 먼저", "데이터는 pend 에 남았다 이어서"], RED),
             ("② 두 번 쏘지 않기", ["busy = sender_busy | go", "go 바로 다음 clk 까지 막음"], U),
             ("③ AUTO_ALL 순환", ["실제로 보낸 clk 에 scan_tick", "sel 0 → 1 → 2 → 3 → 4 → 0", "(파형 P3 : 1 s 간격)"], U),
             ("④ 버튼 (래치)", ["/btn R → c_btn_R = 1", "물리 버튼 없는 clk 에 1 clk 출력", "물리 버튼 있으면 기다림"], U)]
    w = (19.08 - 0.92 - 0.25 * 3) / 4
    for i, (hd, ls, c) in enumerate(cards):
        x = 0.92 + i * (w + 0.25)
        b = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, x, ky, w, 1.42, REDL if c == RED else UL, None, name="규칙")
        b.adjustments[0] = 0.12
        T(s, x + 0.2, ky + 0.08, w - 0.4, 0.34, hd, 13, c, True)
        T(s, x + 0.2, ky + 0.45, w - 0.4, 0.9, ls, 11, INK, anchor="t")
    return s


# ---------------------------------------------------------------- U5 송신 (sender · char_mux · FIFO TX · uart_tx)
def u5(prs, page, P):
    s, yb = frame(prs, "확대 ⑤ 송신 — sender 가 숫자를 글자로 바꿔 한 clk 에 한 글자씩, uart_tx 가 1 글자 1.04 ms 로",
                  [[("send_go 순간 ", 0), ("sel · data 를 잡아 둠", 1), (" (보내는 동안 값이 바뀌어도 그 줄은 그대로) → ", 0),
                    ("sender_char_mux", 1), (" 가 (sel, idx) 자리 글자를 냄", 0)],
                   [("SEND 에서 ", 0), ("idx = last_idx", 1), (" 이면 끝 · TX FIFO 64 칸에 먼저 다 넣고 → ", 0),
                    ("uart_tx 는 busy 가 0 일 때만 pop", 1), (" (한 글자 한 번)", 0)]],
                  page, "U5",
                  "uart_tx 는 IDLE 에서 start 를 받는 clk 에 바로 busy = 1 이 되도록 고친 판 (TS-44). pop = ~busy 라서 "
                  "같은 글자를 두 번 꺼내지 않는다. 13 글자 한 줄은 sender 가 13 clk 만에 FIFO 에 넣고, 선으로 나가는 데는 약 13.5 ms.")
    my = yb + 0.2
    zy = my + 0.75
    minimap(s, my, {"snd", "ftx", "tx"}, zy)
    y0 = zy + 0.55
    # Top 전송 MUX (밖)
    T(s, 1.1, zy + 0.08, 3.0, 0.3, "Top 전송 MUX", 11.5, PUR, True)
    mx, mw, mh = 2.75, 0.75, 2.75
    trap(s, mx, y0 + 0.2, mw, mh, 0.35, PURL, PUR, 1.5, "전송 MUX")
    ins = [("0", "스톱워치 시간"), ("1", "타이머 시간"), ("2", "시계 시간"), ("3", "거리 + 상태"), ("4", "온습도 + 오류"),
           ("7", "0 (ERROR)")]
    for i, (n, t_) in enumerate(ins):
        yy = y0 + 0.5 + i * 0.4
        poly(s, [(mx - 0.25, yy), (mx, yy)], PUR, 1.25, arrow=False)
        T(s, 1.0, yy - 0.15, 1.5, 0.3, t_, 10, PUR, True, al="r")
        T(s, mx + 0.05, yy - 0.13, 0.25, 0.26, n, 9.5, PUR, True)
    T(s, mx - 0.3, y0 + mh + 0.35, 1.6, 0.26, "sel = send_sel", 10, PUR, True, al="c")
    poly(s, [(mx + mw / 2, y0 + mh + 0.35), (mx + mw / 2, y0 + mh - 0.02)], PUR, 1.25)

    # sender 셀
    sx, sw_, sh_ = 4.25, 4.6, 3.7
    cell(s, sx, y0, sw_, sh_, "U_ASCII_SENDER", "uart_sender")
    poly(s, [(mx + mw, y0 + 1.55), (sx + 0.2, y0 + 1.55)], PUR, 1.75)
    T(s, mx + mw - 0.1, y0 + 1.25, 1.3, 0.28, "send_data", 10, PUR, True, al="c")
    sub(s, sx + 0.2, y0 + 0.42, 1.65, 0.7, ["c_state", "IDLE ⇄ SEND"], [11.5, 10], hl=True)
    ff(s, sx + 0.2, y0 + 1.22, 1.65, 0.65, ["c_sel · c_data", "go 순간 잡기"], [10.5, 9.5])
    ff(s, sx + 0.2, y0 + 1.97, 1.65, 0.6, ["c_idx", "0 → last"], [10.5, 9.5])
    T(s, sx + 0.2, y0 + 2.62, 2.2, 0.26, "← send_go · send_sel", 10, U, True)
    # char mux
    cmx = sx + 2.3
    trap(s, cmx, y0 + 0.42, 1.15, 2.15, 0.35, UL, U, 1.5, "char_mux")
    T(s, cmx + 0.05, y0 + 0.95, 1.0, 1.0, ["sender_", "char_mux", "(조합)"], 10, INK, True, al="c")
    poly(s, [(sx + 1.85, y0 + 1.55), (cmx, y0 + 1.55)], G, 1.25)
    poly(s, [(sx + 1.85, y0 + 2.27), (cmx, y0 + 2.27)], G, 1.25)
    T(s, sx + 1.86, y0 + 2.0, 0.5, 0.25, "idx", 9.5, G, True)
    # 출력 : char · last_idx
    poly(s, [(cmx + 1.15, y0 + 1.05), (sx + sw_ + 0.85, y0 + 1.05)], U, 1.75)
    T(s, cmx + 1.18, y0 + 0.76, 1.2, 0.26, "char", 10, U, True)
    T(s, cmx + 1.18, y0 + 1.82, 1.0, 0.26, "last_idx", 10, G, True)
    box(s, cmx + 0.15, y0 + 2.72, 1.75, 0.42, ["idx = last ?"], [10.5], "FFFFFF", G, INK, 1.25)
    poly(s, [(cmx + 1.15, y0 + 2.1), (cmx + 1.6, y0 + 2.1), (cmx + 1.6, y0 + 2.72)], G, 1.25)
    poly(s, [(cmx + 0.15, y0 + 2.93), (sx + 0.1, y0 + 2.93), (sx + 0.1, y0 + 0.77), (sx + 0.2, y0 + 0.77)], G, 1.25,
         dash=True)
    T(s, sx + 0.2, y0 + 3.25, sw_ - 0.4, 0.3, "push = SEND & ~full  ·  busy = SEND (→ 컨트롤러)", 10, U, True)
    poly(s, [(sx + sw_, y0 + 1.75), (sx + sw_ + 0.85, y0 + 1.75)], U, 1.75)
    T(s, sx + sw_ + 0.02, y0 + 1.45, 0.85, 0.26, "push", 10, U, True, al="c")
    # FIFO TX
    fx, fw = 9.7, 1.6
    cell(s, fx, y0, fw, sh_, "U_FIFO_TX", "fifo")
    sub(s, fx + 0.15, y0 + 0.45, fw - 0.3, 0.8, ["64 칸", "× 8 bit"], [11, 10])
    sub(s, fx + 0.15, y0 + 1.4, fw - 0.3, 0.8, ["wptr", "rptr"], [10.5, 10.5])
    poly(s, [(fx, y0 + 2.4), (sx + sw_, y0 + 2.4)], G, 1.25)
    T(s, sx + sw_ + 0.02, y0 + 2.42, 0.85, 0.26, "full", 10, G, True, al="c")
    # uart_tx
    tx_x, tx_w = 12.15, 2.7
    cell(s, tx_x, y0, tx_w, sh_, "U_UART_TX", "uart_tx")
    sub(s, tx_x + 0.15, y0 + 0.42, tx_w - 0.3, 0.7, ["c_state", "IDLE · START · DATA · STOP"], [11.5, 9.5], hl=True)
    ff(s, tx_x + 0.15, y0 + 1.25, tx_w - 0.3, 0.6, ["data_reg ▶ 오른쪽", "tx = data[0] (LSB 먼저)"], [10, 9.5])
    ff(s, tx_x + 0.15, y0 + 1.98, tx_w - 0.3, 0.6, ["tx_busy_reg", "start clk 에 바로 1"], [10, 9.5])
    poly(s, [(fx + fw, y0 + 1.05), (tx_x, y0 + 1.05)], U, 1.75)
    T(s, fx + fw - 0.05, y0 + 0.75, tx_x - fx - fw + 0.1, 0.26, "pop_data", 10, U, True, al="c")
    poly(s, [(fx + fw, y0 + 1.85), (tx_x, y0 + 1.85)], U, 1.75)
    T(s, fx + fw - 0.05, y0 + 1.55, tx_x - fx - fw + 0.1, 0.26, "~empty", 10, U, True, al="c")
    T(s, fx + fw - 0.05, y0 + 1.87, tx_x - fx - fw + 0.1, 0.26, "= start", 10, G, al="c")
    poly(s, [(tx_x, y0 + 2.85), (fx + fw, y0 + 2.85)], G, 1.25)
    T(s, fx + fw - 0.05, y0 + 2.87, tx_x - fx - fw + 0.1, 0.26, "~busy = pop", 10, G, True, al="c")
    T(s, tx_x + 0.15, y0 + 3.25, 2.4, 0.3, "← b_tick (RX 와 같이 씀)", 10, U, True)
    poly(s, [(tx_x + tx_w, y0 + 1.55), (tx_x + tx_w + 0.45, y0 + 1.55)], U, 2.0)
    T(s, tx_x + tx_w - 0.05, y0 + 1.2, 0.7, 0.3, "tx → PC", 10, U, True, al="r")

    # 오른쪽 상태도 (sender · uart_tx) ---------------------------------------------
    rx0 = 15.55
    T(s, rx0, zy + 0.08, 3.5, 0.3, "상태도", 11.5, U, True)
    state(s, rx0, y0 + 0.05, 1.35, 0.7, "IDLE", sz=12, ssz=9)
    state(s, rx0 + 2.1, y0 + 0.05, 1.35, 0.7, "SEND", sz=12)
    poly(s, [(rx0 + 1.35, y0 + 0.25), (rx0 + 2.1, y0 + 0.25)], U, 1.75)
    poly(s, [(rx0 + 2.1, y0 + 0.58), (rx0 + 1.35, y0 + 0.58)], U, 1.75)
    T(s, rx0 + 1.2, y0 - 0.22, 1.05, 0.24, "go", 10, U, True, al="c")
    T(s, rx0 - 0.05, y0 + 0.78, 3.55, 0.26, "idx = last & ~full → IDLE  (sender)", 9.5, U, True, al="c")
    # uart_tx 4 상태 (세로)
    ty0 = y0 + 1.3
    names = [("IDLE", "tx = 1"), ("START", "tx = 0 · 16 tick"), ("DATA", "16 tick × 8"), ("STOP", "tx = 1 · 16 tick")]
    st_, sh2 = 0.62, 0.5
    for i, (nm, sb) in enumerate(names):
        state(s, rx0 + 0.45, ty0 + i * st_, 2.35, sh2, nm, sb, sz=11, ssz=9.5, lw=1.5)
        if i < 3:
            poly(s, [(rx0 + 1.62, ty0 + i * st_ + sh2), (rx0 + 1.62, ty0 + (i + 1) * st_)], U, 1.5)
    poly(s, [(rx0 + 2.8, ty0 + 3 * st_ + 0.25), (rx0 + 3.3, ty0 + 3 * st_ + 0.25), (rx0 + 3.3, ty0 + 0.25),
             (rx0 + 2.8, ty0 + 0.25)], U, 1.5)
    T(s, rx0 - 0.1, ty0 + 0.45, 0.6, 0.24, "start", 9.5, U, True)
    T(s, rx0 + 0.05, ty0 - 0.27, 3.3, 0.24, "uart_tx", 10, U, True, al="c")

    # 아래 : 형식 표 ---------------------------------------------------------------
    ty = y0 + sh_ + 0.32
    rows_ = [["send_sel", "데이터", "보내는 글자 (CR LF = 줄 바꿈)", "글자 수", "last_idx", "선 위 시간"],
             ["0 · 1 · 2", "스톱워치 · 타이머 · 시계", "12:34:56.78 CR LF", "13", "12", "≈ 13.5 ms"],
             ["3", "거리  /  센서 오류", "123cm CR LF   /   Err 2 CR LF", "7", "6", "≈ 7.3 ms"],
             ["4", "온습도  /  측정 전  /  오류", "45%25C CR LF  /  --%--C CR LF  /  Err 1 CR LF", "8 / 8 / 7", "7 / 7 / 6",
              "≈ 8.3 ms"],
             ["7", "디코더 error", "ERROR CR LF", "7", "6", "≈ 7.3 ms"]]
    table(s, 0.92, ty, [1.4, 3.3, 6.2, 1.6, 1.6, 2.0], rows_, row_h=0.34, pt=11.5,
          hl={(1, 2): U, (2, 2): U, (3, 2): U, (4, 2): RED}, name="형식 표")
    T(s, 17.25, ty + 0.05, 1.85, 1.75, ["온습도 99 보다", "크면 99 (FND 와", "같은 규칙)"], 10, G, anchor="t")
    return s


# ---------------------------------------------------------------- U6 명령 하나의 길 (clk 단위)
def u6(prs, page, P):
    s, yb = frame(prs, "명령 하나의 길 — /get CR 마지막 글자에서 TX 시작까지 7 clk",
                  [[("ms 단위", 1), (" : 6 글자 받기 ≈ 6.25 ms, 대답 13 글자 ≈ 13.5 ms → ", 0), ("clk 단위", 1),
                    (" 로 보면 모듈마다 레지스터 1 ~ 2 개", 0)],
                   [("rx_done 에서 tx = 0 까지 7 clk (70 ns)", 1),
                    (" · 파형 장의 rx_done → handshake +2 → go · 버튼 펄스 +1 = 여기 T0 → T2 → T3", 0)]],
                  page, "U6",
                  "T0 = rx_done 이 1 인 clk. 각 줄의 값은 RTL 레지스터 기준 (c_ = FF 출력). "
                  "send_sel 값은 지금 화면에 따라 다름 (리셋 뒤 /mod 없으면 시계 2). 시간 숫자 12:34:56.78 은 예시.")
    # ms 단위 줄 -----------------------------------------------------------------
    y0 = yb + 0.45
    ry_ = y0 + 0.5                       # PC → rx 줄 (아래), tx 줄은 위 (깔때기가 tx 글자를 지나지 않게)
    T(s, 0.92, y0 + 0.02, 1.7, 0.36, "tx → PC", 12, PUR, True)
    T(s, 0.92, ry_ + 0.02, 1.7, 0.36, "PC → rx", 12, U, True)
    x0, cw = 2.7, 0.84
    rxc = ["/", "g", "e", "t", "SP", "CR"]
    for i, c in enumerate(rxc):
        last = i == len(rxc) - 1
        box(s, x0 + i * cw, ry_, cw - 0.04, 0.4, c, 13, U if last else UL, U, "FFFFFF" if last else INK, 1.0,
            rounded=False)
    txc = list("12:34:56.78") + ["CR", "LF"]
    tx0 = x0 + 6 * cw
    for i, c in enumerate(txc):
        box(s, tx0 + i * cw, y0, cw - 0.04, 0.4, c, 13, PURL, PUR, INK, 1.0, rounded=False)
    T(s, x0, ry_ + 0.44, 6 * cw, 0.26, "6 글자 × 1.04 ms ≈ 6.25 ms", 10.5, U, True, al="c")
    T(s, tx0, y0 - 0.29, 13 * cw, 0.26, "13 글자 × 1.04 ms ≈ 13.5 ms  (sender 는 13 clk 만에 TX FIFO 에 다 넣음)", 10.5, PUR,
      True, al="c")
    # 확대 깔때기 (CR 끝 → 아래 clk 그림)
    zx = x0 + 6 * cw
    zt = ry_ + 0.85
    y0 = ry_
    lane_y = zt + 0.35
    fr = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, 0.92, lane_y - 0.15, 18.16, 10.45 - lane_y + 0.15, ZOOM_BG, U, 1.0,
               name="확대 틀")
    fr.adjustments[0] = 0.02
    fr.line.dash_style = MSO_LINE_DASH_STYLE.DASH
    seg(s, zx - 0.12, y0 + 0.42, 3.0, lane_y - 0.15, U, 1.0, dash=True)
    seg(s, zx + 0.12, y0 + 0.42, 18.9, lane_y - 0.15, U, 1.0, dash=True)
    T(s, zx + 0.15, ry_ + 0.07, 5.0, 0.28, "← CR 의 STOP 끝 = T0 → 아래에 clk 단위로 확대", 10.5, U, True)

    # clk 단위 줄 --------------------------------------------------------------
    lanes = [("uart_rx", "rx_done"), ("FIFO RX", "empty"), ("DECODER", "c_state"), ("", "handshake · ascii"),
             ("CONTROLLER", "send_go"), ("", "send_sel"), ("SENDER", "c_state · push"), ("FIFO TX", "empty"),
             ("uart_tx", "c_state · busy"), ("", "tx")]
    nT = 9
    lx0, lx1 = 3.95, 18.75
    tw = (lx1 - lx0) / nT
    ty = lane_y + 0.05
    for k in range(nT):
        T(s, lx0 + k * tw, ty, tw, 0.28, f"T{k}", 11, U if k in (0, 2, 3, 7) else G, True, al="c")
        if k:
            seg(s, lx0 + k * tw, ty + 0.3, lx0 + k * tw, 10.3, "D5D9DE", 0.75, arrow=False, dash=True)
    lh = 0.43
    ly0 = ty + 0.38

    def Y(i):
        return ly0 + i * lh

    for i, (m, sgl) in enumerate(lanes):
        if m:
            T(s, 1.05, Y(i) + 0.03, 1.4, 0.34, m, 10.5, U, True)
        T(s, 2.35, Y(i) + 0.03, 1.55, 0.34, sgl, 10, INK, al="r")

    def X(k):
        return lx0 + k * tw

    def wave(i, hi_ranges, c=U, start_hi=False):
        """디지털 줄 : hi_ranges = [(k0, k1)] 그 사이 1"""
        top, bot = Y(i) + 0.08, Y(i) + 0.34
        lvl = [start_hi] * nT
        for a, b in hi_ranges:
            for k in range(a, b):
                lvl[k] = not start_hi if not start_hi else False
        lvl = [False] * nT
        for a, b in hi_ranges:
            for k in range(a, min(b, nT)):
                lvl[k] = True
        prev = lvl[0]
        for k in range(nT):
            yv = top if lvl[k] else bot
            seg(s, X(k), yv, X(k + 1), yv, c, 2.0)
            if k and lvl[k] != lvl[k - 1]:
                seg(s, X(k), top, X(k), bot, c, 2.0)

    def bus(i, vals, c=U):
        """버스 줄 : vals = [(k0, k1, 글자)]"""
        top, bot = Y(i) + 0.06, Y(i) + 0.36
        for a, b, t_ in vals:
            xa, xb = X(a) + 0.05, X(b) - 0.05
            shp = shape(s, MSO_SHAPE.HEXAGON, xa, top, xb - xa, bot - top, "FFFFFF", c, 1.25, name="버스")
            shp.adjustments[0] = 0.08 * (bot - top) / (xb - xa) * 4
            set_text(shp, [t_], INK, [9.5], bold=False)

    wave(0, [(0, 1)])
    wave(1, [(0, 1), (2, 9)])
    bus(2, [(0, 2, "SPACE"), (2, 9, "IDLE")])
    wave(3, [(2, 3)])
    T(s, X(3) + 0.05, Y(3) + 0.04, 4.0, 0.3, "ascii 는 handshake 인 clk 에만 값, 그 밖 0", 9.5, G)
    wave(4, [(3, 4)])
    bus(5, [(0, 3, "이전 값"), (3, 9, "2 (지금 화면 : 시계)")])
    bus(6, [(0, 4, "IDLE"), (4, 9, "SEND · 매 clk push '1' '2' ':' … (13 clk)")])
    wave(7, [(0, 5)])
    bus(8, [(0, 6, "IDLE · busy 0"), (6, 9, "START · busy 1")])
    wave(9, [(0, 7)], c=PUR)
    # 사건 화살표 (빨강)
    ev = [(0, 0, 1, 1, "push"), (1, 1, 2, 3, "pop · 판별"), (3, 2, 3, 4, "send_pend → go"), (4, 3, 4, 6, "SEND"),
          (6, 4, 5, 7, "push → FIFO"), (7, 5, 6, 8, "start · pop"), (8, 6, 7, 9, "START → tx 0")]
    for li, ka, kb, lj, lab in ev:
        xa = X(ka) + tw * 0.5
        xb = X(kb) + 0.08
        ya_ = Y(li) + 0.34
        yb_ = Y(lj) + 0.1 if lj > li else Y(lj) + 0.2
        seg(s, xa, ya_, xb, yb_, RED, 1.25, arrow=True)
    # 오른쪽 메모
    T(s, X(7) + 0.1, Y(9) + 0.0, 2.0, 0.36, "← tx 0 = START", 10, PUR, True)
    runs(s, 1.05, 10.08 - 0.02, 17.5, 0.3, [("빨간 화살표 = 다음 단계가 그 값을 본 clk", RED, True),
                                              ("  ·  rx_done → handshake +2 (파형 P1 · P2 · P4) → send_go · 버튼 펄스 +1 (P2-B · P4-B)", INK,
                                               False)], 10.5)
    return s


SLIDES = [("U0", u0), ("U1", u1), ("U2", u2), ("U3", u3), ("U4", u4), ("U5", u5), ("U6", u6)]


# ---------------------------------------------------------------- 끼우기 · 쪽 번호
def page_box(sl):
    for sh in sl.shapes:
        if sh.has_text_frame and sh.text_frame.text.strip().isdigit() and abs(sh.left - Inches(18.2)) < Inches(0.05):
            return sh
    return None


def build(src, out):
    prs = Presentation(src)
    lst = prs.slides._sldIdLst
    for sid, sl in list(zip(list(lst), list(prs.slides))):          # 이전에 끼운 장 지우기
        if any(sh.name.startswith("uart:") for sh in sl.shapes):
            prs.part.drop_rel(sid.rId)
            lst.remove(sid)
    prs.part.rename_slide_parts([sid.rId for sid in lst])
    slides = list(prs.slides)
    pos = next((i for i, sl in enumerate(slides) if any(sh.name.startswith("wave:") for sh in sl.shapes)), len(slides))
    pb = page_box(slides[pos]) if pos < len(slides) else None
    first = int(pb.text_frame.text) if pb else pos + 1
    P = {tag: first + i for i, (tag, _) in enumerate(SLIDES)}
    n0 = len(lst)
    for tag, fn in SLIDES:
        fn(prs, P[tag], P)
        check(prs, prs.slides[-1], tag)
        print(f"slide {P[tag]:02d}  {tag}")
    new = list(lst)[n0:]
    for k, sid in enumerate(new):
        lst.remove(sid)
        lst.insert(pos + k, sid)
    prs.part.rename_slide_parts([sid.rId for sid in lst])
    # 뒤 장 쪽 번호 밀기
    for i, sl in enumerate(list(prs.slides)[pos + len(SLIDES):]):
        b = page_box(sl)
        if b:
            r = b.text_frame.paragraphs[0].runs[0]
            r.text = f"{first + len(SLIDES) + i:02d}"
    prs.save(out)
    names = __import__("zipfile").ZipFile(out).namelist()
    dup = sorted({n for n in names if names.count(n) > 1})
    if dup:
        raise SystemExit(f"zip 안에 같은 이름 : {dup}")


if __name__ == "__main__":
    a = sys.argv[1:]
    build(a[0], a[1] if len(a) > 1 else a[0])
