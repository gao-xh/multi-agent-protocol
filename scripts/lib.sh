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

# Names of lines, roles, tasks and topics: letters, digits, '.' and '-', not starting
# with '.' or '-' ('_' separates the parts of message names).
check_name() {
    case "$2" in
        "" | .* | -* | *[!A-Za-z0-9.-]*) die "invalid $1 '$2' (use letters, digits, '.' and '-'; start with a letter or digit)" ;;
    esac
}

coordination_ref() {
    printf 'refs/remotes/%s/%s' "$MAP_REMOTE" "$MAP_BRANCH"
}

fetch_coordination() {
    fetch_error=$(git fetch --quiet "$MAP_REMOTE" "+refs/heads/${MAP_BRANCH}:$(coordination_ref)" 2>&1) && return 0
    git ls-remote --exit-code --heads "$MAP_REMOTE" "$MAP_BRANCH" >/dev/null 2>&1
    case $? in
        2) die "'${MAP_BRANCH}' does not exist on '${MAP_REMOTE}'; create it with init-coordination.sh" ;;
        *) die "cannot fetch '${MAP_BRANCH}' from '${MAP_REMOTE}': $(printf '%s\n' "$fetch_error" | tail -n 1) (no network, no access, or a sandbox that blocks network?)" ;;
    esac
}

# Print a file from the fetched coordination branch; fail quietly if missing.
show_file() {
    git show "$(coordination_ref):$1" 2>/dev/null
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

# Value of a "key: value" line in the header block (up to the first blank line) of a
# message on stdin. Keys are case-insensitive; CRLF line endings are accepted.
header_value() {
    LC_ALL=C awk -v key="$1" '
        BEGIN { key = tolower(key) }
        { line = $0; sub(/\r$/, "", line) }
        line ~ /^[ \t]*$/ { exit }
        {
            colon = index(line, ":")
            if (colon > 1 && tolower(substr(line, 1, colon - 1)) == key) {
                value = substr(line, colon + 1); gsub(/^[ \t]+|[ \t]+$/, "", value)
                print value; exit
            }
        }'
}

# Value of a "- Key: value" line in a status or claim file on stdin. Keys are
# case-insensitive, the leading "- " is optional, and CRLF line endings are accepted.
status_value() {
    LC_ALL=C awk -v key="$1" '
        BEGIN { key = tolower(key) }
        {
            line = $0; sub(/\r$/, "", line); sub(/^[ \t]*-?[ \t]*/, "", line)
            colon = index(line, ":")
            if (colon > 1 && tolower(substr(line, 1, colon - 1)) == key) {
                value = substr(line, colon + 1); gsub(/^[ \t]+|[ \t]+$/, "", value)
                print value; exit
            }
        }'
}

# Message file names in the order they were pushed (the branch history is linear),
# which does not depend on the clocks of the machines that wrote them.
messages_in_push_order() {
    git log --reverse --diff-filter=A --format= --name-only "$(coordination_ref)" -- messages/ |
        sed -n 's|^messages/\([^/]*\.md\)$|\1|p'
}

# One line per message: name<TAB>type<TAB>from<TAB>to, read from all header blocks with a
# single git grep (fast even with thousands of messages). Messages without any header
# line are absent from the output.
message_headers() {
    git grep -n -I -i -E '^(type|from|to):|^[[:space:]]*$' "$(coordination_ref)" -- messages/ 2>/dev/null |
        LC_ALL=C awk -v prefix="$(coordination_ref):messages/" '
            index($0, prefix) == 1 {
                rest = substr($0, length(prefix) + 1)
                colon = index(rest, ":"); name = substr(rest, 1, colon - 1); rest = substr(rest, colon + 1)
                colon = index(rest, ":"); text = substr(rest, colon + 1); sub(/\r$/, "", text)
                if (name in done) next
                if (!(name in seen)) { seen[name] = 1; order[++count] = name }
                if (text ~ /^[ \t]*$/) { done[name] = 1; next }
                colon = index(text, ":"); key = tolower(substr(text, 1, colon - 1))
                value = substr(text, colon + 1); gsub(/^[ \t]+|[ \t]+$/, "", value)
                if (!((name, key) in field)) field[name, key] = value
            }
            END {
                for (i = 1; i <= count; i++) {
                    name = order[i]
                    if (name ~ /\.md$/) printf "%s\t%s\t%s\t%s\n", name, field[name, "type"], field[name, "from"], field[name, "to"]
                }
            }'
}

close_worktree() {
    if [ -n "$MAP_WORKTREE" ]; then
        git worktree remove --force "$MAP_WORKTREE" 2>/dev/null
        rm -rf "$MAP_WORKTREE"
        MAP_WORKTREE=""
    fi
}

open_worktree() {
    # Forget worktrees of earlier runs whose directories are gone.
    git worktree prune 2>/dev/null
    MAP_WORKTREE=$(mktemp -d "${TMPDIR:-/tmp}/map-coordination.XXXXXX") || die "cannot create a temp directory"
    trap close_worktree EXIT
    trap 'close_worktree; exit 130' INT TERM
    git worktree add --quiet --detach "$MAP_WORKTREE" "$(coordination_ref)" 2>/dev/null ||
        die "cannot create a worktree for '${MAP_BRANCH}'"
}

# publish_change <function> <commit message>
# Runs <function> in a fresh copy of the coordination branch (cwd = worktree), commits
# and pushes; when the push is rejected because the branch moved, refetches and runs
# <function> again. <function> returns 0 to publish, or non-zero to stop with that status.
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
        if push_error=$(git -C "$MAP_WORKTREE" push --quiet "$MAP_REMOTE" "HEAD:refs/heads/${MAP_BRANCH}" 2>&1); then
            git update-ref "$(coordination_ref)" "$(git -C "$MAP_WORKTREE" rev-parse HEAD)"
            return 0
        fi
        case "$push_error" in
            *rejected* | *"fetch first"* | *non-fast-forward* | *lock*) ;;
            *) die "push to '${MAP_REMOTE}' failed: $(printf '%s\n' "$push_error" | tail -n 1)" ;;
        esac
        [ "$attempt" -lt "$MAP_MAX_ATTEMPTS" ] || die "push rejected ${attempt} times; giving up"
        attempt=$((attempt + 1))
        note "the branch moved; refetching and retrying (attempt ${attempt})"
        sleep "$attempt"
        fetch_coordination
    done
}

MAP_SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
MAP_TEMPLATE_DIR=${MAP_TEMPLATE_DIR:-"${MAP_SCRIPT_DIR}/../templates"}
