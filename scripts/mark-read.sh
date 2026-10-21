#!/bin/sh
# Advance a line's Last-read to a message it has fully handled (PROTOCOL.md 5.2).
# Usage: mark-read.sh <line> <message-file>
# Run it after acting on the message, not before.
set -u
PROG=mark-read.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

case "${1:-}" in -h | --help) sed -n '2,4s/^# \{0,1\}//p' "$0"; exit 0 ;; esac
[ $# -eq 2 ] || die "usage: mark-read.sh <line> <message-file>"
line=$1
message=$(basename -- "$2")
check_name line "$line"

require_repo

advance_last_read() {
    [ -e "messages/${message}" ] || { note "no message 'messages/${message}'"; return 2; }
    target="status/${line}.md"
    [ -e "$target" ] || { note "no status/${line}.md; publish one with status.sh first"; return 2; }
    now=$(utc_now)
    sed -e "s|^- Last-read:.*|- Last-read: ${message}|" \
        -e "s|^- Updated:.*|- Updated: ${now}|" "$target" >"${target}.new" && mv "${target}.new" "$target"
    grep -q '^- Last-read:' "$target" || printf -- '- Last-read: %s\n' "$message" >>"$target"
}

publish_change advance_last_read "chore: mark ${message} read for ${line}" || exit $?
note "Last-read of '${line}' is now ${message}"
