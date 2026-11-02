# final_ppt.pptx 16 장 (디코더) : 맨 아래 '예 /mod dist' 밑에 틀린 글자 예시 '/mdo temp' 줄 추가 (제자리 수정)
# RTL 근거 : 02_UART_ASCII_DECODER.sv — m 상태에서 'o' 아닌 글자 → bad → 다음 clk error = 1, 깃발 · data_reg 지움, IDLE
#            IDLE 에서는 '/' 아닌 글자 무시 (error 안 냄)
import copy
import sys
from PIL import ImageFont
from pptx import Presentation
from pptx.util import Emu

SRC = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else SRC
IN = 914400
FONT = {False: ImageFont.truetype("/mnt/c/Windows/Fonts/malgun.ttf", 100),
        True: ImageFont.truetype("/mnt/c/Windows/Fonts/malgunbd.ttf", 100)}


def text_w(t, pt, bold):  # EMU
    return int(FONT[bold].getlength(t) / 100 * pt / 72 * IN)


prs = Presentation(SRC)
s = prs.slides[15]
by_id = {sh.shape_id: sh for sh in s.shapes}
assert by_id[139].text_frame.text.startswith("예  /mod dist"), "16 장이 아님"
if any(sh.name.startswith("bad예") for sh in s.shapes):
    sys.exit("이미 추가됨")

tree = s.shapes._spTree
next_id = max(by_id) + 1
RED, REDL, GRAY, GRAYL = "C53030", "FDECEC", "8C8C8C", "F2F2F2"


def clone(src_id, x, y, w, h, text, name, fill=None, line=None, color=None, bold=None, size=None):
    global next_id
    el = copy.deepcopy(by_id[src_id]._element)
    el.nvSpPr.cNvPr.set("id", str(next_id))
    el.nvSpPr.cNvPr.set("name", name)
    next_id += 1
    tree.append(el)
    sh = s.shapes[-1]
    sh.left, sh.top, sh.width, sh.height = Emu(x), Emu(y), Emu(w), Emu(h)
    r = sh.text_frame.paragraphs[0].runs[0]
    r.text = text
    if color:
        r.font.color.rgb = __import__("pptx").dml.color.RGBColor.from_string(color)
    if bold is not None:
        r.font.bold = bold
    if size:
        r.font.size = size
    if fill:
        sh.fill.solid()
        sh.fill.fore_color.rgb = __import__("pptx").dml.color.RGBColor.from_string(fill)
    if line:
        sh.line.color.rgb = __import__("pptx").dml.color.RGBColor.from_string(line)
    return sh


# 1) 첫 줄 끝 : 설명 줄 (158) 을 지우고 끝 라벨에 handshake 를 붙임
by_id[158]._element.getparent().remove(by_id[158]._element)
lab = by_id[157]
lab.text_frame.paragraphs[0].runs[0].text = "→ done · handshake = 1"
lab.width = Emu(text_w("→ done · handshake = 1", 6.75, True) + 20000)
# 첫 줄 9 칸 : 라벨 실제 폭대로 다시 늘어놓아 끝 라벨 자리 확보 (남는 폭은 칸 사이에 고르게)
x0 = by_id[140].left
right_lim = int(9.45 * IN)
items = []
for bid in range(140, 158, 2):
    lb = by_id[bid + 1]
    r = lb.text_frame.paragraphs[0].runs[0]
    lw = text_w(r.text, r.font.size.pt, bool(r.font.bold)) + 20000
    lb.width = Emu(lw)
    items.append((by_id[bid], lb, 214884 + lw))
gap = (right_lim - x0 - sum(w for _, _, w in items)) // (len(items) - 1)
assert gap > 50000, "첫 줄 칸 부족"
x = x0
for bx, lb, w in items:
    bx.left = Emu(x)
    lb.left = Emu(x + 214884)
    x += w + gap

# 2) 둘째 줄
y1 = by_id[140].top                     # 첫 줄 상자 위
dy = 246888                             # 0.27 in
yb = y1 + dy                            # 상자 위
bs = by_id[140].width                   # 상자 한 변 (0.21 in)
ly = by_id[141].top + dy                # 라벨 위
lh = by_id[141].height
cols = [by_id[i].left for i in (140, 142, 144, 146, 148)]   # 첫 줄 상자 x (줄 맞춤)

clone(139, by_id[139].left, by_id[139].top + dy, by_id[139].width, by_id[139].height,
      "예  /mdo temp", "bad예 라벨", color=RED)
# '/' · 'm' : 첫 줄과 같은 꼴
clone(140, cols[0], yb, bs, bs, "/", "bad예 상자")
clone(141, cols[0] + 214884, ly, 599440, lh, "→ SLASH", "bad예 라벨")
clone(140, cols[1], yb, bs, bs, "m", "bad예 상자")
clone(141, cols[1] + 214884, ly, text_w("→ m · mode=1", 6.75, False) + 40000, lh, "→ m · mode=1", "bad예 라벨")
# 'd' : 틀린 글자 (빨강)
clone(156, cols[2], yb, bs, bs, "d", "bad예 상자", fill=RED, line=RED)
t_bad = "→ bad ('o' 자리) → error = 1 · IDLE"
x = cols[2] + 214884
w = text_w(t_bad, 6.75, True) + 20000
clone(157, x, ly, w, lh, t_bad, "bad예 라벨", color=RED)
# 나머지 'o temp' : 회색 (IDLE 이라 무시)
x += w + 70000
for c in ["o", "SP", "t", "e", "m", "p"]:
    clone(140, x, yb, bs, bs, c, "bad예 상자", fill=GRAYL, line="BFBFBF", color=GRAY)
    x += bs + 27432
t_ign = "→ IDLE 이라 무시 (error 안 냄) → ERROR 응답 1 번"
x += 20000
w = text_w(t_ign, 6.75, False) + 20000
clone(141, x, ly, w, lh, t_ign, "bad예 라벨", color=RED)
right = x + w
frame = by_id[28]
print("둘째 줄 오른쪽 끝 %.2f in / 확대 틀 오른쪽 %.2f in" % (right / IN, (frame.left + frame.width) / IN))
assert right < frame.left + frame.width - 60000, "칸 넘침"

# 3) 확대 틀 아래로 늘림 (둘째 줄 상자 아래 + 0.08 in)
frame.height = Emu(yb + bs + 73152 - frame.top)
print("확대 틀 아래 %.2f in / 쪽 번호 위 %.2f in" % ((frame.top + frame.height) / IN, by_id[10].top / IN))

# 4) 노트
tf = s.notes_slide.notes_text_frame
tf.text = tf.text + (" 틀린 예 /mdo temp : m 다음에 'o' 가 와야 하는데 'd' → bad → 다음 clk error = 1, 깃발 · data_reg 지우고 IDLE."
                     " 남은 'o temp' 는 IDLE 에서 '/' 가 아니라 무시 (error 안 냄) → ERROR 응답은 1 번만 (앞 장 오류 흐름과 같은 예).")
prs.save(OUT)
print("저장", OUT)
