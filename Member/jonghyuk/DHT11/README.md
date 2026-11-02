# DHT11 온습도 컨트롤러 (Basys-3)

btnR 을 누르면 DHT11 에서 습도 · 온도를 한 번 읽어 FND 에 `습도.온도` 로 표시한다 (예 : `55.24` = 55 %RH, 24 ℃).
`boyun/sr04_controller_20261029` 의 모듈 · 코드 스타일 (c_ / n_, i_ / o_, fnd_com · fnd_font, ILA 를 컨트롤러 안에) 을 기준으로 만들었다.

## 구조

```
btnC → reset_sync → (모든 모듈 rst)
btnR → btn_debounce → dht11_core (i_start)
                       ├ 요청 관리 : 1 s 부팅 대기 · 2 s 간격 · i_auto_en
                       ├ tick_gen_1us → dht11_controller (FSM)
                       ├ i_dht11 · o_dht_oe ←→ (top 3상태 버퍼) ←→ DHT11 DATA (JA1, 풀업)
                       └ o_humidity · o_temperature · o_valid · o_status · o_done
dht11_manager → fnd_data = 습도 x 100 + 온도 → fnd_controller → FND
             → led[0] 측정 중 · led[1] 오류 · led[2] 정상값
```

- 상태 : IDLE → START (LOW 18 ms) → WAIT (선 놓음 30 us) → SYNC_L (80 us) → SYNC_H (80 us) → (DATA_SYNC → DATA_BIT → BIT_DEC) x 40 → STOP → IDLE
- 비트 : DATA_BIT 의 HIGH 길이를 us 로 세서 40 us 넘으면 1 (0 = 26~28 us, 1 = 70 us)
- 데이터 40 비트, MSB 먼저 : 습도 정수 · 습도 소수 · 온도 정수 · 온도 소수 · 체크섬 (앞 4 바이트 합의 하위 8 비트)
- 예외 : 센서 엣지를 200 us 안에 못 받으면 바로 IDLE, `o_valid = 0`. 체크섬 틀려도 `o_valid = 0`. 습도 · 온도는 마지막 정상값 유지, FND 는 `----`
- 데이터선 : FPGA 는 LOW 만 구동하고 나머지는 high-Z (top 에서 `assign dht11_io = w_dht_oe ? 1'b0 : 1'bz;`, 컨트롤러는 입력 `i_dht11` 과 구동 enable `o_dht_oe` 만 가짐). 입력은 FF 2 개 싱크로나이저 뒤 엣지 검출

## 파일

`src/`
- `top_dht11.v` : Top. 포트 = clk · rst (btnC) · btnR · dht11_io · fnd_com[3:0] · fnd_font[7:0] · led[2:0]
- `dht11_core.v` : **팀 통합용 IP**. tick_gen_1us + dht11_controller + 요청 관리 (부팅 1 s · 간격 2 s · 자동 측정). 입출력은 `doc/dht11_core_io.xlsx`
- `dht11_controller.v` : FSM (c_ / n_). parameter `START_US 18000 · WAIT_US 30 · TIMEOUT_US 200 · BIT1_US 40 · USE_ILA 1`. `o_status` (00 OK · 01 NO_RESPONSE · 10 TIMEOUT · 11 CHECKSUM), `o_state` 출력
- `dht11_manager.v` : 보드 표시용. 결과 → FND 표시값 · `----` · LED
- `tick_gen_1us.v` : 원본 그대로
- `btn_debounce.v` · `fnd_controller.v` : 원본 구조 그대로, 아래 고친 점만 다름
- `reset_sync.v` : btnC 리셋 해제를 클럭에 맞춤

`sim/`
- `tb_dht1_ctrl.v` : dht11_controller 단위 TB (TB 가 센서 역할). 시작 LOW 폭 · 응답 20 / 25 / 40 us · 소수 바이트 · 체크섬 오류 · 응답 없음 · 중간에 멈춤 · 복구 · 측정 중 start 무시
- `tb_dht3_core.v` : dht11_core TB. 부팅 대기 중 요청 기억 · done 뒤 busy · 간격 안 요청 · 자동 측정 3 번 (간격 검사) · status 01 / 10 / 11
- `tb_dht2_top.v` : top 통합 TB. 리셋 직후 `----` · 버튼 튐 · FND `55.24` 자리별 font · 간격 중 버튼 기억 · 오류 LED · 복구 · btnC 리셋
- 둘 다 마지막에 `TOTAL MISMATCH = N` 출력
- 시뮬레이션 시간을 줄이려고 TB 에서만 1 tick = 100 ns (실제 1 us), 시작 LOW 180 tick (실제 18000), 측정 간격 1 ms, FND 스캔 자리당 10 us 로 돌린다. 센서 모델도 같은 비율이라 비트 판단 (27 : 70, 기준 40) 은 실제와 같다. 보드용 기본값은 그대로
- top 파라미터 `TICK_F_COUNT · START_US · FND_SCAN` 은 시뮬레이션 전용, 보드에서는 기본값 사용

`constrs/Basys-3-Master.xdc` : 원본에서 trig/echo 대신 `dht11_io` (J1 = JA1, PULLUP), led[2:0] 추가, 비동기 입력 false path · 출력 max delay 추가

## 원본 대비 고친 점

| 파일 | 고친 점 |
|---|---|
| `btn_debounce.v` | 분주 출력을 클럭으로 쓰지 않고 1 클럭 tick (enable) 으로. 샘플 간격 1 us → 1 ms (8 샘플 = 8 ms, 실제 버튼 튐 제거). 입력 싱크로나이저 추가 |
| `fnd_controller.v` | `clk_div_800hz` 분주 클럭 대신 800 Hz tick 으로 `counter_4` 구동 (TIMING-17 경고 없음). `i_dashes` (----) · `i_dp` (소수점) 입력 추가 |
| `reset_sync.v` (새로) | btnC 를 그대로 비동기 리셋으로 쓰지 않고, 걸 때는 바로 · 풀 때는 클럭에 맞춰 |
| `dht11_controller.v` | 데이터선 구동 enable (`c_oe`) 은 FF 출력 (글리치 없음). 싱크로나이저에 `ASYNC_REG`. ILA 는 `USE_ILA` 로 끄고 켬 (TB 에서 주석 처리 필요 없음) |

## 팀 통합

`dht11_core.v` · `dht11_controller.v` · `tick_gen_1us.v` 세 파일을 가져가서 top 에 `dht11_core` 하나를 올리고 3상태 버퍼 두 줄을 쓴다. 포트 · 파라미터 · 연결 방법은 `doc/dht11_core_io.xlsx`.

```verilog
dht11_core U_DHT11 (
    .clk(clk), .rst(rst), .i_start(w_dht_start), .i_auto_en(w_dht_auto),
    .i_dht11(w_dht_in), .o_dht_oe(w_dht_oe),
    .o_humidity(w_hum), .o_temperature(w_temp), .o_valid(w_dht_valid), .o_status(w_dht_status),
    .o_measuring(), .o_busy(w_dht_busy), .o_done(w_dht_done), .o_state()
);
assign dht11_io = w_dht_oe ? 1'b0 : 1'bz;
assign w_dht_in = dht11_io;
```

## 사용법

1. Vivado Tcl Console :
   ```tcl
   cd D:/work/vivado_direc/20261029_DHT11
   source create_project.tcl
   source run_sim.tcl
   source build.tcl
   ```
   `create_project.tcl` 은 `vivado/dht11_basys3.xpr` 를 만들고 ILA IP 도 생성한다. `run_sim.tcl` 은 새 파일을 프로젝트에 자동 추가하고 세 TB 를 돌려 `SIM PASS / FAIL`, `build.tcl` 은 비트스트림을 만들어 `output/` 에 복사 (타이밍 위반이면 중단).
2. Hardware Manager → Program Device : `output/top_dht11.bit` + `output/top_dht11.ltx`
3. btnC 로 리셋 → 1 초 뒤 btnR → FND 에 `습도.온도`. 2 초 안에 다시 누르면 2 초 지난 뒤 읽음

## 센서 배선

| DHT11 | Basys-3 |
|---|---|
| 1 VCC | JA 6 번 (3.3 V) |
| 2 DATA | JA 1 번 (J1), 5 kΩ 풀업 → 3.3 V |
| 3 | 연결 안 함 (NC) |
| 4 GND | JA 5 번 |

3 핀 모듈 (풀업 내장) 이면 VCC · DATA · GND 만 연결. XDC 에 내부 풀업도 켜 두었지만 약하므로 외부 풀업 권장.

## ILA

probe0 `c_oe` (1) · probe1 `i_dht11` (1) · probe2 `c_io_sync2` (1) · probe3 `c_state` (4), 깊이 131072 (100 MHz 에서 1.31 ms).
전체 통신 (약 4 ms) 이 한 화면에 다 안 들어가므로 트리거를 `c_state == 3` (SYNC_L) 에 걸면 응답 + 앞쪽 약 12 비트가 보인다. 뒤쪽 비트는 `c_state == 7` (BIT_DEC) 등으로 트리거 위치를 옮겨 본다.
상태 값 : IDLE 0 · START 1 · WAIT 2 · SYNC_L 3 · SYNC_H 4 · DATA_SYNC 5 · DATA_BIT 6 · BIT_DEC 7 · STOP 8

## 확인 결과

- 시뮬레이션 (xsim 2020.2) : `tb_dht1_ctrl` · `tb_dht2_top` 둘 다 `TOTAL MISMATCH = 0` (dht11_core 추가 전 기준. 추가 뒤 `run_sim.tcl` 로 세 TB 다시 확인)
- 보드 : Basys-3 + DHT11 실물로 측정값이 FND 에 정상 표시됨
- 합성 중 multi-driven net (Synth 8-6859) 경고 → 3상태 버퍼를 컨트롤러에서 top 으로 옮겨 해결
