# merge_final v2 (B-2 · B-3 수정판, 10/31)

- `merge_final_v2/` = `FINAL/source_file/merge_final` (v1) 전체 복사 + **2 파일만 수정**
  - `merge_final_top.v` 송신 MUX 2 줄 (거리 · 온습도 상태 비트 같이 싣기)
  - `UART/sender_char_mux.v` (오류면 `Err N`, 온습도 첫 측정 전 `--%--C`)
- v1 ↔ v2 바뀐 줄만 : `merge_final_v1_vs_v2.diff`
- 설명 : `5_수정내용_B2B3.md` (html 같은 내용)
- 직접 비교 : 저장소 맨 위에서 `git diff --no-index FINAL/source_file/merge_final boyun/fix_b2b3_1031/merge_final_v2`
