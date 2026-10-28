#!/bin/sh
# Show or publish a line's status file (PROTOCOL.md 5.2, templates/status.md).
# Usage: status.sh <line>              print the line's current status
#        status.sh <line> <file>       publish <file> as status/<line>.md
#        status.sh --all               print every line's status
#        status.sh --claims            list active claims (owner, expires; stale ones marked)
#        status.sh --decisions         print the files in decisions/, newest first
# When publishing, the "- Updated:" field is set to the current UTC time, and an
# existing "- Last-read:" value is kept if <file> leaves it empty or as a placeholder,
# and "- Protocol:" is set to the version of these scripts.
# A Last-read that is neither "none" nor a message on the branch is refused (exit 2).
set -u
PROG=status.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

case "${1:-}" in
    -h | --help | "") sed -n '2,11s/^# \{0,1\}//p' "$0"; [ $# -gt 0 ]; exit $? ;;
esac
require_repo
fetch_coordination

case "$1" in
    --claims)
        now=$(utc_now)
        for path in $(git ls-tree --name-only "$(coordination_ref)" claims/); do
            case "$path" in */.gitkeep) continue ;; esac
            content=$(show_file "$path")
            holder=$(printf '%s\n' "$content" | status_value Owner)
            expires=$(printf '%s\n' "$content" | status_value Expires)
            marker=""
            if [ -n "$expires" ] && is_before "$expires" "$now"; then marker=" (stale)"; fi
            task=${path#claims/}
            printf '%s\t%s\t%s%s\n' "${task%.md}" "${holder:-?}" "${expires:-?}" "$marker"
        done
        exit 0 ;;
    --decisions)
        for path in $(git ls-tree --name-only "$(coordination_ref)" decisions/ | grep -v '/\.gitkeep$' | LC_ALL=C sort -r); do
            printf '===== %s\n' "$path"
            show_file "$path"
            printf '\n'
        done
        exit 0 ;;
esac

if [ "$1" = --all ]; then
    for path in $(git ls-tree --name-only "$(coordination_ref)" status/); do
        case "$path" in *.md) show_file "$path"; printf '\n' ;; esac
    done
    exit 0
fi

line=$1
check_name line "$line"
case "$line" in all | owner) die "'${line}' is a reserved recipient, not a line name (PROTOCOL.md 2.1)" ;; esac
if [ $# -eq 1 ]; then
    show_file "status/${line}.md" || die "no status for '${line}'"
    exit 0
fi
[ $# -eq 2 ] || die "usage: status.sh <line> [<file>]"
[ -f "$2" ] || die "no such file: $2"
source_file=$(CDPATH='' cd -- "$(dirname -- "$2")" && pwd)/$(basename -- "$2")
input_name=$2
refuse_secrets "$source_file"

write_status() {
    target="status/${line}.md"
    kept_last_read=""
    [ ! -e "$target" ] || kept_last_read=$(status_value Last-read <"$target")
    new_last_read=$(status_value Last-read <"$source_file")
    origin="in ${input_name}"
    case "$new_last_read" in "" | "<"*) new_last_read=${kept_last_read:-none}; origin="kept from the published ${target}" ;; esac
    if [ "$new_last_read" != none ] && ! is_message "$new_last_read"; then
        note "error: Last-read '${new_last_read}' (${origin}) is neither 'none' nor a message on '${MAP_BRANCH}'; set Last-read in ${input_name} to the last message this line has fully handled, or to none (PROTOCOL.md 5.2)"
        return 2
    fi
    now=$(utc_now)
    mkdir -p status
    # Updated and Last-read in any spelling that status_value reads, once.
    set_status_field Updated "$now" "$source_file" >"${target}.new" || return 2
    set_status_field Last-read "$new_last_read" "${target}.new" >"${target}.tmp" || return 2
    rm -f "${target}.new"
    # The Protocol field states the version of the scripts that publish the status.
    # Any spelling status_value would read ("-  protocol :"), once.
    sed -e "s|^# Status: <line>|# Status: ${line}|" "${target}.tmp" |
        LC_ALL=C awk -v version="$MAP_VERSION" '
            { line = $0; sub(/\r$/, "", line) }
            # Field lines only ("- Protocol: ..."); free text that starts with "Protocol:" stays.
            line ~ /^[ \t]*-[ \t]*[Pp][Rr][Oo][Tt][Oo][Cc][Oo][Ll][ \t]*:/ {
                if (!done) print "- Protocol: " version
                done = 1
                next
            }
            { print }' >"$target"
    rm -f "${target}.tmp"
    grep -q '^- Protocol:' "$target" || printf -- '- Protocol: %s\n' "$MAP_VERSION" >>"$target"
}

publish_change write_status "chore: update status of ${line}" || exit $?
note "published status/${line}.md"
