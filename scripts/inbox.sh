#!/bin/sh
# List unread messages for a line: addressed to it or to "all", newer than the
# Last-read field of its status file, and not sent by itself. No model call.
# Usage: inbox.sh [--show] [--no-fetch] <line>
#   --show      print each message instead of only its file name
#   --no-fetch  use the last fetched copy of the coordination branch
# Exit status: 0 when there are unread messages, 1 when there are none, 2 on error.
set -u
PROG=inbox.sh
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

last_read=$(show_file "status/${line}.md" | status_value Last-read)
case "$last_read" in
    "" | none | "<"*) last_read="" ;;
    messages/*) last_read=${last_read#messages/} ;;
esac

# Messages in the order they were pushed (the branch history is linear), which
# does not depend on the clocks of the machines that wrote them.
pushed_messages=$(git log --reverse --diff-filter=A --format= --name-only "$(coordination_ref)" -- messages/ |
    sed -n "s|^messages/\(.*\.md\)\$|\1|p")

past_last_read=1
if [ -n "$last_read" ]; then
    past_last_read=0
    printf "%s\n" "$pushed_messages" | grep -Fqx "$last_read" ||
        { note "warning: Last-read '${last_read}' not found; listing all messages"; past_last_read=1; }
fi

found=0
for name in $pushed_messages; do
    if [ "$past_last_read" -eq 0 ]; then
        [ "$name" = "$last_read" ] && past_last_read=1
        continue
    fi
    header=$(show_file "messages/${name}" | sed -n '/^$/q;p')
    from=$(printf '%s\n' "$header" | header_value from)
    [ "$from" != "$line" ] || continue
    recipients=$(printf '%s\n' "$header" | header_value to | tr ',' ' ')
    addressed=0
    for recipient in $recipients; do
        if [ "$recipient" = "$line" ] || [ "$recipient" = all ]; then
            addressed=1
        fi
    done
    [ "$addressed" -eq 1 ] || continue
    found=1
    if [ "$show" -eq 1 ]; then
        printf '===== messages/%s\n' "$name"
        show_file "messages/${name}"
        printf '\n'
    else
        printf 'messages/%s\n' "$name"
    fi
done

[ "$found" -eq 1 ] && exit 0
exit 1
