#!/usr/bin/env python3
"""TB 안내서(README.md) + TB 별 색칠 그림 생성기.

단계(STEP) 데이터 하나에서
  - 그림: 블록 다이어그램 위에 단계 번호 · 색으로 포트를 칠함 (tb/<폴더>/img/<tb>.png)
  - README: 같은 번호의 단계 표 (블록 · 꺼낼 포트 · 시간 · 확인할 것)
을 같이 만든다 → 그림 번호와 문서 번호가 어긋날 수 없다.
포트 이름은 gen_diagram 의 블록 데이터로 검사한다 (없는 포트를 적으면 멈춤).

실행: python3 tb_guide.py [폴더 ...] [--open]   (기본: 전부, --open = 만든 그림을 Windows 사진 앱으로 열기)
"""
import os
import re
import sys

import gen_diagram as G

HERE = os.path.dirname(os.path.abspath(__file__))
TB = os.path.join(HERE, "..", "tb")

FONT = {"0": "C0", "1": "F9", "2": "A4", "3": "B0", "4": "99", "5": "92", "6": "82",
        "7": "F8", "8": "80", "9": "90", "_": "FF"}
COM = {3: "0111", 2: "1011", 1: "1101", 0: "1110"}

# Vivado Scope 경로 (블록 id → 경로). assign 블록은 dut 에서 선 이름으로 찾는다
SCOPE = {
    "PIN_IN": "TB 최상위", "PIN_OUT": "TB 최상위",
    "CLKGEN": "dut/U_CLK_GEN_4KHZ", "TICKGEN": "dut/U_TICK_GEN_100HZ",
    "TICKGEN_SW": "dut/U_TICK_GEN_SW", "TICKGEN_TM": "dut/U_TICK_GEN_TM",
    "BD_R": "dut/U_BD_R", "BD_L": "dut/U_BD_L", "BD_U": "dut/U_BD_U", "BD_D": "dut/U_BD_D",
    "SEL": "dut (assign 화면 선택)", "GATE_SW": "dut (assign 버튼 게이팅)", "GATE_WT": "dut (assign 버튼 게이팅)",
    "GATE_TM": "dut (assign 버튼 게이팅)",
    "SCU": "dut/U_STOPWATCH_CONTROL_UNIT", "WCU": "dut/U_WATCH_CONTROL_UNIT", "TCU": "dut/U_TIMER_CONTROL_UNIT",
    "SDP": "dut/U_STOPWATCH_DATAPATH", "WDP": "dut/U_WATCH_DATAPATH", "TDP": "dut/U_TIMER_DATAPATH",
    "H1224": "dut/U_HOUR_12_24",
    "M_MSEC": "dut (assign 화면 MUX)", "M_SEC": "dut (assign 화면 MUX)", "M_MIN": "dut (assign 화면 MUX)",
    "M_HOUR": "dut (assign 화면 MUX)", "OR_MODE": "dut (assign)",
    "FND": "dut/U_FND_CONTROLLER", "LED": "dut (assign LED)",
    # FND 내부 페이지
    "CNT": "dut/U_FND_CONTROLLER/U_COUNTER8", "DOT": "dut/U_FND_CONTROLLER/U_DOT",
    "AC1": "dut/U_FND_CONTROLLER/U_ANODE_CHOICE_TO_MUX1", "AC2": "dut/U_FND_CONTROLLER/U_ANODE_CHOICE_TO_MUX2",
    "SECMUX": "dut/U_FND_CONTROLLER/U_SEC_MUXER", "MINMUX": "dut/U_FND_CONTROLLER/U_MIN_MUXER",
    "M2": "dut/U_FND_CONTROLLER (assign)", "DEC": "dut/U_FND_CONTROLLER/U_DECODER",
    "FDEC": "dut/U_FND_CONTROLLER/U_FND_DEC", "FIN": "dut/U_FND_CONTROLLER", "FOUT": "dut/U_FND_CONTROLLER",
    "U_MSEC": "dut/U_FND_CONTROLLER/U_MSEC", "U_SEC": "dut/U_FND_CONTROLLER/U_SEC",
    "U_MIN": "dut/U_FND_CONTROLLER/U_MIN", "U_HOUR": "dut/U_FND_CONTROLLER/U_HOUR",
}


def step(name, ports, timing, check, extra=""):
    """ports: [(블록 id, 포트), ...]  extra: 그림에 없는 하위 모듈 포트 (문서에만)"""
    return dict(name=name, ports=ports, timing=timing, check=check, extra=extra)


def drop_empty(steps):
    """버튼을 안 쓰는 TB: 디바운서 · 게이팅 단계 빼기 (포트가 비거나 버튼 관련만 남은 단계)"""
    out = []
    for s in steps:
        ports = [bp for bp in s["ports"] if bp[1]]
        if not ports or s["name"] in ("디바운서 출력",):
            continue
        out.append(dict(s, ports=ports))
    return out


# --------------------------------------------------------------------------- 공통 단계 (스톱워치)
def sw_steps(btns, with_lap=True, disp=("M_MSEC", "M_SEC"), extra7=""):
    return [
        step("버튼 누름 (TB)", [("PIN_IN", "btn_" + b) for b in btns],
             "5 ms 누름 + 5 ms 뗌", "TB 가 Top 입력 핀을 직접 누른다"),
        step("4 kHz 샘플 박자", [("CLKGEN", "o_clk_4khz")],
             "250 us 마다 10 ns 펄스", "디바운서 · FND 스캔이 이 펄스의 상승 엣지로 움직인다"),
        step("디바운서 출력", [("BD_" + b, "o_btn") for b in btns],
             "누른 뒤 1.75 ~ 2.0 ms 에 10 ns 펄스 1 개", "4 kHz 샘플 8 번이 모두 1 이 된 순간 1 클럭. 한 번 누름 = 펄스 1 개"),
        step("버튼 게이팅", [("GATE_SW", "w_sw_btn_" + b) for b in btns],
             "o_btn 과 같은 클럭", "mode_sw0 = 1, timer_sw4 = 0 일 때만 o_btn 이 그대로 지나감. 다른 화면이면 0"),
        step("스톱워치 컨트롤 · FSM", [("SCU", p) for p in ("o_sw_run_stop", "o_sw_clear", "o_sw_down")],
             "run_stop · down: 버튼 펄스 다음 클럭(10 ns 뒤)<br>clear: 버튼 펄스와 같은 10 ns", "R → o_sw_run_stop 토글 / L(정지 중) → o_sw_clear 10 ns 펄스 / U(정지 중) → o_sw_down 토글",
             extra="**FSM**: 같은 블록 Objects 의 `c_state` · `n_state` (STOP / RUN). R 펄스 순간 `n_state` 가 바뀌고 다음 클럭에 `c_state` 가 따라감"),
        step("10 ms tick (스톱워치 전용)", [("TICKGEN_SW", "o_tick_10ms")],
             "RUN 한 순간부터 10 ms 마다 10 ns 펄스", "o_sw_run_stop = 1 동안만 센다 (STOP 이면 멈췄다가 이어서), o_sw_clear 면 0 부터. 첫 펄스는 RUN 뒤 정확히 10 ms"),
        step("스톱워치 값", [("SDP", p) for p in ("o_sw_msec", "o_sw_sec", "o_sw_min", "o_sw_hour")] +
             ([("SDP", "o_sw_lap")] if with_lap else []),
             "o_sw_run_stop = 1 동안 tick 다음 클럭에 +1 (다운이면 −1)",
             "올림은 1 클럭씩 늦게 전달: msec → sec → min → hour (최대 4 클럭)",
             extra=extra7 or "내부 카운터: `dut/U_STOPWATCH_DATAPATH/U_MSEC_COUNTER` 의 `o_count`, `o_tick` (SEC · MIN · HOUR 도 같음)"),
        step("화면 MUX", [(m, G_page_top_out(m)) for m in disp],
             "o_sw_* 와 같은 순간", "timer_sw4 = 0, mode_sw0 = 1 → 입력 1 (스톱워치) 이 지나감"),
        step("FND 출력 (최종)", [("FND", "o_fnd_com"), ("FND", "o_fnd_font")],
             "250 us 마다 자리 바뀜, 2 ms 한 바퀴", "아래 'FND 결론' 표의 자리별 값과 같아야 기능 완료"),
        step("LED", [("LED", "led")], "버튼 펄스 다음 클럭", "led1 스톱워치 화면 · led3 초.1/100초 · led2 시.분 · led7 랩"),
    ]


_TOP = None


def G_page_top_out(bid):
    global _TOP
    if _TOP is None:
        _TOP = G.page_top()
    return _TOP.blocks[bid].outs[0][0]


# --------------------------------------------------------------------------- 폴더별 내용
FOLDERS = {}

FOLDERS["01_stopwatch"] = dict(
    title="01_stopwatch — 스톱워치 동작 확인 안내서 (발표: 이종혁)",
    fsm=[
        "### FSM 상태 (`U_STOPWATCH_CONTROL_UNIT` 의 `c_state` · `n_state`)", "",
        "| 지금 상태 | 조건 | 다음 상태 | 출력 |", "|---|---|---|---|",
        "| STOP (리셋) | R (`i_sw_btn_R`) | RUN | `o_sw_run_stop` = 0, L 이 오면 `o_sw_clear` = L (같은 10 ns) |",
        "| RUN | R | STOP | `o_sw_run_stop` = 1, L · U 는 무시 |",
        "",
        "`o_sw_down` 은 상태가 아니라 따로 있는 레지스터 `down_reg` — STOP 에서 U 가 오면 다음 클럭에 뒤집힘.",
    ],
    spec=[
        "| 버튼 (sw0 = 1, 스톱워치 화면) | 동작 |", "|---|---|",
        "| R | 시작 ↔ 정지 |",
        "| L | **정지 중에만** 0 으로 지우기 + 랩 해제 (동작 중 무시) |",
        "| U | **정지 중에만** 업 ↔ 다운 (동작 중 무시) |",
        "| D | 랩: 누른 순간 값을 화면에 고정, 다시 누르면 실시간 (내부 카운터는 계속) |",
        "",
        "범위 00:00:00.00 ~ 23:59:59.99 (끝에서 순환). 다른 화면으로 가도 계속 돈다.",
    ],
    tbs=[
        dict(
            tb="tb_sw_1_run_stop_clear", title="시작 · 정지 · 지우기",
            goal="R 로 시작/정지, 정지 중 L 로 지우기, 동작 중 L · U 무시, 다른 화면 버튼이 안 들어오는지",
            steps=sw_steps("RLUD"),
            phases=[
                ("P1", "리셋", "5 · 7 · 9 · 10", "`c_state` STOP, `o_sw_run_stop` = 0, `o_sw_*` = 0, `led` = 000A, FND \"00.00\""),
                ("P2", "R → 정확히 1.000 s 뒤 R", "3 · 5 · 6 · 7",
                 "`c_state` STOP → RUN → STOP, RUN 구간 (= `o_sw_run_stop` 1) = 1000.000 ms ± 20 us, 그동안 스톱워치 전용 tick 100 번 (RUN 순간부터 셈) → 값 1.00 초"),
                ("P3", "120 ms 동작 후 R, 200 ms 대기", "5 · 7", "`c_state` STOP 동안 `o_sw_*` 변화 없음"),
                ("P4", "정지 중 D(랩) → L", "4 · 5 · 7 · 9",
                 "`c_state` STOP 유지. `o_sw_lap` 0→1, L 의 `o_sw_clear` 펄스에 `o_sw_*` = 0 · `o_sw_lap` = 0, FND \"00.00\""),
                ("P5", "동작 중 L, 그다음 U", "4 · 5 · 7",
                 "`c_state` RUN 유지 (L · U 가 와도 `n_state` RUN), `o_sw_clear` 펄스 **안 나옴**, `o_sw_down` 그대로 0, `o_sw_msec` 계속 증가 (보드 버그 수정 확인)"),
                ("P6", "정지 중 R 과 L 을 같은 순간", "3 · 5 · 7",
                 "`U_BD_R.o_btn` · `U_BD_L.o_btn` 같은 클럭 → 그 10 ns 에 `n_state` RUN + `o_sw_clear` 펄스 → `c_state` RUN, 0 부터 증가 (`[LIMIT]` 기록)"),
                ("P7", "동작 중 시계 화면(mode_sw0 = 0)에서 R · L · U · D", "4 · 5 · 7 · 10",
                 "`w_sw_btn_*` 계속 0 (게이팅) → `c_state` RUN 그대로, 값 증가, `led` = 8009"),
            ],
            fnd=[("P1 리셋 · P4 지운 뒤", "00.00", "초.1/100초")],
        ),
        dict(
            tb="tb_sw_2_rollover_updown", title="올림 · 빌림 경계",
            goal="1/100초 → 초 → 분 → 시 올림, 24 시간 순환, 다운 카운트의 0 → 23:59:59.99 빌림",
            steps=sw_steps("RU", with_lap=False, disp=("M_MSEC", "M_SEC", "M_MIN", "M_HOUR"),
                           extra7="올림 사슬: `dut/U_STOPWATCH_DATAPATH/U_MSEC_COUNTER.o_tick` → `U_SEC_COUNTER.i_tick` → … `U_HOUR_COUNTER` (각 `o_count`)"),
            phases=[
                ("P1", "동작 중 00:00:59.95 프리로드", "6 · 7",
                 "tick 4 번 뒤 59.99 → 5 번째 tick 에 `o_sw_sec` 0, `o_sw_min` 1 (sec 는 msec 보다 1 클럭 늦게)"),
                ("P2", "00:59:59.95 프리로드", "6 · 7", "59:59.99 → **01:00:00.00** (`o_sw_hour` 1)"),
                ("P3", "23:59:59.95 프리로드 (display_mode_sw1 = 1)", "6 · 7 · 8 · 9",
                 "23:59:59.99 → **00:00:00.00**, FND \"00.00\" (시.분). tick 직후 4 클럭 동안 자리가 하나씩 0 으로"),
                ("P4", "정지 중 U → R → 00:00:00.05 프리로드", "3 · 5 · 6 · 7",
                 "`c_state` STOP 에서 U → `o_sw_down` = 1, R → RUN, 00:00:00.00 → **23:59:59.99** → 23:59:59.98"),
                ("P5", "다운 동작 중 U → R → U → R", "3 · 5 · 7",
                 "`c_state` RUN 중 U: `o_sw_down` 그대로 1 / R → STOP 후 U: 0 → R → RUN, 다시 증가"),
            ],
            fnd=[("P3 자정 순환 뒤 (시.분)", "00.00", "시.분")],
            preload=True,
        ),
        dict(
            tb="tb_sw_3_lap", title="랩",
            goal="D 로 화면 고정 / 다시 D 로 실시간, 랩 중 내부 카운터는 계속, 정지 중 L 로 랩 해제",
            steps=sw_steps("RLD", extra7="랩 전 값: `dut/U_STOPWATCH_DATAPATH/U_LAP_CONTROLLER` 의 `i_cnt_msec` … (내부 카운터), 화면 값은 같은 블록 `o_sw_*`"),
            phases=[
                ("P1", "동작 200 ms 후 D, 100 ms 대기", "3 · 6 · 7 · 10",
                 "`o_sw_lap` = 1, `led[7]` = 1, `o_sw_*` 100 ms 동안 고정, `U_LAP_CONTROLLER.i_cnt_msec` 은 9 번 이상 증가"),
                ("P2", "D 한 번 더", "3 · 7", "`o_sw_lap` = 0, `o_sw_*` = `i_cnt_*`"),
                ("P3", "랩 · 동작 중 L → R → L", "4 · 5 · 7",
                 "`c_state` RUN 중 L: `o_sw_clear` 안 나옴, 랩 유지 / R → STOP 후 L: `o_sw_clear` 펄스 → `o_sw_lap` 0, 값 0"),
                ("P4", "정지 중 D → R", "5 · 7", "`c_state` STOP 에서 랩 (랩은 FSM 이 아니라 데이터패스), R → RUN 이어도 `o_sw_*` 고정 · `i_cnt_*` 만 증가"),
                ("P5", "동작 중 00:00:59.98 프리로드 직후 D", "3 · 7",
                 "랩 값 `o_sw_sec`.`o_sw_msec` = 59.98, 내부 `i_cnt_min` = 1 로 넘어감"),
                ("P6", "set_sw2 = 1 로 랩 중 FND, 시.분 화면 200 ms", "8 · 9",
                 "FND = 랩 값 (예 \"12.34\"), set_sw2 = 1 이어도 스톱워치 화면은 **점멸 없음** (\"00.00\")"),
            ],
            fnd=[("P6 랩 값 (초.1/100초)", "12.34", "초.1/100초"), ("P6 시.분 화면 (set_sw2 = 1)", "00.00", "시.분")],
            preload=True,
        ),
    ],
)


# --------------------------------------------------------------------------- 02_timer
def tm_steps(btns):
    return [
        step("버튼 누름 (TB)", [("PIN_IN", "btn_" + b) for b in btns] + [("PIN_IN", "timer_sw4")],
             "5 ms 누름 + 5 ms 뗌", "timer_sw4 = 1 이면 타이머 화면 (mode_sw0 보다 우선)"),
        step("4 kHz 샘플 박자", [("CLKGEN", "o_clk_4khz")],
             "250 us 마다 10 ns 펄스", "디바운서 · FND 스캔이 이 펄스의 상승 엣지로 움직인다"),
        step("디바운서 출력", [("BD_" + b, "o_btn") for b in btns],
             "누른 뒤 1.75 ~ 2.0 ms 에 10 ns 펄스 1 개", "한 번 누름 = 펄스 1 개"),
        step("화면 선택 · 버튼 게이팅", [("SEL", "w_sel_tm")] + [("GATE_TM", "w_tm_btn_" + b) for b in btns],
             "o_btn 과 같은 클럭", "w_sel_tm = timer_sw4. 타이머 화면일 때만 o_btn 이 w_tm_btn_X 로 지나감"),
        step("타이머 컨트롤 · FSM", [("TCU", p) for p in ("o_tm_add", "o_tm_amount", "o_tm_run", "o_tm_clear", "o_tm_alarm")],
             "add · amount · clear: 버튼 펄스와 같은 10 ns<br>run · alarm: 다음 클럭",
             "SET: U/R/D → o_tm_add 펄스 + o_tm_amount 0/1/2, L → o_tm_run 1 / RUN: L → o_tm_clear / 0 이 되면 o_tm_alarm 1",
             extra="**FSM**: 같은 블록 Objects 의 `c_state` · `n_state` (SET / RUN / ALARM). `o_tm_run` = (c_state == RUN), `o_tm_alarm` = (c_state == ALARM)"),
        step("10 ms tick (타이머 전용)", [("TICKGEN_TM", "o_tick_10ms")], "RUN 한 순간부터 10 ms 마다 10 ns 펄스",
             "o_tm_run = 1 동안만 센다, o_tm_clear(취소) 면 0 부터. 첫 감소는 시작 뒤 정확히 10 ms"),
        step("타이머 값", [("TDP", p) for p in ("o_tm_msec", "o_tm_sec", "o_tm_min", "o_tm_zero")],
             "더하기: o_tm_add 다음 클럭 / 줄이기: tick 다음 클럭에 −1",
             "o_tm_zero 는 TCU 의 i_tm_zero 로 되돌아간다 (0 이면 시작 안 함, 동작 중 0 → 알람)"),
        step("화면 MUX", [("M_HOUR", "w_disp_hour"), ("M_MIN", "w_disp_min"), ("M_MSEC", "w_disp_msec"), ("OR_MODE", "w_disp_mode")],
             "o_tm_* 와 같은 순간",
             "timer_sw4 = 1 → 입력 0: w_disp_hour = 분, w_disp_min = 초, w_disp_mode = 1 (화면 \"분.초\")"),
        step("FND 출력 (최종)", [("FND", "o_fnd_com"), ("FND", "o_fnd_font")],
             "250 us 마다 자리 바뀜, 2 ms 한 바퀴", "아래 'FND 결론' 표의 자리별 값과 같아야 기능 완료"),
        step("LED", [("LED", "led")], "o_tm_run · o_tm_alarm 과 같은 순간",
             "led5 타이머 화면 · led6 동작 중 / 알람 중: 16 개 전부 `U_WATCH_DATAPATH.o_wt_msec` ≥ 50 일 때 켬 (0.5 초 점멸)"),
    ]


FOLDERS["02_timer"] = dict(
    title="02_timer — 타이머 동작 확인 안내서 (발표: 정보윤)",
    fsm=[
        "### FSM 상태 (`U_TIMER_CONTROL_UNIT` 의 `c_state` · `n_state`)", "",
        "| 지금 상태 | 조건 | 다음 상태 | 출력 |", "|---|---|---|---|",
        "| SET (리셋) | L & `i_tm_zero` = 0 | RUN | U / R / D → `o_tm_add` 10 ns + `o_tm_amount` 0 / 1 / 2 (같은 10 ns). L 인데 0 이면 SET 그대로 |",
        "| RUN | L | SET | `o_tm_run` = 1. L 이면 `o_tm_clear` 10 ns (값 0). U · R · D 무시 |",
        "| RUN | `i_tm_zero` = 1 (0 이 됨) | ALARM | 다음 클럭에 `o_tm_run` 0 · `o_tm_alarm` 1 이 동시에 |",
        "| ALARM | 아무 버튼 | SET | `o_tm_alarm` = 1. 버튼은 끄기로만 쓰임 (`o_tm_add` 안 나옴) |",
    ],
    spec=[
        "| 상태 | 버튼 (timer_sw4 = 1) | 동작 |", "|---|---|---|",
        "| SET | U / R / D | +10 초 / +1 분 / +10 분, **최대 59:59** (넘으면 59:59) |",
        "| SET | L | 시작 (남은 시간 0 이면 시작 안 함) |",
        "| RUN | L | 취소 → 00:00, SET |",
        "| RUN | U / R / D | 무시 |",
        "| ALARM | 아무 버튼 | 알람 끄기 → SET (더하기로 안 쓰임) |",
        "",
        "0 이 되면 알람: LED 16 개가 0.5 초마다 켜짐/꺼짐 (어느 화면에서나). 화면은 display_mode_sw1 과 상관없이 \"분.초\".",
        "10 ms tick 은 타이머 전용(U_TICK_GEN_TM, RUN 순간부터 셈)이라 설정 T 초는 정확히 T 초 뒤에 끝난다 (10/17 ④. 그 전 공용 tick 판은 (T − 10 ms) ~ T).",
    ],
    tbs=[
        dict(
            tb="tb_tm_1_add_cap", title="더하기 · 상한 59:59",
            goal="U/R/D 더하는 양, 초 → 분 올림, 59:59 에서 고정, 0 에서 L 로 시작 안 함",
            steps=tm_steps("RLUD"),
            phases=[
                ("P1", "리셋 후 timer_sw4 = 1", "4 · 8 · 9 · 10", "`w_disp_mode` = 1, `led` = 0020 (led5), FND \"00.00\""),
                ("P2", "00:00 에서 L", "5", "`c_state` SET 그대로 (`i_tm_zero` = 1 이라 `n_state` 도 SET), `o_tm_run` 0, `o_tm_alarm` 0"),
                ("P3", "U × 5 → U", "5 · 7 · 9", "`c_state` SET 에서 U 마다 `o_tm_add` 펄스 + `o_tm_amount` 0 → +10 초: 00:50 → **01:00** (초 → 분 올림), FND \"01.00\""),
                ("P4", "R → D → U", "5 · 7", "`o_tm_amount` 1 / 2 / 0: 01:00 → 11:00 → 11:10"),
                ("P5", "D × 5 → R × 9 → U × 5 → U", "7 · 9", "50:00 → 59:00 → 59:50 → **59:59** (60:00 아님), FND \"59.59\""),
                ("P6", "59:59 에서 U, R, D", "5 · 7", "`o_tm_add` 펄스가 나와도 `o_tm_*` 59:59 유지"),
                ("P7", "52:10 에서 D → R", "7", "52:10 + 10 분 → **59:59**, R 에도 59:59"),
            ],
            fnd=[("P1 리셋", "00.00", "분.초"), ("P3 끝", "01.00", "분.초"), ("P5 끝", "59.59", "분.초")],
        ),
        dict(
            tb="tb_tm_2_countdown_alarm", title="실제 카운트다운 · 알람",
            goal="10 초를 프리로드 없이 실제로 흘려 정확도 확인, 알람 LED, 알람 끄기, 빼기 빌림",
            steps=tm_steps("LUD"),
            phases=[
                ("P1", "U(00:10) → L, 끝까지 (약 10 초)", "5 · 6 · 7 · 10",
                 "`c_state` SET → RUN → ALARM. RUN 진입 → ALARM 진입 간격 (= `o_tm_run` ↑ → `o_tm_alarm` ↑) **10.000 초 + 2 클럭(20 ns)** (RUN 순간부터 전용 tick 이 셈. 10/17 ④ 전 공용 tick 판은 9.990 초 초과 ~ 10.000 초), 그때 `o_tm_*` = 0, 동작 중 `led[6]` = 1"),
                ("P2", "알람 1.5 초 (P1 에 이어서)", "10", "`c_state` ALARM 유지. `o_wt_msec` ≥ 50 이면 `led` = FFFF, 아니면 0000. 저절로 안 꺼짐"),
                ("P3", "D 로 알람 끄기 (P2 에 이어서)", "5 · 7 · 10", "`c_state` ALARM → SET, `o_tm_add` **안 나옴** → 값 00:00 그대로, `led` = 0020"),
                ("P4", "동작 중 01:00.00, 10:00.00 프리로드", "6 · 7 · 9", "다음 tick 에 **00:59.99**, **09:59.99** (FND \"09.59\")"),
            ],
            fnd=[("P1 알람 때", "00.00", "분.초"), ("P4 10:00.00 다음 tick", "09.59", "분.초")],
            preload=True,
            note="P2 · P3 은 P1 의 알람을 이어서 쓴다. `RUN_PHASE = 1` 로 실행하면 P1~P3 이 같이 돈다.",
        ),
        dict(
            tb="tb_tm_3_cancel_background", title="취소 · 백그라운드 · 버튼 게이팅",
            goal="동작 중 더하기 무시, L 취소, 다른 화면에서도 줄어들고 알람, 다른 화면 버튼으로 알람 안 꺼짐, sw4 우선",
            steps=tm_steps("RLUD"),
            phases=[
                ("P1", "01:00 시작 후 U, R, D", "5 · 7", "`c_state` RUN 유지, `o_tm_add` **안 나옴**, 값은 약 30 ms 만큼만 줄어듦"),
                ("P2", "동작 중 L", "5 · 7", "`c_state` RUN → SET, 그 10 ns 에 `o_tm_clear` 펄스 → **00:00.00**"),
                ("P3", "01:00 시작 → 시계 화면 → 00:00.30 프리로드", "4 · 7 · 9 · 10",
                 "시계 화면에서도 `c_state` RUN → ALARM, `led` 알람 패턴, FND 는 시계 \"12.00\""),
                ("P4", "알람 중 시계 화면 U/D/L/R, 스톱워치 화면 D", "4 · 5", "`w_tm_btn_*` 모두 0 → `c_state` **ALARM 유지**"),
                ("P5", "timer_sw4 = 1 & mode_sw0 = 1 → R", "4 · 5 · 7 · 10",
                 "`w_sel_tm` = 1, R 로 `c_state` ALARM → SET · `o_tm_add` 안 나옴 (1 분 안 더해짐), `led` = 0020"),
            ],
            fnd=[("P2 취소 뒤", "00.00", "분.초"), ("P3 시계 화면 (알람 중)", "12.00", "시계 시.분")],
            preload=True,
        ),
    ],
)


# --------------------------------------------------------------------------- 03_watch
def wt_steps(btns, disp=("M_HOUR", "M_MIN")):
    return [
        step("버튼 · 스위치 (TB)", [("PIN_IN", "btn_" + b) for b in btns] + [("PIN_IN", "set_sw2"), ("PIN_IN", "hour24_sw3")],
             "5 ms 누름 + 5 ms 뗌", "mode_sw0 = 0, timer_sw4 = 0 (시계 화면). set_sw2 = 1 설정 모드, hour24_sw3 = 0 이면 12 시간 표시"),
        step("4 kHz 샘플 박자", [("CLKGEN", "o_clk_4khz")],
             "250 us 마다 10 ns 펄스", "디바운서 · FND 스캔이 이 펄스의 상승 엣지로 움직인다"),
        step("디바운서 출력", [("BD_" + b, "o_btn") for b in btns],
             "누른 뒤 1.75 ~ 2.0 ms 에 10 ns 펄스 1 개", "한 번 누름 = 펄스 1 개"),
        step("화면 선택 · 버튼 게이팅", [("SEL", "w_sel_wt")] + [("GATE_WT", "w_wt_btn_" + b) for b in btns],
             "o_btn 과 같은 클럭", "w_sel_wt = ~timer_sw4 & ~mode_sw0. 시계 화면일 때만 o_btn 이 w_wt_btn_X 로 지나감"),
        step("시계 컨트롤 · FSM", [("WCU", p) for p in ("o_wt_cursor", "o_wt_up", "o_wt_down")],
             "cursor: L/R 펄스 · set_sw2 다음 클럭<br>up · down: 버튼 펄스와 같은 10 ns",
             "o_wt_cursor 0 분 일 · 1 분 십 · 2 시 · 3 설정 아님. 설정 아닐 때 up/down 안 나옴. U 와 D 같은 클럭이면 U",
             extra="**FSM**: 같은 블록 Objects 의 `c_state` · `n_state` (NORMAL / SET_MIN_1 / SET_MIN_10 / SET_HOUR). 커서 = 상태 (SET_MIN_1 → 0, SET_MIN_10 → 1, SET_HOUR → 2, NORMAL → 3)"),
        step("10 ms tick", [("TICKGEN", "o_tick_10ms")], "10 ms 마다 10 ns 펄스", "시계는 항상 흐른다 (설정 중에도)"),
        step("시계 값", [("WDP", p) for p in ("o_wt_msec", "o_wt_sec", "o_wt_min", "o_wt_hour")],
             "tick 다음 클럭에 +1 / up · down 다음 클럭에 커서 자리만 ±",
             "o_wt_hour 는 0~23 (24 시간 기준). 설정은 윗자리로 올림 · 내림 없음",
             extra="내부 카운터: `dut/U_WATCH_DATAPATH/U_MIN_COUNTER` 의 `i_up`, `i_down`, `i_step10`, `o_count`"),
        step("12/24 변환", [("H1224", "o_wt_hour_disp"), ("H1224", "o_wt_pm")],
             "o_wt_hour 와 같은 순간 (조합)", "hour24_sw3 = 0: 0 → 12, 13~23 → 1~11 / o_wt_pm = (o_wt_hour ≥ 12)"),
        step("화면 MUX", [(m, G_page_top_out(m)) for m in disp],
             "o_wt_* 와 같은 순간", "timer_sw4 = 0, mode_sw0 = 0 → 입력 2 (시계, 시는 o_wt_hour_disp) 가 지나감"),
        step("FND 출력 (최종)", [("FND", "o_fnd_com"), ("FND", "o_fnd_font")],
             "250 us 마다 자리 바뀜, 2 ms 한 바퀴",
             "아래 'FND 결론' 표와 같아야 기능 완료. 설정 점멸은 `dut/U_FND_CONTROLLER/U_ANODE_CHOICE_TO_MUX2` 의 `o_an0~3` 에서 커서 자리가 `d`(빈칸)"),
        step("LED", [("LED", "led")], "스위치 · 버튼 다음 클럭",
             "led0 시계 화면 · led2 시.분 · led3 초.1/100초 · **led15 오후** (시계 화면 & 12 시간 & o_wt_pm)"),
    ]


FOLDERS["03_watch"] = dict(
    title="03_watch — 시계 동작 확인 안내서 (발표: 정안성)",
    fsm=[
        "### FSM 상태 (`U_WATCH_CONTROL_UNIT` 의 `c_state` · `n_state`)", "",
        "| 지금 상태 (커서) | 조건 | 다음 상태 |", "|---|---|---|",
        "| NORMAL (3, 리셋) | set_sw2 = 1 | SET_MIN_1 |",
        "| SET_MIN_1 (0) | L / R / set_sw2 = 0 | SET_MIN_10 / SET_HOUR / NORMAL |",
        "| SET_MIN_10 (1) | L / R / set_sw2 = 0 | SET_HOUR / SET_MIN_1 / NORMAL |",
        "| SET_HOUR (2) | L / R / set_sw2 = 0 | SET_MIN_1 / SET_MIN_10 / NORMAL |",
        "",
        "우선순위: set_sw2 = 0 → L → R. 출력: `o_wt_cursor` = 상태 (괄호 안 숫자, 무어). `o_wt_up` = U, `o_wt_down` = D & ~U — SET_x 이고 set_sw2 = 1 일 때만, 버튼 펄스와 같은 10 ns (밀리).",
    ],
    spec=[
        "리셋 = **12:00:00.00 (오후 12 시)**, 기본 12 시간 표시. 설정 모드 = 시계 화면(mode_sw0 = 0) + set_sw2 = 1", "",
        "| 버튼 | 동작 |", "|---|---|",
        "| L / R | 커서 이동. L: 분 일 → 분 십 → 시 → 분 일, R: 반대 (양 끝에서 돌아감) |",
        "| U / D | 커서 자리만 ±. 분 일 ±1, 분 십 ±10, 시 ±1. **윗자리로 올림/내림 없음** (분 59 + 1 → 00, 시 그대로) |",
        "| U + D 동시 | U 우선 |",
        "",
        "설정에 들어가면 항상 분 일의 자리부터. 초 · 1/100 초는 설정 안 함. 설정 중에도 시계는 흐른다. 설정 중 커서 자리가 0.5 초마다 빈칸 (시.분 화면).",
    ],
    tbs=[
        dict(
            tb="tb_wt_1_set_ui", title="설정 UI",
            goal="설정 아닐 때 버튼 무시, 커서 이동 · 양 끝 회전, 자리별 ± 회전, U 우선, 재진입 커서, 다른 화면 버튼 차단",
            steps=wt_steps("RLUD"),
            phases=[
                ("P1", "리셋", "5 · 7 · 10 · 11", "`c_state` NORMAL, 12:00:00.00, `o_wt_cursor` = 3, `led` = 8009 (led0 · led3 · led15)"),
                ("P2", "set_sw2 = 0 에서 U, D, L, R", "4 · 5 · 7", "`c_state` NORMAL 유지, `o_wt_up` · `o_wt_down` 안 나옴, 12:00 그대로"),
                ("P3", "set_sw2 = 1 → L × 3 → R × 3", "5", "`c_state` NORMAL → SET_MIN_1 / L: SET_MIN_1 → SET_MIN_10 → SET_HOUR → SET_MIN_1 / R: 반대 (`o_wt_cursor` 0 → 1 → 2 → 0)"),
                ("P4", "커서 0, 12:59 프리로드 → U → D → D", "5 · 7", "`c_state` SET_MIN_1: 12:00 (**시 13 아님**) → 12:59 → 12:58"),
                ("P5", "커서 1, 12:55 프리로드 → U → D → D", "5 · 7", "`c_state` SET_MIN_10: 12:05 → 12:55 → 12:45 (분 십 ±10 회전)"),
                ("P6", "커서 2 에서 U → 23:30 프리로드 → U → D", "5 · 7", "`c_state` SET_HOUR: 13:00 → 00:30 (**분 그대로**) → 23:30"),
                ("P7", "U 와 D 를 같은 순간", "3 · 5 · 7", "`U_BD_U.o_btn` · `U_BD_D.o_btn` 같은 클럭 → `o_wt_up` 만 1 → 12:01"),
                ("P8", "커서를 시로 옮긴 뒤 set_sw2 끔 → 다시 켬", "5", "SET_HOUR → (끔) NORMAL → (켬) **SET_MIN_1** (`o_wt_cursor` 3 → 0)"),
                ("P9", "set_sw2 = 1 인 채 스톱워치 · 타이머 화면에서 버튼", "4 · 5 · 7", "`w_wt_btn_*` 모두 0 → `c_state` 그대로, 시간 안 바뀜, 시계는 계속 흐름"),
            ],
            fnd=[("P1 리셋 (시.분)", "12.00", "시.분, 12 시간")],
            preload=True,
            note="TB 전체에서 상시 감시: `U_WATCH_DATAPATH/U_SEC_COUNTER` · `U_MSEC_COUNTER` 의 `i_up` · `i_down` 은 한 번도 1 이 되면 안 된다 (초 설정 없음).",
        ),
        dict(
            tb="tb_wt_2_rollover", title="1 초 정확도 · 올림 경계",
            goal="1 초 = 1 억 클럭 실측, 초 → 분 → 시 → 자정 올림, 설정 중에도 흐름",
            steps=drop_empty(wt_steps("", disp=("M_MSEC", "M_SEC", "M_MIN", "M_HOUR"))),
            phases=[
                ("P1", "리셋 후 프리로드 없이 2 초", "5 · 6", "`o_wt_sec` 바뀌는 간격 = 정확히 **1,000,000,000 ns**, 2 초 뒤 12:00:02.00"),
                ("P2", "00:00:59.95 프리로드", "5 · 6", "tick 4 번 뒤 59.99 → 5 번째 tick 에 **00:01:00.00**"),
                ("P3", "00:59:59.95 프리로드", "5 · 6", "**01:00:00.00**"),
                ("P4", "23:59:59.95 프리로드 (시.분, 12 시간)", "5 · 6 · 7 · 9 · 10",
                 "직후 `o_wt_pm` 1 · `led[15]` 1 → **00:00:00.00** 에서 `o_wt_pm` 0 · `led[15]` 0, `o_wt_hour_disp` 12, FND \"12.00\""),
                ("P5", "설정 모드에서 23:59:59.95 프리로드", "4 · 6", "`c_state` SET_MIN_1 (설정 중) 이어도 00:00:00.00 으로 넘어감"),
            ],
            fnd=[("P4 자정 뒤 (시.분, 12 시간)", "12.00", "시.분")],
            preload=True,
            note="P4 파형 포인트: tick 직후 4 클럭 동안 23:59:59.99 → 23:59:59.00 → 23:59:00.00 → 23:00:00.00 → 00:00:00.00 (올림이 1 클럭씩 늦게 전달, 30 ns).",
        ),
        dict(
            tb="tb_wt_3_display_12h", title="12/24 표시 · FND · 점멸 · LED",
            goal="0 시와 12 시가 둘 다 '12' 로 보이는 변환, 화면 문자열, 설정 점멸, LED 조합",
            steps=wt_steps("L", disp=("M_HOUR", "M_MIN")),
            phases=[
                ("P1", "시 0~23 × hour24_sw3 0/1 (48 경우)", "7 · 8 · 11",
                 "12 시간: 0 → 12, 1~12 그대로, 13~23 → −12 / 24 시간: 그대로. `led[15]` = 12 시간 & 12 시 이상"),
                ("P2", "12:34, 13:05 프리로드", "8 · 10 · 11", "FND \"12.34\" / 24 시간 \"13.05\" / 12 시간 \"01.05\" + `led[15]` 1"),
                ("P3", "12:34 에서 설정, 커서 0 · 1 · 2 각 1 초", "5 · 10",
                 "`c_state` SET_MIN_1 / SET_MIN_10 / SET_HOUR 에서 `o_wt_msec` ≥ 50 동안 커서 자리만 빈칸 (`U_DOT.o_blink_off` = 1): \"12.3_\" / \"12._4\" / \"1_.34\". NORMAL 이면 점멸 없음"),
                ("P4", "display_mode_sw1 × hour24_sw3 × 오전/오후 (9 시, 21 시) 8 경우", "11",
                 "`led` = led0 + (sw1 ? led2 : led3) + (12 시간 & 오후 ? led15)"),
            ],
            fnd=[("P2 12:34", "12.34", "시.분"), ("P2 13:05, 24 시간", "13.05", "시.분"), ("P2 13:05, 12 시간", "01.05", "시.분"),
                 ("P3 커서 0, msec ≥ 50", "12.3_", "시.분"), ("P3 커서 1, msec ≥ 50", "12._4", "시.분"),
                 ("P3 커서 2, msec ≥ 50", "1_.34", "시.분")],
            preload=True,
        ),
    ],
)


# --------------------------------------------------------------------------- top (공통)
FOLDERS["top"] = dict(
    title="top — 공통 (버튼 디바운서 · FND 스캔) 확인 안내서",
    spec=[
        "| 블록 | 사양 |", "|---|---|",
        "| 디바운서 (`U_BD_R/L/U/D`) | 4 kHz(250 us) 로 8 번 샘플, 8 번 모두 1 이면 눌림 → `o_btn` 10 ns 펄스 1 개. 1.75 ms 이하 누름은 무시, 2.0 ms 이상은 1 번 |",
        "| FND 스캔 (`U_FND_CONTROLLER`) | 4 kHz 마다 `o_scan_sel` +1 (0~7). 0~3 숫자 AN0~AN3, 4~7 빈칸 (6 은 AN2 가운데 점). 한 바퀴 2 ms |",
        "",
        "두 기능 모두 스톱워치 · 시계 · 타이머가 같이 쓰는 공통 블록이라 여기서 한 번에 확인한다.",
    ],
    tbs=[
        dict(
            tb="tb_top_1_btn_debounce", title="버튼 디바운서 (누름 시간 · 바운스)",
            goal="누름 길이에 따른 인식/무시, 바운스 · 긴 누름에서 펄스 1 개, 펄스 폭 1 클럭 (시계 설정 모드 U 로 분 증가량을 셈)",
            steps=[
                step("버튼 · 스위치 (TB)", [("PIN_IN", "btn_U"), ("PIN_IN", "set_sw2")],
                     "누름 1.0 ms ~ 2 s, 바운스 패턴", "시계 설정 모드(set_sw2 = 1, 커서 0) 에서 U 를 여러 길이로 누른다"),
                step("4 kHz 샘플 박자", [("CLKGEN", "o_clk_4khz")], "250 us 마다 10 ns 펄스", "디바운서가 이 펄스 상승 엣지마다 i_btn 을 1 번 샘플"),
                step("디바운서 출력", [("BD_U", "o_btn")], "누른 뒤 1.75 ~ 2.0 ms 에 10 ns 펄스 1 개",
                     "샘플 8 개가 모두 1 이 된 순간 1 클럭. 누르고 있어도 다시 안 나옴 (자동 반복 없음)",
                     extra="샘플 레지스터: `dut/U_BD_U` 내부 `q_reg[7:0]` (4 kHz 마다 오른쪽으로 밀림)"),
                step("버튼 게이팅", [("SEL", "w_sel_wt"), ("GATE_WT", "w_wt_btn_U")], "o_btn 과 같은 클럭", "시계 화면이라 o_btn 이 그대로 지나감"),
                step("시계 컨트롤 · FSM", [("WCU", "o_wt_up")], "버튼 펄스와 같은 10 ns", "설정 모드라 U 펄스가 o_wt_up 으로 나감",
                     extra="**FSM**: `c_state` · `n_state` 가 TB 내내 SET_MIN_1 (커서 0) 인지"),
                step("시계 값", [("WDP", "o_wt_min")], "o_wt_up 다음 클럭", "인식된 눌림 1 번 = 분 +1"),
                step("FND 출력 (최종)", [("FND", "o_fnd_com"), ("FND", "o_fnd_font")], "250 us 마다 자리 바뀜", "아래 'FND 결론' 표"),
                step("LED", [("LED", "led")], "리셋 직후", "모든 스위치 0 → `led` = 8009"),
            ],
            phases=[
                ("P0", "리셋 직후 1 us", "8", "`fnd_com` · `fnd_font` · `led` 에 X 없음, `led` = 8009, 12:00:00.00"),
                ("P1", "U 를 1.0 / 1.5 / 1.7 / 2.0 / 2.5 / 5 / 100 ms 누름", "2 · 3 · 6",
                 "1.0 · 1.5 · 1.7 ms: `o_btn` **없음** / 2.0 · 2.5 · 5 · 100 ms: `o_btn` **1 개**, `o_wt_min` +1"),
                ("P2", "바운스 패턴 (40 us ~ 300 us 튐 + 20 ms 누름)", "2 · 3 · 6", "`o_btn` 정확히 1 개, `o_wt_min` +1"),
                ("P3", "2 초 길게 누름", "3 · 6", "`o_btn` 1 개 (자동 반복 없음)"),
                ("P4", "누른 중간에 300 us 떨어짐", "2 · 3 · 6", "`o_btn` **2 개**, `o_wt_min` +2 → `[LIMIT]` 기록 (누른 중 끊김은 새 누름으로 봄)"),
                ("P5", "지금까지 모든 `o_btn`", "3", "펄스 폭 = 정확히 10 ns (1 클럭)"),
            ],
            fnd=[("P1 끝 (설정 모드, 커서 0, msec < 50)", "12.04", "시.분"),
                 ("P1 끝 (msec ≥ 50, 커서 자리 점멸)", "12.0_", "시.분")],
        ),
        dict(
            tb="tb_top_2_fnd_scan", title="FND 스캔 · 자리별 출력", page="fnd",
            goal="자리 순서 AN0 → AN3, 한 칸 250 us, 자리별 글자 · 가운데 점 · 설정 점멸이 참조 모델과 같은지 (fnd_monitor 가 전 구간 비교)",
            steps=[
                step("4 kHz 입력", [("FIN", "i_clk_4khz")], "250 us 마다 10 ns 펄스", "`U_CLK_GEN_4KHZ.o_clk_4khz` 와 같은 선"),
                step("스캔 카운터", [("CNT", "o_scan_sel")], "250 us 마다 +1, 2 ms 한 바퀴", "0 → 1 → … → 7 → 0"),
                step("10 진 분리", [("U_MSEC", "o_digit1"), ("U_MSEC", "o_digit10"), ("U_SEC", "o_digit1"), ("U_SEC", "o_digit10"),
                                   ("U_MIN", "o_digit1"), ("U_MIN", "o_digit10"), ("U_HOUR", "o_digit1"), ("U_HOUR", "o_digit10")],
                     "i_disp_* 와 같은 순간 (조합)", "예: i_disp_min = 34 → o_digit10 = 3, o_digit1 = 4"),
                step("점멸 박자", [("DOT", "o_blink_off")], "i_disp_msec ≥ 50 동안 1 (0.5 초 주기)", "1 이면 커서 자리 빈칸, 가운데 점 꺼짐"),
                step("설정 점멸", [("AC1", "o_an0"), ("AC2", "o_an0"), ("AC2", "o_an1"), ("AC2", "o_an2")],
                     "o_blink_off 와 같은 순간", "시계 화면 & set_sw2 & 시.분 & o_blink_off 일 때만 커서 자리를 `d` (빈칸) 로"),
                step("자리 고르기", [("SECMUX", "o_data"), ("MINMUX", "o_data")], "o_scan_sel 과 같은 순간",
                     "o_scan_sel 0~3 → o_an0~3, 4 · 5 · 7 → f (빈칸), 6 → {111, o_blink_off} (점)"),
                step("초 / 시.분 선택", [("M2", "w_bcd")], "o_data 와 같은 순간", "i_disp_mode 0 → 초.1/100초 쪽, 1 → 시.분 쪽"),
                step("자리 켜기 (최종)", [("DEC", "o_fnd_com")], "o_scan_sel[1:0] 과 같은 순간", "00 → 1110 (AN0) … 11 → 0111 (AN3)"),
                step("글자 (최종)", [("FDEC", "o_fnd_font")], "w_bcd 와 같은 순간", "아래 'FND 결론' 표"),
            ],
            phases=[
                ("P1", "20 ms 동안 `fnd_com` 80 번 바뀜", "1 · 2 · 8", "순서 1110 → 1101 → 1011 → 0111 반복, 한 칸 폭 정확히 **250,000 ns**"),
                ("P2", "시계 시.분: 리셋 → 12:34 프리로드 → 설정 모드 1 초", "3 · 5 · 9", "\"12.00\" → \"12.34\" → 커서 0 점멸 (\"12.3_\" ↔ \"12.34\")"),
                ("P3", "시계 초.1/100초 1 초", "4 · 6", "o_scan_sel 6 칸의 `o_fnd_font` = 7F (점) 인 프레임이 절반 (i_disp_msec < 50)"),
                ("P4", "스톱워치 · 타이머 화면", "7 · 9", "스톱워치 \"34.56\" (초.1/100초) · \"00.00\" (시.분), 타이머 \"12.34\" (분.초), 타이머 + set_sw2 → 점멸 없음"),
            ],
            fnd=[("P2 리셋", "12.00", "시계 시.분"), ("P2 12:34", "12.34", "시계 시.분"), ("P2 설정, msec ≥ 50", "12.3_", "시계 시.분"),
                 ("P4 스톱워치 00:00:34.56", "34.56", "초.1/100초"), ("P4 타이머 12:34", "12.34", "분.초")],
            preload=True,
            note="TB 전체에서 `fnd_monitor` 가 `fnd_com` · `fnd_font` 를 참조 모델과 계속 비교한다. 다르면 그 구간마다 `[FAIL] ... FND` + 시각.",
        ),
    ],
)


# --------------------------------------------------------------------------- 그리기 · 문서
def check_steps(pg, steps):
    for i, s in enumerate(steps, 1):
        for b, p in s["ports"]:
            blk = pg.blocks[b]  # 없으면 KeyError
            if p not in blk.all_outputs() and p not in blk.all_inputs():
                raise SystemExit(f"단계 {i} '{s['name']}': {b}.{p} 포트 없음")


CLK_STEP_TOP = step(
    "클럭 · 리셋 (TB)", [("PIN_IN", "clk"), ("PIN_IN", "rst")],
    "clk: 10 ns 주기 (100 MHz)<br>rst: 각 Phase 시작에 1 us 펄스",
    "모든 '다음 클럭' 의 기준. rst = 1 동안 모든 블록 `i_rst` = 1 → FSM 은 리셋 상태 (STOP · NORMAL · SET), 값은 리셋값, "
    "4 kHz · 10 ms 카운터도 0 부터 다시 셈 (tick 위상의 기준)")
CLK_STEP_FND = step(
    "클럭 · 리셋 (TB)", [("FIN", "i_rst")],
    "clk: 10 ns 주기 (100 MHz)<br>rst: 각 Phase 시작에 1 us 펄스",
    "TB 최상위 `clk` · `rst` 를 같이 넣는다. FND 컨트롤러는 `i_rst` 만 받고 (`i_rst` = Top `rst`), 자리 스캔은 `i_clk_4khz` 로 움직인다. "
    "rst = 1 동안 `o_scan_sel` = 0")


def with_clk(t):
    """(단계, Phase) — 1 단계에 클럭 · 리셋을 넣고 Phase 의 단계 번호를 하나씩 민다"""
    first = CLK_STEP_FND if t.get("page") == "fnd" else CLK_STEP_TOP
    steps = [first] + t["steps"]
    phases = [(p[0], p[1], re.sub(r"\d+", lambda m: str(int(m.group(0)) + 1), p[2]), p[3]) for p in t["phases"]]
    # 리셋을 보는 Phase 는 1 단계 (클럭 · 리셋) 도 본다
    phases = [(p[0], p[1], ("1 · " + p[2]) if p[1].startswith("리셋") else p[2], p[3]) for p in phases]
    return steps, phases


def figure(folder, t):
    pg = G.page_fnd() if t.get("page") == "fnd" else G.page_top()
    steps, _ = with_clk(t)
    check_steps(pg, steps)
    hl = {}
    for i, s in enumerate(steps, 1):
        for bp in s["ports"]:
            hl.setdefault(bp, i)
    legend = [f"{s['name']}" for s in steps]
    svg = G.render(pg, highlight=hl, steps_legend=legend,
                   subtitle=f"{t['tb']} — {t['title']}  (번호 = README 단계, 색칠 안 된 선은 이 TB 에서 안 봄)")
    out = os.path.join(TB, folder, "img")
    os.makedirs(out, exist_ok=True)
    png = os.path.join(out, t["tb"] + ".png")
    G.to_png(svg, png, pg.W, pg.H)
    return png, (svg, pg.W, pg.H)


def port_cell(b, p):
    return f"`{p}`"


def fnd_table(rows):
    L = ["| 순간 | 화면 | AN3 (`fnd_com`=0111) | AN2 (1011) | AN1 (1101) | AN0 (1110) | 가운데 점 (o_scan_sel 6, AN2) |",
         "|---|---|---|---|---|---|---|"]
    for when, disp, mode in rows:
        d3, d2, d1, d0 = disp[0], disp[1], disp[3], disp[4]
        cell = lambda c: f"`{FONT[c]}` ({'빈칸' if c == '_' else c})"
        L.append(f"| {when} | \"{disp}\" ({mode}) | {cell(d3)} | {cell(d2)} | {cell(d1)} | {cell(d0)} | "
                 f"i_disp_msec < 50 → `7F` 점 켬, ≥ 50 → `FF` |")
    return L


COMMON = """
## 0. 시작 전에 (처음 한 번)

1. **Vivado 소스**: Design Sources = `../../source_file/*.v, *.sv` / Simulation Sources = 이 폴더의 `tb_*.sv` 하나 + `fnd_monitor.sv` → TB 를 *Set as Top*
2. **Run Simulation → Run All**. 콘솔 마지막 `[SUMMARY] ... => PASS` 면 이 TB 의 모든 기준 통과. `[FAIL]` 이 있으면 그 시각으로 *Go To Time*
   - 콘솔 읽는 법: Phase 마다 `[BEGIN]` 아래 `plan` (TB 가 할 일) · `expect` (정상 결과). 그다음 TB 가 한 일이 한 줄씩 `[RESET]` `[SW]` `[BTN]` `[WAIT]` `[PRELOAD]` 로 찍히고, 오른쪽에 그 전 → 후 값 (지금 화면 값 · FSM 상태). 검사는 `[OK]` / `[FAIL]` (exp = 기대, got = 실제)
   - 줄 맨 앞 `[시각]` 이 파형 *Go To Time* 에 넣을 시각. `[BTN]` 의 `o_btn @` 시각 = 디바운서 펄스 (파형의 X_tick) 위치
3. **파형에 신호 넣기** — 아래 각 TB 의 "단계" 표 순서대로
   - Scope 창에서 `tb_xxx → dut → U_xxx` 인스턴스를 클릭 → Objects 창에 **그 모듈의 포트**가 나온다 → 표의 포트를 우클릭 *Add to Wave Window*
   - `dut (assign …)` 이라고 적힌 것은 모듈이 아니라 Top 안 선이다 → Scope 에서 `dut` 를 클릭하면 Objects 에 같은 이름의 `w_` 선이 있다
   - 이름 규칙: 모듈 출력 `o_xxx` → Top 선 `w_xxx` → 다음 모듈 입력 `i_xxx` (몸통 이름이 같다). 전체 연결은 `../../source_file/PORT_MAP.md`
4. **Radix**: 시간 값(`o_sw_msec` 등) = Unsigned Decimal, `fnd_com` = Binary, `fnd_font` = Hexadecimal
5. **10 ns 펄스 찾기**: `o_clk_4khz`, `o_tick_10ms`, `o_btn` 은 10 ns 짜리라 줌을 당기면 안 보인다 → 신호를 고르고 툴바의 *Go to next transition* 으로 하나씩 이동
6. **`clk` · `rst` 는 항상 같이 넣는다** (1 단계). 모든 "다음 클럭" 타이밍의 기준이다. 수 초짜리 시뮬에서 `clk` 를 넣으면 파형이 커지므로, 긴 TB 는 파일 맨 위 `RUN_PHASE` 를 Phase 번호로 바꿔 그 Phase 만 실행
7. **FSM 상태 보기**: 컨트롤 유닛 (`U_STOPWATCH_CONTROL_UNIT` · `U_WATCH_CONTROL_UNIT` · `U_TIMER_CONTROL_UNIT`) 을 고르면 Objects 창에 포트 말고 `c_state` · `n_state` 도 있다. enum 이라 파형에 숫자 대신 **STOP · RUN · SET_MIN_1 · ALARM 같은 이름**으로 나온다
   - `n_state` = 다음 상태 (조합): 버튼 펄스가 들어온 **그 10 ns** 에 바뀐다
   - `c_state` = 현재 상태 (레지스터): **다음 클럭 엣지**에 `n_state` 값으로 바뀐다 → 출력 (`o_sw_run_stop` 등) 이 이때 바뀜
   - 각 폴더의 "FSM 상태" 표와 Phase 표의 "상태" 를 같이 보면 된다
8. **프리로드**: `[PRELOAD]` 가 찍힌 시각에 TB 가 카운터에 경계 바로 앞 값(예 23:59:59.95)을 직접 넣는다 (주파수는 그대로 100 MHz). 경계를 넘는 것은 그 뒤 실제 tick 으로 본다
   - 파형에서 **tick · 버튼 없이 값이 갑자기 바뀌는 곳 = 프리로드** (버튼 · DUT 동작 아님). 콘솔 다음 줄에 바뀌기 전 → 후 값이 찍힌다

## 1. 시간 단위 (파형에서 먼저 확인할 것)

| 신호 (블록.포트) | 주기 | 펄스 폭 | 의미 |
|---|---|---|---|
| `U_CLK_GEN_4KHZ.o_clk_4khz` | **250 us** (4 kHz) | 10 ns | 디바운서 샘플 박자, FND 자리 바꾸는 박자 |
| `U_TICK_GEN_100HZ.o_tick_10ms` | **10 ms** (100 Hz) | 10 ns | 1/100 초 한 칸. **시계 전용**, 항상 흐름 |
| `U_TICK_GEN_SW.o_tick_10ms` · `U_TICK_GEN_TM.o_tick_10ms` | **10 ms** | 10 ns | 스톱워치 · 타이머 전용. 시작(RUN) 순간부터 셈 → 첫 칸이 정확히 10 ms (10/17 ④) |
| `U_BD_x.o_btn` | 누를 때 1 번 | 10 ns | 누른 뒤 **1.75 ~ 2.0 ms** (4 kHz 샘플 8 번) |
| `U_FND_CONTROLLER/U_COUNTER8.o_scan_sel` | 한 칸 **250 us**, 한 바퀴 **2 ms** | — | 0~3 숫자 자리, 4~7 빈칸 · 점 |

## 2. FND 읽는 법 (마지막 판정)

기능이 끝까지 맞았는지는 **FND 출력이 자리마다 맞는 글자를 내는지**로 판정한다.
`fnd_com` 의 0 인 비트가 켜진 자리, 그 순간 `fnd_font` 가 그 자리 글자.

| `o_scan_sel` | `fnd_com` | 자리 | `fnd_font` |
|---|---|---|---|
| 0 | 1110 | AN0 (맨 오른쪽) | 화면 4 번째 글자 |
| 1 | 1101 | AN1 | 화면 3 번째 글자 |
| 2 | 1011 | AN2 | 화면 2 번째 글자 |
| 3 | 0111 | AN3 (맨 왼쪽) | 화면 1 번째 글자 |
| 4 · 5 · 7 | 1110 · 1101 · 0111 | AN0 · AN1 · AN3 | `FF` 빈칸 |
| 6 | 1011 | AN2 | 가운데 점: `7F` (i_disp_msec < 50) / `FF` (≥ 50) |

글자 코드 (active-low): `0`=C0 `1`=F9 `2`=A4 `3`=B0 `4`=99 `5`=92 `6`=82 `7`=F8 `8`=80 `9`=90, 빈칸=FF, 점만=7F
"""


def readme(folder):
    F = FOLDERS[folder]
    L = [f"# {F['title']}", "",
         "블록 다이어그램(`../../block_diagram.pdf`)의 **입력 → 출력 순서**로, 각 단계에서 **어느 블록의 어느 포트**를 파형에 넣어 볼지 안내한다. "
         "그림의 번호 · 색 = 표의 단계 번호. TB 그림 모음 PDF: " + f"[`{folder}_tb_figures.pdf`]({folder}_tb_figures.pdf)", "",
         "## 이 기능의 사양", ""] + F["spec"] + ([""] + F["fsm"] if F.get("fsm") else []) + [COMMON]
    for n, t in enumerate(F["tbs"], 3):
        L += ["", "---", "", f"## {n}. `{t['tb']}.sv` — {t['title']}", "", f"**확인하는 것**: {t['goal']}", "",
              f"![{t['tb']}](img/{t['tb']}.png)", "",
              "### 단계 (파형에 넣는 순서)", "",
              "| 단계 | 블록 (Scope 경로) | 꺼낼 포트 | 시간 | 확인할 것 |", "|---|---|---|---|---|"]
        steps, phases = with_clk(t)
        for i, s in enumerate(steps, 1):
            scopes = []
            ports = []
            for b, p in s["ports"]:
                sc = SCOPE[b]
                if sc not in scopes:
                    scopes.append(sc)
                ports.append(port_cell(b, p))
            ex = s["extra"]
            chk = s["check"] + ((f"<br>{ex}" if ex.startswith("**FSM**") else f"<br>더 보려면: {ex}") if ex else "")
            L.append(f"| **{i}** {s['name']} | {'<br>'.join('`' + x + '`' if '/' in x or x == 'dut' else x for x in scopes)} "
                     f"| {' '.join(ports)} | {s['timing']} | {chk} |")
        L += ["", "### Phase 별로 볼 곳", "", "| Phase | TB 가 하는 것 | 볼 단계 | 정상 |", "|---|---|---|---|"]
        for ph in phases:
            L.append(f"| {ph[0]} | {ph[1]} | {ph[2]} | {ph[3]} |")
        if t.get("note"):
            L += ["", t["note"]]
        if t.get("preload"):
            L += ["", "프리로드 Phase 는 콘솔 `[PRELOAD]` 시각부터 보면 된다."]
        L += ["", "### FND 결론 (마지막 단계)", ""] + fnd_table(t["fnd"])
    out = os.path.join(TB, folder, "README.md")
    open(out, "w", encoding="utf-8").write("\n".join(L) + "\n")
    print("README:", out)


def main(folders, show=False):
    for f in folders:
        pages = []
        for t in FOLDERS[f]["tbs"]:
            png, page = figure(f, t)
            pages.append(page)
            print("img:", f, t["tb"])
            if show:
                G.open_in_photos(png)
        # 폴더의 TB 그림을 PDF 하나로 (TB 1 개 = 1 쪽, 벡터)
        W = max(w for _, w, _ in pages)
        H = max(h for _, _, h in pages)
        pages = [(sv.replace(f'width="{w}" height="{h}"', f'width="{W}" height="{H}"', 1), W, H) for sv, w, h in pages]
        pdf = os.path.join(TB, f, f"{f}_tb_figures.pdf")
        G.to_pdf(pages, pdf)
        print("pdf:", pdf)
        readme(f)


if __name__ == "__main__":
    # python3 tb_guide.py [폴더 ...] [--open]  → --open 이면 만든 TB 그림을 Windows 사진 앱으로 열기
    args = [a for a in sys.argv[1:] if a != "--open"]
    main(args or list(FOLDERS), show="--open" in sys.argv)
