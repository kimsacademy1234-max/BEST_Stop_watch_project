#!/usr/bin/env python3
"""merge_final 블록 다이어그램 생성기 (verification_v2/diagram/gen_diagram.py 그림 방식 그대로).

- bd_core.py  : 그림 엔진 + Verilog 검사 (포트 · 인스턴스 연결 · assign 우변 · 배선)
- bd_pages.py : 쪽별 블록 · 선 좌표
- 쪽 : 1 Top · 2 U_UART · 3 U_WTS · 4 U_SR04 + U_DHT11 · 5 U_FND_CONTROLLER · 6 U_LED

실행: python3 gen_block_diagram.py [쪽 이름 ...] [--png-only]
      → merge_final_block_diagram.pdf (+ png/ 미리보기)
"""
import os
import subprocess
import sys

from bd_core import (check_assigns, check_conns, check_ports, check_wiring, render, verilog_ports,
                     HERE, OUT_PDF, PNG_DIR)
from bd_pages import page_top, page_uart, page_wts, page_sensor, page_fnd, page_led


def win(path):
    return subprocess.check_output(["wslpath", "-w", path]).decode().strip()


CHROME = "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"


def chrome(args):
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars"] + args,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=180)


def to_png(svg, out_png, W, H):
    html = out_png[:-4] + "._tmp.html"
    open(html, "w", encoding="utf-8").write(
        f'<!doctype html><meta charset="utf-8"><body style="margin:0">{svg}</body>')
    chrome([f"--screenshot={win(out_png)}", f"--window-size={W},{H}", "file:///" + win(html).replace("\\", "/")])
    os.remove(html)


def to_pdf(svgs, out_pdf):
    """쪽마다 크기가 다름 (CSS named page)"""
    html = out_pdf[:-4] + "._tmp.html"
    css, body = [], []
    for i, (s, W, H) in enumerate(svgs):
        css.append(f"@page p{i} {{ size: {W}px {H}px; margin: 0 }} .p{i} {{ page: p{i}; width:{W}px; height:{H}px }}")
        body.append(f'<div class="pg p{i}">{s}</div>')
    open(html, "w", encoding="utf-8").write(
        '<!doctype html><meta charset="utf-8"><style>' + " ".join(css) +
        ' body { margin: 0 } .pg { overflow: hidden; break-after: page } .pg svg { display:block }</style><body>' +
        "".join(body))
    chrome(["--no-pdf-header-footer", f"--print-to-pdf={win(out_pdf)}", "file:///" + win(html).replace("\\", "/")])
    os.remove(html)


def build_pages():
    pages = [p for p in (page_top(), page_uart(), page_wts(), page_sensor(), page_fnd(), page_led()) if p]
    mods = verilog_ports()
    errs = []
    for pg in pages:
        for f in (check_ports, ):
            errs += [f"[{pg.name}] " + e for e in f(pg, mods)]
        for f in (check_conns, check_assigns, check_wiring):
            errs += [f"[{pg.name}] " + e for e in f(pg)]
    if errs:
        print("\n".join(errs))
        sys.exit("다이어그램 ↔ Verilog 불일치")
    return pages


def main():
    pages = build_pages()
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    os.makedirs(PNG_DIR, exist_ok=True)
    svgs = []
    for i, pg in enumerate(pages, 1):
        s = render(pg)
        if not only or pg.name in only:
            to_png(s, os.path.join(PNG_DIR, f"{i}_{pg.name}.png"), pg.W, pg.H)
        svgs.append((s, pg.W, pg.H))
    if "--png-only" not in sys.argv:
        to_pdf(svgs, OUT_PDF)
    print("ok: 포트 · 연결 · assign · 배선 검사 통과")


if __name__ == "__main__":
    main()
