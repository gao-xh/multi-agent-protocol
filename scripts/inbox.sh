#!/bin/sh
# List unread messages for a line: addressed to the line, to its role (the Role field of
# its status file), or to "all"; pushed after the line's Last-read; not sent by itself unless
# addressed to the line by name (a transfer handover, PROTOCOL.md 5.7).
# No model call.
# Usage: inbox.sh [--show] [--no-fetch] <line>
#   --show      print each message instead of only its file name
#   --no-fetch  use the last fetched copy of the coordination branch
# Exit status: 0 when there are unread messages, 1 when there are none, 2 on error.
set -u
PROG=inbox.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

show=0
fetch=1
while [ $# -gt 0 ]; do
    case "$1" in
        --show) show=1 ;;
        --no-fetch) fetch=0 ;;
        -h | --help) sed -n '2,8s/^# \{0,1\}//p' "$0"; exit 0 ;;
        -*) die "unknown option '$1'" ;;
        *) break ;;
    esac
    shift
done
[ $# -eq 1 ] || die "usage: inbox.sh [--show] [--no-fetch] <line>"
line=$1
check_name line "$line"

require_repo
[ "$fetch" -eq 0 ] || fetch_coordination
git rev-parse --verify --quiet "$(coordination_ref)" >/dev/null || die "no local copy of '${MAP_BRANCH}'; run without --no-fetch"

status_text=$(show_file "status/${line}.md")
last_read=$(printf '%s\n' "$status_text" | status_value Last-read)
case "$last_read" in
    none | "<"*) last_read="" ;;
    messages/*) last_read=${last_read#messages/} ;;
esac
role=$(printf '%s\n' "$status_text" | status_value Role)
case "$role" in "<"* | *[!A-Za-z0-9.-]*) role="" ;; esac

unread=$(
    {
        message_headers
        printf '%s\n' '#push-order'
        messages_in_push_order
    } | LC_ALL=C awk -F '\t' -v line="$line" -v role="$role" -v last_read="$last_read" '
        !in_order && $0 == "#push-order" { in_order = 1; next }
        !in_order { from[$1] = $3; to[$1] = $4; next }
        { order[++count] = $0; if ($0 == last_read) found = 1 }
        END {
            if (last_read != "" && !found) {
                printf "inbox.sh: warning: Last-read \047%s\047 not found; listing all messages\n", last_read > "/dev/stderr"
                last_read = ""
            }
            past = (last_read == "")
            for (i = 1; i <= count; i++) {
                name = order[i]
                if (!past) { if (name == last_read) past = 1; continue }
                recipients = to[name]; gsub(/,/, " ", recipients)
                n = split(recipients, list, /[ \t]+/)
                # Own messages are skipped, unless addressed to this line by name (a transfer handover).
                if (from[name] == line) {
                    named = 0
                    for (j = 1; j <= n; j++) if (list[j] == line) named = 1
                    if (!named) continue
                }
                for (j = 1; j <= n; j++) {
                    if (list[j] == line || list[j] == "all" || (role != "" && list[j] == role)) { print name; break }
                }
            }
        }'
)

[ -n "$unread" ] || exit 1
for name in $unread; do
    if [ "$show" -eq 1 ]; then
        printf '===== messages/%s\n' "$name"
        show_file "messages/${name}"
        printf '\n'
    else
        printf 'messages/%s\n' "$name"
    fi
done
exit 0
