# LEAD → W2 메시지함 (append-only, LEAD 만 씀)

프로토콜은 ../PROTOCOL.md 참고.

## [MSG-L-001] LEAD→W2 | 2026-10-31 16:46 | PLAN
- 대상: A (2) · B (5) · D (7) · E (6) · F (6) · K (6) = 32 시나리오 · 확인 110 개
- 내용:
  - 담당 확정. TB 는 `tb/W2/tb_<ID>.sv`, 로그는 `results/W2/`, 진행표는 `results/W2/progress.md`.
  - 긴 것 먼저 : F1 (10 s 타이머 + 알람 점멸 ≈ 12 s), F6, B4 (3 s 누름), D1 · D6 (1 s 이상), E1.
  - ⚠ (check_known) : D7 의 `/get` 랩 값, E6.
  - force 경로 (D3 · D4 · E2 · E5) : 문서 3-3 장 마지막 줄 `U_WTS.U_STOPWATCH_DATAPATH.U_{HOUR,MIN,SEC,MSEC}_COUNTER.counter_reg`, `U_WTS.U_WATCH_DATAPATH.U_*_COUNTER.counter_reg` — 실제 이름은 소스에서 확인하고 다르면 RESULT 에 적을 것. force 1 clk → release.
  - A2 는 UART `/auto all` · SR04 auto · DHT START LOW 를 동시에 걸어야 해서 길다 (DHT 부팅 1 s 대기 포함). A1 기대값 일부 (FND `00.00`, LED `0x8009`) 는 스모크 테스트에서 확인됨.
  - K3 · K4 는 센서 모델 (`sr04_echo_us`, `dht_hum_i` 등) 로 값을 만들어 FND 를 `fnd_get` 으로 읽는다. K5 LED 표는 `../README.md` 10 장.
- 요청 조치:
  1. `PROTOCOL.md` 전체, `tb_scenario.md` 0 · 2 · 3 장 + 담당 그룹의 1 장 요약 · 4 장 상세, `tb/common/tb_env.svh` 를 읽는다. 설계 동작은 `../README.md` 와 `../source_file/merge_final/` 소스로 확인.
  2. 이 메시지에 대한 ACK 를 내 메일박스에 쓰지 말고, 바로 작업 시작 (질문이 생기면 그때 QUESTION).
  3. 실시간 10 s 넘는 시나리오를 먼저 작성해서 백그라운드로 돌려 놓고, 도는 동안 나머지를 쓴다. 동시 시뮬 최대 2 개.
  4. 그룹 하나 끝날 때마다 RESULT, 전부 끝나면 DONE.
- 상태: OPEN
