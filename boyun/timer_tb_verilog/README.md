# 타이머 TB — Verilog 판 (정보윤 요청 · 클로드코드 작성, 2026-10-17)

팀 v2 타이머 TB 3개(`verification_v2\tb\02_timer\*.sv`, 정안성 님 작성, SystemVerilog)를
**같은 시나리오 · 같은 판정**으로 수업 Verilog 문법만 써서 옮긴 것. 설계(DUT)는 v2 소스를 고치지 않고 그대로 쓴다.

> 이 폴더의 TB 는 클로드코드가 옮겨 쓴 것이다. 팀에 공유할 때는 그렇게 밝힌다.

## 파일

| 파일 | 원본 | 원본 검사 수 |
|---|---|---|
| `tb_tm_1_add_cap.v` | `tb_tm_1_add_cap.sv` (더하기 · 상한 59:59) | 21 |
| `tb_tm_2_countdown_alarm.v` | `tb_tm_2_countdown_alarm.sv` (실제 10초 · 알람 LED · 빌림) | 41 |
| `tb_tm_3_cancel_background.v` | `tb_tm_3_cancel_background.sv` (RUN 중 버튼 · 취소 · 백그라운드 알람) | 11 |
| `tb_timer_simple.v` | (새로 만든 발표용 간단판) for 루프 더하기 30번 · 0 에서 L · 10초 카운트다운 · 알람 끄기 · 취소 | 35 |
| `tb_tick_restart.v` | (10/17 밤 추가) 타이머 리셋 뒤 · 알람 뒤 · 취소 뒤 시작 → 첫 tick 까지 정확히 10,000,000 ns 인지 | 3 |
| `tb_sw_stop_edge.v` | (10/17 밤 추가) 모듈 단위(tick_gen_100hz_run F_COUNT=10 + stopwatch_datapath): tick 이 나오는 클럭에 STOP 해도 그 칸까지 세는지 | 3 |
| `run_xsim.bat` | — | GUI 없이 xsim 으로 돌리는 스크립트 |

## 문법 (수업 HW2 `tb_adder_fnd.v` 와 같은 틀)

- `integer err;` → `if ({…} !== {기대값}) begin err = err + 1; $display("FAIL …"); end` → 끝에 `TOTAL MISMATCH = N` 출력 후 `$finish`
- 버튼: `@(negedge clk); btn_U = 1; #5_000_000; btn_U = 0; #5_000_000;` (5 ms 누름 + 5 ms 뗌, 원본 `press()` 와 같음)
- 같은 버튼 여러 번: `repeat (5) begin … end`
- **안 쓴 것**: task · function · string · bit · longint · `$sformatf` · `void` · `return` (원본의 SV 전용 문법)
- **수업에서 안 나온 것 1개**: `dut.w_tm_min` 처럼 "인스턴스 이름.안쪽 선 이름" 으로 Top 안 신호를 읽는 **계층 이름**. 타이머 값이 Top 핀으로 안 나와서 필요하다.

## 원본과 다른 점

| 곳 | 원본 (SV) | 이 판 (Verilog) | 이유 |
|---|---|---|---|
| TM1 P6 | 59:59 를 레지스터에 직접 씀(프리로드) | D×5 · R×9 · U×6 버튼으로 59:59 를 만듦 | 레지스터에 직접 쓰기(계층 이름 쓰기)를 안 쓰려고 |
| TM2 P4 | RUN 중 01:00.00 · 10:00.00 을 써 넣고 1 tick 뒤 확인 | R(01:00) · D(10:00) 로 만든 뒤 L 로 시작 → 첫 tick 뒤 확인 | 같음 |
| TM3 P3 | 01:00 으로 시작 + 00:00.30 프리로드 → 바로 알람 | U(00:10) 로 시작해 실제 10초 기다림 | 같음. 시뮬이 약 10초 길어짐 |
| FND 확인 | `fnd_monitor.sv` 가 매 칸 참조 모델과 계속 비교 + 화면 글자열 | 스캔 칸 0~3 의 세그먼트를 자리별로 저장해 검사 시점에 기대 세그먼트(8'hC0 등)와 비교 | 문자열 · 참조 모델 없이 |
| 디바운서 펄스 | 펄스 폭을 시간으로 잼 | `w_btn_*` 가 2클럭 연속 1 이면 err | 같은 뜻 (1클럭 펄스인지) |

## 돌리는 법

### A. 명령줄 (GUI 없이)
```
cd <저장소>\boyun\timer_tb_verilog
run_xsim.bat tb_tm_1_add_cap
```
설계는 이 저장소의 `verification_v2\source_file\` 을 그대로 읽는다. Vivado 가 `C:\Xilinx\Vivado\2022.2` 가 아니면 `run_xsim.bat` 의 `settings64.bat` 경로만 고친다.
결과: `run_tb_tm_1_add_cap\xsim.log` 마지막 줄 `TM1 checks = 21, TOTAL MISMATCH = 0` 이면 통과.
(선택) `run_xsim.bat TB이름 설계폴더 이름표` → 다른 설계 폴더(예: bug 를 넣은 사본)로 돌림.

### B. Vivado GUI
1. Design Sources: `verification_v2\source_file\` 의 `.v` 와 `.sv` 전부 (설계 `.sv` 3개 = 컨트롤 유닛, enum 때문에 .sv)
2. Simulation Sources: 이 폴더의 `.v` TB 하나 (`fnd_monitor.sv` 는 필요 없음) → Set as Top
3. Run Simulation → Run All → Tcl Console 마지막 줄 `TOTAL MISMATCH = 0`
   - 파형이 필요하면 원본 TB 와 같은 신호(`dut.U_TIMER_…`)를 Scope 에서 넣는다. TM2 · TM3 는 10초 이상이라 clk 는 빼고 본다.

## 결과 (Vivado 2022.2 xsim, v2 소스 = 팀 저장소 `source_file` 마지막 변경 `bf77587` 그대로, 로컬 수정 없음)

### 10/17 밤 — 팀 결정 ④ (100 Hz tick 분리) 반영한 소스로 (`verification_v2/source_file`, `tick_gen_100hz_run.v` + Top 수정)

| TB | 검사 | MISMATCH | 10초 타이머 | 같은 소스로 돌린 팀 SV TB |
|---|---|---|---|---|
| tb_tm_1_add_cap.v | 21 | **0** | — | 21 / PASS |
| tb_tm_2_countdown_alarm.v | 41 | **0** | **10,000 ms + 20 ns** (RUN ↑ → ALARM ↑, 파이프라인 2클럭) | 41 / PASS |
| tb_tm_3_cancel_background.v | 11 | **0** | — | 11 / PASS |
| tb_timer_simple.v (발표용 간단판) | 35 | **0** | 10,000 ms + 20 ns | — |

- ④ 로 바뀌면서 TB 도 두 곳 고침: ① 10초 판정 범위 (9,990 ~ 10,000 ms + 1클럭 → **10,000 ms − 1클럭 ~ + 3클럭**, SV `tb_tm_2` 도 같이) ② `tb_tm_2.v` P4 빌림 확인은 시계 tick(`dut.w_tick_10ms`) 대신 **타이머 전용 tick `dut.w_tm_tick_10ms`** 첫 펄스를 기다림. 고치기 전 옛 TB 로 ④ 소스를 돌리면 그 두 곳만 FAIL (10,000,000,020 ns, P4 값 그대로) — 바뀐 동작을 TB 가 잡은 것.
- 같은 소스로 팀 SV TB 11개(01_stopwatch 3 · 02_timer 3 · 03_watch 3 · top 2)도 전부 PASS (검사 339개).

### 10/17 저녁 — 그 전 소스 (100 Hz tick 공유, `bf77587`)

| TB | 검사 | MISMATCH | 시뮬 시간 | 원본 SV 결과 (10/16) |
|---|---|---|---|---|
| tb_tm_1_add_cap.v | 21 | **0** | 645 ms | 21 / PASS (455 ms) |
| tb_tm_2_countdown_alarm.v | 41 | **0** | 11,600 ms · 10초 타이머 = **9,998 ms** | 41 / PASS (11,595 ms · 9,998 ms) |
| tb_tm_3_cancel_background.v | 11 | **0** | 10,235 ms | 11 / PASS (555 ms) |
| tb_timer_simple.v (발표용 간단판) | 35 | **0** | 약 10.4 s · 10초 타이머 = 9,998 ms | — |

- 원본 SV 와 검사 수 · 결과가 같았다. 10초 타이머가 9,998 ms 인 것도 같았다 (tick 공유 때문 → ④ 로 해결).
- 시뮬 시간이 다른 것은 프리로드 대신 버튼 · 실제 시간을 써서다 (위 "원본과 다른 점").

### TB 가 정말 잡는지 (변이 테스트: 설계 복사본에 bug 를 일부러 넣고 돌림, 원본 설계는 그대로)

| 복사본에 넣은 bug | 돌린 TB | 결과 |
|---|---|---|
| `timer_datapath.v` 93줄 `if (w_over)` → `if (1'b0)` (59:59 상한 없앰) | tb_tm_1 | **MISMATCH 7** — `59:50 + U exp 59:59.00 got 60:0.0` 등 |
| `timer_control_unit.sv` RUN 에서 U 를 받아 +10초 | tb_tm_3 | **MISMATCH 1** — `U/R/D during RUN exp (5989,5999) got 6996` |

bug 넣은 설계는 저장소에 안 올림(설계 전체 복사본이라). 직접 해 보려면 `verification_v2\source_file` 을 다른 폴더에 복사하고 한 곳만 바꾼 뒤
`run_xsim.bat TB이름 <복사한 폴더> 이름표` 로 돌린다.
- ① `timer_datapath.v` 93줄 `if (w_over) begin` → `if (1'b0) begin`
- ② `timer_control_unit.sv` RUN 상태의 `if (i_tm_btn_L == 1'b1) … end` 와 `else if (i_tm_zero == 1'b1)` 사이에
  `end else if (i_tm_btn_U == 1'b1) begin o_tm_add = 1'b1; o_tm_amount = 2'd0;` 를 끼워 넣음

→ 틀린 설계에서는 FAIL 이 나오므로, 원본의 MISMATCH 0 은 "검사가 엉성해서 0" 이 아니다.

### 10/17 밤 추가 수정 2개 확인 (같은 TB 를 고치기 전 / 후 소스로)

| TB | 고치기 전 (79dcdbb) | 고친 뒤 |
|---|---|---|
| tb_tick_restart.v | 알람 뒤 재시작 첫 tick **9,999,980 ns** → MISMATCH 1 | 리셋 뒤 · 알람 뒤 · 취소 뒤 모두 **10,000,000 ns**, MISMATCH 0 |
| tb_sw_stop_edge.v | tick 클럭에 STOP → msec **4** (10 ms 잃음) → MISMATCH 2 | msec **5**, MISMATCH 0 |

- 고친 소스로 팀 SV TB 11개 PASS (검사 339), Verilog TB 4개 + 위 2개 PASS. 10초 타이머 10,000 ms + 20 ns.
- 구현 후 LUT 356 · FF 228 · WNS +3.626 ns (④ 1차 355 · 228 · +3.837, OR 게이트로 LUT +1).
