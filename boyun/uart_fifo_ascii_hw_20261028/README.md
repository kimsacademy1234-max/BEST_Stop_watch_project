# UART ASCII 명령 디코더 · sender (10/27 숙제, 정보윤)

PC 에서 UART 로 보낸 문자로 스톱워치를 제어하고, `s` 를 받으면 고정 문자열 "OK" 를 PC 로 돌려보낸다. 시뮬레이션까지 (구현 · 보드는 안 함).

| 문자 | hex | 동작 |
|---|---|---|
| `r` | 72 | 스톱워치 run / stop 토글 (btn_R 과 같음) |
| `c` | 63 | clear (btn_L 과 같음) |
| `u` | 75 | up / down 모드 (btn_U 와 같음) |
| `s` | 73 | "OK" (4f 4b) 를 PC 로 송신 — 스톱워치 시간이 아니라 sender 안 상수 |

## 구조

```
PC → UART_RX → FIFO_RX → ascii_decoder ─ r · c · u (1 클럭 펄스) → stopwatch_watch (버튼 펄스와 OR)
                    ↑ o_pop            └ s → ascii_sender ─ push "O" "K" → FIFO_TX → UART_TX → PC
```

- 10/27 수업 판에서 바뀐 점 : FIFO_RX → FIFO_TX 자동 루프백을 끊음. FIFO_RX pop 은 디코더가, FIFO_TX push 는 sender 가 준다. 문자 표시용 fnd_controller 는 뺌.

## 파일

`src/uart_ascii/`
- `uart_fifo_ascii.v` : Top. 아래 4 블록 연결 (clk · rst 이름은 XDC 와 같게 그대로)
- `uart.v` (모듈 `uart_fifo_loopback`) : UART_RX · FIFO_RX · FIFO_TX · UART_TX. 바깥 포트 `i_rx_pop` · `o_rx_pop_data` · `o_rx_empty` · `i_tx_push` · `i_tx_push_data` · `o_tx_full`
  - `o_rx_empty` 는 이름과 달리 값이 `~FIFO_RX empty` (1 = 데이터 있음) — 디코더 enable 로 씀
  - FIFO_TX pop = `~tx_busy`, tx_start = `~FIFO_TX empty`
- `uart_ascii_decoder.v` (모듈 `ascii_decoder`) : `o_pop = i_enable` (조합), `o_key_X = i_enable & (i_ascii == 상수)`
- `ascii_sender.v` : FSM IDLE · SEND. IDLE 에서 `i_key_status` → SEND, SEND 에서 FIFO_TX 가 안 찼으면 한 클럭에 한 바이트 push ("O" → "K") → IDLE
- `uart_tx.v` : busy 타이밍 수정 (아래)
- `uart_rx.v` · `fifo.v` : 수업 판 그대로

`src/stopwatch/` : 미니프로젝트 제출 판 그대로 + `stopwatch_watch.v` 에 키 입력 3 개 추가
- `w_sw_btn_R = (w_btn_R & w_sel_sw & ~w_btn_multi) | i_key_run_stop` (L · U 도 같은 식)

## 디코더 로직 요점

- FIFO 는 show-ahead (pop 전에 맨 앞 바이트가 pop_data 에 보임). `i_enable = ~empty` 가 1 인 클럭에 `i_ascii` 를 비교해서 명령을 낸다.
- 같은 클럭에 `o_pop = 1` → 다음 엣지에 rptr + 1 → empty 1 → enable 0. 그래서 명령이 정확히 1 클럭 (버튼 디바운서 펄스와 같은 폭) 이 된다.
- pop 을 레지스터로 한 클럭 늦게 주면 enable · 명령이 2 클럭이 돼서 `r` 한 번에 토글이 두 번 → 제자리. 그래서 조합 pop 을 쓴다.

## uart_tx 수정 (2 줄)

수업 판 uart_tx 는 busy 를 START 상태에서 1 로 올려서, TX 가 바이트를 잡는 엣지에 busy 가 아직 0 이다. FIFO_TX pop = ~busy 라 pop 이 한 번 더 나가서 2 번째 바이트 (K) 가 사라졌다 (PC 가 "O" 만 받음).

```verilog
IDLE: if (tx_start) begin ... n_state = START; tx_busy_next = 1'b1; end   // 추가 1
STOP: if (b_tick && b_tick_cnt_reg == 15) begin n_state = IDLE; tx_busy_next = 1'b0; end   // 추가 2
```

두 줄 다 필요하다. 1 만 넣으면 busy 가 안 내려가서 FIFO_TX 의 K 가 안 빠지고 계속 반복 송신된다.

## 시뮬레이션 결과 (Vivado 2022.2 xsim)

- loopback 수정 판 : 'A' 수신 뒤 tx 로 안 돌아감, 바깥 push 4b 만 PC 로 — MISMATCH 0
- 디코더 단독 : r c u s 1 R → 명령 각 1 클럭, '1' · 'R' 에는 명령 없음 — MISMATCH 0
- Top + 스톱워치 : r RUN · r STOP · u down · c clear · btn_R RUN — MISMATCH 0
- sender : `s` → PC 4f 4b, 그 뒤 추가 송신 없음 — MISMATCH 0
- 연속 256 바이트 (간격 0) : 명령 누락 0, FIFO_RX full 0
- 한계 : `s` 를 간격 없이 6 번 보내면 12 바이트 중 10 바이트만 옴 (SEND 중 들어온 `s` 는 무시)
- 아직 안 한 것 : 's' 에 스톱워치 시간 보내기 (sender 에 시간 입력 + 아스키 변환 필요)
