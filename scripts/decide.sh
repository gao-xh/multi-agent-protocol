#!/bin/sh
# Record an owner decision on the coordination branch (PROTOCOL.md 3.3, 3.6, 5.2).
# Usage: decide.sh [--supersede <old-file>] <topic> <decision-file>
#   Publishes <decision-file> as decisions/<UTC date>_<topic>.md. With --supersede, also
#   appends "superseded-by: <new file>" to the old decision (after any signature).
# The file should quote the owner's words and state scope and exclusions; sign it first
# (ssh-keygen -Y sign -n map-approval) if the project uses signed owner records.
set -u
PROG=decide.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

supersede=""
while [ $# -gt 0 ]; do
    case "$1" in
        --supersede) [ $# -ge 2 ] || die "--supersede needs a value"; supersede=$(basename -- "$2"); shift ;;
        -h | --help) sed -n '2,7s/^# \{0,1\}//p' "$0"; exit 0 ;;
        -*) die "unknown option '$1'" ;;
        *) break ;;
    esac
    shift
done
[ $# -eq 2 ] || die "usage: decide.sh [--supersede <old-file>] <topic> <decision-file>"
topic=$1
check_name topic "$topic"
[ -f "$2" ] || die "no such file: $2"
source_file=$(CDPATH='' cd -- "$(dirname -- "$2")" && pwd)/$(basename -- "$2")
refuse_secrets "$source_file"

require_repo
published=""

write_decision() {
    name="$(date -u +%Y-%m-%d)_${topic}.md"
    [ ! -e "decisions/${name}" ] || { note "decisions/${name} already exists; choose another topic"; return 1; }
    if [ -n "$supersede" ]; then
        [ -e "decisions/${supersede}" ] || { note "no decision decisions/${supersede}"; return 2; }
        # On a line of its own, even when the file lacks a final newline (else the END line
        # of a signature would no longer match, and verify.sh would refuse the record).
        [ -z "$(tail -c 1 "decisions/${supersede}")" ] || printf '\n' >>"decisions/${supersede}"
        printf 'superseded-by: %s\n' "$name" >>"decisions/${supersede}"
    fi
    mkdir -p decisions
    cp "$source_file" "decisions/${name}" || return 2
    published="decisions/${name}"
}

publish_change write_decision "chore: record decision ${topic}" || exit $?
printf '%s\n' "$published"
