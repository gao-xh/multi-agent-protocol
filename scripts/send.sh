#!/bin/sh
# Publish a message on the coordination branch (PROTOCOL.md 5.4).
# Usage: send.sh <message-file>     publish a filled-in message (header + body)
#        send.sh --template <type>  print the template for <type> to fill in
# The file name is chosen for you: messages/<UTC timestamp>_<from>_<type>.md.
# Prints the published path. Retries when the push is rejected.
set -u
PROG=send.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

is_message_type() {
    for known in $MAP_MESSAGE_TYPES; do
        [ "$known" = "$1" ] && return 0
    done
    return 1
}

case "${1:-}" in
    -h | --help | "") sed -n '2,6s/^# \{0,1\}//p' "$0"; [ $# -gt 0 ]; exit $? ;;
    --template)
        [ $# -eq 2 ] || die "usage: send.sh --template <type>"
        case "$2" in
            question | answer)
                printf 'type: %s\nfrom: <line or role>\nto: <line or role>\nrefs: <earlier messages, optional>\n\n<question or answer, with paths, SHAs and commands>\n' "$2"
                exit 0 ;;
        esac
        is_message_type "$2" || die "unknown type '$2' (one of: ${MAP_MESSAGE_TYPES})"
        cat "${MAP_TEMPLATE_DIR}/${2}.md" || die "template not found in ${MAP_TEMPLATE_DIR}"
        exit 0 ;;
esac

[ $# -eq 1 ] || die "usage: send.sh <message-file>"
source_file=$1
[ -f "$source_file" ] || die "no such file: ${source_file}"
source_file=$(CDPATH='' cd -- "$(dirname -- "$source_file")" && pwd)/$(basename -- "$source_file")

message_type=$(header_value type <"$source_file")
from=$(header_value from <"$source_file")
to=$(header_value to <"$source_file")
is_message_type "$message_type" || die "header 'type:' must be one of: ${MAP_MESSAGE_TYPES}"
check_name sender "$from"
[ -n "$to" ] || die "header 'to:' is empty"
if grep -q '<[a-z][^>]*>' "$source_file"; then
    note "warning: the message still contains template placeholders like <...>"
fi

require_repo
published=""

write_message() {
    name="$(utc_stamp)_${from}_${message_type}.md"
    while [ -e "messages/${name}" ]; do
        sleep 1
        name="$(utc_stamp)_${from}_${message_type}.md"
    done
    mkdir -p messages
    cp "$source_file" "messages/${name}" || return 2
    published="messages/${name}"
}

publish_change write_message "chore: send ${message_type} from ${from} to ${to}"
printf '%s\n' "$published"
