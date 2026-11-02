# UART sender — U_CONTROL 이 고른 24 비트 숫자를 글자로 바꿔 TX FIFO 에 넣는 모듈 (10/30)

팀 프로젝트 2 의 응답 쪽. U_CONTROL 이 `send_go` 를 주면 그 순간의 형식 번호 · 숫자를 잡아 두고, 한 클럭에 한 글자씩 TX FIFO 에 넣는다.

## 결과

- 단위 · Top TB 3 개 모두 **TOTAL MISMATCH = 0** (Vivado 2022.2 xsim)
- 13 글자 응답 : sender busy **13 클럭 = 130 ns**, PC 가 다 받는 시간 **13.49 ms** (9600 bps)
- 5 종 연달아 54 글자 : busy 합 54 클럭 (TX FIFO 64 칸이라 기다림 없음), PC 가 다 받는 시간 56.2 ms

## 포트 (U_CONTROL 과 연결할 것)

| 포트 | 방향 | 폭 | 뜻 |
|---|---|---|---|
| `i_send_go` | in | 1 | 보내 줘 (1 클럭 펄스). **`o_send_busy == 0` 일 때만 줄 것** — busy 중 (마지막 글자 넣는 클럭 포함) 에 온 go 는 무시됨 |
| `i_send_sel` | in | 3 | 형식 : 0 스톱워치 · 1 시계 · 2 타이머 · 3 거리 · 4 온습도 · 7 ERROR (5 · 6 도 ERROR) |
| `i_send_data` | in | 24 | 숫자 (아래 비트 배치) |
| `o_send_busy` | out | 1 | 보내는 중 (= TX FIFO 에 글자 넣는 중) |
| `i_tx_full` · `o_tx_push` · `o_tx_push_data[7:0]` | — | — | TX FIFO 쪽 (Top 안에서 연결) |

## send_data 비트 배치 (제안 — 맞춰서 확정 필요)

| 형식 | 배치 | 응답 (+ CR LF) |
|---|---|---|
| 시간 3 종 | `{hour[4:0], min[5:0], sec[5:0], msec[6:0]}` (msec = 1/100 초 0 ~ 99) | `12:34:56.78` (13 글자) |
| 거리 | `{15'b0, cm[8:0]}` | `123cm` (7 글자, 3 자리 앞을 0 으로) |
| 온습도 | `{8'b0, hum[7:0], temp[7:0]}` (정수만) | `45%25C` (8 글자) |
| ERROR | 안 씀 | `ERROR` (7 글자) |

범위 밖 값 (시 24 이상, 1/100 초 100 이상, 거리 401 이상, 습 · 온 100 이상) 은 숫자가 아닌 글자가 나감 — U_CONTROL 쪽에서 범위를 지켜 주는 것으로 가정.

## 파일

- `src/sender_char_mux.v` : 형식 번호 · 글자 번호 → 그 자리 ASCII (조합 회로)
- `src/uart_sender.v` : FSM (IDLE · SEND) + 잡아 두는 레지스터 + 글자 MUX
- `src/sender_tx_top.v` : 시험용 Top = sender + TX FIFO (DEPTH 64) + uart_tx + baud_tick_gen
  - fifo · uart_tx · uart.v (baud_tick_gen) · uart_rx 는 `boyun/uart_fifo_ascii_hw_20261028/` 의 것과 같음
- `sim/tb_sd1_char.v` : 글자 MUX — 형식 4 종 14 줄 (경계값 0 · 최대 · ERROR 5 · 6 · 7)
- `sim/tb_sd2_sender.v` : sender — 13 시나리오 (형식 4 종, TX FIFO full 기다림 (중간 · 처음부터 · 마지막 글자 직전), busy 중 go 무시, 보내는 도중 데이터 변경, 5 종 연달아, 마지막 글자 클럭의 go 무시, 도중 rst, 랜덤 200 줄 + full 무작위)
- `sim/tb_sd3_top.v` : Top — PC 쪽에서 tx 선을 받아 문자열 비교 (13 글자 · 54 글자)
