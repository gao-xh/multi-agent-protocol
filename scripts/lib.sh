# Shared helpers for the coordination scripts. Source it; do not run it.
# POSIX sh; needs only git and the usual Unix tools.
#
# Environment:
#   MAP_REMOTE  remote that holds the coordination branch (default: origin)
#   MAP_BRANCH  name of the coordination branch (default: coordination)
#   MAP_MAIN    name of the main branch, which holds the agent rules (default: main)
#   MAP_MAIN_REMOTE  remote that holds the main branch (default: MAP_REMOTE); set it when
#               the coordination branch lives in a separate private repository

MAP_REMOTE=${MAP_REMOTE:-origin}
MAP_BRANCH=${MAP_BRANCH:-coordination}
MAP_MAIN=${MAP_MAIN:-main}
MAP_MAIN_REMOTE=${MAP_MAIN_REMOTE:-$MAP_REMOTE}
MAP_MAX_ATTEMPTS=${MAP_MAX_ATTEMPTS:-5}
# The version of these scripts; the release role keeps it equal to .claude-plugin/plugin.json.
MAP_VERSION=2.0.0-rc.3
# Where newer versions are published (update_notice).
MAP_UPSTREAM=${MAP_UPSTREAM:-https://github.com/gao-xh/multi-agent-protocol.git}
MAP_MESSAGE_TYPES="handover release-request released returned review heads-up question answer command"
MAP_WORKTREE=""
# git output goes to scripts and terminals, never to a pager that waits for a key.
GIT_PAGER=cat
export GIT_PAGER

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

# The agent rules files (AGENTS.md, CLAUDE.md, .claude/CLAUDE.md) on the main branch, as
# last fetched from MAP_MAIN_REMOTE (default: MAP_REMOTE), with carriage returns removed.
# Owner keys and project message types come only from here, never from a working tree or
# the coordination branch, so that changing them goes through the main branch.
main_ref() {
    printf 'refs/remotes/%s/%s' "$MAP_MAIN_REMOTE" "$MAP_MAIN"
}
main_rules() {
    for rules in AGENTS.md CLAUDE.md .claude/CLAUDE.md; do
        git show "$(main_ref):${rules}" 2>/dev/null
    done | tr -d '\r'
}

# Message types the project adds, one line each in the rules files on the main branch:
# "- Message type: <name>: <purpose>", the name in lowercase letters, digits and '-'
# (PROTOCOL.md 5.4). Lines that reuse a protocol type's name are ignored.
project_message_types() {
    main_rules | sed -n 's/^[[:space:]]*-[[:space:]]*Message type:[[:space:]]*\([a-z0-9][a-z0-9-]*\)[[:space:]]*:.*$/\1/p' |
        LC_ALL=C sort -u | while IFS= read -r name; do
            case " ${MAP_MESSAGE_TYPES} " in *" ${name} "*) ;; *) printf '%s\n' "$name" ;; esac
        done
}

# The purpose a project gives its message type $1, from the same lines.
message_type_purpose() {
    valid_type_name "$1" || return 1
    main_rules | sed -n "s/^[[:space:]]*-[[:space:]]*Message type:[[:space:]]*$1[[:space:]]*:[[:space:]]*//p" | head -n 1
}

# The first word of the value of the rules line "- <field>: <value> ..." on the main
# branch, in lowercase; empty when the line is missing or the word runs into other
# letters, digits or '-' ("minor-only").
rules_word() {
    main_rules | sed -n "s/^-[[:space:]]*$1:[[:space:]]*\([A-Za-z]*\)\([^A-Za-z0-9-].*\)\{0,1\}\$/\1/p" |
        head -n 1 | tr 'A-Z' 'a-z'
}

# Who the project's commits are authored as (PROTOCOL.md 5.5), from the line
# "- Commit author: line | owner" on the main branch: "line", "owner", or nothing when
# the project has not written the line (sessions then commit under their line names, but
# doctor.sh does not check, so that older histories raise no warnings).
commit_author_policy() {
    case "$(rules_word 'Commit author')" in line) printf 'line\n' ;; owner) printf 'owner\n' ;; esac
}

# The name and the email of a git identity "Name <email> time zone" (git var).
ident_name() { printf '%s\n' "${1% <*}"; }
ident_email() {
    email=${1##*<}
    printf '%s\n' "${email%%>*}"
}

# True when the git author name $1 names line $2: the line name alone, or followed by a
# space and anything (for example "cloud (agent)").
author_names_line() {
    case "$1" in "$2" | "$2 "*) return 0 ;; esac
    return 1
}

# True when $1 could name a message type: lowercase letters, digits and '-'.
valid_type_name() {
    case "$1" in "" | -* | *[!a-z0-9-]*) return 1 ;; esac
}

# True when $1 is exactly one message type of the protocol.
is_builtin_type() {
    for known in $MAP_MESSAGE_TYPES; do
        [ "$known" = "$1" ] && return 0
    done
    return 1
}

# True when $1 is exactly one message type of the protocol or of the project.
is_known_type() {
    valid_type_name "$1" || return 1
    is_builtin_type "$1" && return 0
    project_message_types | grep -Fqx -- "$1"
}

# Refresh the local copy of the main branch, quietly and briefly (for project types).
fetch_main_quietly() {
    quiet_git "${MAP_FETCH_SECONDS:-10}" /dev/null fetch --quiet "$MAP_MAIN_REMOTE" "+refs/heads/${MAP_MAIN}:$(main_ref)"
}

# The line of this worktree: MAP_LINE, or the name stored with set-line.sh.
# Prints nothing and fails when neither is set.
stored_line() {
    stored=${MAP_LINE:-}
    if [ -z "$stored" ] && [ -f "$(git rev-parse --git-dir)/map-line" ]; then
        stored=$(head -n 1 "$(git rev-parse --git-dir)/map-line")
    fi
    [ -n "$stored" ] || return 1
    printf '%s\n' "$stored"
}

# File in this worktree's git directory (never committed) that lists the messages already
# announced to the line by watch.sh or session-start.sh, so neither repeats the other.
announced_store() {
    printf '%s/map-announced-%s' "$(git rev-parse --git-dir)" "$1"
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

# True when $1 (with or without "messages/") is the name of a message file on the fetched
# coordination branch: not a path, not .gitkeep, not a pattern.
is_message() {
    candidate=${1#messages/}
    case "$candidate" in "" | */* | .* | *[\*\?\[]*) return 1 ;; esac
    git ls-tree --name-only "$(coordination_ref)" -- "messages/${candidate}" 2>/dev/null | grep -Fqx "messages/${candidate}"
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

# Every value of a "key: value" line in the header block of a message on stdin, one per
# line, for keys that may repeat (the "allow:" lines of a command).
header_values() {
    LC_ALL=C awk -v key="$1" '
        BEGIN { key = tolower(key) }
        { line = $0; sub(/\r$/, "", line) }
        line ~ /^[ \t]*$/ { exit }
        {
            colon = index(line, ":")
            if (colon > 1 && tolower(substr(line, 1, colon - 1)) == key) {
                value = substr(line, colon + 1); gsub(/^[ \t]+|[ \t]+$/, "", value)
                if (value != "") print value
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

# One line per message: name<TAB>type<TAB>from<TAB>to<TAB>corrects, read from all header
# blocks with a single git grep (fast even with thousands of messages). Messages without
# any header line are absent from the output. "corrects" is optional (PROTOCOL.md 5.2).
message_headers() {
    git grep -n -I -i -E '^(type|from|to|corrects):|^[[:space:]]*$' "$(coordination_ref)" -- messages/ 2>/dev/null |
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
                    if (name ~ /\.md$/) printf "%s\t%s\t%s\t%s\t%s\n", name, field[name, "type"], field[name, "from"], field[name, "to"], field[name, "corrects"]
                }
            }'
}

# Write file $3 to stdout with the "- Key: value" field $1 set to $2. The key matches as
# status_value reads it (any case, "- " optional, CRLF accepted), on a "- " line or before
# the first "## " heading, so that free text further down ("Updated: ..." in a question)
# stays: the first match is replaced, later matches are dropped, and the field is
# appended when there is none.
set_status_field() {
    LC_ALL=C awk -v key="$1" -v value="$2" '
        BEGIN { name = key; key = tolower(key) }
        {
            line = $0; sub(/\r$/, "", line)
            if (line ~ /^## /) section = 1
            if (section && line !~ /^[ \t]*-/) { print; next }
            sub(/^[ \t]*-?[ \t]*/, "", line)
            colon = index(line, ":")
            if (colon > 1 && tolower(substr(line, 1, colon - 1)) == key) {
                if (!done) print "- " name ": " value
                done = 1
                next
            }
            print
        }
        END { if (!done) print "- " name ": " value }' "$3"
}

# Credentials that must never reach the coordination branch: private key blocks and
# common token formats (GitHub, Anthropic, OpenAI, AWS, Google, Slack, npm), as an ERE.
MAP_SECRET_ERE='-----BEGIN [A-Z0-9 ]*PRIVATE KEY( BLOCK)?-----|gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|sk-ant-[A-Za-z0-9_-]{20,}|sk-proj-[A-Za-z0-9_-]{20,}|(AKIA|ASIA)[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[abposr]-[A-Za-z0-9-]{10,}|npm_[A-Za-z0-9]{36}'

# The numbers of the lines of file $1 that look like a credential, one per line (never
# the matched text, so that the warning does not spread it).
secret_lines() {
    grep -nE -e "$MAP_SECRET_ERE" "$1" 2>/dev/null | cut -d: -f1
}

# Stdin to stdout with credentials replaced by "[redacted]"; a private key block becomes
# one "[redacted]" line, so that its body does not get through either.
redact_secrets() {
    LC_ALL=C awk '
        /-----BEGIN [A-Z0-9 ]*PRIVATE KEY( BLOCK)?-----/ { print "[redacted]"; skip = 1; next }
        skip { if ($0 ~ /-----END [A-Z0-9 ]*PRIVATE KEY( BLOCK)?-----/) skip = 0; next }
        { print }' | sed -E "s/${MAP_SECRET_ERE}/[redacted]/g"
}

# What to do after a credential was pushed: the history is never rewritten without the
# owner (PROTOCOL.md 4, 5.2), so the credential itself must be made useless.
MAP_SECRET_HELP='If a real credential was already pushed or sent anywhere: stop, tell the owner, and have it revoked and replaced (rotated) with the owner'"'"'s approval; only the owner may authorize rewriting the branch history.'

# Exit 1 with the lines of file $1 that look like a credential, unless there are none.
# $2: an extra sentence for the error, such as the option that overrides the check.
refuse_secrets() {
    found_lines=$(secret_lines "$1" | tr '\n' ' ' | sed 's/ $//')
    [ -n "$found_lines" ] || return 0
    printf '%s: error: not published: %s looks like it contains a private key or an access token (line %s). Remove it and publish again. %s%s\n' \
        "$PROG" "$(basename -- "$1")" "$found_lines" "$MAP_SECRET_HELP" "${2:+ $2}" >&2
    exit 1
}

# True when PID $1 is alive and, where ps can tell, still runs a command that contains $2
# (a lock left by a dead process whose PID was reused is stale; -ww: never cut at 80
# columns). When ps cannot tell (no ps, or no "-o args"), any live process counts.
lock_holder_alive() {
    kill -0 "$1" 2>/dev/null || return 1
    holder_args=$(ps -ww -p "$1" -o args= 2>/dev/null) || return 0
    [ -n "$holder_args" ] || return 0
    case "$holder_args" in *"$2"*) return 0 ;; esac
    return 1
}

# Stop a process and its descendants (git's transport helpers), children first.
stop_tree() {
    for child in $(ps -A -o pid= -o ppid= 2>/dev/null | awk -v parent="$1" '$2 == parent { print $1 }'); do
        stop_tree "$child"
    done
    kill "$1" 2>/dev/null
}

# quiet_git <seconds> <output-file> <git arguments...>
# Run git without any prompt (terminal, askpass program, credential manager dialog, ssh
# passphrase or host key), for scripts that run with nobody there to answer. Its output
# goes to <output-file> (for example /dev/null), errors are discarded. Stopped, with its
# helper processes, after <seconds>; returns 124 then, or git's own exit status.
quiet_git() {
    git_seconds=$1
    git_output=$2
    shift 2
    case "$git_seconds" in "" | *[!0-9]*) git_seconds=5 ;; esac
    # Decimal, also with leading zeros ("08"): shell arithmetic would read them as octal.
    git_seconds=${git_seconds#"${git_seconds%%[!0]*}"}
    [ -n "$git_seconds" ] || git_seconds=0
    (
        unset GIT_ASKPASS SSH_ASKPASS
        if [ -z "${GIT_SSH:-}" ]; then
            ssh_command=${GIT_SSH_COMMAND:-$(git config --get core.sshCommand 2>/dev/null)}
            GIT_SSH_COMMAND="${ssh_command:-ssh} -o BatchMode=yes -o ConnectTimeout=${git_seconds}"
            export GIT_SSH_COMMAND
        fi
        GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never exec git -c core.askPass= -c credential.interactive=never \
            -c http.lowSpeedLimit=1 -c "http.lowSpeedTime=${git_seconds}" "$@"
    ) </dev/null >"$git_output" 2>/dev/null &
    git_pid=$!
    # Poll in fifths of a second where sleep takes fractions (GNU, BSD, busybox), so a
    # quick git costs no full second; otherwise in seconds (POSIX).
    if sleep 0.01 2>/dev/null; then tick=0.2 ticks=5; else tick=1 ticks=1; fi
    waited=0
    while kill -0 "$git_pid" 2>/dev/null; do
        if [ "$waited" -ge $((git_seconds * ticks)) ]; then
            stop_tree "$git_pid"
            wait "$git_pid" 2>/dev/null
            return 124
        fi
        sleep "$tick"
        waited=$((waited + 1))
    done
    wait "$git_pid"
}

# Semantic Versioning order for awk programs: vcmp(a, b) is 1, 0 or -1 when version a
# (X.Y.Z or X.Y.Z-<pre-release>, such as 2.0.0-rc.1) is newer than, equal to or older
# than b. A release is newer than its pre-releases; pre-release fields compare as numbers
# when both are numeric, otherwise as text, and a numeric field is older than a text one.
# shellcheck disable=SC2016
MAP_VERSION_AWK='
function vcmp(a, b,   cut, ap, bp, x, y, n, m, i, xn, yn) {
    ap = ""; cut = index(a, "-"); if (cut) { ap = substr(a, cut + 1); a = substr(a, 1, cut - 1) }
    bp = ""; cut = index(b, "-"); if (cut) { bp = substr(b, cut + 1); b = substr(b, 1, cut - 1) }
    split(a, x, "."); split(b, y, ".")
    for (i = 1; i <= 3; i++) if (x[i] + 0 != y[i] + 0) return x[i] + 0 > y[i] + 0 ? 1 : -1
    if (ap == bp) return 0
    if (ap == "") return 1
    if (bp == "") return -1
    n = split(ap, x, "."); m = split(bp, y, ".")
    for (i = 1; i <= n && i <= m; i++) {
        if (x[i] == y[i]) continue
        xn = x[i] ~ /^[0-9]+$/; yn = y[i] ~ /^[0-9]+$/
        if (xn && yn) return x[i] + 0 > y[i] + 0 ? 1 : -1
        if (xn) return -1
        if (yn) return 1
        return x[i] > y[i] ? 1 : -1
    }
    return n > m ? 1 : (n < m ? -1 : 0)
}'

# True when version $1 is newer than version $2 (MAP_VERSION_AWK order).
version_newer() {
    LC_ALL=C awk -v a="$1" -v b="$2" "${MAP_VERSION_AWK}"'
        BEGIN { exit !(vcmp(a, b) > 0) }'
}

# The newest release tag (vX.Y.Z) in the git ls-remote output in file $1. Pre-release
# tags (vX.Y.Z-rc.N) count only when version $2 is itself a pre-release: a session on a
# final release is never offered a release candidate, a session on one is told about a
# newer candidate or the final release.
newest_release() {
    LC_ALL=C awk -v current="$2" "${MAP_VERSION_AWK}"'
        BEGIN { pre = index(current, "-") > 0 }
        match($0, /refs\/tags\/v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$/) {
            version = substr($0, RSTART + 11)
            if (index(version, "-") && !pre) next
            if (newest == "" || vcmp(version, newest) > 0) newest = version
        }
        END { if (newest != "") print newest }' "$1"
}

# One line when MAP_UPSTREAM has a release tag (vX.Y.Z, or vX.Y.Z-rc.N for a session on a
# pre-release; see newest_release) newer than MAP_VERSION, otherwise nothing. One git
# ls-remote, at most MAP_UPDATE_SECONDS (a whole number, default 5); silent when offline,
# and off when MAP_UPDATE_CHECK=0. The tag list goes to one fixed file in the git
# directory, so an interrupted check leaves nothing new behind.
update_notice() {
    [ "${MAP_UPDATE_CHECK:-1}" != 0 ] || return 0
    tags_file="$(git rev-parse --git-dir 2>/dev/null)/map-update-tags"
    [ -d "${tags_file%/*}" ] || return 0
    quiet_git "${MAP_UPDATE_SECONDS:-5}" "$tags_file" ls-remote --tags --refs "$MAP_UPSTREAM" 'v*'
    latest=$(newest_release "$tags_file" "$MAP_VERSION")
    rm -f "$tags_file"
    [ -n "$latest" ] && version_newer "$latest" "$MAP_VERSION" || return 0
    printf 'Multi-Agent Protocol: version %s is available; these scripts are %s. For the lead: it runs %s/upgrade.sh --check, and the lead asks the owner unless the project'"'"'s upgrade policy covers the release (PROTOCOL.md 12.3); other sessions wait for the lead. MAP_UPDATE_CHECK=0 turns this check off.\n' \
        "$latest" "$MAP_VERSION" "$MAP_SCRIPT_DIR"
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
    # Commit as this session: its identity as git resolves it here (environment, then this
    # worktree's configuration), not the temporary worktree's.
    author_ident=$(git var GIT_AUTHOR_IDENT 2>/dev/null) || author_ident=""
    committer_ident=$(git var GIT_COMMITTER_IDENT 2>/dev/null) || committer_ident=""
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
        if [ -n "$author_ident" ] && [ -n "$committer_ident" ]; then
            GIT_AUTHOR_NAME=$(ident_name "$author_ident") GIT_AUTHOR_EMAIL=$(ident_email "$author_ident") \
                GIT_COMMITTER_NAME=$(ident_name "$committer_ident") GIT_COMMITTER_EMAIL=$(ident_email "$committer_ident") \
                git -C "$MAP_WORKTREE" commit --quiet --no-verify -m "$2" || die "commit failed"
        else
            git -C "$MAP_WORKTREE" commit --quiet --no-verify -m "$2" || die "commit failed"
        fi
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
