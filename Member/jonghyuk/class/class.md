# SystemVerilog 수업 정리

| 날짜 | 주제 |
|---|---|
| [1104 (수)](#1104-수--class-기반-검증-환경) | Class 기반 검증 환경 · event · mailbox · fork-join · scheduling |
| [1105 (목)](#1105-목--sv-특징--crv--uvm--자료형) | SV 특징 · CRV · UVM 개요 · Verilog vs SV · queue · IPC · 8-bit register 실습 |

---

# 1104 (수) — Class 기반 검증 환경

> **핵심 한 줄** : 역할을 class로 나눠(OOP) **재사용성**을 높이고, 각 컴포넌트는 **event / mailbox**로 동기화한다(event driven).

| # | 목차 |
|---|------|
| 1 | 검증 환경 구조 |
| 2 | Class 기본 (handle · new · 동적 할당) |
| 3 | randomize & constraint |
| 4 | driver ↔ monitor 동기화 (event) |
| 5 | mailbox |
| 6 | fork-join 3종 (면접 단골) |
| 7 | Scheduling (Event Region) |
| 8 | 시뮬레이션 종료 |
| 9 | 면접 / 복습 포인트 |

---

## 1. 검증 환경 구조

### 1-1. 데이터 흐름

```
 generator ──(mailbox)──> driver ──> [interface] ──> DUT ──> [interface] ──> monitor ──(mailbox)──> scoreboard ──> PASS / FAIL
  (stimulus 생성)          (핀에 인가)                                       (핀 값 수집)                 (기댓값 비교)
                              │                                                 ▲
                              └──────────────── event (drv_done) ───────────────┘
                                                                                 └──> coverage (몇 % 검사했나)
```

### 1-2. 컴포넌트 역할

| 컴포넌트 | 역할 | 주요 도구 |
|---|---|---|
| transaction | 주고받을 데이터 묶음(벡터) 정의 | `rand` 변수, `constraint` |
| generator | stimulus(벡터) 생성 → driver로 전달 | `randomize()`, `mailbox.put()` |
| driver | transaction을 **핀 레벨 신호**로 바꿔 DUT에 인가 | `virtual interface`, `mailbox.get()` |
| interface | TB(SW) ↔ DUT(HW) 사이 신호 묶음 | `interface ... endinterface` |
| monitor | DUT 입출력 관찰 → transaction으로 다시 묶어 전달 | `@(event)`, `mailbox.put()` |
| scoreboard | 기댓값(reference model)과 비교 → PASS/FAIL | `mailbox.get()`, 카운터 |
| coverage | 검증을 **얼마나(%)** 했는지 측정 — SV에서 추가된 기능 | `covergroup`, `coverpoint` |
| environment | 위 컴포넌트 생성·연결·실행 | `new()`, `fork…join` |

### 1-3. 최종 목표

| 항목 | 내용 |
|---|---|
| 목표 | 시간마다 발생하는 값(이벤트)에 반응하는 **통합 검증 플랫폼** 구축 |
| 이유 | DUT·시나리오가 바뀌어도 컴포넌트만 교체/재사용 (환경은 다양해질 수밖에 없음) |
| 발전 방향 | class 기반 TB → UVM |

---

## 2. Class 기본

### 2-1. 핸들 → 생성 → 사용

| 단계 | 의미 | 문법 |
|---|---|---|
| ① 핸들 선언 | 객체를 가리킬 **변수**만 생김 (메모리 X, 값은 `null`) | `transaction tr;` |
| ② 생성 | `new` 호출 시 **동적 할당** + 초기화 | `tr = new();` |
| ③ 사용 | 접근 연산자 `.`으로 멤버/메서드 접근 | `tr.a`, `tr.randomize()` |

- `function new` : 생성자. 재정의(override)해서 **인자 전달·초기화**에 사용 (예: mailbox, virtual interface 연결)
- 사용자 `task` / `function` : 이 객체가 **무슨 일을 하는지** 정의 (예: `run()`)

### 2-2. OOP에서 가장 중요한 것 = 자료형

| 구분 | 정적 할당 (HW) | 동적 할당 (class 객체) |
|---|---|---|
| 시점 | elaboration 시 메모리 확정 | `new` 할 때 메모리 할당 |
| 특징 | 위치 고정, 리소스 계속 점유 | 필요할 때 생성, 참조 없으면 자동 회수(GC) |
| 예 | `module`, `interface` instance | `transaction`, `driver` 객체 |

### 2-3. 실행 순서

```
HW instance (module / interface)  →  initial begin  →  env = new(...) (동적 생성)  →  env.run() (task: 시간 제어 가능)
```

### 2-4. task vs function

| 구분 | function | task |
|---|---|---|
| 시간 소모 (`#`, `@`, `wait`) | 불가 | **가능** |
| 반환값 | 있음 (`void` 가능) | 없음 (output 인자로) |
| 용도 | 계산, `new`, 비교 | `run()`, 신호 구동, 대기 |

### 2-5. virtual interface

| 질문 | 답 |
|---|---|
| 왜 필요? | class(SW)는 HW인 interface를 직접 가질 수 없음 |
| 어떻게? | `virtual` 키워드로 interface의 **핸들**을 받아서 접근 |
| 연결 | top에서 실제 interface instance → env `new()` 인자 → driver/monitor로 전달 |

---

## 3. randomize & constraint

| 항목 | 의미 | 문법 예 |
|---|---|---|
| `rand` | `randomize()` 시 랜덤값 생성 대상 (중복 허용) | `rand bit [7:0] a;` |
| `randc` | 한 바퀴 돌 때까지 **중복 없이** 순환 | `randc bit [3:0] b;` |
| 범위 | 지정 범위 안에서만 | `a inside {[0:100]};` |
| 리스트 | 특정 값들 중에서만 | `a inside {1, 5, 10};` |
| 확률 `:=` | 범위 내 **각 값마다** 가중치 그대로 | `a dist {0 := 40, [1:3] := 60};` → 1,2,3 각각 60 |
| 확률 `:/` | 가중치를 범위 전체에 **나눠서** (% 개념) | `a dist {0 :/ 40, [1:3] :/ 60};` → 1,2,3 각각 20 |
| 결과 확인 | 실패 시 0 반환 → 체크 권장 | `if (!tr.randomize()) $error(...)` |

---

## 4. driver ↔ monitor 동기화 (event)

### 4-1. 문제 → 해결

| 구분 | 순차 방식 (문제) | event 방식 (해결) |
|---|---|---|
| 동작 | driver 끝 → `#10` 후 monitor 실행 | driver가 값 인가 후 **event 발생** → monitor가 즉시 캡처 |
| 시간 | 순차 시간이 **2배** | driver와 monitor가 **동시에** 진행 |
| monitor 시점 | 고정 간격마다 감지 | **driver 값이 바뀌었을 때만** 감지 |

### 4-2. 흐름

| 순서 | 주체 | 동작 |
|---|---|---|
| 1 | driver | `mailbox.get(tr)` → 핀에 값 인가 → `#10` (값 안정 대기) |
| 2 | driver | event 발생 `-> drv_done;` |
| 3 | monitor | `@(drv_done);` 로 catch → 핀 값을 읽어 transaction 생성 |
| 4 | monitor | `mon2scb_mbox.put(tr);` 로 scoreboard에 report |
| 5 | scoreboard | `mon2scb_mbox.get(tr);` → 기댓값 비교 → PASS/FAIL |

### 4-3. event 문법

| 문법 | 의미 | 주의 |
|---|---|---|
| `event e;` | event 선언 (driver·monitor가 **같은 핸들** 공유) | env에서 생성 후 둘에게 전달 |
| `-> e;` | event 발생 (trigger) | |
| `@(e);` | 발생할 때까지 대기 (edge 성격) | 같은 time step에 먼저 trigger되면 **놓침** (race) |
| `wait(e.triggered);` | 해당 time step 동안 발생 상태 유지 | race 회피용 |

---

## 5. mailbox

| 메서드 | 동작 | blocking 여부 |
|---|---|---|
| `new()` | 생성 (크기 지정 안 하면 무제한) | — |
| `put(tr)` | 넣기 | 가득 차면 대기 |
| `get(tr)` | 꺼내기 (빼감) | **비어 있으면 대기** → 자연스러운 동기화 |
| `peek(tr)` | 보기만 (안 빼감) | 비어 있으면 대기 |
| `try_get(tr)` | 꺼내기 시도 | 대기 X, 없으면 0 반환 |
| `num()` | 들어있는 개수 | — |

- 타입 지정 : `mailbox #(transaction)` → 다른 타입이 들어오는 실수 방지
- 연결 : env에서 mailbox 1개 생성 → 보내는 쪽/받는 쪽 `new()`에 **같은 핸들** 전달

---

## 6. fork-join 3종 (면접 단골 ★)

### 6-1. 기본 개념

| 구분 | 의미 |
|---|---|
| `begin … end` | **순차** 실행 (위에서 아래로, blocking) — 단점: 개별 동작이 어려움 |
| `fork … join` | 안의 문장/블록을 **병렬** 실행 |
| `forever` | 무한 루프. `fork` 안에 두면 다른 프로세스와 **병렬로 계속** 동작 (예: driver·monitor의 `run()`) |
| 실제 사용 | `fork` 안에 각 컴포넌트의 `begin…end`(순차)를 넣어 **섞어서** 사용 |

> 참고 : `forever` 자체는 병렬이 아니라 무한 반복일 뿐. 병렬성은 `fork`가 만든다.

### 6-2. 3종 비교

| 종류 | 언제 다음 줄로 넘어가나 | 용도 |
|---|---|---|
| `fork … join` | 안의 프로세스가 **모두** 끝나야 | 전부 완료를 기다릴 때 |
| `fork … join_any` | **하나라도** 끝나면 (나머지는 계속 실행) | timeout / 종료 조건 감시 |
| `fork … join_none` | **기다리지 않고 즉시** (프로세스는 백그라운드 실행) | 프로세스 띄워놓고 다른 일 하기 |

```
시간 →        0 ─────────────── 끝
a :           ■■■■■■■■■■
b :           ■■■■■■■■■■■■■■■■■■
join        :                    ▲ (a, b 모두 끝)
join_any    :          ▲ (a 끝나면 바로)
join_none   : ▲ (0ns에 바로)
```

| 보조 문법 | 의미 |
|---|---|
| `wait fork;` | `join_none` / `join_any`로 띄운 자식 프로세스가 다 끝날 때까지 대기 |
| `disable fork;` | 남아 있는 자식 프로세스 강제 종료 (`join_any` 후 정리용) |

### 6-3. 실행 예 (gen + drv를 fork)

| 컴포넌트 | 동작 |
|---|---|
| gen | `repeat(10)` → mailbox가 무제한이면 **0ns에 10개 모두 put 완료** |
| drv | `forever begin…end` 안에서 get → 구동 → 대기를 **순서대로** 반복 |

### 6-4. Race condition

| 항목 | 내용 |
|---|---|
| 현상 | 같은 시각에 실행되는 gen/drv **코드 간 우선순위는 알 수 없음** (LRM 규약 없음) |
| 이유 | CPU가 실제로 동시에 처리하는 게 아니라, 시뮬레이터가 한 time step 안의 프로세스를 **임의 순서**로 실행 |
| 보장되는 것 | **같은 `begin…end` 안**의 순서만 보장. 다른 class/프로세스 간 순서는 보장 X |
| 해결 | 조합논리성 동기화 → **event**, mailbox / 순차논리성 동기화 → **clk 엣지** (`@(posedge clk)`) |

---

## 7. Scheduling (Event Region)

> 한 time step은 여러 **region**으로 나뉘어 정해진 순서로 처리된다. race condition을 이해하는 기준.

| 순서 | Region | 실행되는 것 |
|---|---|---|
| 1 | Preponed | 값 샘플링 (`assert`, clocking block 입력 샘플) |
| 2 | **Active** | blocking 대입 `=`, 연속 대입 `assign`, `$display`, NBA의 **우변 계산** |
| 3 | Inactive | `#0` 지연된 문장 |
| 4 | **NBA** | non-blocking `<=` **좌변 갱신** |
| 5 | Observed | concurrent assertion 평가 |
| 6 | **Reactive** | `program` 블록 코드 실행 (TB 코드) |
| 7 | Re-Inactive | `program` 안의 `#0` |
| 8 | Re-NBA | `program` 안의 `<=` 갱신 |
| 9 | Postponed | `$monitor`, `$strobe` (값이 **최종 확정된 후** 출력) |

| 포인트 | 내용 |
|---|---|
| Active 안의 순서 | **보장 X** → 같은 region에 있는 프로세스끼리 race 발생 |
| `<=`를 쓰는 이유 | 우변 계산(Active)과 좌변 갱신(NBA)이 분리 → 순차논리 race 방지 |
| `$display` vs `$strobe` | `$display`는 Active(갱신 전 값일 수 있음), `$strobe`는 Postponed(확정 값) |
| TB를 Reactive로 | `program` / clocking block 사용 시 DUT(Active) 실행 후 TB가 동작 → race 회피 |

---

## 8. 시뮬레이션 종료

| 항목 | 내용 |
|---|---|
| `$finish` | **반드시** 써서 시뮬레이션 종료 (Synopsys 등 툴에서 `forever`가 있으면 안 끝남) |
| `$stop` | 일시정지 (GUI 디버깅용) — 종료가 아님 |
| 강제 종료 로직 | 버그로 무한 대기 시 대비 → **watchdog timeout** 권장 |
| 구현 아이디어 | `fork` 안에 [정상 종료 조건] + [`#TIMEOUT` 후 에러 메시지] 를 두고 `join_any` → 먼저 끝나는 쪽으로 탈출 → `disable fork` → `$finish` |
| 정상 종료 조건 예 | scoreboard 비교 횟수 == generator 생성 개수 |

---

## 9. 면접 / 복습 포인트

| 질문 | 한 줄 답 |
|---|---|
| class로 TB를 짜는 이유? | 역할 분담 → 재사용성·확장성 (DUT가 바뀌어도 컴포넌트 재사용) |
| 핸들과 객체의 차이? | 핸들은 가리키는 변수(메모리 X), `new` 해야 객체가 생성됨 |
| virtual interface를 쓰는 이유? | class(동적)가 interface(정적 HW)에 접근하기 위한 핸들 |
| task와 function 차이? | task만 시간 소모 가능 |
| `fork-join` / `join_any` / `join_none`? | 모두 대기 / 하나만 대기 / 대기 안 함 |
| race condition 원인과 해결? | 같은 time step·region 내 실행 순서 미보장 → event, mailbox, clk, `<=`, clocking block |
| `:=` vs `:/`? | 각 값마다 가중치 / 범위에 가중치 분배 |
| mailbox `get` vs `peek`? | 빼감 / 보기만 |
| `@(e)` vs `wait(e.triggered)`? | 같은 시각 trigger를 놓칠 수 있음 / 해당 time step 동안 감지 가능 |

---
---

# 1105 (목) — SV 특징 · CRV · UVM · 자료형

> **핵심 한 줄** : SV는 OOP로 TB를 **추상화·재사용**하고, CRV로 빠르게 검증하되 corner case는 coverage로 보완한다. 이를 표준화한 것이 **UVM**.

| # | 목차 |
|---|------|
| 1 | SV의 OOP 특징 |
| 2 | Constraint Random Verification (CRV) |
| 3 | UVM 개요 |
| 4 | Verilog vs SystemVerilog 주요 차이점 · **4-state 진리표** |
| 5 | 배열 자료형 & queue |
| 6 | 왜 fork-join + event인가 (IPC) |
| 7 | 실습 — 8-bit register 검증 |
| 8 | 면접 / 복습 포인트 |

---

## 1. SV의 OOP 특징

| 특징 | 의미 | SV에서 | TB 예시 |
|---|---|---|---|
| 객체화 | 데이터 + 동작을 하나의 **객체**로 묶음 | `class`, `new()` | transaction, driver 객체 |
| 역할 분담 | 컴포넌트마다 한 가지 일만 | class 분리 | gen / drv / mon / scb |
| 추상화 | 내부 구현은 숨기고 **무엇을 하는지**만 노출 | `task run()` | env는 `run()`만 호출 |
| 모듈화(캡슐화) | 독립 단위로 묶고 외부 접근 제한 | `local`, `protected` | 내부 카운터는 외부에서 못 건드림 |
| 상속 | 기존 class를 **확장**해 재사용 | `extends`, `super.` | `transaction` → `err_transaction` |
| 다형성 | 같은 핸들·같은 호출로 **다른 동작** | `virtual` 메서드 | 부모 핸들로 자식 `run()` 실행 |

---

## 2. Constraint Random Verification (CRV)

### 2-1. Directed vs CRV

| 구분 | Directed Test | Constraint Random (CRV) |
|---|---|---|
| 방식 | 사람이 입력값을 **하나하나 지정** | `constraint` 범위 안에서 **랜덤 생성** |
| 초기 비용 | 낮음 (바로 작성) | **env setup 시간이 존재** (gen/drv/mon/scb 구축) |
| 이후 속도 | 케이스마다 새로 작성 → 느림 | 구축 후엔 **많은 케이스를 빠르게** |
| 약점 | 사람이 생각 못 한 버그 놓침 | **corner case에서 100% 도달이 힘듦** |
| 진행 확인 | 작성한 케이스 수 | **functional coverage (%)** |

### 2-2. Coverage Driven Verification 흐름

```
CRV로 대량 검증  →  coverage 측정  →  구멍(미도달 corner case) 확인  →  constraint 조정 or directed test 추가  →  100% 목표
```

---

## 3. UVM 개요

> 일반적인 class TB보다 **빠르고 표준화된** 검증 방법론. 역할 분담된 객체들을 **표준 라이브러리**로 제공.

### 3-1. 내 class TB ↔ UVM 대응

| 내가 만든 class TB | UVM | 역할 |
|---|---|---|
| transaction | `uvm_sequence_item` | 주고받는 데이터 |
| generator | `uvm_sequence` + **sequencer** | stimulus 생성 / driver로 전달 순서 관리 |
| driver | `uvm_driver` | 핀 레벨 구동 |
| monitor | `uvm_monitor` | 핀 관찰 → transaction |
| scoreboard | `uvm_scoreboard` | 비교 |
| (drv + mon 묶음) | `uvm_agent` | 인터페이스 1개 담당 단위 |
| environment | `uvm_env` | agent·scb 묶음 |
| initial 블록 시나리오 | `uvm_test` | 테스트 선택 |
| mailbox | TLM port (`seq_item_port`, `analysis_port`) | 컴포넌트 간 통신 |

### 3-2. 수업에서 나온 키워드

| 키워드 | 의미 |
|---|---|
| 등록 관리자 (factory) | class를 **factory에 등록**해 두고, 코드 수정 없이 다른 class로 **교체(override)** 생성 가능 (`uvm_component_utils` / `uvm_object_utils`) |
| 시퀀서 (sequencer) | 여러 sequence가 보내는 item을 **중재(arbitration)** 해서 driver에 하나씩 전달 |
| multi generator | 여러 sequence가 하나의 sequencer에 동시에 붙을 수 있음 → monitor·transaction 구조는 그대로 재사용 |
| phase | build → connect → run → report 순서로 자동 실행 (내가 `new`·`run` 직접 호출하던 걸 대신함) |
| config_db | virtual interface 등을 **전역 DB**로 전달 (`new()` 인자로 넘기던 방식 대체) |

---

## 4. Verilog vs SystemVerilog 주요 차이점

| 구분 | Verilog | SystemVerilog |
|---|---|---|
| 목적 | **설계(RTL)** 중심 | 설계 + **검증** 통합 (HDVL) |
| 자료형 | `wire`, `reg` (4-state) | `logic`(wire/reg 통합), `bit`·`int`·`byte` (2-state), `enum`, `struct`, `typedef` |
| 배열 | 고정 크기 배열 | + **동적 배열** `[]`, **queue** `[$]`, **연관 배열** `[key]` |
| OOP | 없음 | `class`, 상속, 다형성, `new` 동적 할당 |
| 랜덤 | `$random` (제약 없음) | `rand` / `randc` + `constraint` + `randomize()` |
| 포트 묶음 | 포트 하나하나 연결 | `interface`, `modport`, clocking block |
| always 블록 | `always` 하나로 다 표현 | `always_comb`, `always_ff`, `always_latch` (의도 명시 → 툴이 검사) |
| 프로세스 동기화 | `fork…join` | + `join_any`, `join_none`, `event` 강화, `mailbox`, `semaphore` |
| 검증 기능 | 없음 | **assertion** (SVA), **functional coverage** (`covergroup`) |
| 연산자/문법 | 기본 | `++`, `+=`, `inside`, `unique`/`priority case`, `foreach` 등 |
| 패키지 | 없음 (`include` 사용) | `package` / `import` |
| 시뮬 스케줄 | Active / Inactive / NBA 중심 | + Observed, **Reactive** (program) 등 region 추가 |

### 4-1. 4-state 값 (★ 진리표 꼭 보기)

| 값 | 의미 | 언제 생기나 |
|---|---|---|
| `0` | 논리 0 | — |
| `1` | 논리 1 | — |
| `X` | unknown (알 수 없음) | 초기화 안 된 `logic`/`reg`, 다중 드라이버 충돌(0 vs 1) |
| `Z` | high-impedance (연결 끊김) | 아무도 구동 안 하는 `wire`, tri-state 출력 |

> 연산 입력으로 들어가면 **Z는 X처럼 취급**된다.

### 4-2. 진리표

**AND (`&`)** — 0이 하나라도 있으면 무조건 0

| & | 0 | 1 | X | Z |
|---|---|---|---|---|
| **0** | 0 | 0 | 0 | 0 |
| **1** | 0 | 1 | X | X |
| **X** | 0 | X | X | X |
| **Z** | 0 | X | X | X |

**OR (`\|`)** — 1이 하나라도 있으면 무조건 1

| \| | 0 | 1 | X | Z |
|---|---|---|---|---|
| **0** | 0 | 1 | X | X |
| **1** | 1 | 1 | 1 | 1 |
| **X** | X | 1 | X | X |
| **Z** | X | 1 | X | X |

**XOR (`^`)** — X/Z가 하나라도 있으면 무조건 X

| ^ | 0 | 1 | X | Z |
|---|---|---|---|---|
| **0** | 0 | 1 | X | X |
| **1** | 1 | 0 | X | X |
| **X** | X | X | X | X |
| **Z** | X | X | X | X |

**NOT (`~`)**

| 입력 | 0 | 1 | X | Z |
|---|---|---|---|---|
| **출력** | 1 | 0 | X | X |

### 4-3. 검증할 때 주의점

| 상황 | 결과 | 포인트 |
|---|---|---|
| `==` / `!=` 에 X·Z 포함 | 결과가 **X** | `if (X)`는 **거짓**으로 처리 → else로 빠짐 (FAIL을 PASS로 착각 가능) |
| `===` / `!==` | X·Z까지 **정확히 비교** → 항상 0 또는 1 | scoreboard에서 X 검출하려면 `===` 사용 |
| 4-state → 2-state 대입 (`logic` → `bit`) | X·Z가 **0으로 바뀜** | X가 숨어버려 버그를 못 찾음 |
| reset 전 레지스터 | 출력이 **X** | register 실습에서 reset을 먼저 거는 이유 |

---

## 5. 배열 자료형 & queue

### 5-1. 배열 4종 비교

| 종류 | 선언 예 | 크기 | 특징 / 용도 |
|---|---|---|---|
| 고정 배열 | `byte arr[8];` | 컴파일 시 고정 | Verilog와 동일 |
| 동적 배열 | `byte arr[];` | `new[n]`으로 실행 중 지정 | 크기 바꾸려면 다시 `new` |
| **queue** | `byte queue[$];` | **자동으로 늘고 줄음** | FIFO/스택, scoreboard 기댓값 저장 |
| 연관 배열 | `byte arr[int];` | 쓴 인덱스만 메모리 사용 | 메모리 모델처럼 듬성듬성한 주소 |

### 5-2. queue 메서드

| 메서드 | 동작 |
|---|---|
| `push_back(x)` | 뒤에 넣기 |
| `push_front(x)` | 앞에 넣기 |
| `pop_front()` | 앞에서 꺼내기 (FIFO) |
| `pop_back()` | 뒤에서 꺼내기 (스택) |
| `size()` | 원소 개수 |
| `insert(i, x)` / `delete(i)` | i번째에 삽입 / 삭제 (`delete()`는 전체 삭제) |
| `q[0]`, `q[$]` | 첫 원소 / 마지막 원소 |

### 5-3. queue vs mailbox

| 구분 | queue | mailbox |
|---|---|---|
| 정체 | 자료형 (배열) | class (통신 객체) |
| 비었을 때 꺼내면 | 대기 X (경고 + 기본값) | `get()`은 **대기** (blocking) |
| 용도 | 한 컴포넌트 **내부** 저장 | 컴포넌트 **간** 통신·동기화 |

---

## 6. 왜 fork-join + event인가 (IPC)

### 6-1. 핵심 아이디어

| 질문 | 답 |
|---|---|
| 왜 `fork-join`? | 객체(gen/drv/mon/scb)별로 **병렬화**해서 각자 독립적으로 동작시키기 위해 |
| 왜 event 제어? | 병렬 프로세스끼리 **제어권(이벤트)** 을 주고받아야 순서·타이밍이 맞음 |
| 이걸 뭐라고 부르나? | **IPC** (Inter-Process Communication, 프로세스 간 통신) |

### 6-2. IPC 방식 비교

| 방식 | 원리 | SV / UVM 예 |
|---|---|---|
| 메시지 전달 | 데이터를 **보내고 받음** | `mailbox` |
| 동기화 신호 | 데이터 없이 **"지금이야"** 만 알림 | `event` (+ `semaphore`) |
| shared memory | **key 값을 공유**해서 같은 저장소에 접근 | UVM `config_db` — 객체 관리를 **DB**로 함 |

| UVM에서 달라지는 점 | 내용 |
|---|---|
| 프레임워크가 해주는 것 | 객체 생성·연결·관리 (DB, factory, phase) |
| **우리가 할 것** | **시나리오**(sequence)와 **타이밍** 설계 |

> `fork … join_none` 동작은 1104 [6-2. 3종 비교](#6-2-3종-비교) 참고

---

## 7. 실습 — 8-bit register 검증

### 7-1. 목표 & 핵심 포인트

| 항목 | 내용 |
|---|---|
| DUT | 8-bit register (`posedge clk`에서 D → Q) |
| 핵심 | **D 읽는 시점**과 **Q 읽는 시점**을 다르게 해서 scoreboard에서 비교 |
| 기댓값 전달 | expected data(D) → **mailbox**로 scoreboard에 전달 |
| 주의 | 시뮬레이션 **race condition** — clk 기반이면 drv/mon의 **시점 결정**이 핵심 |
| reset | **reset task**를 따로 만들어 두면 reset 기능을 분리 → 재사용 가능 |

### 7-2. drv / mon 타이밍

| 주체 | 시점 | 이유 |
|---|---|---|
| driver | **상승 엣지** 이후 D 인가 | 엣지와 **같은 순간**에 D를 바꾸면 DUT가 새 값/이전 값 중 뭘 잡을지 race |
| monitor (D) | driver 인가 직후 | 이 값이 **기댓값** (1 clk 뒤 Q로 나와야 함) |
| monitor (Q) | **다음 상승 엣지** 이후 | register는 1 clk 지연 → 그때 Q가 확정됨 |
| scoreboard | 기댓값(D) vs 실제값(Q) 비교 | 같으면 PASS, 다르면 FAIL |

---

## 8. 면접 / 복습 포인트

| 질문 | 한 줄 답 |
|---|---|
| IPC란? 예시는? | 병렬 프로세스 간 통신 — `mailbox`, `event`, `semaphore`, shared memory(`config_db`) |
| clk 기반 TB에서 race를 피하려면? | drv는 엣지 이후 인가, mon은 확정된 시점에 샘플 (또는 clocking block) |
| register 검증에서 D·Q 읽는 시점이 다른 이유? | Q는 D보다 **1 clk 늦게** 나오기 때문 |
| OOP 4대 특징? | 캡슐화 · 추상화 · 상속 · 다형성 |
| 상속과 다형성 키워드? | `extends` / `virtual` 메서드 |
| CRV의 장단점? | 구축 후 빠르고 많은 케이스 / setup 시간 · corner case 도달 어려움 |
| corner case는 어떻게 잡나? | coverage로 구멍 확인 → constraint 조정 or directed test 추가 |
| UVM을 쓰는 이유? | 검증 환경 **표준화** → 팀·프로젝트 간 재사용 |
| sequencer 역할? | 여러 sequence의 item을 중재해서 driver로 전달 |
| factory란? | class 등록 후 코드 수정 없이 교체 생성하는 등록 관리자 |
| `logic` vs `wire`/`reg`? | `logic`은 둘을 통합 (단, 다중 드라이버는 `wire` 필요) |
| 2-state vs 4-state? | `bit`(0,1) / `logic`(0,1,X,Z) — 2-state는 빠르지만 X 검출 불가 |
| 동적 배열 vs queue? | 크기를 `new`로 지정 / 자동으로 늘고 줄음 |
| `1 & X`, `0 & X`, `1 \| X`? | X / **0** / **1** — 결과를 확정하는 값(AND의 0, OR의 1)이 있으면 X여도 결정됨 |
| `==` vs `===`? | X·Z 있으면 `==`는 X(if에서 거짓) / `===`는 X·Z까지 정확 비교 |




1106 수업































