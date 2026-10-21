#!/bin/sh
# Claim a task, or renew your own claim (PROTOCOL.md 5.5).
# Usage: claim.sh [--hours N] [--branch BRANCH] <line> <task-slug>
#   --hours N        lease length in hours (default 4); rerunning renews the lease
#   --branch BRANCH  branch the work happens on (default: the current branch)
# Exit status: 0 when claimed or renewed, 1 when another line holds the claim, 2 on error.
# A stale claim (past its expires time) is reported but not taken over: send a
# heads-up first, then run release-claim.sh --stale.
set -u
PROG=claim.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

hours=4
branch=""
while [ $# -gt 0 ]; do
    case "$1" in
        --hours) [ $# -ge 2 ] || die "--hours needs a value"; hours=$2; shift ;;
        --branch) [ $# -ge 2 ] || die "--branch needs a value"; branch=$2; shift ;;
        -h | --help) sed -n '2,9s/^# \{0,1\}//p' "$0"; exit 0 ;;
        -*) die "unknown option '$1'" ;;
        *) break ;;
    esac
    shift
done
[ $# -eq 2 ] || die "usage: claim.sh [--hours N] [--branch BRANCH] <line> <task-slug>"
line=$1
task=$2
check_name line "$line"
check_name task-slug "$task"
case "$hours" in "" | *[!0-9]*) die "--hours must be a whole number" ;; esac
[ -n "$branch" ] || branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'unknown')

require_repo
claim_file="claims/${task}.md"

write_claim() {
    started=$(utc_now)
    if [ -e "$claim_file" ]; then
        holder=$(status_value Owner <"$claim_file")
        expires=$(status_value Expires <"$claim_file")
        if [ "$holder" != "$line" ]; then
            if is_before "$expires" "$(utc_now)"; then
                note "claim '${task}' by '${holder}' is stale (expired ${expires}); send a heads-up, then release-claim.sh --stale"
            else
                note "task '${task}' is claimed by '${holder}' until ${expires}"
            fi
            return 1
        fi
        started=$(status_value Started <"$claim_file")
    fi
    mkdir -p claims
    {
        printf '# Claim: %s\n\n' "$task"
        printf -- '- Owner: %s\n' "$line"
        printf -- '- Branch: %s\n' "$branch"
        printf -- '- Started: %s\n' "$started"
        printf -- '- Expires: %s\n' "$(utc_in_hours "$hours")"
    } >"$claim_file"
}

publish_change write_claim "chore: claim ${task} for ${line}" || exit $?
note "claimed '${task}' for '${line}' until $(status_value Expires <"$MAP_WORKTREE/$claim_file")"
