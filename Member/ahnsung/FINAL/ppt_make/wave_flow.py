# final_ppt_v2.pptx 파형 장 5 개 : 화살표를 따라가면 '무엇이 어떤 순서로 나오는지' 보이게
# 사용 : python wave_flow.py final_ppt_v2.pptx [out.pptx]          (다시 돌려도 됨 : 이전에 넣은 번호 · 화살표 · 이름 글은 지우고 새로)
#   - 화살표 끝 = 사건 지점 (파형은 안 가림), 번호 원 = 화살표 가운데 (1 번은 들어오는 짧은 화살표 꼬리)
#   - 빨간 테두리 신호 이름 → 이름 칸 위에 읽을 수 있는 크기로 '이름 + 뜻' (검은 바탕 = 원래 작은 글자 가림), 테두리 0.75 pt
#   - 노란 이름표 · 흰 바탕 꼬리표 → 채우기 없음 + 흰 글씨, 빨간 선 · 점선 0.75 pt
#   - 좌표 = 슬라이드 렌더 2000 × 1125 px 기준 (200 px = 1 in)
import sys
from PIL import ImageFont
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_CONNECTOR, MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Emu, Pt

SRC = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else SRC
IN = 914400
PX = IN // 200
RED = RGBColor(0xFF, 0x30, 0x30)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
GRAY = RGBColor(0xC8, 0xC8, 0xC8)
BLACK = RGBColor(0x00, 0x00, 0x00)
FB = ImageFont.truetype("/mnt/c/Windows/Fonts/malgunbd.ttf", 100)
FR = ImageFont.truetype("/mnt/c/Windows/Fonts/malgun.ttf", 100)
THIN = {"빨간 상자", "빨간 타원", "점선", "선", "빨간 동그라미", "화살표", "간격 화살표", "전체 화살표"}
MINE = ("번호 ", "순서 화살표", "신호 이름")      # 이 스크립트가 넣는 것 (다시 돌릴 때 지움)

MEAN = {
    "rx": "PC → 보드 UART 입력", "c_state": "디코더 상태", "sw": "보드 스위치 sw6 ~ sw0",
    "w_uart_mode": "1 = UART 제어", "w_disp_sel": "화면 선택",
    "FND_DATA": "FND 글자", "o_send_sel": "전송 MUX 선택 (0 SW ~ 4 TEMP)", "W_LINE": "PC 가 받은 줄",
    "trig": "초음파 발사 (FPGA → SR04)", "echo": "반사파 (SR04 → FPGA)",
    "w_dist_status": "거리 상태 0 정상 · 1~3 Err", "w_distance": "거리 값 (cm)", "LD9": "오류 LED",
    "w_handshake": "명령 하나 끝 (1 clk)", "w_uart_btn_R": "UART 로 누른 버튼 R", "w_send_go": "한 줄 송신 시작",
    "tx": "보드 → PC UART 출력", "dht11_io": "DHT11 데이터 선", "w_dht_oe": "1 = 선 LOW 잡음",
    "w_dht_status": "0 정상 · 1~3 Err",
}

# P5-1 : 파형 그림 px → 렌더 px
p51 = lambda x, y: ((0.46 + x * 8.75 / 2000) * 200, (1.5 + y * 3.614 / 826) * 200)

CFG = {
    "wave:P1-A": dict(
        text={46: "2. rx 로 /mod dist 9 글자 입력", 47: "3. 't' 수신 → 거리 화면", 48: "1. sw6 = 1 → 온습도 화면",
              49: "4. 스위치 바꿔도 그대로"},
        delete=[30],
        names=(48, 244, ["rx", "c_state", "sw", "w_uart_mode", "w_disp_sel", "FND_DATA"]),
        steps=[(417, 655), (660, 470), (1403, 586), (1700, 655)], lead=(-60, -45)),
    "wave:P3-A": dict(
        text={127: "1. /auto all 수신 → 1 s 카운트 시작", 128: "2. 1 Hz tick → send_go (간격 1,000,000 us)",
              129: "3. send_go 순간 sel 0 줄 → tx → W_LINE = SW", 130: "※ DHT11 부팅 1 s 뒤 측정 → 55.24 (TEMP 줄 값)"},
        add=[("4. 1 s 마다 sel 0 → 1 → 2 → 3 → 4 → 0 : SW → TM → WH → DIST → TEMP → SW …", 800, 349)],
        move={129: (960, 547)},
        delete=[],
        names=(94, 384, ["o_send_sel", "W_LINE"]),
        steps=[(402, 398), (563, 580), (575, 695), (727, 695)], lead=(150, 0),
        chain=[(881, 695), (1035, 695), (1188, 695), (1342, 695), (1496, 695), (1650, 695)]),
    "wave:P5-A": dict(
        text={39: "1. Err1 : echo 안 옴 → 30 ms → status 1", 40: "3. Err2 : echo 23.25 ms → status 2",
              41: "5. Err3 : echo 고착 → 73.2 ms → status 3", 50: "2. /get → PC ← Err 1", 51: "4. /get → PC ← Err 2"},
        delete=[42],
        names=(48, 340, ["trig", "echo", "w_dist_status", "w_distance", "FND_DATA", "LD9", "W_LINE"]),
        steps=[(649, 617), (773, 882), (1044, 617), (1165, 882), (1801, 617)], lead=(-60, -40)),
    "wave:P5-1": dict(
        text={}, delete="circles",
        names=(94, 468, ["w_handshake", "w_uart_btn_R", "trig", "echo", "w_dist_status", "FND_DATA", "LD9",
                         "w_send_go", "o_send_sel", "tx", "W_LINE"]),
        steps=[p51(611, 288), p51(741, 312), p51(1236, 455), p51(1450, 647), p51(1568, 766)], lead=(-75, 0)),
    "wave:P6-A": dict(
        text={37: "1. 측정 전 /get → PC ← --%--C", 35: "2. 1 s : 시작 LOW 18 ms → 응답 없음 → status 1",
              36: "4. + 2 s : 20 비트 뒤 끊김 → status 2", 45: "3. /get → PC ← Err 1", 46: "5. /get → PC ← Err 2"},
        delete=[38],
        move={37: (330, 396)},
        names=(46, 290, ["dht11_io", "w_dht_oe", "w_dht_status", "FND_DATA", "W_LINE"]),
        steps=[(326, 879), (634, 614), (645, 879), (1259, 614), (1270, 879)], lead=(45, -55)),
}


def tw(text, pt, bold=True):
    return int((FB if bold else FR).getlength(text) / 100 * pt / 72 * IN)


def font(r, pt, bold, color):
    r.font.size, r.font.bold, r.font.color.rgb, r.font.name = Pt(pt), bold, color, "Malgun Gothic"
    rpr = r._r.get_or_add_rPr()
    if rpr.find(qn("a:ea")) is None:
        rpr.append(rpr.makeelement(qn("a:ea"), {"typeface": "Malgun Gothic"}))


def tight(tf):
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.word_wrap = False
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE


def white_text(sh, text=None):
    """채우기 · 테두리 없애고 글자 흰색 (글자 바꾸면 폭도 맞춤)"""
    sh.fill.background()
    sh.line.fill.background()
    runs = [r for p in sh.text_frame.paragraphs for r in p.runs]
    if text is not None and runs[0].text != text:
        runs[0].text = text
        for r in runs[1:]:
            r.text = ""
        pt = runs[0].font.size.pt if runs[0].font.size else 6.5
        nw = tw(text, pt) + 50000
        if sh.text_frame.paragraphs[0].alignment == PP_ALIGN.CENTER and sh.name != "이름표":
            sh.left = Emu(int(sh.left + sh.width / 2 - nw / 2))
        sh.width = Emu(nw)
        sh.text_frame.word_wrap = False
    for r in runs:
        r.font.color.rgb = WHITE
        r.font.bold = True


def new_label(s, text, x, y, pt=6.25):
    w, h = tw(text, pt) + 50000, int(0.11 * IN)
    tb = s.shapes.add_textbox(Emu(int(x * PX)), Emu(int(y * PX - h / 2)), Emu(w), Emu(h))
    tb.name = "이름표"
    tight(tb.text_frame)
    font(tb.text_frame.paragraphs[0].add_run(), pt, True, WHITE)
    tb.text_frame.paragraphs[0].runs[0].text = text


def name_tag(s, nm, x1, x2, cy, h):
    """이름 칸 위 : 검은 바탕 + 흰 굵은 이름 + 회색 뜻, 빨간 0.75 pt 테두리"""
    W = (x2 - x1) * PX - 30000
    mean = MEAN.get(nm, "")
    for pt in (6.5, 6.25, 6.0, 5.75, 5.5, 5.25, 5.0):
        if tw(nm, pt) + tw("  " + mean, pt - 0.5, False) <= W:
            break
    else:
        mean = ""
        pt = 6.0
        while pt > 4.5 and tw(nm, pt) > W:
            pt -= 0.25
    sh = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, Emu(int(x1 * PX)), Emu(int(cy * PX - h / 2)),
                            Emu(int((x2 - x1) * PX)), Emu(int(h)))
    sh.name = "신호 이름"
    sh.fill.solid()
    sh.fill.fore_color.rgb = BLACK
    sh.line.color.rgb = RED
    sh.line.width = Pt(0.75)
    sh.shadow.inherit = False
    tf = sh.text_frame
    tight(tf)
    tf.margin_left = 15000
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.LEFT
    r = p.add_run()
    r.text = nm
    font(r, pt, True, WHITE)
    if mean:
        r = p.add_run()
        r.text = "  " + mean
        font(r, pt - 0.5, False, GRAY)


def badge(s, n, cx, cy, d=0.15):
    D = int(d * IN)
    sh = s.shapes.add_shape(MSO_SHAPE.OVAL, Emu(int(cx * PX - D / 2)), Emu(int(cy * PX - D / 2)), Emu(D), Emu(D))
    sh.name = "번호 %d" % n
    sh.fill.solid()
    sh.fill.fore_color.rgb = RED
    sh.line.color.rgb = WHITE
    sh.line.width = Pt(0.5)
    sh.shadow.inherit = False
    tight(sh.text_frame)
    p = sh.text_frame.paragraphs[0]
    p.alignment = PP_ALIGN.CENTER
    r = p.add_run()
    r.text = str(n)
    font(r, 6.5, True, WHITE)


def arrow(s, a, b, g1=5, g2=5):
    (x1, y1), (x2, y2) = a, b
    dx, dy = x2 - x1, y2 - y1
    L = (dx * dx + dy * dy) ** 0.5
    ux, uy = dx / L, dy / L
    c = s.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, Emu(int((x1 + ux * g1) * PX)), Emu(int((y1 + uy * g1) * PX)),
                               Emu(int((x2 - ux * g2) * PX)), Emu(int((y2 - uy * g2) * PX)))
    c.name = "순서 화살표"
    c.line.color.rgb = RED
    c.line.width = Pt(1.0)
    ln = c.line._get_or_add_ln()
    ln.append(ln.makeelement(qn("a:tailEnd"), {"type": "triangle", "w": "med", "len": "med"}))


prs = Presentation(SRC)
done = []
for s in prs.slides:
    wave = next((sh.name for sh in s.shapes if sh.name in CFG), None)
    if not wave:
        continue
    cfg = CFG[wave]
    # 신호 이름 행 (빨간 테두리 / 이전에 넣은 이름 글) 위치 기억 → 지움
    rows = sorted(((sh.top + sh.height / 2) / PX, sh.height) for sh in s.shapes if sh.name == "신호 이름")
    for sh in list(s.shapes):
        if sh.name.startswith(MINE):
            sh._element.getparent().remove(sh._element)
    by = {sh.shape_id: sh for sh in s.shapes}
    # 지우기
    if cfg["delete"] == "circles":
        for sh in list(s.shapes):
            if sh.name == "빨간 동그라미":
                cx, cy = (sh.left + sh.width / 2) / PX, (sh.top + sh.height / 2) / PX
                if any(abs(cx - x) < 6 and abs(cy - y) < 6 for x, y in cfg["steps"]):
                    sh._element.getparent().remove(sh._element)
    else:
        for i in cfg["delete"]:
            if i in by:
                by[i]._element.getparent().remove(by[i]._element)
    # 이름표 · 꼬리표 → 투명 + 흰 글씨
    for sh in s.shapes:
        if sh.shape_id in cfg["text"]:
            white_text(sh, cfg["text"][sh.shape_id])
        elif sh.name in ("이름표", "꼬리표"):
            white_text(sh)
    for i, (x, y) in cfg.get("move", {}).items():
        sh = by.get(i)
        if sh is not None and sh._element.getparent() is not None:
            sh.left, sh.top = Emu(int(x * PX)), Emu(int(y * PX - sh.height / 2))
    texts = {sh.text_frame.text for sh in s.shapes if sh.has_text_frame}
    for t, x, y in cfg.get("add", []):
        if t not in texts:
            new_label(s, t, x, y)
    for sh in s.shapes:
        if sh.name in THIN:
            sh.line.width = Pt(0.75)
    # 신호 이름 + 뜻
    x1, x2, names = cfg["names"]
    assert len(rows) == len(names), (wave, len(rows), names)
    for (cy, h), nm in zip(rows, names):
        name_tag(s, nm, x1, x2, cy, max(h, int(0.095 * IN)))
    # 화살표 (끝 = 사건 지점) + 번호 (화살표 가운데, 1 번은 꼬리)
    pts = cfg["steps"]
    lx, ly = cfg["lead"]
    start = (pts[0][0] + lx, pts[0][1] + ly)
    arrow(s, start, pts[0], g1=0)
    for a, b in zip(pts, pts[1:]):
        arrow(s, a, b)
    ch = [pts[-1]] + cfg.get("chain", [])
    for a, b in zip(ch, ch[1:]):
        arrow(s, a, b)
    badge(s, 1, *start)
    for n, (a, b) in enumerate(zip(pts, pts[1:]), 2):
        badge(s, n, (a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    done.append(wave)

prs.save(OUT)
print("저장", OUT, done)
