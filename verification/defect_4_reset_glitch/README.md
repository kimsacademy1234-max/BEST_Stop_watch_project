# F4 — 리셋 라인 글리치 (EMI)

1. **현업 상황**: btnC(rst) 는 **비동기 리셋**이고 필터 · 동기화가 없다. 모터 · 정전기 · 긴 배선의 수 ns 글리치에도 전체 초기화.
2. **주입 방법**: `src/fault_rst_glitch.v` — sw15 상승 엣지(2FF 동기화)에서 내부 리셋에 1 클럭(10 ns) 펄스를 OR. Top 의 리셋 연결 13 곳을 `w_rst_inj` 로 (하위 모듈 무변경). xdc `sw_fault`(R2) 1 줄. LED 는 건드리지 않음.
3. **보드 증상 (sw15 0→1)**: 맞춰 둔 시계 · 스톱워치 잰 시간 · 진행 중인 타이머가 한 번에 사라짐 (타이머 알람은 영원히 안 울림). 화면은 평범한 12:00 이라 원인을 알기 어렵다.
4. **검출 (로그 인용, `results/defect_4/fault/sim.log`)**: `[DEFECT] [F4.P1.F4.W0] unexpected reset glitch width=0.5ns at 115.007182 ms: watch 09:41:00.04->12:00:00.00, sw 00:00:00.33->00:00:00.00 (RUN->STOP), timer 00:49.99->00:00.00 (alarm lost)` — 폭 0.5 / 1 / 5 / 10 ns 모두 전체 초기화 · 주입기 `[DEFECT] [F4.P2.F4.INJ] ... at 320.019535 ms`.
5. **트러블슈팅**: 리셋 동기화기(비동기 assert · 동기 release) + 최소 폭 필터(예: 수 ms 디바운스).

실행: `./tb/run.sh tb_f4_reset_glitch --out results/defect_4/orig` / `./tb/run.sh tb_f4_reset_glitch --src defect_4_reset_glitch/src --out results/defect_4/fault`
