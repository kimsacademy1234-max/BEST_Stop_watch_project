# 실제 시간 TB (FINAL/sim_file/top_tb 9 개) — 수정본 소스로 재실행 (11/01, xsim 2022.2, -debug off)

| TB | 수정 전 (FINAL v2) | 수정 후 | 비고 |
|---|---|---|---|
| tb_B4 | PASS 1 / 1 | PASS 1 / 1 | |
| tb_D1 | PASS 2 / 2 | PASS 2 / 2 | |
| tb_E1 | PASS 2 / 2 | PASS 2 / 2 | |
| tb_F1 | PASS 3 / 3 | PASS 3 / 3 | |
| tb_F6 | PASS 3 / 3 | PASS 3 / 3 | |
| tb_D6 | 2 / 3 (WATCHDOG 2000 ms) | 2 / 3 (WATCHDOG 2000 ms) | 같은 시간 초과 — TB 대기 조건 |
| tb_H4 | 0 / 1 (WATCHDOG 20000 ms) | 0 / 1 (WATCHDOG 20000 ms) | 같은 시간 초과 — TB 대기 조건 |
| tb_L4 · tb_L5 | 컴파일 안 됨 | 컴파일 안 됨 | xsim 이 $urandom 미지원 (XSIM 43-3122) |

수정으로 새로 깨진 TB 없음 (결과가 수정 전과 같음). 로그 = 이 폴더 *.log
