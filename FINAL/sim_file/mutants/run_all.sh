#!/bin/bash
# mutants/list.txt 의 버그마다 run_mutant.bat 실행 (3 개씩 동시에) → mutants/<ID>.log
cd "$(dirname "$0")/.."
run1() { set -- $1 $2 $3; cmd.exe /c "cd /d C:\26_AI_CAMP\BEST_Stop_watch_project\FINAL\sim_file && run_mutant.bat $1 $2 $3" > mutants/$1.log 2>&1; echo "$1 done: $(grep -a 'SUMMARY' mutants/$1.log | tail -1)"; }
export -f run1
cat mutants/list.txt | xargs -P 3 -I{} bash -c 'run1 {}'
echo ALL_DONE
