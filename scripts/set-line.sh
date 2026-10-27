#!/bin/sh
# Remember which line this checkout belongs to, for the session-start hook.
# Usage: set-line.sh <line>   store the line name for this worktree
#        set-line.sh          print the stored line name
#        set-line.sh --clear  forget it
# Stored in this worktree's own git directory, so it is never committed and each
# worktree of a repository can belong to a different line. MAP_LINE overrides it.
set -u
PROG=set-line.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

require_repo
store="$(git rev-parse --git-dir)/map-line"
case "${1:-}" in
    -h | --help) sed -n '2,7s/^# \{0,1\}//p' "$0"; exit 0 ;;
    "") [ -f "$store" ] || exit 1; cat "$store"; exit 0 ;;
    --clear) rm -f "$store"; note "line name cleared"; exit 0 ;;
esac
[ $# -eq 1 ] || die "usage: set-line.sh [<line> | --clear]"
check_name line "$1"
printf '%s\n' "$1" >"$store" || die "cannot write ${store}"
note "this worktree is line '$1'"
note "the Claude Code plugin watches this line's inbox from the next session (or after /reload-plugins)"
