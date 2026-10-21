#!/bin/sh
# Check the coordination branch: layout, message names and headers, immutable
# messages, status files and claims (PROTOCOL.md 5.2 to 5.5). Read-only.
# Usage: doctor.sh [--no-fetch]
# Exit status: 0 when there are no errors (warnings allowed), 1 on errors, 2 if it cannot run.
set -u
PROG=doctor.sh
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

# Messages: names, headers, and no edits or deletions after push.
message_names=$(git ls-tree --name-only "$ref" messages/ | sed 's|^messages/||')
for name in $message_names; do
    [ "$name" = .gitkeep ] && continue
    case "$name" in
        [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z_*_*.md) ;;
        *) error "message name 'messages/${name}' does not match <YYYYMMDDTHHMMSSZ>_<from>_<type>.md"; continue ;;
    esac
    header=$(show_file "messages/${name}" | sed -n '/^$/q;p')
    message_type=$(printf '%s\n' "$header" | header_value type)
    from=$(printf '%s\n' "$header" | header_value from)
    to=$(printf '%s\n' "$header" | header_value to)
    known=0
    for candidate in $MAP_MESSAGE_TYPES; do [ "$candidate" = "$message_type" ] && known=1; done
    [ "$known" -eq 1 ] || error "messages/${name}: unknown or missing 'type:'"
    [ -n "$from" ] || error "messages/${name}: missing 'from:'"
    [ -n "$to" ] || error "messages/${name}: missing 'to:'"
    case "$name" in
        *_"${from}_${message_type}".md) ;;
        *) warn "messages/${name}: name does not match header (from: ${from}, type: ${message_type})" ;;
    esac
done

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
    for field in Branch Task State Last-read Updated; do
        printf '%s\n' "$content" | grep -q "^- ${field}:" || error "${path}: missing '- ${field}:'"
    done
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
