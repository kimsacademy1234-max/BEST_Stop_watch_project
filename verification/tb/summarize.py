#!/usr/bin/env python3
"""results/**/sim.log → results/summary.md (verification.md §9 표 형식).
| TB | src | 결과 | fail 수 | 첫 이상 시각 | 파형 창 | 비고 |
"""
import glob
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
os.chdir(ROOT)

ORDER = ["TOP1", "TOP2", "WT1", "WT2", "WT3", "SW1", "SW2", "SW3", "TM1", "TM2", "TM3", "F1", "F2", "F3", "F4"]
summ_re = re.compile(r"\[SUMMARY\] (\S+) src=(\S+) checks=(\d+) fail=(\d+) defect=(\d+) limit=(\d+) first_bad=(.+?) => (\S+)")
time_re = re.compile(r"^\[\s*([\d.]+) ms\] \[(FAIL |DEFECT|LIMIT)\] \[([^\]]+)\] (.*)$")

rows = []
for log in sorted(glob.glob("results/**/sim.log", recursive=True)):
    if "/_" in log:
        continue
    text = open(log, encoding="utf-8", errors="replace").read()
    m = summ_re.search(text)
    if not m:
        rows.append(("?", log, "NO SUMMARY (중단?)", "-", "-", "-", "-", "-", log))
        continue
    tb, src, checks, fail, defect, limit, first_bad, res = m.groups()
    first = None
    notes = []
    for line in text.splitlines():
        t = time_re.match(line)
        if not t:
            continue
        ms, lvl, cid, desc = t.groups()
        if lvl.strip() in ("FAIL", "DEFECT") and first is None:
            first = (float(ms), lvl.strip(), cid, desc)
        if lvl.strip() == "LIMIT" and len(notes) < 2:
            notes.append(f"LIMIT {cid}")
    wave = "-"
    fb = "-"
    if first_bad.strip() != "-":
        fb = first_bad.strip()
        v = float(fb.split()[0])
        wave = f"{v - 1:.3f} ~ {v + 1:.3f} ms"
    note = "; ".join(notes)
    if first:
        note = (f"{first[1]} {first[2]}: {first[3][:90]}" + ("; " + note if note else ""))
    rows.append((tb, src, res, fail, defect, limit, fb, wave, note.replace("|", "/")))

def key(r):
    return (ORDER.index(r[0]) if r[0] in ORDER else 99, r[1])

rows.sort(key=key)
out = ["# 검증 결과 요약 (자동 생성: tb/summarize.py)", "",
       "| TB | src | 결과 | fail 수 | defect 수 | limit 수 | 첫 이상 시각 | 파형 창 | 비고 |",
       "|---|---|---|---|---|---|---|---|---|"]
for r in rows:
    out.append("| " + " | ".join(str(x) for x in r) + " |")
out += ["", "- 결과: PASS = 기대대로 / DETECTED = 결함 TB 가 결함을 잡음 (fail 0) / FAIL = 기대와 다름",
        "- 첫 이상 시각 = 처음 FAIL 또는 DEFECT 가 난 시뮬 시각. 파형은 `./tb/run.sh <tb> --sim icarus --phase N --wave` 로 그 Phase 만 다시 뽑는다",
        "- 이상 시각 전체: `grep -E \"FAIL|DEFECT|TIMEOUT\" results/**/sim.log`"]
open("results/summary.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
print("\n".join(out))
