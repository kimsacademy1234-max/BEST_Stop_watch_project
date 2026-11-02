# final_ppt_v2.pptx P6 (DHT11) : 새 파형 wave_img/P6_Err123.png (0 ~ 6 s, Err1 · Err2 · Err3 · /get Err3) 로 바꾸고 표시 다시 배치
# 사용 : python p6_err3.py final_ppt_v2.pptx [out.pptx]   → 이어서 signal_names.py · wave_anim.py
#   - 파형 그림 8 장 (이름 칸 4 + 파형 4 띠) 을 새 그림으로 다시 자름 : 띠 = TB · DHT11 · FND/TX · tx/W_LINE
#   - 기존 이름표 · 꼬리표 · 점선 · 흰 글씨 · 신호 이름 테두리는 새 좌표로 옮기고, Err3 용은 복사해서 'P6-<n> …' 이름으로 추가
#   - 다시 돌려도 됨 (P6-* 지우고 새로, 그림도 새로)
import copy
import sys
from PIL import ImageFont
from pptx import Presentation
from pptx.util import Emu

SRC = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else SRC
IMG = "wave_img/P6_Err123.png"           # 2000 × 939
IW, IH = 2000, 939
IN = 914400
FONT = ImageFont.truetype("/mnt/c/Windows/Fonts/malgunbd.ttf", 100)

NAME_X1, WAVE_X0 = 228, 340                     # 이름 칸 끝 · 파형 시작 (px)
LEFT, RIGHT, TOP, GAP = 0.57, 9.43, 1.68, 0.02  # in
K = (RIGHT - LEFT - 0.03) / (NAME_X1 + IW - WAVE_X0)    # in / px
WAVE_L = LEFT + NAME_X1 * K + 0.03
BANDS = [(20, 160), (372, 609), (662, 820), (873, 939)]  # TB · DHT11 · FND + TX · tx / W_LINE
BT = []
t = TOP
for y0, y1 in BANDS:
    BT.append(t)
    t += (y1 - y0) * K + GAP

E = lambda v: Emu(int(v * IN))
X = lambda px: WAVE_L + (px - WAVE_X0) * K          # 파형 px → in
NX = lambda px: LEFT + px * K                        # 이름 칸 px → in


def Y(py):
    for (y0, y1), bt in zip(BANDS, BT):
        if y0 <= py <= y1:
            return bt + (py - y0) * K
    raise ValueError(py)


prs = Presentation(SRC)
s = next(sl for sl in prs.slides if any(x.name == "wave:P6-A" for x in sl.shapes))
tree = s.shapes._spTree

# ---------------------------------------------------------------- 그림 다시
for x in list(s.shapes):
    if x.name.startswith("P6-"):
        tree.remove(x._element)
pics = [x for x in s.shapes if x.shape_type == 13]
at = list(tree).index(pics[0]._element)
for p in pics:
    tree.remove(p._element)
new = []
for (y0, y1), bt in zip(BANDS, BT):
    for x0, x1, l in ((0, NAME_X1, LEFT), (WAVE_X0, IW, WAVE_L)):
        p = s.shapes.add_picture(IMG, E(l), E(bt), E((x1 - x0) * K), E((y1 - y0) * K))
        p.crop_left, p.crop_right = x0 / IW, 1 - x1 / IW
        p.crop_top, p.crop_bottom = y0 / IH, 1 - y1 / IH
        p.name = "파형"
        new.append(p._element)
for el in new:                                  # 원래 자리 (표시들 아래)
    tree.remove(el)
for i, el in enumerate(new):
    tree.insert(at + i, el)

sh = {x.shape_id: x for x in s.shapes}
nid = [max(sh) + 1]


def dup(src, name):
    el = copy.deepcopy(sh[src]._element)
    el[0][0].set("id", str(nid[0]))
    el[0][0].set("name", name)
    nid[0] += 1
    tree.append(el)
    return next(x for x in s.shapes if x._element is el)


def put(x, text=None, cx=None, left=None, cy=None):
    """글자 바꾸고 폭 = 글자 길이, 가운데 (cx) 또는 왼쪽 (left) 맞춤"""
    runs = [r for p in x.text_frame.paragraphs for r in p.runs]
    if text is not None:
        runs[0].text = text
        for r in runs[1:]:
            r.text = ""
    pt = runs[0].font.size.pt
    w = FONT.getlength(x.text_frame.text) / 100 * pt / 72 * 1.1 + 0.06
    x.width = E(w)
    x.left = E(cx - w / 2 if cx is not None else left)
    x.top = E(cy - x.height / IN / 2)


def vdash(x, px, y1, y2):
    x.left, x.width = E(X(px)), Emu(0)
    x.top, x.height = E(y1), E(y2 - y1)


T1, T3, T5 = 606, 1146, 1686                    # 1.0 · 3.0 · 5.0 s (270 px / s)

# 꼬리표 (위 눈금) + 점선 4 띠
TAG_CY = Y(24)
tags = {1: (29, T1, "1.000 s 측정 → Err1"), 2: (34, T3, "3.000 s 측정 → Err2")}
t5 = dup(34, "P6-6 꼬리표")
put(sh[29], tags[1][2], cx=X(T1), cy=TAG_CY)
put(sh[34], tags[2][2], cx=X(T3), cy=TAG_CY)
put(t5, "5.000 s 측정 → Err3", cx=X(T5), cy=TAG_CY)
band_y = [(TAG_CY + 0.06, BT[0] + (BANDS[0][1] - BANDS[0][0]) * K)] + \
         [(bt, bt + (y1 - y0) * K) for (y0, y1), bt in zip(BANDS[1:], BT[1:])]
for ids, px in (((25, 26, 27, 28), T1), ((30, 31, 32, 33), T3)):
    for i, (a, b) in zip(ids, band_y):
        vdash(sh[i], px, a, b)
for a, b in band_y:
    vdash(dup(30, "P6-6 점선"), T5, a, b)

# 번호 이름표 (빈 묶음 머리 줄 : TB = 67, DHT11 = 385)
put(sh[37], "1. 측정 전 /get → --%--C", left=X(348), cy=Y(67))
put(sh[38], "3. 오류마다 /get → PC 로 Err 1 · Err 2 · Err 3", left=X(628), cy=Y(67))
put(sh[35], "2. 부팅 1 s → 시작 LOW 18 ms → 응답 없음 → Err1", left=X(614), cy=Y(385))
put(sh[36], "4. + 2 s → 20 비트 뒤 끊김 → Err2", left=X(1154), cy=Y(385))
l5 = dup(36, "P6-6 이름표")
put(l5, "5. + 2 s → 체크섬 틀림 → Err3", left=X(1694), cy=Y(385))
assert l5.left + l5.width <= E(RIGHT), "이름표 5 가 파형 밖"

# 흰 글씨 : status (w_dht_err 줄 569) · FND (FND 머리 줄 675) · PC (tx 줄 886)
put(sh[39], "status 1 : 응답 없음", cx=X(878), cy=Y(569))
put(sh[40], "status 2 : 중간 끊김", cx=X(1418), cy=Y(569))
put(dup(40, "P6-6 흰 글씨"), "status 3 : 체크섬 틀림", cx=X(1846), cy=Y(569))
put(sh[41], "FND ----", cx=X(475), cy=Y(675))
put(sh[42], "FND Err1", cx=X(878), cy=Y(675))
put(sh[43], "FND Err2", cx=X(1418), cy=Y(675))
put(dup(43, "P6-6 흰 글씨"), "FND Err3", cx=X(1846), cy=Y(675))
put(sh[44], "PC ← --%--C", cx=X(479), cy=Y(886))
put(sh[45], "PC ← Err 1", cx=X(885), cy=Y(886))
put(sh[46], "PC ← Err 2", cx=X(1425), cy=Y(886))
put(dup(46, "P6-7 흰 글씨"), "PC ← Err 3", cx=X(1848), cy=Y(886))

# 신호 이름 테두리 : dht11_io 411 · w_dht_oe 437 · w_dht_status 543 · FND_DATA 701 · W_LINE 912
for i, py in zip((20, 21, 22, 23, 24), (411, 437, 543, 701, 912)):
    b = sh[i]
    b.left = E(NX(46))
    b.top = E(Y(py) - b.height / IN / 2)
sh[47].top = E(Y(411) - sh[47].height / IN / 2)      # '*' (x 는 signal_names 가)

prs.save(OUT)
print("저장", OUT, "K=%.5f in/px, 파형 끝 %.2f in" % (K, BT[-1] + (BANDS[-1][1] - BANDS[-1][0]) * K))
