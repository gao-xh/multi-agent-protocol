#!/bin/sh
# Publish a message on the coordination branch (PROTOCOL.md 5.4).
# Usage: send.sh [--strict] <message-file>  publish a filled-in message (header + body)
#        send.sh --template <type>         print the template for <type> to fill in
#                                          (also "joined", sent when a session joins, and "transfer",
#                                          the handover when a line moves to another agent)
# The file name is chosen for you: messages/<UTC timestamp>_<from>_<type>.md.
# Prints the published path. Retries when the push is rejected.
# --strict (or MAP_STRICT=1) refuses, with exit status 1, a message whose header or
# "- Field: <...>" lines still hold a placeholder, that still has a line of its
# template unchanged (a line with <...>), or that lacks a "## " heading of the template.
# A partly edited line (for example "Reviewed: x at <SHA>") is not caught.
set -u
PROG=send.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

# A type of the protocol or of the project (PROTOCOL.md 5.4); a type the local copy of the
# main branch does not know yet is looked up again after one quick fetch of main.
is_message_type() {
    is_known_type "$1" && return 0
    git rev-parse --git-dir >/dev/null 2>&1 || return 1
    fetch_main_quietly
    is_known_type "$1"
}

case "${1:-}" in
    -h | --help | "") sed -n '2,12s/^# \{0,1\}//p' "$0"; [ $# -gt 0 ]; exit $? ;;
    --template)
        [ $# -eq 2 ] || die "usage: send.sh --template <type>"
        case "$2" in
            joined)
                cat "${MAP_TEMPLATE_DIR}/joined.md" || die "template not found in ${MAP_TEMPLATE_DIR}"
                exit 0 ;;
            transfer)
                cat "${MAP_TEMPLATE_DIR}/transfer.md" || die "template not found in ${MAP_TEMPLATE_DIR}"
                exit 0 ;;
            question | answer)
                printf 'type: %s\nfrom: <line or role>\nto: <line or role>\nrefs: <earlier messages, optional>\n\n<question or answer, with paths, SHAs and commands>\n' "$2"
                exit 0 ;;
        esac
        is_message_type "$2" || die "unknown type '$2' (one of: ${MAP_MESSAGE_TYPES} $(project_message_types | tr '\n' ' '))"
        if is_builtin_type "$2"; then
            cat "${MAP_TEMPLATE_DIR}/${2}.md"
        else
            # A project type: a plain template with the purpose from the agent rules file.
            printf 'type: %s\nfrom: <line or role>\nto: <line or role>\nrefs: <earlier messages, optional>\n\n<%s>\n' \
                "$2" "$(message_type_purpose "$2")"
        fi
        exit 0 ;;
esac

strict=0
case "${MAP_STRICT:-0}" in
    1 | yes | true) strict=1 ;;
    0 | no | false) ;;
    *) note "warning: MAP_STRICT='${MAP_STRICT}' is not 1; strict mode is off" ;;
esac
if [ "${1:-}" = --strict ]; then
    strict=1
    shift
fi
[ $# -eq 1 ] || die "usage: send.sh [--strict] <message-file>"
source_file=$1
[ -f "$source_file" ] || die "no such file: ${source_file}"
source_file=$(CDPATH='' cd -- "$(dirname -- "$source_file")" && pwd)/$(basename -- "$source_file")

message_type=$(header_value type <"$source_file")
from=$(header_value from <"$source_file")
to=$(header_value to <"$source_file")
is_message_type "$message_type" ||
    die "header 'type:' must be one of: ${MAP_MESSAGE_TYPES} $(project_message_types | tr '\n' ' ')(project types come from the agent rules file on ${MAP_MAIN_REMOTE}/${MAP_MAIN})"
check_name sender "$from"
[ -n "$to" ] || die "header 'to:' is empty"
# Template placeholders left in the header, or a field whose whole value is one.
header_block=$(sed -n '/^[[:space:]]*$/q;p' "$source_file")
placeholders=$({
    printf '%s\n' "$header_block" | grep '<[^>]*>'
    grep -E '^- [^:]+: <[^>]+>[[:space:]]*$' "$source_file"
} | tr -d '\r')
if [ "$strict" != 1 ]; then
    [ -z "$placeholders" ] || note "warning: the message still contains template placeholders like <...>"
else
    # "## " headings of the type's template that the message lacks. A heading matches
    # when it starts with the template heading cut before any "<" or " (", ignoring case.
    template_file="${MAP_TEMPLATE_DIR}/${message_type}.md"
    if [ "$message_type" = handover ] &&
        sed -n '/^[[:space:]]*$/,$p' "$source_file" | tr -d '\r' | grep -qi '^## transfer of line'; then
        template_file="${MAP_TEMPLATE_DIR}/transfer.md"
    fi
    missing=""
    if [ -f "$template_file" ]; then
        missing=$(LC_ALL=C awk '
            { line = $0; sub(/\r$/, "", line) }
            FNR == NR && line ~ /^## / {
                key = substr(line, 4)
                cut = index(key, "<"); if (cut) key = substr(key, 1, cut - 1)
                cut = index(key, " ("); if (cut) key = substr(key, 1, cut - 1)
                sub(/[ \t]+$/, "", key)
                keys[++count] = tolower(key); names[count] = line
                next
            }
            FNR != NR && line ~ /^## / { seen[++found] = tolower(substr(line, 4)) }
            END {
                for (i = 1; i <= count; i++) {
                    hit = 0
                    for (j = 1; j <= found; j++)
                        if (substr(seen[j], 1, length(keys[i])) == keys[i]) { hit = 1; break }
                    if (!hit) print names[i]
                }
            }' "$template_file" "$source_file")
    fi
    # Body lines of the template that hold a placeholder and were left unchanged.
    if [ -f "$template_file" ]; then
        unchanged=$(LC_ALL=C awk '
            { line = $0; sub(/\r$/, "", line) }
            FNR == NR { if (body && line ~ /<[^>]*>/) template[line] = 1; if (line ~ /^[ \t]*$/) body = 1; next }
            !in_body { if (line ~ /^[ \t]*$/) in_body = 1; next }
            line in template { print line }' "$template_file" "$source_file")
        if [ -n "$unchanged" ]; then
            placeholders=$(printf '%s\n%s\n' "$placeholders" "$unchanged" | grep . | awk '!seen[$0]++')
        fi
    fi
    if [ -n "$placeholders" ] || [ -n "$missing" ]; then
        printf '%s: error: --strict: message not sent: %s\n' "$PROG" "$(basename -- "$source_file")" >&2
        if [ -n "$placeholders" ]; then
            printf '  template placeholders <...> still to fill in:\n' >&2
            printf '%s\n' "$placeholders" | sed 's/^/    /' >&2
        fi
        if [ -n "$missing" ]; then
            printf '  headings of %s missing from the message:\n' "$(basename -- "$template_file")" >&2
            printf '%s\n' "$missing" | sed 's/^/    /' >&2
        fi
        exit 1
    fi
fi

require_repo
published=""

# Optional "corrects:" header: earlier messages this one corrects (PROTOCOL.md 5.2).
corrects=$(header_value corrects <"$source_file")

# Unfilled template placeholders <...> name nothing; the rest is checked.
corrects=$(printf '%s\n' "$corrects" | sed 's/<[^>]*>//g')

write_message() {
    set -f
    for corrected in $(printf '%s\n' "$corrects" | tr ',' ' '); do
        is_message "$corrected" || {
            set +f
            note "error: 'corrects:' names '${corrected}', which is not a message on '${MAP_BRANCH}'"
            return 2
        }
    done
    set +f
    name="$(utc_stamp)_${from}_${message_type}.md"
    while [ -e "messages/${name}" ]; do
        sleep 1
        name="$(utc_stamp)_${from}_${message_type}.md"
    done
    mkdir -p messages
    cp "$source_file" "messages/${name}" || return 2
    published="messages/${name}"
}

publish_change write_message "chore: send ${message_type} from ${from} to ${to}" || exit $?
printf '%s\n' "$published"
