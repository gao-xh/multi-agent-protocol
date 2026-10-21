#!/bin/sh
# Advance a line's Last-read to a message it has fully handled (PROTOCOL.md 5.2).
# Usage: mark-read.sh [--force] <line> <message-file>
# Run it after acting on the message, not before. Refuses to skip an earlier unread
# message for the line, or to move Last-read backwards, unless --force is given.
set -u
PROG=mark-read.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

force=0
while [ $# -gt 0 ]; do
    case "$1" in
        --force) force=1 ;;
        -h | --help) sed -n '2,5s/^# \{0,1\}//p' "$0"; exit 0 ;;
        -*) die "unknown option '$1'" ;;
        *) break ;;
    esac
    shift
done
[ $# -eq 2 ] || die "usage: mark-read.sh [--force] <line> <message-file>"
line=$1
message=$(basename -- "$2")
check_name line "$line"

require_repo
fetch_coordination

ordered=$(messages_in_push_order)
position_of() {
    printf '%s\n' "$ordered" | grep -Fnx -- "$1" | cut -d: -f1
}
target_position=$(position_of "$message")
[ -n "$target_position" ] || die "no message 'messages/${message}'"

last_read=$(show_file "status/${line}.md" | status_value Last-read)
last_read=${last_read#messages/}
last_read_position=$(position_of "$last_read")
if [ -n "$last_read_position" ] && [ "$target_position" -lt "$last_read_position" ] && [ "$force" -eq 0 ]; then
    die "this would move Last-read of '${line}' backwards (now ${last_read}); pass --force to do it anyway"
fi

first_unread=$("${MAP_SCRIPT_DIR}/inbox.sh" --no-fetch "$line" 2>/dev/null | head -n 1)
first_unread=${first_unread#messages/}
if [ -n "$first_unread" ] && [ "$first_unread" != "$message" ] && [ "$force" -eq 0 ]; then
    first_unread_position=$(position_of "$first_unread")
    if [ "$first_unread_position" -lt "$target_position" ]; then
        die "messages/${first_unread} is unread and comes first; handle it and mark it read first, or pass --force to skip it"
    fi
fi

advance_last_read() {
    target="status/${line}.md"
    [ -e "$target" ] || { note "no status/${line}.md; publish one with status.sh first"; return 2; }
    now=$(utc_now)
    sed -e "s|^- Last-read:.*|- Last-read: ${message}|" \
        -e "s|^- Updated:.*|- Updated: ${now}|" "$target" >"${target}.new" && mv "${target}.new" "$target"
    grep -q '^- Last-read:' "$target" || printf -- '- Last-read: %s\n' "$message" >>"$target"
}

publish_change advance_last_read "chore: mark ${message} read for ${line}" || exit $?
note "Last-read of '${line}' is now ${message}"
