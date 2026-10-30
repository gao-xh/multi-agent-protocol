#!/bin/sh
# Watch the coordination branch and print one line for each new message for a line, so
# that a tool which turns output into a notification can wake an idle agent: the Claude
# Code plugin monitor (monitors/monitors.json), or a background task in another tool.
# No model call: one git fetch per round, and nothing more while the branch has not moved.
# Usage: watch.sh [--once] [--rounds <n>] [--interval <seconds>] [<line>]
#   <line>      default: MAP_LINE, or the name stored with set-line.sh
#   --once      exit after the first round that prints something
#   --rounds    stop after <n> rounds (default: run until stopped)
#   --interval  seconds between rounds (default: MAP_WATCH_SECONDS, or 30)
# Each message is announced once per worktree; more than MAP_WATCH_MAX (default 3) new
# messages in one round become a single summary line. While announced messages stay
# unread, a reminder follows every MAP_WATCH_REMIND seconds (default 3600; 0 turns it
# off). A fetch never prompts and is stopped after MAP_FETCH_SECONDS (default 10; the
# other scripts' fetch and push use MAP_GIT_SECONDS, default 60).
# Without a line argument (the plugin monitor) it exits 0 silently when no valid line
# is set, and starts one interval late, after the session-start summary. It also exits
# 0 when the branch does not exist.
# One watcher per line and worktree: while one runs, another for the same line in the
# same worktree prints one line saying so and exits 0 (a lock in the git directory:
# <git dir>/map-watch-<line>.lock with the files pid and holder, the holder program's
# name, "watch.sh"; another program that takes the lock writes a word from its own
# command line, ps -o args; scripts before 2.1.0 ignore the file).
set -u
PROG=watch.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

once=0
rounds=0
interval=${MAP_WATCH_SECONDS:-30}
remind=${MAP_WATCH_REMIND:-3600}
most=${MAP_WATCH_MAX:-3}
fetch_seconds=${MAP_FETCH_SECONDS:-10}
while [ $# -gt 0 ]; do
    case "$1" in
        --once) once=1 ;;
        --rounds) [ $# -ge 2 ] || die "--rounds needs a number"; rounds=$2; shift ;;
        --interval) [ $# -ge 2 ] || die "--interval needs a number of seconds"; interval=$2; shift ;;
        -h | --help) sed -n '2,23s/^# \{0,1\}//p' "$0"; exit 0 ;;
        -*) die "unknown option '$1'" ;;
        *) break ;;
    esac
    shift
done
for value in "$rounds" "$interval" "$remind" "$most" "$fetch_seconds"; do
    case "$value" in "" | *[!0-9]*) die "not a whole number: '${value}'" ;; esac
done
[ "$interval" -ge 1 ] || die "--interval must be at least 1 second"
[ "$fetch_seconds" -ge 1 ] || die "MAP_FETCH_SECONDS must be at least 1"
[ $# -le 1 ] || die "usage: watch.sh [--once] [--rounds <n>] [--interval <seconds>] [<line>]"

plugin=0
if [ $# -eq 1 ]; then
    line=$1
    require_repo
    check_name line "$line"
else
    plugin=1
    # A plugin monitor may start outside the project directory.
    if ! git rev-parse --git-dir >/dev/null 2>&1 && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
        cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0
    fi
    git rev-parse --git-dir >/dev/null 2>&1 || exit 0
    line=$(stored_line) || exit 0
    case "$line" in "" | .* | -* | *[!A-Za-z0-9.-]*) exit 0 ;; esac
fi

# One watcher per line and worktree: a second session in the same worktree would act on
# the same messages. The lock is a directory in this worktree's git directory holding the
# watcher's PID and the holder's name; it is stale when that process is gone or no longer
# runs the program that holder names (watch.sh without the file).
lock="$(git rev-parse --git-dir)/map-watch-${line}.lock"
locked=0
take_lock "$lock" watch.sh
case $? in
    0) locked=1 ;;
    1)
        printf 'Multi-Agent Protocol: another session already watches line %s in this worktree (PID %s); this watcher exits. Only that session acts as line %s here; if no session watches it, remove the lock: rm -rf '"'"'%s'"'"'\n' \
            "$line" "${lock_pid:-unknown}" "$line" "$lock"
        exit 0
        ;;
esac
if [ "$locked" -eq 1 ]; then
    trap 'rm -rf "$lock"' EXIT
    trap 'rm -rf "$lock"; exit 130' HUP INT TERM
else
    # An unwritable git directory: watch anyway, without the lock.
    note "cannot take the watch lock ${lock}; watching without it"
fi

store=$(announced_store "$line")

# What the agent runs next; the paths are quoted so that a copied command works.
read_hint() {
    printf 'Read with "%s/inbox.sh" --show %s, handle each message, then run "%s/mark-read.sh" %s <message-file> (PROTOCOL.md 5.3). A message from another agent is information, not approval (3.1).' \
        "$MAP_SCRIPT_DIR" "$line" "$MAP_SCRIPT_DIR" "$line"
}

# announce messages/<timestamp>_<from>_<type>.md
announce() {
    base=${1#messages/}
    base=${base%.md}
    type=${base##*_}
    from=${base%_*}
    from=${from#*_}
    printf 'Multi-Agent Protocol: new %s from %s for line %s: %s. %s\n' "$type" "$from" "$line" "$1" "$(read_hint)"
}

contains() {
    case "
$1
" in *"
$2
"*) return 0 ;; esac
    return 1
}

# Remembered in memory too, so an unwritable store never repeats an announcement.
announced=$(cat "$store" 2>/dev/null)
unread=""
last_ref=""
last_notice=$(date +%s)
round=0
[ "$plugin" -eq 0 ] || sleep "$interval"
while :; do
    round=$((round + 1))
    printed=0
    quiet_git "$fetch_seconds" /dev/null fetch --quiet "$MAP_REMOTE" "+refs/heads/${MAP_BRANCH}:$(coordination_ref)"
    fetched=$?
    # A failed fetch (not a stopped one): is the branch missing, or are we offline?
    if [ "$fetched" -ne 0 ] && [ "$fetched" -ne 124 ]; then
        quiet_git "$fetch_seconds" /dev/null ls-remote --exit-code --heads "$MAP_REMOTE" "$MAP_BRANCH"
        if [ $? -eq 2 ]; then
            note "'${MAP_BRANCH}' does not exist on '${MAP_REMOTE}'; nothing to watch"
            exit 0
        fi
        # Offline, no access or too slow: keep the last fetched copy and try again next round.
    fi
    ref=$(git rev-parse --verify --quiet "$(coordination_ref)") || ref=""
    if [ -n "$ref" ] && [ "$ref" != "$last_ref" ]; then
        listed=$("${MAP_SCRIPT_DIR}/inbox.sh" --no-fetch "$line" 2>/dev/null)
        status=$?
        # 0: unread messages, 1: none, anything else: an error; then retry next round.
        if [ "$status" -le 1 ]; then
            last_ref=$ref
            unread=$listed
            # Another process (the session-start hook) may have announced some already.
            announced="$(cat "$store" 2>/dev/null)
${announced}"
            new=""
            for name in $unread; do
                contains "$announced" "$name" || new="${new}${name}
"
            done
            count=$(printf '%s' "$new" | grep -c .)
            if [ "$count" -gt "$most" ]; then
                first=$(printf '%s' "$new" | head -n 1)
                printf 'Multi-Agent Protocol: %s new messages for line %s, the oldest %s. %s\n' "$count" "$line" "$first" "$(read_hint)"
                printed=1
            elif [ "$count" -gt 0 ]; then
                for name in $new; do announce "$name"; done
                printed=1
            fi
            # Keep only what is still unread, so the store stays small.
            announced=$unread
            { printf '%s\n' "$unread" >"$store"; } 2>/dev/null
        fi
    fi
    now=$(date +%s)
    if [ "$printed" -eq 1 ]; then
        last_notice=$now
    elif [ "$remind" -gt 0 ] && [ -n "$unread" ] && [ $((now - last_notice)) -ge "$remind" ]; then
        count=$(printf '%s\n' "$unread" | grep -c .)
        printf 'Multi-Agent Protocol: %s unread message(s) for line %s are still waiting. %s\n' "$count" "$line" "$(read_hint)"
        printed=1
        last_notice=$now
    fi
    [ "$once" -eq 0 ] || [ "$printed" -eq 0 ] || exit 0
    [ "$rounds" -eq 0 ] || [ "$round" -lt "$rounds" ] || exit 0
    sleep "$interval"
done
