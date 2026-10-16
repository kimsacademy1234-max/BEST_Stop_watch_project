# 검증 결과 요약 (자동 생성: tb/summarize.py)

| TB | src | 결과 | fail 수 | defect 수 | limit 수 | 첫 이상 시각 | 파형 창 | 비고 |
|---|---|---|---|---|---|---|---|---|
| TOP1 | orig | PASS | 0 | 0 | 1 | - | - | LIMIT TOP1.P4.GLITCH |
| TOP2 | orig | PASS | 0 | 0 | 0 | - | - |  |
| WT1 | orig | PASS | 0 | 0 | 0 | - | - |  |
| WT2 | orig | PASS | 0 | 0 | 0 | - | - |  |
| SW1 | orig | PASS | 0 | 0 | 1 | - | - | LIMIT SW1.P6.SB7 |
| SW2 | orig | PASS | 0 | 0 | 0 | - | - |  |
| SW3 | orig | PASS | 0 | 0 | 0 | - | - |  |
| TM1 | orig | PASS | 0 | 0 | 0 | - | - |  |
| TM3 | orig | PASS | 0 | 0 | 0 | - | - |  |
| F1 | defect_1_fnd_com_skew | DETECTED | 0 | 85 | 0 | 76.506105 ms | 75.506 ~ 77.506 ms | DEFECT F1.P1.F1.N500: first ghost at   76.506105 ms, N=500: AN0 shows '3'(AN1 digit) for 5.000 us per slot (2.0  |
| F1 | orig | DETECTED | 0 | 3 | 0 | 76.506105 ms | 75.506 ~ 77.506 ms | DEFECT F1.P1.F1.N500: first ghost at   76.506105 ms, N=500: AN0 shows '3'(AN1 digit) for 5.000 us per slot (2.0  |
| F2 | defect_2_switch_chatter | DETECTED | 0 | 12 | 5 | 317.264190 ms | 316.264 ~ 318.264 ms | DEFECT F2.P3.F2.WATCH: btnU extra pulse #1 at  299.512165 ms (300 us dropout while held = new press) / exp=1 puls; LIMIT F2.P4.F2.TABLE; LIMIT F2.P4.F2.TABLE |
| F2 | orig | DETECTED | 0 | 8 | 5 | 317.264190 ms | 316.264 ~ 318.264 ms | DEFECT F2.P3.F2.WATCH: btnU extra pulse #1 at  299.512165 ms (300 us dropout while held = new press) / exp=1 puls; LIMIT F2.P4.F2.TABLE; LIMIT F2.P4.F2.TABLE |
| F4 | defect_4_reset_glitch | DETECTED | 0 | 5 | 0 | 115.007182 ms | 114.007 ~ 116.007 ms | DEFECT F4.P1.F4.W0: unexpected reset glitch width=0.5ns at  115.007182 ms: watch 09:41:00.04->12:00:00.00, sw  |
| F4 | orig | DETECTED | 0 | 4 | 0 | 115.007182 ms | 114.007 ~ 116.007 ms | DEFECT F4.P1.F4.W0: unexpected reset glitch width=0.5ns at  115.007182 ms: watch 09:41:00.04->12:00:00.00, sw  |
| ? | results/tb_tm_2_countdown_alarm/sim.log | NO SUMMARY (중단?) | - | - | - | - | - | results/tb_tm_2_countdown_alarm/sim.log |
| ? | results/tb_wt_3_display_12h/sim.log | NO SUMMARY (중단?) | - | - | - | - | - | results/tb_wt_3_display_12h/sim.log |

- 결과: PASS = 기대대로 / DETECTED = 결함 TB 가 결함을 잡음 (fail 0) / FAIL = 기대와 다름
- 첫 이상 시각 = 처음 FAIL 또는 DEFECT 가 난 시뮬 시각. 파형은 `./tb/run.sh <tb> --sim icarus --phase N --wave` 로 그 Phase 만 다시 뽑는다
- 이상 시각 전체: `grep -E "FAIL|DEFECT|TIMEOUT" results/**/sim.log`
