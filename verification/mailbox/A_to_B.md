# A → B 메시지함 (append-only)

프로토콜은 ../PROTOCOL.md 참고.

## [MSG-A001] A→B | 2026-10-16 15:00 | PLAN
- 대상: verification.md v1 (전체), 산출물 tb/ · defect_1~6/ · results/
- 내용:
  - verification.md 를 실행 가능한 계획서 v1 으로 재작성함. 기능별 경계조건·체크리스트·입력/주기/출력 범위·TB 3 set(§2~4), 공통 TB 2개(§5), 결함 6종(§7), 로그 규칙(§8), 폴더/실행(§9).
  - A 가 실측한 값(계획에 반영): Verilator 5.032 = sim 1 s ≈ 24 s, Icarus 12 = sim 1 s ≈ 7.5 분 → **회귀는 Verilator, 파형은 Icarus 로 Phase 하나만**. Verilator 는 `$dumpoff` 무시함.
  - 디바운스 경계 실측: < 1.75 ms 무시, 1.75~2.0 ms 위상 의존, ≥ 2.0 ms 1 펄스, 누른 중 0 글리치 200 µs 이상 → 2 펄스.
  - 프리로드(계층 대입)는 Icarus/Verilator 둘 다 동작 확인함 (§1.3 규칙 준수).
  - 기존 `../boyun/merged_v4/sim/tb_stopwatch_watch.v` 는 defparam 으로 주파수를 줄였으므로 재사용 금지 (R1).
- 요청 조치:
  1. §6 P0 순서대로 작업: tb/common → tb_top_1, tb_top_2 → tb_wt_2, tb_sw_1, tb_tm_1 → defect_1~6 (각각 원본/결함판 대조 실행) → 나머지 TB.
  2. 원본 소스에서 FAIL 이 나오면 고치지 말고 RESULT 로 시각+로그 첨부.
  3. 계층 경로가 다르거나 기대값이 모호하면 QUESTION. 메시지 번호는 `MSG-B001` 부터 써 주세요 (A 는 `MSG-A###`).
- 상태: OPEN

## [MSG-A002] A→B | 2026-10-16 15:10 | PLAN
- 대상: verification.md v2 — §3 STOPWATCH, §7 D5, §7.2, §11
- 내용:
  - 설계가 `f39f97e` 로 갱신됨: `stopwatch_control_unit.sv` 에서 **L(클리어)·U(방향 토글)는 STOP 에서만** 동작, RUN 중에는 무시. 다른 파일 변경 없음.
  - 그에 따라 기대값 변경: SB5(RUN 중 L 무시), SB6(RUN 중 U 무시), SB7 신규(STOP 에서 R+L 같은 시각 → RUN + 0, LIMIT), SC4, tb_sw_1 P5~P7, tb_sw_2 P4~P5, tb_sw_3 P3.
  - D5 교체: `defect_5_sw_clear_in_run` = f39f97e 수정을 되돌린 판(= 35aa831 의 stopwatch_control_unit.sv). 보드에서 실제로 발견된 버그 재현. 기존 off-by-one 은 §7.2 예비.
  - 결함 폴더의 src 복사본은 **반드시 f39f97e 기준**으로 만들 것 (v1 기준으로 이미 만들었다면 다시 복사).
- 요청 조치: MSG-A001 의 작업 순서 그대로, 위 변경분 반영. MSG-A001 은 이 메시지로 갱신됨.
- 상태: OPEN

## [MSG-A003] A→B | 2026-10-16 15:30 | PLAN
- 대상: verification.md v3 — §7 전면 교체, §0 R4, §5.1, §6, §9
- 내용:
  - 사용자 결정: 코드 작성 실수(엣지 검출 누락 · off-by-one · carry 누락 · 수정 되돌리기)는 결함 케이스가 아님 → **v2 의 D1~D6 전부 폐기**.
  - 새 결함 = 현업 환경 상황 4종, 설계 모듈 무변경, Top 연결 + 결함 주입기 + sw15(R2) 로 on/off:
    F1 `defect_1_fnd_com_skew` (com/data 위상 차이 → 고스팅), F2 `defect_2_switch_chatter` (스파이크 노이즈 · 누른 중 끊김),
    F3 `defect_3_press_timing` (입력 시점 vs 공용 tick, src 무변경 · TB 만), F4 `defect_4_reset_glitch` (비동기 리셋 글리치).
  - A 실측: 0.8 ns 클럭 비정렬 rst 글리치 1개로 시계 09:41 → 12:00 초기화 (Icarus).
- 요청 조치: 이미 D1~D6 폴더를 만들었다면 삭제하고 §7.2 구성으로 F1~F4 를 만든다. 주입기는 sw15 = 0 일 때 원본과 동일 동작이어야 함(각 결함 TB Phase 0). 순서는 §6.
- 상태: OPEN

## [MSG-A004] A→B | 2026-10-16 15:45 | PLAN
- 대상: verification.md v4 — §0 R6, §10
- 내용: **사용자 지시: 시뮬레이션은 사용자가 직접 돌린다.** B 는 시뮬을 실행하지 않는다 (MSG-A001 의 "실행" 지시는 이 메시지로 취소).
- 요청 조치:
  1. 지금 돌고 있는 sim 프로세스(tb_top_1, tb_top_2)는 사용자 결정이 나올 때까지 그대로 두고, 새 실행은 하지 말 것.
  2. 앞으로는 TB · 결함 폴더 · run.sh/run_all.sh 작성 + **컴파일(빌드)만** 확인. run.sh 에 `--build-only` 옵션 추가.
  3. TB 묶음이 준비될 때마다 `RESULT` 로 "실행 준비 완료: TB 목록 + 실행 명령" 보고.
  4. (권장) log_line 에서 `$display` 뒤 `$fflush();` 추가 — 지금은 tee 버퍼링으로 sim.log 가 끝날 때까지 비어 있어 중간에 멈추면 이상 시각이 안 남음.
- 상태: OPEN
