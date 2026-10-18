#!/usr/bin/env python3
"""시연 영상 시나리오 PDF 생성기 (경계값 위주: 시계 · 스톱워치 · 타이머, 보드 = ../source_file_demo).

실행: python3 demo_scenario.py [--open]  → ../demo_scenario.pdf
"""
import os
import subprocess
import sys

import gen_diagram as G

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "demo_scenario.pdf")


def fnd(s):
    """FND 화면 모양 글자"""
    return f'<span class="fnd">{s}</span>'


def k(s):
    """버튼 · 스위치 키캡"""
    return f'<span class="key">{s}</span>'


# (번호, 제목, 시간, 한 줄 요약, [(조작, 화면 · LED, 자막, 경계값 여부)])
# 보드 비트스트림 = ../source_file_demo (리셋값만 시계 23:59:50.00 · 스톱워치 23:59:55.00, 타이머는 그대로)
SECTIONS = [
    ("①", "시계 — 자정 넘기기", "약 15 초",
     "리셋하면 23:59:50.00 에서 시작. 10 초 뒤 자정을 넘는다.",
     [
         (f"스위치 모두 0, {k('sw3')} = 1 (24 시간) → {k('btnC')}", f"{fnd('50.00')} 부터 흐름",
          "리셋값 23:59:50 (시연용)", False),
         (f"57 초쯤에 {k('sw1')} = 1", f"{fnd('23.59')} → {fnd('00.00')}", "23:59:59.99 → 00:00:00.00", True),
         (f"{k('sw3')} = 0", f"{fnd('12.00')}, led15 꺼짐",
          "12 시간 표시: 자정은 0 시가 아니라 오전 12 시 (led15 = 오후 표시)", True),
     ]),
    ("②", "스톱워치 — 끝에서 0 으로, 0 에서 끝으로 순환", "약 20 초",
     "리셋하면 23:59:55.00 에서 정지 상태. ① 을 하는 동안에도 R 을 누르기 전까지 그대로 기다린다.",
     [
         (f"{k('sw0')} = 1, {k('sw1')} = 0", f"{fnd('55.00')} (정지)", "리셋값 23:59:55 (시연용)", False),
         (f"{k('R')} (시작)", f"{fnd('55.xx')} → {fnd('59.99')} → {fnd('00.00')}", "", False),
         (f"{k('sw1')} = 1", f"{fnd('00.00')}", "시.분도 0 → 23:59:59.99 다음은 00:00:00.00", True),
         (f"{k('R')} (정지) → {k('U')} (다운 모드) → {k('R')} (시작)", f"{fnd('00.00')} → {fnd('23.59')}",
          "0 에서 내려가면 23:59:59.99", True),
         (f"{k('R')} (정지)", f"{fnd('23.59')}", "", False),
     ]),
    ("③", "타이머 — 시작 조건 · 최대값 · 알람", "약 30 초",
     "타이머는 원래 소스 그대로. 0 에서 시작 안 함, 59:59 에서 멈춤, 0 이 되면 알람.",
     [
         (f"{k('sw0')} = 0, {k('sw4')} = 1", f"{fnd('00.00')}, led5", "", False),
         (f"{k('L')}", "변화 없음", "0 이면 시작하지 않음", True),
         (f"{k('D')} × 5", f"{fnd('50.00')}", "D = +10 분", False),
         (f"{k('D')} 한 번 더", f"{fnd('59.59')}", "60:00 이 아니라 최대값 59:59 에서 멈춤", True),
         (f"{k('L')} (시작) → 1~2 초 뒤 {k('L')}", f"{fnd('59.58')} … → {fnd('00.00')}", "동작 중 L = 취소", False),
         (f"{k('U')} → {k('L')}", f"{fnd('00.10')} → 10 초 카운트다운 → {fnd('00.00')}", "U = +10 초", False),
         ("(0 도달)", "LED 16 개가 0.5 초마다 깜빡임", "0 이 되면 알람", True),
         ("아무 버튼", f"깜빡임 멈춤, {fnd('00.00')} 그대로", "버튼은 알람 끄기로만 쓰이고 시간은 더해지지 않음", False),
     ]),
]

SWITCHES = [
    ("sw0", "0 시계 / 1 스톱워치"),
    ("sw1", "0 초.1/100 / 1 시.분"),
    ("sw2", "시계 설정"),
    ("sw3", "24 시간 표시"),
    ("sw4", "타이머 화면 (sw0 보다 우선)"),
    ("btnC", "리셋"),
]

TIPS = [
    "<b>시계는 리셋 뒤 10 초 안에 자정을 넘는다.</b> 놓쳤으면 btnC 를 다시 누르면 된다 "
    "(시계 23:59:50 · 스톱워치 23:59:55 · 타이머 00:00 으로 같이 돌아감).",
    "btnC 는 ① 시작에 한 번. 스톱워치는 R 을 누르기 전까지 23:59:55 에서 멈춰 있으니 ① 이 끝나면 바로 ② 로 넘어간다.",
    "바뀌는 순간 (23.59 → 00.00, 59.59 고정, 알람 LED) 은 <b>FND 와 LED 를 같이 클로즈업</b>, 버튼 누르는 손이 보이게.",
    "자막은 표의 <span class=\"bd\">경계값</span> 줄의 자막 문장 정도면 충분하다. "
    "영상 앞에 <b>“시연을 위해 리셋값만 경계 바로 앞으로 바꾼 빌드”</b> 한 줄을 넣는다.",
]

CSS = """
@page { size: A4; margin: 14mm 13mm 14mm 13mm; }
* { box-sizing: border-box; }
body { font-family: 'Malgun Gothic', sans-serif; color: #1d2430; font-size: 10.2pt; line-height: 1.45; margin: 0; }
h1 { font-size: 19pt; margin: 0 0 2mm; letter-spacing: -0.3pt; }
.sub { color: #5b6573; margin-bottom: 5mm; }
.why { background: #f2f5fa; border-left: 4px solid #3d6fd9; padding: 3mm 4mm; border-radius: 2mm; margin-bottom: 4mm; }
.flow { display: flex; gap: 2mm; margin: 0 0 4mm; }
.flow div { flex: 1; border: 1px solid #d5dbe4; border-radius: 2mm; padding: 2mm 3mm; font-size: 9pt; }
.flow b { display: block; font-size: 10.5pt; }
.flow span { color: #5b6573; }
.sw { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1.5mm 4mm; font-size: 9pt; margin-bottom: 5mm;
      border: 1px solid #d5dbe4; border-radius: 2mm; padding: 2.5mm 3.5mm; }
section { break-inside: avoid; margin-bottom: 5mm; }
h2 { font-size: 13pt; margin: 0 0 1mm; display: flex; align-items: baseline; gap: 2.5mm; }
h2 .t { margin-left: auto; font-size: 9pt; font-weight: normal; color: #5b6573; }
.lead { color: #3a4350; margin: 0 0 2mm; font-size: 9.5pt; }
table { width: 100%; border-collapse: collapse; font-size: 9.4pt; }
th { text-align: left; background: #e9edf3; padding: 1.6mm 2.4mm; font-weight: bold; }
td { padding: 1.7mm 2.4mm; border-bottom: 1px solid #e3e7ee; vertical-align: middle; }
col.c1 { width: 36%; } col.c2 { width: 30%; } col.c3 { width: 34%; }
tr.b td { background: #fff5e6; }
tr.b td:last-child { font-weight: bold; color: #a24b00; }
.fnd { font-family: Consolas, monospace; background: #17191d; color: #ff5a3c; padding: 0.3mm 1.6mm;
       border-radius: 1mm; letter-spacing: 0.6pt; font-weight: bold; white-space: nowrap; }
.key { display: inline-block; border: 1px solid #9aa4b2; border-bottom-width: 2px; border-radius: 1mm;
       padding: 0 1.4mm; font-size: 8.8pt; font-weight: bold; background: #fafbfc; white-space: nowrap; }
code { font-family: Consolas, monospace; font-size: 9pt; background: #e4e9f1; padding: 0 1mm; border-radius: 1mm; }
.bd { background: #fff5e6; color: #a24b00; font-weight: bold; padding: 0 1mm; border-radius: 1mm; }
ul { margin: 1mm 0 0; padding-left: 5mm; } li { margin-bottom: 1.5mm; }
.tips { break-inside: avoid; border: 1px solid #d5dbe4; border-radius: 2mm; padding: 3mm 4mm; }
.tips h2 { margin-bottom: 1mm; }
"""


def build_html():
    h = [f"<!doctype html><meta charset='utf-8'><style>{CSS}</style><body>"]
    h.append("<h1>시연 영상 시나리오 — 경계값</h1>")
    h.append("<div class='sub'>BEST Stop-watch · 시계 · 스톱워치 · 타이머 · 전체 약 1 분 · 리셋 (btnC) 은 처음에 한 번만</div>")
    h.append("<div class='why'><b>시연용 소스 · 비트스트림:</b> <code>verification_v2/source_file_demo/</code> "
             "(<code>source_file/</code> 복사본). <b>리셋값만</b> 경계 바로 앞으로 바꿨다 — "
             "시계 <b>23:59:50.00</b> (원래 12:00:00.00), 스톱워치 <b>23:59:55.00</b> (원래 0). "
             "타이머 · 나머지 동작은 그대로. 그래서 시간을 맞추거나 기다리는 장면 없이 바로 경계를 넘는 것을 보여 줄 수 있다.</div>")
    short = {"①": "시계 자정 넘김", "②": "스톱워치 순환", "③": "타이머 59:59 · 알람"}
    h.append("<div class='flow'>" + "".join(
        f"<div><b>{n} {short[n]}</b><span>{tm}</span></div>" for n, t, tm, _, _ in SECTIONS) + "</div>")
    h.append("<div class='sw'>" + "".join(f"<div>{k(s)} {d}</div>" for s, d in SWITCHES) + "</div>")
    for n, title, tm, lead, rows in SECTIONS:
        h.append(f"<section><h2>{n} {title}<span class='t'>{tm}</span></h2><p class='lead'>{lead}</p>")
        h.append("<table><colgroup><col class='c1'><col class='c2'><col class='c3'></colgroup>"
                 "<tr><th>조작</th><th>화면 · LED</th><th>자막 포인트</th></tr>")
        for op, scr, cap, b in rows:
            h.append(f"<tr class='{'b' if b else ''}'><td>{op}</td><td>{scr}</td><td>{cap}</td></tr>")
        h.append("</table></section>")
    h.append("<div class='tips'><h2>찍을 때 주의할 점</h2><ul>" + "".join(f"<li>{t}</li>" for t in TIPS) + "</ul></div>")
    return "".join(h)


def main():
    html = os.path.abspath(OUT)[:-4] + "._tmp.html"
    open(html, "w", encoding="utf-8").write(build_html())
    G.chrome(["--no-pdf-header-footer", f"--print-to-pdf={G.win(os.path.abspath(OUT))}",
              "file:///" + G.win(html).replace("\\", "/")])
    os.remove(html)
    print("pdf:", os.path.abspath(OUT))
    if "--open" in sys.argv:
        subprocess.run(["explorer.exe", G.win(os.path.abspath(OUT))], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    main()
