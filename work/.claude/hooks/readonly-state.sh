#!/bin/bash
fail() { echo "Blocked: $1" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || fail "jq is missing"
CMD=$(jq -r '.tool_input.command // empty') || fail "cannot parse hook input"
if printf '%s' "$CMD" | grep -qE 'state/|notes\.md|findings\.md'; then
  fail "verifier must not touch state/ from Bash. Use the Read tool and return your verdict."
fi
exit 0
