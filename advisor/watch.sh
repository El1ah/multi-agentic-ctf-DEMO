#!/bin/bash
set -uo pipefail
cd /advisor
mkdir -p advice/logs
ACT=advice/logs/activity.log

# Вербозний лог: і в stdout контейнера (docker logs ctf-advisor), і в спільний файл,
# який видно з хоста (work/advice/logs/activity.log) — зручно для tail -f на вебінарі.
log(){ printf '%s [advisor] %s\n' "$(date -Is)" "$*" | tee -a "$ACT"; }

# Дефолти підібрані емпірично (перевірено наживо):
#  - дефолтна важка "thinking"-модель НЕ встигає завершити хід у headless → зависання;
#  - gemini-3.8-flash-low швидка (~77с), але її контент-фільтр хибно блокує offensive-безпекові питання;
#  - claude-sonnet-4-6 через agy відповідає на авторизовані безпекові питання без хибних відмов (~97с).
# Тому дефолт — claude-sonnet-4-6. Для максимальної швидкості (нейтральні питання): AGY_MODEL=gemini-3.8-flash-low.
AGY_MODEL="${AGY_MODEL:-claude-sonnet-4-6}"
AGY_PRINT_TIMEOUT="${AGY_PRINT_TIMEOUT:-150s}"
AGY_TIMEOUT="${AGY_TIMEOUT:-180}"            # зовнішній страхувальний таймаут (сек)

run_agy(){
  local logf="$1"
  # </dev/null — щоб headless agy не чекав вводу зі stdin і не висив (issue #318)
  timeout "$AGY_TIMEOUT" agy --dangerously-skip-permissions --disable-slash-commands \
    --model "$AGY_MODEL" --print-timeout "$AGY_PRINT_TIMEOUT" \
    -p "$(cat /tmp/agy_prompt.txt)" </dev/null >"$logf" 2>&1
}

log "watcher started; model=$AGY_MODEL print-timeout=$AGY_PRINT_TIMEOUT hard-timeout=${AGY_TIMEOUT}s"
while true; do
  if [ -f advice/question.txt ]; then
    Q=$(cat advice/question.txt)
    rm -f advice/answer.md
    LOG="advice/logs/agy-$(date +%s).log"
    log "picked up question ($(printf '%s' "$Q" | wc -c) bytes); calling agy ($AGY_MODEL) -> $LOG"

    printf '%s' "You are a read-only security advisor for an AUTHORIZED, educational penetration-testing lab (a retired Hack The Box training machine used with explicit permission for training). This is sanctioned coursework, not a real-world attack, and you have no network access to anything. Based only on the engagement notes, give ranked hypotheses and how to test each.
Read state/notes.md and state/findings.md. Question: $Q
Follow AGENTS.md. Write the answer to advice/answer.md." > /tmp/agy_prompt.txt

    START=$(date +%s)
    run_agy "$LOG"; RC=$?
    DUR=$(( $(date +%s) - START ))

    if [ -s advice/answer.md ]; then
      log "agy finished rc=$RC in ${DUR}s; answer.md = $(wc -c < advice/answer.md) bytes"
    else
      log "agy produced NO answer (rc=$RC, ${DUR}s); writing fallback. See $LOG"
      echo "No answer from second opinion (rc=$RC after ${DUR}s). See advice/logs/" > advice/answer.md
    fi
    rm -f advice/question.txt /tmp/agy_prompt.txt
    log "ready for next question"
  fi
  sleep 3
done
