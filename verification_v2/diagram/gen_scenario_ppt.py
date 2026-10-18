"""Build watch_scenario_slides.pptx from watch_verification.pptx's package (theme/master/blank layout).
usage: python3 -I gen_scenario_ppt.py <watch_verification.pptx 압축 푼 폴더> <출력 폴더>  → 출력 폴더를 zip 해서 .pptx"""
import os, re, shutil, sys
from xml.sax.saxutils import escape

SRC, OUT = sys.argv[1], sys.argv[2]
EMU = 914400
def E(inch): return int(round(inch * EMU))

NS = ('xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"')


class Slide:
    def __init__(self):
        self.parts, self.nid = [], 2

    def _id(self):
        self.nid += 1
        return self.nid

    @staticmethod
    def _run(text, sz, bold=False, color="000000"):
        b = ' b="1"' if bold else ""
        return (f'<a:r><a:rPr lang="ko-KR" altLang="en-US" sz="{sz}"{b} dirty="0">'
                f'<a:solidFill><a:srgbClr val="{color}"/></a:solidFill></a:rPr>'
                f'<a:t>{escape(text)}</a:t></a:r>')

    def text(self, x, y, w, h, paras, sz=1400, bold=False, color="000000", align="l", anchor="t",
             bullet=False, name="TextBox", space_after=0):
        """paras: list of str or list of (text, bold, color) runs."""
        ps = []
        for p in paras:
            runs = [(p, bold, color)] if isinstance(p, str) else p
            ppr = f'<a:pPr algn="{align}"'
            if bullet:
                ppr += ' marL="285750" indent="-285750"'
            ppr += '>'
            if space_after:
                ppr += f'<a:spcAft><a:spcPts val="{space_after}"/></a:spcAft>'
            ppr += '<a:buFont typeface="Arial"/><a:buChar char="&#8226;"/>' if bullet else '<a:buNone/>'
            ppr += '</a:pPr>'
            ps.append('<a:p>' + ppr + ''.join(self._run(t, sz, b, c) for t, b, c in runs) + '</a:p>')
        i = self._id()
        self.parts.append(
            f'<p:sp><p:nvSpPr><p:cNvPr id="{i}" name="{name} {i}"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>'
            f'<p:spPr><a:xfrm><a:off x="{E(x)}" y="{E(y)}"/><a:ext cx="{E(w)}" cy="{E(h)}"/></a:xfrm>'
            f'<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/></p:spPr>'
            f'<p:txBody><a:bodyPr wrap="square" lIns="0" tIns="0" rIns="0" bIns="0" rtlCol="0" anchor="{anchor}">'
            f'<a:noAutofit/></a:bodyPr><a:lstStyle/>{"".join(ps)}</p:txBody></p:sp>')

    def rect(self, x, y, w, h, fill=None, line=None, line_w=1.0, dash=None, name="Rect", paras=None,
             sz=1400, color="7F7F7F", bold=False):
        i = self._id()
        f = f'<a:solidFill><a:srgbClr val="{fill}"/></a:solidFill>' if fill else '<a:noFill/>'
        if line:
            d = f'<a:prstDash val="{dash}"/>' if dash else ''
            ln = f'<a:ln w="{int(line_w * 12700)}"><a:solidFill><a:srgbClr val="{line}"/></a:solidFill>{d}</a:ln>'
        else:
            ln = '<a:ln><a:noFill/></a:ln>'
        body = ''
        if paras:
            body = ''.join('<a:p><a:pPr algn="ctr"><a:buNone/></a:pPr>' + self._run(p, sz, bold, color) + '</a:p>'
                           for p in paras)
        else:
            body = '<a:p><a:endParaRPr lang="ko-KR"/></a:p>'
        self.parts.append(
            f'<p:sp><p:nvSpPr><p:cNvPr id="{i}" name="{name} {i}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>'
            f'<p:spPr><a:xfrm><a:off x="{E(x)}" y="{E(y)}"/><a:ext cx="{E(w)}" cy="{E(h)}"/></a:xfrm>'
            f'<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>{f}{ln}</p:spPr>'
            f'<p:txBody><a:bodyPr rtlCol="0" anchor="ctr"/><a:lstStyle/>{body}</p:txBody></p:sp>')

    def table(self, x, y, col_w, row_h, rows, head_fill="CFD5EA", fills=("E9EBF5", "CFD5EA"), sz=1400):
        i = self._id()
        grid = ''.join(f'<a:gridCol w="{E(w)}"/>' for w in col_w)
        trs = []
        for r, row in enumerate(rows):
            fill = head_fill if r == 0 else fills[(r - 1) % 2]
            tcs = []
            for c, cell in enumerate(row):
                bold = (r == 0)
                tcs.append(
                    f'<a:tc><a:txBody><a:bodyPr/><a:lstStyle/><a:p><a:pPr algn="ctr"/>'
                    f'{self._run(cell, sz, bold, "000000")}</a:p></a:txBody>'
                    f'<a:tcPr marL="45720" marR="45720" marT="22860" marB="22860" anchor="ctr">'
                    f'<a:lnL w="12700"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill></a:lnL>'
                    f'<a:lnR w="12700"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill></a:lnR>'
                    f'<a:lnT w="12700"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill></a:lnT>'
                    f'<a:lnB w="12700"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill></a:lnB>'
                    f'<a:solidFill><a:srgbClr val="{fill}"/></a:solidFill></a:tcPr></a:tc>')
            trs.append(f'<a:tr h="{E(row_h)}">' + ''.join(tcs) + '</a:tr>')
        self.parts.append(
            f'<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="{i}" name="Table {i}"/>'
            f'<p:cNvGraphicFramePr><a:graphicFrameLocks noGrp="1"/></p:cNvGraphicFramePr><p:nvPr/></p:nvGraphicFramePr>'
            f'<p:xfrm><a:off x="{E(x)}" y="{E(y)}"/><a:ext cx="{E(sum(col_w))}" cy="{E(row_h * len(rows))}"/></p:xfrm>'
            f'<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">'
            f'<a:tbl><a:tblPr firstRow="1" bandRow="1"/><a:tblGrid>{grid}</a:tblGrid>{"".join(trs)}</a:tbl>'
            f'</a:graphicData></a:graphic></p:graphicFrame>')

    def xml(self, hidden=False):
        show = ' show="0"' if hidden else ''
        return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
                f'<p:sld {NS}{show}><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/>'
                '</p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/>'
                '<a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>' + ''.join(self.parts) +
                '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>')


RED, GRAY = "C00000", "7F7F7F"

SCEN = [
    dict(n=1, name="리셋 뒤 커서 FSM — R · L · U · D", tb="tb_wt_s1_cursor_fsm", span="0 ~ 190 ms", mk="1 ~ 7",
         fig="cursor FSM after reset",
         bullets=["set_sw2 = 0 : R · L · U · D tick 이 와도 NORMAL 유지",
                  "set_sw2 = 1 : SET_MIN_1 진입 → L 왼쪽 회전 / R 오른쪽 회전",
                  "U · D : 상태 그대로 (자기 루프), 커서 자리 값만 ±1",
                  "set_sw2 = 0 : NORMAL 복귀"],
         table=[["1", "rst (1 us)", "리셋 상태", "NORMAL, cursor 3, 12:00"],
                ["2", "set_sw2 = 0, R → L → U → D", "설정 OFF 버튼 무시", "tick 4 개, NORMAL 유지"],
                ["3", "set_sw2 = 1", "설정 진입", "NORMAL → SET_MIN_1"],
                ["4", "L × 3", "커서 왼쪽 이동 · 회전", "MIN_1 → MIN_10 → HOUR → MIN_1"],
                ["5", "R × 3", "커서 오른쪽 이동 · 회전", "MIN_1 → HOUR → MIN_10 → MIN_1"],
                ["6", "U → D", "상태 유지 (자기 루프)", "SET_MIN_1 유지, 분 00 → 01 → 00"],
                ["7", "set_sw2 = 0", "설정 종료", "SET_MIN_1 → NORMAL"]]),
    dict(n=2, name="R · L · U · D 동시 입력", tb="tb_wt_s2_btn_simul", span="0 ~ 50 ms", mk="1 ~ 5",
         fig="simultaneous button input",
         bullets=["버튼을 같은 순간에 눌러 tick 이 같은 클럭에 겹치게 함",
                  "L + R → L 우선 (SET_MIN_1 → SET_MIN_10)",
                  "U + D → 무효 (o_wt_up · o_wt_down 모두 0)",
                  "L + U → 이동 + 분 +10 같은 클럭 / 4 개 동시 → L 이동만"],
         table=[["1", "rst, set_sw2 = 1", "설정 진입", "SET_MIN_1, 12:00"],
                ["2", "L + R 동시", "L 우선", "SET_MIN_1 → SET_MIN_10"],
                ["3", "U + D 동시", "± 무효", "up · down 0, 12:00 유지"],
                ["4", "L + U 동시", "이동 + 증가 같은 클럭", "SET_HOUR, 12:10"],
                ["5", "R + L + U + D 동시", "L 우선 + ± 무효", "SET_MIN_1, 12:10 유지"]]),
    dict(n=3, name="1 초 = 실제 1 초", tb="tb_wt_s3_one_sec", span="0 ~ 2.05 s", mk="1 ~ 4",
         fig="1 s accuracy after reset",
         bullets=["리셋 뒤 버튼 · 프리로드 없이 대기 (시계는 항상 흐름)",
                  "o_tick_10ms : 10 ms 마다 1 펄스 (100 MHz × 1,000,000)",
                  "tick 100 개 → o_wt_msec 99 → 00, o_wt_sec +1",
                  "마커 3 → 4 간격 = 1.000000000 s"],
         table=[["1", "rst 해제", "시계 시작", "12:00:00.00"],
                ["2", "대기", "o_tick_10ms 간격", "10 ms"],
                ["3", "대기", "1/100 초 99 → 00", "1 s 뒤 초 0 → 1"],
                ["4", "대기", "초 1 → 2 간격", "1,000,000,000 ns"]]),
    dict(n=4, name="경계값 — 분 00 ↔ 59 (U · D)", tb="tb_wt_s4_min_boundary", span="0 ~ 50 ms", mk="1 ~ 5",
         fig="minute boundary 00 ↔ 59",
         bullets=["리셋값 12:00, 커서 = 분 일의 자리 (SET_MIN_1)",
                  "보통 : U → 12:01, D → 12:00",
                  "경계 : D → 12:59, U → 12:00",
                  "o_wt_hour 12 고정, min_carry 없음 → 올림 · 내림 없음"],
         table=[["1", "rst, set_sw2 = 1", "분 일의 자리 선택", "SET_MIN_1, 12:00"],
                ["2", "U", "보통 증가", "12:01"],
                ["3", "D", "보통 감소", "12:00"],
                ["4", "D", "경계 아래로 (내림 없음)", "12:59 (시 12 그대로)"],
                ["5", "U", "경계 위로 (올림 없음)", "12:00 (시 12 그대로)"]]),
    dict(n=5, name="FND 점멸 — 설정 중 커서 자리", tb="tb_wt_s5_fnd_blink", span="0 ~ 4 s", mk="1 ~ 4",
         fig="FND blink in set mode",
         bullets=["시.분 화면 · 설정 중 o_wt_msec ≥ 50 이면 커서 자리만 빈칸 (0.5 s)",
                  "커서 0 → 1 → 2 : AN0 → AN1 → AN2 점멸",
                  "\"12.0_\" → \"12._0\" → \"1_.00\"",
                  "set_sw2 = 0 → 점멸 해제, \"12.00\" 고정"],
         table=[["1", "rst, sw1 = 1, set_sw2 = 1", "커서 0 점멸", "AN0 빈칸 \"12.0_\""],
                ["2", "L", "커서 1 점멸", "AN1 빈칸 \"12._0\""],
                ["3", "L", "커서 2 점멸", "AN2 빈칸 \"1_.00\""],
                ["4", "set_sw2 = 0", "점멸 해제", "\"12.00\" 고정"]]),
]


def header(s, sub):
    s.rect(0.4, 0.25, 12.53, 0.1, fill=RED, name="Top band")
    s.text(0.5, 0.45, 8.6, 0.55, ["3. Watch 시뮬레이션"], sz=2800, bold=True, name="Title")
    s.text(0.5, 1.02, 12.3, 0.4, [sub], sz=1800, bold=True, color=GRAY, name="Subtitle")


def scenario_slide(c):
    s = Slide()
    header(s, f"시나리오 {c['n']} : '{c['name']}'")
    s.text(8.8, 0.55, 4.13, 0.4, [f"{c['tb']}.sv"], sz=1000, color=GRAY, align="r", name="TB name")
    s.text(0.6, 1.55, 12.2, 1.0, c["bullets"], sz=1400, bullet=True, name="Wave notes")
    s.rect(0.5, 2.65, 12.33, 4.1, fill="F2F2F2", line="A6A6A6", line_w=1.25, dash="dash", name="Waveform",
           paras=["파형 캡처 붙여넣기",
                  f"{c['tb']}_behav.wcfg · 전체 줌 {c['span']} · 마커 {c['mk']} = 표 순서",
                  "번호 박스 · 화살표 주석은 체크 레퍼런스 받은 뒤 추가"], sz=1400)
    s.text(0.5, 6.85, 12.33, 0.3, [f"Figure {c['n']}. Waveform result of {c['fig']}"], sz=1100, color=RED,
           align="ctr", name="Caption")
    return s.xml()


# 시뮬레이션 시나리오 통합 표 (5 개 시나리오 = 5 행, Image #1 양식) — 시나리오 슬라이드 앞 첫 장
OVERVIEW = [["1", "set_sw2 = 1 → L × 3 · R × 3 · U · D", "커서 FSM 상태 천이", "NORMAL → SET_MIN_1 → 회전"],
            ["2", "L+R · U+D · L+U · R+L+U+D 동시", "동시 입력 동작", "L 우선, U+D 무효"],
            ["3", "rst 후 대기 (2 s)", "1 초 정확도", "초 간격 = 1,000,000,000 ns"],
            ["4", "SET_MIN_1 에서 U · D (분 00)", "경계값 분 00 ↔ 59", "12:59 ↔ 12:00, 시 12 유지"],
            ["5", "시.분 화면, set_sw2 = 1, L × 2", "FND 점멸", "커서 자리 0.5 s 빈칸"]]


def overview_slide():
    s = Slide()
    header(s, "시뮬레이션 시나리오")
    cw = [0.9, 4.4, 3.0, 4.0]
    x0, ty, rh = 0.5 + (12.33 - sum(cw)) / 2, 2.7, 0.62
    rows = [["순서", "입력/동작", "확인 내용", "예상 결과"]] + OVERVIEW
    s.table(x0, ty, cw, rh, rows, sz=1600)
    bottom = ty + rh * len(rows) + 0.08
    top = 1.6
    xs = [x0 + cw[0], x0 + cw[0] + cw[1], x0 + cw[0] + cw[1] + cw[2]]
    for x, w, col, lab in [(xs[0], cw[1], "FFC000", ["Input Stimulus", "OP Check"]),
                           (xs[1], cw[2], RED, ["Checklist"]),
                           (xs[2], cw[3], "00B050", ["Expectation"])]:
        s.rect(x + 0.04, top, w - 0.08, bottom - top, line=col, line_w=3, name="Group box")
        s.text(x + 0.04, top + 0.05, w - 0.08, 0.95, lab, sz=2200 if len(lab) > 1 else 2600, bold=True,
               align="ctr", anchor="ctr", name="Group label")
    return s.xml()


# ------------------------------------------------------------------ package
if os.path.exists(OUT):
    shutil.rmtree(OUT)
shutil.copytree(SRC, OUT)
for d in ("ppt/slides", "ppt/notesSlides"):
    shutil.rmtree(os.path.join(OUT, d), ignore_errors=True)
os.makedirs(os.path.join(OUT, "ppt/slides/_rels"))

slides = [overview_slide()] + [scenario_slide(c) for c in SCEN]
REL = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
       '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
       '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" '
       'Target="../slideLayouts/slideLayout7.xml"/></Relationships>')
for k, x in enumerate(slides, 1):
    with open(f"{OUT}/ppt/slides/slide{k}.xml", "w", encoding="utf-8") as f:
        f.write(x)
    with open(f"{OUT}/ppt/slides/_rels/slide{k}.xml.rels", "w", encoding="utf-8") as f:
        f.write(REL)

# content types
ct_p = f"{OUT}/[Content_Types].xml"
ct = open(ct_p, encoding="utf-8").read()
ct = re.sub(r'<Override PartName="/ppt/(slides|notesSlides)/[^"]+"[^>]*/>', "", ct)
ov = "".join(f'<Override PartName="/ppt/slides/slide{k}.xml" '
             'ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>'
             for k in range(1, len(slides) + 1))
ct = ct.replace("</Types>", ov + "</Types>")
open(ct_p, "w", encoding="utf-8").write(ct)

# presentation rels
pr_p = f"{OUT}/ppt/_rels/presentation.xml.rels"
pr = open(pr_p, encoding="utf-8").read()
pr = re.sub(r'<Relationship [^>]*Type="[^"]*/relationships/slide"[^>]*/>', "", pr)
nr = "".join(f'<Relationship Id="rIdS{k}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" '
             f'Target="slides/slide{k}.xml"/>' for k in range(1, len(slides) + 1))
pr = pr.replace("</Relationships>", nr + "</Relationships>")
open(pr_p, "w", encoding="utf-8").write(pr)

# presentation sldIdLst
p_p = f"{OUT}/ppt/presentation.xml"
p = open(p_p, encoding="utf-8").read()
ids = "".join(f'<p:sldId id="{300 + k}" r:id="rIdS{k}"/>' for k in range(1, len(slides) + 1))
p = re.sub(r"<p:sldIdLst>.*?</p:sldIdLst>", f"<p:sldIdLst>{ids}</p:sldIdLst>", p, flags=re.S)
p = re.sub(r"<p:sectionLst.*?</p:sectionLst>", "", p, flags=re.S)
open(p_p, "w", encoding="utf-8").write(p)
print("slides:", len(slides))
