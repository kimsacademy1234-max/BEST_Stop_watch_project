# Top TB 검증 장표 2 장 — ① 그룹 TB 결과 표 ② 버그 넣기 (TB 신뢰성)
# 사용 : python make_tb_slides.py [out.pptx]      (기본 out = top_TB_검증.pptx)
#   - 디자인 : ppt_정안성.pptx 와 같은 틀 (make_wave_slides.frame : 청록 머리말 · 제목 30 pt · 결론 상자)
#   - ① 근거 : FINAL/sim_file/TB_RESULT_SUMMARY_1031.md · TB_RESULT_1031.md (11/01 정정 : 검사 305 = PASS 297 + 스펙과 다른 8 → 장표는 FAIL 8 로 셈)
#   - ② 근거 : FINAL/sim_file/mutants/<ID>.log 의 [SUMMARY] (run_mutant.bat 로 버그 사본 실행)
import os
import re
import sys

from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN

from make_block_diagram import text, text_runs, shape, set_text, FONT
from make_wave_slides import frame, ACC, ACC_D, ACC_L, check

HERE = os.path.dirname(os.path.abspath(__file__))
MUT = os.path.join(HERE, "..", "..", "..", "FINAL", "sim_file", "mutants")
SEC = "03  Top · 시뮬레이션   검증"
GRN, RED, AMB, INK = "1E8E3E", "C00000", "B7791F", "262626"


def tbl(s, x, y, col_w, rows, row_h=0.42, pt=13.5, align=None, color=None, name="표"):
    """rows[0] = 머리 줄. align = 열별 'l' / 'c', color = {(행, 열): 색} (굵게)"""
    color = color or {}
    align = align or ["c"] * len(col_w)
    t = s.shapes.add_table(len(rows), len(col_w), Inches(x), Inches(y), Inches(sum(col_w)),
                           Inches(row_h * len(rows)))
    t.name = name
    t = t.table
    t.first_row = True
    for j, w in enumerate(col_w):
        t.columns[j].width = Inches(w)
    for i, row in enumerate(rows):
        t.rows[i].height = Inches(row_h)
        for j, v in enumerate(row):
            c = t.cell(i, j)
            c.fill.solid()
            c.fill.fore_color.rgb = RGBColor.from_string(ACC_D if i == 0 else ("FFFFFF" if i % 2 else "F2F8F8"))
            c.margin_left = c.margin_right = Inches(0.1)
            c.margin_top = c.margin_bottom = Inches(0.02)
            c.vertical_anchor = MSO_ANCHOR.MIDDLE
            tf = c.text_frame
            tf.text = ""
            p = tf.paragraphs[0]
            p.alignment = PP_ALIGN.CENTER if (i == 0 or align[j] == "c") else PP_ALIGN.LEFT
            r = p.add_run()
            r.text = str(v)
            r.font.size = Pt(pt)
            r.font.name = FONT
            r.font.bold = (i == 0) or (i, j) in color
            r.font.color.rgb = RGBColor.from_string("FFFFFF" if i == 0 else color.get((i, j), INK))
    return t


def note(s, y, t, pt=13.5):
    text(s, 0.92, y, 18.2, 0.36, t, pt, "595959")


# ---------------------------------------------------------------- ① 그룹 TB 결과
FAILS = [  # ID, 상황, 스펙, 실제 동작 (TB_RESULT_SUMMARY_1031.md 3 장 "ISSUE" → FAIL)
    ("D7-2", "랩 표시 중 /get", "진행값", "랩 값 전송"),
    ("E6-1", "시계 초 화면 + 설정 → U", "분 그대로", "분 +1 (안 보임)"),
    ("G3-3", "/set abcd (시.분 화면)", "변화 없음", "설정 비트 켜짐"),
    ("G7-2", "/off 오타 뒤 /off w_h", "설정 꺼짐", "ERROR · 설정 그대로"),
    ("H7-2", "/auto off 뒤 바로 /auto", "첫 줄 1 주기 뒤", "0.54 주기 뒤"),
    ("H9-1", "/get 20 번 연속", "20 줄", "15 줄 (합쳐짐)"),
    ("J14-2", "습도 ≥ 100 에서 /get", "숫자 2 자리", "\":0%24C\""),
    ("L6-1", "캐리 clk 에 보낸 줄", "00:00:01.00", "00:00:00.00"),
]
TB_ROWS = [  # TB, 영역, 대표 시나리오, 예상 결과, 검사, PASS, FAIL
    ("tb_A_reset", "리셋", "전원 · 동작 중 리셋", "2 clk 뒤 초기값 · x/z 없음", 14, 14, 0),
    ("tb_B_button", "버튼", "채터링 · 1.5 / 2.25 ms 경계 · 화면 게이팅", "누름당 펄스 1 개 · 지금 화면만", 14, 14, 0),
    ("tb_C_mode", "모드 선택", "스위치 우선순위 · /mod 8 종 · 틀린 /mod", "첫 /mod 뒤 스위치 무시", 30, 30, 0),
    ("tb_D_stopwatch", "스톱워치", "시작 정확도 · 23:59:59 wrap · 랩", "첫 tick 10.00 ms", 15, 14, 1),
    ("tb_E_watch", "시계", "12/24 경계 · 설정 커서 · 값 wrap", "0 시 → 12 AM · 59+1 → 00", 23, 22, 1),
    ("tb_F_timer", "타이머", "10 초 알람 · 포화 · 다른 화면 알람", "L 뒤 10.000 s · LED 16 개 점멸", 16, 16, 0),
    ("tb_G_uart_rx", "UART 수신", "명령 24 개 · 형식 오류 10 종 · baud ± 2 %", "handshake 1 번 · ERROR 1 줄", 52, 50, 2),
    ("tb_H_uart_ctrl", "UART 전송", "/get · /auto 1 Hz · ERROR 우선 · /btn", "첫 줄 1.000 s · 줄 안 섞임", 31, 29, 2),
    ("tb_I_sr04", "SR04", "거리 5 점 · Err1 ~ 3 · 자동 60 ms", "352.7 cm (± 0.1) · Err 번호", 26, 26, 0),
    ("tb_J_dht11", "DHT11", "비트 경계 · 체크섬 · Err1 ~ 3 · 자동 2 s", "55.24 · Err3 → 다음 정상", 30, 29, 1),
    ("tb_K_display", "FND · LED", "거리 · 온습도 FND · LED 7 화면", "000.0 · ---- · Err1 ~ 3", 28, 28, 0),
    ("tb_L_integration", "통합", "배경 동작 · 동시 부하 · 랜덤 리셋 20", "형식 오류 · 누락 · hang 0", 26, 25, 1),
]


def slide_groups(prs, page):
    s, y0 = frame(prs, SEC, "Top TB — 그룹 TB 12 개 · 92 시나리오 · 검사 305 개, FAIL 8",
                  ["그룹 TB 12 개 [SUMMARY] 합", "보윤 통합 TB 는 그룹 TB 와 겹치지 않는 검사만"],
                  [[("그룹 TB 12 개 (A ~ L) : 검사 305 → ", 0), ("PASS 297 · FAIL 8", 1),
                    ("  +  통합 TB (겹치지 않는 것) ", 0), ("292 / 292", 1)],
                   [("FAIL 8 = 스펙과 다르게 동작 → ", 0), ("고칠 곳", 1),
                    (" (오른쪽 표 — 나머지 297 검사는 모두 PASS)", 0)]],
                  page, "tb_summary")
    rows = [["TB", "대표 시나리오", "검사", "결과"]]
    col = {}
    for i, (tb, area, sc, exp, n, p, iss) in enumerate(TB_ROWS, 1):
        if iss:
            res = f"{p} / {n} · FAIL {iss}"
            col[(i, 3)] = RED
        else:
            res = f"{p} / {n}"
            col[(i, 3)] = GRN
        rows.append([tb, sc, str(n), res])
    rows.append(["통합 TB (보윤)", "랜덤 명령 120 개 · 송신 MUX 100 번", "292", "292 / 292"])
    col[(len(rows) - 1, 3)] = GRN
    tbl(s, 0.92, y0, [2.1, 4.35, 0.75, 2.05], rows, row_h=0.44, pt=12.5,
        align=["l", "l", "c", "c"], color=col, name="그룹 TB 표")
    irows = [["FAIL", "상황", "스펙", "실제 동작"]] + [list(r) for r in FAILS]
    icol = {(i, 3): RED for i in range(1, len(irows))}
    tbl(s, 10.42, y0, [0.95, 3.2, 1.95, 2.56], irows, row_h=0.44 * len(rows) / len(irows), pt=13,
        align=["c", "l", "l", "l"], color=icol, name="FAIL 표")
    yb = y0 + 0.44 * len(rows) + 0.15
    note(s, yb, "xsim · 100 MHz · FAST = 1 (WTS 1 s → 1 ms · UART 115200 bps · /auto 200 Hz) · 그룹 TB 실행 2,453 s (약 41 분) · "
                "결과 = PASS / 검사")
    note(s, yb + 0.36, "FAIL 8 개 상세 : FINAL/sim_file/TB_RESULT_SUMMARY_1031.md 3 장 — 나머지 시나리오는 모두 PASS")
    s.notes_slide.notes_text_frame.text = (
        "Top TB 는 영역별 12 개 그룹 TB 로 나눴습니다. 시나리오 92 개, 검사 305 개에서 PASS 297, FAIL 8 입니다. "
        "오른쪽 FAIL 8 개는 스펙과 다르게 동작한 항목으로, 랩 중 /get · /get 연타 · /auto 재시작 같은 명령 처리와 "
        "캐리 순간 값 등입니다. "
        "보윤 통합 TB 에서 그룹 TB 와 겹치지 않는 랜덤 명령 · 송신 MUX 검사 292 개도 모두 PASS 입니다.")
    return s


# ---------------------------------------------------------------- ② 버그 넣기
MUTANTS = [  # ID, 넣은 버그, 바꾼 모듈, [(로그 ID, 다시 돌린 그룹 TB)]
    ("M1", "디바운서 8 샘플 AND → OR (튐 통과)", "btn_debounce", [("M1", "tb_B_button")]),
    ("M3", "모드 MUX : /mod 무시 (스위치만)", "merge_final_top", [("M3", "tb_C_mode")]),
    ("M4", "스톱워치 · 타이머 tick 1 clk 짧음", "tick_gen_100hz_run", [("M4", "tb_D_stopwatch"), ("M4F", "tb_F_timer")]),
    ("M5", "12 시간 표시 : 0 시를 12 대신 00", "hour_12_24", [("M5", "tb_E_watch")]),
    ("M6", "SR04 400 cm 한계 100 us 늦음", "sr04_core", [("M6", "tb_I_sr04")]),
    ("M7", "DHT11 체크섬 검사 빠짐", "dht11_controller", [("M7", "tb_J_dht11")]),
    ("M8", "FND 거리 소수점 안 켜짐", "fnd_dist", [("M8", "tb_K_display")]),
    ("M9", "시계 LED 에 스톱워치 신호 연결", "led_output", [("M9", "tb_K_display")]),
    ("M10", "UART 거리 백의 자리 계산 오류", "sender_char_mux", [("M10", "tb_H_uart_ctrl"), ("M10I", "tb_I_sr04")]),
]


def mut_result(mid):
    p = os.path.join(MUT, mid + ".log")
    if not os.path.exists(p):
        return None
    m = re.findall(r"\[SUMMARY\] \S+ checks=(\d+) fail=(\d+) issue=(\d+)", open(p, encoding="utf-8", errors="replace").read())
    return tuple(map(int, m[-1])) if m else None


def card(s, x, y, w, h, n, head, line):
    b = shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, x, y, w, h, "FFFFFF", ACC_D, 2.0, name=f"설명 {n}")
    b.adjustments[0] = 0.08
    c = shape(s, MSO_SHAPE.OVAL, x + 0.18, y + 0.14, 0.4, 0.4, ACC_D, None, name=f"번호 {n}")
    set_text(c, [str(n)], "FFFFFF", [14])
    text(s, x + 0.72, y + 0.12, w - 0.9, 0.44, head, 17, ACC_D, bold=True)
    text(s, x + 0.3, y + 0.62, w - 0.5, h - 0.7, line, 14.5, INK, anchor="t")


def slide_mutants(prs, page):
    n = len(MUTANTS)
    rows = [["#", "넣은 버그", "바꾼 모듈", "다시 돌린 그룹 TB", "FAIL", "검출"]]
    col, got, miss = {}, 0, []
    for i, (mid, desc, mod, runs) in enumerate(MUTANTS, 1):
        rs = [mut_result(lid) for lid, _ in runs]
        tbs = " → ".join(tb for _, tb in runs)
        if any(r is None for r in rs):
            f, d = "-", "실행 중"
        else:
            f = " → ".join(f"FAIL {r[1]}" if r[1] else "0" for r in rs)
            hit = [tb for (_, tb), r in zip(runs, rs) if r[1] > 0]
            if hit:
                got += 1
                d = "검출" if len(runs) == 1 or rs[0][1] else hit[0][:4] + " 검출"
                col[(i, 4)] = RED
                col[(i, 5)] = GRN if rs[0][1] else AMB
            else:
                d = "못 잡음"
                miss.append(mid)
                col[(i, 5)] = RED
        rows.append([f"B{i}", desc, mod, tbs, f, d])   # 장 번호 B1 ~ (폴더 · 로그 이름은 mutants/<mid>)
    s, y0 = frame(prs, SEC, f"Top TB 신뢰성 — 버그 {n} 개를 넣어 보니 {'모두 FAIL' if got == n else f'{got} 개 FAIL'}",
                  ["버그 사본마다 같은 그룹 TB 의 새 FAIL 수", "원본에서 이미 FAIL 인 8 개는 뺌"],
                  [[("버그를 ", 0), ("하나씩 소스 사본에 넣고", 1), (" 같은 Top TB 를 다시 돌림 → ", 0),
                    (f"{got} / {n} 검출", 1), (" (원본에 없던 FAIL 이 새로 나옴)", 0)],
                   [("처음 고른 TB 가 놓친 2 개 (B3 · B9) 는 ", 0), ("다른 TB 가 잡음", 1),
                    (" → 그룹 TB 끼리 서로 보완", 0)]],
                  page, "tb_mutant")
    tbl(s, 0.92, y0, [0.8, 5.3, 2.9, 4.6, 2.2, 2.36], rows, row_h=0.42, pt=13.5,
        align=["c", "l", "l", "l", "c", "c"], color=col, name="버그 표")
    yc = y0 + 0.42 * len(rows) + 0.25
    card(s, 0.92, yc, 8.95, 1.35, 1, "B3 · B9 : 처음 TB 가 못 잡고 다른 TB 가 잡음",
         ["B3 : D1 은 첫 tick 만 봄 → tb_F 10 초 누적 : 알람 9.990 ms ≠ 10.000 ms",
          "B9 : H1 /get 은 거리 0 cm (백의 자리 0) → tb_I : \"110cm\" ≠ \"010cm\""])
    card(s, 10.13, yc, 8.95, 1.35, 2, "아주 작은 차이도 FAIL",
         ["B3 : tick 1 clk (10 ns) · B5 : 400 cm 한계 100 us (약 1.7 cm)",
          "B7 : 소수점 하나 (\"000.0\" → \"0000\") · B8 : LED 한 비트 (8009 → 8008)"])
    note(s, yc + 1.5, "버그 하나씩 FINAL/sim_file/mutants/<ID> 사본에 넣고 run_mutant.bat 로 그 그룹 TB 전체 실행 · "
                      "숫자 = 원본에 없던 새 FAIL 수 (원본 FAIL 8 개는 뺌) · FAST = 1 (시간 단축) 그대로")
    s.notes_slide.notes_text_frame.text = (
        "TB 가 PASS 만 내는 게 아니라 실제로 버그를 잡는지 확인했습니다. 모듈마다 일부러 버그를 하나씩 넣은 소스 사본을 만들고 "
        "같은 그룹 TB 를 다시 돌렸습니다. 9 개 모두 FAIL 로 나왔고, tick 1 clk 처럼 작은 차이는 타이머 10 초 누적에서, "
        "UART 거리 글자는 SR04 TB 의 NNNcm 비교에서 잡혔습니다. 그룹 TB 끼리 서로 보완합니다.")
    return s


def build(out):
    prs = Presentation(os.path.join(HERE, "ppt_정안성.pptx"))
    # 기존 장은 빼고 이 두 장만 (같은 슬라이드 마스터 · 크기)
    sld = prs.slides._sldIdLst
    for sid in list(sld):
        prs.part.drop_rel(sid.rId)
        sld.remove(sid)
    a = slide_groups(prs, 1)
    check(prs, a, "tb_summary")
    b = slide_mutants(prs, 2)
    check(prs, b, "tb_mutant")
    prs.save(out)
    print("saved", out)


if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "top_TB_검증.pptx"))
