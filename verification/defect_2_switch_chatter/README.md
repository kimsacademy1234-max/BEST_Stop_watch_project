# F2 — 스위치 채터링 / 노이즈

1. **현업 상황**: (a) 누르지 않았는데 EMI 스파이크, (b) 낡거나 살짝 누른 스위치가 누른 중에 잠깐 끊김. 디바운서는 "8 샘플 연속 1 → 눌림" 이지만 **떼는 쪽은 0 샘플 1 개로 즉시 해제** → (a) 는 견디고 (b) 에 약하다.
2. **주입 방법**: `src/fault_chatter.v` 를 버튼 핀 4 개와 디바운서 사이에 끼움. sw15 = 1 이면 안 누른 버튼에 스파이크(1 µs · 50 µs · 500 µs · 1.5 ms, 7 ms 간격), 누른 버튼에 20 ms 마다 300 µs 끊김. xdc `sw_fault`(R2) 1 줄.
3. **보드 증상 (sw15 = 1)**: 시계 설정에서 U 를 꾹 누르면 분이 저절로 연타(약 20 ms 마다 +1), 타이머 U 한 번에 +10 초가 여러 번. 안 누를 때는 아무 일 없음.
4. **검출 (로그 인용, `results/defect_2/fault/sim.log`)**: `[DEFECT] [F2.P3.F2.WATCH] btnU extra pulse #1 at 299.512165 ms (300 us dropout while held = new press)` → 한 번 누름에 5 펄스, 분 +5 / 타이머 00:50 · 주입기 `[DEFECT] [F2.P5.F2.INJ.HOLD] btnU held once, extra pulse #1 at 1108.287225 ms` · 스파이크 200 ms 는 펄스 0 (PASS) · 끊김 경계 표: 250 µs 이상이면 위상과 무관하게 항상 2 번 입력.
5. **트러블슈팅**: 해제도 "8 샘플 연속 0" 을 요구(히스테리시스)하면 해결.

실행: `./tb/run.sh tb_f2_chatter --out results/defect_2/orig` / `./tb/run.sh tb_f2_chatter --src defect_2_switch_chatter/src --out results/defect_2/fault`
