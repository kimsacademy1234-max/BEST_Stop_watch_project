# F3 — 버튼 입력 시점 오차 (src 무변경 · TB 자극만)

1. **현업 상황**: 사람이 누르는 순간은 내부 10 ms tick 과 위상이 무관하다. 100 Hz tick 이 Top 에 하나(공용, 항상 흐름) → RUN 시작이 tick 사이 어디든 된다. 2 ms 근처의 짧은 "톡" 입력은 4 kHz 샘플 위상에 따라 씹힌다.
2. **주입 방법**: 없음. `src/` 는 원본과 동일(`diff` 0). TB 가 누르는 시점을 tick/샘플 기준으로 0~9 ms · 30~220 µs 옮겨 가며 측정.
3. **보드 증상**: 재현이 아니라 시뮬 근거로 설명 — 같은 1.005 s 를 재도 위상에 따라 1.00 / 1.01 s, 타이머는 최대 10 ms 일찍 끝남, 1.8~1.9 ms 탭은 될 때도 있고 안 될 때도 있음.
4. **검출 (로그 인용, `results/defect_3/orig/sim.log`)**: _사용자 실행 후 채움_ — `grep -E "LIMIT|FAIL" results/defect_3/orig/sim.log` 의 `[LIMIT] [F3.P1.F3.SW] phase=...ms window=1.005s count=...` · `[LIMIT] [F3.P2.F3.TM] phase=...ms run->alarm = ...` · `[LIMIT] [F3.P3.F3.TAP] tap ... us -> ...` 표.
5. **트러블슈팅**: RUN 시작 때 tick 카운터를 0 으로 맞추면(개별 tick) 오차가 사라지지만 자원 · 공용성과 맞바꿈. 참고: tick 엣지는 항상 디바운서 샘플 엣지와 겹친다(1,000,000 = 40 × 25,000) → 구간이 10 ms 의 배수면 오차 0.

실행 (sim ≈ 22 s → Verilator 단독 ≈ 18 분): `./tb/run.sh tb_f3_press_timing --out results/defect_3/orig`
