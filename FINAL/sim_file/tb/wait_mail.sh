#!/usr/bin/env bash
# 사용법 : tb/wait_mail.sh mailbox/LEAD_to_W1.md [더 볼 파일 ...]
#   지정한 파일 중 하나라도 바뀌면 (크기 · 수정 시각) 바뀐 파일 이름과 마지막 30 줄을 출력하고 끝난다.
#   백그라운드로 실행해 두면 메시지가 왔을 때 알림을 받는다. (/mnt/d 는 inotify 가 안 돼서 15 초 폴링)
cd "$(dirname "$0")/.."
declare -A base
for f in "$@"; do base[$f]="$(stat -c '%s %Y' "$f" 2>/dev/null || echo none)"; done
while true; do
    for f in "$@"; do
        now="$(stat -c '%s %Y' "$f" 2>/dev/null || echo none)"
        if [ "$now" != "${base[$f]}" ]; then
            echo "[MAIL] $f 변경됨 ($(date '+%H:%M:%S'))"
            tail -n 30 "$f"
            exit 0
        fi
    done
    sleep 15
done
