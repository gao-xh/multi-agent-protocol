#!/bin/sh
# Claim a task, or renew your own claim (PROTOCOL.md 5.6).
# Usage: claim.sh [--hours N] [--branch BRANCH] [--take-stale <heads-up>] <line> <task-slug>
#   <task-slug> may be a message file (messages/<name>.md) for its message claim
#   msg-<name, each _ written as -> (PROTOCOL.md 5.6); a message claim is also taken
#   while another line holds its older form msg-<timestamp>-<from>
#   --hours N        lease length in hours (default 4); rerunning renews the lease
#   --branch BRANCH  branch the work happens on (default: the current branch)
#   --take-stale M   take over a stale claim (past its expires time) in one push, after
#                    the heads-up M (a message file on the branch that names the task)
# Exit status: 0 when claimed or renewed, 1 when another line holds the claim, 2 on error.
# Without --take-stale a stale claim is reported but not taken over (PROTOCOL.md 5.6).
set -u
PROG=claim.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

hours=4
branch=""
take_stale=""
while [ $# -gt 0 ]; do
    case "$1" in
        --hours) [ $# -ge 2 ] || die "--hours needs a value"; hours=$2; shift ;;
        --branch) [ $# -ge 2 ] || die "--branch needs a value"; branch=$2; shift ;;
        --take-stale) [ $# -ge 2 ] || die "--take-stale needs the heads-up message"; take_stale=$(basename -- "$2"); shift ;;
        -h | --help) sed -n '2,13s/^# \{0,1\}//p' "$0"; exit 0 ;;
        -*) die "unknown option '$1'" ;;
        *) break ;;
    esac
    shift
done
[ $# -eq 2 ] || die "usage: claim.sh [--hours N] [--branch BRANCH] [--take-stale <heads-up>] <line> <task-slug>"
line=$1
task=$2
check_name line "$line"
case "$task" in *.md) task=$(message_claims "$task" | head -n 1) ;; esac
check_name task-slug "$task"
case "$hours" in "" | *[!0-9]*) die "--hours must be a whole number" ;; esac
# Drop leading zeros so the shell does not read the number as octal.
hours=$(printf '%s\n' "$hours" | sed 's/^0*//')
hours=${hours:-0}
[ -n "$branch" ] || branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'unknown')

require_repo
claim_file="claims/${task}.md"
if [ -n "$take_stale" ]; then
    # The heads-up that 5.6 asks for: a heads-up from this line that names the task as a
    # whole word, sent after the claim went stale (checked in write_claim).
    fetch_coordination
    is_message "$take_stale" || die "--take-stale: no message 'messages/${take_stale}' on '${MAP_BRANCH}'"
    heads_up=$(show_file "messages/${take_stale}")
    task_pattern=$(printf '%s\n' "$task" | sed 's/\./\\./g')
    [ "$(printf '%s\n' "$heads_up" | header_value type)" = heads-up ] &&
        [ "$(printf '%s\n' "$heads_up" | header_value from)" = "$line" ] &&
        printf '%s\n' "$heads_up" | grep -Eq -- "(^|[^A-Za-z0-9.-])${task_pattern}([^A-Za-z0-9.-]|\$)" ||
        die "--take-stale: messages/${take_stale} is not a heads-up from '${line}' that names '${task}' (PROTOCOL.md 5.6)"
    # The message name's UTC time, as YYYY-MM-DDTHH:MM:SSZ.
    heads_up_time=$(printf '%s\n' "$take_stale" | sed -n 's/^\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)T\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)Z_.*/\1-\2-\3T\4:\5:\6Z/p')
    [ -n "$heads_up_time" ] || die "--take-stale: cannot read the time of messages/${take_stale}"
fi

write_claim() {
    started=$(utc_now)
    took_over=""
    # The older form msg-<timestamp>-<from> of the same message claim: from the message
    # on the branch whose claim name this is (PROTOCOL.md 5.6).
    older=""
    case "$task" in
        msg-[0-9]*)
            stamp=${task#msg-}
            stamp=${stamp%%-*}
            for message in messages/"${stamp}"_*.md; do
                [ -e "$message" ] || continue
                [ "$(message_claims "$message" | head -n 1)" = "$task" ] || continue
                older="claims/$(message_claims "$message" | sed -n 2p).md"
                break
            done
            ;;
    esac
    if [ -n "$older" ] && [ -e "$older" ]; then
        holder=$(status_value Owner <"$older")
        expires=$(status_value Expires <"$older")
        if [ "$holder" != "$line" ]; then
            if [ -n "$expires" ] && is_before "$expires" "$(utc_now)"; then
                note "message claim '${task}' has a stale claim in the older form, ${older}, by '${holder}' (expired ${expires}); after a heads-up that names it, release it with release-claim.sh --stale ${line} $(basename "$older" .md), then claim again"
            else
                note "message claim '${task}' is taken: ${older} (the older form) is held by '${holder}'${expires:+ until ${expires}}"
            fi
            return 1
        fi
    fi
    if [ -e "$claim_file" ]; then
        holder=$(status_value Owner <"$claim_file")
        expires=$(status_value Expires <"$claim_file")
        if [ "$holder" != "$line" ]; then
            if [ -z "$holder" ] || [ -z "$expires" ]; then
                note "claim file '${claim_file}' has no Owner or Expires field; treating the task as taken (run doctor.sh)"
            elif is_before "$expires" "$(utc_now)"; then
                if [ -n "$take_stale" ] && is_before "$heads_up_time" "$expires"; then
                    note "messages/${take_stale} was sent before claim '${task}' went stale (expired ${expires}); send a new heads-up"
                    return 1
                elif [ -n "$take_stale" ]; then
                    note "taking over stale claim '${task}' of '${holder}' (expired ${expires}) after messages/${take_stale}"
                    took_over=$holder
                else
                    note "claim '${task}' by '${holder}' is stale (expired ${expires}); send a heads-up that names it, then claim.sh --take-stale <heads-up> (or release-claim.sh --stale)"
                    return 1
                fi
            else
                note "task '${task}' is claimed by '${holder}' until ${expires}"
            fi
            [ -n "$took_over" ] || return 1
        else
            started=$(status_value Started <"$claim_file")
        fi
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

publish_change write_claim "chore: claim ${task} for ${line}${take_stale:+ (stale claim taken over after ${take_stale})}" || exit $?
note "claimed '${task}' for '${line}' until $(status_value Expires <"$MAP_WORKTREE/$claim_file")"
