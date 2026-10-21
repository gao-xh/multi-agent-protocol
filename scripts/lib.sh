# Shared helpers for the coordination scripts. Source it; do not run it.
# POSIX sh; needs only git and the usual Unix tools.
#
# Environment:
#   MAP_REMOTE  remote that holds the coordination branch (default: origin)
#   MAP_BRANCH  name of the coordination branch (default: coordination)

MAP_REMOTE=${MAP_REMOTE:-origin}
MAP_BRANCH=${MAP_BRANCH:-coordination}
MAP_MAX_ATTEMPTS=${MAP_MAX_ATTEMPTS:-5}
MAP_MESSAGE_TYPES="handover release-request released returned heads-up question answer"
MAP_WORKTREE=""

die() {
    printf '%s: error: %s\n' "$PROG" "$*" >&2
    exit 2
}

note() {
    printf '%s: %s\n' "$PROG" "$*" >&2
}

require_repo() {
    git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"
}

# Names of lines, tasks and topics: letters, digits, '.' and '-' ('_' separates parts of message names).
check_name() {
    case "$2" in
        "" | .* | *[!A-Za-z0-9.-]*) die "invalid $1 '$2' (use letters, digits, '.' and '-')" ;;
    esac
}

coordination_ref() {
    printf 'refs/remotes/%s/%s' "$MAP_REMOTE" "$MAP_BRANCH"
}

fetch_coordination() {
    git fetch --quiet "$MAP_REMOTE" \
        "+refs/heads/${MAP_BRANCH}:$(coordination_ref)" 2>/dev/null ||
        die "cannot fetch '${MAP_BRANCH}' from '${MAP_REMOTE}' (run init-coordination.sh first?)"
}

# Print a file from the fetched coordination branch; fail quietly if missing.
show_file() {
    git show "$(coordination_ref):$1" 2>/dev/null
}

file_exists() {
    git cat-file -e "$(coordination_ref):$1" 2>/dev/null
}

utc_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

utc_stamp() {
    date -u +%Y%m%dT%H%M%SZ
}

# UTC time N hours from now, ISO 8601 (BSD and GNU date).
utc_in_hours() {
    later=$(($(date -u +%s) + $1 * 3600))
    date -u -r "$later" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null ||
        date -u -d "@$later" +%Y-%m-%dT%H:%M:%SZ
}

# True when ISO timestamp $1 is earlier than $2 (same format, so compare as text).
is_before() {
    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | LC_ALL=C sort | head -n 1)" = "$1" ]
}

# Value of a "key: value" header line in the header block of a message on stdin.
header_value() {
    sed -n '/^$/q;p' | sed -n "s/^$1:[[:space:]]*//p" | head -n 1
}

# Value of a "- Key: value" line in a status file on stdin.
status_value() {
    sed -n "s/^- $1:[[:space:]]*//p" | head -n 1
}

close_worktree() {
    if [ -n "$MAP_WORKTREE" ]; then
        git worktree remove --force "$MAP_WORKTREE" 2>/dev/null
        rm -rf "$MAP_WORKTREE"
        MAP_WORKTREE=""
    fi
}

open_worktree() {
    MAP_WORKTREE=$(mktemp -d "${TMPDIR:-/tmp}/map-coordination.XXXXXX") || die "cannot create a temp directory"
    trap close_worktree EXIT
    trap 'close_worktree; exit 130' INT TERM
    git worktree add --quiet --detach "$MAP_WORKTREE" "$(coordination_ref)" 2>/dev/null ||
        die "cannot create a worktree for '${MAP_BRANCH}'"
}

# publish_change <function> <commit message>
# Runs <function> in a fresh copy of the coordination branch (cwd = worktree), commits
# and pushes; on a rejected push, refetches and runs <function> again.
# <function> returns 0 to publish, or non-zero to stop with that status.
publish_change() {
    attempt=1
    fetch_coordination
    open_worktree
    while :; do
        git -C "$MAP_WORKTREE" reset --quiet --hard "$(coordination_ref)" || die "cannot reset the worktree"
        git -C "$MAP_WORKTREE" clean --quiet -fd
        status=0
        previous_dir=$(pwd)
        cd "$MAP_WORKTREE" || die "cannot enter the worktree"
        "$1" || status=$?
        cd "$previous_dir" || die "cannot return to $previous_dir"
        [ "$status" -eq 0 ] || return "$status"
        git -C "$MAP_WORKTREE" add -A
        if git -C "$MAP_WORKTREE" diff --cached --quiet; then
            note "nothing to change"
            return 0
        fi
        git -C "$MAP_WORKTREE" commit --quiet --no-verify -m "$2" || die "commit failed"
        if git -C "$MAP_WORKTREE" push --quiet "$MAP_REMOTE" "HEAD:refs/heads/${MAP_BRANCH}" 2>/dev/null; then
            git update-ref "$(coordination_ref)" "$(git -C "$MAP_WORKTREE" rev-parse HEAD)"
            return 0
        fi
        [ "$attempt" -lt "$MAP_MAX_ATTEMPTS" ] || die "push rejected ${attempt} times; giving up"
        attempt=$((attempt + 1))
        note "push rejected; refetching and retrying (attempt ${attempt})"
        sleep "$attempt"
        fetch_coordination
    done
}

MAP_SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
MAP_TEMPLATE_DIR=${MAP_TEMPLATE_DIR:-"${MAP_SCRIPT_DIR}/../templates"}
