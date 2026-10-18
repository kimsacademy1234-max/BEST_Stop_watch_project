#!/usr/bin/env python3
"""발표용 Top 블럭 다이어그램 슬라이드 갱신 (ahnsung/stopwatch_watch.pptx 3 쪽).

- 10/17 팀 결정 ④ 반영: 기능별 100 Hz tick (U_TICK_GEN_100HZ 시계 · U_TICK_GEN_SW · U_TICK_GEN_TM)
  + 4 kHz 공용 (U_CLK_GEN_4KHZ → 디바운서 · FND 스캔)
- 기존 슬라이드와 같은 도형 어휘 (homePlate 태그 · roundRect 블록 · line 화살표 · 색 범례)
- 제목 · 섹션 placeholder 와 쪽 번호는 그대로 두고, 그 사이 도형만 다시 만든다

실행: python3 gen_top_slide.py [pptx 경로]   (기본: ../../ahnsung/stopwatch_watch.pptx, 제자리 갱신)
"""
import os
import re
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
PPTX = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "ahnsung", "stopwatch_watch.pptx")
SLIDE = "ppt/slides/slide3.xml"
EMU = 914400

DARK, TXT, MUTED, RED = "2E3B44", "1B2228", "6B7A85", "C8323C"
TICK = "6741D9"   # 100 Hz tick · 4 kHz (보라)
CAT = {   # (채움, 테두리)
    "ctrl": ("FFF2DC", "E08A00"), "dp": ("E3F3F1", "0F7C73"), "tick": ("EFEAFB", TICK),
    "disp": ("FCE6E7", RED), "common": ("EEF1F4", "5B6B76"),
}
MONO = ('<a:latin typeface="Consolas" pitchFamily="34" charset="0"/>'
        '<a:ea typeface="Consolas" pitchFamily="34" charset="-122"/>'
        '<a:cs typeface="Consolas" pitchFamily="34" charset="-120"/>')

shapes = []


def e(v):
    return int(round(v * EMU))


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _sp(name, x, y, w, h, geom, sppr, paras=None, body='lIns="0" tIns="0" rIns="0" bIns="0"', algn=None, txbox=True):
    sid = len(shapes) + 4
    xml = (f'<p:sp><p:nvSpPr><p:cNvPr id="{sid}" name="{name}_{sid}"></p:cNvPr><p:cNvSpPr{" txBox=\"1\"" if txbox else ""}/>'
           f'<p:nvPr></p:nvPr></p:nvSpPr><p:spPr>{geom_xfrm(x, y, w, h)}{geom}{sppr}</p:spPr>')
    if paras is not None:
        xml += f'<p:txBody><a:bodyPr wrap="square" {body} rtlCol="0" anchor="ctr"></a:bodyPr><a:lstStyle/>'
        for runs in paras:
            ppr = f'<a:pPr{f" algn=\"{algn}\"" if algn else ""} indent="0" marL="0"><a:buNone/></a:pPr>'
            rs = ""
            for t, sz, b, col, mono in runs:
                rs += (f'<a:r><a:rPr lang="en-US" sz="{sz}"{" b=\"1\"" if b else ""} dirty="0"><a:solidFill>'
                       f'<a:srgbClr val="{col}"/></a:solidFill>{MONO if mono else ""}</a:rPr><a:t>{esc(t)}</a:t></a:r>')
            xml += f'<a:p>{ppr}{rs}<a:endParaRPr lang="en-US" sz="{runs[0][1]}" dirty="0"/></a:p>'
        xml += '</p:txBody>'
    shapes.append(xml + '</p:sp>')


def geom_xfrm(x, y, w, h, flip=""):
    return f'<a:xfrm{flip}><a:off x="{e(x)}" y="{e(y)}"/><a:ext cx="{e(w)}" cy="{e(h)}"/></a:xfrm>'


def solid(fill, line, lw=15875):
    return (f'<a:solidFill><a:srgbClr val="{fill}"/></a:solidFill>'
            f'<a:ln w="{lw}"><a:solidFill><a:srgbClr val="{line}"/></a:solidFill></a:ln>')


def para(*runs):
    """runs: (text, sz, bold, color, mono)"""
    return list(runs)


def block(cat, x, y, w, h, title, inst, lines=(), tsz=900):
    fill, line = CAT[cat]
    paras = [para((title, tsz, True, TXT, False)), para((inst, 600, False, MUTED, True))]
    paras += [para((l, 700, False, DARK, False)) for l in lines]
    _sp("blk", x, y, w, h, '<a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 6000"/></a:avLst></a:prstGeom>',
        solid(fill, line), paras, body='lIns="38100" tIns="38100" rIns="38100" bIns="38100"', algn="ctr")


def tag(x, y, w, text, color=DARK, h=0.24):
    """y = 가운데"""
    _sp("tag", x, y - h / 2, w, h, '<a:prstGeom prst="homePlate"><a:avLst></a:avLst></a:prstGeom>',
        solid(color, color, 9525), [para((text, 800, False, "FFFFFF", True))],
        body='lIns="45720" tIns="0" rIns="25400" bIns="0"', algn="l")


def label(x, y, w, h, lines, sz=700, col=MUTED, mono=True, algn=None, bold=False):
    if isinstance(lines, str):
        lines = [lines]
    _sp("txt", x, y, w, h, '<a:prstGeom prst="rect"><a:avLst></a:avLst></a:prstGeom>', '<a:noFill/><a:ln></a:ln>',
        [para((l, sz, bold, col, mono)) for l in lines], algn=algn)


def wire(x1, y1, x2, y2, col=DARK, lw=15875, arrow=True, dash=None):
    """수평 · 수직 선 하나. 화살표는 (x2, y2) 쪽"""
    flip = (' flipH="1"' if x2 < x1 else "") + (' flipV="1"' if y2 < y1 else "")
    sid = len(shapes) + 4
    ln = (f'<a:ln w="{lw}"><a:solidFill><a:srgbClr val="{col}"/></a:solidFill>'
          f'<a:prstDash val="{dash or "solid"}"/>{"<a:tailEnd type=\"triangle\"/>" if arrow else ""}</a:ln>')
    shapes.append(f'<p:sp><p:nvSpPr><p:cNvPr id="{sid}" name="wire_{sid}"></p:cNvPr><p:cNvSpPr/><p:nvPr></p:nvPr></p:nvSpPr>'
                  f'<p:spPr>{geom_xfrm(min(x1, x2), min(y1, y2), abs(x2 - x1), abs(y2 - y1), flip)}'
                  f'<a:prstGeom prst="line"><a:avLst></a:avLst></a:prstGeom><a:noFill/>{ln}</p:spPr></p:sp>')


def path(pts, **kw):
    """꺾인 선: 마지막 구간에만 화살표"""
    for i in range(len(pts) - 1):
        wire(*pts[i], *pts[i + 1], **{**kw, "arrow": kw.get("arrow", True) and i == len(pts) - 2})


BUS = 25400      # 굵은 선 = 다비트 버스
TK = 22225       # 100 Hz tick 선

# ------------------------------------------------------------------ 열 x (블록 왼쪽 · 오른쪽)
PX0, PX1 = 0.30, 1.05            # 보드 핀 태그
C1, C1R = 1.15, 2.30             # CLK_GEN · 디바운서
G, GR = 2.62, 3.32               # 모드 선택 & 버튼 게이팅
CU, CUR = 3.58, 4.98             # 컨트롤 유닛
TG, TGR = 5.40, 6.70             # 기능별 tick 생성기
DP, DPR = 7.10, 8.50             # 데이터패스
MX, MXR = 8.80, 9.25             # 화면 MUX
FD, FDR = 10.05, 11.55           # FND · LED
OT = 11.68                       # 출력 태그

# ------------------------------------------------------------------ 두괄식 요약
_sp("txt", 0.30, 1.14, 12.6, 0.26, '<a:prstGeom prst="rect"><a:avLst></a:avLst></a:prstGeom>', '<a:noFill/><a:ln></a:ln>',
    [para(("100 Hz tick 기능별 3 개 분리", 1100, True, TICK, False),
          (" — 시계 = 항상 흐름 · 스톱워치 / 타이머 = 시작 순간부터 셈 (첫 1/100 초 최대 10 ms 오차 제거)  ·  4 kHz 는 디바운서 · FND 스캔 공용",
           1000, False, DARK, False))])

# ------------------------------------------------------------------ 클럭 · 4 kHz
Y4K = 1.69
tag(PX0, Y4K, 0.75, "clk  W5")
wire(PX1, Y4K, C1, Y4K)
block("tick", C1, 1.48, 1.40, 0.42, "clock_tick_generator", "U_CLK_GEN_4KHZ", tsz=800)
wire((C1 + C1R) / 2, 1.90, (C1 + C1R) / 2, 2.05, col=TICK, dash="dash")
path([(C1 + 1.40, Y4K), ((FD + FDR) / 2, Y4K), ((FD + FDR) / 2, 2.05)], col=TICK, dash="dash")
label(3.20, 1.50, 3.6, 0.17, "w_clk_4khz — 4 kHz (250 µs 마다 10 ns 펄스)", col=TICK)

# ------------------------------------------------------------------ 버튼 · 디바운서
block("common", C1, 2.05, C1R - C1, 2.00, "btn_debounce ×4", "U_BD_R/L/U/D", ["4 kHz 로 8 번 샘플", "(약 2 ms)", "→ 1 클럭 펄스"], tsz=850)
for k, pin, y in [("R", "T17", 2.30), ("L", "W19", 2.75), ("U", "T18", 3.20), ("D", "U17", 3.65)]:
    tag(PX0, y, 0.75, f"btn{k}  {pin}")
    wire(PX1, y, C1, y)
    wire(C1R, y, G, y)
    label(C1R + 0.03, y - 0.16, 0.30, 0.14, f"btn_{k}", sz=600)

# ------------------------------------------------------------------ 스위치 · 리셋
for s, y in [("SW0 mode", 4.55), ("SW4 timer", 4.95)]:
    tag(PX0, y, 0.92, s)
    wire(PX0 + 0.92, y, G, y)
tag(PX0, 5.75, 0.75, "rst  U18", color=RED)
label(1.15, 5.58, 1.45, 0.36, ["btnC → 모든 순차 모듈", "비동기 리셋"], sz=750, mono=False)

# ------------------------------------------------------------------ 게이팅
_sp("blk", G, 2.05, GR - G, 4.15, '<a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 6000"/></a:avLst></a:prstGeom>',
    solid(*CAT["common"]),
    [para(("모드 선택", 1000, True, TXT, False)), para(("& 버튼", 1000, True, TXT, False)),
     para(("게이팅", 1000, True, TXT, False)), para(("top assign", 650, False, MUTED, True)),
     para(("sel_tm = SW4", 700, False, DARK, False)), para(("sel_sw =", 700, False, DARK, False)),
     para(("~SW4 & SW0", 700, False, DARK, False)), para(("sel_wt =", 700, False, DARK, False)),
     para(("~SW4 & ~SW0", 700, False, DARK, False))],
    body='lIns="25400" tIns="38100" rIns="25400" bIns="38100"', algn="ctr")

# ------------------------------------------------------------------ 스톱워치 줄
block("ctrl", CU, 2.05, CUR - CU, 0.80, "control_unit", "U_STOPWATCH_CONTROL_UNIT", ["STOP · RUN"])
block("tick", TG, 2.05, TGR - TG, 0.50, "tick_gen_100hz_run", "U_TICK_GEN_SW", ["RUN 동안만 셈"], tsz=850)
block("dp", DP, 2.05, DPR - DP, 0.95, "stopwatch_datapath", "U_STOPWATCH_DATAPATH", ["경과 시간 업/다운"])
wire(GR, 2.45, CU, 2.45, lw=BUS)
label(GR + 0.03, 2.27, 0.24, 0.16, "×3", sz=750)
wire(CUR, 2.30, TG, 2.30)
label(CUR + 0.03, 1.94, 0.40, 0.34, ["run_stop", "clear"], sz=600)
wire(TGR, 2.30, DP, 2.30, col=TICK, lw=TK)
label(TGR + 0.03, 2.12, 0.38, 0.16, "sw_tick", sz=600, col=TICK)
wire(CUR, 2.70, DP, 2.70, lw=BUS)
label(TG + 0.05, 2.72, 1.05, 0.15, "clear · down", sz=650)
wire(GR, 2.93, DP, 2.93)
label(CU + 0.03, 2.95, 1.10, 0.15, "btn_D (랩)", sz=650)

# ------------------------------------------------------------------ 시계 줄
block("ctrl", CU, 3.30, CUR - CU, 0.80, "watch_control_unit", "U_WATCH_CONTROL_UNIT", ["NORMAL · 커서 3 자리"])
block("tick", TG, 3.30, TGR - TG, 0.50, "tick_gen_100hz", "U_TICK_GEN_100HZ", ["항상 흐름"], tsz=850)
block("dp", DP, 3.30, DPR - DP, 0.90, "watch_datapath", "U_WATCH_DATAPATH", ["현재 시각 (설정 ± 1)"])
wire(GR, 3.70, CU, 3.70, lw=BUS)
label(GR + 0.03, 3.52, 0.24, 0.16, "×4", sz=750)
wire(TGR, 3.55, DP, 3.55, col=TICK, lw=TK)
label(TGR + 0.03, 3.37, 0.38, 0.16, "wt_tick", sz=600, col=TICK)
wire(CUR, 3.95, DP, 3.95, lw=BUS)
label(TG + 0.05, 3.97, 1.30, 0.15, "cursor[1:0] · up · down", sz=650)
wire(CU + 0.70, 4.32, CU + 0.70, 4.10)
label(CU + 0.22, 4.33, 0.95, 0.17, "SW2 set", sz=750, col=DARK, mono=True, algn="ctr")
block("dp", DP, 4.45, DPR - DP, 0.45, "hour_12_24", "U_HOUR_12_24", tsz=900)
wire((DP + DPR) / 2, 4.20, (DP + DPR) / 2, 4.45)
label((DP + DPR) / 2 + 0.05, 4.24, 0.40, 0.15, "hour", sz=650)
wire(DP - 0.36, 4.68, DP, 4.68)
label(DP - 1.10, 4.60, 0.70, 0.17, "SW3 hour24", sz=700, col=DARK, algn="r")
label(DP, 4.92, DPR - DP, 0.14, "pm → led[15]", sz=650, algn="ctr")

# ------------------------------------------------------------------ 타이머 줄
block("ctrl", CU, 5.20, CUR - CU, 1.00, "timer_control_unit", "U_TIMER_CONTROL_UNIT", ["SET · RUN · ALARM"])
block("tick", TG, 5.20, TGR - TG, 0.50, "tick_gen_100hz_run", "U_TICK_GEN_TM", ["clear = 취소 | 알람"], tsz=850)
block("dp", DP, 5.20, DPR - DP, 1.00, "timer_datapath", "U_TIMER_DATAPATH", ["남은 시간 다운카운트"])
wire(GR, 5.70, CU, 5.70, lw=BUS)
label(GR + 0.03, 5.52, 0.24, 0.16, "×4", sz=750)
wire(CUR, 5.42, TG, 5.42)
label(CUR + 0.03, 5.06, 0.40, 0.34, ["run", "clear"], sz=600)
wire(TGR, 5.42, DP, 5.42, col=TICK, lw=TK)
label(TGR + 0.03, 5.24, 0.38, 0.16, "tm_tick", sz=600, col=TICK)
wire(CUR, 5.85, DP, 5.85, lw=BUS)
label(TG + 0.05, 5.87, 1.45, 0.14, "run · clear · add · amount", sz=650)
wire(DP, 6.08, CUR, 6.08)
label(TG + 0.05, 6.10, 0.50, 0.14, "zero", sz=650)

# ------------------------------------------------------------------ 화면 MUX
_sp("blk", MX, 2.05, MXR - MX, 4.15, '<a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 8000"/></a:avLst></a:prstGeom>',
    solid(*CAT["common"]),
    [para(("화면", 900, True, TXT, False)), para(("MUX", 900, True, TXT, False)), para(("3:1 ×4", 700, False, MUTED, False)),
     para(("msec", 650, False, DARK, True)), para(("sec", 650, False, DARK, True)),
     para(("min", 650, False, DARK, True)), para(("hour", 650, False, DARK, True))],
    body='lIns="0" tIns="38100" rIns="0" bIns="38100"', algn="ctr")
for txt, y, lw in [("SW", 2.45, BUS), ("WT", 3.55, BUS), ("hour_d", 4.68, 15875), ("TM", 5.55, BUS)]:
    wire(DPR, y, MX, y, lw=lw)
    label(DPR + 0.02, y - 0.16, 0.28, 0.14, txt, sz=600)
wire((MX + MXR) / 2, 6.40, (MX + MXR) / 2, 6.20)
label(MX - 0.38, 6.41, 1.20, 0.17, "sel: SW4 > SW0", sz=750, col=DARK, algn="ctr")

# ------------------------------------------------------------------ FND · LED
block("disp", FD, 2.05, FDR - FD, 2.05, "SW2_FND_CONTROLLER", "U_FND_CONTROLLER",
      ["자리 분리 → 설정 자리 점멸", "→ 8 슬롯 스캔 (4 kHz)", "→ 세그먼트"], tsz=850)
wire(MXR, 2.35, FD, 2.35, lw=BUS)
label(MXR + 0.05, 2.17, 0.72, 0.16, "w_disp_*", sz=650)
for txt, y in [("wt_cursor", 2.75), ("sel_wt", 3.07), ("SW1|SW4", 3.39), ("SW2 set", 3.71)]:
    tag(MXR + 0.05, y, 0.74, txt, h=0.22)
block("common", FD, 4.45, FDR - FD, 1.75, "LED 로직", "top assign",
      ["sel_sw/wt/tm · SW1 · SW4", "tm_run · sw_lap · pm(SW3)", "알람: 16 개 0.5 s 점멸", "(wt_msec ≥ 50)"])
for txt, y in [("fnd_com[3:0]", 2.75), ("fnd_font[7:0]", 3.55), ("led[15:0]", 5.30)]:
    wire(FDR, y, OT, y)
    tag(OT, y, 1.15, txt, color=RED)

# ------------------------------------------------------------------ 범례
label(0.30, 6.86, 3.95, 0.22, "▶ 태그 = 보드 핀 또는 같은 이름의 net · 굵은 선 = 다비트 버스", sz=800, mono=False)
lx = 4.35
for cat, txt in [("ctrl", "컨트롤"), ("dp", "데이터패스"), ("tick", "타이밍 (tick)"), ("disp", "표시"), ("common", "공통/글루")]:
    fill, line = CAT[cat]
    _sp("lg", lx, 6.90, 0.22, 0.15, '<a:prstGeom prst="roundRect"><a:avLst></a:avLst></a:prstGeom>', solid(fill, line, 12700), txbox=False)
    w = 0.95 if cat == "tick" else 0.75
    label(lx + 0.27, 6.86, w, 0.22, txt, sz=800, mono=False)
    lx += 0.27 + w + 0.08
wire(lx + 0.05, 6.97, lx + 0.40, 6.97, col=TICK, lw=TK)
label(lx + 0.45, 6.86, 1.05, 0.22, "100 Hz tick", sz=800, mono=False)
lx += 1.45
wire(lx + 0.05, 6.97, lx + 0.40, 6.97, col=TICK, dash="dash")
label(lx + 0.45, 6.86, 0.70, 0.22, "4 kHz", sz=800, mono=False)


# ------------------------------------------------------------------ 슬라이드 XML 교체
def main():
    zin = zipfile.ZipFile(PPTX)
    items = {n: zin.read(n) for n in zin.namelist()}
    infos = {i.filename: i for i in zin.infolist()}
    zin.close()
    x = items[SLIDE].decode("utf-8")
    sps = list(re.finditer(r"<p:sp>.*?</p:sp>", x, re.S))
    keep_head = sps[1].end()                                    # 섹션 · 제목 placeholder 2 개
    tail = next(m for m in sps if "Slide Number Placeholder" in m.group(0))
    sld_num = re.sub(r'<p:cNvPr id="\d+"', f'<p:cNvPr id="{len(shapes) + 4}"', tail.group(0), count=1)
    x = x[:keep_head] + "".join(shapes) + sld_num + x[tail.end():]
    items[SLIDE] = x.encode("utf-8")
    tmp = PPTX + ".tmp"
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
        for n, data in items.items():
            zout.writestr(infos[n], data, compress_type=zipfile.ZIP_DEFLATED)
    os.replace(tmp, PPTX)
    print(f"ok: {os.path.relpath(PPTX)} 3 쪽 도형 {len(shapes)} 개로 갱신")


if __name__ == "__main__":
    main()
