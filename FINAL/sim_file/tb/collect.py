#!/usr/bin/env python3
"""결과 취합 (LEAD) : results/W*/tb_*.log + tb_scenario.md → results/SUMMARY.md

판정 (시나리오별)
  PASS        : FAIL 0, 확인 개수 = 문서 개수, [SUMMARY] 있음
  PASS*       : FAIL 0 이지만 ⚠ 항목이 [KNOWN] (예상한 설계 이슈 재현)
  FAIL        : [FAIL] 1 개 이상 (WATCHDOG 포함)
  INCOMPLETE  : 로그는 있는데 [SUMMARY] 없음 (중단 · 빌드 실패)
  COUNT?      : FAIL 0 인데 확인 개수가 문서와 다름
  NOT RUN     : 로그 없음
"""
import re, glob, os, collections, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
doc = open(os.path.join(ROOT, 'tb_scenario.md'), encoding='utf-8').read()

# "#### G1. 정상 명령 전부 — `P1` · 24 개"
scen = collections.OrderedDict()
for m in re.finditer(r'^#### ([A-L]\d+)\. (.+?) — `(P\d)` · (\d+) 개(.*)$', doc, re.M):
    scen[m.group(1)] = dict(title=m.group(2).strip(), p=m.group(3), n=int(m.group(4)),
                            warn='⚠' in m.group(5))
groups = collections.OrderedDict()
for m in re.finditer(r'^### ([A-L])\. (.+)$', doc.split('## 4. 상세 시나리오')[1], re.M):
    groups[m.group(1)] = m.group(2).strip()

owner = {}
for g in 'CGH': owner[g] = 'W1'
for g in 'ABDEFK': owner[g] = 'W2'
for g in 'IJL': owner[g] = 'W3'

res = {}
fails = []
for log in sorted(glob.glob(os.path.join(ROOT, 'results', 'W*', 'tb_*.log'))):
    sid = os.path.basename(log)[3:-4]
    r = dict(PASS=0, FAIL=0, KNOWN=0, XPASS=0, INFO=0, summary=False, wall='', log=os.path.relpath(log, ROOT))
    for line in open(log, encoding='utf-8', errors='replace'):
        m = re.match(r'^\[(PASS|FAIL|KNOWN|XPASS|INFO)\] (\S+)', line)
        if m:
            r[m.group(1)] += 1
            if m.group(1) == 'FAIL':
                fails.append((sid, line.strip()))
        if line.startswith('[SUMMARY]'):
            r['summary'] = True
        m = re.match(r'^\[WALL\] \S+ (\d+) s', line)
        if m:
            r['wall'] = m.group(1)
    res[sid] = r

def verdict(sid):
    if sid not in res:
        return 'NOT RUN'
    r = res[sid]
    if r['FAIL'] > 0:
        return 'FAIL'
    if not r['summary']:
        return 'INCOMPLETE'
    n = r['PASS'] + r['KNOWN'] + r['XPASS']
    if n != scen[sid]['n']:
        return 'COUNT?'
    return 'PASS*' if r['KNOWN'] > 0 else 'PASS'

out = []
now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M')
cnt = collections.Counter(verdict(s) for s in scen)
tot = collections.Counter()
for s in scen:
    if s in res:
        for k in ('PASS', 'FAIL', 'KNOWN', 'XPASS'):
            tot[k] += res[s][k]
out.append('# merge_final_top TB 결과 취합\n')
out.append(f'- 생성 : {now} (`python3 tb/collect.py`)')
out.append('- 기준 : 실제 100 MHz · 실시간 (시간 단축 없음), Verilator 5.032')
out.append('- 판정 : `PASS` 전부 통과 · `PASS*` 통과 + ⚠ 설계 이슈 재현 (KNOWN) · `FAIL` · `COUNT?` 확인 개수 불일치 · `INCOMPLETE` · `NOT RUN`\n')
out.append('## 요약\n')
out.append('| 시나리오 판정 | 개수 |\n|---|:-:|')
for k in ('PASS', 'PASS*', 'FAIL', 'COUNT?', 'INCOMPLETE', 'NOT RUN'):
    out.append(f'| {k} | {cnt[k]} |')
out.append(f'| **합계** | **{len(scen)}** |\n')
out.append(f'확인 항목 : PASS {tot["PASS"]} · FAIL {tot["FAIL"]} · KNOWN {tot["KNOWN"]} · XPASS {tot["XPASS"]} (문서 합계 {sum(v["n"] for v in scen.values())})\n')
out.append('## 그룹별\n')
out.append('| 그룹 | 담당 | 시나리오 | PASS | PASS* | FAIL | 기타 |\n|---|---|:-:|:-:|:-:|:-:|:-:|')
for g, name in groups.items():
    ids = [s for s in scen if s.startswith(g) and s[1:].isdigit()]
    c = collections.Counter(verdict(s) for s in ids)
    other = len(ids) - c['PASS'] - c['PASS*'] - c['FAIL']
    out.append(f'| {g}. {name} | {owner[g]} | {len(ids)} | {c["PASS"]} | {c["PASS*"]} | {c["FAIL"]} | {other} |')
out.append('\n## 시나리오별\n')
for g, name in groups.items():
    out.append(f'### {g}. {name} ({owner[g]})\n')
    out.append('| ID | 시나리오 | P | 문서 개수 | PASS | FAIL | KNOWN | XPASS | 판정 | 벽시계 (s) |\n|---|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|')
    for s, v in scen.items():
        if not (s.startswith(g) and s[1:].isdigit()):
            continue
        r = res.get(s, {})
        warn = ' ⚠' if v['warn'] else ''
        out.append(f'| {s} | {v["title"]}{warn} | {v["p"]} | {v["n"]} | {r.get("PASS", "")} | {r.get("FAIL", "")} | '
                   f'{r.get("KNOWN", "")} | {r.get("XPASS", "")} | **{verdict(s)}** | {r.get("wall", "")} |')
    out.append('')
out.append('## FAIL 줄 전체\n')
if fails:
    out.append('```')
    out += [f'{s}: {l}' for s, l in fails]
    out.append('```')
else:
    out.append('없음')
open(os.path.join(ROOT, 'results', 'SUMMARY.md'), 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print(f'results/SUMMARY.md 작성 : ' + ', '.join(f'{k} {cnt[k]}' for k in cnt))
