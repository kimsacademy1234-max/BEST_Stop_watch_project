#!/usr/bin/env bash
# 사용법 : tb/run_tb.sh tb/W1/tb_G1.sv
#   Verilator 로 빌드 (build/<이름>/, WSL 리눅스 디스크) → 실행 → results/<W>/<이름>.log
#   마지막 [SUMMARY] 줄과 [FAIL] 줄을 화면에 출력
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"           # FINAL/sim_file
SRC="$ROOT/../source_file/merge_final"
TB="$(realpath "$1")"; shift || true
NAME="$(basename "$TB" .sv)"
WDIR="$(basename "$(dirname "$TB")")"               # W1 / W2 / W3 / LEAD
BUILD="${TB_BUILD_ROOT:-$HOME/stw_build}/$NAME"     # /mnt/d 는 느려서 리눅스 쪽에 빌드
LOG="$ROOT/results/$WDIR/$NAME.log"
mkdir -p "$BUILD" "$ROOT/results/$WDIR"

verilator --binary --timing -O3 -CFLAGS -O3 -Wno-fatal -Wno-lint -Wno-style -Wno-MULTIDRIVEN \
    -j 2 --top-module "$NAME" -I"$ROOT/tb/common" --Mdir "$BUILD" -o sim \
    "$TB" $(find "$SRC" -name '*.v' -o -name '*.sv' | sort) > "$BUILD/build.log" 2>&1 \
    || { echo "[BUILD-ERROR] $NAME (로그 : $BUILD/build.log)"; grep -m 20 -E "%Error" "$BUILD/build.log"; exit 2; }

START=$(date +%s)
"$BUILD/sim" "$@" > "$LOG" 2>&1 || true
END=$(date +%s)
echo "[WALL] $NAME $((END - START)) s" >> "$LOG"
grep -E "^\[(FAIL|SUMMARY|TBERR)\]" "$LOG" || echo "[NO-SUMMARY] $NAME — 로그 확인 : $LOG"
echo "[WALL] $NAME $((END - START)) s"
