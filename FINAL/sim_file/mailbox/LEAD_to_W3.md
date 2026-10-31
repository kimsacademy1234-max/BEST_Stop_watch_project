# LEAD → W3 메시지함 (append-only, LEAD 만 씀)

프로토콜은 ../PROTOCOL.md 참고.

## [MSG-L-001] LEAD→W3 | 2026-10-31 16:46 | PLAN
- 대상: I (11) · J (14) · L (6) = 31 시나리오 · 확인 82 개
- 내용:
  - 담당 확정. TB 는 `tb/W3/tb_<ID>.sv`, 로그는 `results/W3/`, 진행표는 `results/W3/progress.md`.
  - 긴 것 먼저 : **L4 soak (30 s) · L1 · L5 (리셋 20 회)** — L 은 전체 40 s 라 제일 오래 걸림. 그 다음 J11 (7 s), J9, J6.
  - DHT11 은 리셋 해제 뒤 1 s 부팅 대기가 있어서 J 시나리오는 전부 최소 1 s 이상. 2 s 측정 간격도 실제 값.
  - ⚠ (check_known) : J14 (UART `:0%`). L6 은 `info` 로 스냅샷 기록 + 판정 1 개.
  - SR04 : 정상은 `sr04_mode = 1` + `sr04_echo_us`, 응답 없음 `sr04_mode = 2`, 고착 · 글리치 (I5 · I11) 는 `sr04_mode = 0` 으로 끄고 `echo` 직접 구동.
  - DHT11 : 체크섬 오류 `dht_chk_ofs`, 비트 경계 `dht_hi0_us` · `dht_hi1_us`, 끊김 `dht_stop_after`, 응답 없음 `dht_mode = 0`, 선 고착 `dht_stuck_low = 1`.
  - L5 · L4 랜덤은 시드 고정 (`$urandom(<seed>)` 한 번 호출 후 `$urandom`). 시드를 로그에 `info` 로 남길 것.
- 요청 조치:
  1. `PROTOCOL.md` 전체, `tb_scenario.md` 0 · 2 · 3 장 + 담당 그룹의 1 장 요약 · 4 장 상세, `tb/common/tb_env.svh` 를 읽는다. 설계 동작은 `../README.md` 와 `../source_file/merge_final/` 소스로 확인.
  2. 이 메시지에 대한 ACK 를 내 메일박스에 쓰지 말고, 바로 작업 시작 (질문이 생기면 그때 QUESTION).
  3. 실시간 10 s 넘는 시나리오를 먼저 작성해서 백그라운드로 돌려 놓고, 도는 동안 나머지를 쓴다. 동시 시뮬 최대 2 개.
  4. 그룹 하나 끝날 때마다 RESULT, 전부 끝나면 DONE.
- 상태: OPEN
