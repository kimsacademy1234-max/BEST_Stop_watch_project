# LEAD → W1 메시지함 (append-only, LEAD 만 씀)

프로토콜은 ../PROTOCOL.md 참고.

## [MSG-L-001] LEAD→W1 | 2026-10-31 16:46 | PLAN
- 대상: C (8) · G (9) · H (12) = 29 시나리오 · 확인 113 개
- 내용:
  - 담당 확정. TB 는 `tb/W1/tb_<ID>.sv`, 로그는 `results/W1/`, 진행표는 `results/W1/progress.md` (TODO 로 채워 둠).
  - 긴 것 먼저 : H4 (`/auto` 5 종 × 3 s ≈ 15 s), H5 (`/auto all` 11 s), H6 · H7 · H3 (각 수 초). AUTO_FRQ 는 1 Hz 그대로.
  - ⚠ (check_known) : G7 · H2 · H7 · H9 (H9 는 개수 기록이라 `info` + 20 줄이면 PASS 판정 1 개).
  - G8 RX 물리층 : baud 오차는 `uart_tx_bit_ns`, 글리치 · break 는 `rx` 를 직접 구동, stop 0 은 `uart_send_byte(b, 0)`.
  - H12 · L2 류 정밀 타이밍은 `pulse_phy` (force) 사용. UART `/btn` 이 나오는 clk 는 `dut.w_uart_btn_*` 로 확인.
  - C 그룹 스위치는 `set_sw(7'b…)` 또는 개별 reg.
  - G1 "명령 24 개" 는 문서 4 장 G1 표 그대로 (명령마다 handshake 1 번 = 디코더 → 컨트롤러 신호, 이름은 `../source_file/merge_final/UART/uart_top.v` 에서 확인).
- 요청 조치:
  1. `PROTOCOL.md` 전체, `tb_scenario.md` 0 · 2 · 3 장 + 담당 그룹의 1 장 요약 · 4 장 상세, `tb/common/tb_env.svh` 를 읽는다. 설계 동작은 `../README.md` 와 `../source_file/merge_final/` 소스로 확인.
  2. 이 메시지에 대한 ACK 를 내 메일박스에 쓰지 말고, 바로 작업 시작 (질문이 생기면 그때 QUESTION).
  3. 실시간 10 s 넘는 시나리오를 먼저 작성해서 백그라운드로 돌려 놓고, 도는 동안 나머지를 쓴다. 동시 시뮬 최대 2 개.
  4. 그룹 하나 끝날 때마다 RESULT, 전부 끝나면 DONE.
- 상태: OPEN
