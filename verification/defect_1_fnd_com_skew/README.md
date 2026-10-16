# F1 — FND 자리선택(com) 위상 차이 → 고스팅

1. **현업 상황**: 다이나믹 구동 FND 에서 애노드 트랜지스터 turn-off 지연 · 배선 길이 차이 때문에 com 이 data 보다 늦게 바뀜. 이 설계는 자리 사이 블랭킹이 없어 이전 자리에 다음 숫자가 잠깐 켜진다(잔상).
2. **주입 방법**: `src/fault_com_skew.v` (N = 12,500 clk = 125 µs 지연) 를 FND_CON 의 `o_fnd_com` 과 핀 `fnd_com` 사이에 끼움. `stopwatch_watch.v` 연결 몇 줄 + xdc `sw_fault`(sw15, R2) 1 줄. 설계 모듈 무변경 (`defect.patch`).
3. **보드 증상 (sw15 = 1)**: 각 자리에 옆 자리 숫자가 겹쳐 보임. 12:34 → AN0('4') 에 '3', AN3('1') 에 '4' 가 희미하게. sw15 = 0 이면 원본과 같음.
4. **검출 (로그 인용, `results/defect_1/fault/sim.log`)**: `[DEFECT] [F1.P1.F1.N3000] first ghost at 76.506105 ms, N=3000: AN0 shows '3'(AN1 digit) for 30.000 us per slot (12.0 % duty)` · sw15 = 1 구간 `[DEFECT] [F1.P2.FND] FND output != reference for 125.000 us from 127.257105 ms (slot=5 com=1110 exp_com=1101)` · sw15 = 0 구간 불일치 0.
5. **트러블슈팅**: 자리 전환 때 슬롯 일부를 블랭킹(com 전부 off) 하면 해결. 지연 N 에 비례해 고스트 duty 가 커짐 (N = 500 → 2 %, 3,000 → 12 %, 12,500 → 50 %).

실행: `./tb/run.sh tb_f1_com_skew --out results/defect_1/orig` / `./tb/run.sh tb_f1_com_skew --src defect_1_fnd_com_skew/src --out results/defect_1/fault`
