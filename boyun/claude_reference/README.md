# 클로드코드(AI) 참고 구현 — 스톱워치 + 시계 + 타이머 (2026-10-15)

> **이 폴더의 새 모듈은 정보윤이 설계한 것이 아니라 클로드코드(Claude Code, AI)가 작성한 참고 구현이다.**
> 보드에서 동작을 먼저 확인하고 각자 담당 모듈을 직접 설계할 때 비교용으로 쓰려고 팀에 공유한다. 제출·발표용 설계가 아니다.
> `src/` 의 btn_debounce · control_unit · stopwatch_datapath · fnd_controller 는 김창형 교수님 수업 코드 복사본(fnd_controller 는 클로드코드가 설정 점멸 입력 추가).

## 비트파일 (`bit/`)
| 파일 | 내용 |
|---|---|
| `stopwatch_watch_v1.bit` | 스톱워치 + 시계 + 12/24시간 (타이머 없음). 보드 확인 끝남 |
| `stopwatch_watch_v2_timer.bit` | v1 + 타이머(sw4 · sw5). 보드 확인 아직 |
| `stopwatch_watch_2khz.bit` | v2 와 같고 디바운서 샘플만 1 MHz → 2 kHz (8칸 = 8 µs → 4 ms). 버튼 두 번 눌림 비교용 |

## 파일
| 파일 | 내용 | 출처 |
|---|---|---|
| `src/btn_debounce.v` · `control_unit.v` | 디바운서, 스톱워치 FSM | 김창형 교수님 수업 코드 복사(그대로) |
| `src/stopwatch_datapath.v` | stopwatch_datapath · tick_gen_100hz · tick_counter | 수업 `stopwatch.v` 에서 top 만 빼고 복사 |
| `src/fnd_controller.v` | dot 판 + **설정 점멸**(`blink_en`, `blink_field`) | 수업 코드 복사 후 클로드코드 추가 |
| `src/watch_control_unit.v` | 시계 FSM: NORMAL · SET_HOUR · SET_MIN · SET_SEC | 클로드코드 |
| `src/watch_datapath.v` | 시계 데이터패스 + watch_tick_counter(리셋값 INIT, 칸 ±1, tick 우선) | 클로드코드 |
| `src/hour_12_24.v` | 12/24 시간 표시 변환 (sw3, 팀 추가 기능) | 클로드코드 |
| `src/stopwatch_watch.v` · `.xdc` | Top · 핀 | 클로드코드 |
| `sim/tb_stopwatch_watch.v` | Top 자동 검사 T1~T10 (100Hz tick 만 1/10000 로 줄임) | 클로드코드 |
| `sim/tb_watch_tick_counter.v` | 카운터 단위 검사 (tick 우선, 칸만 돌기) | 클로드코드 |
| `build/build.tcl` | 배치 빌드 (build 폴더에서 실행하면 stopwatch_watch.bit 생성) | 클로드코드 |

## 스위치 · 버튼 · LED
| | 0 | 1 |
|---|---|---|
| sw0 (V17) | 시계 | 스톱워치 |
| sw1 (V16) | 초.1/100초 | 시.분 |
| sw2 (W16) | 시계 normal | 시계 시간 설정 |
| sw3 (W17) | 24시간 표시 | 12시간 표시 (시계만) |

- 버튼(시계, sw2 = 1 일 때만): R 오른쪽 칸 · L 왼쪽 칸(양 끝 돌아감) · U +1 · D −1. 설정 들어가면 시 칸부터. 칸만 돌고 올림·내림 없음. msec 는 설정 안 함.
- 버튼(스톱워치): R run_stop · L clear · U mode(업/다운). D 랩타임은 없음(옵션).
- btnC = reset: 스톱워치 0, 시계 12:00:00:00 (둘 다).
- LED: led0 시계 · led1 스톱워치 · led2 시.분 표시 · led3 초.1/100초 표시 · led4 오후(시계 + 12시간 표시일 때).
- 시계는 스톱워치를 보고 있을 때도, 설정 중에도 계속 흐른다. 같은 클럭에 tick 과 버튼이 겹치면 tick 우선.

## 확인한 것 (2026-10-15, 클로드코드 실행)
- Icarus 12: `tb_stopwatch_watch` TOTAL MISMATCH = 0, `tb_watch_tick_counter` TOTAL MISMATCH = 0.
- bug 6개를 하나씩 넣어 TB 가 잡는지 확인: L 돌아가기 없음 · 게이팅 반대 · 12h 0시→0 · 점멸 칸 틀림 · tick 우선 뒤집기 · 설정 중 올림 발생 → 모두 FAIL 로 잡힘.
- Vivado 2022.2 배치 빌드(실제 100 MHz 값): WNS +5.476 ns, 래치 0, DRC 0, LUT 256 · FF 189, IO 27.
- report_methodology: TIMING-17 35개 = 디바운서 1 MHz 신호와 FND 800 Hz 신호를 클럭으로 쓰는 수업 구조 그대로 (수업 프로젝트에도 같은 것). 이번에 새로 생긴 것 아님.
- 보드 확인: 정보윤이 v1 기본 동작 확인 (10/15).

## 보드에 올리기
1. 아무 Vivado 창에서 Open Hardware Manager → Open Target → Auto Connect → Program Device.
2. Bitstream file 칸에 **이 경로**가 있는지 확인: ``bit\stopwatch_watch_v2_timer.bit` (또는 v1)` (다른 프로젝트 bit 가 들어가 있을 수 있음).
3. 다시 빌드하려면 `build` 폴더에서 `vivado -mode batch -nojournal -source build.tcl -log build.log`.

## 보드 확인 순서
1. 스위치 모두 0, btnC → FND `00.00` 부터 초.1/100초 흐름, 점 0.5 초 점멸, led0 · led3 켜짐.
2. sw1 = 1 → `12.00`, led2 켜짐(led3 꺼짐).
3. sw2 = 1 → 시 두 자리 0.5 초 점멸. U → `13.xx`, D → `12.xx`.
4. R → 분 점멸, U/D 로 분만 바뀌고 시는 그대로(59 ↔ 00 에서 시가 안 바뀜).
5. R → 초 칸(sw1 = 0 으로 내려서 초 점멸 확인) → R → 다시 시 칸. L 은 반대로, 시에서 L → 초.
6. sw2 = 0 → 점멸 멈춤, 버튼 눌러도 안 바뀜.
7. sw3 = 1 → 시가 13 이면 `01`, led4 켜짐. 12 → `12` + led4, 00 → `12` + led4 꺼짐. sw3 = 0 → 원래대로.
8. sw0 = 1 → led1, 스톱워치: R 시작/정지, L clear, U 업/다운 (전과 같음). 이때 U/D 를 눌러도 시계는 안 바뀜.
9. sw0 = 0 으로 돌아오면 시계는 그동안 흐른 시각.
10. btnC → 둘 다 리셋(시계 12:00).

---

## 타이머(빠른 알람) 추가 — 2026-10-15 04:30 (정보윤 요청)
- 타이머가 없는 앞 판(보드 확인 끝난 것)은 `bit\stopwatch_watch_v1.bit`.
- 새 파일: `src\timer_control_unit.v`(FSM SET → RUN → ALARM), `src\timer_datapath.v`(남은 시간 거꾸로 세기 · 분 더하기 · 12:00 상한 · 0 검출). Top · XDC · TB 수정.

| 스위치 | 0 | 1 |
|---|---|---|
| sw4 (W15) `sw_timer` | 시계/스톱워치 (sw0 대로) | **타이머** 화면 · 버튼 (sw0 보다 우선) |
| sw5 (V15) `sw_alt` | U +1분 · R +10분 | U +4분 · R +30분 |

- 타이머 버튼: SET 에서 U · R · D(+60분) = 더하기, L = 시작(0 이면 안 함). RUN 에서 L = 취소(0 으로). ALARM 에서 아무 버튼 = 끄기(타이머 화면에서만).
- 최대 12:00:00.00 — 넘게 더하면 12:00 으로.
- LED: led5 (U15) 타이머 화면 · led6 (U14) 타이머 진행 중 · **알람 중에는 어느 화면이든 led 16개 전부 0.5초 점멸**. 소리는 Basys-3 에 부저/스피커가 없어 안 넣음(Pmod 부품 필요).
- 타이머도 시계·스톱워치처럼 화면과 상관없이 계속 줄어든다.

### 확인한 것 (Icarus · Vivado 2022.2)
- TB T11 추가: 0 에서 시작 안 함, +1 · +10 · +4 · +30 · +60, 분 넘김(1:45 + 30 = 2:15), 12:00 상한, 시작 · 취소, 시계 화면에서도 계속 줄어듦, **1분 = 6,000,020 ns (1 "초" = 100 µs 로 줄인 시뮬, 60 "초" + 2클럭)**, 알람 LED 16개 점멸, 시계 버튼으로는 안 꺼짐, 타이머 버튼으로 끔(D 가 60분 더하지 않음). T1~T11 TOTAL MISMATCH = 0.
- bug 4개 주입 → 모두 잡힘 (상한 없음 · 0 에서 시작 · 알람 LED 타이머 화면만 · 알람 중 D 가 60분 더함).
- Vivado: WNS +2.064 ns, 래치 0, LUT 353 · FF 237 · IO 40. 방법론 TIMING-17 35개(수업 구조, 전과 같음) + **TIMING-18 29개 새로**(입출력 지연 미지정 — LED 가 레지스터 값으로도 바뀌게 되어 생김. 사람이 보는 스위치·LED 라 영향 없음).
- 보드 확인은 아직.

### 보드 확인 순서 (타이머)
1. sw4 올림 → LD5 켜짐, FND `00.00`. sw1 올려서 시.분으로.
2. U → `00.01`, R → `00.11`. sw5 올리고 U → `00.15`, R → `00.45`. sw5 내리고 D → `01.45`.
3. D 를 열 번 넘게 → `12.00` 에서 멈춤.
4. L → LD6 켜짐, 줄어들기 시작(sw1 내리면 초.1/100초가 줄어드는 게 보임). 다시 L → 취소, `00.00`.
5. U(1분) → L 시작 → sw4 내려 시계 화면으로. 약 1분 뒤 **LED 16개 전부 깜빡임**.
6. 시계 화면에서 버튼 → 안 꺼짐. sw4 올리고 아무 버튼 → 꺼짐, LD5 만 남음.

---

## 디바운서 2 kHz 판 — 2026-10-15 낮 (보드에서 U/D 가 가끔 2 이상 변함)
- `bit\stopwatch_watch_2khz.bit`: 타이머 판(v2)과 같고, `btn_debounce` 의 F_COUNT 만 100 → 50,000 (샘플 1 MHz → 2 kHz, 8칸 = 8 µs → 4 ms). `src\` 는 안 바꿈 — 바꾼 파일은 `build_2khz\btn_debounce.v`, 빌드 `build_2khz\build.tcl`.
- Vivado 2022.2: LUT 353 → 377, FF 237 → 273 (디바운서 4개 × 카운터 7 → 16비트), WNS +1.701 ns, ERROR 0.
- 시뮬(인위적 튐 모델: 누를 때 · 뗄 때 각각 5~105 µs 조각 20개, 20번 누름): o_btn 1 MHz 판 412개 / 2 kHz 판 20개. 실제 보드 버튼의 튐 길이는 안 잼.
- 보드 비교: 시계 설정(sw1 · sw2 = 1)에서 U 를 20번 → 시가 20 올라야 정상. 1 MHz 판(`bit\stopwatch_watch_v2_timer.bit`)과 2 kHz 판에서 각각 실제로 오른 값을 적는다.
- 주의: Top TB(`sim\tb_stopwatch_watch.v`)는 버튼을 20 µs 누르므로 2 kHz 판 디바운서로는 안 눌린다. 이 판은 보드 비교용.
