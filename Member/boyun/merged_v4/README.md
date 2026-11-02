# merged_v4 — merged_v3 + 상태 머신 enum 변환 (2026-10-16)

## 10/16 오후 변경: 스톱워치 RUN 중 L · U 무시
- `stopwatch_control_unit.sv` 두 곳: `clear = btn_clear` 를 STOP 상태에서만, `mode_reg` 토글(`btn_mode`)을 STOP 상태에서만. 나머지(enum · 상태 · 이름)는 그대로.
- 이유: 달리는 중 L 을 실수로 누르면 잰 시간이 지워지고(계속 달림), U 를 누르면 방향이 바뀌었다. 9일차 판서 FSM 도 RUN 에서는 R 만 받는다.
- 남은 차이 1개: STOP 에서 R 과 L 이 **같은 클럭**에 오면 RUN 이 되면서 0 으로 지워진다(판서 FSM 은 R 우선, 지우지 않음). 사람 손으로는 거의 안 생김.
- 검증 (xsim 2022.2, 이 폴더 src 그대로): 스톱워치 CU 단위 TB MISMATCH 0 (판서 FSM 과 다른 점 4 → 1), 시계 CU · 타이머 단위 0, Top 지시형 21 시나리오 0, 실제 시간 Top 0, SV 랜덤 2 시드(각 약 200만 클럭) 0, 이 폴더 `sim/tb_stopwatch_watch.v` 0.
- 비트스트림: `bit/stopwatch_watch_merged_v4.bit` (이 src 로 새로 빌드. 예전 v3 bit 는 지움 — `boyun/merged_v3/bit/` 에 있음). Vivado 2022.2: LUT 346 · FF 186 · WNS +3.682 ns · CRITICAL WARNING 0. (v3 는 LUT 313. 늘어난 이유는 아직 확인 안 함)
- 보드 확인: SW0 올림 → R(시작) → 5초 뒤 **L → 안 지워지고 계속** → **U → 방향 안 바뀜** → R(정지) → L → `00.00` · U → 다운카운트 설정됨.

## v3 → v4 변경 (기능 변화 없음)
- 상태 머신 3개를 `.sv` 로 바꾸고 `parameter` 상태값을 `typedef enum` (`state_t`)로 바꿈 → 시뮬레이션 파형에서 `c_state`/`n_state` 가 숫자 대신 이름(STOP · RUN · NORMAL · SET_MIN_1 · ALARM …)으로 보인다. 인코딩 값은 그대로.
  - `stopwatch_control_unit.sv` : STOP, RUN
  - `watch_control_unit.sv` : NORMAL, SET_HOUR, SET_MIN_10, SET_MIN_1
  - `timer_control_unit.sv` : SET, RUN, ALARM
- `build/build.tcl` : `.sv` 는 `read_verilog -sv` 로 읽도록 한 줄 추가.
- 검증: v3 TB 그대로 Icarus(-g2012) 실행 → TOTAL MISMATCH = 0 (PASS), T11 = 5999610 ns 로 v3 와 동일. **v4 bit 는 아직 안 만들었다** (`bit/` 에 있는 것은 v3 것).

---

# (아래는 merged_v3 내용 그대로)
# merged_v3 — 팀 통합판 + 10/16 변경 반영 (2026-10-16)

- **기준**: `ahnsung/source_file_v2/` (정안성 통합판, 랩타임 · 공용 100 Hz tick · 4 kHz 버튼/FND 포함, 커밋 83c53ad) + `ahnsung/lib/` 에서 필요한 9개(btn_debounce · clock_tick_generator · counter8 · decoder_2x4 · digit_splitter · dot · fnd_decoder · mux_2x1 · mux_8x1)를 그대로 복사.
- 바꾼 부분 외에는 팀원 코드 그대로. `ahnsung/` 폴더는 건드리지 않았다.

## 바뀐 것
| 기능 | 내용 | 파일 |
|---|---|---|
| 12/24시간 (sw3) | 극성 반대: **sw3 = 0 → 12시간(기본)**, 1 → 24시간. 포트 이름 `sw_12h` → `sw_24h`. 리셋하면 오후 12:00 | `stopwatch_watch.v`(`.sw_12h(~sw_24h)`), `.xdc` |
| 오후 LED | led4 → **led15 (맨 왼쪽)**. led4 는 알람 때만 깜빡임 | `stopwatch_watch.v` |
| 타이머 더하기 | **U +10초 · R +1분 · D +10분**, 최대 **59:59**. sw5(sw_alt) 없앰 | `timer_control_unit.v`, `timer_datapath.v`(공용 tick 입력은 팀원 판 그대로), `.xdc` |
| 타이머 화면 | sw1 과 상관없이 **왼쪽 2칸 = 분, 오른쪽 2칸 = 초**. 타이머 화면에서는 시계 점멸 안 함, LD2 · LD3 꺼짐 | `stopwatch_watch.v` |
| FND 시 자리 폭 | 시 자리 digit_splitter 폭 5 → `HOUR_BIT_WIDTH`(Top 에서 6). 타이머 분(최대 59)이 이 자리로 오기 때문 | `SW2_FND_CONTROLLER.v` (1줄) |

## 검증
- Icarus: `sim/tb_stopwatch_watch.v` (참고판 Top TB 를 통합판 이름에 맞춤: 공용 tick · 4 kHz 생성기 defparam) — T1~T11 TOTAL MISMATCH = 0. FND 점멸 검사(T8)는 정안성 FND 모듈 몫이라 이 TB 에서 뺌.
- 타이머 1분(축소 시뮬) = 5,999,610 ns: 100 Hz tick 을 셋이 같이 써서 시작 후 첫 tick 이 최대 1 tick(실제 10 ms) 빠를 수 있음 → 1분이 최대 10 ms 짧아질 수 있다(구조상 대가).
- Vivado 2022.2 (xc7a35t): LUT 313 · FF 186 · WNS +3.943 ns · 래치 0 · ERROR 0 · CRITICAL WARNING 0.
- **보드 확인은 아직.**

## 보드 확인 순서
1. 스위치 모두 0, btnC → SW1 올림 → `12.00`, **LD15 켜짐**(오후 12시)
2. SW2 올림 → L 두 번(시 자리) → U → SW2 내림 → `01.00`, LD15 켜짐 → **SW3 올림 → `13.00`, LD15 꺼짐**
3. SW4 올림 → `00.00`, LD5. U → `00.10`, U 다섯 번 더 → `01.00`, R → `02.00`, D → `12.00`, D 다섯 번 → `59.59` 에서 멈춤
4. L → LD6, 줄어듦. L → `00.00`
5. R → L → 1분 기다림 → LED 깜빡임 → 아무 버튼 → 꺼짐
6. SW4 내리고 SW0 올림 → 스톱워치 · 랩타임(D) 이 팀원 판 그대로 동작하는지

## 빌드
`build` 폴더에서 `vivado -mode batch -source build.tcl` → `stopwatch_watch.bit`. 미리 만든 것은 `bit/stopwatch_watch_merged_v3.bit`.
