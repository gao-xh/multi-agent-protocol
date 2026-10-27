#!/bin/sh
# Send signed owner commands to a relay and show its progress and replies: remote control
# of another machine through the coordination branch (PROTOCOL.md 2.3, 3.6). Runs on the
# owner's computer, in a clone of the project, with git and ssh-keygen (macOS, Linux, or
# Git Bash on Windows).
# Usage: remote.sh [options] <relay-line> [<instruction>]
#   Without an instruction it reads instructions line by line, as a console:
#   "/allow <rule>" adds a permission rule to the next instruction; "/quit" ends.
#   --key <file>      the owner's private SSH signing key (default: MAP_SIGNING_KEY);
#                     without one, commands go unsigned, which a relay accepts only when
#                     the main branch says "- Owner commands: lenient"
#   --expires <min>   minutes until the relay refuses the command (default 60)
#   --allow <rule>    a permission rule for the run, passed to the agent (repeatable)
#   --print           print the command instead of sending it, to paste into a
#                     session that sends it, or to commit on the coordination branch by hand
#   --no-wait         send and exit without waiting for the reply
#   --interval <s>    seconds between fetches while waiting (default 10)
#   --wait <s>        stop waiting for a reply after <seconds> (default 3600)
# A signing key's public key must be listed as "- Owner signing key: <name> <key>" in the
# agent rules file on the main branch. While waiting it prints the relay's output from
# the branch <relay-line>/progress (runner.sh --progress) and every message from the
# relay that names the command.
# Exit status: 0 replied, sent or printed; 1 no reply in time; 2 on error.
set -u
PROG=remote.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

key=${MAP_SIGNING_KEY:-}
expires=60
allow_rules=""
print=0
wait_reply=1
interval=10
wait_seconds=3600
while [ $# -gt 0 ]; do
    case "$1" in
        --key) [ $# -ge 2 ] || die "--key needs a file"; key=$2; shift ;;
        --expires) [ $# -ge 2 ] || die "--expires needs minutes"; expires=$2; shift ;;
        --allow) [ $# -ge 2 ] || die "--allow needs a rule"; allow_rules="${allow_rules}${2}
"; shift ;;
        --print) print=1 ;;
        --no-wait) wait_reply=0 ;;
        --interval) [ $# -ge 2 ] || die "--interval needs seconds"; interval=$2; shift ;;
        --wait) [ $# -ge 2 ] || die "--wait needs seconds"; wait_seconds=$2; shift ;;
        -h | --help) sed -n '2,25s/^# \{0,1\}//p' "$0"; exit 0 ;;
        -*) die "unknown option '$1'" ;;
        *) break ;;
    esac
    shift
done
for value in "$expires" "$interval" "$wait_seconds"; do
    case "$value" in "" | *[!0-9]*) die "expected a whole number, got '${value}'" ;; esac
done
[ "$expires" -gt 0 ] || die "--expires must be at least 1"
[ "$interval" -gt 0 ] || die "--interval must be at least 1"
[ $# -ge 1 ] && [ $# -le 2 ] || die "usage: remote.sh [options] <relay-line> [<instruction>]"
relay=$1
check_name line "$relay"
require_repo
if [ -n "$key" ]; then
    [ -f "$key" ] || die "no such key file: ${key}"
    command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen is needed to sign commands"
else
    fetch_main_quietly
    case "$(rules_word 'Owner commands')" in
        lenient) note "no signing key: commands go unsigned (- Owner commands: lenient)" ;;
        off) die "owner commands are off in this project (- Owner commands: off)" ;;
        *) die "no signing key: give --key <file> or set MAP_SIGNING_KEY; this project accepts only signed owner commands (- Owner commands: strict)" ;;
    esac
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/map-remote.XXXXXX") || die "cannot create a temp directory"
trap 'rm -rf "$work"' EXIT
trap 'rm -rf "$work"; exit 130' HUP INT TERM

utc_in_minutes() {
    later=$(($(date -u +%s) + $1 * 60))
    date -u -r "$later" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null ||
        date -u -d "@$later" +%Y-%m-%dT%H:%M:%SZ
}

# Write the command (signed when there is a key) for instruction $1 with rules $2 to ${work}/command.md.
make_command() {
    suffix=$(od -An -N4 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')
    [ -n "$suffix" ] || suffix=$$
    {
        printf 'type: command\nfrom: owner\nto: %s\nid: %s-%s\nexpires: %s\n' \
            "$relay" "$(utc_stamp)" "$suffix" "$(utc_in_minutes "$expires")"
        printf '%s' "$2" | sed -n 's/^\(..*\)$/allow: \1/p'
        printf '\n%s\n' "$1"
    } >"${work}/command.md"
    [ -n "$key" ] || return 0
    rm -f "${work}/command.md.sig"
    ssh-keygen -q -Y sign -f "$key" -n map-approval "${work}/command.md" >/dev/null ||
        die "ssh-keygen could not sign with ${key}"
    cat "${work}/command.md.sig" >>"${work}/command.md"
}

progress_ref="refs/map/progress/${relay}"
fetch_progress() {
    quiet_git "${MAP_FETCH_SECONDS:-10}" /dev/null fetch --quiet "$MAP_REMOTE" "+refs/heads/${relay}/progress:${progress_ref}"
    git rev-parse --verify --quiet "$progress_ref" 2>/dev/null
}

# Wait for messages from the relay that name $1, printing its progress meanwhile.
wait_for_reply() {
    base=$(fetch_progress) || base=""
    shown=""
    needed=""
    shown_run=""
    printed=0
    started=$(date +%s)
    while :; do
        quiet_git "${MAP_FETCH_SECONDS:-10}" /dev/null fetch --quiet "$MAP_REMOTE" "+refs/heads/${MAP_BRANCH}:$(coordination_ref)"
        current=$(fetch_progress) || current=""
        if [ -n "$current" ] && [ "$current" != "$base" ]; then
            git show "${current}:progress.txt" 2>/dev/null >"${work}/progress"
            run=$(sed -n '1s/^# line [^,]*, run \([0-9]*\),.*/\1/p' "${work}/progress")
            if [ "$run" != "$shown_run" ]; then
                shown_run=$run
                printed=0
                printf -- '--- %s, run %s ---\n' "$relay" "$run"
            fi
            # Lines are numbered "<n>| text"; print those after the last one shown.
            awk -v after="$printed" '/^[0-9]+\| / {
                if (substr($0, 1, index($0, "|") - 1) + 0 > after) print substr($0, index($0, "|") + 2) }' "${work}/progress"
            last=$(awk '/^[0-9]+\| / { n = substr($0, 1, index($0, "|") - 1) + 0 } END { print n + 0 }' "${work}/progress")
            [ "$last" -le "$printed" ] || printed=$last
        fi
        done_now=0
        for reply in $(git grep -l -F "$1" "$(coordination_ref)" -- messages/ 2>/dev/null | sed "s|^$(coordination_ref):||"); do
            [ "$reply" != "$1" ] || continue
            case "
$shown
" in *"
$reply
"*) continue ;; esac
            [ "$(show_file "$reply" | header_value from)" = "$relay" ] || continue
            shown="${shown}${reply}
"
            printf '===== %s\n' "$reply"
            show_file "$reply"
            printf '\n'
            # Permission rules the relay asks for, one "Rule needed: <rule>" line each.
            needed="${needed}$(show_file "$reply" | tr -d '\r' |
                sed -n 's/^[[:space:]]*Rule needed:[[:space:]]*//p' | tr -d '`' | sed 's/[[:space:]]*$//')
"
            done_now=1
        done
        [ "$done_now" -eq 0 ] || return 0
        [ $(($(date +%s) - started)) -lt "$wait_seconds" ] || return 1
        sleep "$interval"
    done
}

# Sign, then print or send instruction $1 with rules $2; wait for the reply.
handle() {
    instruction=$1
    rules=$2
    while :; do
        make_command "$instruction" "$rules"
        if [ "$print" -eq 1 ]; then
            note "publish it as messages/$(utc_stamp)_owner_command.md on '${MAP_BRANCH}', unchanged"
            cat "${work}/command.md"
            return 0
        fi
        published=$("${MAP_SCRIPT_DIR}/send.sh" "${work}/command.md") || die "send.sh could not send the command"
        note "sent ${published} to ${relay}"
        [ "$wait_reply" -eq 1 ] || return 0
        note "waiting for ${relay} (Ctrl-C stops waiting; the command stays sent)"
        wait_for_reply "$published" || { note "no reply from ${relay} in ${wait_seconds} s"; return 1; }
        needed=$(printf '%s\n' "$needed" | grep . | awk '!seen[$0]++')
        [ -n "$needed" ] || return 0
        # Ask the owner at the terminal; never allow anything without an answer.
        printf '%s asks for these permission rules:\n' "$relay" >&2
        printf '%s\n' "$needed" | sed 's/^/  /' >&2
        answer=""
        if [ -t 2 ] && { : </dev/tty; } 2>/dev/null; then
            printf 'Allow them for one run and try again? [y/N] ' >&2
            IFS= read -r answer </dev/tty || answer=""
        else
            note "to allow them, send the command again with: $(printf '%s\n' "$needed" | sed "s/.*/--allow '&'/" | tr '\n' ' ')(or /allow <rule> in the console)"
        fi
        case "$answer" in y | Y | yes) ;; *) return 0 ;; esac
        rules="${2}${needed}
"
        instruction="Allowed now for this run: $(printf '%s\n' "$needed" | tr '\n' ' ')Run again the steps of ${published} that were refused for lack of these permissions, and reply as before."
    done
}

if [ $# -eq 2 ]; then
    handle "$2" "$allow_rules"
    exit $?
fi
pending=$allow_rules
while printf '%s> ' "$relay" >&2 && IFS= read -r input; do
    case "$input" in
        "") ;;
        /quit) break ;;
        "/allow "*) pending="${pending}${input#/allow }
" ;;
        *) handle "$input" "$pending"; pending=$allow_rules ;;
    esac
done
