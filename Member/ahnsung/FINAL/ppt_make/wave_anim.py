# final_ppt_v2.pptx 파형 장 5 개 : 선 굵기 줄이기 + 번호 순서대로 클릭 애니메이션 (나타내기 · 페이드)
# 사용 : python wave_anim.py final_ppt_v2.pptx [out.pptx]          (다시 돌려도 됨 : 애니메이션은 통째로 새로)
#   - 빨간 테두리 · 타원 · 점선 2 pt → 0.75 pt, 꼬리표 테두리 1 pt → 0.75 pt, P3 간격 화살표 1.75 pt → 1 pt
#   - 클릭 1 번 = 번호 하나 : 그 번호 이름표 + 같이 붙은 점선 · 꼬리표 · 흰 글씨 · 빨간 표시 · 아래 FND 그림
#   - 파형 · 머리말 · 결론 · 신호 이름 테두리 · 처음 상태 글씨는 처음부터 보임
import copy
import sys
from lxml import etree
from pptx import Presentation
from pptx.util import Pt

SRC = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else SRC
P = "http://schemas.openxmlformats.org/presentationml/2006/main"
FADE = 300          # ms
STAGGER = 350       # P3 줄마다 간격 ms

THIN = {"신호 이름": 0.75, "빨간 상자": 0.75, "빨간 타원": 0.75, "점선": 0.75, "꼬리표": 0.75, "간격 화살표": 1.0}


def fnd(name, desc):
    """FND 그림 (상자 이름) + 그 안 세그먼트 + 설명 2 줄"""
    return ("FND", name, desc)


# 클릭 순서 : [ [id 또는 fnd(...) …], … ]  (P3 3 번은 ('seq', 첫 묶음, [줄1, 줄2 …]) : 클릭 한 번에 줄이 차례로)
CFG = {
    "wave:P1-A": [[48, 22, 21, 51, 44],
                  [46, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 29],
                  [47, 24, 23, 30, 45],
                  [49, 26, 25, 28, 27, 31, 32, 52, 53]],
    "wave:P3-A": [[127],
                  [128] + list(range(181, 195)),
                  ("seq", [129, 131, 132, 133],
                   [[134, 135, 136, 162, 161], [137, 138, 139, 164, 163], [140, 141, 142, 166, 165],
                    [143, 144, 145, 146, 168, 167], [147, 148, 149, 150, 170, 169], [151, 152, 153, 154, 172, 171],
                    [155, 156, 157, 174, 173], [158, 159, 160, 176, 175]]),
                  [130],
                  [87, 177, 178, 179, 180]],
    "wave:P5-A": [[39, 28, 25, 26, 27, 43, 47, fnd("FND 1", [82, 83])],
                  [40, 32, 29, 30, 31, 37, 44, 48, fnd("FND 2", [113, 114])],
                  [41, 36, 33, 34, 35, 38, 45, 49, fnd("FND 3", [144, 145])],
                  [42, 50, 51]],
    # P5-1 : 'P51-n' = p5_1_io.py 가 넣은 단계 n 도형
    "wave:P5-1": [["P51-1"], ["P51-2"], ["P51-3", 27, 21], ["P51-4"], ["P51-5", 28, 20, 29]],
    # P6 : 시간 순서 (측정 전 → Err1 → /get Err 1 → Err2 → /get Err 2 → Err3 → /get Err 3), 'P6-n' = p6_err3.py 가 넣은 Err3 도형
    "wave:P6-A": [[37, 44, fnd("FND 1", [78, 79])],
                  [35, 29, 25, 26, 27, 28, 39, 42, fnd("FND 2", [109, 110])],
                  [38, 45],
                  [36, 34, 30, 31, 32, 33, 40, 43, fnd("FND 3", [140, 141])],
                  [46],
                  ["P6-6", fnd("FND 4", [171, 172])],
                  ["P6-7"]],
}
RETEXT = {"wave:P6-A": {37: "1. 측정 전 /get → --%--C", 35: "2. 부팅 1 s → 시작 LOW 18 ms → 응답 없음 → Err1",
                        38: "3. 오류마다 /get → PC 로 Err 1 · Err 2 · Err 3", 36: "4. + 2 s → 20 비트 뒤 끊김 → Err2"}}


def E(tag, **attr):
    el = etree.SubElement(attr.pop("_parent"), "{%s}%s" % (P, tag)) if "_parent" in attr else etree.Element("{%s}%s" % (P, tag))
    for k, v in attr.items():
        el.set(k, str(v))
    return el


class Ids:
    def __init__(self):
        self.n = 2

    def __call__(self):
        self.n += 1
        return str(self.n)


def effect(parent, spid, node, delay, nid):
    """나타내기 · 페이드 하나"""
    par = E("par", _parent=parent)
    ctn = E("cTn", _parent=par, id=nid(), presetID=10, presetClass="entr", presetSubtype=0, fill="hold",
            grpId=0, nodeType=node)
    E("cond", _parent=E("stCondLst", _parent=ctn), delay=delay)
    kids = E("childTnLst", _parent=ctn)
    st = E("set", _parent=kids)
    cb = E("cBhvr", _parent=st)
    c2 = E("cTn", _parent=cb, id=nid(), dur=1, fill="hold")
    E("cond", _parent=E("stCondLst", _parent=c2), delay=0)
    E("spTgt", _parent=E("tgtEl", _parent=cb), spid=spid)
    an = etree.SubElement(E("attrNameLst", _parent=cb), "{%s}attrName" % P)
    an.text = "style.visibility"
    E("strVal", _parent=E("to", _parent=st), val="visible")
    ae = E("animEffect", _parent=kids, transition="in", filter="fade")
    cb = E("cBhvr", _parent=ae)
    E("cTn", _parent=cb, id=nid(), dur=FADE)
    E("spTgt", _parent=E("tgtEl", _parent=cb), spid=spid)


def expand(s, items):
    """id · fnd(...) → 실제 spid 목록"""
    out = []
    shapes = list(s.shapes)
    for it in items:
        if isinstance(it, tuple) and it[0] == "FND":
            box = next(x for x in shapes if x.name == it[1])
            out.append(box.shape_id)
            for x in shapes:
                if x.name == "세그먼트" and box.left <= x.left <= box.left + box.width and box.top <= x.top <= box.top + box.height:
                    out.append(x.shape_id)
            out += it[2]
        elif isinstance(it, str):
            out += [x.shape_id for x in shapes if x.name.startswith(it + " ")]
        else:
            out.append(it)
    return out


def build_timing(s, steps):
    ids = {x.shape_id for x in s.shapes}
    nid = Ids()
    timing = E("timing")
    root = E("cTn", _parent=E("par", _parent=E("tnLst", _parent=timing)), id=1, dur="indefinite", restart="never",
             nodeType="tmRoot")
    seq = E("seq", _parent=E("childTnLst", _parent=root), concurrent=1, nextAc="seek")
    main = E("cTn", _parent=seq, id=2, dur="indefinite", nodeType="mainSeq")
    clicks = E("childTnLst", _parent=main)
    used = []
    for step in steps:
        if isinstance(step, tuple) and step[0] == "seq":
            groups = [expand(s, step[1])] + [expand(s, g) for g in step[2]]
            delays = [0] + [STAGGER * (k + 1) for k in range(len(step[2]))]
        else:
            groups, delays = [expand(s, step)], [0]
        cpar = E("par", _parent=clicks)
        cctn = E("cTn", _parent=cpar, id=nid(), fill="hold")
        E("cond", _parent=E("stCondLst", _parent=cctn), delay="indefinite")
        inner = E("par", _parent=E("childTnLst", _parent=cctn))
        ictn = E("cTn", _parent=inner, id=nid(), fill="hold")
        E("cond", _parent=E("stCondLst", _parent=ictn), delay=0)
        ikids = E("childTnLst", _parent=ictn)
        first = True
        for g, d in zip(groups, delays):
            for spid in g:
                assert spid in ids, (spid, "없는 도형")
                effect(ikids, spid, "clickEffect" if first else "withEffect", d, nid)
                first = False
                used.append(spid)
    pc = E("prevCondLst", _parent=seq)
    c = E("cond", _parent=pc, evt="onPrev", delay=0)
    E("sldTgt", _parent=E("tgtEl", _parent=c))
    nc = E("nextCondLst", _parent=seq)
    c = E("cond", _parent=nc, evt="onNext", delay=0)
    E("sldTgt", _parent=E("tgtEl", _parent=c))
    bld = E("bldLst", _parent=timing)
    sp_ids = {int(x.shape_id) for x in s.shapes if x._element.tag == "{%s}sp" % P}
    for spid in dict.fromkeys(used):
        if spid in sp_ids:
            E("bldP", _parent=bld, spid=spid, grpId=0, animBg=1)
    return timing


prs = Presentation(SRC)
done = []
for s in prs.slides:
    wave = next((x.name for x in s.shapes if x.name in CFG), None)
    if not wave:
        continue
    # 이름표 번호 다시 매김 (첫 글자 묶음만 바꿈 → 글꼴 · 색 그대로)
    for x in s.shapes:
        new = RETEXT.get(wave, {}).get(x.shape_id)
        if new:
            runs = [r for pp in x.text_frame.paragraphs for r in pp.runs]
            runs[0].text = new
            for r in runs[1:]:
                r.text = ""
    # 선 굵기
    for x in s.shapes:
        if x.name in THIN:
            x.line.width = Pt(THIN[x.name])
    # 애니메이션 (있던 것 지우고 새로) : clrMapOvr · transition 뒤, extLst 앞
    sld = s._element
    for old in sld.findall("{%s}timing" % P):
        sld.remove(old)
    t = build_timing(s, CFG[wave])
    ext = sld.find("{%s}extLst" % P)
    if ext is not None:
        ext.addprevious(t)
    else:
        sld.append(t)
    done.append((wave, len(CFG[wave])))

prs.save(OUT)
print("저장", OUT, done)
