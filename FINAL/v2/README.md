# FINAL v2 (B-2 · B-3 수정판, 10/31)

- 원본 (v1) : `FINAL/source_file/merge_final` — **손대지 않음**
- v2 소스 : `FINAL/v2/source_file/merge_final` = v1 전체 + **2 파일만 수정**
  - `merge_final_top.v` 송신 MUX 2 줄 (거리 · 온습도 상태 비트를 같이 실음)
  - `UART/sender_char_mux.v` (오류면 `Err N`, 온습도 첫 측정 전 `--%--C`)
- 비트 : `FINAL/v2/bit/merge_final_top_v2.bit` (Vivado 2022.2, LUT 1,489 · FF 737 · WNS +0.320 ns)
- 바뀐 줄만 : `merge_final_v1_vs_v2.diff`
- 설명 : `5_수정내용_B2B3.md` (html 같은 내용)

| 상황 | FND | v1 PC | v2 PC |
|---|---|---|---|
| 거리 Err2 · Err1 · Err3 | `Err2` · `Err1` · `Err3` | `400cm` · `000cm` · 직전 값 | `Err 2` · `Err 1` · `Err 3` |
| 온습도 첫 측정 전 | `----` | `00%00C` | `--%--C` |
| 온습도 오류 | `Err1` ~ `Err3` | 마지막 정상값 | `Err 1` ~ `Err 3` |
| 정상 | 숫자 | 숫자 | 숫자 (같음) |

직접 비교 : 저장소 맨 위에서 `git diff --no-index FINAL/source_file/merge_final FINAL/v2/source_file/merge_final`
