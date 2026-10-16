#!/usr/bin/env python3
"""verification_v2 블록 다이어그램 생성기.

- source_file/ 의 Verilog 포트 목록을 직접 읽어서, 다이어그램 블록의 입력 · 출력 핀과
  이름 · 개수가 하나라도 다르면 멈춘다 (check_ports).
- 모든 입력 핀은 선 1 개 또는 깃발(clk · rst · 스위치) 1 개, 모든 출력 핀은 선 1 개 이상 (check_wiring).
- page_top()  : Top(stopwatch_watch) 전체
- page_fnd()  : U_FND_CONTROLLER 내부
- render(page, highlight={(블록, 포트): 단계번호}) 로 TB 별 색칠 그림을 만든다.

실행: python3 gen_diagram.py [--open]  → ../block_diagram.pdf (+ png/ 미리보기)
      --open : 만든 png 를 Windows 사진 앱으로 열기
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "source_file")

P = 24     # 핀 간격
HDR = 46   # 블록 머리(인스턴스 이름 · 모듈 이름) 높이

FONT = "'Malgun Gothic','Noto Sans KR','Apple SD Gothic Neo',sans-serif"
MONO = "Consolas,'D2Coding','Courier New',monospace"

COL = {
    "module_fill": "#eef3fb", "module_line": "#3b5b92",
    "assign_fill": "#f6f6f6", "assign_line": "#777777",
    "mux_fill": "#fff7e6", "mux_line": "#b7791f",
    "wire": "#4a4a4a", "bus": "#4a4a4a",
    "clk4k": "#7b3fbf", "tick": "#d6336c",
    "flag_clk": "#8a8a8a", "flag_sw": "#e8590c",
    "pin_in": "#fdf1e7", "pin_out": "#e9f7ef",
    "dim": "#c8c8c8",
}
# TB 단계 색 (1 단계부터)
STEP = ["#e03131", "#f08c00", "#2f9e44", "#1c7ed6", "#7048e8", "#c2255c", "#0c8599", "#5c940d", "#862e9c", "#495057", "#d9480f"]

SWITCHES = {"mode_sw0", "display_mode_sw1", "set_sw2", "hour24_sw3", "timer_sw4"}


# --------------------------------------------------------------------------- 모델
class Block:
    def __init__(self, bid, x, y, w, ins, outs, inst=None, module=None, kind="module",
                 title=None, note=None, sel=None, pin_y=None, h=None):
        self.id, self.x, self.y, self.w = bid, x, y, w
        self.ins = [p if isinstance(p, tuple) else (p, "") for p in ins]
        self.outs = [p if isinstance(p, tuple) else (p, "") for p in outs]
        self.sel = [p if isinstance(p, tuple) else (p, "") for p in (sel or [])]  # MUX 아래쪽 선택 입력
        self.inst, self.module, self.kind = inst, module, kind
        self.title, self.note = title, note
        self.pin_y = pin_y or {}
        n = max(len(self.ins), len(self.outs), 1)
        if kind == "mux":
            self.h = h or (30 + len(self.ins) * P + 6)
        elif kind == "or":
            self.h = h or 70
        else:
            self.h = h or (HDR + n * P + 10)

    def all_inputs(self):
        return [p for p, _ in self.ins] + [p for p, _ in self.sel]

    def all_outputs(self):
        return [p for p, _ in self.outs]

    def pin(self, port):
        """핀 좌표 (x, y, side)"""
        if port in self.pin_y:
            yy = self.pin_y[port]
            if any(port == p for p, _ in self.ins):
                return (self.x, yy, "L")
            return (self.x + self.w, yy, "R")
        for i, (p, _) in enumerate(self.ins):
            if p == port:
                if self.kind == "mux":
                    return (self.x, self.y + 30 + i * P, "L")
                if self.kind == "or":
                    return (self.x, self.y + 22 + i * 26, "L")
                return (self.x, self.y + HDR + i * P + P // 2, "L")
        for i, (p, _) in enumerate(self.sel):
            if p == port:
                n = len(self.sel)
                xx = self.x + self.w * (i + 1) / (n + 1)
                # 사다리꼴 아래 변 위의 점
                slope = self.w * 0.28 / self.w
                yy = self.y + self.h - (xx - self.x) * slope
                return (xx, yy, "B")
        for i, (p, _) in enumerate(self.outs):
            if p == port:
                if self.kind in ("mux", "or"):
                    return (self.x + self.w, self.y + self.h / 2, "R")
                return (self.x + self.w, self.y + HDR + i * P + P // 2, "R")
        raise KeyError(f"{self.id}.{port}")

    def width_of(self, port):
        for p, wd in self.ins + self.outs + self.sel:
            if p == port:
                return wd
        return ""


class Page:
    def __init__(self, name, title, W, H):
        self.name, self.title, self.W, self.H = name, title, W, H
        self.blocks = {}
        self.nets = []    # dict(name, src=(b,p), dsts=[(b,p,wps)], kind)
        self.flags = []   # (b, p, text, kind)
        self.notes = []   # (x, y, text, size, color)

    def add(self, b):
        self.blocks[b.id] = b
        return b

    def net(self, name, src, dsts, kind="wire", label_at=None):
        self.nets.append(dict(name=name, src=src, dsts=dsts, kind=kind, label_at=label_at))

    def flag(self, b, p, text=None, kind="clk"):
        self.flags.append((b, p, text or p, kind))


# --------------------------------------------------------------------------- Verilog 포트 읽기
def verilog_ports():
    mods = {}
    for fn in sorted(os.listdir(SRC)):
        if not fn.endswith((".v", ".sv")):
            continue
        text = open(os.path.join(SRC, fn), encoding="utf-8").read()
        text = re.sub(r"//.*", "", text)
        text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
        for m in re.finditer(r"\bmodule\s+(\w+)\s*(#\s*\(.*?\)\s*)?\((.*?)\);", text, re.S):
            name, body = m.group(1), m.group(3)
            ins, outs = [], []
            for d in re.finditer(r"\b(input|output)\b([^,;]*?)(\w+)\s*(?=,|$)", body.strip() + ",", re.S):
                (ins if d.group(1) == "input" else outs).append(d.group(3))
            mods[name] = (ins, outs)
    return mods


def check_ports(page, mods):
    errs = []
    if getattr(page, "boundary", None):
        mod, bin_, bout = page.boundary
        vin, vout = mods[mod]
        din, dout = page.blocks[bin_].all_outputs(), page.blocks[bout].all_inputs()
        if sorted(vin) != sorted(din) or sorted(vout) != sorted(dout):
            errs.append(f"{mod} 바깥 핀 불일치\n   Verilog in {vin} out {vout}\n   그림    in {din} out {dout}")
    for b in page.blocks.values():
        if not b.module:
            continue
        if b.module not in mods:
            errs.append(f"{b.id}: 모듈 {b.module} 이 source_file 에 없음")
            continue
        vin, vout = mods[b.module]
        din, dout = b.all_inputs(), b.all_outputs()
        if sorted(vin) != sorted(din):
            errs.append(f"{b.inst}({b.module}) 입력 불일치\n   Verilog {len(vin)}: {vin}\n   그림    {len(din)}: {din}")
        if sorted(vout) != sorted(dout):
            errs.append(f"{b.inst}({b.module}) 출력 불일치\n   Verilog {len(vout)}: {vout}\n   그림    {len(dout)}: {dout}")
    return errs


SW_SHORT = {"sw0": "mode_sw0", "sw1": "display_mode_sw1", "sw2": "set_sw2", "sw3": "hour24_sw3", "sw4": "timer_sw4"}


def verilog_conns(module_file):
    """인스턴스 이름 → {포트: 연결된 식}"""
    text = open(os.path.join(SRC, module_file), encoding="utf-8").read()
    text = re.sub(r"//.*", "", text)
    out = {}
    for m in re.finditer(r"\b\w+\s*(?:#\s*\((?:[^()]|\([^()]*\))*\))?\s*(U_\w+)\s*\(((?:[^;])*?)\);", text, re.S):
        out[m.group(1)] = {a: b.strip() for a, b in re.findall(r"\.(\w+)\s*\(((?:[^()]|\([^()]*\))*)\)", m.group(2))}
    return out


def check_conns(page, module_file, rename=None):
    """다이어그램의 선 이름이 Verilog 인스턴스 연결과 같은지 (모듈 블록만)"""
    rename = rename or {}
    conns = verilog_conns(module_file)
    net_at = {}
    for n in page.nets:
        net_at[n["src"]] = n["name"]
        for d in n["dsts"]:
            net_at[(d[0], d[1])] = n["name"]
    for b, p, t, k in page.flags:
        net_at[(b, p)] = SW_SHORT.get(t, t)
    errs = []
    for b in page.blocks.values():
        if not b.module or b.kind == "mux" and not b.inst:
            continue
        v = conns.get(b.inst)
        if v is None:
            errs.append(f"{b.inst}: {module_file} 에 인스턴스 없음")
            continue
        for p in b.all_inputs() + b.all_outputs():
            want = rename.get(net_at.get((b.id, p)), net_at.get((b.id, p)))
            got = v.get(p, "<없음>")
            if want != got and not (want and re.search(r"\b" + re.escape(want) + r"\b", got)):
                errs.append(f"{b.inst}.{p}: Verilog ({got}) ↔ 그림 ({want})")
    return errs


def check_assigns(page, module_file):
    """assign 블록(게이팅 · MUX · OR · LED): 그림의 입력 선 = Verilog assign 우변 신호"""
    text = re.sub(r"//.*", "", open(os.path.join(SRC, module_file), encoding="utf-8").read())
    rhs = {}
    for lhs, expr in re.findall(r"\bassign\s+([\w\[\]:]+)\s*=\s*(.*?);", text, re.S):
        rhs.setdefault(re.sub(r"\[.*", "", lhs), []).append(expr)
    errs = []
    for b in page.blocks.values():
        if b.module or b.kind in ("pins_in", "pins_out"):
            continue
        used = set()
        for o in b.all_outputs():
            if o not in rhs:
                errs.append(f"{b.title}: assign {o} 없음")
                continue
            for e in rhs[o]:
                used |= set(re.findall(r"\b(w_\w+|\w+_sw\d)\b", e))
        # 같은 블록의 다른 출력(w_alarm_blink 등 중간 와이어)은 펼쳐서 비교
        for mid in [u for u in used if u in rhs and u not in b.all_outputs() and not u.startswith("w_sel")
                    and u not in ("w_btn_R", "w_btn_L", "w_btn_U", "w_btn_D")]:
            if mid not in b.all_inputs():
                used.discard(mid)
                for e in rhs[mid]:
                    used |= set(re.findall(r"\b(w_\w+|\w+_sw\d)\b", e))
        din = set(b.all_inputs())
        if used != din:
            errs.append(f"{b.title}: assign 우변 {sorted(used)} ↔ 그림 입력 {sorted(din)}")
    return errs


def check_wiring(page):
    errs = []
    used_in, used_out = {}, {}
    for n in page.nets:
        used_out.setdefault(n["src"], []).append(n["name"])
        for d in n["dsts"]:
            used_in.setdefault((d[0], d[1]), []).append(n["name"])
    for b, p, t, k in page.flags:
        b_ = page.blocks[b]
        if p in b_.all_inputs():
            used_in.setdefault((b, p), []).append("flag:" + t)
        else:
            used_out.setdefault((b, p), []).append("flag:" + t)
    for b in page.blocks.values():
        for p in b.all_inputs():
            c = used_in.get((b.id, p), [])
            if len(c) != 1:
                errs.append(f"입력 {b.id}.{p}: 연결 {len(c)} 개 {c}")
        for p in b.all_outputs():
            if not used_out.get((b.id, p)):
                errs.append(f"출력 {b.id}.{p}: 연결 없음")
    for (b, p) in list(used_in) + list(used_out):
        page.blocks[b].pin(p)  # 없는 핀이면 KeyError
    return errs


# --------------------------------------------------------------------------- 그리기
def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def text(x, y, s, size=12, color="#222", anchor="start", weight="normal", mono=False, extra=""):
    fam = MONO if mono else FONT
    return (f'<text x="{x:.1f}" y="{y:.1f}" font-family="{fam}" font-size="{size}" fill="{color}" '
            f'text-anchor="{anchor}" font-weight="{weight}" {extra}>{esc(s)}</text>')


def path_points(page, src, dst, wps):
    sb, sp = src
    db, dp = dst
    sx, sy, _ = page.blocks[sb].pin(sp)
    dx, dy, side = page.blocks[db].pin(dp)
    pts = [(sx, sy)]
    cx, cy = sx, sy
    for i, v in enumerate(wps):
        if i % 2 == 0:
            cx = v
        else:
            cy = v
        pts.append((cx, cy))
    if side == "B":
        if len(wps) % 2 == 0:   # 마지막이 y → x 로 이동 후 아래에서 올라옴
            pts.append((dx, cy))
        else:
            pts.append((cx, dy + 30))
            pts.append((dx, dy + 30))
        pts.append((dx, dy))
    else:
        if len(wps) % 2 == 1:   # 마지막이 x
            pts.append((cx, dy))
        else:
            pts.append((dx - 0, cy))
        pts.append((dx, dy))
    # 중복 제거
    out = [pts[0]]
    for p in pts[1:]:
        if abs(p[0] - out[-1][0]) > 0.1 or abs(p[1] - out[-1][1]) > 0.1:
            out.append(p)
    return out


def render(page, highlight=None, steps_legend=None, subtitle=None):
    hl = highlight or {}
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{page.W}" height="{page.H}" '
           f'viewBox="0 0 {page.W} {page.H}">',
           f'<rect width="{page.W}" height="{page.H}" fill="#ffffff"/>',
           '<defs><marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
           'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="context-stroke"/></marker></defs>']
    svg.append(text(30, 42, page.title, 26, "#111", weight="bold"))
    if subtitle:
        svg.append(text(30, 70, subtitle, 15, "#444"))

    # 선 (블록보다 먼저)
    hl_nets = {}
    for n in page.nets:
        if n["src"] in hl:
            hl_nets[n["name"]] = hl[n["src"]]
    wire_svg, label_svg, dot_svg = [], [], []
    for n in page.nets:
        base = COL["wire"]
        if n["kind"] == "clk4k":
            base = COL["clk4k"]
        elif n["kind"] == "tick":
            base = COL["tick"]
        sb = page.blocks[n["src"][0]]
        wd = sb.width_of(n["src"][1])
        sw = 3.0 if wd else 1.6
        net_step = hl_nets.get(n["name"])
        any_hl = bool(hl)
        for (db, dp, wps) in n["dsts"]:
            step = net_step or hl.get((db, dp))
            color = STEP[(step - 1) % len(STEP)] if step else (COL["dim"] if any_hl else base)
            w_ = sw + (1.6 if step else 0)
            pts = path_points(page, n["src"], (db, dp), wps)
            d = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
            wire_svg.append(f'<polyline points="{d}" fill="none" stroke="{color}" stroke-width="{w_}" '
                            f'stroke-linejoin="round" marker-end="url(#arr)"/>')
            if len(n["dsts"]) > 1 and len(pts) >= 3:
                x, y = pts[1]
                dot_svg.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3.2" fill="{color}"/>')
        # 선 이름 (출발점 바로 옆) — 모듈 출력만. assign · 핀 블록은 핀 이름이 곧 선 이름
        if sb.kind != "module" and not n["label_at"]:
            continue
        sx, sy, _ = sb.pin(n["src"][1])
        lx, ly = (n["label_at"] if n["label_at"] else (sx + 6 + (22 if net_step else 0), sy - 4))
        col = STEP[(net_step - 1) % len(STEP)] if net_step else ("#999" if hl else "#555")
        label_svg.append(text(lx, ly, n["name"], 10.5, col, mono=True,
                              weight="bold" if net_step else "normal"))
    svg += wire_svg + dot_svg

    # 블록
    for b in page.blocks.values():
        svg += draw_block(b, hl)

    # 깃발
    for b, p, t, k in page.flags:
        x, y, side = page.blocks[b].pin(p)
        step = hl.get((b, p))
        if not step and k == "sw":   # 보드 스위치 핀이 칠해졌으면 그 스위치 깃발도 같은 색
            step = hl.get(("PIN_IN", SW_SHORT.get(t, t)))
        if not step and k == "clk" and t in ("clk", "rst"):   # clk · rst 핀이 칠해졌으면 모든 블록의 clk · rst 깃발도
            step = hl.get(("PIN_IN", t))
        c = COL["flag_sw"] if k == "sw" else COL["flag_clk"]
        if step:
            c = STEP[(step - 1) % len(STEP)]
        elif hl:
            c = COL["dim"] if k != "sw" else "#f4b183"
        tw = 7.0 * len(t) + 14
        if page.blocks[b].kind == "pins_in":
            # 보드 입력 핀: 짧은 선 + 동그라미 (깃발로 퍼져 나감)
            svg.append(f'<line x1="{x}" y1="{y}" x2="{x + 22}" y2="{y}" stroke="{c}" stroke-width="2"/>')
            svg.append(f'<circle cx="{x + 26}" cy="{y}" r="4.5" fill="#fff" stroke="{c}" stroke-width="2"/>')
            continue
        if side == "L":
            x0 = x - 18 - tw
            svg.append(f'<polygon points="{x0},{y-8} {x0+tw},{y-8} {x0+tw+8},{y} {x0+tw},{y+8} {x0},{y+8}" '
                       f'fill="#fff" stroke="{c}" stroke-width="1.4"/>')
            svg.append(f'<line x1="{x0+tw+8}" y1="{y}" x2="{x}" y2="{y}" stroke="{c}" stroke-width="1.4"/>')
            svg.append(text(x0 + 6, y + 4, t, 10.5, c, mono=True, weight="bold"))
        elif side == "R":
            x0 = x + 18
            svg.append(f'<line x1="{x}" y1="{y}" x2="{x0}" y2="{y}" stroke="{c}" stroke-width="1.4"/>')
            svg.append(f'<polygon points="{x0},{y} {x0+8},{y-8} {x0+8+tw},{y-8} {x0+8+tw},{y+8} {x0+8},{y+8}" '
                       f'fill="#fff" stroke="{c}" stroke-width="1.4"/>')
            svg.append(text(x0 + 14, y + 4, t, 10.5, c, mono=True, weight="bold"))
        else:  # B (MUX 선택)
            y0 = y + 14
            svg.append(f'<line x1="{x}" y1="{y}" x2="{x}" y2="{y0}" stroke="{c}" stroke-width="1.4"/>')
            svg.append(f'<rect x="{x - tw/2:.1f}" y="{y0}" width="{tw:.1f}" height="16" rx="3" fill="#fff" '
                       f'stroke="{c}" stroke-width="1.4"/>')
            svg.append(text(x, y0 + 12, t, 10, c, anchor="middle", mono=True, weight="bold"))

    svg += label_svg

    # 단계 번호 동그라미
    for (b, p), step in hl.items():
        x, y, side = page.blocks[b].pin(p)
        c = STEP[(step - 1) % len(STEP)]
        if side == "L":
            cx, cy = x + 2, y - 14
        elif side == "R":
            cx, cy = x + 13, y - 11
        else:
            cx, cy = x + 14, y + 8
        svg.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="11" fill="{c}" stroke="#fff" stroke-width="2"/>')
        svg.append(text(cx, cy + 4.5, str(step), 13, "#fff", anchor="middle", weight="bold"))

    for x, y, s, size, color in page.notes:
        svg.append(text(x, y, s, size, color))

    if steps_legend:
        svg += draw_legend(page, steps_legend)
    svg.append("</svg>")
    return "\n".join(svg)


def draw_legend(page, steps):
    out = []
    x0, y0, w = getattr(page, "legend_xyw", (page.W - 640, 96, 620))
    h = 26 + 22 * len(steps)
    out.append(f'<rect x="{x0}" y="{y0}" width="{w}" height="{h}" rx="8" fill="#ffffff" stroke="#999" stroke-width="1"/>')
    for i, s in enumerate(steps):
        c = STEP[i % len(STEP)]
        yy = y0 + 22 + i * 22
        out.append(f'<circle cx="{x0 + 18}" cy="{yy - 4}" r="9" fill="{c}"/>')
        out.append(text(x0 + 18, yy, str(i + 1), 11, "#fff", anchor="middle", weight="bold"))
        out.append(text(x0 + 36, yy, s, 12.5, "#222"))
    return out


def draw_block(b, hl):
    out = []
    if b.kind == "mux":
        s = b.w * 0.28
        pts = f"{b.x},{b.y} {b.x + b.w},{b.y + s} {b.x + b.w},{b.y + b.h - s} {b.x},{b.y + b.h}"
        out.append(f'<polygon points="{pts}" fill="{COL["mux_fill"]}" stroke="{COL["mux_line"]}" stroke-width="2"/>')
        out.append(text(b.x + b.w / 2, b.y + b.h / 2 - 2, "MUX", 12, COL["mux_line"], anchor="middle", weight="bold"))
        if b.title:
            out.append(text(b.x + b.w / 2, b.y - 8, b.title, 11.5, "#7a4d00", anchor="middle", weight="bold"))
        for i, (p, wd) in enumerate(b.ins):
            x, y, _ = b.pin(p)
            out.append(text(x + 4, y + 4, str(i), 9.5, "#7a4d00"))
        if b.note:
            for i, line in enumerate(b.note.split("\n")):
                out.append(text(b.x + b.w / 2, b.y + b.h + 44 + i * 13, line, 10, "#7a4d00", anchor="middle"))
        return out
    if b.kind == "or":
        x, y, w, h = b.x, b.y, b.w, b.h
        out.append(f'<path d="M{x},{y} Q{x + w*0.35},{y + h/2} {x},{y + h} Q{x + w*0.7},{y + h} {x + w},{y + h/2} '
                   f'Q{x + w*0.7},{y} {x},{y} z" fill="{COL["mux_fill"]}" stroke="{COL["mux_line"]}" stroke-width="2"/>')
        out.append(text(x + w * 0.45, y + h / 2 + 4, "OR", 11, COL["mux_line"], anchor="middle", weight="bold"))
        if b.title:
            out.append(text(x + w / 2, y - 8, b.title, 11.5, "#7a4d00", anchor="middle", weight="bold"))
        return out

    fill, line, dash = COL["module_fill"], COL["module_line"], ""
    if b.kind == "assign":
        fill, line, dash = COL["assign_fill"], COL["assign_line"], 'stroke-dasharray="6,4"'
    elif b.kind == "pins_in":
        fill, line = COL["pin_in"], "#c05621"
    elif b.kind == "pins_out":
        fill, line = COL["pin_out"], "#2f855a"
    out.append(f'<rect x="{b.x}" y="{b.y}" width="{b.w}" height="{b.h}" rx="8" fill="{fill}" stroke="{line}" '
               f'stroke-width="2" {dash}/>')
    if b.kind in ("pins_in", "pins_out"):
        out.append(text(b.x + b.w / 2, b.y + 20, b.title, 13, line, anchor="middle", weight="bold"))
    elif b.kind == "assign":
        out.append(text(b.x + b.w / 2, b.y + 19, b.title, 13, "#333", anchor="middle", weight="bold"))
        out.append(text(b.x + b.w / 2, b.y + 36, "(Top 안 assign)", 10.5, "#777", anchor="middle"))
    else:
        out.append(text(b.x + b.w / 2, b.y + 19, b.inst, 13, "#1a2f55", anchor="middle", weight="bold", mono=True))
        out.append(text(b.x + b.w / 2, b.y + 36, b.module, 11, "#5a6d8f", anchor="middle", mono=True))
    pin_col = line
    for p, wd in b.ins:
        x, y, _ = b.pin(p)
        step = hl.get((b.id, p))
        c = STEP[(step - 1) % len(STEP)] if step else "#222"
        out.append(f'<rect x="{x - 3}" y="{y - 3}" width="6" height="6" fill="{pin_col}"/>')
        out.append(text(x + 7, y + 4, p + wd, 11, c, mono=True, weight="bold" if step else "normal"))
    for p, wd in b.outs:
        x, y, _ = b.pin(p)
        step = hl.get((b.id, p))
        c = STEP[(step - 1) % len(STEP)] if step else "#222"
        out.append(f'<rect x="{x - 3}" y="{y - 3}" width="6" height="6" fill="{pin_col}"/>')
        out.append(text(x - 7, y + 4, p + wd, 11, c, anchor="end", mono=True, weight="bold" if step else "normal"))
    if b.note:
        for i, line_ in enumerate(b.note.split("\n")):
            out.append(text(b.x + b.w / 2, b.y + b.h + 15 + i * 13, line_, 10, "#555", anchor="middle"))
    return out


# --------------------------------------------------------------------------- 페이지 1: Top
def page_top():
    pg = Page("top", "stopwatch_watch (Top) — 블록 다이어그램 · 포트 이름 = 선 이름", 2830, 1440)
    B = pg.add

    # 열 x (블록 왼쪽 변)
    XA, XB, XC, XD, XE, XF, XG, XH = 280, 570, 880, 1180, 1570, 2000, 2260, 2680
    WA, WB, WC, WD, WE, WG = 210, 200, 190, 250, 260, 270

    # ---------------- 블록
    B(Block("CLKGEN", XA, 130, WA, ["i_clk", "i_rst"], ["o_clk_4khz"],
            inst="U_CLK_GEN_4KHZ", module="clock_tick_generator",
            note="o_clk_4khz: 250 us 마다 10 ns 펄스"))
    B(Block("TICKGEN", XA, 280, WA, ["i_clk", "i_rst"], ["o_tick_10ms"],
            inst="U_TICK_GEN_100HZ", module="tick_gen_100hz",
            note="o_tick_10ms: 10 ms 마다 10 ns 펄스"))
    bds = {}
    for i, k in enumerate("RLUD"):
        bds[k] = B(Block("BD_" + k, XB, 420 + i * 170, WB, ["i_clk", "i_rst", "i_clk_4khz", "i_btn"], ["o_btn"],
                         inst="U_BD_" + k, module="btn_debounce"))
    B(Block("SEL", XB, 1130, WB, ["mode_sw0", "timer_sw4"], ["w_sel_sw", "w_sel_wt", "w_sel_tm"],
            kind="assign", title="화면 선택",
            note="w_sel_tm = timer_sw4\nw_sel_sw = ~timer_sw4 & mode_sw0\nw_sel_wt = ~timer_sw4 & ~mode_sw0"))
    for i, (dom, nm) in enumerate([("sw", "스톱워치"), ("wt", "시계"), ("tm", "타이머")]):
        B(Block("GATE_" + dom.upper(), XC, 420 + i * 230, WC,
                ["w_btn_R", "w_btn_L", "w_btn_U", "w_btn_D", "w_sel_" + dom],
                [f"w_{dom}_btn_{k}" for k in "RLUD"],
                kind="assign", title=f"버튼 게이팅 ({nm})",
                note=f"w_{dom}_btn_X = w_btn_X & w_sel_{dom}"))
    pin_in = ["clk", "rst", "btn_R", "btn_L", "btn_U", "btn_D",
              "mode_sw0", "display_mode_sw1", "set_sw2", "hour24_sw3", "timer_sw4"]
    pins = B(Block("PIN_IN", 20, 110, 150, [], pin_in, kind="pins_in", title="Top 입력 (보드)", h=1250))
    py = {"clk": 160, "rst": 190}
    for k in "RLUD":
        py["btn_" + k] = bds[k].pin("i_btn")[1]
    for i, s in enumerate(["mode_sw0", "display_mode_sw1", "set_sw2", "hour24_sw3", "timer_sw4"]):
        py[s] = 1170 + i * 36
    pins.pin_y = py

    B(Block("SCU", XD, 400, WD, ["i_clk", "i_rst", "i_sw_btn_R", "i_sw_btn_L", "i_sw_btn_U"],
            ["o_sw_run_stop", "o_sw_clear", "o_sw_down"],
            inst="U_STOPWATCH_CONTROL_UNIT", module="stopwatch_control_unit"))
    B(Block("WCU", XD, 640, WD, ["i_clk", "i_rst", "i_wt_btn_R", "i_wt_btn_L", "i_wt_btn_U", "i_wt_btn_D", "i_set_sw2"],
            [("o_wt_cursor", "[1:0]"), "o_wt_up", "o_wt_down"],
            inst="U_WATCH_CONTROL_UNIT", module="watch_control_unit"))
    B(Block("TCU", XD, 900, WD, ["i_clk", "i_rst", "i_tm_btn_R", "i_tm_btn_L", "i_tm_btn_U", "i_tm_btn_D", "i_tm_zero"],
            ["o_tm_run", "o_tm_alarm", "o_tm_clear", "o_tm_add", ("o_tm_amount", "[1:0]")],
            inst="U_TIMER_CONTROL_UNIT", module="timer_control_unit"))

    B(Block("SDP", XE, 380, WE, ["i_clk", "i_rst", "i_tick_10ms", "i_sw_run_stop", "i_sw_clear", "i_sw_down", "i_sw_btn_D"],
            [("o_sw_msec", "[6:0]"), ("o_sw_sec", "[5:0]"), ("o_sw_min", "[5:0]"), ("o_sw_hour", "[4:0]"), "o_sw_lap"],
            inst="U_STOPWATCH_DATAPATH", module="stopwatch_datapath"))
    B(Block("WDP", XE, 670, WE, ["i_clk", "i_rst", "i_tick_10ms", ("i_wt_cursor", "[1:0]"), "i_wt_up", "i_wt_down"],
            [("o_wt_msec", "[6:0]"), ("o_wt_sec", "[5:0]"), ("o_wt_min", "[5:0]"), ("o_wt_hour", "[4:0]")],
            inst="U_WATCH_DATAPATH", module="watch_datapath"))
    B(Block("H1224", XE, 905, WE, [("i_wt_hour", "[4:0]"), "i_hour24_sw3"],
            [("o_wt_hour_disp", "[4:0]"), "o_wt_pm"],
            inst="U_HOUR_12_24", module="hour_12_24"))
    B(Block("TDP", XE, 1050, WE, ["i_clk", "i_rst", "i_tick_10ms", "i_tm_run", "i_tm_clear", "i_tm_add", ("i_tm_amount", "[1:0]")],
            [("o_tm_msec", "[6:0]"), ("o_tm_sec", "[5:0]"), ("o_tm_min", "[5:0]"), "o_tm_zero"],
            inst="U_TIMER_DATAPATH", module="timer_datapath"))

    # 화면 MUX (assign) : 입력 0 = 타이머, 1 = 스톱워치, 2 = 시계
    mux_note = "sw4 = 1 → 0 (타이머)\nsw4 = 0, sw0 = 1 → 1 (스톱워치)\nsw4 = 0, sw0 = 0 → 2 (시계)"
    for i, (bid, ins, out) in enumerate([
            ("M_MSEC", ["w_tm_msec", "w_sw_msec", "w_wt_msec"], "w_disp_msec"),
            ("M_SEC", ["w_tm_sec", "w_sw_sec", "w_wt_sec"], "w_disp_sec"),
            ("M_MIN", ["w_tm_sec", "w_sw_min", "w_wt_min"], "w_disp_min"),
            ("M_HOUR", ["w_tm_min", "w_sw_hour", "w_wt_hour_disp"], "w_disp_hour")]):
        B(Block(bid, XF, 300 + i * 170, 80, ins, [out], kind="mux", title=out, sel=["timer_sw4", "mode_sw0"]))
    B(Block("OR_MODE", XF, 1200, 80, ["timer_sw4", "display_mode_sw1"], ["w_disp_mode"],
            kind="or", title="w_disp_mode"))

    fnd = B(Block("FND", XG, 330, WG, ["i_rst", "i_clk_4khz", ("i_disp_msec", "[6:0]"), ("i_disp_sec", "[5:0]"),
                                        ("i_disp_min", "[5:0]"), ("i_disp_hour", "[5:0]"), "i_disp_mode",
                                        ("i_wt_cursor", "[1:0]"), "i_sel_wt", "i_set_sw2"],
                  [("o_fnd_com", "[3:0]"), ("o_fnd_font", "[7:0]")],
                  inst="U_FND_CONTROLLER", module="SW2_FND_CONTROLLER", note="내부는 2 쪽"))
    led = B(Block("LED", XG, 800, WG, ["w_tm_alarm", "w_tm_run", ("w_wt_msec", "[6:0]"), "w_wt_pm", "w_sel_wt",
                                        "w_sel_sw", "w_sel_tm", "w_sw_lap", "display_mode_sw1", "timer_sw4", "hour24_sw3"],
                  [("led", "[15:0]")], kind="assign", title="LED 출력",
                  note="알람 중: 16 개 전부 (w_wt_msec ≥ 50) 일 때 켬\n평소: led0 시계 · led1 스톱워치 · led2 시.분 · led3 초.1/100초\nled5 타이머 · led6 타이머 동작 · led7 랩 · led15 오후"))
    pout = B(Block("PIN_OUT", XH, 330, 130, ["fnd_com", "fnd_font", "led"], [], kind="pins_out",
                   title="Top 출력 (보드)", h=640,
                   pin_y={"fnd_com": fnd.pin("o_fnd_com")[1], "fnd_font": fnd.pin("o_fnd_font")[1],
                          "led": led.pin("led")[1]}))
    pout.ins = [("fnd_com", "[3:0]"), ("fnd_font", "[7:0]"), ("led", "[15:0]")]

    # ---------------- 깃발: clk / rst / 스위치
    pg.flag("PIN_IN", "clk", "clk", "clk")
    pg.flag("PIN_IN", "rst", "rst", "clk")
    for s in ["mode_sw0", "display_mode_sw1", "set_sw2", "hour24_sw3", "timer_sw4"]:
        pg.flag("PIN_IN", s, s, "sw")
    for b in pg.blocks.values():
        for p in b.all_inputs():
            if p in ("i_clk", "i_rst"):
                pg.flag(b.id, p, p[2:], "clk")
    for b, p, s in [("SEL", "mode_sw0", "sw0"), ("SEL", "timer_sw4", "sw4"),
                    ("WCU", "i_set_sw2", "sw2"), ("H1224", "i_hour24_sw3", "sw3"),
                    ("FND", "i_set_sw2", "sw2"),
                    ("OR_MODE", "timer_sw4", "sw4"), ("OR_MODE", "display_mode_sw1", "sw1"),
                    ("LED", "display_mode_sw1", "sw1"), ("LED", "timer_sw4", "sw4"),
                    ("LED", "hour24_sw3", "sw3")]:
        pg.flag(b, p, s, "sw")
    for m in ["M_MSEC", "M_SEC", "M_MIN", "M_HOUR"]:
        pg.flag(m, "timer_sw4", "sw4", "sw")
        pg.flag(m, "mode_sw0", "sw0", "sw")

    # ---------------- 선 (waypoint: x, y, x ... 순서)
    gAB, gBC, gCD, gDE, gEF, gFG = XA + WA, XB + WB, XC + WC, XD + WD, XE + WE, XF + 80
    for k in "RLUD":
        pg.net("btn_" + k, ("PIN_IN", "btn_" + k), [("BD_" + k, "i_btn", [])])
    pg.net("w_clk_4khz", ("CLKGEN", "o_clk_4khz"),
           [("BD_" + k, "i_clk_4khz", [gAB + 40]) for k in "RLUD"] +
           [("FND", "i_clk_4khz", [gAB + 40, 96, XG - 40])], kind="clk4k")
    pg.net("w_tick_10ms", ("TICKGEN", "o_tick_10ms"),
           [(d, "i_tick_10ms", [gAB + 56, 110, XE - 22]) for d in ("SDP", "WDP", "TDP")], kind="tick")
    for i, k in enumerate("RLUD"):
        pg.net("w_btn_" + k, ("BD_" + k, "o_btn"),
               [(g, "w_btn_" + k, [gBC + 22 + i * 14]) for g in ["GATE_SW", "GATE_WT", "GATE_TM"]])
    pg.net("w_sel_sw", ("SEL", "w_sel_sw"),
           [("GATE_SW", "w_sel_sw", [gBC + 12]), ("LED", "w_sel_sw", [gBC + 12, 1386, XG - 16])])
    pg.net("w_sel_wt", ("SEL", "w_sel_wt"),
           [("GATE_WT", "w_sel_wt", [gBC + 84]), ("FND", "i_sel_wt", [gBC + 84, 1398, XG - 64]),
            ("LED", "w_sel_wt", [gBC + 84, 1398, XG - 64])])
    pg.net("w_sel_tm", ("SEL", "w_sel_tm"),
           [("GATE_TM", "w_sel_tm", [gBC + 98]), ("LED", "w_sel_tm", [gBC + 98, 1410, XG - 10])])
    for i, k in enumerate("RLU"):
        pg.net(f"w_sw_btn_{k}", ("GATE_SW", f"w_sw_btn_{k}"), [("SCU", f"i_sw_btn_{k}", [gCD + 22 + i * 16])])
    pg.net("w_sw_btn_D", ("GATE_SW", "w_sw_btn_D"), [("SDP", "i_sw_btn_D", [gCD + 70, 370, gDE + 22])])
    for dom, cu in [("wt", "WCU"), ("tm", "TCU")]:
        for i, k in enumerate("RLUD"):
            pg.net(f"w_{dom}_btn_{k}", (f"GATE_{dom.upper()}", f"w_{dom}_btn_{k}"),
                   [(cu, f"i_{dom}_btn_{k}", [gCD + 22 + i * 16])])
    c1, c2, c3, c4 = gDE + 40, gDE + 56, gDE + 72, gDE + 88
    pg.net("w_sw_run_stop", ("SCU", "o_sw_run_stop"), [("SDP", "i_sw_run_stop", [c2])])
    pg.net("w_sw_clear", ("SCU", "o_sw_clear"), [("SDP", "i_sw_clear", [c3])])
    pg.net("w_sw_down", ("SCU", "o_sw_down"), [("SDP", "i_sw_down", [c4])])
    pg.net("w_wt_cursor", ("WCU", "o_wt_cursor"),
           [("WDP", "i_wt_cursor", [c2]), ("FND", "i_wt_cursor", [c2, 643, XG - 52])])
    pg.net("w_wt_up", ("WCU", "o_wt_up"), [("WDP", "i_wt_up", [c3])])
    pg.net("w_wt_down", ("WCU", "o_wt_down"), [("WDP", "i_wt_down", [c4])])
    pg.net("w_wt_hour", ("WDP", "o_wt_hour"), [("H1224", "i_wt_hour", [gEF + 14, 885, XE - 10])])
    pg.net("w_tm_run", ("TCU", "o_tm_run"),
           [("TDP", "i_tm_run", [c1]), ("LED", "w_tm_run", [c1, 1350, XG - 28])])
    pg.net("w_tm_alarm", ("TCU", "o_tm_alarm"), [("LED", "w_tm_alarm", [gDE + 24, 1338, XG - 40])])
    pg.net("w_tm_clear", ("TCU", "o_tm_clear"), [("TDP", "i_tm_clear", [c2])])
    pg.net("w_tm_add", ("TCU", "o_tm_add"), [("TDP", "i_tm_add", [c3])])
    pg.net("w_tm_amount", ("TCU", "o_tm_amount"), [("TDP", "i_tm_amount", [c4])])
    pg.net("w_tm_zero", ("TDP", "o_tm_zero"), [("TCU", "i_tm_zero", [gEF + 20, 1300, XD - 22])])
    # 데이터패스 → 화면 MUX
    ch = iter(range(gEF + 60, gEF + 400, 11))
    def to_mux(name, src, mux, port, extra=None):
        x = next(ch)
        d = [(mux, port, [x])]
        if extra:
            d += extra(x)
        pg.net(name, src, d)
    to_mux("w_sw_msec", ("SDP", "o_sw_msec"), "M_MSEC", "w_sw_msec")
    to_mux("w_sw_sec", ("SDP", "o_sw_sec"), "M_SEC", "w_sw_sec")
    to_mux("w_sw_min", ("SDP", "o_sw_min"), "M_MIN", "w_sw_min")
    to_mux("w_sw_hour", ("SDP", "o_sw_hour"), "M_HOUR", "w_sw_hour")
    pg.net("w_sw_lap", ("SDP", "o_sw_lap"), [("LED", "w_sw_lap", [gEF + 30, 1362, XG - 34])])
    to_mux("w_wt_msec", ("WDP", "o_wt_msec"), "M_MSEC", "w_wt_msec",
           extra=lambda x: [("LED", "w_wt_msec", [x, 1374, XG - 46])])
    to_mux("w_wt_sec", ("WDP", "o_wt_sec"), "M_SEC", "w_wt_sec")
    to_mux("w_wt_min", ("WDP", "o_wt_min"), "M_MIN", "w_wt_min")
    to_mux("w_wt_hour_disp", ("H1224", "o_wt_hour_disp"), "M_HOUR", "w_wt_hour_disp")
    pg.net("w_wt_pm", ("H1224", "o_wt_pm"), [("LED", "w_wt_pm", [gEF + 40, 1326, XG - 22])])
    to_mux("w_tm_msec", ("TDP", "o_tm_msec"), "M_MSEC", "w_tm_msec")
    xs = next(ch)
    pg.net("w_tm_sec", ("TDP", "o_tm_sec"), [("M_SEC", "w_tm_sec", [xs]), ("M_MIN", "w_tm_sec", [xs])])
    to_mux("w_tm_min", ("TDP", "o_tm_min"), "M_HOUR", "w_tm_min")
    # MUX → FND
    for m, port, x in [("M_MSEC", "i_disp_msec", gFG + 34), ("M_SEC", "i_disp_sec", gFG + 50),
                       ("M_MIN", "i_disp_min", gFG + 66), ("M_HOUR", "i_disp_hour", gFG + 82)]:
        nm = pg.blocks[m].outs[0][0]
        pg.net(nm, (m, nm), [("FND", port, [x])])
    pg.net("w_disp_mode", ("OR_MODE", "w_disp_mode"), [("FND", "i_disp_mode", [gFG + 18])])
    pg.net("fnd_com", ("FND", "o_fnd_com"), [("PIN_OUT", "fnd_com", [])])
    pg.net("fnd_font", ("FND", "o_fnd_font"), [("PIN_OUT", "fnd_font", [])])
    pg.net("led", ("LED", "led"), [("PIN_OUT", "led", [])])

    pg.notes.append((30, 1432, "회색 깃발 clk · rst = Top 핀 clk · rst 직결 / 주황 깃발 swN = 보드 스위치 핀 직결 "
                     "(sw0 mode_sw0 · sw1 display_mode_sw1 · sw2 set_sw2 · sw3 hour24_sw3 · sw4 timer_sw4) / "
                     "보라 선 = 4 kHz (250 us) / 분홍 선 = 10 ms tick / 굵은 선 = 버스 / 점선 블록 · MUX · OR = Top 안 assign", 13, "#333"))
    pg.boundary = ("stopwatch_watch", "PIN_IN", "PIN_OUT")
    pg.legend_xyw = (600, 128, 330)
    pg.notes.append((XF - 80, 160, "화면 MUX 입력 번호", 12.5, "#7a4d00"))
    for i, line in enumerate(mux_note.split("\n")):
        pg.notes.append((XF - 80, 180 + i * 17, line, 12, "#7a4d00"))
    return pg


# --------------------------------------------------------------------------- 페이지 2: FND 내부
def page_fnd():
    pg = Page("fnd", "U_FND_CONTROLLER (SW2_FND_CONTROLLER) 내부 — FND 자리별 출력이 만들어지는 길", 2300, 1230)
    B = pg.add
    pin_in = [("i_disp_msec", "[6:0]"), ("i_disp_sec", "[5:0]"), ("i_disp_min", "[5:0]"), ("i_disp_hour", "[5:0]"),
              "i_rst", "i_clk_4khz", "i_disp_mode", ("i_wt_cursor", "[1:0]"), "i_sel_wt", "i_set_sw2"]
    pin = B(Block("FIN", 20, 110, 160, [], pin_in, kind="pins_in", title="입력 포트", h=960))
    pin.outs = [p if isinstance(p, tuple) else (p, "") for p in pin_in]

    XS, XC, XA, XM, X2, XD = 330, 330, 720, 1140, 1400, 1660
    sp = {}
    for i, (nm, w) in enumerate([("MSEC", 7), ("SEC", 6), ("MIN", 6), ("HOUR", 6)]):
        sp[nm] = B(Block("U_" + nm, XS, 130 + i * 150, 250, [("i_value", f"[{w-1}:0]")],
                         [("o_digit1", "[3:0]"), ("o_digit10", "[3:0]")],
                         inst="U_" + nm, module="digit_splitter"))
    cnt = B(Block("CNT", XC, 760, 250, ["i_clk_4khz", "i_rst"], [("o_scan_sel", "[2:0]")],
                  inst="U_COUNTER8", module="counter8", note="i_clk_4khz 마다 +1 → 0~7, 한 칸 250 us"))
    dot = B(Block("DOT", XC, 920, 250, [("i_disp_msec", "[6:0]")], ["o_blink_off"],
                  inst="U_DOT", module="dot", note="o_blink_off = (i_disp_msec ≥ 50)"))
    ac_in = ["i_set_sw2", "i_disp_mode", "i_sel_wt", ("i_wt_cursor", "[1:0]"), "i_blink_off",
             ("i_an0", "[3:0]"), ("i_an1", "[3:0]"), ("i_an2", "[3:0]"), ("i_an3", "[3:0]")]
    ac_out = [("o_an0", "[3:0]"), ("o_an1", "[3:0]"), ("o_an2", "[3:0]"), ("o_an3", "[3:0]")]
    ac1 = B(Block("AC1", XA, 130, 270, ac_in, ac_out, inst="U_ANODE_CHOICE_TO_MUX1", module="SW2_ANODE_CHOICE",
                  note="초.1/100초 쪽 (설정 점멸은 시.분 화면만이라 실제로는 그대로 통과)"))
    ac2 = B(Block("AC2", XA, 470, 270, ac_in, ac_out, inst="U_ANODE_CHOICE_TO_MUX2", module="SW2_ANODE_CHOICE",
                  note="시.분 쪽: set_sw2 & disp_mode & sel_wt & blink_off 이면 커서 자리 = 4'hd (빈칸)"))
    m8_in = [("i_d0", ""), ("i_d1", ""), ("i_d2", ""), ("i_d3", ""), ("i_d4", ""), ("i_d5", ""), ("i_d6", ""), ("i_d7", "")]
    sm = B(Block("SECMUX", XM, 160, 110, [p for p, _ in m8_in], ["o_data"], kind="mux", title="U_SEC_MUXER (mux_8x1)",
                 sel=["i_sel"]))
    sm.module, sm.inst = "mux_8x1", "U_SEC_MUXER"
    mm = B(Block("MINMUX", XM, 520, 110, [p for p, _ in m8_in], ["o_data"], kind="mux", title="U_MIN_MUXER (mux_8x1)",
                 sel=["i_sel"]))
    mm.module, mm.inst = "mux_8x1", "U_MIN_MUXER"
    m2 = B(Block("M2", X2, 380, 80, ["w_sec_mux_bcd", "w_min_mux_bcd"], ["w_bcd"], kind="mux",
                 title="2:1 (assign)", sel=["i_disp_mode"]))
    dec = B(Block("DEC", XD, 760, 260, [("i_sel", "[1:0]")], [("o_fnd_com", "[3:0]")], inst="U_DECODER",
                  module="decoder_2x4", note="00→1110(AN0) 01→1101 10→1011 11→0111(AN3)"))
    fdec = B(Block("FDEC", XD, 380, 260, [("i_bcd", "[3:0]")], [("o_fnd_font", "[7:0]")], inst="U_FND_DEC",
                   module="fnd_decoder", note="0~9 숫자 · d,f = 빈칸 FF · e = 점 7F"))
    pout = B(Block("FOUT", 2080, 330, 170, ["o_fnd_com", "o_fnd_font"], [], kind="pins_out",
                   title="출력 포트", h=600,
                   pin_y={"o_fnd_com": dec.pin("o_fnd_com")[1], "o_fnd_font": fdec.pin("o_fnd_font")[1]}))
    pout.ins = [("o_fnd_com", "[3:0]"), ("o_fnd_font", "[7:0]")]

    # 입력 핀 y 정리
    py = {"i_disp_msec": sp["MSEC"].pin("i_value")[1], "i_disp_sec": sp["SEC"].pin("i_value")[1],
          "i_disp_min": sp["MIN"].pin("i_value")[1], "i_disp_hour": sp["HOUR"].pin("i_value")[1],
          "i_clk_4khz": cnt.pin("i_clk_4khz")[1], "i_rst": cnt.pin("i_rst")[1],
          "i_disp_mode": 1000, "i_wt_cursor": 1025, "i_sel_wt": 1050, "i_set_sw2": 1075}
    pin.pin_y = py

    for k in ["MSEC", "SEC", "MIN", "HOUR"]:
        pg.net("i_disp_" + k.lower(), ("FIN", "i_disp_" + k.lower()),
               [("U_" + k, "i_value", [])] + ([("DOT", "i_disp_msec", [230, 1012 - 70, 300])] if k == "MSEC" else []))
    pg.net("i_clk_4khz", ("FIN", "i_clk_4khz"), [("CNT", "i_clk_4khz", [])], kind="clk4k")
    pg.net("i_rst", ("FIN", "i_rst"), [("CNT", "i_rst", [])])
    # 공통 제어 → AC1/AC2
    for j, (p, x) in enumerate([("i_set_sw2", 640), ("i_disp_mode", 652), ("i_sel_wt", 664), ("i_wt_cursor", 676)]):
        pg.net(p, ("FIN", p), [("AC1", p, [x]), ("AC2", p, [x])] +
               ([("M2", "i_disp_mode", [x, 1110, 1440])] if p == "i_disp_mode" else []))
    pg.net("w_blink_off", ("DOT", "o_blink_off"),
           [("AC1", "i_blink_off", [688]), ("AC2", "i_blink_off", [688]),
            ("SECMUX", "i_d6", [688, 1100, 1066]), ("MINMUX", "i_d6", [688, 1100, 1066])],
           label_at=(590, 985))
    # 자리 분리 → AC
    for k, ac, base in [("MSEC", "AC1", 0), ("SEC", "AC1", 2), ("MIN", "AC2", 0), ("HOUR", "AC2", 2)]:
        b = sp[k]
        pg.net(f"w_{k.lower()}_digit1", ("U_" + k, "o_digit1"), [(ac, f"i_an{base}", [600 + base * 10])])
        pg.net(f"w_{k.lower()}_digit10", ("U_" + k, "o_digit10"), [(ac, f"i_an{base + 1}", [615 + base * 10])])
    # AC → 8:1 MUX
    for i in range(4):
        pg.net(f"w_mux1_an{i}", ("AC1", f"o_an{i}"), [("SECMUX", f"i_d{i}", [1000 + i * 14])])
        pg.net(f"w_mux2_an{i}", ("AC2", f"o_an{i}"), [("MINMUX", f"i_d{i}", [1000 + i * 14])])
    # 상수 입력 (4'hf) 깃발
    for m in ["SECMUX", "MINMUX"]:
        for d in ["i_d4", "i_d5", "i_d7"]:
            pg.flag(m, d, "4'hf", "clk")
    pg.net("w_scan_sel", ("CNT", "o_scan_sel"),
           [("SECMUX", "i_sel", [600, 1130, 1290, 440]), ("MINMUX", "i_sel", [600, 1130, 1195]),
            ("DEC", "i_sel", [600])], kind="clk4k")
    pg.net("w_sec_mux_bcd", ("SECMUX", "o_data"), [("M2", "w_sec_mux_bcd", [1330])])
    pg.net("w_min_mux_bcd", ("MINMUX", "o_data"), [("M2", "w_min_mux_bcd", [1345])])
    pg.net("w_bcd", ("M2", "w_bcd"), [("FDEC", "i_bcd", [])])
    pg.net("o_fnd_font", ("FDEC", "o_fnd_font"), [("FOUT", "o_fnd_font", [])])
    pg.net("o_fnd_com", ("DEC", "o_fnd_com"), [("FOUT", "o_fnd_com", [])])
    pg.boundary = ("SW2_FND_CONTROLLER", "FIN", "FOUT")
    pg.legend_xyw = (1470, 880, 580)
    pg.notes.append((30, 1180, "스캔 순서 (o_scan_sel 0→7, 2 ms 한 바퀴): 0 AN0 숫자 → 1 AN1 → 2 AN2 → 3 AN3 → 4 AN0 빈칸 → "
                     "5 AN1 빈칸 → 6 AN2 점(blink_off=0 일 때) → 7 AN3 빈칸.  i_d6 은 {3'b111, w_blink_off}.", 13, "#333"))
    pg.notes.append((30, 1206, "U_SEC_MUXER · U_MIN_MUXER: i_sel 0~3 → i_d0~i_d3 (AN0~AN3 숫자), 4 · 5 · 7 → 4'hf 빈칸, 6 → {3'b111, w_blink_off} AN2 점  /  "
                     "2:1 MUX: i_disp_mode 0 → w_sec_mux_bcd (초.1/100초), 1 → w_min_mux_bcd (시.분)", 13, "#333"))
    return pg


# --------------------------------------------------------------------------- 출력
def win(path):
    return subprocess.check_output(["wslpath", "-w", path]).decode().strip()


CHROME = "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"


def open_in_photos(path):
    """만든 PNG 를 Windows 사진 앱으로 연다 (기본 연결 프로그램과 상관없이 ms-photos: 로 직접)"""
    subprocess.run(["explorer.exe", "ms-photos:viewer?fileName=" + win(os.path.abspath(path))],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def chrome(args):
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars"] + args,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)


def to_png(svg, out_png, W, H):
    html = out_png[:-4] + "._tmp.html"
    open(html, "w", encoding="utf-8").write(
        f'<!doctype html><meta charset="utf-8"><body style="margin:0">{svg}</body>')
    chrome([f"--screenshot={win(out_png)}", f"--window-size={W},{H}", "file:///" + win(html).replace("\\", "/")])
    os.remove(html)


def to_pdf(svgs, out_pdf):
    html = out_pdf[:-4] + "._tmp.html"
    pages = "".join(f'<div class="pg" style="width:{W}px;height:{H}px">{s}</div>' for s, W, H in svgs)
    W, H = svgs[0][1], svgs[0][2]
    open(html, "w", encoding="utf-8").write(
        '<!doctype html><meta charset="utf-8"><style>'
        f'@page {{ size: {W}px {H}px; margin: 0 }} body {{ margin: 0 }} '
        '.pg { page-break-after: always; overflow: hidden } .pg svg { display:block }</style><body>' + pages)
    chrome(["--no-pdf-header-footer", f"--print-to-pdf={win(out_pdf)}", "file:///" + win(html).replace("\\", "/")])
    os.remove(html)


def build_pages():
    pages = [page_top(), page_fnd()]
    mods = verilog_ports()
    errs = []
    errs += ["[top] " + e for e in check_conns(pages[0], "stopwatch_watch.v")]
    errs += ["[top] " + e for e in check_assigns(pages[0], "stopwatch_watch.v")]
    errs += ["[fnd] " + e for e in check_conns(pages[1], "SW2_FND_CONTROLLER.v")]
    for pg in pages:
        errs += [f"[{pg.name}] " + e for e in check_ports(pg, mods)]
        errs += [f"[{pg.name}] " + e for e in check_wiring(pg)]
    if errs:
        print("\n".join(errs))
        sys.exit("다이어그램 ↔ Verilog 불일치")
    return pages


def port_map(pages):
    """블록별 입력 · 출력 포트와 연결 상대 표 (source_file/PORT_MAP.md)"""
    L = ["# PORT_MAP — 모듈 포트 · 연결표 (자동 생성: diagram/gen_diagram.py)", "",
         "블록 다이어그램(`../block_diagram.pdf`)과 같은 데이터에서 만든다. "
         "Verilog 포트 목록과 하나라도 다르면 생성 스크립트가 멈춘다.", "",
         "- 이름 규칙: 모듈 입력 `i_*`, 출력 `o_*`, Top 안 와이어 `w_*` (`o_xxx` → `w_xxx` → `i_xxx`)",
         "- 기능 접두어: `sw_` 스톱워치 · `wt_` 시계 · `tm_` 타이머 / 스위치 `*_swN` / 버튼 `*_btn_R·L·U·D`",
         "- Vivado 파형: Scope 창에서 `dut` 아래 인스턴스를 고르면 Objects 창에 아래 포트가 그대로 나온다", ""]
    for pg in pages:
        src_of, dst_of = {}, {}
        for n in pg.nets:
            for d in n["dsts"]:
                src_of[(d[0], d[1])] = (n["name"], n["src"])
                dst_of.setdefault(n["src"], []).append((n["name"], (d[0], d[1])))
        for b, p, t, k in pg.flags:
            if p in pg.blocks[b].all_inputs():
                src_of[(b, p)] = (t, None)
        def nm(bid):
            b = pg.blocks[bid]
            if b.inst:
                return f"`{b.inst}`"
            return b.title or bid
        L += ["", f"## {pg.title}", ""]
        for b in pg.blocks.values():
            if b.kind in ("pins_in", "pins_out"):
                continue
            head = f"### {b.inst} ({b.module})" if b.module else f"### {b.title} (Top 안 assign{', MUX' if b.kind == 'mux' else ''})"
            L += [head, "", f"입력 {len(b.all_inputs())} 개 · 출력 {len(b.all_outputs())} 개", "",
                  "| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |", "|---|---|---|---|"]
            for p in b.all_inputs():
                net, src = src_of[(b.id, p)]
                frm = f"`{net}` ← {nm(src[0])}.`{src[1]}`" if src else f"`{net}` (깃발: Top 핀 직결)"
                L.append(f"| in | `{p}` | {b.width_of(p) or '1'} | {frm} |")
            for p in b.all_outputs():
                tos = dst_of.get((b.id, p), [])
                to = "<br>".join(f"`{n_}` → {nm(d[0])}.`{d[1]}`" for n_, d in tos)
                L.append(f"| out | `{p}` | {b.width_of(p) or '1'} | {to} |")
            L.append("")
    return "\n".join(L) + "\n"


def main():
    pages = build_pages()
    open(os.path.join(SRC, "PORT_MAP.md"), "w", encoding="utf-8").write(port_map(pages))
    os.makedirs(os.path.join(HERE, "png"), exist_ok=True)
    svgs = []
    for pg in pages:
        s = render(pg)
        open(os.path.join(HERE, "png", f"{pg.name}.svg"), "w", encoding="utf-8").write(s)
        to_png(s, os.path.join(HERE, "png", f"{pg.name}.png"), pg.W, pg.H)
        svgs.append((s, pg.W, pg.H))
    # PDF 는 같은 크기로 맞춤
    W = max(w for _, w, _ in svgs)
    H = max(h for _, _, h in svgs)
    svgs = [(s.replace(f'width="{w}" height="{h}"', f'width="{W}" height="{H}"', 1), W, H) for s, w, h in svgs]
    to_pdf(svgs, os.path.join(HERE, "..", "block_diagram.pdf"))
    print("ok: 포트 · 연결 검사 통과, block_diagram.pdf 생성")
    return [os.path.join(HERE, "png", f"{pg.name}.png") for pg in pages]


if __name__ == "__main__":
    # python3 gen_diagram.py --open  → 만든 뒤 top.png · fnd.png 를 Windows 사진 앱으로 열기
    pngs = main()
    if "--open" in sys.argv:
        for p in pngs:
            open_in_photos(p)
