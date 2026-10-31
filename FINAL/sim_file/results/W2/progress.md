# W2 진행 현황 (W2 만 씀)

상태 : TODO → WRITING → RUNNING → DONE (WAIT-Q 질문 대기 · BLOCKED)

| ID | 시나리오 | P | 개수 | 상태 | pass | fail | known | xpass | 벽시계 | 메모 |
|---|---|:-:|:-:|---|:-:|:-:|:-:|:-:|:-:|---|
| A1 | 전원 · 리셋 직후 초기값 | P1 | 7 | TODO | | | | | | |
| A2 | 동작 중 리셋 | P1 | 7 | TODO | | | | | | |
| B1 | 정상 누름 | P1 | 4 | TODO | | | | | | |
| B2 | 채터링 | P1 | 2 | TODO | | | | | | |
| B3 | 짧은 누름 경계 | P2 | 2 | TODO | | | | | | |
| B4 | 길게 누름 | P2 | 1 | WRITING | | | | | | TB 작성 · lint OK, 실행 전 |
| B5 | 화면 게이팅 | P1 | 5 | TODO | | | | | | |
| D1 | 시작 정확도 | P1 | 2 | WRITING | | | | | | TB 작성 · lint OK, 실행 전 |
| D2 | 짧은 run 누적 | P2 | 2 | TODO | | | | | | |
| D3 | 최대값 wrap (업) | P1 | 1 | TODO | | | | | | |
| D4 | 다운 wrap | P1 | 2 | TODO | | | | | | |
| D5 | RUN 중 U · L | P1 | 3 | TODO | | | | | | |
| D6 | 랩 | P1 | 3 | WRITING | | | | | | TB 작성 · lint OK, 실행 전. 랩 D 를 t0+0.305/1.305 s 로 (tick 경계 경합 회피) |
| D7 | 랩 + 지우기 / UART | P2 | 2 | TODO | | | | | | |
| E1 | 초기값 · 1 초 | P1 | 2 | WRITING | | | | | | TB 작성 · lint OK, 실행 전 |
| E2 | 12/24 경계 | P1 | 6 | TODO | | | | | | |
| E3 | 설정 커서 순환 | P1 | 6 | TODO | | | | | | |
| E4 | 설정 값 wrap | P1 | 6 | TODO | | | | | | |
| E5 | 동시 입력 | P3 | 2 | TODO | | | | | | |
| E6 | 초 화면에서 설정 ⚠ | P2 | 1 | TODO | | | | | | |
| F1 | 10 초 타이머 | P1 | 3 | RUNNING | | | | | | LED6 0 = w_tm_run 0 으로 해석 (알람 중 led[6] 은 점멸) |
| F2 | 0 에서 시작 | P1 | 1 | TODO | | | | | | |
| F3 | 포화 · 올림 | P1 | 3 | TODO | | | | | | |
| F4 | RUN 중 더하기 · 취소 | P1 | 2 | TODO | | | | | | |
| F5 | 알람 끄기 | P1 | 4 | TODO | | | | | | |
| F6 | 다른 화면에서 알람 | P1 | 3 | RUNNING | | | | | | |
| K1 | WTS FND | P1 | 3 | TODO | | | | | | |
| K2 | 설정 점멸 | P1 | 3 | TODO | | | | | | |
| K3 | 거리 FND | P1 | 7 | TODO | | | | | | |
| K4 | 온습도 FND | P1 | 6 | TODO | | | | | | |
| K5 | LED 화면별 | P1 | 7 | TODO | | | | | | |
| K6 | 스캔 | P2 | 2 | TODO | | | | | | |
