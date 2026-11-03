# F3 — 버튼 입력 시점 오차 (소스 변경 없음 · TB 자극만)

## 상황

- **현업 상황**: 사람이 누르는 순간은 내부 10 ms tick 과 위상이 무관하다. `U_TICK_GEN_100HZ` 가 Top 에 하나 (공용, 항상 흐름) → 스톱워치 시작이 tick 사이 어디든 된다. 2 ms 근처의 짧은 "톡" 입력은 4 kHz 샘플 위상에 따라 씹힌다.
- **주입**: 없음. 원본 `../../source_file` 그대로. TB 가 누르는 시점을 tick · 샘플 기준으로 0 ~ 9 ms · 30 ~ 220 us 옮겨 가며 잰다.
- **보드 증상**: 재현이 아니라 시뮬 근거로 설명 — 같은 1.005 초를 재도 위상에 따라 1.00 / 1.01 초, 타이머는 최대 10 ms 일찍 끝남, 1.8 ~ 1.9 ms 탭은 될 때도 있고 안 될 때도 있음.

## Vivado 실행

Design Sources = `../../source_file/*.v, *.sv` / Simulation Sources = `tb_f3_press_timing.sv` + `fnd_monitor.sv`. 시뮬 시간이 길다 (약 22 초) → `RUN_PHASE` 로 Phase 하나씩 권장. 공통 사용법은 `../top/README.md` §0

## 파형 단계

TB 최상위 `clk` · `rst` 는 항상 같이 넣는다 (모든 "다음 클럭" 의 기준, `../top/README.md` §0 의 6).

| 단계 | 블록 (Scope 경로) | 꺼낼 포트 | 시간 | 확인할 것 |
|---|---|---|---|---|
| **1** 버튼 | TB 최상위 | `btn_R` (P1) · `btn_L` (P2) · `btn_U` (P3) | tick 기준 0 ~ 9 ms 옮겨 누름 | 누른 시점 |
| **2** 4 kHz 샘플 | `dut/U_CLK_GEN_4KHZ` | `o_clk_4khz` | 250 us | tick 엣지 = 샘플 엣지 (1,000,000 = 40 × 25,000) |
| **3** 디바운서 | `dut/U_BD_R` / `U_BD_L` / `U_BD_U` | `o_btn` | 누른 뒤 1.75 ~ 2.0 ms | 짧은 탭은 위상에 따라 없음 |
| **4** 컨트롤 · FSM | `dut/U_STOPWATCH_CONTROL_UNIT` / `dut/U_TIMER_CONTROL_UNIT` | `o_sw_run_stop` / `o_tm_run`, `o_tm_alarm` + Objects 의 `c_state` · `n_state` | 버튼 펄스 다음 클럭 | 시작 시점 = `c_state` 가 RUN 이 되는 클럭 (P2 는 RUN → ALARM 까지) |
| **5** 10 ms tick | `dut/U_TICK_GEN_100HZ` | `o_tick_10ms` | 10 ms | 시작과 첫 tick 사이 간격 = 오차 |
| **6** 값 | `dut/U_STOPWATCH_DATAPATH` | `o_sw_sec`, `o_sw_msec` | tick 다음 클럭 | 같은 구간인데 count 가 100 / 101 |

## Phase 와 판정

| Phase | TB 가 하는 것 | 판정 |
|---|---|---|
| P1 | 스톱워치: 시작 위상 0 ~ 9 ms, 동작 구간 1.005 초 | 위상별 count 표 `[LIMIT] [F3.P1...]` — 공용 tick 은 위상에 따라 100 / 101 (이상적 스톱워치는 항상 100) |
| P2 | 타이머: 00:01.00 프리로드, 시작 위상 0 ~ 9 ms | `o_tm_run` ↑ → `o_tm_alarm` ↑ 간격 표 `[LIMIT] [F3.P2...]` ∈ (0.99 초, 1.00 초 + 1 클럭] |
| P3 | 짧은 탭 1.5 / 1.8 / 1.9 / 2.0 ms × 샘플 위상 30 / 90 / 160 / 220 us | 인식 / 무시 표 `[LIMIT] [F3.P3...]` — 1.75 ms 이하 무시, 2.0 ms 항상 인식, 그 사이는 위상 따라 |

`[LIMIT]` = 사양상 한계를 기록한 것 (FAIL 아님). `[SUMMARY] ... => PASS` 이고 표 세 개가 나오면 성공.

## 해결

시작 때 tick 카운터를 0 으로 맞추면 (기능별 tick) 오차가 사라지지만 자원 · 공용성과 맞바꿈. 구간이 10 ms 의 배수면 오차 0.
