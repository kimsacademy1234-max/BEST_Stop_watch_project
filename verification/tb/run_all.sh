#!/usr/bin/env bash
# =============================================================================
# run_all.sh — 전체 회귀 (verification.md §6, §9)
#   P0 → P1 순서로 전부 Verilator 실행 (병렬 JOBS 개), 끝에 results/summary.md 생성
#   ./tb/run_all.sh [JOBS]      기본 JOBS = 8
#   결함 TB 는 원본 src(orig) / 결함 src(fault) 두 번 실행 (F3 는 src 무변경이라 orig 만)
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."
JOBS="${1:-8}"

P0=(
  "tb_top_1_btn_debounce"
  "tb_top_2_fnd_scan"
  "tb_wt_2_rollover"
  "tb_sw_1_run_stop_clear"
  "tb_tm_1_add_cap"
  "tb_f1_com_skew --out results/defect_1/orig"
  "tb_f1_com_skew --src defect_1_fnd_com_skew/src --out results/defect_1/fault"
  "tb_f2_chatter --out results/defect_2/orig"
  "tb_f2_chatter --src defect_2_switch_chatter/src --out results/defect_2/fault"
  "tb_f4_reset_glitch --out results/defect_4/orig"
  "tb_f4_reset_glitch --src defect_4_reset_glitch/src --out results/defect_4/fault"
  "tb_f3_press_timing --out results/defect_3/orig"
)
P1=(
  "tb_wt_1_set_ui"
  "tb_wt_3_display_12h"
  "tb_sw_2_rollover_updown"
  "tb_sw_3_lap"
  "tb_tm_2_countdown_alarm"
  "tb_tm_3_cancel_background"
)

T0=$(date +%s)
echo "== run_all: ${#P0[@]} P0 + ${#P1[@]} P1 jobs, $JOBS parallel"
printf '%s\n' "${P0[@]}" "${P1[@]}" | xargs -P "$JOBS" -I{} sh -c './tb/run.sh {} > /dev/null 2>&1; echo "done: {}"'
python3 tb/summarize.py
echo "== run_all wall $(( $(date +%s) - T0 )) s → results/summary.md"
