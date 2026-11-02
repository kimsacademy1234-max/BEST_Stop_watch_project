# tb_merge_final_top — 전체 동작 시나리오 TB 가이드

`merge_final_top` (v2) 을 **보드 핀만** 구동해서 버튼 · 스위치 · UART 명령 → FND · LED · UART 응답까지 한 번에 확인하는 TB.

| 파일 | 내용 |
|---|---|
| `tb_merge_final_top.sv` | TB (시나리오 S01 ~ S20, 센서 모델, PC 수신 모델, FND 해석, PASS / FAIL 로그) |
| `tb_merge_final_top_behav.wcfg` | 파형 설정 (그룹 G01 ~ G10) |
| `tb_merge_final_top.md` | 이 문서 |

> **상태** : TB 는 작성만 했고 **아직 시뮬레이션으로 돌려 보지 않음**. 기대값은 RTL (`merge_final_v2`) 코드를 읽고 계산한 값.

---

## 1. 실행 (Vivado)

1. **Design Sources** : `FINAL/source_file/merge_final_v2/` 아래 `.v` · `.sv` 전부 (하위 폴더 `IP` `UART` `SR04` `DHT11` `WTS` `FND_LED` 포함)
2. **Simulation Sources** : `tb_merge_final_top.sv` 하나 → **Set as Top**
   - 같은 폴더의 예전 `tb_decoder.sv` · `tb_uart_decoder_behav.wcfg` 는 포트가 맞지 않으므로 **시뮬 소스에서 뺄 것**
3. Run Simulation → **Run All** (끝나면 `$finish` 로 멈춤, 시뮬 시간 약 1.4 s)
4. File → Open Waveform Configuration → `tb_merge_final_top_behav.wcfg`
5. Tcl Console 맨 아래 **RESULT** 표에서 FAIL 줄을 찾고, 그 시각으로 파형 이동 (Go To Time)

---

## 2. 시간 단축 (`FAST_SIM`)

TB 맨 위 `` `define FAST_SIM `` 이 켜져 있으면 TB 의 `defparam` 으로만 시간을 줄인다 (**RTL 파일은 그대로**). 주석 처리하면 보드와 같은 시간.

| 대상 | 보드 | 시뮬 (FAST_SIM) | 비율 |
|---|---|---|---|
| 시계 · 스톱워치 · 타이머 1/100 초 | 10 ms | 100 us | **100 배** (1 s = 10 ms) |
| UART `/auto` 전송 주기 | 1 Hz | 50 Hz (20 ms) | 50 배 |
| DHT11 부팅 대기 | 1 s | 1 ms | |
| DHT11 측정 간격 | 2 s | 50 ms | |
| DHT11 시작 LOW | 18 ms | 2 ms | |
| SR04 측정 주기 | 60 ms | 10 ms | |
| SR04 echo 대기 (없으면 Err1) | 30 ms | 5 ms | |
| SR04 echo 끝난 뒤 대기 | 10 ms | 2 ms | |
| SR04 echo 고착 판정 (Err3) | 50 ms | 10 ms | |
| 버튼 디바운스 · UART 9600 · FND 스캔 | | **그대로** | 1 |

- 시계는 100 배라서 **시뮬 0.6 s = 시계 1 분**. 그래서 시계 화면 기대값은 분 자리를 `??` 로 둔다.
- 시계 · 타이머 화면의 가운데 점은 0.5 초 (= 5 ms) 마다 깜빡이므로, 기대값에 `.` 이 없으면 점은 무시하고 비교한다.

---

## 3. 파형 그룹 (wcfg)

| 그룹 | 이름 | 무엇을 보나 |
|---|---|---|
| **G01** | SCENARIO / CHECK | `SCN_NUM` · `SCN_NAME` = 지금 시나리오 번호 · 이름. `CHK_CMD` · `CHK_EXPECT` · `CHK_GOT` · `CHK_RESULT` (WAIT → PASS / FAIL) · `CHK_DELAY_US` |
| **G02** | TEXT | `CMD_TEXT` 보낸 명령, `PC_TEXT` FPGA 가 보낸 마지막 줄, `FND_TEXT` FND 4 자리 글자 (모두 ASCII) |
| **G03** | BOARD IN | `rst` · 버튼 4 개 · 스위치 sw0 ~ sw6 · sw15 |
| **G04** | BOARD OUT | `FND_AN` 지금 켜진 자리 (AN0 ~ AN3) · `FND_NUM` 그 자리 글자 (ASCII) · `fnd_com` · `fnd_font` · `led` |
| **G05** | MODE | `o_uart_mode` (1 = UART 제어 중), `o_module_control_bit` [6:0], `i_disp_sel` (0 WTS · 1 거리 · 2 온습도), `/btn` 출력 4 개 |
| **G06** | UART RX | `rx` → 디코더 `i_ascii` (받은 글자) · `o_handshake` · `o_error` · `o_ascii` (명령 문자열) |
| **G07** | UART TX | 컨트롤러 `o_sender_go` · `o_send_sel` · `o_sender_data` → sender `o_send_busy` · `o_tx_push_data` (글자) → `tx` |
| **G08** | WTS | WTS 로 들어간 버튼, 화면 선택 `o_sel_*`, 화면 값 `o_disp_*`, 타이머 `o_tm_run` · `o_tm_alarm` |
| **G09** | SR04 | SR04 로 들어간 버튼, `o_auto_en`, `trig` · `echo`, `o_done`, `o_distance` (cm), `o_err` · `o_status` |
| **G10** | DHT11 | DHT11 로 들어간 버튼, `dht11_io`, `o_done`, `o_humidity` · `o_temperature`, `o_dashes` · `o_status`, `o_led` |

### 파형 읽는 순서

1. **G01** `SCN_NUM` 이 바뀌는 곳 = 시나리오 시작. 아래 4 장 표에서 그 번호를 찾는다.
2. 같은 G01 의 `CHK_RESULT` 가 `WAIT` → `PASS` / `FAIL` 로 바뀌는 곳 = 확인 1 건이 끝난 시각. `CHK_EXPECT` 와 `CHK_GOT` 를 비교.
3. 4 장 표의 **볼 그룹** 을 펼쳐서 원인 확인 (예 : 거리 값이 이상하면 G09 의 `echo` 길이 · `o_distance`).

---

## 4. 시나리오 (S01 ~ S20)

- 확인 방법 : `FND` = FND 글자가 기대값이 되는지, `UART` = PC 가 받은 줄, `NOW` = 그 순간 값
- 기대값의 `?` = 아무 글자 1 개
- 관련 = `FINAL/sim_file/tb_scenario.md` 의 영역 (A 리셋 · C 모드 · D 스톱워치 · E 시계 · F 타이머 · G UART 수신 · H UART 컨트롤 · I SR04 · J DHT11 · K 표시)

| 번호 | 이름 (`SCN_NAME`) | 하는 일 | 기대 결과 | 볼 그룹 | 관련 |
|---|---|---|---|---|---|
| **S01** | reset | `rst` 1 us | UART 제어 0, 화면 WTS, LED `8009` (시계 · 초.1/100초 · 오후, 시계 시작값 12:00), `tx` = 1 | G03 · G04 · G05 | A |
| **S02** | switch : watch hh.mm 12h/24h | sw1 = 1 → sw3 = 1 → 둘 다 0 | FND `12.00`. 12 시라 12 / 24 시간 모두 `12.00` 이므로 **오후 LED (led[15])** 로 구분 : 12 시간 1 → 24 시간 0 | G03 · G02 · G04 | E · K |
| **S03** | switch : distance screen | sw5 = 1 | 화면 거리, FND `000.0` (측정 전) | G05 · G02 | C · I |
| **S04** | switch : distance btn R | 물리 R (거리 100 cm) | FND `100.0` | G03 · G09 · G02 | I |
| **S05** | switch : temp screen + btn R | sw6 = 1 → 물리 R (55 %, 24 ℃) | FND `----` (측정 전) → `55.24` | G10 · G02 | J |
| **S06** | UART /mod dist (switch off) | `/mod dist` → sw5 · sw6 = 0 | FND `100.0` (마지막 값), UART 제어 1, **스위치를 내려도 화면 거리 유지** | G05 · G06 | C |
| **S07** | UART /btn R (35 cm) | `/btn R` | FND `035.0` | G05 · G09 | H · I |
| **S08** | UART /btn U auto on (250 cm) | `/btn U` | 자동 측정 켜짐 (`o_auto_en` = 1), FND `250.0` | G09 | I |
| **S09** | SR04 error Err1 Err2 Err3 | 센서 모델 : echo 없음 → 30 ms (범위 초과) → 1 고정 → 정상 | FND `Err1` → `Err2` → `Err3` → `250.0` | G09 (`echo` · `o_status`) · G02 | I |
| **S10** | UART /get distance | `/get` (정상) → echo 없음 → `/get` → 정상 | PC `250cm` → FND `Err1` → PC **`Err 1`** (v2) → FND `250.0` | G07 · G02 | H · I |
| **S11** | UART /btn U auto off | `/btn U` | `o_auto_en` = 0 | G09 | I |
| **S12** | UART /mod temp + /get | `/mod temp` → `/get` | FND `55.24`, PC `55%24C` | G05 · G07 | H · J |
| **S13** | DHT11 error + new value | 응답 없음 + `/btn R` → `/get` → 체크섬 틀림 + `/btn R` → 정상 60 % 25 ℃ + `/btn R` → `/get` | FND `Err1` → PC **`Err 1`** → FND `Err3` → FND `60.25` → PC `60%25C` | G10 · G02 | J |
| **S14** | DHT11 auto on / off (LED3) | `/btn U` 두 번 | LED[3] 1 → 0 | G10 · G04 | J · K |
| **S15** | UART /auto dis / tem / all / off | `/auto dis` → `/auto tem` → `/auto all` → `/auto off` | PC `250cm` → `60%25C` → 시간 줄 (`??:??:??.??`) 과 `60%25C` → off 뒤 60 ms 동안 줄 없음 | G07 · G02 | H |
| **S16** | wrong command -> ERROR | `/gxt` | PC `ERROR` | G06 (`o_error`) · G07 | G |
| **S17** | UART watch /set 24h 12h | `/mod w_hm` → `/set 24h` → `/set 12h` | FND `12.??`, 오후 LED (led[15]) 1 → 0 → 1 | G05 · G02 · G04 | E |
| **S18** | UART stopwatch run/stop/clear | `/mod s_ms` → `/btn R` → 20 ms → `/btn R` → `/get` 두 번 → `/btn L` → `/get` | PC `00:00:0?.??` (약 2.7 s), 두 번째 `/get` 이 **같은 값** (멈춤), 지운 뒤 `00:00:00.00` | G08 · G07 | D |
| **S19** | UART timer 10 s + alarm | `/mod t_ms` → `/btn U` (+10 초) → `/get` → `/btn L` (시작) → 120 ms → `/btn L` | PC `00:00:10.00`, 120 ms 뒤 `o_tm_alarm` = 1 (LED 전체 점멸), 버튼 뒤 0 | G08 · G04 | F |
| **S20** | reset during /auto all | `/auto all` → 30 ms → 리셋 버튼 | UART 제어 0 (스위치로 돌아옴), 화면 WTS, 리셋 뒤 60 ms 동안 줄 없음 | G05 · G07 · G03 | A |

### v1 과 다른 기대값 (v2 기준)

| 상황 | v1 | **v2 (이 TB)** |
|---|---|---|
| 거리 오류 `/get` | `000cm` · `400cm` 등 숫자 | `Err 1` ~ `Err 3` |
| 온습도 오류 `/get` | 마지막 정상값 | `Err 1` ~ `Err 3` |
| 온습도 첫 측정 전 `/get` | `00%00C` | `--%--C` |

---

## 5. 콘솔 로그 읽는 법

```
[  12.345 ms] ======== S07 UART /btn R (35 cm) ========
[  12.345 ms] PC -> "/btn R"
[  19.640 ms] S07 #12 PASS | CMD /btn R     | sent    19.640 ms | expect FND  "035.0"     | got "035.0"     at    28.210 ms (delay    8.570 ms)
[  45.000 ms] PC <- "250cm"
```

| 칸 | 뜻 |
|---|---|
| `S07 #12` | 시나리오 번호 · 확인 번호 |
| `PASS` / `FAIL` | 결과 |
| `CMD` / `BTN` / `WAIT` / 이름 | UART 명령 / 보드 버튼 / 아무것도 안 보내고 기다림 / `NOW` 확인 이름 |
| `sent` | 명령을 다 보낸 시각 (버튼은 뗀 뒤 5 ms) |
| `expect` | `FND` · `UART` · `NOW` 와 기대값 |
| `got ... at` | 실제 값과 그 값이 나온 시각 |
| `delay` | 나온 시각 − 보낸 시각. **음수** = 명령을 다 보내기 전에 결과가 나옴 (예 : `ERROR`) |
| `timeout` | FAIL 일 때 기다린 시간, `got` 은 마지막으로 본 값 |

맨 끝 **RESULT** 에 모든 확인 줄과 `checks N : PASS a, FAIL b` 가 다시 나온다.

---

## 6. 시나리오 고치기 · 추가하기

TB 맨 아래 `SCENARIO` 블록에서 `scenario(번호, "이름");` 로 시작하고 아래 태스크를 쓴다.

| 태스크 | 하는 일 |
|---|---|
| `uart_send("/mod dist");` | 명령 1 줄 (CR 자동) |
| `press("R");` · `hold("U", 300);` | 보드 버튼 (R L U D, C = 리셋) |
| `sw5 = 1;` … | 스위치 |
| `wait_ms(n);` | 기다리기 |
| `cmd_fnd(cmd, exp, ms)` · `cmd_pc(cmd, exp, ms)` | 명령 보내고 FND / UART 줄 확인 |
| `btn_fnd(b, exp, ms)` | 보드 버튼 누르고 FND 확인 |
| `wait_fnd(exp, ms)` · `wait_pc(exp, ms)` | 아무것도 안 보내고 기다리며 확인 |
| `check_now(이름, 값, 기대)` | 지금 값 확인 (`b2s(1비트)`, `scr_name()`, `$sformatf("%04h", led)` 등) |
| `sr04_cm = 123;` · `dist_err(0~3);` | SR04 모델 값 · 오류 (1 echo 없음 · 2 범위 초과 · 3 echo 고착) |
| `dht_hum = 55; dht_temp = 24;` · `dht_err(0~3);` | DHT11 모델 값 · 오류 (1 응답 없음 · 2 중간 끊김 · 3 체크섬) |
| `show();` · `report();` | 지금 상태 출력 / 결과 표 |
