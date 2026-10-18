#!/usr/bin/env python3
"""발표 자료 생성기 — reference_presentation.pptx 디자인 베이스 + stopwatch_presentation.pptx 팀원 슬라이드 재구성.

- 디자인 베이스 : reference_presentation.pptx 의 마스터 · 레이아웃(Blank) · 테마 · 20 x 11.25 in 판형
  (임베디드 Noto 폰트는 일부 글자만 들어 있는 subset 이라 빼고, 전부 맑은 고딕 / 맑은 고딕 Semilight)
- 팀원 슬라이드(스톱워치 · 타이머 · 트러블 슈팅 · 결론 · 부록) : 파형 이미지 + 주석 도형을 그대로 옮겨
  1.36 ~ 1.5 배로 키우고, 머리글(제목 · 결과 한 줄 · 페이지)만 공통 양식으로 다시 씀
- 발표자 노트 : 원본에서 슬라이드가 어긋나 붙어 있던 노트를 끝 번호(원본 쪽 번호)로 제자리에 다시 붙임
- 작성 규칙 : PPT_GUIDE.md (개조식 · 두괄식 결과 한 줄 · 번호 매칭 · 수치 · 4 단계 트러블 슈팅)

실행: python3 build_deck.py   → BEST_stopwatch_presentation.pptx
"""
import copy
import os
import re
import zipfile

from lxml import etree

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, "reference_presentation.pptx")
SRC = os.path.join(HERE, "stopwatch_presentation.pptx")
OUT = os.path.join(HERE, "BEST_stopwatch_presentation.pptx")

EMU = 914400
W, H = 20.0, 11.25
P_NS = "http://schemas.openxmlformats.org/presentationml/2006/main"
A_NS = "http://schemas.openxmlformats.org/drawingml/2006/main"
R_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS = {"p": P_NS, "a": A_NS, "r": R_NS}
IMG_REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"

FONT, FONT_L, MONO = "Malgun Gothic", "Malgun Gothic Semilight", "Consolas"
TEXT, TEXT2, MUTED, LINE, BG2 = "262626", "595959", "8C8C8C", "D9D9D9", "F4F4F4"
DARK, ACCENT, WHITE = "404040", "C00000", "FFFFFF"
FN = {  # 기능 색 (진한 색, 옅은 바탕)
    "sw": ("2B6CB0", "E6EFFA"), "wt": ("2F855A", "E4F3EA"), "tm": ("C05621", "FCEDE1"),
    "cm": ("718096", "F0F2F5"), "dp": ("6B46C1", "F0EBFB"),
}
FN_NAME = {"sw": "스톱워치", "wt": "시계", "tm": "타이머"}
DATA_C, CTRL_C, TICK_C = "262626", "8C8C8C", "D53F8C"

SRCZ = zipfile.ZipFile(SRC)
MEDIA = {}  # 출력 media 이름 → bytes


def e(v):
    return int(round(v * EMU))


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


# ============================================================== 슬라이드 · 기본 도형
class Slide:
    def __init__(self, notes=None):
        self.sh, self.rels, self.notes = [], [], notes

    def add(self, xml):
        self.sh.append(xml)

    def image_rel(self, name, data):
        MEDIA[name] = data
        rid = f"rId{len(self.rels) + 2}"
        self.rels.append((rid, IMG_REL, f"../media/{name}"))
        return rid


def R(t, sz=16, c=TEXT, b=False, f=FONT, i=False):
    return dict(t=t, sz=sz, c=c, b=b, f=f, i=i)


def P(*runs, algn="l", bef=0, ln=100):
    return dict(runs=[r if isinstance(r, dict) else R(r) for r in runs], algn=algn, bef=bef, ln=ln)


def run_xml(r):
    f = r["f"]
    return (f'<a:r><a:rPr lang="ko-KR" altLang="en-US" sz="{int(r["sz"] * 100)}"{" b=\"1\"" if r["b"] else ""}'
            f'{" i=\"1\"" if r["i"] else ""} dirty="0"><a:solidFill><a:srgbClr val="{r["c"]}"/></a:solidFill>'
            f'<a:latin typeface="{f}"/><a:ea typeface="{f}"/><a:cs typeface="{f}"/></a:rPr>'
            f'<a:t>{esc(r["t"])}</a:t></a:r>')


def para_xml(p):
    sz = int(p["runs"][0]["sz"] * 100) if p["runs"] else 1200
    return (f'<a:p><a:pPr algn="{p["algn"]}"><a:lnSpc><a:spcPct val="{p["ln"] * 1000}"/></a:lnSpc>'
            f'<a:spcBef><a:spcPts val="{int(p["bef"] * 100)}"/></a:spcBef><a:buNone/></a:pPr>'
            + "".join(run_xml(r) for r in p["runs"]) + f'<a:endParaRPr lang="ko-KR" sz="{sz}" dirty="0"/></a:p>')


def fill_xml(fill):
    return f'<a:solidFill><a:srgbClr val="{fill}"/></a:solidFill>' if fill else "<a:noFill/>"


def ln_xml(line, lw=1.0, dash=None, head=False, tail=False):
    if not line:
        return "<a:ln><a:noFill/></a:ln>"
    return (f'<a:ln w="{int(lw * 12700)}"><a:solidFill><a:srgbClr val="{line}"/></a:solidFill>'
            f'<a:prstDash val="{dash or "solid"}"/>{"<a:headEnd type=\"triangle\"/>" if head else ""}'
            f'{"<a:tailEnd type=\"triangle\"/>" if tail else ""}</a:ln>')


def geom_xml(geom, adj=None):
    av = f'<a:gd name="adj" fmla="val {adj}"/>' if adj is not None else ""
    return f'<a:prstGeom prst="{geom}"><a:avLst>{av}</a:avLst></a:prstGeom>'


def xfrm(x, y, w, h, flip=""):
    return f'<a:xfrm{flip}><a:off x="{e(x)}" y="{e(y)}"/><a:ext cx="{e(w)}" cy="{e(h)}"/></a:xfrm>'


def box(s, x, y, w, h, paras=None, fill=None, line=None, lw=1.0, geom="rect", adj=None, anchor="t",
        ins=(0, 0, 0, 0), dash=None, name="shape"):
    """도형 + (선택) 글자. paras: [P(...), ...]"""
    body = ""
    if paras is not None:
        l, t, r_, b = (e(v) for v in ins)
        body = (f'<p:txBody><a:bodyPr wrap="square" lIns="{l}" tIns="{t}" rIns="{r_}" bIns="{b}" anchor="{anchor}" '
                f'rtlCol="0"><a:noAutofit/></a:bodyPr><a:lstStyle/>' + "".join(para_xml(p) for p in paras) + "</p:txBody>")
    tx = ' txBox="1"' if (paras is not None and not fill and not line) else ""
    s.add(f'<p:sp><p:nvSpPr><p:cNvPr id="@@" name="{name}"/><p:cNvSpPr{tx}/><p:nvPr/></p:nvSpPr>'
          f'<p:spPr>{xfrm(x, y, w, h)}{geom_xml(geom, adj)}{fill_xml(fill)}{ln_xml(line, lw, dash)}</p:spPr>{body}</p:sp>')


def text(s, x, y, w, h, paras, anchor="t", **kw):
    if isinstance(paras, (str, dict)):
        paras = [paras]
    paras = [p if (isinstance(p, dict) and "runs" in p) else P(p) for p in paras]
    box(s, x, y, w, h, paras, anchor=anchor, name="text", **kw)


def line(s, x1, y1, x2, y2, c=CTRL_C, lw=1.25, dash=None, arrow=True, head=False):
    flip = (' flipH="1"' if x2 < x1 else "") + (' flipV="1"' if y2 < y1 else "")
    s.add(f'<p:cxnSp><p:nvCxnSpPr><p:cNvPr id="@@" name="line"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr>'
          f'<p:spPr>{xfrm(min(x1, x2), min(y1, y2), abs(x2 - x1), abs(y2 - y1), flip)}{geom_xml("line")}'
          f'{ln_xml(c, lw, dash, head=head, tail=arrow)}</p:spPr></p:cxnSp>')


def path(s, pts, **kw):
    arrow = kw.pop("arrow", True)
    for i in range(len(pts) - 1):
        line(s, *pts[i], *pts[i + 1], arrow=arrow and i == len(pts) - 2, **kw)


def table(s, x, y, colw, rows, rowh=0.5, fs=13, head_fill=DARK, zebra=None, border=LINE, name="table"):
    """rows[0] = 머리 줄. 셀 = str 또는 dict(t / runs, fill, c, b, algn, f)"""
    grid = "".join(f'<a:gridCol w="{e(cw)}"/>' for cw in colw)
    trs = ""
    for ri, row in enumerate(rows):
        rh = rowh[ri] if isinstance(rowh, (list, tuple)) else rowh
        tcs = ""
        for ci, cell in enumerate(row):
            c = cell if isinstance(cell, dict) else {"t": cell}
            head = ri == 0
            col = c.get("c", WHITE if head else TEXT)
            runs = c.get("runs") or [R(c.get("t", ""), c.get("sz", fs), col, c.get("b", head), c.get("f", FONT))]
            paras = c.get("paras") or [P(*runs, algn=c.get("algn", "ctr" if head else "l"))]
            fill = c.get("fill", head_fill if head else (zebra if (zebra and ri % 2 == 0) else None))
            bl = (f'<a:ln{{s}} w="{12700 if border else 0}">{fill_xml(border) if border else "<a:noFill/>"}</a:ln{{s}}>')
            tcs += (f'<a:tc><a:txBody><a:bodyPr/><a:lstStyle/>{"".join(para_xml(p) for p in paras)}</a:txBody>'
                    f'<a:tcPr marL="{e(0.12)}" marR="{e(0.1)}" marT="{e(0.05)}" marB="{e(0.05)}" anchor="ctr">'
                    + "".join(bl.format(s=k) for k in "LRTB") + f'{fill_xml(fill)}</a:tcPr></a:tc>')
        trs += f'<a:tr h="{e(rh)}">{tcs}</a:tr>'
    tot_h = sum(rowh) if isinstance(rowh, (list, tuple)) else rowh * len(rows)
    s.add(f'<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="@@" name="{name}"/><p:cNvGraphicFramePr>'
          f'<a:graphicFrameLocks noGrp="1"/></p:cNvGraphicFramePr><p:nvPr/></p:nvGraphicFramePr>'
          f'<p:xfrm><a:off x="{e(x)}" y="{e(y)}"/><a:ext cx="{e(sum(colw))}" cy="{e(tot_h)}"/></p:xfrm>'
          f'<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">'
          f'<a:tbl><a:tblPr firstRow="1" bandRow="0"/><a:tblGrid>{grid}</a:tblGrid>{trs}</a:tbl>'
          f'</a:graphicData></a:graphic></p:graphicFrame>')


def chip(s, x, y, w, h, t, fill, c=WHITE, sz=13, b=True, f=FONT, line_c=None):
    box(s, x, y, w, h, [P(R(t, sz, c, b, f), algn="ctr")], fill=fill, line=line_c, geom="roundRect", adj=50000,
        anchor="ctr", name="chip")


def circle_num(s, cx, cy, d, t, fill, c=WHITE, sz=12):
    box(s, cx - d / 2, cy - d / 2, d, d, [P(R(t, sz, c, True), algn="ctr")], fill=fill, geom="ellipse",
        anchor="ctr", name="badge")


# ============================================================== 공통 머리글
BRAND = "STOPWATCH · WATCH · TIMER"


def brand(s, c=MUTED):
    text(s, 13.6, 0.22, 6.0, 0.3, P(R(BRAND, 10.5, c, False), algn="r"))


def header(s, sec, title, msg=None, chip_t="결과", sub=None, fn=None, steps=None, title_sz=30):
    """sec: '04  시뮬레이션 · 스톱워치'. msg: 두괄식 한 줄. steps: 트러블 슈팅 단계 강조 (set)"""
    brand(s)
    col = FN[fn][0] if fn else DARK
    box(s, 0.92, 0.55, 0.14, 0.14, fill=col, geom="ellipse")
    text(s, 1.14, 0.44, 10.0, 0.34, R(sec, 12.5, col, True))
    tw = 11.6 if steps else 18.2
    text(s, 0.92, 0.78, tw, 0.72, R(title, title_sz, TEXT, False, FONT_L), anchor="ctr")
    if steps:
        names = ["현상", "원인", "해결", "적용 결과"]
        for i, nm in enumerate(names):
            x = 12.95 + i * 1.55
            on = (i + 1) in steps
            circle_num(s, x + 0.22, 1.05, 0.42, "①②③④"[i], ACCENT if on else "E7E7E7", WHITE if on else MUTED, 13)
            text(s, x + 0.48, 0.9, 1.05, 0.32, R(nm, 12, TEXT if on else MUTED, on), anchor="ctr")
    if msg is not None:
        pending = msg.startswith("[")
        chip(s, 0.92, 1.66, 0.95, 0.44, chip_t, MUTED if pending else ACCENT, sz=14)
        text(s, 2.02, 1.62, 17.1, 0.52, R(msg, 19, MUTED if pending else TEXT, not pending, i=pending), anchor="ctr")
    if sub:
        text(s, 2.02, 2.14, 17.1, 0.4, R(sub, 15, TEXT2), anchor="ctr")


def figure_note(s, t, y=10.15):
    text(s, 0.92, y, 16.5, 0.34, R(t, 11.5, MUTED), anchor="ctr")


# ============================================================== 팀원 슬라이드 옮기기
CMAP = {"14A89A": FN["sw"][0], "102748": TEXT, "202D3C": TEXT, "586678": TEXT2, "7A8B9E": MUTED,
        "1F3864": DARK, "374151": TEXT, "1F2937": TEXT, "6B7280": "7F7F7F"}
KEEP_FONTS = {"Consolas", "D2Coding", "Courier New"}


def _xfrm_of(el):
    tag = etree.QName(el).localname
    if tag in ("sp", "pic", "cxnSp"):
        return el.find("./p:spPr/a:xfrm", NS)
    if tag == "grpSp":
        return el.find("./p:grpSpPr/a:xfrm", NS)
    if tag == "graphicFrame":
        return el.find("./p:xfrm", NS)
    return None


def transplant(s, src_no, cut_top, region, drop_text=(), max_scale=1.5, cmap=None):
    """원본 slide{src_no} 의 내용 도형(머리글 · 꼬리말 제외)을 region(x, y, w, h)에 맞춰 옮김"""
    cmap = {**CMAP, **(cmap or {})}
    root = etree.fromstring(SRCZ.read(f"ppt/slides/slide{src_no}.xml"))
    rels = {}
    rx = SRCZ.read(f"ppt/slides/_rels/slide{src_no}.xml.rels").decode()
    for m in re.finditer(r"<Relationship ([^>]*)/>", rx):
        a = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
        rels[a["Id"]] = a["Target"]
    tree = root.find(".//p:cSld/p:spTree", NS)
    kept = []
    for el in tree:
        xf = _xfrm_of(el)
        if xf is None:
            continue
        o, ex = xf.find("a:off", NS), xf.find("a:ext", NS)
        x, y, w, h = (int(v) / EMU for v in (o.get("x"), o.get("y"), ex.get("cx"), ex.get("cy")))
        t = "".join(el.xpath(".//a:t/text()", namespaces=NS))
        if y < cut_top or y >= 6.9 or any(d in t for d in drop_text):
            continue
        kept.append((el, x, y, w, h))
    bx0 = min(k[1] for k in kept); by0 = min(k[2] for k in kept)
    bx1 = max(k[1] + k[3] for k in kept); by1 = max(k[2] + k[4] for k in kept)
    X, Y, RW, RH = region
    sc = min(RW / (bx1 - bx0), RH / (by1 - by0), max_scale)
    ox = X + (RW - (bx1 - bx0) * sc) / 2
    for el, x, y, w, h in kept:
        el = copy.deepcopy(el)
        xf = _xfrm_of(el)
        xf.find("a:off", NS).set("x", str(e(ox + (x - bx0) * sc)))
        xf.find("a:off", NS).set("y", str(e(Y + (y - by0) * sc)))
        xf.find("a:ext", NS).set("cx", str(e(w * sc)))
        xf.find("a:ext", NS).set("cy", str(e(h * sc)))
        for n in el.iter():
            if not isinstance(n.tag, str):
                continue
            ln = etree.QName(n).localname
            if ln in ("rPr", "defRPr", "endParaRPr"):
                for k in ("sz", "spc"):
                    if n.get(k):
                        n.set(k, str(int(round(int(n.get(k)) * sc))))
            elif ln in ("ln", "lnL", "lnR", "lnT", "lnB") and n.get("w"):
                n.set("w", str(int(int(n.get("w")) * sc)))
            elif ln == "bodyPr":
                for k in ("lIns", "tIns", "rIns", "bIns"):
                    if n.get(k):
                        n.set(k, str(int(int(n.get(k)) * sc)))
            elif ln == "tcPr":
                for k in ("marL", "marR", "marT", "marB"):
                    if n.get(k):
                        n.set(k, str(int(int(n.get(k)) * sc)))
            elif ln == "gridCol":
                n.set("w", str(int(int(n.get("w")) * sc)))
            elif ln == "tr":
                n.set("h", str(int(int(n.get("h")) * sc)))
            elif ln == "spcPts" and n.get("val"):
                n.set("val", str(int(int(n.get("val")) * sc)))
            elif ln in ("latin", "ea", "cs") and n.get("typeface") not in KEEP_FONTS:
                n.set("typeface", FONT)
            elif ln == "srgbClr" and n.get("val", "").upper() in cmap:
                n.set("val", cmap[n.get("val").upper()])
            elif ln == "cNvPr":
                n.set("id", "@@")
                for hl in n.findall("a:hlinkClick", NS):
                    n.remove(hl)
            for k in list(n.attrib):
                if k in (f"{{{R_NS}}}embed", f"{{{R_NS}}}link"):
                    tgt = rels[n.get(k)]
                    data = SRCZ.read("ppt/" + tgt.replace("../", ""))
                    n.set(k, s.image_rel(f"src{src_no}_{os.path.basename(tgt)}", data))
        s.add(etree.tostring(el, encoding="unicode"))
    return sc


def src_notes():
    """원본 노트 → 붙어 있는 원본 슬라이드 번호 (끝의 옛 쪽 번호 · '출처:' 메모는 뺌)"""
    out = {}
    for i in range(1, 39):
        try:
            x = SRCZ.read(f"ppt/notesSlides/notesSlide{i}.xml").decode()
        except KeyError:
            continue
        rels = SRCZ.read(f"ppt/notesSlides/_rels/notesSlide{i}.xml.rels").decode()
        m = re.search(r'slides/slide(\d+)\.xml', rels)
        host = int(m.group(1)) if m else None
        t = " ".join(re.findall(r"<a:t>([^<]*)</a:t>", x)).strip()
        t = re.sub(r"\s+", " ", t).replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&")
        if len(t) < 5:
            continue
        t = re.split(r"\s*출처\s*:", t)[0].strip()
        out[host] = re.sub(r"\s\d{1,2}\s*$", "", t).strip()
    return out


NOTES = src_notes()


FIG = [0]


def moved(src_no, sec, title, msg, fn=None, sub=None, cut_top=1.2, steps=None, drop=(), chip_t="결과",
          top=None, max_scale=1.5, title_sz=30, fig=None):
    s = Slide(notes=NOTES.get(src_no))
    header(s, sec, title, msg, chip_t=chip_t, sub=sub, fn=fn, steps=steps, title_sz=title_sz)
    y0 = top if top else (2.7 if sub else 2.4)
    bottom = 9.95 if fig else 10.35
    transplant(s, src_no, cut_top, (0.92, y0, 18.16, bottom - y0), drop_text=drop, max_scale=max_scale)
    if fig:
        FIG[0] += 1
        figure_note(s, f"Figure {FIG[0]}.  {fig}  — Vivado xsim 파형", y=10.15)
    return s


# ============================================================== 슬라이드들
def s_cover():
    s = Slide()
    brand(s)
    text(s, 0.92, 2.55, 10.5, 2.6, [P(R("STOPWATCH ·", 60, DARK, False, FONT_L)),
                                    P(R("WATCH · TIMER", 60, DARK, False, FONT_L))], anchor="t")
    text(s, 0.95, 5.25, 10.5, 0.55, R("Basys-3 FPGA 3-in-1 디지털 시계 — 설계 · 시뮬레이션 검증", 21, TEXT2))
    for i, (k, nm) in enumerate([("sw", "STOPWATCH"), ("wt", "WATCH"), ("tm", "TIMER")]):
        chip(s, 0.95 + i * 2.05, 6.15, 1.85, 0.46, nm, None, FN[k][0], 13, True, line_c=FN[k][0])
    text(s, 0.95, 9.05, 9.0, 0.4, R("2026. 10. 18", 15, TEXT2))
    text(s, 0.95, 9.45, 9.0, 0.4, R("팀원   정안성 · 정보윤 · 이종혁", 15, TEXT2))
    # 오른쪽: FND 4 자리 그림
    box(s, 11.3, 2.6, 7.8, 4.3, fill="1C1F23", geom="roundRect", adj=6000)
    for i, d in enumerate("1200"):
        x = 11.75 + i * 1.78
        text(s, x, 3.0, 1.55, 2.5, P(R(d, 150, "FF4136", False, MONO), algn="ctr"), anchor="ctr")
        if i == 1:
            box(s, x + 1.5, 4.95, 0.2, 0.2, fill="FF4136", geom="ellipse")
    for i, an in enumerate(["AN3", "AN2", "AN1", "AN0"]):
        text(s, 11.75 + i * 1.78, 5.75, 1.55, 0.35, P(R(an, 12, "9AA0A6", f=MONO), algn="ctr"))
    text(s, 11.3, 7.05, 7.8, 0.4, P(R("FND 4 자리 · 버튼 4 개 · 스위치 5 개로 세 기능을 전환", 13, MUTED), algn="ctr"))
    return s


TOC = [("01", "프로젝트 개요", "팀 구성 · 기능별 목표 · 핵심 결과"),
       ("02", "보드 사용 설명서", "스톱워치 · 시계 · 타이머 조작법"),
       ("03", "시스템 구조", "Top 블록 다이어그램 · 신호 흐름"),
       ("04", "시뮬레이션 검증", "시계 · 스톱워치 · 타이머 시나리오"),
       ("05", "트러블 슈팅", "현상 → 원인 → 해결 → 적용 결과"),
       ("06", "결론 · 고찰", "목표 달성 수치 · 남은 과제"),
       ("07", "시연 영상", "보드 동작")]


def s_contents():
    s = Slide()
    brand(s)
    text(s, 0.92, 1.18, 7.0, 1.1, R("Contents", 47, "595959", False, FONT_L))
    text(s, 0.95, 2.35, 6.5, 0.9, [P(R("Basys-3 FPGA 위에 세 가지 시간 기능을 하나의 Top 으로 통합,", 14, MUTED)),
                                   P(R("Top 테스트벤치로 버튼 → FND 전체 경로를 검증", 14, MUTED))])
    for i, (n, t, d) in enumerate(TOC):
        y = 1.35 + i * 1.2
        text(s, 8.6, y, 1.3, 0.8, R(n, 32, "BFBFBF", False, FONT_L), anchor="ctr")
        text(s, 10.0, y + 0.02, 5.0, 0.5, R(t, 22, TEXT, False), anchor="ctr")
        text(s, 10.0, y + 0.5, 8.5, 0.35, R(d, 13, MUTED), anchor="ctr")
        line(s, 8.6, y + 1.05, 19.08, y + 1.05, c=LINE, lw=0.75, arrow=False)
    for i, (k, nm, d) in enumerate([("sw", "STOPWATCH", "시작 · 정지 · 초기화 · 업/다운 + LAP"),
                                    ("wt", "WATCH", "12:00 시작 · SW2 자리 단위 설정 · 12/24 h"),
                                    ("tm", "TIMER", "+10 초 · +1 분 · +10 분 · 0 도달 알람")]):
        y = 6.6 + i * 1.05
        box(s, 0.95, y + 0.08, 0.22, 0.22, fill=FN[k][0], geom="ellipse")
        text(s, 1.35, y - 0.05, 5.0, 0.45, R(nm, 16, FN[k][0], True), anchor="ctr")
        text(s, 1.35, y + 0.38, 6.5, 0.4, R(d, 13, TEXT2), anchor="ctr")
    return s


def s_team():
    s = Slide()
    header(s, "01  프로젝트 개요", "팀 구성 · 역할 분담",
           "FND · Top TB / 타이머 · 시계 · 자원 최적화 / 스톱워치 · LAP — 기능 단위로 나눠 설계 · 검증", chip_t="요약")
    members = [
        ("정안성", "FND · Top 검증", "dp", ["FND 컨트롤러 설정 자리 점멸 기능 추가", "Top 모듈 전체 TB 시나리오 구성",
                                           "트러블 슈팅 3 : 디바운서"], ["FND", "TOP TB"]),
        ("정보윤", "Timer · Watch 설계", "tm", ["Timer · Watch 모듈 설계", "자원 최적화 — tick 구조 4 종 비교 (LUT · FF)",
                                              "타이머 검증 · 트러블 슈팅 2"], ["TIMER", "WATCH", "자원"]),
        ("이종혁", "Stopwatch · LAP", "sw", ["Stopwatch 기능 동작 확인 (R · L · U)", "D 버튼 LAP time 추가",
                                            "LAP 저장 · 해제 파형 검증"], ["STOPWATCH", "LAP"]),
    ]
    for i, (nm, role, k, tasks, tags) in enumerate(members):
        x = 0.92 + i * 6.15
        box(s, x, 2.6, 5.86, 7.45, fill=BG2, geom="roundRect", adj=3000)
        box(s, x + 2.18, 3.0, 1.5, 1.5, [P(R(nm[0], 34, WHITE, False, FONT_L), algn="ctr")], fill=FN[k][0],
            geom="ellipse", anchor="ctr")
        text(s, x, 4.7, 5.86, 0.6, P(R(nm, 26, TEXT, True), algn="ctr"), anchor="ctr")
        text(s, x, 5.3, 5.86, 0.4, P(R(role, 15, FN[k][0], True), algn="ctr"), anchor="ctr")
        line(s, x + 0.6, 5.95, x + 5.26, 5.95, c=LINE, arrow=False)
        for j, t in enumerate(tasks):
            circle_num(s, x + 0.82, 6.48 + j * 0.72, 0.36, str(j + 1), FN[k][0], sz=12)
            text(s, x + 1.15, 6.25 + j * 0.72, 4.5, 0.46, R(t, 15, TEXT), anchor="ctr")
        tx = x + 0.6
        for t in tags:
            wdt = 0.3 + 0.13 * len(t) if t.isascii() else 0.3 + 0.27 * len(t)
            chip(s, tx, 9.35, wdt, 0.4, t, None, FN[k][0], 11, True, line_c=FN[k][0])
            tx += wdt + 0.12
    return s


def s_goal():
    s = Slide()
    header(s, "01  프로젝트 개요", "기능별 목표 · 핵심 결과",
           "목표 기능 전부 구현 — Top TB 검사 436 개 PASS · 보드 동작 확인")
    goals = [
        ("wt", "WATCH", "SW2 설정 — 커서 + 자리 단위 올림", ["SW2 = 1 → 설정 모드, L · R 로 커서 이동", "U · D 로 그 자리만 ± (분 십의 자리 ± 10 분)",
                                                      "설정 중인 자리 점멸로 커서 위치 표시"]),
        ("sw", "STOPWATCH", "기존 스톱워치 + D 버튼 LAP time", ["시작 · 정지 · 초기화 · 업 / 다운 (R · L · U)", "D : 현재 시간 저장 · 표시 고정, 다시 D 로 복귀",
                                                           "LAP 중에도 내부 측정은 계속"]),
        ("tm", "TIMER", "새 기능 — 빠른 알람 타이머", ["U + 10 초 · R + 1 분 · D + 10 분, 상한 59 : 59", "L 시작 / 진행 중 취소",
                                                  "0 도달 → LED 16 개 0.5 s 점멸 알람"]),
    ]
    for i, (k, tag, head, bl) in enumerate(goals):
        x = 0.92 + i * 6.15
        box(s, x, 2.55, 5.86, 3.95, fill=FN[k][1], geom="roundRect", adj=4000)
        chip(s, x + 0.35, 2.85, 0.32 + 0.14 * len(tag), 0.42, tag, FN[k][0], WHITE, 12)
        text(s, x + 0.35, 3.45, 5.3, 0.55, R(head, 18, TEXT, True), anchor="ctr")
        for j, t in enumerate(bl):
            text(s, x + 0.35, 4.2 + j * 0.62, 0.3, 0.45, R("·", 18, FN[k][0], True), anchor="ctr")
            text(s, x + 0.65, 4.2 + j * 0.62, 5.0, 0.45, R(t, 14.5, TEXT), anchor="ctr")
    stats = [("436 / 436", "Top TB 11 개 · 검사 PASS"), ("1.6 %", "LUT 337 · FF 228 (0.5 %)"),
             ("+3.785 ns", "WNS @ 100 MHz · 래치 0"), ("10 s + 20 ns", "10 초 타이머 실측 (2 클럭 고정 지연)")]
    for i, (num, lab) in enumerate(stats):
        x = 0.92 + i * 4.6
        text(s, x, 7.05, 4.3, 1.1, R(num, 44, ACCENT if i == 0 else DARK, False, FONT_L), anchor="ctr")
        line(s, x, 8.25, x + 4.1, 8.25, c=LINE, arrow=False)
        text(s, x, 8.35, 4.3, 0.5, R(lab, 14, TEXT2), anchor="ctr")
    figure_note(s, "Note. 수치 출처 — Vivado 2022.2 구현 결과 (xc7a35t) · xsim Top TB [SUMMARY] 자동 판정 (부록 A)", y=9.6)
    return s


def mini_board(s, x, y, k, fnd, cap, btn, leds, sws):
    """보드 그림: btn = {'R': '①', ...}, leds = {0, 2}, sws = {0: '1', 1: '0/1'}"""
    c, _ = FN[k]
    w, h = 5.86, 3.5
    box(s, x, y, w, h, fill="2A2F35", geom="roundRect", adj=4000)
    text(s, x + w - 1.75, y + 0.12, 1.55, 0.3, P(R("BASYS 3", 11, WHITE, True), algn="r"))
    box(s, x + 0.3, y + 0.42, 3.05, 1.2, [P(R(fnd, 44, "FF4136", False, MONO), algn="ctr")], fill="0E0F11",
        anchor="ctr")
    text(s, x + 0.3, y + 1.65, 3.05, 0.3, P(R(cap, 10.5, "E2C08D"), algn="ctr"), anchor="ctr")
    cx, cy, b = x + 4.55, y + 1.05, 0.42
    for key, (dx, dy) in {"U": (0, -0.5), "L": (-0.5, 0), "C": (0, 0), "R": (0.5, 0), "D": (0, 0.5)}.items():
        on = key in btn
        box(s, cx + dx - b / 2, cy + dy - b / 2, b, b, [P(R(key, 12, WHITE if on else "AEB4BA", True), algn="ctr")],
            fill=c if on else "4A525A", geom="roundRect", adj=15000, anchor="ctr")
        if on:
            circle_num(s, cx + dx + 0.27, cy + dy - 0.24, 0.27, btn[key], WHITE, c, 10)
    for i in range(16):
        n = 15 - i
        lx = x + 0.3 + i * 0.334
        box(s, lx, y + 2.15, 0.2, 0.1, fill="4ADE80" if n in leds else "4A525A")
        if n in leds:
            text(s, lx - 0.15, y + 1.93, 0.5, 0.2, P(R(f"LD{n}", 8, "4ADE80", True), algn="ctr"))
        on = n in sws
        box(s, lx, y + 2.4, 0.2, 0.42, fill="15181B", line=c if on else None, lw=1.75)
        box(s, lx + 0.03, y + 2.62 if sws.get(n) != "1" else y + 2.44, 0.14, 0.16, fill="D0D4D8" if on else "5A636B")
        if on:
            text(s, lx - 0.15, y + 2.86, 0.5, 0.2, P(R(f"SW{n}", 8, WHITE, True), algn="ctr"))
            text(s, lx - 0.15, y + 3.06, 0.5, 0.2, P(R(sws[n], 8, "E2C08D", True), algn="ctr"))


def s_board():
    s = Slide()
    header(s, "02  보드 사용 설명서", "보드 사용 설명서 — 기능별 조작법",
           "SW4 · SW0 로 화면 선택 (타이머 > 스톱워치 > 시계) · 버튼 4 개는 보이는 화면의 기능만 조작", chip_t="요약")
    cols = [
        ("sw", "STOPWATCH", "SW4 = 0 · SW0 = 1  →  LD1", "05.27", "SW1 = 0 → 초 . 1/100 초",
         {"R": "1", "L": "2", "U": "3", "D": "4"}, {1, 3, 7}, {0: "1", 1: "0/1", 4: "0"},
         [("①", "BTNR", "시작 / 정지 토글"), ("②", "BTNL", "초기화 → 00:00:00.00 (정지 중)"),
          ("③", "BTNU", "Up ↔ Down 방향 전환 (정지 중)"), ("④", "BTND", "LAP : 시간 저장 · 표시 고정 / 다시 → 실시간"),
          ("", "SW1", "화면 0 : 초.1/100초 · 1 : 시.분"), ("", "LED", "LD1 스톱워치 · LD7 LAP · LD3 / LD2 화면")]),
        ("wt", "WATCH", "SW4 = 0 · SW0 = 0  →  LD0", "12.00", "SW1 = 1 → 시 . 분 (설정 자리 점멸)",
         {"L": "1", "R": "2", "U": "3", "D": "4"}, {0, 2}, {0: "0", 1: "1", 2: "1", 3: "0/1", 4: "0"},
         [("", "SW2", "1 : 설정 모드 (분 1 의 자리부터) · 0 : 끝"), ("①②", "BTNL / R", "설정 자리 이동  시 ↔ 분10 ↔ 분1"),
          ("③", "BTNU", "그 자리 + 1  (분10 자리 : + 10 분)"), ("④", "BTND", "그 자리 − 1  (분10 자리 : − 10 분)"),
          ("", "SW3", "0 : 12 시간 (오후 LD15) · 1 : 24 시간"), ("", "SW1", "1 : 시.분 화면 — 설정 자리 점멸")]),
        ("tm", "TIMER", "SW4 = 1 (우선)  →  LD5 · 진행 중 LD6", "01.30", "분 . 초 고정 (MM.SS)",
         {"U": "1", "R": "2", "D": "3", "L": "4"}, {5, 6}, {4: "1"},
         [("①", "BTNU", "+ 10 초"), ("②", "BTNR", "+ 1 분"), ("③", "BTND", "+ 10 분 (상한 59 : 59)"),
          ("④", "BTNL", "시작 (0 이면 무시) · 진행 중 취소 → 0"), ("", "ALARM", "0 도달 → LED 16 개 0.5 s 점멸"),
          ("", "끄기", "알람 중 아무 버튼 → SET (값 유지)")]),
    ]
    for i, (k, tag, cond, fnd, cap, btn, leds, sws, rows) in enumerate(cols):
        x = 0.92 + i * 6.15
        c = FN[k][0]
        chip(s, x, 2.5, 0.32 + 0.15 * len(tag), 0.44, tag, c, WHITE, 13)
        text(s, x + 0.45 + 0.15 * len(tag), 2.5, 4.5, 0.44, R(cond, 13.5, TEXT, True, MONO if False else FONT),
             anchor="ctr")
        mini_board(s, x, 3.1, k, fnd, cap, {kk: "①②③④"[int(v) - 1] for kk, v in btn.items()}, leds, sws)
        trows = [[{"t": "#"}, {"t": "입력"}, {"t": "동작"}]]
        for num, inp, act in rows:
            trows.append([{"t": num, "c": c, "b": True, "algn": "ctr"}, {"t": inp, "b": True, "f": MONO, "sz": 12.5},
                          {"t": act, "sz": 12.5}])
        table(s, x, 6.8, [0.7, 1.2, 3.96], trows, rowh=0.47, fs=12.5, head_fill=c)
    figure_note(s, "Note. BTNC = 전체 리셋 (세 기능 모두 초기화) · 다른 화면을 보는 동안에도 스톱워치 · 시계 · 타이머는 계속 동작", y=10.2)
    return s


def s_block():
    s = Slide()
    header(s, "03  시스템 구조", "Top 블록 다이어그램 — 버튼에서 FND · LED 까지",
           "기능마다 컨트롤 유닛 → tick → 데이터패스 사슬 · 화면 MUX 로 FND 공유 · 100 Hz tick 은 기능별 분리",
           chip_t="요약")
    PX0, PX1 = 0.55, 1.6
    C1, C1R = 1.8, 3.35
    G, GR = 3.8, 4.95
    CU, CUR = 5.4, 7.3
    TG, TGR = 8.0, 9.7
    DP, DPR = 10.3, 12.2
    MX, MXR = 12.65, 13.3
    TX, TXR = 13.45, 14.9
    FD, FDR = 15.0, 17.3
    OT = 17.5

    def tag(x, y, w, t, col=DARK, h=0.3):
        box(s, x, y - h / 2, w, h, [P(R(t, 10, WHITE, False, MONO))], fill=col, geom="homePlate", anchor="ctr",
            ins=(0.07, 0, 0.12, 0))

    def blk(k, x, y, w, h, title, inst, lines=(), tsz=12.5):
        fc, fl = FN[k]
        paras = [P(R(title, tsz, TEXT, True), algn="ctr"), P(R(inst, 9, MUTED, False, MONO), algn="ctr")]
        paras += [P(R(t, 10, TEXT2), algn="ctr") for t in lines]
        box(s, x, y, w, h, paras, fill=fl, line=fc, lw=1.5, geom="roundRect", adj=7000, anchor="ctr",
            ins=(0.05, 0.04, 0.05, 0.04))

    def lab(x, y, w, t, c=MUTED, algn="l", sz=9, f=MONO, h=0.2):
        text(s, x, y, w, h, P(R(t, sz, c, False, f), algn=algn), anchor="ctr")

    def data(x1, y1, x2, y2=None, **kw):
        line(s, x1, y1, x2, y1 if y2 is None else y2, c=DATA_C, lw=2.25, **kw)

    def ctrl(x1, y1, x2, y2=None, lw=1.25, **kw):
        line(s, x1, y1, x2, y1 if y2 is None else y2, c=CTRL_C, lw=lw, **kw)

    def tick(x1, y1, x2, y2=None, **kw):
        line(s, x1, y1, x2, y1 if y2 is None else y2, c=TICK_C, lw=1.75, dash="dash", **kw)

    # 기능 묶음 바탕
    for k, nm, y0, y1 in [("sw", "STOPWATCH", 3.25, 4.97), ("wt", "WATCH", 5.1, 7.45), ("tm", "TIMER", 7.6, 9.6)]:
        box(s, CU - 0.22, y0, DPR - CU + 0.44, y1 - y0, fill=FN[k][1], geom="roundRect", adj=3000)
        lab(CU - 0.12, y0 + 0.02, 2.0, nm, FN[k][0], sz=10, f=FONT)
    # 클럭 · 4 kHz
    Y4 = 2.8
    tag(PX0, Y4, 1.05, "clk  W5")
    ctrl(PX1, Y4, C1)
    blk("cm", C1, 2.58, 2.3, 0.44, "clock_tick_generator", "U_CLK_GEN_4KHZ", tsz=11)
    tick((C1 + C1R) / 2, 3.02, (C1 + C1R) / 2, 3.4)
    path(s, [(C1 + 2.3, Y4), ((FD + FDR) / 2, Y4), ((FD + FDR) / 2, 3.4)], c=TICK_C, lw=1.75, dash="dash")
    lab(4.6, 2.55, 7.0, "w_clk_4khz — 4 kHz (250 µs) · 디바운서 · FND 스캔 공용", TICK_C)
    # 버튼 · 디바운서
    blk("cm", C1, 3.4, C1R - C1, 2.6, "btn_debounce ×4", "U_BD_R/L/U/D", ["4 kHz 8 번 샘플", "(2 ms) → 1 클럭 펄스"],
        tsz=11.5)
    for kk, pin, y in [("R", "T17", 3.75), ("L", "W19", 4.35), ("U", "T18", 4.95), ("D", "U17", 5.55)]:
        tag(PX0, y, 1.05, f"btn{kk}  {pin}")
        ctrl(PX1, y, C1)
        ctrl(C1R, y, G)
        lab(C1R + 0.03, y - 0.21, 0.42, f"btn_{kk}")
    for t, y in [("SW0 mode", 6.55), ("SW4 timer", 7.05)]:
        tag(PX0, y, 1.25, t)
        ctrl(PX0 + 1.25, y, G)
    tag(PX0, 9.05, 1.05, "rst  U18", col=ACCENT)
    text(s, 1.72, 8.82, 2.0, 0.48, [P(R("BTNC → 모든 순차", 10, MUTED)), P(R("모듈 비동기 리셋", 10, MUTED))])
    # 게이팅
    box(s, G, 3.4, GR - G, 6.05,
        [P(R("모드 선택", 12, TEXT, True), algn="ctr"), P(R("& 버튼", 12, TEXT, True), algn="ctr"),
         P(R("게이팅", 12, TEXT, True), algn="ctr"), P(R("top assign", 9, MUTED, False, MONO), algn="ctr", bef=2),
         P(R("sel_tm = SW4", 9.5, TEXT2), algn="ctr", bef=6), P(R("sel_sw =", 9.5, TEXT2), algn="ctr", bef=4),
         P(R("~SW4 & SW0", 9.5, TEXT2), algn="ctr"), P(R("sel_wt =", 9.5, TEXT2), algn="ctr", bef=4),
         P(R("~SW4 & ~SW0", 9.5, TEXT2), algn="ctr")],
        fill=FN["cm"][1], line=FN["cm"][0], lw=1.5, geom="roundRect", adj=6000, anchor="ctr")
    # 스톱워치
    blk("sw", CU, 3.45, CUR - CU, 1.05, "stopwatch_control_unit", "U_STOPWATCH_CONTROL_UNIT", ["STOP · RUN"], tsz=11.5)
    blk("sw", TG, 3.45, TGR - TG, 0.75, "tick_gen_100hz_run", "U_TICK_GEN_SW", ["RUN 동안만 셈"], tsz=11)
    blk("sw", DP, 3.45, DPR - DP, 1.3, "stopwatch_datapath", "U_STOPWATCH_DATAPATH", ["경과 시간 · LAP"], tsz=11.5)
    ctrl(GR, 4.0, CU, lw=2.25); lab(GR + 0.04, 3.78, 0.4, "×3", sz=10)
    ctrl(CUR, 3.75, TG); lab(CUR + 0.04, 3.38, 0.6, "run_stop", h=0.17); lab(CUR + 0.04, 3.55, 0.6, "clear", h=0.17)
    tick(TGR, 3.75, DP); lab(TGR + 0.04, 3.53, 0.6, "sw_tick", TICK_C)
    ctrl(CUR, 4.35, DP); lab(TG + 0.1, 4.37, 1.6, "clear · down")
    ctrl(GR, 4.68, DP); lab(CU + 0.05, 4.7, 1.5, "btn_D (LAP)")
    # 시계
    blk("wt", CU, 5.3, CUR - CU, 1.05, "watch_control_unit", "U_WATCH_CONTROL_UNIT", ["NORMAL · 커서 3 자리"], tsz=11.5)
    blk("wt", TG, 5.3, TGR - TG, 0.75, "tick_gen_100hz", "U_TICK_GEN_100HZ", ["항상 흐름"], tsz=11)
    blk("wt", DP, 5.3, DPR - DP, 1.15, "watch_datapath", "U_WATCH_DATAPATH", ["현재 시각 (설정 ±)"], tsz=11.5)
    blk("wt", DP, 6.75, DPR - DP, 0.55, "hour_12_24", "U_HOUR_12_24", tsz=11)
    ctrl(GR, 5.85, CU, lw=2.25); lab(GR + 0.04, 5.63, 0.4, "×4", sz=10)
    tick(TGR, 5.6, DP); lab(TGR + 0.04, 5.38, 0.6, "wt_tick", TICK_C)
    ctrl(CUR, 6.2, DP); lab(TG + 0.1, 6.22, 1.8, "cursor · up · down")
    ctrl(CU + 0.95, 6.78, CU + 0.95, 6.35); lab(CU + 0.35, 6.8, 1.2, "SW2 (설정)", TEXT2, "ctr", 10)
    data((DP + DPR) / 2, 6.45, (DP + DPR) / 2, 6.75); lab((DP + DPR) / 2 + 0.06, 6.5, 0.5, "hour")
    ctrl(DP - 0.45, 7.02, DP); lab(DP - 1.85, 6.92, 1.36, "SW3 (12/24h)", TEXT2, "r", 10)
    # 타이머
    blk("tm", CU, 7.8, CUR - CU, 1.4, "timer_control_unit", "U_TIMER_CONTROL_UNIT", ["SET · RUN · ALARM"], tsz=11.5)
    blk("tm", TG, 7.8, TGR - TG, 0.75, "tick_gen_100hz_run", "U_TICK_GEN_TM", ["clear = 취소 | 알람"], tsz=11)
    blk("tm", DP, 7.8, DPR - DP, 1.4, "timer_datapath", "U_TIMER_DATAPATH", ["남은 시간 다운카운트"], tsz=11.5)
    ctrl(GR, 8.5, CU, lw=2.25); lab(GR + 0.04, 8.28, 0.4, "×4", sz=10)
    ctrl(CUR, 8.1, TG); lab(CUR + 0.04, 7.88, 0.6, "run·clr")
    tick(TGR, 8.1, DP); lab(TGR + 0.04, 7.88, 0.6, "tm_tick", TICK_C)
    ctrl(CUR, 8.8, DP); lab(TG + 0.1, 8.82, 2.2, "run · clear · add · amount")
    ctrl(DP, 9.07, CUR); lab(TG + 0.1, 9.09, 0.8, "zero")
    # 화면 MUX
    box(s, MX, 3.45, MXR - MX, 5.75,
        [P(R("화면", 12, TEXT, True), algn="ctr"), P(R("MUX", 12, TEXT, True), algn="ctr"),
         P(R("3:1 ×4", 9.5, MUTED), algn="ctr", bef=4)] + [P(R(t, 9, TEXT2, False, MONO), algn="ctr", bef=3)
                                                           for t in ("msec", "sec", "min", "hour")],
        fill=FN["cm"][1], line=FN["cm"][0], lw=1.5, geom="roundRect", adj=10000, anchor="ctr")
    for t, y, d in [("SW", 4.05, True), ("WT", 5.75, True), ("hour", 7.02, True), ("TM", 8.45, True)]:
        data(DPR, y, MX)
        lab(DPR + 0.03, y - 0.22, 0.42, t)
    ctrl((MX + MXR) / 2, 9.55, (MX + MXR) / 2, 9.2)
    lab(MX - 0.6, 9.56, 1.85, "sel : SW4 > SW0", TEXT2, "ctr", 10)
    # FND · LED
    blk("dp", FD, 3.4, FDR - FD, 2.7, "SW2_FND_CONTROLLER", "U_FND_CONTROLLER",
        ["자리 분리 → 설정 자리 점멸", "→ 8 칸 스캔 (4 kHz)", "→ 세그먼트"], tsz=11.5)
    data(MXR, 3.85, FD); lab(MXR + 0.08, 3.62, 1.2, "w_disp_*")
    for t, y in [("wt_cursor", 4.4), ("sel_wt", 4.8), ("SW1 | SW4", 5.2), ("SW2 set", 5.6)]:
        tag(TX, y, TXR - TX, t, h=0.28)
        ctrl(TXR, y, FD)
    blk("cm", FD, 6.55, FDR - FD, 2.65, "LED 로직", "top assign",
        ["화면 · 동작 상태 표시", "알람 : 16 개 0.5 s 점멸", "(wt_msec ≥ 50 박자)"], tsz=11.5)
    for t, y in [("sel_sw/wt/tm", 6.95), ("SW1 · SW3 · SW4", 7.35), ("tm_run·alarm", 7.75), ("sw_lap · wt_pm", 8.15),
                 ("wt_msec", 8.55)]:
        tag(TX, y, TXR - TX, t, h=0.28)
        ctrl(TXR, y, FD)
    for t, y in [("fnd_com[3:0]", 4.3), ("fnd_font[7:0]", 5.2), ("led[15:0]", 7.85)]:
        data(FDR, y, OT)
        tag(OT, y, 1.75, t, col=ACCENT)
    # 범례
    lx = 0.92
    for k, t in [("sw", "스톱워치"), ("wt", "시계"), ("tm", "타이머"), ("dp", "표시"), ("cm", "공통")]:
        box(s, lx, 9.98, 0.32, 0.22, fill=FN[k][1], line=FN[k][0], lw=1.25, geom="roundRect", adj=20000)
        text(s, lx + 0.38, 9.92, 1.0, 0.34, R(t, 11.5, TEXT2), anchor="ctr")
        lx += 1.35
    for t, c, lw, d in [("데이터 (시간 값 버스)", DATA_C, 2.25, None), ("제어 신호", CTRL_C, 1.25, None),
                        ("tick · 4 kHz 클럭", TICK_C, 1.75, "dash")]:
        line(s, lx + 0.1, 10.09, lx + 0.65, 10.09, c=c, lw=lw, dash=d)
        text(s, lx + 0.75, 9.92, 2.3, 0.34, R(t, 11.5, TEXT2), anchor="ctr")
        lx += 2.75
    text(s, lx, 9.92, 4.0, 0.34, R("▶ 태그 = 보드 핀 · 같은 이름의 net", 11.5, TEXT2), anchor="ctr")
    return s


def s_divider(num, title, items, foot=None):
    s = Slide()
    brand(s)
    text(s, 0.92, 1.6, 6.0, 2.2, R(num, 120, "D9D9D9", False, FONT_L), anchor="ctr")
    text(s, 0.95, 3.9, 9.0, 1.0, R(title, 47, "595959", False, FONT_L), anchor="ctr")
    for i, (k, head, d) in enumerate(items):
        y = 1.9 + i * 1.75
        col = FN[k][0] if k in FN else DARK
        box(s, 10.2, y, 8.9, 1.45, fill=FN[k][1] if k in FN else BG2, geom="roundRect", adj=8000)
        text(s, 10.55, y + 0.18, 8.3, 0.5, R(head, 20, col, True), anchor="ctr")
        text(s, 10.55, y + 0.72, 8.3, 0.5, R(d, 14, TEXT2), anchor="ctr")
    if foot:
        text(s, 0.95, 5.2, 8.5, 2.0, [P(R(t, 14, MUTED), bef=4) for t in foot])
    return s


SCN_COLS = [0.7, 3.2, 4.4, 4.3, 5.56]


def scn_table(s, rows, fn, y=2.55, rowh=0.62, extra_col=None):
    c = FN[fn][0]
    head = ["#", "시나리오", "입력 (Stimulus)", "확인 신호", "예상 결과"]
    colw = list(SCN_COLS)
    if extra_col:
        head.append(extra_col)
        colw = [0.7, 3.0, 4.0, 3.9, 5.06, 1.5]
    trows = [[{"t": h} for h in head]]
    for r in rows:
        trows.append([{"t": r[0], "c": c, "b": True, "algn": "ctr", "sz": 15}, {"t": r[1], "b": True, "sz": 14},
                      {"t": r[2], "sz": 13}, {"t": r[3], "sz": 12.5, "f": MONO, "c": TEXT2},
                      {"t": r[4], "sz": 13.5, "b": True}] + ([{"t": r[5], "sz": 12.5, "algn": "ctr", "c": "2E7D32", "b": True}]
                                                           if extra_col else []))
    table(s, 0.92, y, colw, trows, rowh=[0.55] + [rowh] * len(rows), fs=14, head_fill=c)


def s_watch_table():
    s = Slide()
    header(s, "04  시뮬레이션 · 시계", "시계 시뮬레이션 시나리오", "[작성 중] 시나리오 5 개 — 표 · 파형 추가 예정", fn="wt",
           chip_t="요약")
    scn_table(s, [[str(i), "", "", "", ""] for i in range(1, 6)], "wt", rowh=1.25)
    return s


def s_watch_scn(n):
    s = Slide()
    header(s, "04  시뮬레이션 · 시계", f"시계 시나리오 {n} :", "[작성 중] 검증 결과 한 줄", fn="wt")
    box(s, 0.92, 2.5, 18.16, 5.6, [P(R("파형 캡처 삽입 영역", 20, "BFBFBF"), algn="ctr")], line="BFBFBF", lw=1.5,
        dash="dash", anchor="ctr")
    for j in range(3):
        circle_num(s, 1.15, 8.6 + j * 0.52, 0.36, "①②③"[j], "BFBFBF", sz=12)
        text(s, 1.5, 8.4 + j * 0.52, 16, 0.42, R("확인 포인트 (파형 번호와 같은 번호)", 15, "BFBFBF", i=True), anchor="ctr")
    figure_note(s, f"Figure. 시계 시나리오 {n}  (작성 중)")
    return s


def s_sw_table():
    s = Slide(notes=NOTES.get(11))
    header(s, "04  시뮬레이션 · 스톱워치", "스톱워치 시뮬레이션 시나리오",
           "R · L · U 기본 동작 3 개 + D 버튼 LAP 2 개 — 버튼마다 한 시나리오", fn="sw", chip_t="요약")
    rows = [["1", "R  정지 · 재실행", "RUN 중 R → 정지 → R 재입력", "w_sw_run_stop · o_sw_msec", "정지 중 값 유지, 재실행 후 증가"],
            ["2", "L  정지 중 초기화", "R 로 정지 → L", "w_sw_clear · o_sw_msec", "Clear 펄스 → 16 → 0"],
            ["3", "U  감소 방향 전환", "정지 중 U → R 로 실행", "w_sw_down · o_sw_msec", "Down 1 → 5 · 4 · … · 0 감소"],
            ["4", "D  LAP 저장 · 표시 유지", "측정 중 D", "o_sw_lap · save_msec", "내부 카운터 증가, 표시 21 유지"],
            ["5", "D  LAP 해제 · 현재 값", "LAP 중 D 재입력", "save_msec · w_disp_msec", "저장값 11 유지, 표시 17 (현재)"]]
    scn_table(s, rows, "sw", rowh=0.8)
    box(s, 0.92, 7.45, 18.16, 1.25, fill=FN["sw"][1], geom="roundRect", adj=8000)
    text(s, 1.3, 7.55, 17.5, 1.05, [P(R("규칙   ", 15, FN["sw"][0], True), R("실행 중 L · U 입력 무시 (STOP 에서만 동작) · D 는 화면에 보낼 값만 바꾸고 내부 측정은 계속", 15, TEXT)),
                                    P(R("담당   ", 15, FN["sw"][0], True), R("이종혁 — LAP 구현 및 버튼 동작 검증", 15, TEXT), bef=6)],
         anchor="ctr")
    figure_note(s, "Note. 시나리오 3 의 99 → 5 구간은 감소를 짧게 보이기 위한 검증용 프리로드")
    return s


def s_tm_table():
    s = Slide(notes=NOTES.get(21))
    header(s, "04  시뮬레이션 · 타이머", "타이머 시뮬레이션 시나리오",
           "TB 3 개 · 검사 73 개를 $display 로 자동 판정 → 전부 PASS", fn="tm")
    rows = [["1", "더하기 · 자리 올림", "SET 에서 U 6 번 (+10 초씩)", "o_tm_add · o_tm_min/sec", "00:50 + 10 초 = 01:00", "TM1"],
            ["2", "59:59 상한", "59:40 에서 U 2 번", "o_tm_min · o_tm_sec", "59:50 → 59:59 유지 (60:00 X)", "TM1"],
            ["3", "10 초 카운트다운 · 알람", "00:10 설정 → L 시작", "c_state · o_tm_alarm · led", "알람까지 10 s + 20 ns · LED 0.5 s 점멸", "TM2"],
            ["4", "다운카운트 빌림", "01:00.00 · 10:00.00 에서 tick", "o_tm_min/sec/msec", "00:59.99 · 09:59.99", "TM2"],
            ["5", "백그라운드 · 화면 우선순위", "RUN 중 sw4 1 → 0 / 알람 중 R", "c_state · o_tm_alarm · led", "시계 화면에서도 알람 · R 은 알람만 끔", "TM3"]]
    scn_table(s, rows, "tm", rowh=0.66, extra_col="TB")
    box(s, 0.92, 6.75, 11.2, 2.75, [
        P(R("# Vivado xsim 콘솔 — 팀 TB (SystemVerilog) 마지막 줄", 12, "6A9955", f=MONO)),
        P(R("[  455.019 ms] [SUMMARY] TM1 checks=21 fail=0 => PASS", 13, "D4D4D4", f=MONO), bef=4),
        P(R("[11597.002 ms] [SUMMARY] TM2 checks=41 fail=0 => PASS", 13, "D4D4D4", f=MONO)),
        P(R("[  547.009 ms] [SUMMARY] TM3 checks=11 fail=0 => PASS", 13, "D4D4D4", f=MONO)),
        P(R("# 같은 시나리오를 수업 Verilog 문법 (err 카운트) 으로 옮긴 TB", 12, "6A9955", f=MONO), bef=6),
        P(R("TM1 checks = 21, TOTAL MISMATCH = 0   (TM2 41 · TM3 11 도 0)", 13, "D4D4D4", f=MONO))],
        fill="1E1E1E", geom="roundRect", adj=4000, ins=(0.3, 0.2, 0.3, 0.2), anchor="ctr")
    for i, (num, lab) in enumerate([("73 / 73", "검사 PASS (TM1 21 · TM2 41 · TM3 11)"), ("0", "TOTAL MISMATCH (Verilog TB)")]):
        x = 12.6
        y = 6.75 + i * 1.42
        text(s, x, y, 6.4, 0.85, R(num, 38, "2E7D32" if i == 0 else DARK, False, FONT_L), anchor="ctr")
        text(s, x, y + 0.82, 6.4, 0.4, R(lab, 13, TEXT2), anchor="ctr")
    figure_note(s, "Note. 판정 예 — if (값 !== 기대값) err = err + 1; $display(\"FAIL …\") · 캡처는 10/17 소스, 결과 숫자는 10/18 최종 소스 기준 (둘 다 전부 PASS)", y=9.75)
    return s


def s_ts1():
    s = Slide()
    header(s, "05  트러블 슈팅", "트러블 슈팅 1 — 버튼 동시 입력 시 예상과 다른 반응",
           "[작성 중] 원인 · 해결 · 적용 결과 자료 추가 예정", chip_t="요약", steps={1, 2, 3, 4}, title_sz=28)
    cells = [("① 현상", ["목표 : 버튼 2 개 이상 동시 입력 → 반응하지 않고 오류 처리",
                         "실제 : 우선순위대로 한 버튼만 동작 (시뮬레이션에서 확인)"], False),
             ("② 원인", ["[작성 중]"], True), ("③ 해결", ["[작성 중]"], True), ("④ 적용 결과", ["[작성 중] Before / After 비교"], True)]
    for i, (head, lines, pend) in enumerate(cells):
        x = 0.92 + (i % 2) * 9.18
        y = 2.5 + (i // 2) * 3.85
        box(s, x, y, 8.98, 3.6, fill=BG2 if not pend else None, line=None if not pend else "BFBFBF", lw=1.25,
            dash=None if not pend else "dash", geom="roundRect", adj=4000)
        text(s, x + 0.35, y + 0.25, 8.0, 0.5, R(head, 19, ACCENT if not pend else MUTED, True), anchor="ctr")
        text(s, x + 0.35, y + 0.95, 8.3, 2.4, [P(R(t, 15, MUTED if pend else TEXT, i=pend), bef=6) for t in lines])
    return s


def s_video():
    s = Slide()
    header(s, "07  시연 영상", "시연 영상 — 보드 동작", "[후첨] 보드 시연 영상 삽입 예정", chip_t="요약")
    box(s, 4.2, 2.55, 11.6, 6.53, fill="F2F2F2", line="BFBFBF", lw=1.25, dash="dash")
    box(s, 9.45, 5.3, 1.1, 1.1, fill="BFBFBF", geom="triangle")
    text(s, 4.2, 7.0, 11.6, 0.5, P(R("영상 삽입 영역 (16 : 9)", 16, MUTED), algn="ctr"))
    return s


def s_qna():
    s = Slide()
    brand(s)
    text(s, 0, 4.2, W, 1.2, P(R("Q & A", 54, "595959", False, FONT_L), algn="ctr"), anchor="ctr")
    text(s, 0, 5.45, W, 0.5, P(R("감사합니다", 18, MUTED), algn="ctr"), anchor="ctr")
    text(s, 12.0, 9.2, 7.1, 1.0, [P(R("STOPWATCH · WATCH · TIMER", 12, TEXT2, True), algn="r"),
                                  P(R("정안성 · 정보윤 · 이종혁", 12, MUTED), algn="r", bef=4)])
    return s


# ============================================================== 덱 순서
def slides():
    SW, TM, TS = "04  시뮬레이션 · 스톱워치", "04  시뮬레이션 · 타이머", "05  트러블 슈팅"
    out = [s_cover(), s_contents(), s_team(), s_goal(), s_board(), s_block(),
           s_divider("04", "시뮬레이션 검증", [
               ("wt", "시계", "SW2 설정 · 커서 · 자리 단위 증감 — 시나리오 5 개 (작성 중)"),
               ("sw", "스톱워치", "R · L · U 기본 동작 + D 버튼 LAP 저장 · 해제"),
               ("tm", "타이머", "더하기 · 59:59 상한 · 10 초 카운트다운 · 알람 · 백그라운드")],
               foot=["공통 검증 방법", "· Top 모듈을 넣은 TB · 100 MHz 그대로 (주파수 축소 없음)",
                     "· 시나리오 표 (입력 → 확인 신호 → 예상 결과) → 파형 · 콘솔 판정"]),
           s_watch_table()] + [s_watch_scn(n) for n in range(1, 6)]
    out += [s_sw_table(),
            moved(12, SW, "시나리오 1 : R 버튼 — 정지 · 재실행", "정지 중 값 유지, 재실행 후 카운터 증가", "sw",
                  sub="시나리오 : R 입력으로 정지한 뒤 다시 R 입력으로 실행", cut_top=2.2, drop=("파형 이미지", "이 안내 상자"),
                  fig="스톱워치 R 버튼 정지 · 재실행"),
            moved(13, SW, "시나리오 2 : L 버튼 — 정지 중 초기화", "Clear 신호 발생 후 시간 값 16 → 0 초기화", "sw",
                  sub="시나리오 : R 로 정지한 뒤 L 입력으로 시간 초기화 확인", cut_top=2.2, drop=("파형 이미지", "이 안내 상자"),
                  fig="스톱워치 L 버튼 정지 중 초기화"),
            moved(14, SW, "시나리오 3 : U 버튼 — 감소 방향 전환", "Down 신호 활성화 후 카운터 감소", "sw",
                  sub="시나리오 : 정지 중 U 입력 후 R 로 실행하여 감소 확인", cut_top=2.0,
                  drop=("파형 이미지", "이 안내 상자", "99에서 5로"), fig="스톱워치 U 버튼 감소 방향 전환 (99 → 5 는 검증용 프리로드)"),
            moved(15, SW, "LAP 기능 코드 설계 — 저장 · 출력 선택", "D 입력마다 LAP 토글, 켤 때만 저장 · 출력은 LAP 상태로 선택",
                  "sw", cut_top=1.25, chip_t="요약"),
            moved(16, SW, "시나리오 4 : LAP — 시간 저장 · 표시 유지", "내부 카운터는 증가, 표시값은 21 유지", "sw",
                  sub="시나리오 : 측정 중 D 버튼 입력 후 시간 저장과 표시 유지 확인", cut_top=2.2, drop=("파형 이미지", "이 안내 상자"),
                  fig="스톱워치 LAP 시간 저장 · 표시 유지"),
            moved(17, SW, "시나리오 5 : LAP — 해제 · 현재 값 표시", "저장값 11 대신 현재 카운터 값 17 표시", "sw",
                  sub="시나리오 : LAP 상태에서 D 버튼 재입력 후 현재 값 복귀 확인", cut_top=2.0, drop=("파형 이미지", "이 안내 상자"),
                  fig="스톱워치 LAP 해제 · 현재 값 복귀")]
    out += [moved(19, TM, "타이머 동작 사양 — SET · RUN · ALARM", "버튼 4 개로 더하고 · 시작하고 · 끈다 (3 상태 FSM)", "tm",
                  chip_t="요약"),
            s_tm_table(),
            moved(22, TM, "시나리오 1 : 더하기 · 자리 올림", "U 6 번째 — 00:50 + 10 초 = 01:00 (60 초 아님)", "tm", fig="타이머 더하기 · 자리 올림 (위 : 전체, 아래 : ns 확대)"),
            moved(23, TM, "시나리오 2 : 59:59 상한", "59:50 + 10 초 → 59:59 에서 멈춤 (분.초 4 자리라 60:00 불가)", "tm", fig="타이머 59:59 상한"),
            moved(24, TM, "시나리오 3-1 : 10 초 카운트다운 → 알람", "00:10 설정 → 시작부터 알람까지 10.000000020 s (= 10 s + 2 클럭)", "tm", fig="타이머 10 초 카운트다운 → 알람"),
            moved(25, TM, "시나리오 3-2 : 알람 LED 점멸", "알람 중 LED 16 개가 0.5 s 켜짐 · 0.5 s 꺼짐 반복", "tm", fig="타이머 알람 LED 점멸 (아래 : 49 → 50 확대)"),
            moved(26, TM, "시나리오 4 : 다운카운트 빌림", "빌림 정상 — 01:00.00 → 00:59.99, 10:00.00 → 09:59.99", "tm", fig="타이머 다운카운트 빌림"),
            moved(27, TM, "시나리오 5-1 : 백그라운드 동작", "시계 화면으로 바꿔도 타이머는 계속 줄고, 0 이 되면 알람", "tm", fig="타이머 백그라운드 동작 (왼쪽 : 화면 전환, 오른쪽 : 알람)"),
            moved(28, TM, "시나리오 5-2 : 화면 우선순위 · 알람 끄기", "sw4 · sw0 모두 1 → 타이머 화면, 알람 중 R 은 알람만 끄고 값 유지", "tm", fig="타이머 화면 우선순위 · 알람 끄기"),
            moved(29, TM, "타이머 검증 신뢰도 — 변이 테스트", "bug 2 종 주입 → TB 가 FAIL 7 개 · 1 개로 검출, 원 설계 MISMATCH 0", "tm")]
    out += [s_divider("05", "트러블 슈팅", [
                ("cm", "1. 버튼 동시 입력 — 예상과 다른 반응", "오류 처리 목표 → 우선순위 동작 (작성 중)"),
                ("tm", "2. 10 초 타이머가 9.998 초에 울림", "100 Hz tick 공유 → 기능별 tick 분리"),
                ("dp", "3. 한 번 눌렀는데 두 번 인식", "디바운서 샘플 1 MHz → 4 kHz")],
                foot=["분석 순서", "① 현상 → ② 원인 → ③ 해결 → ④ 적용 결과 (Before / After)"]),
            s_ts1(),
            moved(30, TS, "트러블 슈팅 2 — 10 초 타이머가 9.998 초에 울림",
                  "원인 : 100 Hz tick 1 개를 시계 · 스톱워치 · 타이머가 공유 → 시작 시점 따라 최대 10 ms 일찍", steps={1, 2},
                  chip_t="원인", title_sz=28),
            moved(33, TS, "트러블 슈팅 2 — 해결 : tick 구조 4 종 비교",
                  "④ 선택 : 4 kHz 공유 + 100 Hz 기능별 분리 → 매번 정확히 10 ms (FF + 42)", steps={3}, chip_t="해결",
                  title_sz=28),
            moved(34, TS, "트러블 슈팅 2 — 적용 결과",
                  "9.998000010 s → 10.000000020 s (10 s + 2 클럭 고정 지연) · 잔여 2 건도 PASS", steps={4}, title_sz=28),
            moved(35, TS, "트러블 슈팅 3 — 한 번 눌렀는데 두 번 인식",
                  "디바운서 샘플 1 MHz → 4 kHz : 같은 튐 입력 20 번 → 펄스 158 개 → 20 개", steps={1, 2, 3, 4},
                  title_sz=28),
            moved(36, "06  결론 · 고찰", "결론 · 고찰",
                  "목표 기능 전부 Top TB PASS · 보드 확인 — 고찰 : 남은 경고 · 입력 처리 한계 → 다음 목표", chip_t="결론",
                  cut_top=1.25),
            s_video(), s_qna(),
            moved(37, "부록  질문 대비", "부록 A — 검증 전체 : TB 11 개 · 검사 436 개 PASS",
                  "Top 을 넣은 TB · 100 MHz 그대로 · 콘솔 [SUMMARY] 자동 판정 · 최신 소스로 다시 실행", chip_t="요약",
                  cut_top=1.25)]
    return out


# ============================================================== 패키지 쓰기
SLD_T = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
         f'<p:sld xmlns:a="{A_NS}" xmlns:r="{R_NS}" xmlns:p="{P_NS}"><p:cSld><p:spTree><p:nvGrpSpPr>'
         '<p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/>'
         '<a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>{body}</p:spTree>'
         '</p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>')
NOTES_T = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
           f'<p:notes xmlns:a="{A_NS}" xmlns:r="{R_NS}" xmlns:p="{P_NS}"><p:cSld><p:spTree><p:nvGrpSpPr>'
           '<p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'
           '<p:sp><p:nvSpPr><p:cNvPr id="2" name="Slide Image Placeholder 1"/><p:cNvSpPr><a:spLocks noGrp="1" '
           'noRot="1" noChangeAspect="1"/></p:cNvSpPr><p:nvPr><p:ph type="sldImg"/></p:nvPr></p:nvSpPr><p:spPr/></p:sp>'
           '<p:sp><p:nvSpPr><p:cNvPr id="3" name="Notes Placeholder 2"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>'
           '<p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr><p:spPr/><p:txBody><a:bodyPr/><a:lstStyle/>'
           '<a:p><a:r><a:rPr lang="ko-KR" altLang="en-US" dirty="0"/><a:t>{text}</a:t></a:r></a:p></p:txBody></p:sp>'
           '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:notes>')
REL_T = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
         '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">{}</Relationships>')
RT = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"
CT = "application/vnd.openxmlformats-officedocument.presentationml."


def rel(rid, typ, tgt):
    return f'<Relationship Id="{rid}" Type="{typ}" Target="{tgt}"/>'


def write(deck):
    ref = zipfile.ZipFile(REF)
    parts = {}
    for n in ref.namelist():
        if n.startswith(("ppt/slideMasters/", "ppt/slideLayouts/", "ppt/theme/")) or n in (
                "ppt/tableStyles.xml", "ppt/viewProps.xml", "ppt/presProps.xml", "docProps/core.xml"):
            parts[n] = ref.read(n)
    for n in [n for n in parts if n.endswith(".rels")]:   # 레이아웃이 쓰는 그림
        for t in re.findall(r'Target="\.\./media/([^"]+)"', parts[n].decode()):
            parts["ppt/media/" + t] = ref.read("ppt/media/" + t)
    parts["ppt/notesMasters/notesMaster1.xml"] = SRCZ.read("ppt/notesMasters/notesMaster1.xml")
    parts["ppt/notesMasters/_rels/notesMaster1.xml.rels"] = REL_T.format(
        rel("rId1", RT + "theme", "../theme/theme2.xml")).encode()
    parts["ppt/theme/theme2.xml"] = SRCZ.read("ppt/theme/theme2.xml")

    pres_rels = [rel("rId1", RT + "slideMaster", "slideMasters/slideMaster1.xml"),
                 rel("rId2", RT + "notesMaster", "notesMasters/notesMaster1.xml"),
                 rel("rId3", RT + "theme", "theme/theme1.xml"), rel("rId4", RT + "presProps", "presProps.xml"),
                 rel("rId5", RT + "viewProps", "viewProps.xml"), rel("rId6", RT + "tableStyles", "tableStyles.xml")]
    sld_ids, nnotes = [], 0
    for i, s in enumerate(deck, 1):
        if i > 1:   # 쪽 번호 (표지 제외)
            text(s, 18.2, 10.62, 0.9, 0.35, P(R(f"{i:02d}", 11, MUTED), algn="r"))
        cnt = iter(range(2, 100000))
        body = re.sub(r'id="@@"', lambda m: f'id="{next(cnt)}"', "".join(s.sh))
        parts[f"ppt/slides/slide{i}.xml"] = SLD_T.format(body=body).encode("utf-8")
        rels = [rel("rId1", RT + "slideLayout", "../slideLayouts/slideLayout7.xml")] + [rel(*r) for r in s.rels]
        if s.notes:
            nnotes += 1
            rels.append(rel("rIdN", RT + "notesSlide", f"../notesSlides/notesSlide{i}.xml"))
            parts[f"ppt/notesSlides/notesSlide{i}.xml"] = NOTES_T.format(text=esc(s.notes)).encode("utf-8")
            parts[f"ppt/notesSlides/_rels/notesSlide{i}.xml.rels"] = REL_T.format(
                rel("rId1", RT + "notesMaster", "../notesMasters/notesMaster1.xml")
                + rel("rId2", RT + "slide", f"../slides/slide{i}.xml")).encode()
        parts[f"ppt/slides/_rels/slide{i}.xml.rels"] = REL_T.format("".join(rels)).encode()
        pres_rels.append(rel(f"rId{100 + i}", RT + "slide", f"slides/slide{i}.xml"))
        sld_ids.append(f'<p:sldId id="{255 + i}" r:id="rId{100 + i}"/>')
    for name, data in MEDIA.items():
        parts["ppt/media/" + name] = data

    pres = ref.read("ppt/presentation.xml").decode()
    pres = re.sub(r"<p:embeddedFontLst>.*?</p:embeddedFontLst>", "", pres, flags=re.S)
    pres = pres.replace(' embedTrueTypeFonts="1"', "").replace(' saveSubsetFonts="1"', "")
    pres = re.sub(r"<p:sldIdLst>.*?</p:sldIdLst>", "<p:sldIdLst>" + "".join(sld_ids) + "</p:sldIdLst>", pres, flags=re.S)
    pres = pres.replace("</p:sldMasterIdLst>",
                        '</p:sldMasterIdLst><p:notesMasterIdLst><p:notesMasterId r:id="rId2"/></p:notesMasterIdLst>')
    parts["ppt/presentation.xml"] = pres.encode()
    parts["ppt/_rels/presentation.xml.rels"] = REL_T.format("".join(pres_rels)).encode()
    parts["_rels/.rels"] = REL_T.format(
        rel("rId1", RT + "officeDocument", "ppt/presentation.xml")
        + rel("rId2", "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties",
              "docProps/core.xml")
        + rel("rId3", RT + "extended-properties", "docProps/app.xml")).encode()
    parts["docProps/app.xml"] = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Properties xmlns="http://schemas.openxmlformats.org/'
        'officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/'
        f'docPropsVTypes"><Application>Microsoft Office PowerPoint</Application><Slides>{len(deck)}</Slides>'
        f'<Notes>{nnotes}</Notes></Properties>').encode()

    ov = {"ppt/presentation.xml": CT + "presentation.main+xml", "ppt/presProps.xml": CT + "presProps+xml",
          "ppt/viewProps.xml": CT + "viewProps+xml", "ppt/tableStyles.xml": CT + "tableStyles+xml",
          "docProps/core.xml": "application/vnd.openxmlformats-package.core-properties+xml",
          "docProps/app.xml": "application/vnd.openxmlformats-officedocument.extended-properties+xml"}
    for n in parts:
        if re.match(r"ppt/slideMasters/slideMaster\d+\.xml$", n):
            ov[n] = CT + "slideMaster+xml"
        elif re.match(r"ppt/slideLayouts/slideLayout\d+\.xml$", n):
            ov[n] = CT + "slideLayout+xml"
        elif re.match(r"ppt/slides/slide\d+\.xml$", n):
            ov[n] = CT + "slide+xml"
        elif re.match(r"ppt/notesSlides/notesSlide\d+\.xml$", n):
            ov[n] = CT + "notesSlide+xml"
        elif re.match(r"ppt/notesMasters/notesMaster\d+\.xml$", n):
            ov[n] = CT + "notesMaster+xml"
        elif re.match(r"ppt/theme/theme\d+\.xml$", n):
            ov[n] = "application/vnd.openxmlformats-officedocument.theme+xml"
    ct = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Types xmlns="http://schemas.openxmlformats.org/'
          'package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.'
          'relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" '
          'ContentType="image/png"/><Default Extension="jpeg" ContentType="image/jpeg"/><Default Extension="jpg" '
          'ContentType="image/jpeg"/><Default Extension="svg" ContentType="image/svg+xml"/>'
          + "".join(f'<Override PartName="/{n}" ContentType="{t}"/>' for n, t in ov.items()) + "</Types>")
    parts["[Content_Types].xml"] = ct.encode()
    tmp = OUT + ".tmp"
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", parts.pop("[Content_Types].xml"))
        for n, d in parts.items():
            z.writestr(n, d)
    os.replace(tmp, OUT)
    print(f"ok: {os.path.basename(OUT)} — 슬라이드 {len(deck)} 장 · 노트 {nnotes} 장 · 그림 {len(MEDIA)} 개")


if __name__ == "__main__":
    write(slides())
