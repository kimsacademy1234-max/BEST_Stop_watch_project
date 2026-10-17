#!/usr/bin/env python3
"""컨트롤 유닛 3 개 (스톱워치 · 타이머 · 시계) 의 상태도 · ASM 차트 생성기.

- 아래 SPEC 이 그림의 원본: 상태도 · 전이표 · Mealy 표 · ASM 차트를 모두 여기서 그린다.
- 그리기 전에 SPEC 을 RTL 과 맞춰 본다. 하나라도 다르면 멈춘다 (PDF 를 만들지 않음).
  1. enum 상태 이름 · 리셋 상태, 입력 · 출력 포트 = source_file/*_control_unit.sv
  2. 전이표: 상태마다 조건이 겹치지 않고 빠짐없음 (모든 입력 조합)
  3. ASM 차트와 전이표 · Mealy 표를 실행해 보면 모든 상태 × 입력 조합에서 같은 결과
  4. Verilator 로 RTL 을 무작위 입력 N_CYCLES 클럭 돌려, 매 클럭 c_state · n_state · 출력이
     ASM 차트를 그대로 실행한 값과 같음 (상태 × 입력 조합이 전부 나와야 통과)

실행: python3 gen_fsm.py [--open] [--png DIR]  → ../control_unit_fsm.pdf
      --open : 만든 PDF 를 Windows 기본 프로그램으로 열기
      --png  : 쪽마다 PNG 도 DIR 에 저장 (미리보기)
"""
import itertools
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile

from gen_diagram import FONT, MONO, esc, to_pdf, to_png, win

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "source_file")
OUT_PDF = os.path.join(HERE, "..", "control_unit_fsm.pdf")

W, H = 1800, 1272          # 쪽 크기 (가로 A4 비율)
N_CYCLES = 20000           # RTL 대조 클럭 수
ELSE = None                # 전이표의 "그 외" 줄

STATE_COL = ["#1c7ed6", "#2f9e44", "#e8590c", "#7048e8"]
DEC_FILL, DEC_LINE = "#fff9db", "#b08900"
OUT_FILL, OUT_LINE = "#e6fcf5", "#0ca678"


# --------------------------------------------------------------------------- ASM 차트 노드
class Go:
    """다음 상태 (ASM 블록 출구)"""
    def __init__(self, state):
        self.state = state


class Out:
    """조건 출력 박스 (Mealy) → next"""
    def __init__(self, assigns, next, right=True):
        self.assigns, self.next, self.right = assigns, next, right


class Opt:
    """판단 → 1 이면 조건 출력 박스 → 다시 합류해서 next"""
    def __init__(self, cond, assigns, next):
        self.cond, self.assigns, self.next = cond, assigns, next


class Dec:
    """판단 → 1 / 0 갈래. down = 아래로 내려가는 쪽 값 (나머지는 오른쪽)"""
    def __init__(self, cond, one, zero, down=0):
        self.cond, self.one, self.zero, self.down = cond, one, zero, down


# --------------------------------------------------------------------------- SPEC
# 조건 · 값은 Verilog 식 그대로 (~ & | 와 포트 · 레지스터 이름). "\n" 은 그림에서 줄바꿈만.
# assigns = [(이름, 값, 설명)] — 이름이 출력 포트가 아니면 레지스터 (<=, 다음 클럭에 반영)
SPECS = [
    dict(
        key="sw", title="스톱워치", file="stopwatch_control_unit.sv", inst="U_STOPWATCH_CONTROL_UNIT",
        states=["STOP", "RUN"], reset="STOP", regs={"down_reg": 0},
        rand={"i_sw_btn_R": 0.3, "i_sw_btn_L": 0.3, "i_sw_btn_U": 0.3},
        abbr={"i_sw_btn_R": "R", "i_sw_btn_L": "L", "i_sw_btn_U": "U"},
        moore={"STOP": [("o_sw_run_stop", 0), ("o_sw_down", "down_reg")],
               "RUN":  [("o_sw_run_stop", 1), ("o_sw_down", "down_reg")]},
        next={"STOP": [("i_sw_btn_R", "RUN"), (ELSE, "STOP")],
              "RUN":  [("i_sw_btn_R", "STOP"), (ELSE, "RUN")]},
        mealy=[(["STOP"], "i_sw_btn_L", [("o_sw_clear", 1)]),
               (["STOP"], "i_sw_btn_U", [("down_reg", "~down_reg")])],
        asm={"STOP": Opt("i_sw_btn_L", [("o_sw_clear", 1)],
                         Opt("i_sw_btn_U", [("down_reg", "~down_reg")],
                             Dec("i_sw_btn_R", Go("RUN"), Go("STOP")))),
             "RUN": Dec("i_sw_btn_R", Go("STOP"), Go("RUN"))},
        notes=["o_sw_down 은 상태가 아니라 레지스터 down_reg (리셋 0) — STOP 에서 U 가 오면 다음 클럭 엣지에 뒤집힘",
               "RUN 중에는 L (지우기) · U (업/다운) 무시, R 만 봄",
               "D (랩) 은 컨트롤 유닛을 거치지 않고 stopwatch_datapath 로 바로 감"],
        diagram=dict(pos={"STOP": (300, 450), "RUN": (760, 450)},
                     bend={("STOP", "RUN"): 90, ("RUN", "STOP"): 90},
                     loops={"STOP": 180, "RUN": 0},
                     reset=("STOP", -120),
                     mealy={("STOP",): (110, 680)}),
    ),
    dict(
        key="tm", title="타이머", file="timer_control_unit.sv", inst="U_TIMER_CONTROL_UNIT",
        states=["SET", "RUN", "ALARM"], reset="SET", regs={},
        rand={"i_tm_btn_R": 0.25, "i_tm_btn_L": 0.25, "i_tm_btn_U": 0.25, "i_tm_btn_D": 0.25, "i_tm_zero": 0.5},
        abbr={"i_tm_btn_R": "R", "i_tm_btn_L": "L", "i_tm_btn_U": "U", "i_tm_btn_D": "D", "i_tm_zero": "zero"},
        moore={"SET":   [("o_tm_run", 0), ("o_tm_alarm", 0)],
               "RUN":   [("o_tm_run", 1), ("o_tm_alarm", 0)],
               "ALARM": [("o_tm_run", 0), ("o_tm_alarm", 1)]},
        next={"SET":   [("i_tm_btn_L & ~i_tm_zero", "RUN"), (ELSE, "SET")],
              "RUN":   [("i_tm_btn_L", "SET"), ("~i_tm_btn_L & i_tm_zero", "ALARM"), (ELSE, "RUN")],
              "ALARM": [("i_tm_btn_L | i_tm_btn_R |\ni_tm_btn_U | i_tm_btn_D", "SET"), (ELSE, "ALARM")]},
        mealy=[(["SET"], "~i_tm_btn_L & i_tm_btn_U",
                [("o_tm_add", 1), ("o_tm_amount", 0, "+10초")]),
               (["SET"], "~i_tm_btn_L & ~i_tm_btn_U &\ni_tm_btn_R",
                [("o_tm_add", 1), ("o_tm_amount", 1, "+1분")]),
               (["SET"], "~i_tm_btn_L & ~i_tm_btn_U &\n~i_tm_btn_R & i_tm_btn_D",
                [("o_tm_add", 1), ("o_tm_amount", 2, "+10분")]),
               (["RUN"], "i_tm_btn_L", [("o_tm_clear", 1)])],
        asm={"SET": Dec("i_tm_btn_L",
                        Dec("i_tm_zero", Go("SET"), Go("RUN"), down=1),
                        Dec("i_tm_btn_U", Out([("o_tm_add", 1), ("o_tm_amount", 0, "+10초")], Go("SET")),
                            Dec("i_tm_btn_R", Out([("o_tm_add", 1), ("o_tm_amount", 1, "+1분")], Go("SET")),
                                Dec("i_tm_btn_D", Out([("o_tm_add", 1), ("o_tm_amount", 2, "+10분")], Go("SET")),
                                    Go("SET"))))),
             "RUN": Dec("i_tm_btn_L", Out([("o_tm_clear", 1)], Go("SET")),
                        Dec("i_tm_zero", Go("ALARM"), Go("RUN"))),
             "ALARM": Dec("i_tm_btn_L |\ni_tm_btn_R |\ni_tm_btn_U |\ni_tm_btn_D", Go("SET"), Go("ALARM"))},
        notes=["SET 의 버튼 우선순위 L > U > R > D (같은 클럭에 둘 이상이면 앞의 것 하나만)",
               "SET 에서 L 이어도 i_tm_zero = 1 (남은 시간 0) 이면 시작 안 함",
               "i_tm_zero 는 timer_datapath 에서 옴 (남은 시간 = 0 이면 1)",
               "RUN 중 L = 취소: SET 으로 가면서 o_tm_clear 로 남은 시간 지우기"],
        diagram=dict(pos={"SET": (290, 450), "RUN": (790, 450), "ALARM": (540, 860)},
                     bend={("SET", "RUN"): 90, ("RUN", "SET"): 90, ("RUN", "ALARM"): 50, ("ALARM", "SET"): 50},
                     loops={"SET": 180, "RUN": 0, "ALARM": 90},
                     reset=("SET", -115),
                     mealy={("SET",): (20, 660), ("RUN",): (620, 150)}),
    ),
    dict(
        key="wt", title="시계", file="watch_control_unit.sv", inst="U_WATCH_CONTROL_UNIT",
        states=["NORMAL", "SET_HOUR", "SET_MIN_10", "SET_MIN_1"], reset="NORMAL", regs={},
        rand={"i_wt_btn_R": 0.3, "i_wt_btn_L": 0.3, "i_wt_btn_U": 0.3, "i_wt_btn_D": 0.3, "i_set_sw2": 0.7},
        abbr={"i_wt_btn_R": "R", "i_wt_btn_L": "L", "i_wt_btn_U": "U", "i_wt_btn_D": "D", "i_set_sw2": "sw2"},
        moore={"NORMAL":     [("o_wt_cursor", 3, "CUR_NONE")],
               "SET_HOUR":   [("o_wt_cursor", 2, "CUR_HOUR")],
               "SET_MIN_10": [("o_wt_cursor", 1, "CUR_MIN_10")],
               "SET_MIN_1":  [("o_wt_cursor", 0, "CUR_MIN_1")]},
        next={"NORMAL":     [("i_set_sw2", "SET_MIN_1"), (ELSE, "NORMAL")],
              "SET_HOUR":   [("~i_set_sw2", "NORMAL"), ("i_set_sw2 & i_wt_btn_L", "SET_MIN_1"),
                             ("i_set_sw2 & ~i_wt_btn_L & i_wt_btn_R", "SET_MIN_10"), (ELSE, "SET_HOUR")],
              "SET_MIN_10": [("~i_set_sw2", "NORMAL"), ("i_set_sw2 & i_wt_btn_L", "SET_HOUR"),
                             ("i_set_sw2 & ~i_wt_btn_L & i_wt_btn_R", "SET_MIN_1"), (ELSE, "SET_MIN_10")],
              "SET_MIN_1":  [("~i_set_sw2", "NORMAL"), ("i_set_sw2 & i_wt_btn_L", "SET_MIN_10"),
                             ("i_set_sw2 & ~i_wt_btn_L & i_wt_btn_R", "SET_HOUR"), (ELSE, "SET_MIN_1")]},
        mealy=[(["SET_HOUR", "SET_MIN_10", "SET_MIN_1"], "i_set_sw2 & i_wt_btn_U", [("o_wt_up", 1)]),
               (["SET_HOUR", "SET_MIN_10", "SET_MIN_1"], "i_set_sw2 & i_wt_btn_D &\n~i_wt_btn_U", [("o_wt_down", 1)])],
        asm={"NORMAL": Dec("i_set_sw2", Go("SET_MIN_1"), Go("NORMAL")),
             **{s: Dec("i_set_sw2",
                       Opt("i_wt_btn_U", [("o_wt_up", 1)],
                           Opt("i_wt_btn_D &\n~i_wt_btn_U", [("o_wt_down", 1)],
                               Dec("i_wt_btn_L", Go(left),
                                   Dec("i_wt_btn_R", Go(right), Go(s))))),
                       Go("NORMAL"), down=1)
                for s, left, right in [("SET_HOUR", "SET_MIN_1", "SET_MIN_10"),
                                       ("SET_MIN_10", "SET_HOUR", "SET_MIN_1"),
                                       ("SET_MIN_1", "SET_MIN_10", "SET_HOUR")]}},
        notes=["i_set_sw2 를 1 로 올리면 항상 SET_MIN_1 (FND 맨 오른쪽 자리) 부터, 0 으로 내리면 어느 자리에서든 NORMAL",
               "L 이 R 보다, U 가 D 보다 우선 (같은 클럭에 둘 다 오면)",
               "o_wt_up · o_wt_down 은 L · R 과 상관없이 나감 (같은 클럭에 L 과 U 가 오면 자리 이동 + 증가 둘 다)",
               "o_wt_cursor = FND 자리 번호 (AN0 = 맨 오른쪽): 0 분 일 · 1 분 십 · 2 시 일 · 3 없음"],
        diagram=dict(pos={"NORMAL": (530, 300), "SET_HOUR": (230, 660), "SET_MIN_10": (530, 660),
                          "SET_MIN_1": (830, 660)},
                     bend={("NORMAL", "SET_MIN_1"): 60, ("SET_MIN_1", "NORMAL"): 60,
                           ("SET_MIN_10", "NORMAL"): 0, ("SET_HOUR", "NORMAL"): 0,
                           ("SET_MIN_1", "SET_MIN_10"): 50, ("SET_MIN_10", "SET_MIN_1"): 50,
                           ("SET_MIN_10", "SET_HOUR"): 50, ("SET_HOUR", "SET_MIN_10"): 50,
                           ("SET_HOUR", "SET_MIN_1"): 420, ("SET_MIN_1", "SET_HOUR"): -600},
                     loops={"NORMAL": -90, "SET_HOUR": 180, "SET_MIN_10": 90, "SET_MIN_1": 0},
                     reset=("NORMAL", 180),
                     mealy={("SET_HOUR", "SET_MIN_10", "SET_MIN_1"): (10, 10)}),
    ),
]


# --------------------------------------------------------------------------- RTL 읽기
def parse_sv(fname):
    s = re.sub(r"//.*", "", open(os.path.join(SRC, fname), encoding="utf-8").read())
    ports = [(m.group(1), m.group(4), int(m.group(2)) - int(m.group(3)) + 1 if m.group(2) else 1)
             for m in re.finditer(r"\b(input|output)\s+(?:reg\s+|wire\s+|logic\s+)?(?:\[(\d+):(\d+)\]\s*)?(\w+)", s)]
    em = re.search(r"typedef\s+enum\s+logic\s*(?:\[(\d+):0\])?\s*\{([^}]*)\}", s)
    ew = int(em.group(1)) + 1 if em.group(1) else 1
    states = [(n, int(v, 2)) for n, v in re.findall(r"(\w+)\s*=\s*\d+'b([01]+)", em.group(2))]
    reset = re.search(r"if\s*\(\s*i_rst\s*\)\s*begin\s*c_state\s*<=\s*(\w+)", s).group(1)
    return dict(module=re.search(r"module\s+(\w+)", s).group(1), ports=ports, states=states,
                code={n: c for n, c in states}, ew=ew, reset=reset,
                ins=[p for d, p, _ in ports if d == "input" and p not in ("i_clk", "i_rst")],
                outs=[p for d, p, _ in ports if d == "output"],
                width={p: w for _, p, w in ports})


# --------------------------------------------------------------------------- SPEC 실행 (모델)
def py(expr):
    return expr.replace("\n", " ").replace("~", " not ").replace("&", " and ").replace("|", " or ")


def ev(expr, env):
    return int(bool(eval(py(expr), {}, dict(env))))


def apply(assigns, env, outs, upd):
    for a in assigns:
        n, v = a[0], a[1]
        val = v if isinstance(v, int) else ev(v, env)
        if n in outs:
            outs[n] = val
        else:
            upd[n] = val


def run_asm(spec, info, state, inp, regs):
    env = {**inp, **regs}
    outs, upd = {p: 0 for p in info["outs"]}, {}
    apply(spec["moore"][state], env, outs, upd)
    node = spec["asm"][state]
    while True:
        if isinstance(node, Opt):
            if ev(node.cond, env):
                apply(node.assigns, env, outs, upd)
            node = node.next
        elif isinstance(node, Dec):
            node = node.one if ev(node.cond, env) else node.zero
        elif isinstance(node, Out):
            apply(node.assigns, env, outs, upd)
            node = node.next
        else:
            return outs, node.state, upd


def run_table(spec, info, state, inp, regs):
    env = {**inp, **regs}
    outs, upd = {p: 0 for p in info["outs"]}, {}
    apply(spec["moore"][state], env, outs, upd)
    rows = spec["next"][state]
    hit = [d for c, d in rows if c is not ELSE and ev(c, env)]
    nxt = hit[0] if hit else [d for c, d in rows if c is ELSE][0]
    for sts, c, assigns in spec["mealy"]:
        if state in sts and ev(c, env):
            apply(assigns, env, outs, upd)
    return outs, nxt, upd


# --------------------------------------------------------------------------- 검사
def check_static(spec, info):
    errs = []
    if [n for n, _ in info["states"]] != spec["states"]:
        errs.append(f"상태 {spec['states']} ≠ RTL enum {[n for n, _ in info['states']]}")
    if info["reset"] != spec["reset"]:
        errs.append(f"리셋 상태 {spec['reset']} ≠ RTL {info['reset']}")
    if sorted(spec["rand"]) != sorted(info["ins"]):
        errs.append(f"입력 {sorted(spec['rand'])} ≠ RTL {sorted(info['ins'])}")
    if set(spec["asm"]) != set(spec["states"]) or set(spec["next"]) != set(spec["states"]):
        errs.append("ASM · 전이표에 빠진 상태")
    if errs:
        return errs
    ins = info["ins"]
    for st in spec["states"]:
        rows = spec["next"][st]
        if sum(c is ELSE for c, _ in rows) > 1:
            errs.append(f"{st}: '그 외' 줄이 둘 이상")
        for vals in itertools.product((0, 1), repeat=len(ins)):
            env = dict(zip(ins, vals))
            hit = [d for c, d in rows if c is not ELSE and ev(c, env)]
            if len(hit) > 1:
                errs.append(f"{st}: 전이표 조건이 겹침 {env}")
            if not hit and all(c is not ELSE for c, _ in rows):
                errs.append(f"{st}: 전이표 조건이 빠짐 {env}")
            for rv in itertools.product((0, 1), repeat=len(spec["regs"])):
                regs = dict(zip(spec["regs"], rv))
                a, t = run_asm(spec, info, st, env, regs), run_table(spec, info, st, env, regs)
                if a != t:
                    errs.append(f"{st} {env} {regs}: ASM {a} ≠ 전이표 {t}")
    return errs[:10]


def check_rtl(spec, info):
    """Verilator 로 RTL 을 무작위 입력으로 돌려 매 클럭 SPEC (ASM 실행) 과 비교"""
    ins, outs = info["ins"], info["outs"]
    decl = "".join(f"  logic {'[%d:0] ' % (info['width'][p] - 1) if info['width'][p] > 1 else ''}{p};\n"
                   for p in outs)
    drive = "".join(f"      {p} = ($urandom % 1000) < {int(spec['rand'][p] * 1000)};\n" for p in ins)
    show = ", ".join(["dut.c_state", "dut.n_state"] + ins + outs)
    tb = ("`timescale 1ns / 1ps\nmodule tb;\n  logic i_clk = 0, i_rst = 1;\n"
          + "".join(f"  logic {p} = 0;\n" for p in ins) + decl
          + f"  {info['module']} dut (.*);\n  always #5 i_clk = ~i_clk;\n"
          "  initial begin\n    repeat (3) @(posedge i_clk);\n    @(negedge i_clk) i_rst = 0;\n"
          f"    for (int k = 0; k < {N_CYCLES}; k++) begin\n" + drive
          + f"      #1 $display(\"T{' %0d' * (2 + len(ins) + len(outs))}\", {show});\n"
          "      @(negedge i_clk);\n    end\n    $finish;\n  end\nendmodule\n")
    tmp = tempfile.mkdtemp(prefix="gen_fsm_")
    try:
        open(os.path.join(tmp, "tb.sv"), "w").write(tb)
        r = subprocess.run(["verilator", "--binary", "--timing", "-Wno-fatal", "-Wno-lint", "-Wno-style",
                            "--top-module", "tb", "-Mdir", os.path.join(tmp, "obj"), "-o", "Vtb",
                            os.path.join(tmp, "tb.sv"), os.path.join(SRC, spec["file"])],
                           capture_output=True, text=True)
        if r.returncode:
            return [f"Verilator 빌드 실패:\n{r.stderr[-2000:]}"], 0
        log = subprocess.run([os.path.join(tmp, "obj", "Vtb")], capture_output=True, text=True).stdout
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    name = {c: n for n, c in info["states"]}
    state, regs = spec["reset"], dict(spec["regs"])
    errs, seen, n = [], set(), 0
    for line in log.splitlines():
        if not line.startswith("T "):
            continue
        v = list(map(int, line.split()[1:]))
        cs, ns = name.get(v[0], v[0]), name.get(v[1], v[1])
        inp = dict(zip(ins, v[2:2 + len(ins)]))
        o = dict(zip(outs, v[2 + len(ins):]))
        mo, mn, mu = run_asm(spec, info, state, inp, regs)
        if cs != state or ns != mn or o != mo:
            errs.append(f"클럭 {n}: 입력 {inp} RTL c={cs} n={ns} {o} / SPEC c={state} n={mn} {mo}")
            if len(errs) >= 10:
                break
        seen.add((state, tuple(inp[p] for p in ins)))
        state = mn
        regs.update(mu)
        n += 1
    if n != N_CYCLES:
        errs.append(f"RTL 출력 줄 {n} 개 (기대 {N_CYCLES})")
    total = len(spec["states"]) * 2 ** len(ins)
    if not errs and len(seen) != total:
        errs.append(f"상태 × 입력 조합 {len(seen)} / {total} 만 나옴 (N_CYCLES 를 늘릴 것)")
    return errs, total


# --------------------------------------------------------------------------- 그리기 도구
def tw(s, size, mono=True):
    """글자 폭 어림 (px)"""
    return sum((0.56 if mono else 0.55) * size if ord(ch) < 128 else 1.0 * size for ch in s)


def T(x, y, s, size=13, color="#222", anchor="start", weight="normal", mono=False):
    fam = MONO if mono else FONT
    return (f'<text x="{x:.1f}" y="{y:.1f}" font-family="{fam}" font-size="{size}" fill="{color}" '
            f'text-anchor="{anchor}" font-weight="{weight}">{esc(str(s))}</text>')


def lines_at(cx, cy, lines, size=13, color="#222", mono=True, weight="normal", lh=None, anchor="middle"):
    lh = lh or size * 1.3
    y0 = cy - (len(lines) - 1) * lh / 2 + size * 0.35
    return "".join(T(cx, y0 + i * lh, ln, size, color, anchor, weight, mono) for i, ln in enumerate(lines))


def light(c, k=0.88):
    r, g, b = (int(c[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02x%02x%02x" % tuple(int(v + (255 - v) * k) for v in (r, g, b))


def head(x, y, ang, color, size=11):
    pts = [(x, y)] + [(x + size * math.cos(ang + s * 2.7), y + size * math.sin(ang + s * 2.7)) for s in (1, -1)]
    return f'<polygon points="{" ".join(f"{a:.1f},{b:.1f}" for a, b in pts)}" fill="{color}"/>'


def arrow(pts, color="#444", width=1.7, tip=True, dash=None):
    d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    s = (f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}"'
         + (f' stroke-dasharray="{dash}"' if dash else "") + "/>")
    if tip:
        (x0, y0), (x1, y1) = pts[-2], pts[-1]
        s += head(x1, y1, math.atan2(y1 - y0, x1 - x0), color)
    return s


def svg_page(body, title, subtitle, page_no, n_pages):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            f'<rect width="{W}" height="{H}" fill="#ffffff"/>'
            + T(30, 50, title, 28, "#111", weight="bold") + T(30, 82, subtitle, 15, "#555")
            + f'<line x1="30" y1="98" x2="{W - 30}" y2="98" stroke="#d0d7e2" stroke-width="1.5"/>'
            + body
            + T(W - 30, H - 18, f"control_unit_fsm.pdf · {page_no} / {n_pages} · 자동 생성: diagram/gen_fsm.py",
                12, "#999", "end")
            + "</svg>")


class Ctx:
    """FSM 하나를 그릴 때 쓰는 공통 정보"""
    def __init__(self, spec, info):
        self.spec, self.info = spec, info
        self.color = {s: STATE_COL[i] for i, s in enumerate(spec["states"])}

    def code(self, st):
        return f"{self.info['ew']}'b{self.info['code'][st]:0{self.info['ew']}b}"

    def fmt(self, a):
        n, v = a[0], a[1]
        w = self.info["width"].get(n, 1)
        val = (f"{w}'d{v}" if w > 1 else str(v)) if isinstance(v, int) else v
        s = f"{n} {'=' if n in self.info['outs'] else '<='} {val}"
        return s + (f"  ({a[2]})" if len(a) > 2 else "")

    def abbr(self, cond):
        if cond is ELSE:
            return "그 외"
        s = cond.replace("\n", " ")
        for full, short in self.spec["abbr"].items():
            s = re.sub(rf"\b{full}\b", short, s)
        return re.sub(r"\s+", " ", s)


# --------------------------------------------------------------------------- ASM 차트
COL_GAP, ROW_GAP = 46, 40


def occ(node):
    """노드가 차지하는 칸 (자기 = (0, 0) 기준)"""
    if isinstance(node, Go):
        return {(0, 0)}
    if isinstance(node, Out):
        dc, dr = (1, 0) if node.right else (0, 1)
        return {(0, 0)} | {(c + dc, r + dr) for c, r in occ(node.next)}
    if isinstance(node, Opt):
        return {(0, 0), (1, 0)} | {(c, r + 1) for c, r in occ(node.next)}
    dn, rt = (node.zero, node.one) if node.down == 0 else (node.one, node.zero)
    k = right_offset(node)
    return {(0, 0)} | {(c, r + 1) for c, r in occ(dn)} | {(c + k, r) for c, r in occ(rt)}


def right_offset(dec):
    """오른쪽 갈래를 아래 갈래와 겹치지 않는 가장 가까운 열에 둔다"""
    dn, rt = (dec.zero, dec.one) if dec.down == 0 else (dec.one, dec.zero)
    d = {(0, 0)} | {(c, r + 1) for c, r in occ(dn)}
    R = occ(rt)
    k = 1
    while any((c + k, r) in d for c, r in R):
        k += 1
    return k


def asm_block(ctx, state):
    """ASM 블록 하나 → (svg, 폭, 높이)"""
    items, edges = [], []

    def add(kind, c, r, **kw):
        items.append(dict(kind=kind, c=c, r=r, **kw))
        return len(items) - 1

    def place(node, c, r):
        if isinstance(node, Go):
            return add("go", c, r, state=node.state)
        if isinstance(node, Out):
            i = add("out", c, r, lines=[ctx.fmt(a) for a in node.assigns])
            j = place(node.next, c + 1, r) if node.right else place(node.next, c, r + 1)
            edges.append(("right" if node.right else "down", i, j, ""))
            return i
        i = add("dec", c, r, lines=node.cond.split("\n"))
        if isinstance(node, Opt):
            o = add("out", c + 1, r, lines=[ctx.fmt(a) for a in node.assigns])
            j = place(node.next, c, r + 1)
            edges.extend([("right", i, o, "1"), ("down", i, j, "0"), ("merge", o, j, "")])
            return i
        dn, rt = (node.zero, node.one) if node.down == 0 else (node.one, node.zero)
        j = place(dn, c, r + 1)
        m = place(rt, c + right_offset(node), r)
        edges.extend([("down", i, j, str(node.down)), ("right", i, m, str(1 - node.down))])
        return i

    st = add("state", 0, 0, lines=[ctx.fmt(a) for a in ctx.spec["moore"][state]])
    edges.append(("down", st, place(ctx.spec["asm"][state], 0, 1), ""))

    for it in items:
        if it["kind"] == "state":
            it["w"] = max(220, max(tw(s, 13) for s in it["lines"]) + 40, tw(state, 15, False) + 90)
            it["h"] = 30 + 21 * len(it["lines"]) + 12
        elif it["kind"] == "dec":
            a = max(tw(s, 13) for s in it["lines"]) / 2 + 40
            b = max(30, (len(it["lines"]) * 17 / 2) / (1 - (a - 40) / a))
            it["w"], it["h"] = 2 * a, 2 * b
        elif it["kind"] == "out":
            it["w"], it["h"] = max(tw(s, 13) for s in it["lines"]) + 40, 20 * len(it["lines"]) + 18
        else:
            label = it["state"] + (" (유지)" if it["state"] == state else "")
            it["label"] = label
            it["w"], it["h"] = tw(label, 13, False) + 30, 30
    ncol = max(it["c"] for it in items) + 1
    nrow = max(it["r"] for it in items) + 1
    colW = [max([it["w"] for it in items if it["c"] == c] or [0]) for c in range(ncol)]
    rowH = [max([it["h"] for it in items if it["r"] == r] or [0]) for r in range(nrow)]
    PAD, TOP = 22, 74
    colX, x = [], PAD
    for wv in colW:
        colX.append(x)
        x += wv + COL_GAP
    rowY, y = [], TOP
    for hv in rowH:
        rowY.append(y)
        y += hv + ROW_GAP
    bw, bh = x - COL_GAP + PAD, y - ROW_GAP + PAD
    for it in items:
        it["x"] = colX[it["c"]] + colW[it["c"]] / 2
        it["y"] = rowY[it["r"]] + rowH[it["r"]] / 2

    col = ctx.color[state]
    s = [f'<rect x="0" y="0" width="{bw:.0f}" height="{bh:.0f}" rx="10" fill="#fbfcfe" stroke="{light(col, 0.55)}" '
         f'stroke-width="1.5"/>', T(PAD, 30, f"ASM 블록 — {state}", 17, col, weight="bold")]
    # 진입 화살표
    st_it = items[st]
    top = st_it["y"] - st_it["h"] / 2
    s.append(arrow([(st_it["x"], top - 30), (st_it["x"], top)]))
    if state == ctx.spec["reset"]:
        s.append(T(st_it["x"] + 10, top - 16, "i_rst (리셋 상태)", 12, "#c92a2a", weight="bold"))

    def bottom(it):
        return it["y"] + it["h"] / 2

    for kind, i, j, lab in edges:
        a, b = items[i], items[j]
        if kind == "down":
            s.append(arrow([(a["x"], bottom(a)), (b["x"], b["y"] - b["h"] / 2)]))
            if lab:
                s.append(T(a["x"] + 8, bottom(a) + 15, lab, 13, DEC_LINE, weight="bold", mono=True))
        elif kind == "right":
            s.append(arrow([(a["x"] + a["w"] / 2, a["y"]), (b["x"] - b["w"] / 2, b["y"])]))
            if lab:
                s.append(T(a["x"] + a["w"] / 2 + 6, a["y"] - 7, lab, 13, DEC_LINE, weight="bold", mono=True))
        else:  # merge: 조건 출력 박스 → 아래 줄 위 빈 칸에서 왼쪽 세로선에 합류
            ym = rowY[a["r"]] + rowH[a["r"]] + ROW_GAP / 2
            s.append(arrow([(a["x"], bottom(a)), (a["x"], ym), (b["x"] + 1, ym)], tip=False))
            s.append(f'<circle cx="{b["x"]:.1f}" cy="{ym:.1f}" r="3.5" fill="#444"/>')
    for it in items:
        x0, y0, w_, h_ = it["x"] - it["w"] / 2, it["y"] - it["h"] / 2, it["w"], it["h"]
        if it["kind"] == "state":
            s.append(f'<rect x="{x0:.1f}" y="{y0:.1f}" width="{w_:.1f}" height="{h_:.1f}" fill="{light(col, 0.9)}" '
                     f'stroke="{col}" stroke-width="2.2"/>'
                     f'<rect x="{x0:.1f}" y="{y0:.1f}" width="{w_:.1f}" height="30" fill="{col}"/>')
            s.append(T(x0 + 10, y0 + 21, state, 15, "#fff", weight="bold"))
            s.append(T(x0 + w_ - 10, y0 + 20, ctx.code(state), 13, "#fff", "end", mono=True))
            s.append(lines_at(it["x"], y0 + 30 + (h_ - 30) / 2, it["lines"], 13, lh=21))
        elif it["kind"] == "dec":
            pts = [(it["x"], y0), (x0 + w_, it["y"]), (it["x"], y0 + h_), (x0, it["y"])]
            s.append(f'<polygon points="{" ".join(f"{p:.1f},{q:.1f}" for p, q in pts)}" fill="{DEC_FILL}" '
                     f'stroke="{DEC_LINE}" stroke-width="1.8"/>')
            s.append(lines_at(it["x"], it["y"], it["lines"], 13, lh=17))
        elif it["kind"] == "out":
            s.append(f'<rect x="{x0:.1f}" y="{y0:.1f}" width="{w_:.1f}" height="{h_:.1f}" rx="{h_ / 2:.1f}" '
                     f'fill="{OUT_FILL}" stroke="{OUT_LINE}" stroke-width="1.8"/>')
            s.append(lines_at(it["x"], it["y"], it["lines"], 13, lh=20))
        else:
            gc = ctx.color[it["state"]]
            s.append(f'<rect x="{x0:.1f}" y="{y0:.1f}" width="{w_:.1f}" height="{h_:.1f}" rx="6" '
                     f'fill="{light(gc, 0.82)}" stroke="{gc}" stroke-width="1.5"/>')
            s.append(T(it["x"], it["y"] + 5, it["label"], 13, gc, "middle", "bold"))
    return "".join(s), bw, bh


def asm_legend(x, y):
    """ASM 기호 설명 한 줄"""
    s = []
    s.append(f'<rect x="{x}" y="{y}" width="44" height="26" fill="{light(STATE_COL[0], 0.9)}" stroke="{STATE_COL[0]}" '
             f'stroke-width="2"/><rect x="{x}" y="{y}" width="44" height="8" fill="{STATE_COL[0]}"/>')
    s.append(T(x + 54, y + 18, "상태 박스: 상태 이름 · 코드 + Moore 출력 (그 상태에 있는 동안 계속)", 14))
    x2 = x + 560
    s.append(f'<polygon points="{x2 + 24},{y - 2} {x2 + 50},{y + 13} {x2 + 24},{y + 28} {x2 - 2},{y + 13}" '
             f'fill="{DEC_FILL}" stroke="{DEC_LINE}" stroke-width="1.8"/>')
    s.append(T(x2 + 60, y + 18, "판단: 입력 조건 (1 / 0 갈래)", 14))
    x3 = x2 + 300
    s.append(f'<rect x="{x3}" y="{y}" width="48" height="26" rx="13" fill="{OUT_FILL}" stroke="{OUT_LINE}" '
             f'stroke-width="1.8"/>')
    s.append(T(x3 + 58, y + 18, "조건 출력 (Mealy): 그 클럭에 바로, 1 클럭 동안", 14))
    x4 = x3 + 430
    s.append(f'<rect x="{x4}" y="{y}" width="48" height="26" rx="6" fill="{light(STATE_COL[1], 0.82)}" '
             f'stroke="{STATE_COL[1]}" stroke-width="1.5"/>')
    s.append(T(x4 + 58, y + 18, "다음 상태 (다음 클럭 엣지에 c_state 가 됨)", 14))
    return "".join(s)


def page_asm(ctx, no, n_pages):
    blocks = [asm_block(ctx, st) for st in ctx.spec["states"]]
    GAP = 28
    total_w = sum(b[1] for b in blocks) + GAP * (len(blocks) - 1)
    max_h = max(b[2] for b in blocks)
    avail_w, avail_h = W - 60, H - 120 - 150
    k = min(1.35, avail_w / total_w, avail_h / max_h)
    x0 = 30 + (avail_w - total_w * k) / 2
    body = [f'<g transform="translate({x0:.1f},120) scale({k:.4f})">']
    x = 0
    for svg, bw, bh in blocks:
        body.append(f'<g transform="translate({x:.1f},0)">{svg}</g>')
        x += bw + GAP
    body.append("</g>")
    ly = H - 128
    body.append(asm_legend(40, ly))
    body.append(T(40, ly + 58, "표에 없는 출력 = 0 (기본값).  판단 순서 = RTL 의 if / else if 우선순위 (점으로 합류하는 판단은 서로 독립).  "
                  "<= 는 레지스터 (다음 클럭 엣지에 바뀜).", 14, "#444"))
    body.append(T(40, ly + 84, f"이 차트는 Verilator 로 RTL ({ctx.spec['file']}) 과 매 클럭 대조해서 같을 때만 만들어짐 "
                  "(상태 × 입력 조합 전부).", 14, "#444"))
    title = f"{ctx.spec['title']} 컨트롤 유닛 — ASM 차트"
    sub = f"{ctx.spec['inst']} ({ctx.spec['file']}) · 상태 {len(ctx.spec['states'])} 개 · ASM 블록 1 개 = 상태 1 개 (한 클럭)"
    return svg_page("".join(body), title, sub, no, n_pages)


# --------------------------------------------------------------------------- 상태도
R_ST = 88


def unit(dx, dy):
    L = math.hypot(dx, dy) or 1
    return dx / L, dy / L


def label_box(x, y, lines, size=14, color="#222", anchor="middle", mono=True, bg=True):
    w = max(tw(s, size, mono) for s in lines) + 10
    h = len(lines) * size * 1.3 + 6
    bx = x - w / 2 if anchor == "middle" else (x - 5 if anchor == "start" else x - w + 5)
    rect = (f'<rect x="{bx:.1f}" y="{y - h / 2:.1f}" width="{w:.1f}" height="{h:.1f}" rx="4" fill="#ffffff" '
            f'fill-opacity="0.92"/>') if bg else ""
    return rect + lines_at(x, y, lines, size, color, mono, lh=size * 1.3, anchor=anchor)


def anchor_for(ang):
    c = math.cos(ang)
    return "start" if c > 0.45 else ("end" if c < -0.45 else "middle")


def state_diagram(ctx):
    sp, dg = ctx.spec, ctx.spec["diagram"]
    pos = dg["pos"]
    s_edges, s_labels, s_nodes = [], [], []
    # 화살표 (src, dst) 마다 조건 모으기
    pairs = {}
    for src in sp["states"]:
        for cond, dst in sp["next"][src]:
            pairs.setdefault((src, dst), []).append(ctx.abbr(cond))
    for (src, dst), conds in pairs.items():
        if src == dst:
            continue
        (ax, ay), (bx, by) = pos[src], pos[dst]
        bend = dg["bend"].get((src, dst), 0)
        nx, ny = unit(-(by - ay), bx - ax)
        cx, cy = (ax + bx) / 2 + nx * bend, (ay + by) / 2 + ny * bend
        ux, uy = unit(cx - ax, cy - ay)
        p0 = (ax + ux * R_ST, ay + uy * R_ST)
        vx, vy = unit(cx - bx, cy - by)
        p1 = (bx + vx * (R_ST + 2), by + vy * (R_ST + 2))
        s_edges.append(f'<path d="M{p0[0]:.1f},{p0[1]:.1f} Q{cx:.1f},{cy:.1f} {p1[0]:.1f},{p1[1]:.1f}" fill="none" '
                       f'stroke="#444" stroke-width="2"/>' + head(p1[0], p1[1], math.atan2(-vy, -vx), "#444", 13))
        mx, my = 0.25 * p0[0] + 0.5 * cx + 0.25 * p1[0], 0.25 * p0[1] + 0.5 * cy + 0.25 * p1[1]
        sg = 1 if bend >= 0 else -1
        h = 18 * len(conds)
        wl = max(tw(c, 14) for c in conds)
        off = 10 + abs(nx) * wl / 2 + abs(ny) * h / 2
        s_labels.append(label_box(mx + nx * sg * off, my + ny * sg * off, conds, 14, "#1a1a1a"))
    # 자기 자신으로 (유지)
    for st, ang_d in dg["loops"].items():
        ang = math.radians(ang_d)
        cx, cy = pos[st]
        p = lambda a, r: (cx + r * math.cos(a), cy + r * math.sin(a))
        a0, a1 = ang - math.radians(24), ang + math.radians(24)
        q0, q1 = p(a0, R_ST), p(a1, R_ST + 2)
        c0, c1 = p(ang - math.radians(36), R_ST + 85), p(ang + math.radians(36), R_ST + 85)
        s_edges.append(f'<path d="M{q0[0]:.1f},{q0[1]:.1f} C{c0[0]:.1f},{c0[1]:.1f} {c1[0]:.1f},{c1[1]:.1f} '
                       f'{q1[0]:.1f},{q1[1]:.1f}" fill="none" stroke="#888" stroke-width="1.8"/>'
                       + head(q1[0], q1[1], math.atan2(q1[1] - c1[1], q1[0] - c1[0]), "#888", 12))
        conds = pairs[(st, st)]
        an = anchor_for(ang)
        if an == "middle":   # 위 · 아래 루프: 라벨은 루프 오른쪽 옆
            lx, ly = p(ang, R_ST + 40)
            s_labels.append(label_box(lx + 52, ly, conds, 14, "#666", "start"))
        else:
            lx, ly = p(ang, R_ST + 60)
            s_labels.append(label_box(lx + (8 if an == "start" else -8), ly, conds, 14, "#666", an))
    # 리셋
    rst, rang = dg["reset"]
    rang = math.radians(rang)
    cx, cy = pos[rst]
    r0 = (cx + (R_ST + 70) * math.cos(rang), cy + (R_ST + 70) * math.sin(rang))
    r1 = (cx + (R_ST + 2) * math.cos(rang), cy + (R_ST + 2) * math.sin(rang))
    s_edges.append(arrow([r0, r1], "#c92a2a", 2.2))
    s_edges.append(f'<circle cx="{r0[0]:.1f}" cy="{r0[1]:.1f}" r="4" fill="#c92a2a"/>')
    an = anchor_for(rang)
    s_labels.append(T(r0[0] + (-8 if an == "end" else 8 if an == "start" else 0),
                      r0[1] + (5 if an != "middle" else -10), "i_rst", 15, "#c92a2a", an, "bold", True))
    # Mealy 박스
    for sts, (bx, by) in dg["mealy"].items():
        rows = [(ctx.abbr(c), [ctx.fmt(a) for a in assigns]) for ss, c, assigns in sp["mealy"] if tuple(ss) == sts]
        lines = []
        for c, outs in rows:
            lines.append((c + "  →", "#7a5c00", 0))
            lines += [(o, "#0b7a5b", 26) for o in outs]
        hdr = "Mealy 출력 · " + " · ".join(sts)
        bw_ = max([tw(hdr, 14, False) + 24] + [tw(t, 13) + 28 + ind for t, _, ind in lines])
        bh_ = 34 + 19 * len(lines) + 8
        s_nodes.append(f'<rect x="{bx}" y="{by}" width="{bw_:.0f}" height="{bh_:.0f}" rx="6" fill="#fbfffd" '
                       f'stroke="{OUT_LINE}" stroke-width="1.5" stroke-dasharray="6 4"/>')
        s_nodes.append(T(bx + 12, by + 23, hdr, 14, OUT_LINE, weight="bold"))
        for i, (t, c, ind) in enumerate(lines):
            s_nodes.append(T(bx + 12 + ind, by + 48 + 19 * i, t, 13, c, mono=True))
        if len(sts) == 1:
            sx, sy = pos[sts[0]]
            tx, ty = min(max(sx, bx + 20), bx + bw_ - 20), (by if by > sy else by + bh_)
            ux, uy = unit(tx - sx, ty - sy)
            s_edges.append(arrow([(sx + ux * R_ST, sy + uy * R_ST), (tx, ty)], OUT_LINE, 1.4, False, "5 4"))
    # 상태 원
    for st in sp["states"]:
        cx, cy = pos[st]
        col = ctx.color[st]
        s_nodes.append(f'<circle cx="{cx}" cy="{cy}" r="{R_ST}" fill="{light(col, 0.9)}" stroke="{col}" '
                       f'stroke-width="3"/>')
        moore = [ctx.fmt(a).split("  (")[0] for a in sp["moore"][st]]
        n = len(moore)
        y0 = cy - (24 + 18 + 17 * n) / 2
        s_nodes.append(T(cx, y0 + 18, st, 19 if len(st) < 8 else 16, col, "middle", "bold"))
        s_nodes.append(T(cx, y0 + 38, ctx.code(st), 13, "#555", "middle", mono=True))
        for i, m in enumerate(moore):
            s_nodes.append(T(cx, y0 + 60 + 17 * i, m, 12, "#222", "middle", mono=True))
    return "".join(s_edges + s_nodes + s_labels)


def table(x, y, widths, header, rows, size=13):
    """rows: [[셀, ...]] — 셀 = 문자열 / 줄 리스트 / (줄 리스트, 색)"""
    out, cy = [], y
    tot = sum(widths)
    out.append(f'<rect x="{x}" y="{cy}" width="{tot}" height="28" fill="#eef3fb"/>')
    cx = x
    for wv, h_ in zip(widths, header):
        out.append(T(cx + 8, cy + 19, h_, 13, "#333", weight="bold"))
        cx += wv
    cy += 28
    for k, row in enumerate(rows):
        cells = []
        for c in row:
            if isinstance(c, tuple):
                cells.append(c)
            else:
                cells.append(([c] if isinstance(c, str) else c, "#222"))
        rh = max(len(ls) for ls, _ in cells) * 18 + 10
        if k % 2:
            out.append(f'<rect x="{x}" y="{cy}" width="{tot}" height="{rh}" fill="#f8f9fb"/>')
        cx = x
        for wv, (ls, color) in zip(widths, cells):
            for i, ln in enumerate(ls):
                bold = color != "#222" and wv == widths[0]
                out.append(T(cx + 8, cy + 18 + 18 * i, ln, size, color, weight="bold" if bold else "normal",
                             mono=True))
            cx += wv
        cy += rh
        out.append(f'<line x1="{x}" y1="{cy}" x2="{x + tot}" y2="{cy}" stroke="#e3e7ee"/>')
    return "".join(out), cy - y


def page_diagram(ctx, no, n_pages):
    sp = ctx.spec
    body = [f'<g transform="translate(20,110)">{state_diagram(ctx)}</g>']
    body.append(f'<line x1="1060" y1="115" x2="1060" y2="{H - 50}" stroke="#e3e7ee" stroke-width="1.5"/>')
    body.append(T(40, H - 46, "원 = 상태 (이름 · 코드 · Moore 출력) · 굵은 화살표 = 다음 클럭에 옮겨 가는 조건 · "
                  "가는 화살표 = 그대로 (유지) · 점선 = Mealy 출력", 13, "#666"))
    x, y = 1080, 112
    PW = W - 30 - x

    def head_(t):
        nonlocal y
        body.append(T(x, y + 22, t, 16, "#111", weight="bold"))
        y += 32

    head_("상태 · Moore 출력 (c_state 에 따라)")
    rows = []
    for st in sp["states"]:
        nm = st + (" (리셋)" if st == sp["reset"] else "")
        rows.append([([nm], ctx.color[st]), ctx.code(st), [ctx.fmt(a) for a in sp["moore"][st]]])
    t, h_ = table(x, y, [190, 80, PW - 270], ["상태", "코드", "Moore 출력"], rows)
    body.append(t)
    y += h_ + 18
    head_("다음 상태 n_state (위 줄부터 = 우선순위)")
    rows = []
    for st in sp["states"]:
        for i, (c, d) in enumerate(sp["next"][st]):
            rows.append([([st] if i == 0 else [""], ctx.color[st]),
                         "그 외" if c is ELSE else c.replace("\n", " "),
                         ([d + (" (유지)" if d == st else "")], ctx.color[d] if d != st else "#888")])
    t, h_ = table(x, y, [190, PW - 190 - 160, 160], ["c_state", "조건", "n_state"], rows, 12.5)
    body.append(t)
    y += h_ + 18
    head_("Mealy 출력 (조건이 1 인 그 클럭에 바로 · 표에 없는 출력 = 0)")
    rows = [[(list(sts), ctx.color[sts[0]]), c.split("\n"), [ctx.fmt(a) for a in assigns]]
            for sts, c, assigns in sp["mealy"]]
    t, h_ = table(x, y, [150, 270, PW - 420], ["c_state", "조건", "출력"], rows, 12.5)
    body.append(t)
    y += h_ + 18
    head_("상태도 약어 · 메모")
    body.append(T(x, y + 14, "   ".join(f"{v} = {k}" for k, v in sp["abbr"].items()), 13, "#333", mono=True))
    y += 30
    for n_ in sp["notes"]:
        body.append(T(x, y + 14, "• " + n_, 13, "#333"))
        y += 22
    if y > H - 40:
        sys.exit(f"[{sp['key']}] 오른쪽 표가 쪽을 넘침 (y={y:.0f})")
    ins = ", ".join(ctx.info["ins"])
    outs = ", ".join(ctx.info["outs"])
    title = f"{sp['title']} 컨트롤 유닛 — 상태도 (FSM)"
    sub = f"{sp['inst']} ({sp['file']}) · 입력 {ins} · 출력 {outs}"
    return svg_page("".join(body), title, sub, no, n_pages)


# --------------------------------------------------------------------------- 표지
def page_cover(ctxs, results, n_pages):
    b = []
    b.append(T(60, 150, "컨트롤 유닛 FSM — 상태도 · ASM 차트", 44, "#111", weight="bold"))
    b.append(T(62, 196, "verification_v2 · Top (stopwatch_watch) 안의 컨트롤 유닛 3 개 · 원본 source_file/*_control_unit.sv",
               18, "#555"))
    rows = []
    for i, c in enumerate(ctxs):
        sts = [f"{s} = {c.code(s)}" + (" (리셋)" if s == c.spec["reset"] else "") for s in c.spec["states"]]
        rows.append([([f"{2 + 2 * i} · {3 + 2 * i}"], "#333"), [c.spec["inst"], f"({c.spec['file']})"], sts,
                     c.info["ins"], c.info["outs"]])
    t, h_ = table(60, 240, [110, 400, 330, 300, 300], ["쪽", "인스턴스 (파일)", "상태 = 코드", "입력", "출력"], rows, 14)
    b.append(t)
    y = 240 + h_ + 50
    b.append(T(60, y, "읽는 법", 22, "#111", weight="bold"))
    y += 20
    # 상태도 기호
    b.append(f'<circle cx="110" cy="{y + 60}" r="40" fill="{light(STATE_COL[0], 0.9)}" stroke="{STATE_COL[0]}" stroke-width="3"/>')
    b.append(T(110, y + 56, "STOP", 15, STATE_COL[0], "middle", "bold") + T(110, y + 74, "1'b0", 12, "#555", "middle", mono=True))
    b.append(arrow([(155, y + 60), (245, y + 60)], "#444", 2))
    b.append(T(200, y + 50, "R", 14, "#111", "middle", mono=True))
    b.append(T(270, y + 48, "상태도: 원 = 상태 (이름 · enum 코드 · Moore 출력)", 16))
    b.append(T(270, y + 74, "화살표 = 그 조건이 1 이면 다음 클럭 엣지에 옮겨 감 (조건은 약어, 쪽마다 약어표)", 16))
    b.append(T(270, y + 100, "오른쪽 표 = 같은 내용을 포트 이름 그대로 (다음 상태 표는 위 줄이 우선)", 16))
    y += 150
    b.append(asm_legend(60, y))
    b.append(T(60, y + 56, "ASM 차트: 상태 1 개 = ASM 블록 1 개 = 한 클럭. 블록 안의 판단 순서 = RTL 의 if / else if 순서.",
               16))
    y += 110
    b.append(T(60, y, "타이밍 (Vivado 파형에서 c_state · n_state 로 보기)", 22, "#111", weight="bold"))
    for i, ln in enumerate([
            "n_state 는 조합 회로: 버튼 펄스 (10 ns) 가 들어온 그 클럭 동안 바로 바뀐다",
            "c_state 는 레지스터: 다음 클럭 엣지에 n_state 값이 되고, 이때 Moore 출력 (o_sw_run_stop, o_tm_run, o_wt_cursor …) 이 바뀐다",
            "Mealy 출력 (o_sw_clear, o_tm_add, o_tm_clear, o_wt_up, o_wt_down) 은 입력이 1 인 그 클럭에만 1 → 1 클럭 펄스",
            "버튼 입력은 debounce 뒤 1 클럭 펄스라 같은 클럭에 둘이 겹치는 일은 드물지만, 겹쳐도 차트의 우선순위대로 동작"]):
        b.append(T(76, y + 36 + 28 * i, "• " + ln, 16, "#333"))
    y += 36 + 28 * 4 + 30
    b.append(T(60, y, "그림 = 코드 보증", 22, "#111", weight="bold"))
    for i, ln in enumerate([
            "모든 그림 · 표는 diagram/gen_fsm.py 의 SPEC 하나에서 그림. 만들 때마다 아래를 확인하고, 하나라도 다르면 PDF 를 만들지 않음",
            "① enum 상태 이름 · 리셋 상태 · 입력 / 출력 포트를 RTL 파일에서 직접 읽어 SPEC 과 비교",
            "② 다음 상태 표: 상태마다 모든 입력 조합에서 조건이 정확히 하나만 맞음 / ASM 차트와 표가 같은 결과",
            "③ Verilator 로 RTL 을 무작위 입력으로 돌려 매 클럭 c_state · n_state · 출력이 ASM 차트와 같음:  "
            + " · ".join(f"{c.spec['title']} {N_CYCLES} 클럭 (조합 {results[c.spec['key']]} 개 전부)" for c in ctxs)]):
        b.append(T(76, y + 36 + 28 * i, "• " + ln if i == 0 else ln, 16, "#333"))
    return svg_page("".join(b), "", "", 1, n_pages).replace(
        f'<line x1="30" y1="98" x2="{W - 30}" y2="98" stroke="#d0d7e2" stroke-width="1.5"/>', "")


# --------------------------------------------------------------------------- 실행
def main():
    errs, ctxs, results = [], [], {}
    for sp in SPECS:
        info = parse_sv(sp["file"])
        e = check_static(sp, info)
        if not e:
            e, total = check_rtl(sp, info)
            results[sp["key"]] = total
        errs += [f"[{sp['file']}] " + x for x in e]
        ctxs.append(Ctx(sp, info))
    if errs:
        print("\n".join(errs))
        sys.exit("상태도 · ASM 차트 ↔ RTL 불일치 (PDF 안 만듦)")
    n_pages = 1 + 2 * len(ctxs)
    pages = [page_cover(ctxs, results, n_pages)]
    for i, c in enumerate(ctxs):
        pages.append(page_diagram(c, 2 + 2 * i, n_pages))
        pages.append(page_asm(c, 3 + 2 * i, n_pages))
    to_pdf([(p, W, H) for p in pages], OUT_PDF)
    if "--png" in sys.argv:
        d = sys.argv[sys.argv.index("--png") + 1]
        os.makedirs(d, exist_ok=True)
        for i, p in enumerate(pages):
            to_png(p, os.path.join(os.path.abspath(d), f"fsm_{i + 1}.png"), W, H)
    print(f"ok: RTL 대조 통과 ({', '.join(f'{k} {v} 조합' for k, v in results.items())}), "
          f"{os.path.relpath(OUT_PDF, HERE)} 생성 ({n_pages} 쪽)")
    if "--open" in sys.argv:
        subprocess.run(["explorer.exe", win(os.path.abspath(OUT_PDF))],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    main()
