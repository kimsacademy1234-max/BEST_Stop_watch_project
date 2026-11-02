# sender 버그 주입 검증 (11/01)

- 대상 : 팀 FINAL v2 소스 (`C:\work\merge_fix2\src` = `FINAL/source_file/merge_final`) 사본에 버그를 **하나씩** 넣음. 원본은 그대로.
- 만들기 : `py -3.10 -X utf8 make_mut.py` → `S1 ~ S8\src` · 각 폴더 `BUG.txt`
- 돌리기 : `bash run_bug.sh S1` (단위 TB 2 개 + Top TB, Vivado 2022.2 xsim `-debug typical`)
  - 단위 TB : `tb_sd1_char` (글자 MUX) · `tb_sd2_sender` (sender FSM, v2 포트 이름으로 바꾼 사본 `C:\work\sender_v2_tb\tb_sd2_sender\tb_sd2_sender_v2.v`)
  - Top TB : `통합검증\tb\tb_top_full.v` (`FIX = 6` = v2 기대값), 시간 단축 파라미터
- 원본 (버그 없음) : 단위 TB 2 개 · Top TB 모두 TOTAL MISMATCH 0

| # | 넣은 버그 | 파일 | tb_sd1_char | tb_sd2_sender | tb_top_full | 검출 |
|---|---|---|---:|---:|---:|---|
| S1 | busy 중 send_go 를 받음 (SEND 에서도 새 값 잡기) | uart_sender.v | 0 | **9** | 0 | 단위 |
| S2 | TX FIFO full 을 무시하고 push | uart_sender.v | 0 | **538** | 0 | 단위 |
| S3 | go 순간 값을 안 잡고 바깥 값을 바로 글자 MUX 로 | uart_sender.v | 0 | **16** | **73** | 둘 다 |
| S4 | 마지막 글자 (LF) 하나 덜 보냄 | uart_sender.v | 0 | **465** | **113** | 둘 다 |
| S5 | 새 줄 시작 때 글자 번호를 0 으로 안 돌림 | uart_sender.v | 0 | **143** (FAIL 줄, (11) 에서 멈춰 시간 초과) | **108** | 둘 다 |
| S6 | 거리 백의 자리 계산 오류 (÷100 → ÷10 %10) | sender_char_mux.v | **2** | **32** | **10** | 둘 다 |
| S7 | v2 거리 상태 무시 (Err 대신 숫자) | sender_char_mux.v | 0 | 0 | **4** | Top |
| S8 | v2 온습도 측정 전 무시 (--%--C 대신 숫자) | sender_char_mux.v | 0 | 0 | **4** | Top |

- 숫자 = TOTAL MISMATCH (불일치 수). 굵은 칸 = FAIL 검출.
- **8 개 모두 검출** (단위 TB 6 · Top TB 6, 서로 보완).
- Top TB 가 S1 · S2 를 못 잡는 이유 : Top 에서는 U_CONTROL 이 busy 0 일 때만 send_go 를 주고, TX FIFO 64 칸이 시나리오 안에서 차지 않아 그 상황 자체가 안 생김 → 단위 TB 로만 확인 가능.
- 단위 TB 가 S7 · S8 을 못 잡는 이유 : 단위 TB (10/30 작성) 입력 데이터에 v2 상태 비트 (거리 10:9 · 온습도 19:16) 가 없음 → Top TB 의 Err · --%--C 검사가 잡음.
- Top TB 예 : S7 `got "400cm" exp "Err 2"`, S8 `got "00%00C" exp "--%--C"`, S6 `got "000cm" exp "100cm"`.
