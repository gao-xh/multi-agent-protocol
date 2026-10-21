#!/bin/sh
# Check the coordination branch: layout, message names and headers, immutable
# messages, status files and claims (PROTOCOL.md 5.2 to 5.6). Read-only.
# Usage: doctor.sh [--no-fetch]
# Exit status: 0 when there are no errors (warnings allowed), 1 on errors, 2 if it cannot run.
set -u
PROG=doctor.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

fetch=1
case "${1:-}" in
    --no-fetch) fetch=0 ;;
    -h | --help) sed -n '2,5s/^# \{0,1\}//p' "$0"; exit 0 ;;
    "") ;;
    *) die "unknown option '$1'" ;;
esac

require_repo
[ "$fetch" -eq 0 ] || fetch_coordination
ref=$(coordination_ref)
git rev-parse --verify --quiet "$ref" >/dev/null || die "no local copy of '${MAP_BRANCH}'"

errors=0
warnings=0
error() { printf 'ERROR    %s\n' "$*"; errors=$((errors + 1)); }
warn() { printf 'WARNING  %s\n' "$*"; warnings=$((warnings + 1)); }

# Layout: only the known top-level entries.
for entry in $(git ls-tree --name-only "$ref"); do
    case "$entry" in
        README.md | status | messages | claims | decisions) ;;
        *) warn "unexpected top-level entry '${entry}'" ;;
    esac
done
for folder in status messages claims decisions; do
    git cat-file -e "${ref}:${folder}" 2>/dev/null || error "missing folder '${folder}/'"
done

# The branch must not share history with the development branches.
if [ "$(git rev-list --max-parents=0 "$ref" | wc -l | tr -d ' ')" != 1 ]; then
    warn "'${MAP_BRANCH}' has more than one root commit; was a development branch merged into it?"
fi

# The message order relies on linear history (pull with rebase, never a merge commit).
if [ -n "$(git rev-list --merges -n 1 "$ref")" ]; then
    warn "'${MAP_BRANCH}' contains merge commits; message order may be unclear (pull with --rebase)"
fi

# Temporary worktrees left behind by interrupted runs of these scripts (this clone only).
git worktree prune 2>/dev/null
leftovers=$(git worktree list --porcelain | sed -n 's/^worktree \(.*\/map-coordination\.[^/]*\)$/\1/p')
if [ -n "$leftovers" ]; then
    printf '%s\n' "$leftovers" | while IFS= read -r leftover; do
        printf 'WARNING  leftover temporary worktree %s; if no script is running, remove it with: git worktree remove --force "%s"\n' "$leftover" "$leftover"
    done
    warnings=$((warnings + 1))
fi

# Messages: names and headers (read in one pass), and no edits or deletions after push.
message_names=$(git ls-tree --name-only "$ref" messages/ | sed 's|^messages/||' | grep -v '^\.gitkeep$')
headers=$(message_headers)
for name in $message_names; do
    case "$name" in
        [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z_*_*.md) ;;
        *) error "message name 'messages/${name}' does not match <YYYYMMDDTHHMMSSZ>_<from>_<type>.md" ;;
    esac
done
problems=$({ printf '%s\n' "$headers"; printf '%s\n' '#names' "$message_names"; } |
    LC_ALL=C awk -F '\t' -v types="$MAP_MESSAGE_TYPES" '
    BEGIN { n = split(types, list, " "); for (i = 1; i <= n; i++) known[list[i]] = 1 }
    !in_names && $0 == "#names" { in_names = 1; next }
    !in_names { if ($1 != "") { type[$1] = $2; from[$1] = $3; to[$1] = $4; seen[$1] = 1 }; next }
    $0 == "" { next }
    {
        name = $0
        if (!(name in seen)) { print "ERROR messages/" name ": no header block (type:, from:, to:)"; next }
        if (!(type[name] in known)) print "ERROR messages/" name ": unknown or missing \047type:\047"
        if (from[name] == "") print "ERROR messages/" name ": missing \047from:\047"
        if (to[name] == "") print "ERROR messages/" name ": missing \047to:\047"
        suffix = "_" from[name] "_" type[name] ".md"
        if (from[name] != "" && substr(name, length(name) - length(suffix) + 1) != suffix)
            print "WARNING messages/" name ": name does not match header (from: " from[name] ", type: " type[name] ")"
    }')
if [ -n "$problems" ]; then
    while IFS= read -r problem; do
        case "$problem" in
            "ERROR "*) error "${problem#ERROR }" ;;
            "WARNING "*) warn "${problem#WARNING }" ;;
        esac
    done <<PROBLEMS
$problems
PROBLEMS
fi

changed=$(git log --format= --name-status --diff-filter=MDRT "$ref" -- messages/ | grep -v '/\.gitkeep$' | sort -u)
if [ -n "$changed" ]; then
    printf '%s\n' "$changed" | while IFS= read -r change; do
        printf 'ERROR    message changed or deleted after push: %s\n' "$change"
    done
    errors=$((errors + 1))
fi

# Status files: required fields, and Last-read pointing at a real message.
for path in $(git ls-tree --name-only "$ref" status/); do
    case "$path" in */.gitkeep) continue ;; *.md) ;; *) warn "unexpected file '${path}'"; continue ;; esac
    content=$(show_file "$path")
    for field in Role Branch Task State Last-read Updated; do
        [ -n "$(printf '%s\n' "$content" | status_value "$field")" ] || error "${path}: missing or empty '- ${field}:'"
    done
    for field in Agent Model Machine Sandbox "Can run" "Reachable by"; do
        [ -n "$(printf '%s\n' "$content" | status_value "$field")" ] ||
            warn "${path}: environment field '- ${field}:' is missing (PROTOCOL.md 5.5)"
    done
    # Privacy (5.5): no IP addresses or home-directory paths with user names.
    if printf '%s\n' "$content" | grep -Eq '(^|[^0-9.])([0-9]{1,3}\.){3}[0-9]{1,3}([^0-9.]|$)|/Users/[^/[:space:]]+|/home/[^/[:space:]]+|[A-Za-z]:\\Users\\'; then
        warn "${path}: looks like it contains an IP address or a home-directory path; use a machine label instead (PROTOCOL.md 5.5)"
    fi
    last_read=$(printf '%s\n' "$content" | status_value Last-read)
    last_read=${last_read#messages/}
    case "$last_read" in
        "" | none | "<"*) ;;
        *) printf '%s\n' "$message_names" | grep -Fqx "$last_read" || error "${path}: Last-read '${last_read}' is not a message" ;;
    esac
done

# Claims: required fields and stale leases.
now=$(utc_now)
for path in $(git ls-tree --name-only "$ref" claims/); do
    case "$path" in */.gitkeep) continue ;; *.md) ;; *) warn "unexpected file '${path}'"; continue ;; esac
    content=$(show_file "$path")
    holder=$(printf '%s\n' "$content" | status_value Owner)
    expires=$(printf '%s\n' "$content" | status_value Expires)
    if [ -z "$holder" ] || [ -z "$expires" ]; then
        error "${path}: missing '- Owner:' or '- Expires:'"
    elif is_before "$expires" "$now"; then
        warn "${path}: stale claim by '${holder}' (expired ${expires})"
    fi
done

# Decisions: names.
for path in $(git ls-tree --name-only "$ref" decisions/); do
    case "$path" in
        */.gitkeep) ;;
        decisions/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_*.md) ;;
        *) warn "decision name '${path}' does not match <YYYY-MM-DD>_<topic>.md" ;;
    esac
done

printf '%s errors, %s warnings\n' "$errors" "$warnings"
[ "$errors" -eq 0 ]
