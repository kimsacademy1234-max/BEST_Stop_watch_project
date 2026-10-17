# 타이머 시뮬레이션 검증 결과 (정보윤)

`verification_v2/tb/02_timer` 의 TB 3개를 Vivado GUI 로 돌린 결과와 발표용 파형 캡처입니다.

## 결과

| TB | 시뮬 시간 | 검사 수 | 결과 |
|---|---|---|---|
| `tb_tm_1_add_cap` (더하기 · 59:59 상한) | 455 ms | 21 | PASS (fail 0) |
| `tb_tm_2_countdown_alarm` (카운트다운 · 알람) | 11,595 ms | 41 | PASS (fail 0) |
| `tb_tm_3_cancel_background` (취소 · 백그라운드 · 우선순위) | 555 ms | 11 | PASS (fail 0) |

- 조건: Vivado 2022.2 behavioral 시뮬레이션, 소스 · TB 는 `verification_v2` (커밋 d413554 기준), 실제 시간(tick 올리지 않음).
- 근거: Vivado 콘솔 `[SUMMARY] TM1/TM2/TM3 ... => PASS` 줄 (2026-10-17 실행 로그).

## 보고 자료

- `정보윤_타이머_시뮬레이션검증_v1.0.pdf` (바로 보기) · `.pptx` (33장): 타이머 사양 · 신호 경로 · 검증 방법 · TB 별 시나리오와 콘솔 · 캡처마다 번호 설명 · 정리

## 폴더

- `captures/` : 파형 캡처. `_원본` = Vivado 화면 그대로, `_상자` = 빨간 상자 + 번호를 친 판 (발표용).
- `script/timer_wave_v2.tcl` : 파형 창에 11개 그룹(TB 안내서 단계 순서)을 자동으로 넣는 스크립트.
  시뮬레이션 창 Tcl Console 에서 `source <경로>/timer_wave_v2.tcl` → wcfg 저장 → Relaunch Simulation → `run all`.
  TB2 처럼 긴 것은 먼저 `set noclk 1` (clk 를 빼서 파형 파일을 작게).

## 캡처 목록 (상자 번호 설명)

### TM1 더하기 · 상한
| 파일 | 내용 |
|---|---|
| TM1_P1_리셋화면 | 리셋 직후 `w_disp_mode` 1 (타이머 화면), LED 0020, 값 00:00.00 |
| TM1_P2_0에서L | 00:00 에서 L → SET 그대로, `o_tm_run` 0 (`i_tm_zero` = 1 이면 시작 안 함) |
| TM1_P3a_U6번 | U 6번 → 초 10 … 50 → 6번째에 01:00 (분으로 올림) |
| TM1_P3b_올림확대 | `o_tm_add` 펄스 다음 클럭에 00:50 → 01:00 |
| TM1_P3c1_U경로ms | `btn_U` 누름 → 약 2 ms 뒤 `U_BD_U.o_btn` → `w_tm_btn_U` → 초 +10 |
| TM1_P3c2_U경로ns | `w_tm_btn_U` 와 같은 클럭에 `o_tm_add`, 다음 클럭에 초 0 → 10 |
| TM1_P4_RDU | R(+1분, amount 1) · D(+10분, amount 2) · U(+10초, amount 0) → 01:00 → 11:00 → 11:10 |
| TM1_P5_5959상한 | 59:50 + U → 59:59 (60:00 아님) |
| TM1_P6_5959에서더하기 | 59:59 프리로드 후 U → 59:59 그대로 |
| TM1_P7_D로5959 | 52:10 + D(+10분) → 59:59 |
| TM1_FND_0100스캔 | 한 바퀴 8칸 × 250 µs: 숫자 4칸 "0100" + 빈칸 4칸(1011 칸 7f = 가운데 점) |
| TM1_전체_0to455ms_원본 | TM1 전체 흐름 (상자 없음) |

### TM2 카운트다운 · 알람
| 파일 | 내용 |
|---|---|
| TM2_P1 | `o_tm_run`↑ → `o_tm_alarm`↑ 간격 9.998000010 s (TB 합격 범위 (9,990 ms, 10,000 ms + 1클럭]) |
| TM2_P2a_전체 · P2b_49to50 · P2c_99to0 | 알람 LED 500 ms 점멸: 시계 1/100초 ≥ 50 이면 ffff (10,500.001 ms 켜짐, 11,000.001 ms 꺼짐) |
| TM2_P3_D끄기 | 알람 중 D → SET, `o_tm_add` 안 나옴, 00:00.00, LED ffff → 0020 |
| TM2_P4_빌림 | 01:00.00 → 다음 tick 00:59.99, 10:00.00 → 09:59.99 (분에서 빌림) |

### TM3 취소 · 백그라운드 · 우선순위
| 파일 | 내용 |
|---|---|
| TM3_P1a_전체 · P1b_R확대 | RUN 중 U · R · D → `o_tm_add` 안 나옴, 값은 줄기만 |
| TM3_P2a_전체 · P2b_L확대 | RUN 중 L → 같은 클럭 `o_tm_clear`, 다음 클럭 00:00.00 · SET |
| TM3_P3_시계화면알람 | `timer_sw4` 0 (시계 화면)에서도 타이머가 돌고 460 ms 에 ALARM. LED 0000 = 점멸의 꺼진 쪽(시계 1/100초 33 < 50) |
| TM3_P4_다른화면버튼 | 시계 · 스톱워치 화면 버튼 → `w_tm_btn_*` 전부 0 → 알람 유지 |
| TM3_P5_타이머화면R끄기 | `timer_sw4` 1 · `mode_sw0` 1 → 타이머 화면 우선, R → ALARM → SET, 1분 안 더해짐, LED 0020 |

## 누가 무엇을
- TB · 안내서: 정안성 (`verification_v2`, Claude 공동 작성 커밋)
- 시뮬레이션 실행 · 파형 캡처: 정보윤 (Vivado GUI)
- 캡처의 빨간 상자 · 번호 · 위 설명 문장, 파형 배치 스크립트: Claude Code 로 작성, 정보윤 확인

> **10/17 밤 추가**: 위 "① 10초 → 9,998 ms" 는 팀 결정 ④(100 Hz tick 을 스톱워치 · 타이머 전용 `tick_gen_100hz_run` 으로 분리)로 해결 — 같은 TB 로 10,000 ms + 20 ns. 자세한 것은 `../timer_tb_verilog/README.md` · `../../verification_v2/README.md`.
