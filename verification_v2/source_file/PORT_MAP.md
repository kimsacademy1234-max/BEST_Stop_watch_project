# PORT_MAP — 모듈 포트 · 연결표 (자동 생성: diagram/gen_diagram.py)

블록 다이어그램(`../block_diagram.pdf`)과 같은 데이터에서 만든다. Verilog 포트 목록과 하나라도 다르면 생성 스크립트가 멈춘다.

- 이름 규칙: 모듈 입력 `i_*`, 출력 `o_*`, Top 안 와이어 `w_*` (`o_xxx` → `w_xxx` → `i_xxx`)
- 기능 접두어: `sw_` 스톱워치 · `wt_` 시계 · `tm_` 타이머 / 스위치 `*_swN` / 버튼 `*_btn_R·L·U·D`
- Vivado 파형: Scope 창에서 `dut` 아래 인스턴스를 고르면 Objects 창에 아래 포트가 그대로 나온다


## stopwatch_watch (Top) — 블록 다이어그램 · 포트 이름 = 선 이름

### U_CLK_GEN_4KHZ (clock_tick_generator)

입력 2 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_clk` | 1 | `clk` (깃발: Top 핀 직결) |
| in | `i_rst` | 1 | `rst` (깃발: Top 핀 직결) |
| out | `o_clk_4khz` | 1 | `w_clk_4khz` → `U_BD_R`.`i_clk_4khz`<br>`w_clk_4khz` → `U_BD_L`.`i_clk_4khz`<br>`w_clk_4khz` → `U_BD_U`.`i_clk_4khz`<br>`w_clk_4khz` → `U_BD_D`.`i_clk_4khz`<br>`w_clk_4khz` → `U_FND_CONTROLLER`.`i_clk_4khz` |

### U_TICK_GEN_100HZ (tick_gen_100hz)

입력 2 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_clk` | 1 | `clk` (깃발: Top 핀 직결) |
| in | `i_rst` | 1 | `rst` (깃발: Top 핀 직결) |
| out | `o_tick_10ms` | 1 | `w_tick_10ms` → `U_WATCH_DATAPATH`.`i_tick_10ms` |

### U_BD_R (btn_debounce)

입력 4 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_clk` | 1 | `clk` (깃발: Top 핀 직결) |
| in | `i_rst` | 1 | `rst` (깃발: Top 핀 직결) |
| in | `i_clk_4khz` | 1 | `w_clk_4khz` ← `U_CLK_GEN_4KHZ`.`o_clk_4khz` |
| in | `i_btn` | 1 | `btn_R` ← Top 입력 (보드).`btn_R` |
| out | `o_btn` | 1 | `w_btn_R` → 버튼 게이팅 (스톱워치).`w_btn_R`<br>`w_btn_R` → 버튼 게이팅 (시계).`w_btn_R`<br>`w_btn_R` → 버튼 게이팅 (타이머).`w_btn_R` |

### U_BD_L (btn_debounce)

입력 4 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_clk` | 1 | `clk` (깃발: Top 핀 직결) |
| in | `i_rst` | 1 | `rst` (깃발: Top 핀 직결) |
| in | `i_clk_4khz` | 1 | `w_clk_4khz` ← `U_CLK_GEN_4KHZ`.`o_clk_4khz` |
| in | `i_btn` | 1 | `btn_L` ← Top 입력 (보드).`btn_L` |
| out | `o_btn` | 1 | `w_btn_L` → 버튼 게이팅 (스톱워치).`w_btn_L`<br>`w_btn_L` → 버튼 게이팅 (시계).`w_btn_L`<br>`w_btn_L` → 버튼 게이팅 (타이머).`w_btn_L` |

### U_BD_U (btn_debounce)

입력 4 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_clk` | 1 | `clk` (깃발: Top 핀 직결) |
| in | `i_rst` | 1 | `rst` (깃발: Top 핀 직결) |
| in | `i_clk_4khz` | 1 | `w_clk_4khz` ← `U_CLK_GEN_4KHZ`.`o_clk_4khz` |
| in | `i_btn` | 1 | `btn_U` ← Top 입력 (보드).`btn_U` |
| out | `o_btn` | 1 | `w_btn_U` → 버튼 게이팅 (스톱워치).`w_btn_U`<br>`w_btn_U` → 버튼 게이팅 (시계).`w_btn_U`<br>`w_btn_U` → 버튼 게이팅 (타이머).`w_btn_U` |

### U_BD_D (btn_debounce)

입력 4 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_clk` | 1 | `clk` (깃발: Top 핀 직결) |
| in | `i_rst` | 1 | `rst` (깃발: Top 핀 직결) |
| in | `i_clk_4khz` | 1 | `w_clk_4khz` ← `U_CLK_GEN_4KHZ`.`o_clk_4khz` |
| in | `i_btn` | 1 | `btn_D` ← Top 입력 (보드).`btn_D` |
| out | `o_btn` | 1 | `w_btn_D` → 버튼 게이팅 (스톱워치).`w_btn_D`<br>`w_btn_D` → 버튼 게이팅 (시계).`w_btn_D`<br>`w_btn_D` → 버튼 게이팅 (타이머).`w_btn_D` |

### 화면 선택 (Top 안 assign)

입력 2 개 · 출력 3 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `mode_sw0` | 1 | `sw0` (깃발: Top 핀 직결) |
| in | `timer_sw4` | 1 | `sw4` (깃발: Top 핀 직결) |
| out | `w_sel_sw` | 1 | `w_sel_sw` → 버튼 게이팅 (스톱워치).`w_sel_sw`<br>`w_sel_sw` → LED 출력.`w_sel_sw` |
| out | `w_sel_wt` | 1 | `w_sel_wt` → 버튼 게이팅 (시계).`w_sel_wt`<br>`w_sel_wt` → `U_FND_CONTROLLER`.`i_sel_wt`<br>`w_sel_wt` → LED 출력.`w_sel_wt` |
| out | `w_sel_tm` | 1 | `w_sel_tm` → 버튼 게이팅 (타이머).`w_sel_tm`<br>`w_sel_tm` → LED 출력.`w_sel_tm` |

### 버튼 게이팅 (스톱워치) (Top 안 assign)

입력 5 개 · 출력 4 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `w_btn_R` | 1 | `w_btn_R` ← `U_BD_R`.`o_btn` |
| in | `w_btn_L` | 1 | `w_btn_L` ← `U_BD_L`.`o_btn` |
| in | `w_btn_U` | 1 | `w_btn_U` ← `U_BD_U`.`o_btn` |
| in | `w_btn_D` | 1 | `w_btn_D` ← `U_BD_D`.`o_btn` |
| in | `w_sel_sw` | 1 | `w_sel_sw` ← 화면 선택.`w_sel_sw` |
| out | `w_sw_btn_R` | 1 | `w_sw_btn_R` → `U_STOPWATCH_CONTROL_UNIT`.`i_sw_btn_R` |
| out | `w_sw_btn_L` | 1 | `w_sw_btn_L` → `U_STOPWATCH_CONTROL_UNIT`.`i_sw_btn_L` |
| out | `w_sw_btn_U` | 1 | `w_sw_btn_U` → `U_STOPWATCH_CONTROL_UNIT`.`i_sw_btn_U` |
| out | `w_sw_btn_D` | 1 | `w_sw_btn_D` → `U_STOPWATCH_DATAPATH`.`i_sw_btn_D` |

### 버튼 게이팅 (시계) (Top 안 assign)

입력 5 개 · 출력 4 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `w_btn_R` | 1 | `w_btn_R` ← `U_BD_R`.`o_btn` |
| in | `w_btn_L` | 1 | `w_btn_L` ← `U_BD_L`.`o_btn` |
| in | `w_btn_U` | 1 | `w_btn_U` ← `U_BD_U`.`o_btn` |
| in | `w_btn_D` | 1 | `w_btn_D` ← `U_BD_D`.`o_btn` |
| in | `w_sel_wt` | 1 | `w_sel_wt` ← 화면 선택.`w_sel_wt` |
| out | `w_wt_btn_R` | 1 | `w_wt_btn_R` → `U_WATCH_CONTROL_UNIT`.`i_wt_btn_R` |
| out | `w_wt_btn_L` | 1 | `w_wt_btn_L` → `U_WATCH_CONTROL_UNIT`.`i_wt_btn_L` |
| out | `w_wt_btn_U` | 1 | `w_wt_btn_U` → `U_WATCH_CONTROL_UNIT`.`i_wt_btn_U` |
| out | `w_wt_btn_D` | 1 | `w_wt_btn_D` → `U_WATCH_CONTROL_UNIT`.`i_wt_btn_D` |

### 버튼 게이팅 (타이머) (Top 안 assign)

입력 5 개 · 출력 4 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `w_btn_R` | 1 | `w_btn_R` ← `U_BD_R`.`o_btn` |
| in | `w_btn_L` | 1 | `w_btn_L` ← `U_BD_L`.`o_btn` |
| in | `w_btn_U` | 1 | `w_btn_U` ← `U_BD_U`.`o_btn` |
| in | `w_btn_D` | 1 | `w_btn_D` ← `U_BD_D`.`o_btn` |
| in | `w_sel_tm` | 1 | `w_sel_tm` ← 화면 선택.`w_sel_tm` |
| out | `w_tm_btn_R` | 1 | `w_tm_btn_R` → `U_TIMER_CONTROL_UNIT`.`i_tm_btn_R` |
| out | `w_tm_btn_L` | 1 | `w_tm_btn_L` → `U_TIMER_CONTROL_UNIT`.`i_tm_btn_L` |
| out | `w_tm_btn_U` | 1 | `w_tm_btn_U` → `U_TIMER_CONTROL_UNIT`.`i_tm_btn_U` |
| out | `w_tm_btn_D` | 1 | `w_tm_btn_D` → `U_TIMER_CONTROL_UNIT`.`i_tm_btn_D` |

### U_STOPWATCH_CONTROL_UNIT (stopwatch_control_unit)

입력 5 개 · 출력 3 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_clk` | 1 | `clk` (깃발: Top 핀 직결) |
| in | `i_rst` | 1 | `rst` (깃발: Top 핀 직결) |
| in | `i_sw_btn_R` | 1 | `w_sw_btn_R` ← 버튼 게이팅 (스톱워치).`w_sw_btn_R` |
| in | `i_sw_btn_L` | 1 | `w_sw_btn_L` ← 버튼 게이팅 (스톱워치).`w_sw_btn_L` |
| in | `i_sw_btn_U` | 1 | `w_sw_btn_U` ← 버튼 게이팅 (스톱워치).`w_sw_btn_U` |
| out | `o_sw_run_stop` | 1 | `w_sw_run_stop` → `U_TICK_GEN_SW`.`i_run_stop` |
| out | `o_sw_clear` | 1 | `w_sw_clear` → `U_STOPWATCH_DATAPATH`.`i_sw_clear`<br>`w_sw_clear` → `U_TICK_GEN_SW`.`i_clear` |
| out | `o_sw_down` | 1 | `w_sw_down` → `U_STOPWATCH_DATAPATH`.`i_sw_down` |

### U_TICK_GEN_SW (tick_gen_100hz_run)

입력 4 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_clk` | 1 | `clk` (깃발: Top 핀 직결) |
| in | `i_rst` | 1 | `rst` (깃발: Top 핀 직결) |
| in | `i_run_stop` | 1 | `w_sw_run_stop` ← `U_STOPWATCH_CONTROL_UNIT`.`o_sw_run_stop` |
| in | `i_clear` | 1 | `w_sw_clear` ← `U_STOPWATCH_CONTROL_UNIT`.`o_sw_clear` |
| out | `o_tick_10ms` | 1 | `w_sw_tick_10ms` → `U_STOPWATCH_DATAPATH`.`i_tick_10ms` |

### U_TICK_GEN_TM (tick_gen_100hz_run)

입력 4 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_run_stop` | 1 | `w_tm_run` ← `U_TIMER_CONTROL_UNIT`.`o_tm_run` |
| in | `i_clear` | 1 | `w_tm_tick_clear` ← w_tm_tick_clear.`w_tm_tick_clear` |
| in | `i_clk` | 1 | `clk` (깃발: Top 핀 직결) |
| in | `i_rst` | 1 | `rst` (깃발: Top 핀 직결) |
| out | `o_tick_10ms` | 1 | `w_tm_tick_10ms` → `U_TIMER_DATAPATH`.`i_tick_10ms` |

### w_tm_tick_clear (Top 안 assign)

입력 2 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `w_tm_clear` | 1 | `w_tm_clear` ← `U_TIMER_CONTROL_UNIT`.`o_tm_clear` |
| in | `w_tm_alarm` | 1 | `w_tm_alarm` ← `U_TIMER_CONTROL_UNIT`.`o_tm_alarm` |
| out | `w_tm_tick_clear` | 1 | `w_tm_tick_clear` → `U_TICK_GEN_TM`.`i_clear` |

### U_WATCH_CONTROL_UNIT (watch_control_unit)

입력 7 개 · 출력 3 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_clk` | 1 | `clk` (깃발: Top 핀 직결) |
| in | `i_rst` | 1 | `rst` (깃발: Top 핀 직결) |
| in | `i_wt_btn_R` | 1 | `w_wt_btn_R` ← 버튼 게이팅 (시계).`w_wt_btn_R` |
| in | `i_wt_btn_L` | 1 | `w_wt_btn_L` ← 버튼 게이팅 (시계).`w_wt_btn_L` |
| in | `i_wt_btn_U` | 1 | `w_wt_btn_U` ← 버튼 게이팅 (시계).`w_wt_btn_U` |
| in | `i_wt_btn_D` | 1 | `w_wt_btn_D` ← 버튼 게이팅 (시계).`w_wt_btn_D` |
| in | `i_set_sw2` | 1 | `sw2` (깃발: Top 핀 직결) |
| out | `o_wt_cursor` | [1:0] | `w_wt_cursor` → `U_WATCH_DATAPATH`.`i_wt_cursor`<br>`w_wt_cursor` → `U_FND_CONTROLLER`.`i_wt_cursor` |
| out | `o_wt_up` | 1 | `w_wt_up` → `U_WATCH_DATAPATH`.`i_wt_up` |
| out | `o_wt_down` | 1 | `w_wt_down` → `U_WATCH_DATAPATH`.`i_wt_down` |

### U_TIMER_CONTROL_UNIT (timer_control_unit)

입력 7 개 · 출력 5 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_clk` | 1 | `clk` (깃발: Top 핀 직결) |
| in | `i_rst` | 1 | `rst` (깃발: Top 핀 직결) |
| in | `i_tm_btn_R` | 1 | `w_tm_btn_R` ← 버튼 게이팅 (타이머).`w_tm_btn_R` |
| in | `i_tm_btn_L` | 1 | `w_tm_btn_L` ← 버튼 게이팅 (타이머).`w_tm_btn_L` |
| in | `i_tm_btn_U` | 1 | `w_tm_btn_U` ← 버튼 게이팅 (타이머).`w_tm_btn_U` |
| in | `i_tm_btn_D` | 1 | `w_tm_btn_D` ← 버튼 게이팅 (타이머).`w_tm_btn_D` |
| in | `i_tm_zero` | 1 | `w_tm_zero` ← `U_TIMER_DATAPATH`.`o_tm_zero` |
| out | `o_tm_run` | 1 | `w_tm_run` → `U_TIMER_DATAPATH`.`i_tm_run`<br>`w_tm_run` → LED 출력.`w_tm_run`<br>`w_tm_run` → `U_TICK_GEN_TM`.`i_run_stop` |
| out | `o_tm_alarm` | 1 | `w_tm_alarm` → LED 출력.`w_tm_alarm`<br>`w_tm_alarm` → w_tm_tick_clear.`w_tm_alarm` |
| out | `o_tm_clear` | 1 | `w_tm_clear` → `U_TIMER_DATAPATH`.`i_tm_clear`<br>`w_tm_clear` → w_tm_tick_clear.`w_tm_clear` |
| out | `o_tm_add` | 1 | `w_tm_add` → `U_TIMER_DATAPATH`.`i_tm_add` |
| out | `o_tm_amount` | [1:0] | `w_tm_amount` → `U_TIMER_DATAPATH`.`i_tm_amount` |

### U_STOPWATCH_DATAPATH (stopwatch_datapath)

입력 6 개 · 출력 5 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_clk` | 1 | `clk` (깃발: Top 핀 직결) |
| in | `i_rst` | 1 | `rst` (깃발: Top 핀 직결) |
| in | `i_tick_10ms` | 1 | `w_sw_tick_10ms` ← `U_TICK_GEN_SW`.`o_tick_10ms` |
| in | `i_sw_clear` | 1 | `w_sw_clear` ← `U_STOPWATCH_CONTROL_UNIT`.`o_sw_clear` |
| in | `i_sw_down` | 1 | `w_sw_down` ← `U_STOPWATCH_CONTROL_UNIT`.`o_sw_down` |
| in | `i_sw_btn_D` | 1 | `w_sw_btn_D` ← 버튼 게이팅 (스톱워치).`w_sw_btn_D` |
| out | `o_sw_msec` | [6:0] | `w_sw_msec` → w_disp_msec.`w_sw_msec` |
| out | `o_sw_sec` | [5:0] | `w_sw_sec` → w_disp_sec.`w_sw_sec` |
| out | `o_sw_min` | [5:0] | `w_sw_min` → w_disp_min.`w_sw_min` |
| out | `o_sw_hour` | [4:0] | `w_sw_hour` → w_disp_hour.`w_sw_hour` |
| out | `o_sw_lap` | 1 | `w_sw_lap` → LED 출력.`w_sw_lap` |

### U_WATCH_DATAPATH (watch_datapath)

입력 6 개 · 출력 4 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_clk` | 1 | `clk` (깃발: Top 핀 직결) |
| in | `i_rst` | 1 | `rst` (깃발: Top 핀 직결) |
| in | `i_tick_10ms` | 1 | `w_tick_10ms` ← `U_TICK_GEN_100HZ`.`o_tick_10ms` |
| in | `i_wt_cursor` | [1:0] | `w_wt_cursor` ← `U_WATCH_CONTROL_UNIT`.`o_wt_cursor` |
| in | `i_wt_up` | 1 | `w_wt_up` ← `U_WATCH_CONTROL_UNIT`.`o_wt_up` |
| in | `i_wt_down` | 1 | `w_wt_down` ← `U_WATCH_CONTROL_UNIT`.`o_wt_down` |
| out | `o_wt_msec` | [6:0] | `w_wt_msec` → w_disp_msec.`w_wt_msec`<br>`w_wt_msec` → LED 출력.`w_wt_msec` |
| out | `o_wt_sec` | [5:0] | `w_wt_sec` → w_disp_sec.`w_wt_sec` |
| out | `o_wt_min` | [5:0] | `w_wt_min` → w_disp_min.`w_wt_min` |
| out | `o_wt_hour` | [4:0] | `w_wt_hour` → `U_HOUR_12_24`.`i_wt_hour` |

### U_HOUR_12_24 (hour_12_24)

입력 2 개 · 출력 2 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_wt_hour` | [4:0] | `w_wt_hour` ← `U_WATCH_DATAPATH`.`o_wt_hour` |
| in | `i_hour24_sw3` | 1 | `sw3` (깃발: Top 핀 직결) |
| out | `o_wt_hour_disp` | [4:0] | `w_wt_hour_disp` → w_disp_hour.`w_wt_hour_disp` |
| out | `o_wt_pm` | 1 | `w_wt_pm` → LED 출력.`w_wt_pm` |

### U_TIMER_DATAPATH (timer_datapath)

입력 7 개 · 출력 4 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_clk` | 1 | `clk` (깃발: Top 핀 직결) |
| in | `i_rst` | 1 | `rst` (깃발: Top 핀 직결) |
| in | `i_tick_10ms` | 1 | `w_tm_tick_10ms` ← `U_TICK_GEN_TM`.`o_tick_10ms` |
| in | `i_tm_run` | 1 | `w_tm_run` ← `U_TIMER_CONTROL_UNIT`.`o_tm_run` |
| in | `i_tm_clear` | 1 | `w_tm_clear` ← `U_TIMER_CONTROL_UNIT`.`o_tm_clear` |
| in | `i_tm_add` | 1 | `w_tm_add` ← `U_TIMER_CONTROL_UNIT`.`o_tm_add` |
| in | `i_tm_amount` | [1:0] | `w_tm_amount` ← `U_TIMER_CONTROL_UNIT`.`o_tm_amount` |
| out | `o_tm_msec` | [6:0] | `w_tm_msec` → w_disp_msec.`w_tm_msec` |
| out | `o_tm_sec` | [5:0] | `w_tm_sec` → w_disp_sec.`w_tm_sec`<br>`w_tm_sec` → w_disp_min.`w_tm_sec` |
| out | `o_tm_min` | [5:0] | `w_tm_min` → w_disp_hour.`w_tm_min` |
| out | `o_tm_zero` | 1 | `w_tm_zero` → `U_TIMER_CONTROL_UNIT`.`i_tm_zero` |

### w_disp_msec (Top 안 assign, MUX)

입력 5 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `w_tm_msec` | 1 | `w_tm_msec` ← `U_TIMER_DATAPATH`.`o_tm_msec` |
| in | `w_sw_msec` | 1 | `w_sw_msec` ← `U_STOPWATCH_DATAPATH`.`o_sw_msec` |
| in | `w_wt_msec` | 1 | `w_wt_msec` ← `U_WATCH_DATAPATH`.`o_wt_msec` |
| in | `timer_sw4` | 1 | `sw4` (깃발: Top 핀 직결) |
| in | `mode_sw0` | 1 | `sw0` (깃발: Top 핀 직결) |
| out | `w_disp_msec` | 1 | `w_disp_msec` → `U_FND_CONTROLLER`.`i_disp_msec` |

### w_disp_sec (Top 안 assign, MUX)

입력 5 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `w_tm_sec` | 1 | `w_tm_sec` ← `U_TIMER_DATAPATH`.`o_tm_sec` |
| in | `w_sw_sec` | 1 | `w_sw_sec` ← `U_STOPWATCH_DATAPATH`.`o_sw_sec` |
| in | `w_wt_sec` | 1 | `w_wt_sec` ← `U_WATCH_DATAPATH`.`o_wt_sec` |
| in | `timer_sw4` | 1 | `sw4` (깃발: Top 핀 직결) |
| in | `mode_sw0` | 1 | `sw0` (깃발: Top 핀 직결) |
| out | `w_disp_sec` | 1 | `w_disp_sec` → `U_FND_CONTROLLER`.`i_disp_sec` |

### w_disp_min (Top 안 assign, MUX)

입력 5 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `w_tm_sec` | 1 | `w_tm_sec` ← `U_TIMER_DATAPATH`.`o_tm_sec` |
| in | `w_sw_min` | 1 | `w_sw_min` ← `U_STOPWATCH_DATAPATH`.`o_sw_min` |
| in | `w_wt_min` | 1 | `w_wt_min` ← `U_WATCH_DATAPATH`.`o_wt_min` |
| in | `timer_sw4` | 1 | `sw4` (깃발: Top 핀 직결) |
| in | `mode_sw0` | 1 | `sw0` (깃발: Top 핀 직결) |
| out | `w_disp_min` | 1 | `w_disp_min` → `U_FND_CONTROLLER`.`i_disp_min` |

### w_disp_hour (Top 안 assign, MUX)

입력 5 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `w_tm_min` | 1 | `w_tm_min` ← `U_TIMER_DATAPATH`.`o_tm_min` |
| in | `w_sw_hour` | 1 | `w_sw_hour` ← `U_STOPWATCH_DATAPATH`.`o_sw_hour` |
| in | `w_wt_hour_disp` | 1 | `w_wt_hour_disp` ← `U_HOUR_12_24`.`o_wt_hour_disp` |
| in | `timer_sw4` | 1 | `sw4` (깃발: Top 핀 직결) |
| in | `mode_sw0` | 1 | `sw0` (깃발: Top 핀 직결) |
| out | `w_disp_hour` | 1 | `w_disp_hour` → `U_FND_CONTROLLER`.`i_disp_hour` |

### w_disp_mode (Top 안 assign)

입력 2 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `timer_sw4` | 1 | `sw4` (깃발: Top 핀 직결) |
| in | `display_mode_sw1` | 1 | `sw1` (깃발: Top 핀 직결) |
| out | `w_disp_mode` | 1 | `w_disp_mode` → `U_FND_CONTROLLER`.`i_disp_mode` |

### U_FND_CONTROLLER (SW2_FND_CONTROLLER)

입력 10 개 · 출력 2 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_rst` | 1 | `rst` (깃발: Top 핀 직결) |
| in | `i_clk_4khz` | 1 | `w_clk_4khz` ← `U_CLK_GEN_4KHZ`.`o_clk_4khz` |
| in | `i_disp_msec` | [6:0] | `w_disp_msec` ← w_disp_msec.`w_disp_msec` |
| in | `i_disp_sec` | [5:0] | `w_disp_sec` ← w_disp_sec.`w_disp_sec` |
| in | `i_disp_min` | [5:0] | `w_disp_min` ← w_disp_min.`w_disp_min` |
| in | `i_disp_hour` | [5:0] | `w_disp_hour` ← w_disp_hour.`w_disp_hour` |
| in | `i_disp_mode` | 1 | `w_disp_mode` ← w_disp_mode.`w_disp_mode` |
| in | `i_wt_cursor` | [1:0] | `w_wt_cursor` ← `U_WATCH_CONTROL_UNIT`.`o_wt_cursor` |
| in | `i_sel_wt` | 1 | `w_sel_wt` ← 화면 선택.`w_sel_wt` |
| in | `i_set_sw2` | 1 | `sw2` (깃발: Top 핀 직결) |
| out | `o_fnd_com` | [3:0] | `fnd_com` → Top 출력 (보드).`fnd_com` |
| out | `o_fnd_font` | [7:0] | `fnd_font` → Top 출력 (보드).`fnd_font` |

### LED 출력 (Top 안 assign)

입력 11 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `w_tm_alarm` | 1 | `w_tm_alarm` ← `U_TIMER_CONTROL_UNIT`.`o_tm_alarm` |
| in | `w_tm_run` | 1 | `w_tm_run` ← `U_TIMER_CONTROL_UNIT`.`o_tm_run` |
| in | `w_wt_msec` | [6:0] | `w_wt_msec` ← `U_WATCH_DATAPATH`.`o_wt_msec` |
| in | `w_wt_pm` | 1 | `w_wt_pm` ← `U_HOUR_12_24`.`o_wt_pm` |
| in | `w_sel_wt` | 1 | `w_sel_wt` ← 화면 선택.`w_sel_wt` |
| in | `w_sel_sw` | 1 | `w_sel_sw` ← 화면 선택.`w_sel_sw` |
| in | `w_sel_tm` | 1 | `w_sel_tm` ← 화면 선택.`w_sel_tm` |
| in | `w_sw_lap` | 1 | `w_sw_lap` ← `U_STOPWATCH_DATAPATH`.`o_sw_lap` |
| in | `display_mode_sw1` | 1 | `sw1` (깃발: Top 핀 직결) |
| in | `timer_sw4` | 1 | `sw4` (깃발: Top 핀 직결) |
| in | `hour24_sw3` | 1 | `sw3` (깃발: Top 핀 직결) |
| out | `led` | [15:0] | `led` → Top 출력 (보드).`led` |


## U_FND_CONTROLLER (SW2_FND_CONTROLLER) 내부 — FND 자리별 출력이 만들어지는 길

### U_MSEC (digit_splitter)

입력 1 개 · 출력 2 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_value` | [6:0] | `i_disp_msec` ← 입력 포트.`i_disp_msec` |
| out | `o_digit1` | [3:0] | `w_msec_digit1` → `U_ANODE_CHOICE_TO_MUX1`.`i_an0` |
| out | `o_digit10` | [3:0] | `w_msec_digit10` → `U_ANODE_CHOICE_TO_MUX1`.`i_an1` |

### U_SEC (digit_splitter)

입력 1 개 · 출력 2 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_value` | [5:0] | `i_disp_sec` ← 입력 포트.`i_disp_sec` |
| out | `o_digit1` | [3:0] | `w_sec_digit1` → `U_ANODE_CHOICE_TO_MUX1`.`i_an2` |
| out | `o_digit10` | [3:0] | `w_sec_digit10` → `U_ANODE_CHOICE_TO_MUX1`.`i_an3` |

### U_MIN (digit_splitter)

입력 1 개 · 출력 2 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_value` | [5:0] | `i_disp_min` ← 입력 포트.`i_disp_min` |
| out | `o_digit1` | [3:0] | `w_min_digit1` → `U_ANODE_CHOICE_TO_MUX2`.`i_an0` |
| out | `o_digit10` | [3:0] | `w_min_digit10` → `U_ANODE_CHOICE_TO_MUX2`.`i_an1` |

### U_HOUR (digit_splitter)

입력 1 개 · 출력 2 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_value` | [5:0] | `i_disp_hour` ← 입력 포트.`i_disp_hour` |
| out | `o_digit1` | [3:0] | `w_hour_digit1` → `U_ANODE_CHOICE_TO_MUX2`.`i_an2` |
| out | `o_digit10` | [3:0] | `w_hour_digit10` → `U_ANODE_CHOICE_TO_MUX2`.`i_an3` |

### U_COUNTER8 (counter8)

입력 2 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_clk_4khz` | 1 | `i_clk_4khz` ← 입력 포트.`i_clk_4khz` |
| in | `i_rst` | 1 | `i_rst` ← 입력 포트.`i_rst` |
| out | `o_scan_sel` | [2:0] | `w_scan_sel` → `U_SEC_MUXER`.`i_sel`<br>`w_scan_sel` → `U_MIN_MUXER`.`i_sel`<br>`w_scan_sel` → `U_DECODER`.`i_sel` |

### U_DOT (dot)

입력 1 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_disp_msec` | [6:0] | `i_disp_msec` ← 입력 포트.`i_disp_msec` |
| out | `o_blink_off` | 1 | `w_blink_off` → `U_ANODE_CHOICE_TO_MUX1`.`i_blink_off`<br>`w_blink_off` → `U_ANODE_CHOICE_TO_MUX2`.`i_blink_off`<br>`w_blink_off` → `U_SEC_MUXER`.`i_d6`<br>`w_blink_off` → `U_MIN_MUXER`.`i_d6` |

### U_ANODE_CHOICE_TO_MUX1 (SW2_ANODE_CHOICE)

입력 9 개 · 출력 4 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_set_sw2` | 1 | `i_set_sw2` ← 입력 포트.`i_set_sw2` |
| in | `i_disp_mode` | 1 | `i_disp_mode` ← 입력 포트.`i_disp_mode` |
| in | `i_sel_wt` | 1 | `i_sel_wt` ← 입력 포트.`i_sel_wt` |
| in | `i_wt_cursor` | [1:0] | `i_wt_cursor` ← 입력 포트.`i_wt_cursor` |
| in | `i_blink_off` | 1 | `w_blink_off` ← `U_DOT`.`o_blink_off` |
| in | `i_an0` | [3:0] | `w_msec_digit1` ← `U_MSEC`.`o_digit1` |
| in | `i_an1` | [3:0] | `w_msec_digit10` ← `U_MSEC`.`o_digit10` |
| in | `i_an2` | [3:0] | `w_sec_digit1` ← `U_SEC`.`o_digit1` |
| in | `i_an3` | [3:0] | `w_sec_digit10` ← `U_SEC`.`o_digit10` |
| out | `o_an0` | [3:0] | `w_mux1_an0` → `U_SEC_MUXER`.`i_d0` |
| out | `o_an1` | [3:0] | `w_mux1_an1` → `U_SEC_MUXER`.`i_d1` |
| out | `o_an2` | [3:0] | `w_mux1_an2` → `U_SEC_MUXER`.`i_d2` |
| out | `o_an3` | [3:0] | `w_mux1_an3` → `U_SEC_MUXER`.`i_d3` |

### U_ANODE_CHOICE_TO_MUX2 (SW2_ANODE_CHOICE)

입력 9 개 · 출력 4 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_set_sw2` | 1 | `i_set_sw2` ← 입력 포트.`i_set_sw2` |
| in | `i_disp_mode` | 1 | `i_disp_mode` ← 입력 포트.`i_disp_mode` |
| in | `i_sel_wt` | 1 | `i_sel_wt` ← 입력 포트.`i_sel_wt` |
| in | `i_wt_cursor` | [1:0] | `i_wt_cursor` ← 입력 포트.`i_wt_cursor` |
| in | `i_blink_off` | 1 | `w_blink_off` ← `U_DOT`.`o_blink_off` |
| in | `i_an0` | [3:0] | `w_min_digit1` ← `U_MIN`.`o_digit1` |
| in | `i_an1` | [3:0] | `w_min_digit10` ← `U_MIN`.`o_digit10` |
| in | `i_an2` | [3:0] | `w_hour_digit1` ← `U_HOUR`.`o_digit1` |
| in | `i_an3` | [3:0] | `w_hour_digit10` ← `U_HOUR`.`o_digit10` |
| out | `o_an0` | [3:0] | `w_mux2_an0` → `U_MIN_MUXER`.`i_d0` |
| out | `o_an1` | [3:0] | `w_mux2_an1` → `U_MIN_MUXER`.`i_d1` |
| out | `o_an2` | [3:0] | `w_mux2_an2` → `U_MIN_MUXER`.`i_d2` |
| out | `o_an3` | [3:0] | `w_mux2_an3` → `U_MIN_MUXER`.`i_d3` |

### U_SEC_MUXER (mux_8x1)

입력 9 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_d0` | 1 | `w_mux1_an0` ← `U_ANODE_CHOICE_TO_MUX1`.`o_an0` |
| in | `i_d1` | 1 | `w_mux1_an1` ← `U_ANODE_CHOICE_TO_MUX1`.`o_an1` |
| in | `i_d2` | 1 | `w_mux1_an2` ← `U_ANODE_CHOICE_TO_MUX1`.`o_an2` |
| in | `i_d3` | 1 | `w_mux1_an3` ← `U_ANODE_CHOICE_TO_MUX1`.`o_an3` |
| in | `i_d4` | 1 | `4'hf` (깃발: Top 핀 직결) |
| in | `i_d5` | 1 | `4'hf` (깃발: Top 핀 직결) |
| in | `i_d6` | 1 | `w_blink_off` ← `U_DOT`.`o_blink_off` |
| in | `i_d7` | 1 | `4'hf` (깃발: Top 핀 직결) |
| in | `i_sel` | 1 | `w_scan_sel` ← `U_COUNTER8`.`o_scan_sel` |
| out | `o_data` | 1 | `w_sec_mux_bcd` → 2:1 (assign).`w_sec_mux_bcd` |

### U_MIN_MUXER (mux_8x1)

입력 9 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_d0` | 1 | `w_mux2_an0` ← `U_ANODE_CHOICE_TO_MUX2`.`o_an0` |
| in | `i_d1` | 1 | `w_mux2_an1` ← `U_ANODE_CHOICE_TO_MUX2`.`o_an1` |
| in | `i_d2` | 1 | `w_mux2_an2` ← `U_ANODE_CHOICE_TO_MUX2`.`o_an2` |
| in | `i_d3` | 1 | `w_mux2_an3` ← `U_ANODE_CHOICE_TO_MUX2`.`o_an3` |
| in | `i_d4` | 1 | `4'hf` (깃발: Top 핀 직결) |
| in | `i_d5` | 1 | `4'hf` (깃발: Top 핀 직결) |
| in | `i_d6` | 1 | `w_blink_off` ← `U_DOT`.`o_blink_off` |
| in | `i_d7` | 1 | `4'hf` (깃발: Top 핀 직결) |
| in | `i_sel` | 1 | `w_scan_sel` ← `U_COUNTER8`.`o_scan_sel` |
| out | `o_data` | 1 | `w_min_mux_bcd` → 2:1 (assign).`w_min_mux_bcd` |

### 2:1 (assign) (Top 안 assign, MUX)

입력 3 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `w_sec_mux_bcd` | 1 | `w_sec_mux_bcd` ← `U_SEC_MUXER`.`o_data` |
| in | `w_min_mux_bcd` | 1 | `w_min_mux_bcd` ← `U_MIN_MUXER`.`o_data` |
| in | `i_disp_mode` | 1 | `i_disp_mode` ← 입력 포트.`i_disp_mode` |
| out | `w_bcd` | 1 | `w_bcd` → `U_FND_DEC`.`i_bcd` |

### U_DECODER (decoder_2x4)

입력 1 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_sel` | [1:0] | `w_scan_sel` ← `U_COUNTER8`.`o_scan_sel` |
| out | `o_fnd_com` | [3:0] | `o_fnd_com` → 출력 포트.`o_fnd_com` |

### U_FND_DEC (fnd_decoder)

입력 1 개 · 출력 1 개

| 방향 | 포트 | 폭 | 연결 (선 이름 · 상대 블록.포트) |
|---|---|---|---|
| in | `i_bcd` | [3:0] | `w_bcd` ← 2:1 (assign).`w_bcd` |
| out | `o_fnd_font` | [7:0] | `o_fnd_font` → 출력 포트.`o_fnd_font` |

