# HC-SR04 초음파 거리 측정 컨트롤러 (10/28 ~ 10/29 수업 실습, 정보윤)

btnR 을 누를 때마다 HC-SR04 로 거리를 한 번 재서 FND 에 cm 로 표시한다. Basys-3 보드 동작 · ILA 확인까지 함.

## 구조

```
btnR → btn_debounce → sr04_controller (i_start)
                       ├ o_trig ───────────────→ HC-SR04 TRIG (JA1)
                       ├ i_echo ←─────────────── HC-SR04 ECHO (JA2)
                       ├ o_tick_en · o_tick_clr → tick_gen_1us → i_us_tick (1 us)
                       └ o_distance[8:0] → fnd_controller ({5'b0, distance}) → FND
```

- 상태 : IDLE → START (trig 11 µs) → WAIT (echo 상승 대기) → DIST (echo 동안 58 µs 마다 cm + 1) → STOP (echo 끝 뒤 10 ms) → IDLE
- 거리 = echo 폭 ÷ 58 µs (나눗셈 없이 58 µs 마다 1 cm 씩 셈), 0 ~ 400 cm → 9 비트
- tick 생성기는 IDLE 에서 clear, 측정 중 enable → START 진입 후 첫 tick 이 정확히 1 µs 뒤 (trig 11.01 µs)
- echo 는 FF 2 개 싱크로나이저 (c_echo_sync1 → c_echo_sync2) 를 거쳐 FSM 이 봄
- 예외 처리 : echo 가 30 ms 안에 안 오면 timeout (거리 0), 400 cm 넘으면 범위 밖 (거리 0), 범위 밖으로 끝나도 STOP 에서 echo 가 내려갈 때까지 기다린 뒤 10 ms

## 파일

`src/`
- `top_sr04.v` : Top. 포트 17 개 = clk · rst · btnR · echo · trig · fnd_com[3:0] · fnd_font[7:0]
- `sr04_controller.v` : FSM + 카운터 (c_ = 현재 · n_ = 다음 짝). parameter `TRIG_US 11 · CM_US 58 · MAX_CM 400 · STOP_US 10000 · TIMEOUT_US 30000`
- `tick_gen_1us.v` : 100 MHz → 1 µs tick, `i_enable` · `i_clear`
- `btn_debounce.v` · `fnd_controller.v` : 이전 실습 모듈 그대로

`sim/`
- `tb_sr1_tick.v` : tick_gen_1us 단위 TB (enable 0 · 첫 tick 100 클럭 · 폭 · enable 끄기 · 도중 clear)
- `tb_sr2_ctrl.v` : sr04_controller 단위 TB (TB 가 센서 역할). trig 폭 · 10 / 100 / 400 cm · done 1 클럭 · 측정 중 start 무시 · timeout · 36 ms 범위 밖 · STOP 중 start 무시 · echo 끝 → 다음 trig 10 ms 이상
- 둘 다 `TOTAL MISMATCH = 0` (xsim)

`constrs/Basys-3-Master.xdc` : clk W5 · rst U18 (btnC) · btnR T17 · trig J1 (JA1) · echo L2 (JA2) · FND
- 센서 배선 : VCC → JA 6 번 (3.3 V), GND → JA 5 번

`ip/ila_0.xci` : ILA 설정 (probe 5 개 : o_trig · i_echo · c_echo_sync1 · c_echo_sync2 · c_state[2:0], 깊이 131072)
- `sr04_controller.v` 33 번 줄에 `ila_0 U_ILA` 인스턴스가 있음
- **ILA 없이 쓰려면** 그 인스턴스 (33 ~ 40 줄) 를 지우거나 주석 처리. 쓰려면 IP Catalog → ILA 를 위 설정으로 만들거나 이 xci 를 Add Sources 로 추가
- TB 시뮬레이션 때도 ILA 인스턴스는 주석 처리하는 게 안전

## ILA 보드 파형 (10/29)

`ila/README.md` : 상태 천이 5 개 · trig 11.01 µs · echo → DIST 3 / 2 샘플 · 거리 3 점 (ILA echo 폭 ÷ 58 = FND) 정리 + 캡처 13 장

## 보드 결과 (10/29)

| 확인 | 결과 |
|---|---|
| 구현 | WNS +3.893 ns, WHS +0.055 ns, 우리 설계 LUT 150 · FF 83 (ILA 제외) |
| trig 폭 (ILA) | 1101 샘플 = 11.01 µs |
| echo → 상태 반영 | echo → sync1 → sync2 → 상태 한 샘플씩 (상승 · 하강 같음) |
| 거리 (ILA echo 폭 ÷ 58 vs FND) | 174.6 µs → 3 / 640.3 µs → 11 / 1,222.3 µs → 21 — 세 번 모두 일치 |

- Methodology TIMING-17 10 개는 btn_debounce · fnd_controller 가 FF 출력 (1 MHz · 800 Hz) 을 클럭으로 쓴 곳. sr04_controller · tick_gen 은 tick 인에이블 방식이라 없음
- 사용법 : btnC 로 리셋 → 센서 앞에 물체 → btnR 한 번 → FND 에 cm. FND 0 = echo 안 옴 또는 400 cm 초과
