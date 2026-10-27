#!/bin/sh
# Session-start check for agents (used as a Claude Code SessionStart hook; works from
# any tool). When this checkout has a line name (MAP_LINE, or set-line.sh), fetch the
# coordination branch and print a short summary of unread messages and active claims.
# Prints nothing and exits 0 when no line is set or there is no coordination branch.
# Ends with one line when a newer release exists upstream (UPGRADING.md: MAP_UPSTREAM,
# MAP_UPDATE_SECONDS, MAP_UPDATE_CHECK=0).
# Usage: session-start.sh [--json [hook]]
#   --json       print the summary as {"additionalContext": "..."} (GitHub Copilot hooks)
#   --json hook  print {"hookSpecificOutput": {"hookEventName": "SessionStart",
#                "additionalContext": "..."}} (Gemini CLI, Claude Code)
set -u
PROG=session-start.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

case "${1:-}" in
    -h | --help) sed -n '2,11s/^# \{0,1\}//p' "$0"; exit 0 ;;
    --json)
        # The same summary, as one JSON string; nothing at all when there is none. The
        # summary runs under the POSIX sh on PATH, like the hook that called this.
        summary=$(sh "$0") || exit 0
        [ -n "$summary" ] || exit 0
        text=$(printf '%s\n' "$summary" | LC_ALL=C awk '
            { gsub(/\r/, ""); gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t")
              gsub(/[\001-\010\013\014\016-\037]/, "") # other control characters
              out = (NR == 1) ? $0 : out "\\n" $0 }
            END { printf "%s", out }')
        if [ "${2:-}" = hook ]; then
            printf '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "%s"}}\n' "$text"
        else
            printf '{"additionalContext": "%s"}\n' "$text"
        fi
        exit 0 ;;
esac

git rev-parse --git-dir >/dev/null 2>&1 || exit 0
line=$(stored_line) || exit 0
case "$line" in "" | .* | *[!A-Za-z0-9.-]*) exit 0 ;; esac

# Fetch, but never hold up the session for long.
git fetch --quiet "$MAP_REMOTE" "+refs/heads/${MAP_BRANCH}:$(coordination_ref)" >/dev/null 2>&1 &
fetch_pid=$!
waited=0
while kill -0 "$fetch_pid" 2>/dev/null; do
    if [ "$waited" -ge "${MAP_FETCH_SECONDS:-10}" ]; then
        kill "$fetch_pid" 2>/dev/null
        stale=" (fetch timed out; showing the last fetched copy)"
        break
    fi
    sleep 1
    waited=$((waited + 1))
done
wait "$fetch_pid" 2>/dev/null
git rev-parse --verify --quiet "$(coordination_ref)" >/dev/null || exit 0

unread=$("${MAP_SCRIPT_DIR}/inbox.sh" --no-fetch "$line" 2>/dev/null)
unread_count=$(printf '%s' "$unread" | grep -c .)
claims=$(git ls-tree --name-only "$(coordination_ref)" claims/ | grep -v '/\.gitkeep$' | sed 's|^claims/||; s|\.md$||' | tr '\n' ' ')

printf 'Multi-Agent Protocol: this session is line "%s"%s.\n' "$line" "${stale:-}"
if [ "$unread_count" -gt 0 ]; then
    printf '%s unread coordination message(s):\n%s\n' "$unread_count" "$unread"
    # Listed here, so the plugin monitor (watch.sh) does not announce them again.
    { printf '%s\n' "$unread" >>"$(announced_store "$line")"; } 2>/dev/null
    printf 'Before other work, read them with %s/inbox.sh --show %s, handle each one, then run %s/mark-read.sh %s <message> (PROTOCOL.md 5.2, 5.3).\n' \
        "$MAP_SCRIPT_DIR" "$line" "$MAP_SCRIPT_DIR" "$line"
else
    printf 'No unread coordination messages.\n'
fi
[ -z "$claims" ] || printf 'Active claims: %s\n' "$claims"
update_notice
