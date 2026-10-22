#!/bin/bash
# Панель для вебінару: в одному вікні видно команди агентів, обмін із радником і стан.
# Запуск на ХОСТІ з теки проєкту:  ./demo-watch.sh
cd "$(dirname "$0")"
exec tail -n +1 -F \
  work/logs/commands.log \
  work/advice/logs/activity.log \
  work/state/notes.md \
  work/state/findings.md
