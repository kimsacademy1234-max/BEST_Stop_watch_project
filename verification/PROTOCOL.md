# A/B 에이전트 협업 프로토콜

작업 디렉터리: `BEST_Stop_watch_project/verification/` (검증 전용). 설계 소스(`boyun/merged_v4`)는 **읽기 전용**, 절대 수정하지 않는다.

## 파일 역할
| 파일 | 설명 | 쓰는 사람 |
|---|---|---|
| `verification_original.md` | 사용자의 원본 요청 (불변) | 사용자 |
| `verification.md` | 검증 계획서. 원본 요청을 B가 바로 실행 가능하게 재작성한 것 | **A만** |
| `mailbox/A_to_B.md` | A → B 메시지 (append-only) | A |
| `mailbox/B_to_A.md` | B → A 메시지 (append-only) | B |
| `tb/`, `defect_N_<name>/`, `results/` | TB, 결함 주입 폴더, 시뮬 로그/파형 | **B만** |

## 역할
- **A (검증 기획자)**: `verification_original.md`와 `merged_v4` 소스를 읽고 `verification.md`를 B가 모호함 없이 작업할 수 있게 계속 재작성/개선한다. B의 질문·결과에 답하여 계획을 갱신한다. TB/RTL은 작성하지 않는다.
- **B (검증 수립자)**: `verification.md`대로 TB 작성, 결함 주입 폴더 생성, 시뮬레이션 실행. 계획이 모호하거나 틀리면 직접 판단하지 말고 `B_to_A.md`로 질문한다.

## 메시지 형식 (append, 기존 내용 수정 금지)
```
## [MSG-<번호>] <A→B | B→A> | <YYYY-MM-DD HH:MM> | <type: PLAN|QUESTION|RESULT|BLOCKER|ACK>
- 대상: <verification.md 섹션 / 파일 경로>
- 내용: ...
- 요청 조치: ...
- 상태: OPEN
```
- 처리한 쪽은 해당 메시지 아래에 `- 상태: DONE (MSG-<번호> 회신)` 줄을 추가한다.
- 작업 시작 시 항상 상대 mailbox에서 `상태: OPEN`인 메시지를 먼저 확인한다.

## 공통 규칙 (원본 요청 요약)
- 시뮬레이션 시간 때문에 **주파수를 줄이지 않는다** (실시간 기준).
- TB는 이상 발생 시 **시간(`$time`)과 결함 내용을 console에 출력**한다.
- 기능별 TB 3 set 이상, 이름/Phase로 목적 구분.
- 결함 주입은 `defect_N_<name>/` 폴더별 소스+TB로 분리.
- 담당: ahnsung=watch, jonghyuk=stopwatch, boyun=timer.
