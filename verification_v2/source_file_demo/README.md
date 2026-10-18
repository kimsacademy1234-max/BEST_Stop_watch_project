# source_file_demo — 시연 영상용 소스 (보드 전용)

`../source_file/` 복사본에서 **리셋값 두 군데만** 바꿨다. 리셋 (btnC) 하면 바로 경계값 앞에서 시작한다.
시연 시나리오: [`../demo_scenario.pdf`](../demo_scenario.pdf)

| 파일 | 바꾼 것 | 원래 |
|---|---|---|
| `watch_datapath.v` | 시계 리셋값 **23:59:50.00** (리셋 10 초 뒤 자정) | 12:00:00.00 |
| `stopwatch_datapath.v` | 스톱워치 리셋값 **23:59:55.00** (`stopwatch_tick_counter` 에 `INIT` 추가). L (clear) 은 그대로 0 | 00:00:00.00 |

타이머 · 나머지 파일은 `source_file/` 과 같다.

- 검증 TB (`../tb/`) 는 리셋값 12:00:00.00 · 0 을 기대하므로 **이 폴더로 TB 를 돌리지 않는다** (TB 는 `source_file/`).
- `source_file/` 을 고치면 이 폴더에도 같이 복사하고 위 두 군데만 다시 바꾼다.
