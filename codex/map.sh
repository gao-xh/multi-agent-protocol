#!/bin/sh
# Call the shared MAP scripts from a Codex skill, without depending on hook variables.
set -eu
plugin_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
operation=${1:---help}
[ $# -eq 0 ] || shift
case "$operation" in
    --root) printf '%s\n' "$plugin_root" ;;
    --help | -h)
        printf '%s\n' 'Usage: sh codex/map.sh <operation> [arguments]' \
            'Operations: inbox, send, status, claim, release-claim, mark-read, set-line,' \
            'doctor, decide, verify, init-coordination, session-start, watch, runner,' \
            'remote, upgrade. --root prints the installed plugin root.' ;;
    inbox | send | status | claim | release-claim | mark-read | set-line | doctor | \
        decide | verify | init-coordination | session-start | watch | runner | remote | upgrade)
        exec sh "$plugin_root/scripts/$operation.sh" "$@" ;;
    *) printf 'map.sh: unknown operation: %s\n' "$operation" >&2; exit 2 ;;
esac
