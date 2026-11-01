# J14-2 수정 : 습도 · 온도가 100 이상이면 PC 줄 첫 글자가 ':' 로 나가던 것 (11/01)

- 현상 (그룹 TB `tb_J_dht11` J14-2, ISSUE) : 습도 100 → FND `99.24` 인데 UART `/get` 은 `:0%24C`
- 원인 : `UART/sender_char_mux.v` 가 습도 · 온도를 2 자리로 가정 → 100 / 10 = 10 → `8'h30 + 10` = `8'h3A` = `:`
- 수정 : FND 와 같은 규칙 (`DHT11/dht11_manager.v` 22 ~ 23 줄 : 99 보다 크면 99) 을 글자 MUX 에도 → `99%24C`
- 바뀐 곳 : `UART/sender_char_mux.v` 22 ~ 23 줄 2 줄뿐 (`fix_j14_1101.diff`). 다른 파일은 `FINAL/source_file/merge_final` (v2) 그대로
- 확인 (Vivado 2022.2 xsim, -debug typical)
  - 그룹 TB 12 개 : 모두 FAIL 0 · J14-2 `got "99%24C"` OK → ISSUE 8 → 7 (나머지 7 건은 전과 같음)
  - 통합 TB `tb_top_full` (v2 기대값) : 검사 560 · TOTAL MISMATCH 0
- 합계 : 그룹 TB 305 = PASS 298 + ISSUE 7 + FAIL 0, + 보윤 통합 TB 292 → **PASS 590 · ISSUE 7 · FAIL 0**
- FINAL 원본에 반영할지는 팀에서 결정 (반영하면 이 파일 하나만 덮어쓰면 됨)
