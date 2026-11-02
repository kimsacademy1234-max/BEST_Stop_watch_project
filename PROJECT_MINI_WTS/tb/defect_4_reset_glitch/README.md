# F4 — 리셋 라인 글리치 (EMI)

## 상황 · 주입

- **현업 상황**: btnC (`rst`) 는 **비동기 리셋**이고 필터 · 동기화가 없다. 모터 · 정전기 · 긴 배선의 수 ns 글리치에도 전체 초기화.
- **주입**: `src/fault_rst_glitch.v` (`U_FAULT_RST_GLITCH`) — `fault_sw15` 상승 엣지 (2FF 동기화) 에서 내부 리셋에 1 클럭 (10 ns) 펄스를 OR → `w_rst_inj`. Top 의 `i_rst` 연결 13 곳을 `w_rst_inj` 로 (하위 모듈 무변경). LED 는 건드리지 않음. 바뀐 줄은 `[FAULT-INJ F4]`, 전체는 `defect.patch`
- **보드 증상 (fault_sw15 0 → 1)**: 맞춰 둔 시계 · 스톱워치 잰 시간 · 진행 중인 타이머가 한 번에 사라짐 (타이머 알람은 영원히 안 울림). 화면은 평범한 12:00 이라 원인을 알기 어렵다.

## Vivado 실행

| 볼 것 | Design Sources | 추가 설정 |
|---|---|---|
| 결함 src (주입기 있음) | 이 폴더 `src/*.v, *.sv` | 없음 |
| 원본 (P0 · P1 만) | `../../source_file/*.v, *.sv` | Simulation Settings → `xsim.compile.xvlog.more_options = -d NO_SW_FAULT` |

Simulation Sources = `tb_f4_reset_glitch.sv` + `fnd_monitor.sv`. 공통 사용법은 `../top/README.md` §0

## 파형 단계

TB 최상위 `clk` · `rst` 는 항상 같이 넣는다 (모든 "다음 클럭" 의 기준, `../top/README.md` §0 의 6).

| 단계 | 블록 (Scope 경로) | 꺼낼 포트 | 시간 | 확인할 것 |
|---|---|---|---|---|
| **1** 리셋 핀 · 결함 스위치 | TB 최상위 | `rst`, `fault_sw15` | P1: 0.5 / 1 / 5 / 10 ns 글리치 | 글리치 순간 |
| **2** 주입기 출력 | `dut/U_FAULT_RST_GLITCH` | `o_rst` (= `w_rst_inj`) | fault_sw15 ↑ 뒤 2 ~ 3 클럭에 10 ns | 내부 리셋 펄스 (결함 src 만) |
| **3** 시계 | `dut/U_WATCH_DATAPATH` | `o_wt_hour`, `o_wt_min` | 리셋 순간 | 09:41 → **12:00** |
| **4** 스톱워치 | `dut/U_STOPWATCH_CONTROL_UNIT`, `dut/U_STOPWATCH_DATAPATH` | `c_state`, `o_sw_run_stop`, `o_sw_msec` | 리셋 순간 | `c_state` RUN → STOP, 값 0 |
| **5** 타이머 · 시계 FSM | `dut/U_TIMER_CONTROL_UNIT`, `dut/U_TIMER_DATAPATH`, `dut/U_WATCH_CONTROL_UNIT` | `c_state`, `o_tm_run`, `o_tm_sec` | 리셋 순간 | 타이머 `c_state` RUN → SET, 00:00 (알람 안 옴). 시계 `c_state` 도 NORMAL 로 |
| **6** LED | TB 최상위 | `led` | 리셋 순간 | 리셋을 알리는 표시 없음 |

## Phase 와 판정

| Phase | TB 가 하는 것 | 정상 / 결함 판정 |
|---|---|---|
| P0 | fault_sw15 = 0, 기능 대표 확인 | PASS |
| P1 | 시계 09:41 · 스톱워치 동작 · 타이머 00:50 동작 중 `rst` 핀에 클럭과 안 맞는 글리치 0.5 / 1 / 5 / 10 ns | 매번 전체 초기화 → `[DEFECT] [F4.P1...] unexpected reset glitch width=...` |
| P2 | RTL 주입기: fault_sw15 0 → 1 (1 로 유지) | `o_rst` 펄스 1 개 → 같은 소실 `[DEFECT] [F4.P2.F4.INJ]`, 1 로 유지해도 다시 안 걸림 |

결함 src 에서 `[SUMMARY] ... => DETECTED` 가 나오면 성공.

## 해결

리셋 동기화기 (비동기 assert · 동기 release) + 최소 폭 필터 (예: 수 ms 디바운스).

## 보드 비트스트림

`build/` 에서 `vivado -mode batch -source build.tcl`
