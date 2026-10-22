#!/bin/bash
fail() { echo "Blocked: $1" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || fail "jq is missing, scope guard cannot check commands"
[ -n "${TARGET_IP:-}" ] || fail "TARGET_IP is not set"

CMD=$(jq -r '.tool_input.command // empty') || fail "cannot parse hook input"
ATTACKER_IP=$(ip -4 -o addr show tun0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
ALLOWED=" $TARGET_IP $ATTACKER_IP 127.0.0.1 0.0.0.0 "

if printf '%s' "$CMD" | grep -qE '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}'; then
  fail "network ranges are out of scope. Target a single host: $TARGET_IP"
fi
for ip in $(printf '%s' "$CMD" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u); do
  case "$ALLOWED" in
    *" $ip "*) ;;
    *) fail "$ip is out of scope. Only $TARGET_IP is allowed." ;;
  esac
done
exit 0
