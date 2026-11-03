# F1 — FND 자리선택(com) 위상 차이 → 고스팅

## 상황 · 주입

- **현업 상황**: 다이나믹 구동 FND 에서 애노드 트랜지스터 turn-off 지연 · 배선 길이 차이로 `fnd_com` 이 `fnd_font` 보다 늦게 바뀐다. 이 설계는 자리 사이 블랭킹이 없어 이전 자리에 다음 숫자가 잠깐 켜진다 (잔상).
- **주입**: `src/fault_com_skew.v` (`U_FAULT_COM_SKEW`, N = 12,500 클럭 = 125 us 지연) 를 `U_FND_CONTROLLER.o_fnd_com` 과 핀 `fnd_com` 사이에 끼움. 보드 스위치 `fault_sw15` (sw15, R2). 설계 모듈 무변경 — 바뀐 줄은 `[FAULT-INJ F1]` 표시, 전체는 `defect.patch` (`../../source_file` 대비)
- **보드 증상 (fault_sw15 = 1)**: 각 자리에 옆 자리 숫자가 겹쳐 보임. "12.34" → AN0('4') 에 '3', AN3('1') 에 '4' 가 희미하게. fault_sw15 = 0 이면 원본과 같음

## Vivado 실행

| 볼 것 | Design Sources | 추가 설정 |
|---|---|---|
| 결함 src (주입기 있음) | 이 폴더 `src/*.v, *.sv` | 없음 |
| 원본 (P0 · P1 만) | `../../source_file/*.v, *.sv` | Simulation Settings → `xsim.compile.xvlog.more_options = -d NO_SW_FAULT` |

Simulation Sources = `tb_f1_com_skew.sv` + `fnd_monitor.sv`. 공통 사용법 · FND 읽는 법은 `../top/README.md` §0 · §2

## 파형 단계

TB 최상위 `clk` · `rst` 는 항상 같이 넣는다 (모든 "다음 클럭" 의 기준, `../top/README.md` §0 의 6).

| 단계 | 블록 (Scope 경로) | 꺼낼 포트 | 시간 | 확인할 것 |
|---|---|---|---|---|
| **1** 결함 스위치 | TB 최상위 | `fault_sw15` | P2 에서 0 → 1 → 0 (20 ms 씩) | 1 동안만 지연 |
| **2** 스캔 카운터 | `dut/U_FND_CONTROLLER/U_COUNTER8` | `o_scan_sel` | 250 us 마다 +1 | 자리가 바뀌어야 할 순간 |
| **3** 주입기 앞 com | `dut/U_FND_CONTROLLER` | `o_fnd_com` | o_scan_sel 과 같은 순간 | 정상 com (= 주입기 `i_fnd_com`) |
| **4** 글자 | `dut/U_FND_CONTROLLER` | `o_fnd_font` | o_scan_sel 과 같은 순간 | 바로 다음 자리 글자로 바뀜 |
| **5** 주입기 뒤 com (핀) | `dut/U_FAULT_COM_SKEW` | `o_fnd_com` (= Top `fnd_com`) | fault_sw15 = 1: 3 단계보다 **125 us 늦게** | 늦은 구간에 이전 자리 + 다음 글자 = 고스트 |

## Phase 와 판정

| Phase | TB 가 하는 것 | 정상 / 결함 판정 |
|---|---|---|
| P0 | fault_sw15 = 0, 기능 대표 확인 | PASS (주입기 통과 = 원본과 같음) |
| P1 | TB 안 지연 모델 `com_skew_tbmodel` N = 0 / 500 / 3,000 / 12,500 을 모니터 4 개로 동시에 (화면 "12.34", 20 ms) | N = 0 PASS, N > 0 은 `[DEFECT] [F1.P1...] first ghost at ...` + 자리별 고스트 시간 표 (원본 src 에서도 실행) |
| P2 | RTL 주입기: fault_sw15 0 → 1 → 0 | 0 구간 불일치 0, 1 구간 `[DEFECT] [F1.P2.FND] FND output != reference for 125.000 us ...`, 다시 0 이면 회복 |

`[DEFECT]` = 결함을 잡았다는 뜻 (기대한 결과). 결함 src 에서 `[SUMMARY] ... => DETECTED` 가 나오면 성공.

## 해결

자리 전환 때 슬롯 일부를 블랭킹 (com 전부 off) 하면 해결. 지연 N 에 비례해 고스트 duty 가 커짐 (N = 500 → 2 %, 3,000 → 12 %, 12,500 → 50 %).

## 보드 비트스트림

`build/` 에서 `vivado -mode batch -source build.tcl` (src = 이 폴더 `src/`)
