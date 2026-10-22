#!/bin/bash
mkdir -p "$CLAUDE_PROJECT_DIR/logs"
printf '%s\t%s\n' "$(date -Is)" "$(jq -r '.tool_input.command')" >> "$CLAUDE_PROJECT_DIR/logs/commands.log"
exit 0
