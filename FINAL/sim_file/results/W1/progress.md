# W1 진행 현황 (W1 만 씀)

상태 : TODO → WRITING → RUNNING → DONE (WAIT-Q 질문 대기 · BLOCKED)

| ID | 시나리오 | P | 개수 | 상태 | pass | fail | known | xpass | 벽시계 | 메모 |
|---|---|:-:|:-:|---|:-:|:-:|:-:|:-:|:-:|---|
| C1 | 스위치 우선순위 | P1 | 8 | TODO | | | | | | |
| C2 | 첫 정상 `/mod` 뒤 스위치 무시 | P1 | 3 | TODO | | | | | | |
| C3 | 틀린 `/mod` | P1 | 2 | TODO | | | | | | |
| C4 | `/mod` 8 종 매핑 | P1 | 8 | TODO | | | | | | |
| C5 | 12/24 시간 유지 | P2 | 2 | TODO | | | | | | |
| C6 | `/set w_hm` 조건 | P2 | 4 | TODO | | | | | | |
| C7 | `/mod` 전 `/set 24h` | P3 | 1 | TODO | | | | | | |
| C8 | 설정 중 `/mod` | P2 | 2 | TODO | | | | | | |
| G1 | 정상 명령 전부 | P1 | 24 | TODO | | | | | | |
| G2 | 형식 오류 | P1 | 10 | TODO | | | | | | |
| G3 | 형식 OK · 모르는 옵션 | P2 | 3 | TODO | | | | | | |
| G4 | `/` 로 복구 | P1 | 2 | TODO | | | | | | |
| G5 | 쓰레기 · 꼬리 문자 | P2 | 3 | TODO | | | | | | |
| G6 | 짧은 옵션 | P2 | 2 | TODO | | | | | | |
| G7 | `/off` 오타 뒤 `/off` ⚠ | P1 | 2 | TODO | | | | | | |
| G8 | RX 물리층 | P2 | 5 | TODO | | | | | | |
| G9 | 바이트 연속 | P2 | 1 | TODO | | | | | | |
| H1 | 화면별 `/get` | P1 | 5 | TODO | | | | | | |
| H2 | 스위치 모드 `/get` ⚠ | P1 | 1 | TODO | | | | | | |
| H3 | auto 중 `/get` | P2 | 1 | TODO | | | | | | |
| H4 | `/auto` 주기 | P1 | 5 | RUNNING | | | | | | |
| H5 | `/auto all` 순서 | P1 | 1 | TODO | | | | | | |
| H6 | auto 중 전환 | P2 | 1 | TODO | | | | | | |
| H7 | off 뒤 재시작 ⚠ | P2 | 2 | TODO | | | | | | |
| H8 | ERROR 우선 · 줄 무결성 | P1 | 3 | TODO | | | | | | |
| H9 | `/get` 연타 ⚠ | P2 | 1 | TODO | | | | | | |
| H10 | 응답 형식 경계값 | P1 | 5 | TODO | | | | | | |
| H11 | `/btn` | P1 | 4 | TODO | | | | | | |
| H12 | 물리 + UART 같은 clk | P2 | 2 | TODO | | | | | | |
