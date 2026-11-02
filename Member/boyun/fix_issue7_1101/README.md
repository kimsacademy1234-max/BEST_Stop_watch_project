# ISSUE 7 건 + J14 수정본 (11/01) — FINAL v2 사본에서 수정, 원본은 그대로

- 출발점 : `FINAL/source_file/merge_final` (v2, B-2 · B-3 반영) 그대로 복사
- 바꾼 파일 5 개 : `UART/01_UART_CONTROLLER.sv` · `UART/02_UART_ASCII_DECODER.sv` · `UART/sender_char_mux.v` · `WTS/stopwatch_datapath.v` · `WTS/wts_top.v`
  - 바뀐 줄만 : `fix_issue7_vs_v2.diff` (v2 와 비교, 바뀐 줄마다 `(fix 11/01 …)` 주석)
- 나머지 파일 · XDC 는 v2 와 같음 → FINAL 에 반영하려면 위 5 개만 덮어쓰면 됨

## 1. 무엇을 고쳤나 (tb_scenario.md 2 장 항목 · 그룹 TB ID)

| ID | 상황 (원래 동작) | 고친 곳 | 고친 뒤 |
|---|---|---|---|
| G3-3 | `/set abcd` 처럼 아무 4 글자나 와도 시계 설정이 켜짐 | `01_UART_CONTROLLER.sv` `/set` 조건 | 옵션이 `w_hm` 일 때만 켜짐 (`/set abcd` 는 변화 없음, ERROR 없음) |
| G7-2 | `/off` 를 한 번 잘못 보내 ERROR 가 나면 그 뒤 `/off w_h` 도 계속 ERROR | `02_UART_ASCII_DECODER.sv` 오류 처리 | 오류 때 `/off` 글자 세던 카운터 (`off`) 도 0 → 다음 `/off w_h` 정상 |
| H7-2 | `/auto off` 뒤 바로 `/auto` 를 켜면 첫 줄이 1 초보다 일찍 옴 (카운터가 남은 값부터) | `01_UART_CONTROLLER.sv` `sender_tick_generator` | 끌 때 카운터도 0 → 다시 켜면 첫 줄은 1 초 뒤 |
| H9-1 | `/get` 을 쉬지 않고 20 번 보내면 TX FIFO 가 차서 요청이 합쳐져 15 줄만 옴 | `01_UART_CONTROLLER.sv` `c_send_pend` | 요청을 1 비트 (있다 / 없다) 대신 개수 (5 비트, 31 까지) 로 기억 → 20 번이면 20 줄 |
| D7-2 | 스톱워치 랩 표시 중 `/get` → 흐르는 값이 아니라 랩 값 | `stopwatch_datapath.v` 새 출력 `o_sw_run_time` · `wts_top.v` | PC 로는 랩과 상관없이 지금 흐르는 값. FND 는 그대로 랩 값 |
| E6-1 | 시계 초 화면 (sw1 0) 에서 sw2 1 + U → 화면엔 안 보이는 분이 +1 | `wts_top.v` 시계 컨트롤 유닛 입력 | 시계 설정은 시.분 화면 (sw1 1) 일 때만 |
| L6-1 | 59.99 → 00.00 넘어가는 바로 그 클럭에 `/get` 이 걸리면 1 초 늦은 값 | `stopwatch_datapath.v` `stopwatch_tick_counter` | 자리 올림 (`o_tick`) 을 레지스터 대신 조합으로 → 같은 클럭에 윗자리도 바뀜 |
| J14-2 | 습도 100 이상이면 PC 로 `:0%24C` | `sender_char_mux.v` (보윤) | 99 보다 크면 99 (FND 와 같은 규칙) → `99%24C` (`../fix_j14_1101` 과 같은 수정) |

## 2. 확인 (Vivado 2022.2 xsim `-debug typical`, 클럭 100 MHz)

| TB | v2 (원본) | 이 수정본 |
|---|---|---|
| 그룹 TB 12 개 (`FINAL/sim_file`) | 검사 305 = PASS 297 · FAIL 8 (tb_scenario 2 장 ISSUE) | 검사 305 = **PASS 305 · FAIL 0 · ISSUE 0** (12 개 모두) |
| 보윤 통합 TB `tb_top_full` (v2 기대값) | 검사 560 · MISMATCH 0 | 검사 558 · **MISMATCH 0** |

- 통합 TB 검사가 560 → 558 인 이유 : H7 수정으로 S16 (`/auto all` 을 켜고 4 주기 기다림) 에서 첫 줄이 이제 1 주기 뒤에 나와, 그 구간에 받은 줄이 1 줄 줄어듦 (줄마다 검사 2 개). 틀린 줄은 0.
- 합계 (그룹 TB 와 겹치지 않는 통합 TB 검사 = 랜덤 192 + 송신 MUX 99) : **PASS 305 + 291 = 596 · FAIL 0**
- 실제 시간 TB (`top_tb/` 9 개) 는 한 번에 몇 시간씩 걸려 이번엔 다시 안 돌림

## 3. 구현 (같은 XDC, xc7a35tcpg236-1)

| | v2 (원본) | 이 수정본 |
|---|---|---|
| LUT | 1,489 | **1,476** (−13) |
| FF | 737 | **738** (+1) |
| WNS (setup 여유) | +0.320 ns | **+1.442 ns** |
| WHS (hold 여유) | +0.078 ns | +0.078 ns |
| 타이밍 위반 | 0 | 0 |

- 비트스트림 : `bit/merge_final_top_fix_issue7_1101.bit`
- 보고서 : `report/util.rpt` · `report/util_hier.rpt` · `report/timing.rpt`

## 4. 보드에서 확인하는 법 → `보드확인_순서.md`
