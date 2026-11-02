# final_ppt.pptx (팀원별 장 취합본, 10 × 5.625 in) 손보기 — 각자 포맷은 그대로, 글자 크기 · 목차만
# 사용 : python fix_final.py final_ppt.pptx [out.pptx]
#   1) 목차 (2 장) : 장 머리말 번호 (01 ~ 06) 와 맞추고 7 번째 줄 = 부록, 설명 끝에 발표자
#   2) 20 × 11.25 in 덱에서 가져와 0.5 배로 줄어든 장 (머리말 'WTS · SR04 · DHT11 · UART') :
#      머리말 · 쪽 번호 · 제목 = 덱 표준 (7 / 8 / 20 pt, 안 맞으면 줄임), 본문 = 칸 안 넘는 만큼만 키움 (1.4 → 1.1 배)
#      위치 · 크기 · 색 · 도형은 그대로
import os
import sys
from PIL import ImageFont
from pptx import Presentation
from pptx.util import Pt
from pptx.enum.shapes import MSO_SHAPE, MSO_SHAPE_TYPE
from pptx.oxml.ns import qn

E = 914400
LH = 1.33                                          # 맑은 고딕 한 줄 높이 (글자 크기 배)
FD = "/mnt/c/Windows/Fonts" if os.path.isdir("/mnt/c/Windows/Fonts") else "C:/Windows/Fonts"
_F = {}


def font(bold):
    k = bool(bold)
    if k not in _F:
        _F[k] = ImageFont.truetype(os.path.join(FD, "malgunbd.ttf" if k else "malgun.ttf"), 100)
    return _F[k]


def runs(tf):
    return [r for p in tf.paragraphs for r in p.runs]


def fits(sh, scale, sx=1.0, sy=1.0, right=9.38):
    """글자를 scale 배로 키워도 도형 안에 들어가는지 (맑은 고딕 폭, 공백 단위 줄바꿈)"""
    tf = sh.text_frame
    w, h = sh.width * sx / E, sh.height * sy / E
    m = lambda v, d: (v if v is not None else d) / E
    ml, mr, mt, mb = m(tf.margin_left, 91440), m(tf.margin_right, 91440), m(tf.margin_top, 45720), m(tf.margin_bottom, 45720)
    try:
        kind = sh.auto_shape_type
    except Exception:
        kind = None
    avail = (w * 0.74 if kind == MSO_SHAPE.OVAL else w) - ml - mr
    avail = min(avail, right - sh.left * sx / E - ml)
    tot = 0.0
    for p in tf.paragraphs:
        rs = p.runs
        if not rs:
            tot += 6 / 72 * LH
            continue
        pt = max((r.font.size.pt if r.font.size else 18) for r in rs) * scale
        f = font(any(r.font.bold for r in rs))
        lines, cur = 1, 0.0
        for wd in "".join(r.text for r in rs).split(" "):
            ww = f.getlength(wd + " ") / 100 * pt / 72
            if ww > avail + 0.01:
                return False
            if cur + ww > avail + 0.01 and cur > 0:
                lines += 1
                cur = ww
            else:
                cur += ww
        tot += lines * pt / 72 * LH
    room = (h * 0.8 if kind == MSO_SHAPE.OVAL else h - mt - mb)
    return tot <= room + 0.02


def set_size(sh, pt):
    for r in runs(sh.text_frame):
        r.font.size = Pt(pt)


def scale_size(sh, k):
    for r in runs(sh.text_frame):
        if r.font.size:
            r.font.size = Pt(round(r.font.size.pt * k * 4) / 4)


# ---------------------------------------------------------------- 1) 목차
TOC = [  # (번호, 제목, 설명)
    ("01", "프로젝트 개요", "요약 · 목적 · 스펙 · 보드 IO · UART 명령표"),
    ("02", "시스템 구조", "Top 블록 다이어그램 · 명령별 흐름 · UART 동작  — 이종혁 · 정안성"),
    ("03", "Top · 모듈 검증", "Top 시뮬레이션 파형 · UART sender 설계 · TB  — 정안성 · 정보윤"),
    ("04", "트러블 슈팅", "센서 오류 표시 (B-2 · B-3) · TB 가 찾은 결함 8 건  — 정보윤"),
    ("05", "시연 영상", "보드 동작  — 정보윤"),
    ("06", "결론 · 고찰", "목표 달성 수치 · 남은 과제  — 정보윤"),
    ("+", "부록", "UART · Top 파형 상세 · DHT11 모듈 설계 · 검증"),
]


def set_text_keep(sh, t):
    """첫 run 서식 그대로 글자만 바꿈 (나머지 run · 문단 지움)"""
    tf = sh.text_frame
    ps = tf.paragraphs
    r0 = ps[0].runs[0]
    for r in ps[0].runs[1:]:
        r._r.getparent().remove(r._r)
    for p in ps[1:]:
        p._p.getparent().remove(p._p)
    r0.text = t


def fix_toc(s):
    rows = {}
    for sh in s.shapes:
        if not sh.has_text_frame or not sh.text_frame.text.strip():
            continue
        x, y = sh.left / E, sh.top / E
        if abs(x - 4.30) < 0.05 and sh.text_frame.text.strip()[:2].isdigit():
            rows.setdefault(round(y, 1), {})["no"] = sh
    order = sorted(rows)
    for sh in s.shapes:                         # 같은 줄의 제목 · 설명 찾기 (번호 y 기준)
        if not sh.has_text_frame or abs(sh.left / E - 5.00) > 0.05:
            continue
        for ky in order:
            dy = sh.top / E - ky
            if -0.1 < dy < 0.15:
                rows[ky]["title"] = sh
            elif 0.2 < dy < 0.4:
                rows[ky]["sub"] = sh
    assert len(order) == len(TOC), f"목차 줄 {len(order)} 개"
    for ky, (no, title, sub) in zip(order, TOC):
        r = rows[ky]
        set_text_keep(r["no"], no)
        set_text_keep(r["title"], title)
        set_text_keep(r["sub"], sub)
        if not fits(r["sub"], 1.0, right=9.6):
            for pt in (8.5, 8, 7.5):
                set_size(r["sub"], pt)
                if fits(r["sub"], 1.0, right=9.6):
                    break


# ---------------------------------------------------------------- 2) 줄어든 장 글자 맞추기
HDR = "WTS · SR04 · DHT11 · UART"


class Item:
    """글자 도형 하나 (그룹 안이면 실제 슬라이드 좌표로 바꿔 둠)"""

    def __init__(self, sh, gx=0.0, gy=0.0, sx=1.0, sy=1.0, cx=0.0, cy=0.0):
        self.sh = sh
        self.x = (gx + (sh.left - cx) * sx) / E
        self.y = (gy + (sh.top - cy) * sy) / E
        self.w, self.h = sh.width * sx / E, sh.height * sy / E
        self.sx = sx
        tf = sh.text_frame
        m = lambda v, d: (v if v is not None else d) * sx / E
        self.ml, self.mr = m(tf.margin_left, 91440), m(tf.margin_right, 91440)
        self.mt, self.mb = m(tf.margin_top, 45720), m(tf.margin_bottom, 45720)
        try:
            self.kind = sh.auto_shape_type
        except Exception:
            self.kind = None
        self.auto = sh.shape_type == MSO_SHAPE_TYPE.AUTO_SHAPE
        self.k = 1.0

    def layout(self, k):
        """k 배일 때 (줄 수, 가장 긴 줄 폭, 전체 높이) — 한 단어가 칸보다 길면 None"""
        tf = self.sh.text_frame
        avail = (self.w * 0.74 if self.kind == MSO_SHAPE.OVAL else self.w) - self.ml - self.mr
        if k > 1:
            avail *= 0.88                                      # 키울 때는 폭 여유 (글꼴 · 렌더러 차이)
        n, wmax, tot = 0, 0.0, 0.0
        for p in tf.paragraphs:
            rs = p.runs
            if not rs:
                tot += 6 / 72 * LH
                continue
            pt = max((r.font.size.pt if r.font.size else 18) for r in rs) * k
            f = font(any(r.font.bold for r in rs))
            lines, cur = 1, 0.0
            for wd in "".join(r.text for r in rs).split(" "):
                ww = f.getlength(wd + " ") / 100 * pt / 72
                if ww > avail + 0.01:
                    return None
                if cur + ww > avail + 0.01 and cur > 0:
                    wmax = max(wmax, cur)
                    lines += 1
                    cur = ww
                else:
                    cur += ww
            wmax = max(wmax, cur)
            n += lines
            tot += lines * pt / 72 * LH
        return n, wmax, tot

    def rect(self, k):
        lay = self.layout(k)
        if lay is None:
            return None
        _, wmax, tot = lay
        p0 = self.sh.text_frame.paragraphs[0]
        al = p0.alignment
        al = int(al) if al is not None else (2 if self.auto else 1)          # 1 왼 · 2 가운데 · 3 오른
        a = self.sh.text_frame.vertical_anchor
        a = int(a) if a is not None else (3 if self.auto else 1)             # 1 위 · 3 가운데 · 4 아래
        x0, x1 = self.x + self.ml, self.x + self.w - self.mr
        rx = x0 if al == 1 else (x1 - wmax if al == 3 else (x0 + x1 - wmax) / 2)
        y0, y1 = self.y + self.mt, self.y + self.h - self.mb
        ry = y0 if a == 1 else (y1 - tot if a == 4 else (y0 + y1 - tot) / 2)
        return rx, ry, rx + wmax, ry + tot


def overlap(a, b, tol=0.01):
    return not (a[2] <= b[0] + tol or b[2] <= a[0] + tol or a[3] <= b[1] + tol or b[3] <= a[1] + tol)


def collect(shapes, out, gx=0.0, gy=0.0, sx=1.0, sy=1.0, cx=0.0, cy=0.0):
    for sh in shapes:
        if sh.shape_type == MSO_SHAPE_TYPE.GROUP:
            x = sh._element.grpSpPr.find(qn("a:xfrm"))
            off, ext = x.find(qn("a:off")), x.find(qn("a:ext"))
            co, ce = x.find(qn("a:chOff")), x.find(qn("a:chExt"))
            ksx = int(ext.get("cx")) / max(1, int(ce.get("cx")))
            ksy = int(ext.get("cy")) / max(1, int(ce.get("cy")))
            ngx = gx + (int(off.get("x")) - cx) * sx
            ngy = gy + (int(off.get("y")) - cy) * sy
            collect(sh.shapes, out, ngx, ngy, sx * ksx, sy * ksy, int(co.get("x")), int(co.get("y")))
            continue
        if visible_box(sh):
            bx = ((gx + (sh.left - cx) * sx) / E, (gy + (sh.top - cy) * sy) / E)
            out.append(("box", (bx[0], bx[1], bx[0] + sh.width * sx / E, bx[1] + sh.height * sy / E), sh))
        if sh.shape_type == MSO_SHAPE_TYPE.TABLE or not (sh.has_text_frame and sh.text_frame.text.strip()):
            if sh.shape_type == MSO_SHAPE_TYPE.TABLE:
                out.append(("table", sh))
            continue
        out.append(("text", Item(sh, gx, gy, sx, sy, cx, cy)))


def visible_box(sh):
    """테두리 · 채움이 보이는 도형, 그림, 표 → 글자가 넘어가면 안 되는 칸"""
    if sh.shape_type in (MSO_SHAPE_TYPE.PICTURE, MSO_SHAPE_TYPE.TABLE):
        return True
    if sh.shape_type != MSO_SHAPE_TYPE.AUTO_SHAPE:
        return False
    sp = sh._element.find(qn("p:spPr"))
    if sp is None:
        return False
    fill = any(sp.find(qn(t)) is not None for t in ("a:solidFill", "a:gradFill", "a:blipFill", "a:pattFill"))
    ln = sp.find(qn("a:ln"))
    line = ln is not None and ln.find(qn("a:noFill")) is None
    if sp.find(qn("a:noFill")) is not None and not line:
        return False
    if fill or line:
        return True
    return sh._element.find(qn("p:style")) is not None and (ln is None or ln.find(qn("a:noFill")) is None)


def inside(a, b, tol=0.0):
    return a[0] >= b[0] - tol and a[1] >= b[1] - tol and a[2] <= b[2] + tol and a[3] <= b[3] + tol


def blocked(new, old, me, texts, rects, boxes):
    """키운 글자 칸 new 가 원래 (old) 에 없던 겹침을 만드는지"""
    for o in texts:
        if o is not me and rects[id(o)] is not None and overlap(new, rects[id(o)]) and not overlap(old, rects[id(o)]):
            return True
    for b, sh in boxes:
        if sh is me.sh:
            continue
        if inside(old, b, 0.05):                           # 담고 있던 칸 → 밖으로 나가면 안 됨 (안쪽 여유 0.02 in)
            if not inside(new, b, -0.02):
                return True
        elif overlap(new, b) and not overlap(old, b):     # 떨어져 있던 칸 → 새로 닿으면 안 됨
            return True
    return False


def normalize(s):
    st = {"title": None, "body": 0, "body_all": 0, "tbl": 0}
    items = []
    collect(s.shapes, items)
    texts = [it for kind, it, *_ in items if kind == "text"]
    boxes = [(b, sh) for kind, b, *rest in items if kind == "box" for sh in rest]
    rects = {id(it): it.rect(1.0) for it in texts}
    body = []
    for it in texts:
        sh, t = it.sh, it.sh.text_frame.text.strip()
        if it.sx == 1.0 and t == HDR and it.y < 0.2:
            set_size(sh, 7)
        elif it.sx == 1.0 and it.y < 0.3 and it.x < 1.0 and len(t) < 60:          # 머리말
            set_size(sh, 8)
        elif it.sx == 1.0 and 0.3 <= it.y < 0.6 and it.w > 6:                     # 제목 (한 줄, 폭만 봄)
            cur = runs(sh.text_frame)[0].font.size.pt
            old = rects[id(it)]
            for pt in (20, 19, 18, 17, 16):
                if pt <= cur:
                    break
                lay = it.layout(pt / cur)
                r = it.rect(pt / cur)
                if lay and lay[0] == 1 and r[2] <= 9.62 and not blocked(r, old, it, texts, rects, boxes):
                    set_size(sh, pt)
                    st["title"] = pt
                    break
        elif it.sx == 1.0 and it.y > 5.2 and it.x > 8.8 and t.isdigit():         # 쪽 번호
            set_size(sh, 7)
        else:
            rs = [r for r in runs(sh.text_frame) if r.font.size]
            if rs and max(r.font.size.pt for r in rs) < 12:
                body.append(it)
    for it in body:
        st["body_all"] += 1
        base = it.layout(1.0)
        if base is None:
            continue
        for k in (1.4, 1.3, 1.2, 1.1):
            lay = it.layout(k)
            if lay is None or lay[0] > base[0]:                       # 원래보다 줄 수가 늘면 안 됨
                continue
            r = it.rect(k)
            if lay[2] > it.h - it.mt - it.mb + 0.02 and visible_box(it.sh):   # 테두리 있는 칸 높이 (글상자는 겹침 검사로)
                continue
            if it.kind == MSO_SHAPE.OVAL and lay[2] > it.h * 0.8:
                continue
            if r[2] > 9.62:                                           # 슬라이드 오른쪽 끝
                continue
            if blocked(r, rects[id(it)], it, texts, rects, boxes):   # 원래 없던 겹침 · 칸 밖으로 나감
                continue
            scale_size(it.sh, k)
            rects[id(it)] = r
            st["body"] += 1
            break
    for kind, gf, *_ in items:
        if kind == "table":
            grow_table(gf, st)
    return st


def grow_table(gf, st, k=1.25):
    tb = gf.table
    cells = [(c, row.height / E) for row in tb.rows for c in row.cells]
    for c, rh in cells:
        for p in c.text_frame.paragraphs:
            for r in p.runs:
                if r.font.size and r.font.size.pt * k / 72 * 1.25 + 0.05 > rh:
                    return
    widths = [col.width / E for col in tb.columns]
    for ri, row in enumerate(tb.rows):
        for ci, c in enumerate(row.cells):
            rs = runs(c.text_frame)
            if not rs or not rs[0].font.size:
                continue
            pt = rs[0].font.size.pt * k
            wd = font(any(r.font.bold for r in rs)).getlength(c.text_frame.text) / 100 * pt / 72
            if wd > widths[ci] - 0.1:
                return
    for c, _ in cells:
        for r in runs(c.text_frame):
            if r.font.size and r.font.size.pt < 12:
                r.font.size = Pt(round(r.font.size.pt * k * 4) / 4)
    st["tbl"] += 1


def main(src, out):
    prs = Presentation(src)
    fix_toc(prs.slides[1])
    print("목차 고침")
    for i, s in enumerate(prs.slides, 1):
        if any(sh.has_text_frame and sh.text_frame.text.strip() == HDR for sh in s.shapes):
            st = normalize(s)
            print(f"slide {i:2} : 제목 {st['title']} pt · 본문 {st['body']} / {st['body_all']} 키움 · 표 {st['tbl']}")
    prs.save(out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else sys.argv[1])
