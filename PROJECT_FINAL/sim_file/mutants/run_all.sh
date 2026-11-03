#!/bin/bash
# mutants/list.txt 의 버그마다 run_mutant.bat 실행 (3 개씩 동시에) → mutants/logs/<ID>.log
# WSL 에서 실행 : bash mutants/run_all.sh  (sim_file 위치는 스크립트 위치로 자동 계산)
cd "$(dirname "$0")"
MUT_WIN=$(wslpath -w "$(pwd)")
export MUT_WIN
mkdir -p logs
run1() { set -- $1 $2 $3; cmd.exe /c "cd /d $MUT_WIN && run_mutant.bat $1 $2 $3" > logs/$1.log 2>&1; echo "$1 done: $(grep -a 'SUMMARY' logs/$1.log | tail -1)"; }
export -f run1
cat list.txt | xargs -P 3 -I{} bash -c 'run1 {}'
echo ALL_DONE
