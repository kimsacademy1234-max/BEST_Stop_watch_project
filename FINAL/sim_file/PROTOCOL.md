# merge_final_top TB 병렬 검증 — 협업 프로토콜

작업 폴더 : `FINAL/sim_file/` (이 파일이 있는 곳). 모든 경로는 여기 기준.
대상 설계 : `../source_file/merge_final/merge_final_top.v` — **읽기 전용, 절대 수정 금지**.
시나리오 : `tb_scenario.md` (92 시나리오 · 305 확인) — **읽기 전용**.

---

## 1. 역할 · 담당

| 세션 | 역할 | 담당 그룹 | 시나리오 · 확인 수 | 실시간 길이 |
|---|---|---|---|---|
| **LEAD** | 분배 · 공통 환경 · 질문 답변 · 결과 취합 | — | — | — |
| **W1** | UART | C (모드 선택), G (UART 수신 · 디코더), H (UART 컨트롤러 · 전송) | 29 · 113 | ≈ 27 s |
| **W2** | WTS · 표시 | A (리셋), B (버튼), D (스톱워치), E (시계), F (타이머), K (FND · LED) | 32 · 110 | ≈ 26 s |
| **W3** | 센서 · 통합 | I (SR04), J (DHT11), L (통합 · 교차) | 31 · 82 | ≈ 53 s |

- 작업자는 **자기 그룹만** 쓴다. 다른 그룹 시나리오가 필요해 보이면 LEAD 에게 QUESTION.
- 작업 순서 권장 : 각자 P1 → P2 → P3. 길이가 긴 시나리오 (H4 · H5 · F1 · J11 · L4 등) 는 먼저 짜서 백그라운드로 돌려 놓고, 도는 동안 다음 TB 를 쓴다.

---

## 2. 파일 · 폴더 (누가 쓰는가)

| 경로 | 내용 | 쓰는 사람 |
|---|---|---|
| `PROTOCOL.md` | 이 문서 | LEAD |
| `tb_scenario.md` | 시나리오 원본 | 아무도 안 씀 (기대값이 틀려 보이면 QUESTION) |
| `tb/common/tb_env.svh` | 공통 환경 (DUT · BFM · 모니터 · 센서 모델 · 스코어보드) | **LEAD 만** — 기능이 더 필요하면 REQUEST |
| `tb/run_tb.sh` | Verilator 빌드 + 실행 스크립트 | LEAD |
| `tb/wait_mail.sh` | 메일박스 바뀔 때까지 대기 | LEAD |
| `tb/collect.py` | 결과 취합 → `results/SUMMARY.md` | LEAD |
| `tb/W1/` `tb/W2/` `tb/W3/` | 작업자 TB (`tb_<ID>.sv`) | 그 작업자만 |
| `results/W1/` … `W3/` | 시뮬 로그 (`tb_<ID>.log`) + `progress.md` | 그 작업자만 |
| `results/SUMMARY.md` | 최종 취합 | LEAD |
| `mailbox/LEAD_to_Wn.md` | LEAD → 작업자 n | LEAD |
| `mailbox/Wn_to_LEAD.md` | 작업자 n → LEAD | 작업자 n |

- 메일박스는 **이어쓰기 (append) 만**. 지난 메시지 수정 · 삭제 금지 (상태 줄 추가만 허용, 아래 4 장).
- 파일 하나에 쓰는 사람은 한 명 → 동시에 써도 충돌 없음.

---

## 3. 절대 규칙

1. **시간 단축 금지** — `defparam` · 파라미터 오버라이드 · 클럭 변경 금지. 전부 실제 100 MHz · 실제 시간 기준. (`tb_scenario.md` 3-3 장 "시뮬 시간 단축" 표는 **쓰지 않는다**. 3-2 장 허용 오차는 그대로 쓴다.)
2. **설계 소스 수정 금지**. FAIL 이 나와도 고치지 말고 RESULT 로 보고 (시각 · 로그 줄 첨부).
3. **기대값 임의 수정 금지**. 문서의 예상 결과는 코드를 읽고 계산한 값이라 틀릴 수 있다. 시뮬 결과가 다르면 ① 내 TB 실수인지 먼저 확인 → ② 그래도 다르면 QUESTION 으로 근거 (코드 줄 · 파형 시각) 와 함께 LEAD 에게. LEAD 가 "설계 FAIL" 인지 "문서 기대값 수정" 인지 판정한다.
4. `force` 는 `tb_scenario.md` 3-3 장 마지막 줄의 경로 (`counter_reg`, `w_phy_btn_*`) 와 시나리오에 force 라고 적힌 곳에서만. 레지스터는 force 1 clk → release.
5. **커밋 · 푸시 금지** (사용자 승인 사항). 서브에이전트 · 다른 세션 띄우기 금지.
6. 시뮬은 **작업자당 동시에 최대 2 개** (메모리 7 GB 를 4 세션이 나눠 씀).
7. 다른 작업자 폴더 · 공통 파일을 고치지 않는다.

---

## 4. 메시지 형식

```
## [MSG-<보낸이>-<번호>] <보낸이>→<받는이> | <YYYY-MM-DD HH:MM> | <PLAN | QUESTION | ANSWER | REQUEST | RESULT | BLOCKER | DONE>
- 대상: <시나리오 ID / 파일 경로>
- 내용: ...
- 요청 조치: ...
- 상태: OPEN
```

- 번호 : LEAD = `MSG-L-001` …, 작업자 = `MSG-W1-001` … (각자 1 부터).
- 받은 쪽이 처리하면 **자기 메일박스 (보내는 파일)** 에 회신을 쓰고, 회신 안에 `- 회신 대상: MSG-xx-nnn` 을 적는다. 원래 메시지는 건드리지 않는다.
- 종류
  - `QUESTION` 기대값 · 해석이 애매함 / 문서와 시뮬이 다름 → LEAD 답 `ANSWER`
  - `REQUEST` `tb_env.svh` 에 기능 추가 요청 (예 : 새 센서 옵션) → LEAD 가 추가 후 `ANSWER`
  - `RESULT` 중간 결과 (그룹 하나 끝날 때마다, 예상 밖 FAIL 은 바로)
  - `BLOCKER` 빌드가 안 됨 · 시뮬 hang 등 진행 불가
  - `DONE` 담당 전부 끝 = **완료 신호** (아래 7 장 형식)
- 답을 기다리는 동안 그 시나리오는 미뤄 두고 다음 시나리오를 진행한다 (멈추지 말 것).

### 메일 확인 타이밍

- 작업 시작 때, TB 하나 쓸 때마다, 시뮬 결과 볼 때마다 `mailbox/LEAD_to_<나>.md` 에서 아직 회신 안 한 LEAD 메시지를 확인.
- 할 일이 없어 기다려야 하면 `tb/wait_mail.sh mailbox/LEAD_to_<나>.md` 를 **백그라운드**로 실행 (파일이 바뀌면 끝나서 알림이 온다).

---

## 5. TB 작성 규칙

- 파일 : `tb/<나>/tb_<ID>.sv` (예 `tb/W1/tb_G1.sv`), **모듈 이름 = 파일 이름**. 시나리오 하나에 파일 하나.
- 틀 :

```systemverilog
`timescale 1ns / 1ps
// <ID>. <시나리오 이름> — <P> · <개수> 개   (tb_scenario.md 4 장 <ID>)
// 스티뮬러스 / 확인 요약 몇 줄
module tb_G1;
    `include "tb_env.svh"
    string s;
    bit    ok;
    initial begin
        env_start("tb_G1", 2 * SEC);       // 워치독 = 예상 길이의 1.5 ~ 2 배
        ...
        check("G1-01", <조건>, $sformatf("기대 ... / 실제 ...", ...));
        ...
        env_finish();
    end
endmodule
```

- 확인 ID : `<시나리오>-<두 자리 번호>` (`G1-01` … `G1-24`). **check 개수 = 문서의 "개수"** 와 맞출 것. 다르게 할 이유가 있으면 RESULT 에 적는다.
- ⚠ 항목 (문서 2 장) 은 `check_known(ID, 스펙대로면 1, msg)` → `[KNOWN]` / `[XPASS]`.
- 판정 없는 기록 (H9 개수 · L6 스냅샷) 은 `info`.
- msg 에는 **기대값과 실제값을 둘 다** 넣는다 (로그만 보고 판단 가능하게).
- 시간 비교는 `US` `MS` `SEC` 상수와 `tb_scenario.md` 3-2 장 허용 오차로. 숫자 하드코딩 대신 의미 있는 `localparam` 사용.
- Verilator 5.032 + Vivado xsim 2020.2 둘 다 되는 문법만 (클래스 · 랜덤 제약 · `program` · interface 쓰지 말 것). `$urandom` 은 OK (L5 · L4 는 시드 고정 `$urandom(<seed>)` 한 번).
- 공통 환경에서 쓸 수 있는 것은 `tb/common/tb_env.svh` 머리 주석과 본문 참고 (아래 6 장 요약).

---

## 6. 공통 환경 요약 (`tb_env.svh`)

| 분류 | 이름 | 설명 |
|---|---|---|
| 상수 | `US` `MS` `SEC` `CLK_NS` `UART_BIT_NS` | ns 단위. `UART_BIT_NS` = 104,160 (DUT 실제) |
| 핀 | `rst` `btn_*` `mode_sw0` … `dist_led_sw15` `rx` `echo` / `tx` `trig` `dht11_io` `fnd_com` `fnd_font` `led` | 이름 = Top 포트 이름. DUT 인스턴스 = `dut` |
| 시작 | `env_start(name, timeout)` | 워치독 + 리셋 1 us (해제 후 3 clk 대기) |
| | `env_reset(dur)` | 언제든 리셋 (A2 · L5) |
| | `env_finish()` | `[SUMMARY]` 출력 후 종료 |
| | `set_sw(7'b…)` · `wait_clk(n)` | {sw6 … sw0} |
| 판정 | `check` · `check_known` · `info` | `[PASS]/[FAIL]`, `[KNOWN]/[XPASS]`, `[INFO]` |
| 버튼 | `press("R", dur, gap)` | 물리 핀, 기본 20 ms 누름 + 20 ms 대기 |
| | `bounce("R", n, step, level)` | 채터링 |
| | `pulse_phy("R")` | `dut.w_phy_btn_R` 1 clk force (정밀 타이밍) |
| | `cnt_btn_R` … `t_btn_R` … | 게이팅 전 실제 버튼 펄스 (물리 \| UART) 개수 · 마지막 시각 |
| UART 송신 | `uart_send_byte(b, stop_bit)` · `uart_send_str(s, gap)` | `uart_tx_bit_ns` 바꾸면 baud 오차 시험 |
| | `rx_done_cnt` · `rx_done_t` | DUT `w_rx_done` 개수 · 마지막 시각 |
| UART 수신 | `uart_lines[$]` `uart_line_t0[$]` `uart_line_t1[$]` | 줄 내용 (CR LF 뺌) · 첫 바이트 start · LF 끝 |
| | `uart_clear()` · `uart_wait_lines(n, timeout, ok)` | |
| | `uart_byte_cnt` · `uart_frame_err` · `uart_last_byte_t0` | |
| SR04 모델 | `sr04_mode` (0 끔 / 1 정상 / 2 응답 없음) · `sr04_dly_us` · `sr04_echo_us` | 0 이면 TB 가 `echo` 직접 구동 |
| | `sr04_trig_cnt` · `sr04_trig_rise_t` · `sr04_trig_fall_t` · `sr04_echo_fall_t` | |
| DHT11 모델 | `dht_mode` (0 응답 없음 / 1 정상) · `dht_hum_i` `dht_hum_d` `dht_tmp_i` `dht_tmp_d` | 기본 55 % · 24 ℃ |
| | `dht_chk_ofs` · `dht_hi0_us` · `dht_hi1_us` · `dht_stop_after` · `dht_resp_dly_us` · `dht_stuck_low` | 오류 · 경계 시험 |
| | `dht_start_cnt` · `dht_start_fall_t` · `dht_start_rise_t` · `dht_resp_end_t` | |
| FND | `fnd_get(s)` | 새로 한 바퀴 모은 표시 문자열 ("55.24", "Err1", "----", 빈칸 = ' ') |
| | `fnd_text()` | 지금 모인 문자열 (기다리지 않음) |

- 리셋 직후 상태 : 스위치 전부 0 = 시계 초.1/100 화면, FND `00.00`, LED `0x8009` (스모크 테스트로 확인됨).
- 내부 신호는 `dut.` 계층으로 직접 봐도 된다 (예 `dut.w_disp_sel`, `dut.U_UART.w_rx_done`, `dut.U_WTS.U_STOPWATCH_DATAPATH...`). 계층 이름은 `../README.md` 1 장 "계층 (인스턴스 이름)" 참고.

---

## 7. 실행 · 완료

```bash
tb/run_tb.sh tb/W1/tb_G1.sv              # 빌드 (~/stw_build/tb_G1) + 실행 → results/W1/tb_G1.log
```

- 화면에는 `[FAIL]` 줄 · `[SUMMARY]` 줄 · `[WALL]` 만 나온다. 자세한 건 로그.
- 속도 : 실시간 1 s ≈ 벽시계 40 ~ 90 s. 10 s 넘는 시나리오는 **백그라운드**로 돌릴 것.
- 결과는 `results/<나>/progress.md` 에 표로 계속 갱신 :

```
| ID | 상태 | pass | fail | known | 벽시계 | 메모 |
|---|---|---|---|---|---|---|
| G1 | DONE | 24 | 0 | 0 | 95 s | |
| G7 | DONE | 1 | 0 | 1 | 40 s | ⚠ 재현 |
| G8 | WAIT-Q | | | | | MSG-W1-004 답 대기 |
```

  상태 : `TODO` → `WRITING` → `RUNNING` → `DONE` (또는 `WAIT-Q` 질문 대기 · `BLOCKED`)

### 완료 신호 (DONE)

담당 시나리오가 전부 `DONE` 이면 (질문 대기 중인 것 없이) 메일박스에 :

```
## [MSG-W1-0xx] W1→LEAD | 2026-10-31 18:00 | DONE
- 대상: C · G · H 전체 (29 시나리오)
- 내용: 확인 113 개 중 PASS n · FAIL n · KNOWN n · XPASS n. 예상 밖 FAIL 목록 : ...
- 요청 조치: 취합
- 상태: OPEN
```

DONE 뒤에도 LEAD 가 재실행 · 수정 요청을 보낼 수 있으니, 메일박스 대기 (`tb/wait_mail.sh`) 를 백그라운드로 걸어 두고 끝낸다.

LEAD 는 세 작업자의 DONE 을 받으면 `python3 tb/collect.py` 로 `results/SUMMARY.md` (시나리오별 PASS 표) 를 만든다.
