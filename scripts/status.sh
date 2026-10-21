#!/bin/sh
# Show or publish a line's status file (PROTOCOL.md 5.2, templates/status.md).
# Usage: status.sh <line>              print the line's current status
#        status.sh <line> <file>       publish <file> as status/<line>.md
#        status.sh --all               print every line's status
# When publishing, the "- Updated:" field is set to the current UTC time, and an
# existing "- Last-read:" value is kept if <file> leaves it empty or as a placeholder.
set -u
PROG=status.sh
. "$(dirname -- "$0")/lib.sh"

case "${1:-}" in
    -h | --help | "") sed -n '2,7s/^# \{0,1\}//p' "$0"; [ $# -gt 0 ]; exit $? ;;
esac
require_repo
fetch_coordination

if [ "$1" = --all ]; then
    for path in $(git ls-tree --name-only "$(coordination_ref)" status/); do
        case "$path" in *.md) show_file "$path"; printf '\n' ;; esac
    done
    exit 0
fi

line=$1
check_name line "$line"
if [ $# -eq 1 ]; then
    show_file "status/${line}.md" || die "no status for '${line}'"
    exit 0
fi
[ $# -eq 2 ] || die "usage: status.sh <line> [<file>]"
[ -f "$2" ] || die "no such file: $2"
source_file=$(CDPATH='' cd -- "$(dirname -- "$2")" && pwd)/$(basename -- "$2")

write_status() {
    target="status/${line}.md"
    kept_last_read=""
    [ ! -e "$target" ] || kept_last_read=$(status_value Last-read <"$target")
    new_last_read=$(status_value Last-read <"$source_file")
    case "$new_last_read" in "" | "<"*) new_last_read=${kept_last_read:-none} ;; esac
    now=$(utc_now)
    mkdir -p status
    sed -e "s|^- Updated:.*|- Updated: ${now}|" \
        -e "s|^- Last-read:.*|- Last-read: ${new_last_read}|" \
        -e "s|^# Status: <line>|# Status: ${line}|" "$source_file" >"$target"
    grep -q '^- Updated:' "$target" || printf -- '- Updated: %s\n' "$now" >>"$target"
    grep -q '^- Last-read:' "$target" || printf -- '- Last-read: %s\n' "$new_last_read" >>"$target"
}

publish_change write_status "chore: update status of ${line}" || exit $?
note "published status/${line}.md"
