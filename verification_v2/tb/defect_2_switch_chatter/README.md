# F2 — 스위치 채터링 / 노이즈

## 상황 · 주입

- **현업 상황**: (a) 누르지 않았는데 EMI 스파이크, (b) 낡거나 살짝 누른 스위치가 누른 중에 잠깐 끊김. 디바운서는 "8 샘플 연속 1 → 눌림" 이지만 **떼는 쪽은 0 샘플 1 개로 바로 해제** → (a) 는 견디고 (b) 에 약하다.
- **주입**: `src/fault_chatter.v` (`U_FAULT_CHATTER`) 를 버튼 핀 4 개와 디바운서 `i_btn` 사이에 끼움 (`w_btn_X_inj`). fault_sw15 = 1 이면 안 누른 버튼에 스파이크 (1 us · 50 us · 500 us · 1.5 ms, 7 ms 간격), 누른 버튼에 20 ms 마다 300 us 끊김. 바뀐 줄은 `[FAULT-INJ F2]`, 전체는 `defect.patch`
- **보드 증상 (fault_sw15 = 1)**: 시계 설정에서 U 를 꾹 누르면 분이 저절로 연타 (약 20 ms 마다 +1), 타이머 U 한 번에 +10 초가 여러 번. 안 누를 때는 아무 일 없음

## Vivado 실행

| 볼 것 | Design Sources | 추가 설정 |
|---|---|---|
| 결함 src (주입기 있음) | 이 폴더 `src/*.v, *.sv` | 없음 |
| 원본 (P0~P4 만) | `../../source_file/*.v, *.sv` | Simulation Settings → `xsim.compile.xvlog.more_options = -d NO_SW_FAULT` |

Simulation Sources = `tb_f2_chatter.sv` + `fnd_monitor.sv`. 공통 사용법은 `../top/README.md` §0

## 파형 단계

| 단계 | 블록 (Scope 경로) | 꺼낼 포트 | 시간 | 확인할 것 |
|---|---|---|---|---|
| **1** 버튼 · 결함 스위치 | TB 최상위 | `btn_U`, `fault_sw15` | 누름 100 ms | TB 가 누르는 모양 |
| **2** 주입기 출력 | `dut/U_FAULT_CHATTER` | `o_btn[3:0]` ({D,U,L,R}) | 20 ms 마다 300 us 0 | 끊김 · 스파이크가 들어간 버튼 (결함 src 만) |
| **3** 4 kHz 샘플 | `dut/U_CLK_GEN_4KHZ` | `o_clk_4khz` | 250 us 마다 10 ns | 끊김 300 us 안에 샘플이 1 개 이상 들어감 |
| **4** 디바운서 | `dut/U_BD_U` | `o_btn` | 끊김이 끝나고 1.75 ~ 2.0 ms 뒤 | 한 번 눌렀는데 펄스가 또 나옴 = 결함 |
| **5** 시계 / 타이머 값 | `dut/U_WATCH_DATAPATH`, `dut/U_TIMER_DATAPATH` | `o_wt_min`, `o_tm_sec` | o_btn 다음 클럭 | 펄스 수만큼 +1 / +10 초 |

## Phase 와 판정

| Phase | TB 가 하는 것 | 정상 / 결함 판정 |
|---|---|---|
| P0 | fault_sw15 = 0, 기능 대표 확인 | PASS |
| P1 | 안 누른 `btn_U` 핀에 스파이크 열 200 ms | `U_BD_U.o_btn` 0 개 → PASS (견고) |
| P2 | 바운스 패턴 | 1 개 → PASS |
| P3 | 100 ms 누름 + 300 us 끊김 × 4 | 펄스 5 개 → `[DEFECT] [F2.P3...] extra pulse #1 at ...`, 시계 분 +5 / 타이머 +50 초 |
| P4 | 끊김 폭 50 · 100 · 200 · 250 · 300 us × 샘플 위상 4 개 | 두 번 입력 되는 경계 표 (`[INFO]`): 250 us 이상이면 위상과 무관하게 항상 2 번 |
| P5 | RTL 주입기: fault_sw15 = 1 로 안 누름 200 ms → U 100 ms → fault_sw15 = 0 | 안 누름 0 개, 누름 연타 `[DEFECT] [F2.P5...]`, 끄면 1 개 |

결함 src 에서 `[SUMMARY] ... => DETECTED` 가 나오면 성공.

## 해결

뗄 때도 "8 샘플 연속 0" 을 요구 (히스테리시스) 하면 해결.

## 보드 비트스트림

`build/` 에서 `vivado -mode batch -source build.tcl`
