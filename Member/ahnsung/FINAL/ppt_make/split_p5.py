# final_ppt.pptx 21 장 (P5 SR04 Err1 · Err2 · Err3 전체 파형 1 장) → Err 마다 확대 파형 1 장씩 3 장 (21 · 22 · 23)
# 사용 : python split_p5.py final_ppt.pptx err1.png err2.png err3.png [out.pptx]
#   - 머리말 · 제목 · 결론 틀은 21 장 것을 그대로 복제, 파형 · 꼬리표만 새로
#   - 뒤 장 쪽 번호 (오른쪽 아래 숫자) +2
import copy
import re
import sys
from PIL import Image, ImageFont
from pptx import Presentation
from pptx.util import Emu, Inches

SRC, IMGS, OUT = sys.argv[1], sys.argv[2:5], (sys.argv[5] if len(sys.argv) > 5 else sys.argv[1])
IN = 914400
FONT = ImageFont.truetype("/mnt/c/Windows/Fonts/malgunbd.ttf", 100)


def text_w(t, pt):
    return int(FONT.getlength(t) / 100 * pt / 72 * IN)


prs = Presentation(SRC)
sld_ids = prs.slides._sldIdLst
src = prs.slides[20]
by = {sh.shape_id: sh for sh in src.shapes}
assert by[5].name == "wave:P5-A", "21 장이 P5-A 가 아님"
T_LABEL = copy.deepcopy(by[39]._element)       # 노란 이름표
T_DASH = copy.deepcopy(by[25]._element)        # 빨간 점선 (세로)
T_NAME = copy.deepcopy(by[18]._element)        # 신호 이름 빨간 테두리
T_RBOX = copy.deepcopy(by[37]._element)        # 파형 위 빨간 상자
s48 = {sh.shape_id: sh for sh in prs.slides[47].shapes}
T_LINE = copy.deepcopy(s48[28]._element)       # 빨간 실선 (괄호)
CONCL_BOX = (s48[6].top, s48[6].height)        # 결론 2 줄 상자
CONCL_CHIP = s48[7].top
RPR_N = copy.deepcopy(by[8].text_frame.paragraphs[0].runs[0]._r.rPr)   # 결론 보통
RPR_E = copy.deepcopy(by[8].text_frame.paragraphs[0].runs[1]._r.rPr)   # 결론 강조 (청록 굵게)
KEEP = list(range(2, 11))                      # 머리말 · 제목 · 결론 상자 · 칩 · 결론 1~3 · (11 = 쪽 번호)
TPL = [copy.deepcopy(by[i]._element) for i in KEEP + [11]]

# ---------------------------------------------------------------- 장 내용
# 신호 행 y (원본 px) : 이미지마다 조금씩 다름
ROWS = [
    dict(trig=360, echo=384, w_state=407, w_dist_status=455, FND=575, LD9=599, W_LINE=766, name_x=62,
         names=[("trig", 360), ("echo", 384), ("w_state[2:0]", 407), ("w_dist_status[1:0]", 455),
                ("FND_DATA[63:0]", 575), ("LD9", 599), ("W_LINE[127:0]", 766)]),
    dict(name_x=58, names=[("trig", 350), ("echo", 373), ("w_state[2:0]", 396), ("w_dist_status[1:0]", 443),
                           ("w_distance[8:0]", 490), ("FND_DATA[63:0]", 560), ("W_LINE[127:0]", 747)]),
    dict(name_x=62, names=[("trig", 350), ("echo", 373), ("w_state[2:0]", 396), ("w_dist_status[1:0]", 442),
                           ("FND_DATA[63:0]", 557), ("W_LINE[127:0]", 741)]),
]
SLIDES = [
    dict(page="21", wave="wave:P5-1",
         title="P5-1  SR04 Err1 무응답 — echo 가 안 오면 trig↓ + 30 ms 에 Err1",
         concl=["/btn R 로 측정 시작 → trig ({18.1 ms}) → echo 없이 {30 ms} 기다림 → {48.2 ms} 에 w_dist_status {1} · w_dist_err 1",
                "같은 순간 FND 000.0 → {Err1} · LD9 켜짐 → 이어진 /get 응답 W_LINE = {Err 1} (68.4 ms)"],
         labels=[("1. /btn R → trig (18.1 ms)", 750, 312, "l"),
                 ("2. echo 안 옴 — w_state 2 로 30 ms 기다림", 988, 340, "c"),
                 ("3. 48.2 ms : status 1 · FND Err1 · LD9", 1245, 527, "l"),
                 ("4. /get → PC 에 'Err 1' (68.4 ms)", 1575, 623, "l")],
         dashes=[(1236, 352, 610)],
         brackets=[(741, 1236, 372)],
         rboxes=[(1572, 1994, 766)],
         caption="Figure.  0 ~ 99 ms — W_STEP 'Err1 no echo' : TB 센서 모델이 echo 를 주지 않음 · 커서 1.99 / 68.44 ms",
         notes="P5-1 Err1 무응답. /btn R 로 거리 측정 시작 → trig 18.1 ms → echo 가 안 와서 w_state 2 (echo 기다림) 로 30 ms → 48.2 ms 에 "
               "w_dist_status 1 · w_dist_err 1 · FND Err1 · LD9 켜짐. /get 을 보내면 PC 줄 W_LINE = Err 1 (68.4 ms)."),
    dict(page="22", wave="wave:P5-2",
         title="P5-2  SR04 Err2 범위 밖 — echo 가 23.2 ms (400 cm) 를 넘으면 Err2",
         concl=["/btn R → trig ({88.1 ms}) → echo 가 88.71 ~ 111.96 ms = {23.25 ms} 동안 1 (TB 가 일부러 길게)",
                "400 cm 한계 {23.2 ms} 를 넘어 status {2} · distance {400} · FND {Err2} → 이어진 /get 응답 W_LINE = {Err 2}"],
         labels=[("1. /btn R → trig (88.1 ms)", 690, 303, "r"),
                 ("2. echo 23.25 ms — 400 cm 한계 23.2 ms 넘음", 891, 327, "c"),
                 ("3. 112.0 ms : status 2 · distance 400 · FND Err2", 1088, 513, "l"),
                 ("4. /get → PC 에 'Err 2' (131.2 ms)", 1400, 607, "l"),
                 ("다음 장 Err3 : TB 가 echo 를 1 로 고정", 1990, 327, "r")],
         dashes=[(1078, 340, 595)],
         brackets=[],
         rboxes=[(704, 1078, 373), (1396, 1994, 747)],
         caption="Figure.  76 ~ 169 ms — W_STEP 'Err2 long echo' : echo 폭 23,250 us · 커서 88.71 / 111.96 ms (차 23.25 ms)",
         notes="P5-2 Err2 범위 밖. trig 88.1 ms → TB 가 echo 를 23.25 ms (88.71 ~ 111.96 ms) 동안 1 로 줌 → 400 cm 에 해당하는 23.2 ms 를 넘어 "
               "status 2 · distance 400 · FND Err2. /get 응답 W_LINE = Err 2 (131.2 ms). 오른쪽 끝 echo 가 trig 전에 올라가는 것은 다음 장 Err3 준비."),
    dict(page="23", wave="wave:P5-3",
         title="P5-3  SR04 Err3 echo 고착 — echo 가 계속 1 이면 trig↓ + 73.2 ms 에 Err3 · 강제 IDLE",
         concl=["echo 를 1 로 고정한 채 /btn R → trig ({160.21 ms}) → {23.2 ms} 뒤 (183.4 ms) 먼저 Err2 판정 (status 2 그대로)",
                "echo 가 안 내려가 trig↓ + {73.2 ms} (233.41 ms) 에 status {3} · w_state 강제 {0} · FND {Err3} → /get 응답 {Err 3}"],
         labels=[("1. echo 가 trig 전부터 1 (TB 가 고정)", 300, 327, "l"),
                 ("2. /btn R → trig (160.21 ms)", 395, 304, "l"),
                 ("3. 183.4 ms : 23.2 ms 지나 Err2 (status 2)", 780, 327, "l"),
                 ("4. 233.41 ms (trig↓ + 73.2 ms) : status 3 · 강제 IDLE · FND Err3", 1585, 510, "r"),
                 ("5. /get → PC 에 'Err 3'", 1700, 603, "l"),
                 ("6. TB 가 echo 풂 (255 ms)", 1945, 350, "r")],
         dashes=[(769, 340, 430), (1592, 340, 595)],
         brackets=[],
         rboxes=[(1594, 1994, 442)],
         caption="Figure.  150 ~ 258 ms — W_STEP '/btn R (stuck)' : TB 가 trig 전 (152 ms) 부터 echo = 1 고정 → 255 ms 에 풂 · 커서 160.21 / 233.41 ms (차 73.2 ms)",
         notes="P5-3 Err3 echo 고착. TB 가 152 ms 부터 echo 를 1 로 고정 → /btn R trig 160.21 ms → 23.2 ms 뒤 183.4 ms 에 먼저 Err2 (status 2 유지) → "
               "echo 가 계속 안 내려가 trig↓ + 73.2 ms = 233.41 ms 에 status 3 · w_state 강제 0 (IDLE) · FND Err3. /get 응답 Err 3. 255 ms 에 TB 가 echo 풂."),
]


# ---------------------------------------------------------------- 도구
def next_id(s):
    return max([int(e.get("id")) for e in s._element.iter() if e.tag.endswith("}cNvPr")] + [1]) + 1


def put(s, tpl, x, y, w, h, text=None, name=None):
    el = copy.deepcopy(tpl)
    c = next(e for e in el.iter() if e.tag.endswith("}cNvPr"))
    c.set("id", str(next_id(s)))
    if name:
        c.set("name", name)
    s.shapes._spTree.append(el)
    sh = s.shapes[-1]
    sh.left, sh.top, sh.width, sh.height = Emu(int(x)), Emu(int(y)), Emu(int(w)), Emu(int(h))
    if text is not None:
        sh.text_frame.paragraphs[0].runs[0].text = text
    return sh


def set_runs(shape, line):
    p = shape.text_frame.paragraphs[0]
    for r in list(p.runs):
        p._p.remove(r._r)
    for k, part in enumerate(re.split(r"[{}]", line)):
        if not part:
            continue
        r = p.add_run()
        r.text = part
        r._r.insert(0, copy.deepcopy(RPR_E if k % 2 else RPR_N))


def build(s, d, img, rows):
    sh = {x.shape_id: x for x in s.shapes}
    sh[5].name = d["wave"]
    sh[5].text_frame.paragraphs[0].runs[0].text = d["title"]
    for r in sh[5].text_frame.paragraphs[0].runs[1:]:
        r.text = ""
    sh[6].top, sh[6].height = CONCL_BOX
    sh[7].top = CONCL_CHIP
    set_runs(sh[8], d["concl"][0])
    set_runs(sh[9], d["concl"][1])
    sh[10]._element.getparent().remove(sh[10]._element)
    pg = next(x for x in s.shapes if x.has_text_frame and x.left > 8 * IN and x.top > 5.2 * IN)
    pg.text_frame.paragraphs[0].runs[0].text = d["page"]

    iw, ih = Image.open(img).size
    L, T, W = int(0.46 * IN), int(1.5 * IN), int(8.75 * IN)
    H = int(W * ih / iw)
    pic = s.shapes.add_picture(img, Emu(L), Emu(T), Emu(W), Emu(H))
    pic.name = "파형"
    X = lambda px: L + px * W / iw
    Y = lambda py: T + py * H / ih
    # 신호 이름 테두리
    for nm, ry in rows["names"]:
        x0 = rows["name_x"] - 16
        put(s, T_NAME, X(x0), Y(ry - 9), X(rows["name_x"] + sum(7.6 if ch.isupper() else 5.4 for ch in nm) + 8) - X(x0), Y(18) - Y(0), name="신호 이름")
    # 파형 위 빨간 상자
    for x1, x2, ry in d["rboxes"]:
        put(s, T_RBOX, X(x1), Y(ry - 10), X(x2) - X(x1), Y(20) - Y(0), name="빨간 상자")
    # 세로 점선
    for x, y1, y2 in d["dashes"]:
        put(s, T_DASH, X(x), Y(y1), 0, Y(y2) - Y(y1), name="점선")
    # 괄호 (가로 실선 + 양끝 눈금)
    for x1, x2, ry in d["brackets"]:
        put(s, T_LINE, X(x1), Y(ry), X(x2) - X(x1), 0, name="선")
        for x in (x1, x2):
            put(s, T_LINE, X(x), Y(ry - 6), 0, Y(12) - Y(0), name="선")
    # 노란 이름표
    lh = 96180
    for t, px, py, al in d["labels"]:
        w = text_w(t, 6.25) + 60000
        x = X(px) - (w / 2 if al == "c" else w if al == "r" else 0)
        put(s, T_LABEL, x, Y(py) - lh / 2, w, lh, t, name="이름표")
        assert L <= x and x + w <= L + W, ("이름표가 파형 밖", t)
    # Figure 캡션 (21 장 각주 꼴)
    cap = put(s, by[147]._element, L, T + H + 30000, W, 100000, name="Figure")
    tf = cap.text_frame
    for p_ in tf.paragraphs[1:]:
        p_._p.getparent().remove(p_._p)
    tf.paragraphs[0].runs[0].text = d["caption"]
    for r in tf.paragraphs[0].runs[1:]:
        r.text = ""
    print("%s : 파형 아래 %.2f in · 캡션 아래 %.2f in" % (d["page"], (T + H) / IN, (T + H + 130000) / IN))
    # 노트
    s.notes_slide.notes_text_frame.text = d["notes"]


# ---------------------------------------------------------------- 21 장 비우기 + 22 · 23 장 만들기
# 쪽 번호 먼저 +2 (22 장 이후)
for s in list(prs.slides)[21:]:
    for x in s.shapes:
        if x.has_text_frame and x.left > 8 * IN and x.top > 5.2 * IN and re.fullmatch(r"\d+", x.text_frame.text.strip()):
            r = x.text_frame.paragraphs[0].runs[0]
            r.text = str(int(r.text) + 2).zfill(len(r.text))

# 21 장 : KEEP + 쪽 번호 빼고 다 지움 (그림 rel 도)
rids = []
for x in list(src.shapes):
    if x.shape_id not in KEEP + [11]:
        if x.shape_type == 13:
            rids.append(x._element.blipFill.blip.rEmbed)
        x._element.getparent().remove(x._element)
for rid in set(rids):
    src.part.drop_rel(rid)
slides = [src]
for k in (1, 2):
    ns = prs.slides.add_slide(src.slide_layout)
    for ph in list(ns.placeholders):
        ph._element.getparent().remove(ph._element)
    for el in TPL:
        ns.shapes._spTree.append(copy.deepcopy(el))
    # 맨 끝에 붙은 sldId 를 21 장 뒤로
    el = sld_ids[-1]
    sld_ids.remove(el)
    sld_ids.insert(20 + k, el)
    slides.append(ns)

for s, d, img, rows in zip(slides, SLIDES, IMGS, ROWS):
    build(s, d, img, rows)
prs.save(OUT)
print("저장", OUT, "· 장 수", len(prs.slides))
