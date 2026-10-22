#!/bin/bash
set -uo pipefail
cd /work
Q="${1:?usage: second-opinion.sh \"question\"}"
mkdir -p advice
rm -f advice/answer.md
printf '%s\n' "$Q" > advice/question.tmp && mv advice/question.tmp advice/question.txt

# Прогрес — у stderr (видно на вебінарі), сама відповідь — у stdout (її бере оркестратор).
WAIT_STEPS="${SO_WAIT_STEPS:-80}"     # 80 * 5s = ~6.5 хв
echo "[second-opinion] питання передано раднику (advice/question.txt); чекаю відповідь..." >&2
for i in $(seq 1 "$WAIT_STEPS"); do
  if [ -f advice/answer.md ] && [ ! -f advice/question.txt ]; then
    echo "[second-opinion] відповідь отримано за $((i*5))s:" >&2
    echo "========================= ADVISOR (Antigravity/Gemini) =========================" >&2
    cat advice/answer.md
    echo "================================================================================" >&2
    exit 0
  fi
  [ $((i % 6)) -eq 0 ] && echo "[second-opinion] ще чекаю... $((i*5))s" >&2
  sleep 5
done
echo "No answer from second opinion in $((WAIT_STEPS*5))s. Is ctf-advisor running? See advice/logs/" >&2
exit 1
