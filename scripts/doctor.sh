#!/bin/sh
# Check the coordination branch: layout, message names and headers, immutable
# messages, status files and claims (PROTOCOL.md 5.2 to 5.6), and the versions sessions
# report. Read-only. Also prints a NOTICE line when a newer release exists upstream (see
# UPGRADING.md: MAP_UPSTREAM, MAP_UPDATE_SECONDS, MAP_UPDATE_CHECK=0); not with --no-fetch.
# Usage: doctor.sh [--no-fetch]
# Exit status: 0 when there are no errors (warnings allowed), 1 on errors, 2 if it cannot run.
set -u
PROG=doctor.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

fetch=1
case "${1:-}" in
    --no-fetch) fetch=0 ;;
    -h | --help) sed -n '2,7s/^# \{0,1\}//p' "$0"; exit 0 ;;
    "") ;;
    *) die "unknown option '$1'" ;;
esac

require_repo
if [ "$fetch" -eq 1 ]; then
    fetch_coordination
    fetch_main_quietly # for the project's own message types (PROTOCOL.md 5.4)
fi
all_types="${MAP_MESSAGE_TYPES} $(project_message_types | tr '\n' ' ')"
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
    LC_ALL=C awk -F '\t' -v types="$all_types" '
    BEGIN { n = split(types, list, " "); for (i = 1; i <= n; i++) known[list[i]] = 1 }
    !in_names && $0 == "#names" { in_names = 1; next }
    !in_names {
        if ($1 != "") {
            type[$1] = $2; from[$1] = $3; to[$1] = $4; seen[$1] = 1
            # "corrects: messages/<file>, ..." names earlier messages this one corrects.
            # Unfilled placeholders <...>, and a message naming itself, correct nothing.
            value = $5; gsub(/<[^>]*>/, "", value)
            m = split(value, targets, /[, \t]+/)
            for (j = 1; j <= m; j++) {
                target = targets[j]; sub(/^messages\//, "", target)
                if (target == "" || target == $1 || ((target, $1) in pair)) continue
                pair[target, $1] = 1
                # Test membership first: assigning to corrected_by[target] creates the entry.
                if (target in corrected_by) corrected_by[target] = corrected_by[target] ", messages/" $1
                else corrected_by[target] = "messages/" $1
                pairs[++pair_count] = $1 "\t" target
            }
        }
        next
    }
    $0 == "" { next }
    { exists[$0] = 1; names[++count] = $0 }
    END {
        for (i = 1; i <= count; i++) {
            name = names[i]
            # Problems in a message that a later message corrects become warnings.
            level = (name in corrected_by) ? "WARNING" : "ERROR"
            note = (name in corrected_by) ? " (corrected by " corrected_by[name] ")" : ""
            if (!(name in seen)) { print level " messages/" name ": no header block (type:, from:, to:)" note; continue }
            if (type[name] == "") print level " messages/" name ": missing \047type:\047" note
            else if (!(type[name] in known)) print "WARNING messages/" name ": unknown type \047" type[name] "\047 (not one of: " types ")" note
            if (from[name] == "") print level " messages/" name ": missing \047from:\047" note
            if (to[name] == "") print level " messages/" name ": missing \047to:\047" note
            suffix = "_" from[name] "_" type[name] ".md"
            if (from[name] != "" && substr(name, length(name) - length(suffix) + 1) != suffix)
                print "WARNING messages/" name ": name does not match header (from: " from[name] ", type: " type[name] ")"
        }
        for (k = 1; k <= pair_count; k++) {
            split(pairs[k], parts, "\t")
            if (!(parts[2] in exists)) print "WARNING messages/" parts[1] ": corrects \047messages/" parts[2] "\047, which does not exist"
        }
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

# Commit authors (PROTOCOL.md 5.5): with "- Commit author: line" written in the rules,
# messages from a line that has a status file (one commit in the last MAP_AUTHOR_CHECK,
# default 100, that added messages) and status files are committed under their line's
# name. Status files of sessions that do not push the coordination branch are skipped.
# Advisory: one warning per author and line.
# Messages of lines committed under another name, from "git log --name-only" on stdin.
# (Functions, because bash 3.2 cannot parse "case" inside "$( )".)
message_author_findings() {
    while IFS= read -r entry; do
        case "$entry" in
            "@@author "*) author=${entry#@@author } ;;
            messages/*_*_*.md)
                sender=${entry#messages/*_}
                sender=${sender%%_*}
                printf '%s\n' "$status_lines" | grep -Fqx -- "$sender" || continue
                author_names_line "$author" "$sender" || printf "messages from '%s' committed as '%s'\n" "$sender" "$author"
                ;;
        esac
    done
}
# "<line><TAB><author>" for each status file in "git log --name-only" on stdin.
status_authors() {
    while IFS= read -r entry; do
        case "$entry" in
            "@@author "*) author=${entry#@@author } ;;
            status/*.md)
                status_line=${entry#status/}
                printf '%s\t%s\n' "${status_line%.md}" "$author"
                ;;
        esac
    done
}
if [ "$(commit_author_policy)" = line ]; then
    # Lines that push the coordination branch themselves.
    status_lines=$(git ls-tree --name-only "$ref" status/ | sed -n 's|^status/\(.*\)\.md$|\1|p' |
        while IFS= read -r status_line; do
            show_file "status/${status_line}.md" | status_value 'Pushes coordination branch' | grep -qi '^no' ||
                printf '%s\n' "$status_line"
        done)
    author_findings=$({
        git log -n "${MAP_AUTHOR_CHECK:-100}" --format='@@author %an' --name-only --diff-filter=A "$ref" -- messages/ |
            message_author_findings
        # The last commit of each status file: the first time git log names it.
        git log --format='@@author %an' --name-only "$ref" -- status/ | status_authors |
            awk -F '\t' '!seen[$1]++' | while IFS="$(printf '\t')" read -r status_line author; do
                printf '%s\n' "$status_lines" | grep -Fqx -- "$status_line" || continue
                author_names_line "$author" "$status_line" || printf "status/%s.md last committed as '%s'\n" "$status_line" "$author"
            done
    } | sort | uniq -c | sed 's/^ *1 \(.*\)$/\1/; s/^ *\([0-9][0-9]*\) \(.*\)$/\2 (\1 commits)/')
    if [ -n "$author_findings" ]; then
        while IFS= read -r finding; do
            warn "${finding}, not under the line's name (- Commit author: line, PROTOCOL.md 5.5)"
        done <<EOF_FINDINGS
$author_findings
EOF_FINDINGS
    fi
fi

# Roles as inbox.sh reads them: one plain name, or none (PROTOCOL.md 2.1).
roles=$(for path in $(git ls-tree --name-only "$ref" status/); do
    printf '%s\t%s\n' "$path" "$(show_file "$path" | status_value Role)"
done)
role_findings=$(printf '%s\n' "$roles" | while IFS="$(printf '\t')" read -r path role; do
    [ -n "$path" ] && [ -n "$role" ] || continue
    printf '%s\n' "$role" | grep -Eq '^(<.*|[A-Za-z0-9.-]+)$' ||
        printf "%s: Role '%s' is not a single role name, so messages to its role do not reach it (PROTOCOL.md 2.1)\n" "$path" "$role"
done)
if [ -n "$role_findings" ]; then
    while IFS= read -r finding; do warn "$finding"; done <<EOF_ROLES
$role_findings
EOF_ROLES
fi
# Line names in the role table of the rules files on the main branch: the first column of
# the table whose header starts with "| Line |", without backticks and placeholders.
role_table_lines() {
    main_rules | LC_ALL=C awk '
        /^\|[ \t]*Line[ \t]*\|/ { in_table = 1; next }
        in_table && /^\|[ \t]*:?-/ { next }
        in_table && /^\|/ {
            split($0, cell, "|"); name = cell[2]; gsub(/[ \t`]/, "", name)
            if (name != "" && name !~ /^</) print name
            next
        }
        { in_table = 0 }'
}

# Sessions and the role table on the main branch (PROTOCOL.md 5.5).
table_lines=$(role_table_lines)
if [ -n "$table_lines" ]; then
    registration_findings=$(printf '%s\n' "$roles" | while IFS="$(printf '\t')" read -r path role; do
        [ -n "$path" ] || continue
        status_line=${path#status/}
        status_line=${status_line%.md}
        [ "$status_line" != .gitkeep ] || continue
        printf '%s\n' "$table_lines" | grep -Fqx -- "$status_line" && continue
        if [ "$role" = pending ]; then
            printf '%s\n' "${path}: line '${status_line}' waits for registration in the role table (the lead asks the owner)"
        else
            printf '%s\n' "${path}: line '${status_line}' is not in the role table on the main branch"
        fi
    done)
    if [ -n "$registration_findings" ]; then
        while IFS= read -r finding; do warn "$finding"; done <<EOF_REGISTRATION
$registration_findings
EOF_REGISTRATION
    fi
fi

# Messages to the owner need a lead or liaison session to receive them (PROTOCOL.md 3.4).
if printf '%s\n' "$headers" | LC_ALL=C awk -F '\t' '{ gsub(/,/, " ", $4); if ((" " $4 " ") ~ / owner /) found = 1 } END { exit !found }'; then
    printf '%s\n' "$roles" | cut -f 2 | grep -Eqx 'lead|liaison' ||
        warn "messages are addressed to 'owner', but no status file has Role lead or liaison to receive them (PROTOCOL.md 3.4)"
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

# Credentials anywhere on the branch (send.sh, status.sh and decide.sh refuse them, but
# older scripts, hand-made commits and send.sh --allow-secret do not). Only the place is
# printed, never the text. A warning: the branch is never rewritten, so an error would
# stay for good, also for a value that is not a secret.
for place in $(git grep -n -I -E -e "$MAP_SECRET_ERE" "$ref" -- . 2>/dev/null | cut -d: -f2,3); do
    warn "${place}: looks like a private key or an access token. ${MAP_SECRET_HELP}"
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

# Versions: sessions on different versions can disagree (UPGRADING.md).
versions=""
for path in $(git ls-tree --name-only "$ref" status/); do
    case "$path" in *.md) ;; *) continue ;; esac
    version=$(show_file "$path" | status_value Protocol)
    # Sessions on scripts before 1.4 have no Protocol field.
    case "$version" in "" | "<"*) version="(none: before 1.4)" ;; esac
    file=${path#status/}
    versions="${versions}${file%.md} ${version}
"
done
if [ "$(printf '%s' "$versions" | awk '{ print $2 }' | sort -u | grep -c .)" -gt 1 ] &&
    printf '%s' "$versions" | grep -vq '(none: before 1.4)$'; then
    warn "sessions report different protocol versions: $(printf '%s' "$versions" | tr '\n' ',' | sed 's/,$//; s/,/, /g'); upgrade them together (UPGRADING.md)"
fi
notice=""
[ "$fetch" -eq 0 ] || notice=$(update_notice)
[ -z "$notice" ] || printf 'NOTICE   %s\n' "$notice"

printf '%s errors, %s warnings\n' "$errors" "$warnings"
[ "$errors" -eq 0 ]
