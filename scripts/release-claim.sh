#!/bin/sh
# Release a claim by deleting its file (PROTOCOL.md 5.6).
# Usage: release-claim.sh [--stale] <line> <task-slug>
#   --stale  release another line's claim that is past its expires time
#            (send a heads-up naming the stale claim first)
# Exit status: 0 when released, 1 when the claim is not yours (or not stale), 2 on error.
set -u
PROG=release-claim.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

stale=0
while [ $# -gt 0 ]; do
    case "$1" in
        --stale) stale=1 ;;
        -h | --help) sed -n '2,6s/^# \{0,1\}//p' "$0"; exit 0 ;;
        -*) die "unknown option '$1'" ;;
        *) break ;;
    esac
    shift
done
[ $# -eq 2 ] || die "usage: release-claim.sh [--stale] <line> <task-slug>"
line=$1
task=$2
check_name line "$line"
check_name task-slug "$task"

require_repo
claim_file="claims/${task}.md"

remove_claim() {
    if [ ! -e "$claim_file" ]; then
        note "no claim '${task}'"
        return 0
    fi
    holder=$(status_value Owner <"$claim_file")
    expires=$(status_value Expires <"$claim_file")
    if [ "$holder" != "$line" ]; then
        if [ "$stale" -eq 0 ]; then
            note "claim '${task}' belongs to '${holder}'; use --stale only for an expired claim"
            return 1
        fi
        if [ -z "$expires" ] || ! is_before "$expires" "$(utc_now)"; then
            note "claim '${task}' by '${holder}' is not past a valid expires time (${expires:-none})"
            return 1
        fi
        note "releasing stale claim '${task}' of '${holder}' (expired ${expires})"
    fi
    git rm --quiet "$claim_file"
}

publish_change remove_claim "chore: release claim ${task} (${line})" || exit $?
note "released '${task}'"
