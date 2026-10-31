# sim_file — merge_final_top TB

시나리오 표 : [`tb_scenario.md`](tb_scenario.md) (ID = TB 의 검사 ID)

## 파일

| 파일 | 내용 |
|---|---|
| `tb_merge_harness.sv` | 공통 하네스 : DUT + 클럭 + 핀 모델 (버튼 · 스위치 · PC UART · SR04 · DHT11) + 모니터 + 스코어보드. 그룹 TB 가 `h` 로 둠 |
| `tb_A_reset.sv` | A1 ~ A2 리셋 · 공통 |
| `tb_B_button.sv` | B1 ~ B5 버튼 · 디바운스 |
| `tb_C_mode.sv` | C1 ~ C8 모드 선택 (스위치 ↔ UART) |
| `tb_D_stopwatch.sv` | D1 ~ D7 스톱워치 |
| `tb_E_watch.sv` | E1 ~ E6 시계 |
| `tb_F_timer.sv` | F1 ~ F6 타이머 |
| `tb_G_uart_rx.sv` | G1 ~ G9 UART 수신 · 디코더 |
| `tb_H_uart_ctrl.sv` | H1 ~ H12 UART 컨트롤러 · 전송 |
| `tb_I_sr04.sv` | I1 ~ I11 SR04 |
| `tb_J_dht11.sv` | J1 ~ J14 DHT11 |
| `tb_K_display.sv` | K1 ~ K6 FND · LED |
| `tb_L_integration.sv` | L1 ~ L6 통합 · 교차 |
| `run_xsim.bat` | xsim 배치 실행 (`wave` 를 붙이면 GUI + 파형) |
| `wcfg/tb_*.wcfg` | 그룹 TB 별 파형 설정 12 개 (시나리오 · 판정 · UART 줄 · FND 문자열 ASCII + 그룹 내부 신호) |
| `make_wcfg.py` | wcfg 생성기 — 신호를 더하려면 표를 고치고 `python3 make_wcfg.py` |
| `tb_P_present.sv` | **발표용** 대표 파형 P1 ~ P6 (`/mod` · `/btn`+`/get` · `/auto all` · ERROR · SR04 Err1~3 · DHT11 Err1~3), **시간 줄이기 없음 (실제 1 Hz)** |
| `run_present.bat` | `run_present.bat P3 wave` — 발표용 장면 하나 + `wcfg/present/P3.wcfg` |
| `make_wcfg_present.py` | 발표용 장면별 wcfg 생성기 (`wcfg/present/P1~P6.wcfg`) |
| 발표 안내서 | `../../ahnsung/FINAL/ppt_make/top_파형_캡처_안내.md` — 캡처 구간 · 슬라이드 메시지 |

설계 : `../source_file/merge_final/` = **v2 (B-2 · B-3, 10/31)** — 센서 오류 · 측정 전에 PC 도 `Err N` · `--%--C` (`../v2/README.md`). TB 기대값도 v2 기준.

## 실행

### Vivado GUI

1. Design Sources : `../source_file/merge_final/` 아래 `*.v`, `*.sv` 전부
2. Simulation Sources : `tb_merge_harness.sv` + 돌릴 그룹 TB 하나 → 그 TB 를 *Set as Top*
3. 파형 : Simulation Sources 에 `wcfg/<tb>.wcfg` 도 추가 → *Settings > Simulation > Simulation* 탭 `xsim.view` 에 그 wcfg 지정 (그러면 Run Simulation 때 자동으로 열림).
   이미 열린 시뮬이면 *File > Simulation Waveform > Open Configuration* 으로 열고 **Restart → Run All** (열기 전 구간은 기록이 안 됨)
4. Run Simulation → Run All. 콘솔 마지막 `[SUMMARY] ... => PASS` 확인

### 배치 (명령창)

```
run_xsim.bat tb_D_stopwatch        :: D 전부
run_xsim.bat tb_D_stopwatch D3     :: D3 만 (bat 이 +only_D3 로 넘김)
run_xsim.bat tb_D_stopwatch D      :: 그룹 글자도 됨
run_xsim.bat tb_D_stopwatch D3 wave :: D3 만 + xsim GUI 에 wcfg 파형 (run all 까지 자동)
run_xsim.bat tb_D_stopwatch all wave
```

### 파형 (wcfg) 읽는 법

| 묶음 | 신호 | 보는 법 |
|---|---|---|
| TB | `W_SC` · `W_CHK` · `W_RES` · `n_chk` · `n_fail` · `n_issue` | 지금 시나리오 · 마지막 검사 ID · `OK`/`FAIL`/`ISSUE` (ASCII). `n_fail` 이 늘어난 시각 = FAIL 위치 |
| UART | `W_CMD` · `W_LINE` | PC 가 보낸 명령 (CR = `#`) · FPGA 가 보낸 줄 (CR LF 뺌) |
| FND | `W_FND` | 2 ms 마다 갱신되는 표시 문자열 (`12.34` · `Err1` · `----`) |
| 그 밖 | 그룹별 | A 리셋 · B 디바운서 · C 모드 비트 · D/E/F 카운터 · G/H UART 내부 · I SR04 · J DHT11 · K FND 스캔 · L 통합 |

결과는 `xsim_work\<tb>\sim.log` (git 제외). Vivado 경로가 `C:\Xilinx\Vivado\2020.2` 가 아니면 bat 맨 위 `VIV` 수정.
**sim 은 한 번에 하나씩** (동시에 여러 개 돌리면 PC 가 매우 느려짐).

## TB 맨 위 설정

| 이름 | 뜻 |
|---|---|
| `ONLY` | `""` 전부, `"D3"` 그 시나리오만, `"D"` 그 그룹만 (`+only=D3` / `+only_D3` 플러스아그가 있으면 그쪽 우선) |
| `FAST` | 1 = 시간 줄임 (아래 표), 0 = 실제 하드웨어 시간 (몇 시간 걸릴 수 있음) |

판정 시간은 전부 이 파라미터로 계산하므로 `FAST` 를 바꿔도 판정 코드는 그대로입니다.

| 하네스 파라미터 | 대상 | 실제 (`FAST = 0`) | `FAST = 1` |
|---|---|---|---|
| `TICK_F` | WTS 10 ms tick (시계 · 스톱워치 · 타이머) | 1,000,000 | 1,000 (1 초 = 1 ms). A 는 원래 값, K 는 100,000 |
| `AUTO_FRQ` | `/auto` 주기 | 1 Hz | 200 Hz (5 ms) |
| `DHT_BOOT` / `DHT_INTV` | DHT11 부팅 대기 / 측정 간격 (clk) | 100 M / 200 M (1 s / 2 s) | 300 k / 500 k (3 ms / 5 ms) |
| `BLINK_HALF` | SR04 근접 경고 점멸 반 주기 | 25 M (250 ms) | 25 k (250 us) |
| `BAUD` | UART (DUT baud tick + PC 모델) | 9600 | 115200 |
| `SR_TICK` | SR04 1 us tick | 100 | 10 (센서 시간 전부 10 배 빠르게, 거리 계산 결과는 같음) |
| `DHT_TICK` | DHT11 1 us tick | 100 | 10 |

4 kHz (디바운스 · FND 스캔) 는 줄이지 않습니다. B4 길게 누름은 3 s 대신 0.5 s (원리 같음).

## 콘솔 읽는 법

```
[  12.345678 ms] [BEGIN  ] D3  max value wrap (up)       ← 시나리오 시작 (plan / expect 같이 찍힘)
[  12.400000 ms] [OK     ] D3-1   ... | exp ... | got ...  ← 검사 1 건
[  12.400000 ms] [FAIL   ] ...                             ← 기대와 다름
[  12.400000 ms] [ISSUE  ] ...                             ← tb_scenario.md 2 장 ⚠ 항목 : 스펙과 다르게 동작 (FAIL 과 따로 셈)
[  12.400000 ms] [PRELOAD] stopwatch <- 23:59:59.98        ← TB 가 카운터에 값을 직접 넣음 (경계 바로 앞으로)
[  12.400000 ms] [WARN   ] tx line "..." != go snapshot     ← UART 줄이 보낸 순간 값과 다름
```

맨 앞 시각 = 파형 *Go To Time*. 마지막 요약에 시나리오별 PASS / FAIL, UART 줄 무결성, x/z 여부, FAIL · ISSUE ID 목록.

## 모델 · 모니터 요약

| 부분 | 동작 |
|---|---|
| 버튼 | `press` (물리 핀, 디바운서 통과) / `pulse_phy` (디바운서 출력 `w_phy_btn_*` 에 1 clk, 정밀 타이밍용) |
| PC UART | `uart_send` · `uart_line` (+CR) · `mod` · `ubtn` · `uget`, baud 오차 `uart_err` |
| UART 수신 모니터 | `tx` 를 줄 단위로 모음. 줄마다 sender 가 go 를 받은 순간의 값 (스냅샷) 과 비교 |
| SR04 모델 | trig ↓ + 0.5 ms 뒤 echo 를 `sr_w_us` 동안. `SR_NONE` echo 없음, `SR_MANUAL` TB 가 echo 직접 |
| DHT11 모델 | `pullup` + 시작 LOW 감지 → 응답 + 40 비트. 비트 HIGH 길이 · 몇 비트 뒤 끊기 · 체크섬 오프셋 · 무응답 · LOW 고착 |
| FND | `fnd_read` : `fnd_com` / `fnd_font` 8 칸 (2 ms) 을 모아 `"12.34"` `"Err1"` `"----"` 같은 문자열로 |
| 프리로드 | `preload_sw` · `preload_wt` : 카운터 레지스터 force 1 clk (경계값 바로 앞으로) |
