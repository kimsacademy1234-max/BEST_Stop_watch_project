#!/usr/bin/env bash
# =============================================================================
# run.sh — TB 하나 실행 (verification_plan.md)
#   ./tb/run.sh <tb_name|tb경로> [--sim verilator|icarus] [--src <dir>] [--phase N] [--wave] [--out <dir>] [--plus "+a=1 +b=2"] [--build-only]
#   --build-only : 컴파일(빌드)만 하고 실행하지 않음 (verification_plan.md)
#   항상 verification/ 에서 실행. 기본: verilator, ../boyun/merged_v4/src, 모든 Phase, 파형 없음
#   --src 의 stopwatch_watch.v 에 sw_fault 포트가 없으면 NO_SW_FAULT 자동 정의 (결함 TB 를 원본 src 로 돌릴 때)
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

TB="${1:?usage: ./tb/run.sh <tb_name|path> [--sim verilator|icarus] [--src dir] [--phase N] [--wave] [--out dir]}"
shift
SIM=verilator
SRC=../boyun/merged_v4/src
PHASE=""
WAVE=0
OUT=""
PLUS=""
BUILD_ONLY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --sim)   SIM="$2"; shift 2 ;;
        --src)   SRC="$2"; shift 2 ;;
        --phase) PHASE="$2"; shift 2 ;;
        --wave)  WAVE=1; shift ;;
        --out)   OUT="$2"; shift 2 ;;
        --plus)  PLUS="$2"; shift 2 ;;
        --build-only) BUILD_ONLY=1; shift ;;
        *) echo "unknown option $1"; exit 2 ;;
    esac
done

# TB 파일 찾기
if [ -f "$TB" ]; then
    TBFILE="$TB"
else
    TBFILE=$(find tb defect_* -name "${TB%.sv}.sv" 2>/dev/null | head -1 || true)
fi
[ -n "${TBFILE:-}" ] && [ -f "$TBFILE" ] || { echo "TB not found: $TB"; exit 2; }
TOP=$(basename "$TBFILE" .sv)

# src 태그: 원본이면 orig, 아니면 결함 폴더 이름
SRC_ABS=$(cd "$SRC" && pwd)
ORIG_ABS=$(cd ../boyun/merged_v4/src && pwd)
if [ "$SRC_ABS" = "$ORIG_ABS" ]; then TAG=orig; else TAG=$(basename "$(dirname "$SRC_ABS")"); fi

# 결함 TB(F1/F2/F4)는 파일 안에서 HAS_SW_FAULT 를 켠다 → 원본 src(sw_fault 포트 없음)로 돌릴 때만 끔
DEFS=""
if ! grep -q "sw_fault" "$SRC/stopwatch_watch.v"; then DEFS="+define+NO_SW_FAULT"; fi

[ -n "$OUT" ] || OUT="results/$TOP"
[ "$TAG" = "orig" ] || [ "$OUT" != "results/$TOP" ] || OUT="results/${TOP}__${TAG}"
mkdir -p "$OUT"
LOG="$OUT/sim.log"

ARGS="+src=$TAG $PLUS"
[ -n "$PHASE" ] && ARGS="$ARGS +phase=$PHASE"

SRCS=$(ls "$SRC"/*.v "$SRC"/*.sv 2>/dev/null)
EXTRA=$(dirname "$TBFILE")
# 결함 폴더 TB 는 그 폴더의 보조 .sv/.v(주입기 모델 등)도 같이 읽는다
EXTRA_SRCS=$(ls "$EXTRA"/*_model.v 2>/dev/null || true)

echo "== $TOP | sim=$SIM | src=$SRC ($TAG) | out=$OUT | $(date '+%F %T')"
T0=$(date +%s)
if [ "$SIM" = "verilator" ]; then
    [ "$WAVE" = 1 ] && echo "note: --wave 는 Icarus 전용 (verification_plan.md). Verilator 는 로그만"
    verilator --binary --timing -j 0 -Wno-fatal -Wno-lint -Wno-style -Wno-MULTIDRIVEN \
        --top-module "$TOP" $DEFS \
        "$TBFILE" "$(dirname "$TBFILE")/fnd_monitor.sv" $EXTRA_SRCS $SRCS \
        --Mdir "$OUT/obj" -o sim > "$OUT/build.log" 2>&1 || { tail -n 30 "$OUT/build.log"; echo "== BUILD FAIL"; exit 1; }
    if [ "$BUILD_ONLY" = 1 ]; then echo "== BUILD OK: $OUT/obj/sim (run: $OUT/obj/sim $ARGS)"; exit 0; fi
    "$OUT/obj/sim" $ARGS 2>&1 | tee "$LOG"
else
    IDEFS=${DEFS//+define+/-D}
    [ "$WAVE" = 1 ] && ARGS="$ARGS +wave=$OUT/wave.vcd"
    iverilog -g2012 $IDEFS -s "$TOP" -o "$OUT/sim.vvp" \
        "$TBFILE" "$(dirname "$TBFILE")/fnd_monitor.sv" $EXTRA_SRCS $SRCS > "$OUT/build.log" 2>&1 || { tail -n 30 "$OUT/build.log"; echo "== BUILD FAIL"; exit 1; }
    if [ "$BUILD_ONLY" = 1 ]; then echo "== BUILD OK: $OUT/sim.vvp (run: vvp -n $OUT/sim.vvp $ARGS)"; exit 0; fi
    vvp -n "$OUT/sim.vvp" $ARGS 2>&1 | tee "$LOG"
fi
echo "== wall $(( $(date +%s) - T0 )) s"
