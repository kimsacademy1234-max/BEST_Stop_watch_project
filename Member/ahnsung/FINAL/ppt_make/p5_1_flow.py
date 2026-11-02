# final_ppt_v2.pptx 의 P5-1 (SR04 Err1) 장 : /mod dist → /btn R → Err1 → /get → sender 송신 흐름을 파형 위에 5 단계로 표시
# 사용 : python p5_1_flow.py final_ppt_v2.pptx [out.pptx]
#   - 이름표 = 채우기 없는 투명 상자 + 흰 글씨 (파형 가리지 않게), 사건 지점 = 가는 빨간 동그라미 · 점선
#   - 신호 이름 · 값 테두리 = 0.75 pt 빨강
#   - 다시 돌려도 됨 : 파형 그림 · 머리말 · 결론 · 쪽 번호 빼고 지운 뒤 새로 그림
import sys
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_CONNECTOR, MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Emu, Pt
from PIL import ImageFont

SRC = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else SRC
IN = 914400
RED = RGBColor(0xFF, 0x30, 0x30)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
FONT = ImageFont.truetype("/mnt/c/Windows/Fonts/malgunbd.ttf", 100)
SZ = 6.5

prs = Presentation(SRC)
s = next(sl for sl in prs.slides if any(sh.name == "wave:P5-1" for sh in sl.shapes))
pic = next(sh for sh in s.shapes if sh.shape_type == 13)
IW, IH = 2000, 826                                       # wave_img/P5-1_Err1.png
L, T, W, H = pic.left, pic.top, pic.width, pic.height
X = lambda px: int(L + px * W / IW)
Y = lambda py: int(T + py * H / IH)

# 파형 그림 · 머리말 · 결론 · 쪽 번호만 남김
keep = {"라벨", "shape", "결론 상자", "결론 칩", "결론 1", "결론 2", "파형"}
for sh in list(s.shapes):
    if not (sh.name in keep or sh.name.startswith("wave:")):
        sh._element.getparent().remove(sh._element)


def thin_red(sh, w=0.75):
    sh.fill.background()
    sh.line.color.rgb = RED
    sh.line.width = Pt(w)
    sh.shadow.inherit = False


def rbox(x1, x2, ry, h=18, name="빨간 상자"):
    sh = s.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, X(x1), Y(ry - h / 2), X(x2) - X(x1), Y(h) - Y(0))
    sh.adjustments[0] = 0.3
    thin_red(sh)
    sh.name = name
    return sh


def circle(px, py, r=9):
    sh = s.shapes.add_shape(MSO_SHAPE.OVAL, X(px - r), Y(py - r * 1.2), X(2 * r) - X(0), Y(2.4 * r) - Y(0))
    thin_red(sh)
    sh.name = "빨간 동그라미"


def vline(px, y1, y2, dash=True, color=RED, w=0.75, arrow=False, name="점선"):
    c = s.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, X(px), Y(y1), X(px), Y(y2))
    c.line.color.rgb = color
    c.line.width = Pt(w)
    if dash:
        ln = c.line._get_or_add_ln()
        d = ln.makeelement(qn("a:prstDash"), {"val": "dash"})
        ln.append(d)
    c.name = name
    return c


def hline(x1, x2, py, color=WHITE, w=1.0, arrow=True, name="화살표"):
    c = s.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, X(x1), Y(py), X(x2), Y(py))
    c.line.color.rgb = color
    c.line.width = Pt(w)
    if arrow:
        ln = c.line._get_or_add_ln()
        ln.append(ln.makeelement(qn("a:tailEnd"), {"type": "triangle"}))
    c.name = name


def label(text, px, py, al="l", sz=SZ, maxw=None):
    if maxw:                                # 칸 폭 (원본 px) 안에 들어가게 글자 줄임
        while sz > 5.0 and FONT.getlength(text) / 100 * sz / 72 * IN > X(maxw) - X(0):
            sz -= 0.25
    w = int(FONT.getlength(text) / 100 * sz / 72 * IN) + 40000
    h = int(0.11 * IN)
    x = X(px) - (w // 2 if al == "c" else w if al == "r" else 0)
    tb = s.shapes.add_textbox(x, Y(py) - h // 2, w, h)
    tb.name = "흰 이름표"
    tf = tb.text_frame
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.word_wrap = False
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.LEFT
    r = p.add_run()
    r.text = text
    f = r.font
    f.size, f.bold, f.color.rgb, f.name = Pt(sz), True, WHITE, "Malgun Gothic"
    r._r.get_or_add_rPr().get_or_add_latin()  # latin 은 name 으로 이미 들어감
    rpr = r._r.get_or_add_rPr()
    rpr.append(rpr.makeelement(qn("a:ea"), {"typeface": "Malgun Gothic"}))
    assert L <= x and x + w <= L + W, ("이름표가 파형 밖", text)
    return tb


# ---------------------------------------------------------------- 신호 이름 테두리 (0.75 pt)
NAME_X = 62
for nm, ry in [("w_handshake", 288), ("w_uart_btn_R", 312), ("trig", 360), ("echo", 384),
               ("w_dist_status[1:0]", 455), ("FND_DATA[63:0]", 575), ("LD9", 599),
               ("w_send_go", 647), ("o_send_sel[2:0]", 671), ("tx", 742), ("W_LINE[127:0]", 766)]:
    rbox(NAME_X - 16, NAME_X + sum(7.6 if ch.isupper() else 5.4 for ch in nm) + 8, ry, name="신호 이름")

# ---------------------------------------------------------------- 1. /mod dist → 거리 모드
circle(611, 288)                       # handshake
circle(608, 575)                       # FND 00.00 → 000.0
vline(611, 298, 565)
label("1. /mod dist → 거리 모드", 735, 336, al="r")

# ---------------------------------------------------------------- 2. /btn R → w_uart_btn_R → trig
circle(741, 288)
circle(741, 312)
circle(741, 360)
label("2. /btn R → w_uart_btn_R 1 clk → trig (18.1 ms) · 측정 시작", 1000, 336)

# ---------------------------------------------------------------- 3. echo 없음 30 ms → Err1
vline(1236, 352, 610)
label("3. echo 없이 30 ms → 48.2 ms : status 1 · FND Err1 · LD9", 1226, 527, al="r")

# ---------------------------------------------------------------- 4. /get → send_go · sel 3
circle(1450, 288)
circle(1450, 647)
vline(1450, 298, 662)
label("4. /get (61.1 ms) → w_send_go · o_send_sel 0 → 3 (거리)", 1440, 623, al="r")

# ---------------------------------------------------------------- 5. sender → tx → PC
rbox(1450, 1566, 742, h=20)            # tx 글자 전송 구간
rbox(1572, 1994, 766)                  # W_LINE = Err 1
hline(1340, 1562, 766)
label("5. sender → TX FIFO → tx → PC 'Err 1' (68.4 ms)", 1330, 766, al="r")

# ---------------------------------------------------------------- 아스키 값 → 글자 (투명 상자 + 흰 글씨)
# W_RX : 바로 위 빈 줄 (UART RX 머리 행) 에 명령 단위로 · 범위 = 첫 글자 rx_done ~ 다음 명령
for t_, x1, x2 in [("/mod dist", 473, 654), ("/btn R", 654, 741), ("/get CR", 1363, 1450), ("/btn R", 1808, 1894)]:
    label(t_, (x1 + x2) / 2, 168, al="c", maxw=x2 - x1 + 30)
# c_state : 바로 아래 빈 버스 (w_ascii 행) 에 상태 순서 · done 뒤 IDLE
for t_, x1, w_ in [("SLASH m o d SPACE", 473, 158), ("SLASH b t n SPACE → IDLE", 660, 300),
                   ("SLASH g e t SPACE → IDLE", 1363, 300), ("SLASH b t n SPACE", 1808, 180)]:
    label(t_, x1, 264, maxw=w_)
# FND_DATA · W_LINE : 넓은 칸 왼쪽에 값 크게
for t_, x1, ry in [("00.00", 452, 575), ("000.0", 632, 575), ("Err1", 1248, 575), ("Err 1", 1600, 766)]:
    label(t_, x1, ry)

prs.save(OUT)
print("저장", OUT)
