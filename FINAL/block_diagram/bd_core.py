#!/usr/bin/env python3
"""merge_final 블록 다이어그램 — 그림 엔진 · Verilog 검사 (bd_core)

원본: verification_v2/diagram/gen_diagram.py
 (verification_v2/diagram/gen_diagram.py 그림 방식 그대로).

- ../source_file/merge_final 의 Verilog 를 직접 읽어서
    check_ports   : 그림 블록의 입력 · 출력 핀 이름 · 개수 = Verilog 포트 목록
    check_conns   : 그림의 선 이름 = Verilog 인스턴스 연결 (.port(선))
    check_assigns : assign 블록 · MUX · OR · NOT 의 입력 선 = Verilog assign 우변 신호
    check_wiring  : 모든 입력 핀은 선 1 개 또는 깃발 1 개, 모든 출력 핀은 선 1 개 이상
  하나라도 다르면 PDF 를 만들지 않고 멈춘다.
- 쪽 : 1 Top · 2 U_UART · 3 U_WTS · 4 U_SR04 + U_DHT11 · 5 U_FND_CONTROLLER · 6 U_LED

실행: python3 gen_block_diagram.py   → merge_final_block_diagram.pdf (+ png/ 미리보기)
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "source_file", "merge_final")
OUT_PDF = os.path.join(HERE, "merge_final_block_diagram.pdf")
PNG_DIR = os.environ.get("BD_PNG_DIR", os.path.join(HERE, "png"))

P = 24     # 핀 간격
HDR = 46   # 블록 머리(인스턴스 이름 · 모듈 이름) 높이

FONT = "'Malgun Gothic','Noto Sans KR','Apple SD Gothic Neo',sans-serif"
MONO = "Consolas,'D2Coding','Courier New',monospace"

COL = {
    "module_fill": "#eef3fb", "module_line": "#3b5b92",
    "sub_fill": "#e6f0e0", "sub_line": "#3d7a2e",
    "assign_fill": "#f6f6f6", "assign_line": "#777777",
    "mux_fill": "#fff7e6", "mux_line": "#b7791f",
    "wire": "#4a4a4a",
    "clk4k": "#7b3fbf", "tick": "#d6336c", "btn": "#1c7ed6", "bidir": "#0c8599",
    "flag_clk": "#8a8a8a", "flag_sw": "#e8590c", "flag_ctrl": "#0b7285", "flag_nc": "#adb5bd",
    "pin_in": "#fdf1e7", "pin_out": "#e9f7ef",
}


# --------------------------------------------------------------------------- 모델
class Block:
    def __init__(self, bid, x, y, w, ins, outs, inst=None, module=None, kind="module",
                 title=None, note=None, sel=None, pin_y=None, h=None, parent=None,
                 groups=None, sub=None, check=True, also=None, title2=None):
        self.id, self.x, self.y, self.w = bid, x, y, w
        self.ins = [p if isinstance(p, tuple) else (p, "") for p in ins]
        self.outs = [p if isinstance(p, tuple) else (p, "") for p in outs]
        self.sel = [p if isinstance(p, tuple) else (p, "") for p in (sel or [])]  # MUX 아래쪽 선택 입력
        self.inst, self.module, self.kind = inst, module, kind
        self.title, self.note, self.title2 = title, note, title2
        self.pin_y = pin_y or {}
        self.parent = parent      # 이 인스턴스가 들어 있는 Verilog 파일
        self.groups = groups      # MUX 입력 묶음 [(번호 글자, 핀 개수), ...]
        self.sub = sub            # 하위 Top 이면 "n 쪽" 글자
        self.check = check        # False : assign 검사 제외 (always · 포트 연결로 만든 묶음)
        self.also = also or []    # assign 검사 때 같이 보는 왼쪽 신호 (3상태 버퍼 등)
        n = max(len(self.ins), len(self.outs), 1)
        if kind == "mux":
            self.h = h or (30 + len(self.ins) * P + 6)
        elif kind == "or":
            self.h = h or 70
        elif kind == "not":
            self.h = h or 30
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
                if self.kind == "not":
                    return (self.x, self.y + self.h / 2, "L")
                return (self.x, self.y + HDR + i * P + P // 2, "L")
        for i, (p, _) in enumerate(self.sel):
            if p == port:
                n = len(self.sel)
                xx = self.x + self.w * (i + 1) / (n + 1)
                slope = 0.28
                yy = self.y + self.h - (xx - self.x) * slope
                return (xx, yy, "B")
        for i, (p, _) in enumerate(self.outs):
            if p == port:
                if self.kind in ("mux", "or", "not"):
                    return (self.x + self.w, self.y + self.h / 2, "R")
                return (self.x + self.w, self.y + HDR + i * P + P // 2, "R")
        raise KeyError(f"{self.id}.{port}")

    def py(self, port):
        return self.pin(port)[1]

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
        self.notes = []   # (x, y, text, size, color, weight)
        self.frames = []  # (x, y, w, h, label)  구역 테두리
        self.boundaries = []   # (module, pin_in 블록, pin_out 블록)
        self.flagmap = {}      # 깃발 글자 → Verilog 선 이름

    def add(self, b):
        assert b.id not in self.blocks, b.id
        self.blocks[b.id] = b
        return b

    def net(self, name, src, dsts, kind="wire", label_at=None):
        self.nets.append(dict(name=name, src=src, dsts=dsts, kind=kind, label_at=label_at))

    def flag(self, b, p, text=None, kind="clk"):
        self.flags.append((b, p, text or p, kind))

    def note(self, x, y, s, size=12.5, color="#333", weight="normal"):
        self.notes.append((x, y, s, size, color, weight))


# --------------------------------------------------------------------------- Verilog 읽기
def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//.*", "", text)


def src_files():
    for root, _, files in os.walk(SRC):
        for fn in sorted(files):
            if fn.endswith((".v", ".sv")):
                yield os.path.join(root, fn)


def read_src(rel):
    for f in src_files():
        if f.endswith(os.sep + rel) or os.path.basename(f) == rel:
            return strip_comments(open(f, encoding="utf-8", errors="replace").read())
    raise FileNotFoundError(rel)


def verilog_ports():
    """모듈 이름 → (입력 목록, 출력 목록).  inout 은 입력 쪽에 넣음"""
    mods = {}
    for f in src_files():
        text = strip_comments(open(f, encoding="utf-8", errors="replace").read())
        for m in re.finditer(r"\bmodule\s+(\w+)\s*(#\s*\((?:[^()]|\([^()]*\))*\)\s*)?\((.*?)\);", text, re.S):
            name, body = m.group(1), m.group(3)
            ins, outs, cur = [], [], None
            for item in body.split(","):
                d = re.match(r"\s*(input|output|inout)\b", item)
                if d:
                    cur = d.group(1)
                nm = re.findall(r"(\w+)\s*$", item.strip())
                if cur and nm:
                    (outs if cur == "output" else ins).append(nm[0])
            mods[name] = (ins, outs)
    return mods


def verilog_conns(rel):
    """인스턴스 이름 → {포트: 연결된 식}"""
    text = read_src(rel)
    out = {}
    for m in re.finditer(r"\b\w+\s*(?:#\s*\((?:[^()]|\([^()]*\))*\))?\s*(U_\w+)\s*\(((?:[^;])*?)\);", text, re.S):
        out[m.group(1)] = {a: re.sub(r"\s+", " ", b.strip())
                           for a, b in re.findall(r"\.(\w+)\s*\(((?:[^()]|\([^()]*\))*)\)", m.group(2))}
    return out


def idents(expr):
    """식 안의 신호 이름 (숫자 상수 · 대문자 parameter 제외)"""
    e = re.sub(r"\d*'[sS]?[bdhoBDHO][0-9a-fA-FxXzZ_]+", " ", expr)
    return {t for t in re.findall(r"\b([A-Za-z_]\w*)\b", e) if not t.isupper()}


def verilog_rhs(rel):
    """왼쪽 신호 → 오른쪽 식 목록 (assign · wire x = · always @(*) case)"""
    text = read_src(rel)
    rhs = {}
    for lhs, expr in re.findall(r"\bassign\s+([\w\[\]:]+)\s*=\s*(.*?);", text, re.S):
        rhs.setdefault(re.sub(r"\[.*", "", lhs), []).append(expr)
    for lhs, expr in re.findall(r"\bwire\s*(?:\[[^\]]*\])?\s*(\w+)\s*=\s*(.*?);", text, re.S):
        rhs.setdefault(lhs, []).append(expr)
    for body in re.findall(r"always\s*@\(\*\)\s*begin(.*?)\bend\s*(?:\n|$)", text, re.S):
        sel = re.findall(r"\bcase\s*\((.*?)\)", body)
        for lhs, expr in re.findall(r"\b(\w+)\s*=\s*([^;]+);", body):
            rhs.setdefault(lhs, []).append(expr + " " + " ".join(sel))
    return rhs


def net_names(page):
    at = {}
    for n in page.nets:
        at[n["src"]] = n["name"]
        for d in n["dsts"]:
            at[(d[0], d[1])] = n["name"]
    for b, p, t, k in page.flags:
        at[(b, p)] = page.flagmap.get(t, t)
    return at


def check_ports(page, mods):
    errs = []
    for mod, bin_, bout in page.boundaries:
        vin, vout = mods[mod]
        din, dout = page.blocks[bin_].all_outputs(), page.blocks[bout].all_inputs()
        if sorted(vin) != sorted(din) or sorted(vout) != sorted(dout):
            errs.append(f"{mod} 바깥 핀 불일치\n   Verilog in {sorted(vin)} out {sorted(vout)}\n"
                        f"   그림    in {sorted(din)} out {sorted(dout)}")
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


def check_conns(page):
    """그림의 선 이름 = Verilog 인스턴스 연결 (모듈 블록만)"""
    at = net_names(page)
    errs, cache = [], {}
    for b in page.blocks.values():
        if not b.module:
            continue
        if b.parent not in cache:
            cache[b.parent] = verilog_conns(b.parent)
        v = cache[b.parent].get(b.inst)
        if v is None:
            errs.append(f"{b.inst}: {b.parent} 에 인스턴스 없음")
            continue
        for p in b.all_inputs() + b.all_outputs():
            want = at.get((b.id, p))
            got = v.get(p, "<없음>")
            same = want is not None and (re.sub(r"\s", "", want) == re.sub(r"\s", "", got) or
                                         re.search(r"(?<!\w)" + re.escape(want) + r"(?!\w)", got))
            if not same:
                errs.append(f"{b.inst}.{p}: Verilog ({got}) ↔ 그림 ({want})")
    return errs


def check_assigns(page):
    """assign 블록 · MUX · OR · NOT : 그림 입력 선 = Verilog 우변 신호 (중간 선은 펼쳐서)"""
    errs, cache = [], {}
    at = net_names(page)
    for b in page.blocks.values():
        if b.module or b.kind in ("pins_in", "pins_out") or not b.check:
            continue
        if b.parent not in cache:
            cache[b.parent] = verilog_rhs(b.parent)
        rhs = cache[b.parent]
        din = {at.get((b.id, p), p) for p in b.all_inputs() if not p.startswith("c_")}
        used = set()
        for o in b.all_outputs() + b.also:
            key = re.sub(r"\[.*", "", o)
            if key in rhs:
                for e in rhs[key]:
                    used |= idents(e)
            elif re.search(r"[~&|]", o):
                used |= idents(o)
            else:
                errs.append(f"{b.title or b.id}: {o} 를 만드는 assign 없음")
        for _ in range(6):
            mids = [u for u in used if u not in din and u in rhs]
            if not mids:
                break
            for u in mids:
                used.discard(u)
                for e in rhs[u]:
                    used |= idents(e)
        if used != din:
            errs.append(f"{b.title or b.id}: Verilog 우변 {sorted(used)} ↔ 그림 입력 {sorted(din)}")
    return errs


def check_wiring(page):
    errs = []
    used_in, used_out = {}, {}
    for n in page.nets:
        used_out.setdefault(n["src"], []).append(n["name"])
        for d in n["dsts"]:
            used_in.setdefault((d[0], d[1]), []).append(n["name"])
    for b, p, t, k in page.flags:
        if p in page.blocks[b].all_inputs():
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
        page.blocks[b].pin(p)
    return errs


# --------------------------------------------------------------------------- 그리기
def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def text(x, y, s, size=12, color="#222", anchor="start", weight="normal", mono=False):
    fam = MONO if mono else FONT
    return (f'<text x="{x:.1f}" y="{y:.1f}" font-family="{fam}" font-size="{size}" fill="{color}" '
            f'text-anchor="{anchor}" font-weight="{weight}">{esc(s)}</text>')


def path_points(page, src, dst, wps):
    sx, sy, _ = page.blocks[src[0]].pin(src[1])
    dx, dy, side = page.blocks[dst[0]].pin(dst[1])
    pts = [(sx, sy)]
    cx, cy = sx, sy
    for i, v in enumerate(wps):
        if i % 2 == 0:
            cx = v
        else:
            cy = v
        pts.append((cx, cy))
    if side == "B":
        if len(wps) % 2 == 0:
            pts.append((dx, cy))
        else:
            pts.append((cx, dy + 30))
            pts.append((dx, dy + 30))
        pts.append((dx, dy))
    else:
        if len(wps) % 2 == 1:
            pts.append((cx, dy))
        else:
            pts.append((dx, cy))
        pts.append((dx, dy))
    out = [pts[0]]
    for p in pts[1:]:
        if abs(p[0] - out[-1][0]) > 0.1 or abs(p[1] - out[-1][1]) > 0.1:
            out.append(p)
    return out


FLAG_COL = {"clk": COL["flag_clk"], "sw": COL["flag_sw"], "ctrl": COL["flag_ctrl"], "nc": COL["flag_nc"]}


def render(page):
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{page.W}" height="{page.H}" '
           f'viewBox="0 0 {page.W} {page.H}">',
           f'<rect width="{page.W}" height="{page.H}" fill="#ffffff"/>',
           '<defs><marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
           'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="context-stroke"/></marker></defs>']
    svg.append(text(30, 42, page.title, 26, "#111", weight="bold"))

    for x, y, w, h, label in page.frames:
        svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="none" stroke="#b0b8c4" '
                   f'stroke-width="1.5" stroke-dasharray="10,6"/>')
        svg.append(text(x + 14, y + 22, label, 15, "#3d4a5c", weight="bold"))

    wire_svg, label_svg, dot_svg = [], [], []
    for n in page.nets:
        color = {"clk4k": COL["clk4k"], "tick": COL["tick"], "bidir": COL["bidir"]}.get(n["kind"], COL["wire"])
        sb = page.blocks[n["src"][0]]
        wd = sb.width_of(n["src"][1]) or re.search(r"\[\d+:\d+\]", n["name"])
        sw = 3.0 if wd else 1.6
        for (db, dp, wps) in n["dsts"]:
            pts = path_points(page, n["src"], (db, dp), wps)
            d = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
            ms = ' marker-start="url(#arr)"' if n["kind"] == "bidir" else ""
            wire_svg.append(f'<polyline points="{d}" fill="none" stroke="{color}" stroke-width="{sw}" '
                            f'stroke-linejoin="round" marker-end="url(#arr)"{ms}/>')
            if len(n["dsts"]) > 1 and len(pts) >= 3:
                x, y = pts[1]
                dot_svg.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3.4" fill="{color}"/>')
        if sb.kind != "module" and not n["label_at"]:
            continue
        sx, sy, _ = sb.pin(n["src"][1])
        lx, ly = n["label_at"] if n["label_at"] else (sx + 6, sy - 4)
        label_svg.append(text(lx, ly, n["name"], 10.5, "#555", mono=True))
    svg += wire_svg + dot_svg

    for b in page.blocks.values():
        svg += draw_block(b)

    for b, p, t, k in page.flags:
        x, y, side = page.blocks[b].pin(p)
        c = FLAG_COL[k]
        tw = 6.6 * len(t) + 14
        if page.blocks[b].kind == "pins_in":
            svg.append(f'<line x1="{x}" y1="{y}" x2="{x + 22}" y2="{y}" stroke="{c}" stroke-width="2"/>')
            svg.append(f'<circle cx="{x + 26}" cy="{y}" r="4.5" fill="#fff" stroke="{c}" stroke-width="2"/>')
            continue
        dash = ' stroke-dasharray="3,2"' if k == "nc" else ""
        tc = "#868e96" if k == "nc" else c
        if side == "L":
            x0 = x - 18 - tw
            svg.append(f'<polygon points="{x0},{y-8} {x0+tw},{y-8} {x0+tw+8},{y} {x0+tw},{y+8} {x0},{y+8}" '
                       f'fill="#fff" stroke="{c}" stroke-width="1.4"{dash}/>')
            svg.append(f'<line x1="{x0+tw+8}" y1="{y}" x2="{x}" y2="{y}" stroke="{c}" stroke-width="1.4"/>')
            svg.append(text(x0 + 6, y + 4, t, 10.5, tc, mono=True, weight="bold"))
        elif side == "R":
            x0 = x + 18
            svg.append(f'<line x1="{x}" y1="{y}" x2="{x0}" y2="{y}" stroke="{c}" stroke-width="1.4"{dash}/>')
            svg.append(f'<polygon points="{x0},{y} {x0+8},{y-8} {x0+8+tw},{y-8} {x0+8+tw},{y+8} {x0+8},{y+8}" '
                       f'fill="#fff" stroke="{c}" stroke-width="1.4"{dash}/>')
            svg.append(text(x0 + 14, y + 4, t, 10.5, tc, mono=True, weight="bold"))
        else:
            y0 = y + 14
            svg.append(f'<line x1="{x}" y1="{y}" x2="{x}" y2="{y0}" stroke="{c}" stroke-width="1.4"/>')
            svg.append(f'<rect x="{x - tw/2:.1f}" y="{y0}" width="{tw:.1f}" height="16" rx="3" fill="#fff" '
                       f'stroke="{c}" stroke-width="1.4"/>')
            svg.append(text(x, y0 + 12, t, 10, c, anchor="middle", mono=True, weight="bold"))

    svg += label_svg
    for x, y, s, size, color, weight in page.notes:
        svg.append(text(x, y, s, size, color, weight=weight))
    svg.append("</svg>")
    return "\n".join(svg)


def draw_block(b):
    out = []
    if b.kind == "mux":
        s = b.w * 0.28
        pts = f"{b.x},{b.y} {b.x + b.w},{b.y + s} {b.x + b.w},{b.y + b.h - s} {b.x},{b.y + b.h}"
        out.append(f'<polygon points="{pts}" fill="{COL["mux_fill"]}" stroke="{COL["mux_line"]}" stroke-width="2"/>')
        out.append(text(b.x + b.w / 2, b.y + b.h / 2 - 2, "MUX", 12, COL["mux_line"], anchor="middle", weight="bold"))
        if b.title:
            out.append(text(b.x + b.w / 2, b.y - 8, b.title, 11.5, "#7a4d00", anchor="middle", weight="bold"))
        if b.title2:
            out.append(text(b.x + b.w / 2, b.y - 22, b.title2, 11.5, "#7a4d00", anchor="middle", weight="bold"))
        if b.groups:
            i = 0
            for lab, n in b.groups:
                y0 = b.pin(b.ins[i][0])[1]
                y1 = b.pin(b.ins[i + n - 1][0])[1]
                if n > 1:
                    out.append(f'<line x1="{b.x + 6}" y1="{y0}" x2="{b.x + 6}" y2="{y1}" stroke="#b7791f" stroke-width="1.5"/>')
                out.append(text(b.x + 10, (y0 + y1) / 2 + 4, lab, 10, "#7a4d00", weight="bold"))
                i += n
        else:
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
    if b.kind == "not":
        x, y, w, h = b.x, b.y, b.w, b.h
        out.append(f'<path d="M{x},{y} L{x + w - 8},{y + h/2} L{x},{y + h} z" fill="{COL["mux_fill"]}" '
                   f'stroke="{COL["mux_line"]}" stroke-width="2"/>')
        out.append(f'<circle cx="{x + w - 4}" cy="{y + h/2}" r="4" fill="#fff" stroke="{COL["mux_line"]}" stroke-width="2"/>')
        return out

    fill, line, dash = COL["module_fill"], COL["module_line"], ""
    if b.sub:
        fill, line = COL["sub_fill"], COL["sub_line"]
    if b.kind == "assign":
        fill, line, dash = COL["assign_fill"], COL["assign_line"], 'stroke-dasharray="6,4"'
    elif b.kind == "pins_in":
        fill, line = COL["pin_in"], "#c05621"
    elif b.kind == "pins_out":
        fill, line = COL["pin_out"], "#2f855a"
    sw = 3 if b.sub else 2
    out.append(f'<rect x="{b.x}" y="{b.y}" width="{b.w}" height="{b.h}" rx="8" fill="{fill}" stroke="{line}" '
               f'stroke-width="{sw}" {dash}/>')
    if b.kind in ("pins_in", "pins_out"):
        out.append(text(b.x + b.w / 2, b.y + 20, b.title, 13, line, anchor="middle", weight="bold"))
    elif b.kind == "assign":
        out.append(text(b.x + b.w / 2, b.y + 19, b.title, 13, "#333", anchor="middle", weight="bold"))
        out.append(text(b.x + b.w / 2, b.y + 36, b.title2 or "(assign)", 10.5, "#777", anchor="middle"))
    else:
        tc, mc = ("#1f4d16", "#4a7a3e") if b.sub else ("#1a2f55", "#5a6d8f")
        out.append(text(b.x + b.w / 2, b.y + 19, b.inst, 13, tc, anchor="middle", weight="bold", mono=True))
        out.append(text(b.x + b.w / 2, b.y + 36, b.module + (f"   · 내부 {b.sub}" if b.sub else ""), 11, mc,
                        anchor="middle", mono=True))
    pin_col = line
    for p, wd in b.ins:
        x, y, _ = b.pin(p)
        out.append(f'<rect x="{x - 3}" y="{y - 3}" width="6" height="6" fill="{pin_col}"/>')
        if b.kind != "pins_out" or True:
            out.append(text(x + 7, y + 4, p + wd, 11, "#222", mono=True))
    for p, wd in b.outs:
        x, y, _ = b.pin(p)
        out.append(f'<rect x="{x - 3}" y="{y - 3}" width="6" height="6" fill="{pin_col}"/>')
        out.append(text(x - 7, y + 4, p + wd, 11, "#222", anchor="end", mono=True))
    if b.note:
        for i, line_ in enumerate(b.note.split("\n")):
            out.append(text(b.x + b.w / 2, b.y + b.h + 15 + i * 13, line_, 10, "#555", anchor="middle"))
    return out


