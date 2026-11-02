# final_ppt_v2.pptx P5-1 (SR04 Err1) : UART rx 명령 → handshake → FND 변화 → /get → sender → tx → UART 송출 화면 흐름 표시
# 사용 : python p5_1_io.py final_ppt_v2.pptx [out.pptx]   → 이어서 signal_names.py · wave_anim.py
#   - 새 도형 이름 'P51-<단계> …' (wave_anim 이 단계별 클릭으로 묶음), 다시 돌리면 지우고 새로
#   - 이름표 = 채우기 없음 + 흰 글씨, 표시 = 빨간 0.75 pt 동그라미 · 점선 · 상자
#   - 흐름에 필요한 신호 (rx · W_RX · c_state · handshake · btn_R · send_go · sel · tx) 에 빨간 테두리 추가 → signal_names 가 쉬운 이름으로
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
RED = RGBColor(0xFF, 0x30, 0x30)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
FONT = ImageFont.truetype("/mnt/c/Windows/Fonts/malgunbd.ttf", 100)
SZ = 6.25

prs = Presentation(SRC)
s = next(sl for sl in prs.slides if any(x.name == "wave:P5-1" for x in sl.shapes))
pic = next(x for x in s.shapes if x.shape_type == 13)
L, T, W, H = pic.left, pic.top, pic.width, pic.height
X = lambda px: int(L + px * W / 2000)          # wave_img/P5-1_Err1.png (2000 × 826)
Y = lambda py: int(T + py * H / 826)

# 이전에 넣은 것 · 직접 그린 '1. 모드 전환' 글 상자와 동그라미 지움
for x in list(s.shapes):
    if x.name.startswith("P51-") or x.name in ("TextBox 31", "타원 30"):
        x._element.getparent().remove(x._element)


def tag(sh, step, what):
    sh.name = "P51-%d %s" % (step, what)
    return sh


def circle(step, px, py, r=9):
    sh = s.shapes.add_shape(MSO_SHAPE.OVAL, X(px - r), Y(py - r * 1.2), X(2 * r) - X(0), Y(2.4 * r) - Y(0))
    sh.fill.background()
    sh.line.color.rgb = RED
    sh.line.width = Pt(0.75)
    sh.shadow.inherit = False
    tag(sh, step, "동그라미")


def rbox(step, x1, x2, py, h=20):
    sh = s.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, X(x1), Y(py - h / 2), X(x2) - X(x1), Y(h) - Y(0))
    sh.adjustments[0] = 0.3
    sh.fill.background()
    sh.line.color.rgb = RED
    sh.line.width = Pt(0.75)
    sh.shadow.inherit = False
    tag(sh, step, "상자")


def dash(step, px, y1, y2):
    c = s.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, X(px), Y(y1), X(px), Y(y2))
    c.line.color.rgb = RED
    c.line.width = Pt(0.75)
    ln = c.line._get_or_add_ln()
    ln.append(ln.makeelement(qn("a:prstDash"), {"val": "dash"}))
    tag(c, step, "점선")


def label(step, text, px, py, al="l"):
    w = int(FONT.getlength(text) / 100 * SZ / 72 * IN * 1.08) + 40000
    h = int(0.11 * IN)
    x = X(px) - (w // 2 if al == "c" else w if al == "r" else 0)
    tb = s.shapes.add_textbox(x, Y(py) - h // 2, w, h)
    tf = tb.text_frame
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.word_wrap = False
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.LEFT
    r = p.add_run()
    r.text = text
    r.font.size, r.font.bold, r.font.color.rgb, r.font.name = Pt(SZ), True, WHITE, "Malgun Gothic"
    rpr = r._r.get_or_add_rPr()
    rpr.append(rpr.makeelement(qn("a:ea"), {"typeface": "Malgun Gothic"}))
    assert L <= x and x + w <= L + W, ("이름표가 파형 밖", text)
    tag(tb, step, "이름표")


def white(sh, text):
    """기존 노란 이름표 → 투명 + 흰 글씨, 글자 바꿈"""
    sh.fill.background()
    sh.line.fill.background()
    runs = [r for p in sh.text_frame.paragraphs for r in p.runs]
    runs[0].text = text
    for r in runs[1:]:
        r.text = ""
    for r in runs:
        r.font.color.rgb = WHITE
        r.font.bold = True
    pt = runs[0].font.size.pt if runs[0].font.size else SZ
    sh.width = Emu(int(FONT.getlength(text) / 100 * pt / 72 * IN * 1.08) + 40000)
    sh.text_frame.word_wrap = False


# ---------------------------------------------------------------- 1. /mod dist → handshake → FND 거리 화면
label(1, "/mod dist", 563, 168, "c")
circle(1, 611, 288)
circle(1, 608, 575)
dash(1, 611, 298, 512)
label(1, "1. rx 로 /mod dist → handshake (10.2 ms) → FND 00.00 → 000.0 (거리 화면)", 450, 527)

# ---------------------------------------------------------------- 2. /btn R → handshake → btn_R → trig
label(2, "/btn R", 698, 168, "c")
circle(2, 741, 288)
circle(2, 741, 312)
circle(2, 741, 360)
label(2, "2. rx 로 /btn R → handshake → UART 버튼 R → SR04 trig (18.1 ms)", 752, 336)

# ---------------------------------------------------------------- 3. echo 없음 → Err1 (기존 이름표 · 점선 + 동그라미)
circle(3, 1236, 455)
circle(3, 1236, 575)

# ---------------------------------------------------------------- 4. /get → handshake → send_go · 송신 줄 3
label(4, "/get CR", 1407, 168, "c")
circle(4, 1450, 288)
circle(4, 1450, 647)
circle(4, 1450, 671)
dash(4, 1450, 298, 505)
dash(4, 1450, 545, 732)
label(4, "4. rx 로 /get → handshake (61.1 ms) → 송신 시작 · 송신 줄 3 (거리)", 1440, 623, "r")

# ---------------------------------------------------------------- 5. sender → tx → UART 송출 화면 (기존 이름표 · 화살표 · 상자)
rbox(5, 1450, 1566, 742)

# 기존 노란 이름표 → 흰 글씨, 번호 맞춤
for x in s.shapes:
    if x.shape_id == 27:
        white(x, "3. echo 없이 30 ms → 48.2 ms : SR04 오류 상태 1 · FND Err1 · LD9")
    elif x.shape_id == 28:
        white(x, "5. sender → tx → UART 송출 화면 Err 1")

# 흐름 신호 빨간 테두리 추가 (이미 있으면 건너뜀) : 기존 테두리와 같은 왼쪽 · 높이
boxes = [x for x in s.shapes if x.name == "신호 이름"]
ref = boxes[0]
have = [(x.top + x.height / 2) for x in boxes]
for py in (144, 216, 240, 288, 312, 647, 671, 742):
    cy = Y(py)
    if any(abs(cy - h) < 0.03 * IN for h in have):
        continue
    sh = s.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, ref.left, Emu(int(cy - ref.height / 2)), ref.width, ref.height)
    sh.name = "신호 이름"
    sh.fill.background()
    sh.line.color.rgb = RGBColor(0xFF, 0x00, 0x00)
    sh.line.width = Pt(0.75)
    sh.shadow.inherit = False

prs.save(OUT)
print("저장", OUT)
