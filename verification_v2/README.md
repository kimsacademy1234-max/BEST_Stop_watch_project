# verification_v2 — 포트 이름 통일 · 블록 다이어그램 일치 · 모듈 포트 기준 파형 분석

## 1. 왜 v2 를 만들었나 (기존 문제)

1. **포트 · 와이어 이름이 모듈마다 제각각** — 리셋이 `rst` / `reset` / `i_reset`, 세 데이터패스 출력이 모두 `msec sec min hour`, 스위치가 `sw_mode` 처럼 이름만 있고 보드의 몇 번 스위치인지 모름 → 파형에서 어느 모듈 출력인지 알 수 없음
2. **블록 다이어그램이 실제 포트와 안 맞음** — 선 개수 · 이름이 포트와 1:1 이 아니고, 안 쓰는 포트 · 연결 안 된 출력이 있었음
3. **TB 문서가 TB 별칭 와이어(`wv_*`) 기준** — 어느 블록에서 어느 블록으로 흐르는지 파형에서 알 수 없음

## 2. 결과물

| 위치 | 내용 |
|---|---|
| `source_file/` | `boyun/merged_v4/src` 복사 → 포트 이름 통일 (동작 동일, 100 MHz 그대로). 원본 `boyun/merged_v4` 는 손대지 않음 |
| `source_file/PORT_MAP.md` | 블록마다 입력 · 출력 포트와 연결 상대 (자동 생성) |
| `block_diagram.pdf` | 1 쪽 Top 전체, 2 쪽 `U_FND_CONTROLLER` 내부. 선 이름 = 포트 이름, 블록의 선 개수 = 포트 개수 |
| `control_unit_fsm.pdf` | 컨트롤 유닛 3 개 (스톱워치 · 타이머 · 시계) 의 상태도 + 전이표 · Mealy 표, ASM 차트 (7 쪽). 만들 때마다 Verilator 로 RTL 과 매 클럭 대조 |
| `tb/top`, `tb/01_stopwatch`, `tb/02_timer`, `tb/03_watch` | TB 11 개 (새 포트 이름) + 폴더마다 안내서 `README.md` + TB 별 색칠 그림 `img/*.png` + 그림 모음 PDF `<폴더>_tb_figures.pdf` (TB 1 개 = 1 쪽) |
| `tb/defect_1~4` | 결함 주입 TB 4 개 + 결함 src (F1 · F2 · F4, 주입기 포트도 같은 규칙) |
| `diagram/` | 다이어그램 · 안내서 그림 생성 스크립트 |

## 3. 이름 규칙

| 규칙 | 예 |
|---|---|
| 모듈 입력 `i_`, 출력 `o_`, Top 안 선 `w_` | |
| **한 신호는 출력 → 선 → 입력까지 같은 몸통 이름** | `U_STOPWATCH_CONTROL_UNIT.o_sw_run_stop` → `w_sw_run_stop` → `U_STOPWATCH_DATAPATH.i_sw_run_stop` |
| 클럭 · 리셋 | 모든 모듈 `i_clk`, `i_rst` (Top 핀은 `clk`, `rst`) |
| 기능 접두어 | `sw_` 스톱워치 · `wt_` 시계 · `tm_` 타이머 (`o_sw_msec`, `o_wt_msec`, `o_tm_msec`) |
| 스위치 = 이름_보드번호 | `mode_sw0`, `display_mode_sw1`, `set_sw2`, `hour24_sw3`, `timer_sw4` (결함용 `fault_sw15`) |
| 버튼 = 버튼 글자 | 핀 `btn_R` → `U_BD_R.o_btn` = `w_btn_R` → 게이팅 `w_sw_btn_R` / `w_wt_btn_R` / `w_tm_btn_R` → `i_sw_btn_R` … |
| 시간 박자 | `o_clk_4khz` (250 us), `o_tick_10ms` (10 ms) |

### 이름 말고 바꾼 것 (동작은 같음)

- 지운 것: 안 쓰던 포트 `SW2_FND_CONTROLLER` 의 `i_clk` · `i_btn_R` · `i_btn_L`, 연결 안 되던 출력 `watch_control_unit.set_mode` · `timer_datapath.hour`, 상수로 묶여 있던 `tick_gen_100hz` 의 `run_stop` · `clear`, 어디서도 안 쓰던 파일 `mux_2x1.v`
- `stopwatch_control_unit` 출력 `mode` → `o_sw_down` (1 = 다운). `mode_sw0` 스위치와 헷갈리지 않게
- `SW2_FND_CONTROLLER` 의 `i_sw_0` (= sw_mode | sw_timer) → `i_sel_wt` (= 그 반대, 시계 화면일 때 1)
- `hour_12_24` 는 스위치 `i_hour24_sw3` 를 그대로 받음 (원본은 Top 에서 `~sw_24h` 를 넣었음)
- Top 안 assign 로직 (화면 선택 · 버튼 게이팅 · 화면 MUX · LED) 은 그대로 assign. 다이어그램에서 점선 블록 · MUX 사다리꼴 · OR 로 그림

### 10/17 ④ — 100 Hz tick 분리 (팀 결정, 정보윤 · 클로드코드 반영)

- 문제: 100 Hz tick 하나(`U_TICK_GEN_100HZ`, 항상 흐름)를 시계 · 스톱워치 · 타이머가 같이 쓰면 스톱워치 · 타이머를 **시작한 순간이 tick 사이 어디냐에 따라 첫 1/100초가 최대 10 ms 일찍** 바뀐다 (10초 타이머 = 9,998 ms, `tb_tm_2` P1).
- 바꾼 것: `source_file/tick_gen_100hz_run.v` 추가 (10/14 수업 tick_gen 과 같은 run_stop · clear 판). Top 에 `U_TICK_GEN_SW`(run = `w_sw_run_stop`, clear = `w_sw_clear`) · `U_TICK_GEN_TM`(run = `w_tm_run`, clear = `w_tm_clear`) 을 두고 각 데이터패스 `i_tick_10ms` 에 연결. 시계는 `U_TICK_GEN_100HZ` 그대로. **4 kHz(디바운서 4 + FND 스캔)는 그대로 하나를 공유** (시작 시점을 맞출 필요가 없어서 — 자원 이득은 여기서 나옴).
- 결과: 스톱워치 · 타이머 첫 tick = 시작 뒤 정확히 10.000 ms. 자원은 아래 "구현 결과" 표.
- **10/17 밤 추가 수정 2개** (④ 구조에서 남던 클럭 단위 어긋남):
  1. 타이머 tick clear = 취소 **또는 알람** (`assign w_tm_tick_clear = w_tm_clear | w_tm_alarm;`). 전에는 0 이 된 뒤 ALARM 까지 2클럭 더 세어 카운터에 2 가 남아, 알람 뒤 다시 시작하면 첫 tick 이 20 ns 일찍(9,999,980 ns) 나왔음.
  2. `stopwatch_datapath` 의 `assign w_tick_10ms = i_tick_10ms & i_sw_run_stop;` → `= i_tick_10ms;` 와 `i_sw_run_stop` 포트 삭제. tick 생성기가 이미 run_stop 을 보는데 데이터패스가 한 번 더 막아서, STOP 이 tick 이 나오는 바로 그 클럭에 들어오면 RUN 동안 다 센 마지막 10 ms 를 잃었음.
  - 확인 TB (`boyun/timer_tb_verilog/`): `tb_tick_restart.v` (리셋 뒤 · 알람 뒤 · 취소 뒤 시작 → 첫 tick = 10,000,000 ns), `tb_sw_stop_edge.v` (tick 클럭에 STOP 해도 그 칸까지 셈)
- 같이 바꾼 것: `tb_tm_2` P1 의 10초 판정 범위 (9990 ms ~ 10000 ms + 1 clk → 10000 ms ± 파이프라인 클럭), 블록도 · PORT_MAP · TB 안내서(tick 단계) 재생성. `tb/defect_*/src` 의 설계 사본은 10/16 판(공용 tick) 그대로 — 결함 TB 는 FND · 스위치 · 리셋 결함이라 tick 과 무관.

## 4. 다이어그램 = 코드 보증

`diagram/gen_diagram.py` 가 Verilog 를 직접 읽어 아래가 하나라도 다르면 멈춘다 (PDF 를 만들지 않음).

1. 블록마다 입력 · 출력 포트 이름과 개수 (Top · FND 바깥 핀 포함)
2. 인스턴스마다 `.포트(선)` 연결 = 다이어그램의 선 이름
3. assign 블록의 입력 = 실제 `assign` 우변의 신호
4. 모든 입력 핀은 선 1 개 또는 깃발 1 개, 모든 출력 핀은 선 1 개 이상

다시 만들기: `cd diagram && python3 gen_diagram.py && python3 tb_guide.py && python3 gen_fsm.py` (Windows Chrome 으로 PDF · PNG 를 그림). 뒤에 `--open` 을 붙이면 만든 PNG 를 Windows 사진 앱으로 연다 (예: `python3 tb_guide.py 01_stopwatch --open`)

## 5. 파형 보는 법 (요약)

Vivado Scope 창에서 `dut → U_xxx` 인스턴스를 고르면 Objects 창에 **그 모듈의 포트가 다이어그램과 같은 이름으로** 나온다. 각 `tb/*/README.md` 의 "단계" 표 순서 (= 다이어그램 입력 → 출력 순서) 로 포트를 넣고, 마지막 단계 FND (`fnd_com` 자리별 `fnd_font`) 로 기능 완료를 판정한다.

## 6. 폴더 구조

```
verification_v2/
├── README.md               (이 문서)
├── block_diagram.pdf
├── control_unit_fsm.pdf     (컨트롤 유닛 상태도 · ASM 차트)
├── source_file/            (포트 통일한 설계 + PORT_MAP.md + stopwatch_watch.xdc, 10/17 tick_gen_100hz_run.v 추가)
├── diagram/                (gen_diagram.py, tb_guide.py, gen_fsm.py, png/ 미리보기)
└── tb/
    ├── top/                tb_top_1_btn_debounce, tb_top_2_fnd_scan
    ├── 01_stopwatch/       tb_sw_1 ~ 3
    ├── 02_timer/           tb_tm_1 ~ 3
    ├── 03_watch/           tb_wt_1 ~ 3
    └── defect_1 ~ 4/       결함 주입 (src/, build/, defect.patch)
    (폴더마다 README.md 안내서 · fnd_monitor.sv, 기능 폴더 4 개에는 img/ TB 별 그림)
```
