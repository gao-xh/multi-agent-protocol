#!/bin/sh
# Show or publish a line's status file (PROTOCOL.md 5.2, templates/status.md).
# Usage: status.sh <line>              print the line's current status
#        status.sh <line> <file>       publish <file> as status/<line>.md
#        status.sh --all               print every line's status
#        status.sh --claims            list active claims (owner, expires; stale ones marked)
#        status.sh --decisions         print the files in decisions/, newest first
# When publishing, the "- Updated:" field is set to the current UTC time, and an
# existing "- Last-read:" value is kept if <file> leaves it empty or as a placeholder,
# and "- Protocol:" is set to the version of these scripts.
# A Last-read that is neither "none" nor a message on the branch is refused (exit 2).
# It also fills in the environment facts it can detect, each marked "(detected by
# status.sh)": Toolchain (git, the shell that runs the scripts, python3 and uv when on
# PATH), Checkout (own clone or git worktree) and, in Machine, the part after the label
# (operating system, version and architecture). Only a field that is empty, a template
# placeholder <...> or marked as detected is written; text the agent wrote is kept, and a
# field the file does not have is not added. Never a host name, IP address, user name or
# path. MAP_STATUS_DETECT=0 turns this off; it is off too when this worktree belongs to
# another line (MAP_LINE or set-line.sh), as when a line reports for a builder. A value
# that ends with the mark is replaced on the next update: remove the mark when you edit it.
# The coordination fetch and push never prompt and stop after MAP_GIT_SECONDS (default 60).
set -u
PROG=status.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

case "${1:-}" in
    -h | --help | "") sed -n '2,22s/^# \{0,1\}//p' "$0"; [ $# -gt 0 ]; exit $? ;;
esac
require_repo
fetch_coordination

case "$1" in
    --claims)
        now=$(utc_now)
        for path in $(git ls-tree --name-only "$(coordination_ref)" claims/); do
            case "$path" in */.gitkeep) continue ;; esac
            content=$(show_file "$path")
            holder=$(printf '%s\n' "$content" | status_value Owner)
            expires=$(printf '%s\n' "$content" | status_value Expires)
            marker=""
            if [ -n "$expires" ] && is_before "$expires" "$now"; then marker=" (stale)"; fi
            task=${path#claims/}
            printf '%s\t%s\t%s%s\n' "${task%.md}" "${holder:-?}" "${expires:-?}" "$marker"
        done
        exit 0 ;;
    --decisions)
        for path in $(git ls-tree --name-only "$(coordination_ref)" decisions/ | grep -v '/\.gitkeep$' | LC_ALL=C sort -r); do
            printf '===== %s\n' "$path"
            show_file "$path"
            printf '\n'
        done
        exit 0 ;;
esac

if [ "$1" = --all ]; then
    for path in $(git ls-tree --name-only "$(coordination_ref)" status/); do
        case "$path" in *.md) show_file "$path"; printf '\n' ;; esac
    done
    exit 0
fi

line=$1
check_name line "$line"
case "$line" in all | owner) die "'${line}' is a reserved recipient, not a line name (PROTOCOL.md 2.1)" ;; esac
if [ $# -eq 1 ]; then
    show_file "status/${line}.md" || die "no status for '${line}'"
    exit 0
fi
[ $# -eq 2 ] || die "usage: status.sh <line> [<file>]"
[ -f "$2" ] || die "no such file: $2"
source_file=$(CDPATH='' cd -- "$(dirname -- "$2")" && pwd)/$(basename -- "$2")
input_name=$2
refuse_secrets "$source_file"

# Environment facts, detected here in the caller's checkout (write_status runs in a
# temporary worktree). Versions and names of programs only (templates/status.md).
detected_toolchain=""
detected_machine=""
detected_checkout=""
detect=1
case "${MAP_STATUS_DETECT:-1}" in 0 | no | false) detect=0 ;; esac
own_line=$(stored_line 2>/dev/null) || own_line=""
if [ "$detect" -eq 1 ] && [ -n "$own_line" ] && [ "$own_line" != "$line" ]; then
    note "not detecting environment facts: this worktree belongs to line '${own_line}', not '${line}'"
    detect=0
fi
if [ "$detect" -eq 1 ]; then
    detected_toolchain="git $(git --version 2>/dev/null | awk '{ print $3 }')"
    if [ -n "${BASH_VERSION:-}" ]; then
        shell_name="bash ${BASH_VERSION%%[(-]*}"
    else
        shell_name=$(ps -p $$ -o comm= 2>/dev/null | sed 's|.*/||; s/^-//')
    fi
    detected_toolchain="${detected_toolchain}; sh: ${shell_name:-sh}"
    if command -v python3 >/dev/null 2>&1; then
        python_version=$(python3 --version 2>/dev/null | awk '{ print $2 }')
        [ -z "$python_version" ] || detected_toolchain="${detected_toolchain}; Python ${python_version}"
    fi
    if command -v uv >/dev/null 2>&1; then
        uv_version=$(uv --version 2>/dev/null | awk '{ print $2 }')
        [ -z "$uv_version" ] || detected_toolchain="${detected_toolchain}; uv ${uv_version}"
    fi
    if [ "$(uname -s 2>/dev/null)" = Darwin ] && os_version=$(sw_vers -productVersion 2>/dev/null); then
        detected_machine="macOS ${os_version}"
    elif [ -r /etc/os-release ]; then
        detected_machine=$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | tr -d '"' | head -n 1)
    fi
    [ -n "$detected_machine" ] || detected_machine=$(uname -sr 2>/dev/null)
    detected_machine="${detected_machine}, $(uname -m 2>/dev/null)"
    git_dir=$(CDPATH='' cd -- "$(git rev-parse --git-dir)" && pwd -P)
    common_dir=$(CDPATH='' cd -- "$(git rev-parse --git-common-dir)" && pwd -P)
    if [ "$git_dir" = "$common_dir" ]; then detected_checkout="own clone"; else detected_checkout="git worktree"; fi
fi

write_status() {
    target="status/${line}.md"
    kept_last_read=""
    [ ! -e "$target" ] || kept_last_read=$(status_value Last-read <"$target")
    new_last_read=$(status_value Last-read <"$source_file")
    origin="in ${input_name}"
    case "$new_last_read" in "" | "<"*) new_last_read=${kept_last_read:-none}; origin="kept from the published ${target}" ;; esac
    if [ "$new_last_read" != none ] && ! is_message "$new_last_read"; then
        note "error: Last-read '${new_last_read}' (${origin}) is neither 'none' nor a message on '${MAP_BRANCH}'; set Last-read in ${input_name} to the last message this line has fully handled, or to none (PROTOCOL.md 5.2)"
        return 2
    fi
    now=$(utc_now)
    mkdir -p status
    # Updated and Last-read in any spelling that status_value reads, once.
    set_status_field Updated "$now" "$source_file" >"${target}.new" || return 2
    set_status_field Last-read "$new_last_read" "${target}.new" >"${target}.tmp" || return 2
    rm -f "${target}.new"
    # The Protocol field states the version of the scripts that publish the status.
    # Any spelling status_value would read ("-  protocol :"), once.
    sed -e "s|^# Status: <line>|# Status: ${line}|" "${target}.tmp" |
        LC_ALL=C awk -v version="$MAP_VERSION" '
            { line = $0; sub(/\r$/, "", line) }
            # Field lines only ("- Protocol: ..."); free text that starts with "Protocol:" stays.
            line ~ /^[ \t]*-[ \t]*[Pp][Rr][Oo][Tt][Oo][Cc][Oo][Ll][ \t]*:/ {
                if (!done) print "- Protocol: " version
                done = 1
                next
            }
            { print }' >"$target"
    rm -f "${target}.tmp"
    grep -q '^- Protocol:' "$target" || printf -- '- Protocol: %s\n' "$MAP_VERSION" >>"$target"
    [ -n "$detected_checkout" ] || return 0
    # Detected facts go only into fields that hold no text of the agent's: empty, a
    # placeholder, or detected before. In Machine only the part after "<label>; ".
    LC_ALL=C awk -v toolchain="$detected_toolchain" -v machine="$detected_machine" -v checkout="$detected_checkout" '
        function open_value(v) { return v == "" || v ~ /^</ || v ~ /\(detected by status\.sh\)$/ }
        {
            line = $0; sub(/\r$/, "", line)
            if (line ~ /^## /) { section = 1; fields = (tolower(line) ~ /^## environment([^a-z]|$)/) }
            if (section && !fields) { print; next }
            if (line !~ /^[ \t]*-[ \t]*[^:]+:/) { print; next }
            key = line; sub(/^[ \t]*-[ \t]*/, "", key); colon = index(key, ":")
            value = substr(key, colon + 1); key = tolower(substr(key, 1, colon - 1))
            gsub(/^[ \t]+|[ \t]+$/, "", key); gsub(/^[ \t]+|[ \t]+$/, "", value)
            mark = " (detected by status.sh)"
            if (key == "toolchain" && open_value(value)) { print "- Toolchain: " toolchain mark; next }
            if (key == "checkout" && open_value(value)) { print "- Checkout: " checkout mark; next }
            if (key == "machine" && (cut = index(value, "; ")) > 0 && open_value(substr(value, cut + 2))) {
                print "- Machine: " substr(value, 1, cut + 1) machine mark; next
            }
            print
        }' "$target" >"${target}.tmp" && mv "${target}.tmp" "$target"
}

publish_change write_status "chore: update status of ${line}" || exit $?
note "published status/${line}.md"
