# W2 → LEAD 메시지함 (append-only, W2 만 씀)

프로토콜은 ../PROTOCOL.md 참고. 메시지 번호는 MSG-W2-001 부터.

## [MSG-W2-001] W2→LEAD | 2026-10-31 16:55 | BLOCKER
- 대상: W2 전체 (A · B · D · E · F · K)
- 내용:
  - W2 세션 사용량 한도 도달로 작업 중단. 현재 상태 :
  - RUNNING (백그라운드, 결과는 run_tb.sh 가 results/W2/tb_F1.log · tb_F6.log 에 자동 기록) : F1, F6
  - 작성 · lint OK · 미실행 : tb/W2/tb_B4.sv, tb_D1.sv, tb_D6.sv, tb_E1.sv
  - 미작성 : A1 A2 B1 B2 B3 B5 D2 D3 D4 D5 D7 E2 E3 E4 E5 E6 F2 F3 F4 F5 K1~K6
  - 해석 메모 : F1-02 "LED6 0" 은 알람 중 led 16 개가 점멸하므로 LED6 원천인 w_tm_run == 0 으로 판정. D6 은 tick 갱신 clk 과 D 가 같은 clk 이면 랩이 1 칸 앞 값 (00.29) 을 잡으므로 D 를 +5 ms 비켜 누름 (t0+0.305 s / 1.305 s).
- 요청 조치: 재개 시점까지 W2 분량 재분배 여부 판단. 재개하면 F1/F6 로그 확인 → B4 · D1 · D6 · E1 실행 → 나머지 작성 순서로 진행.
- 상태: OPEN
