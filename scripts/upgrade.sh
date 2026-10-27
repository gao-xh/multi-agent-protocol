#!/bin/sh
# Upgrade a project's copy of the protocol, after the owner approved it (PROTOCOL.md 12.3).
# The lead asks the owner first; "--check" prints what that question needs.
# Usage: upgrade.sh --check [--to X.Y.Z] [--dest DIR] [<project-directory>]
#            the version in use (the project's copy in DIR if a project is given, else
#            these scripts), the newest release upstream and its commit, the CHANGELOG
#            sections in between, and whether the agent rules block changes. Exit 0 when
#            the release is newer, 1 when not, 2 on error.
#        upgrade.sh [--to X.Y.Z] [--dest DIR] [--force] <project-directory>
#            install release X.Y.Z or X.Y.Z-rc.N (default: the newest) into <project-directory>/DIR
#            with that release's install.sh, and show how the rules block changes.
#            Refuses a release that is not newer than the copy in DIR unless --force.
# Upstream: MAP_UPSTREAM (default: the public repository). DIR defaults to
# tools/multi-agent-protocol. Changes only files in DIR; never edits AGENTS.md, commits
# or pushes. Claude Code plugin users update the plugin instead, with the owner's approval.
set -u
PROG=upgrade.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

# The "- Upgrades: manual | patch | minor" line of the agent rules on the main branch of
# the project in directory $1, freshly fetched; "manual" when the fetch fails, the line is
# missing or its value is anything but one of those words (optionally with a comment in
# parentheses).
upgrade_policy() {
    (cd "$1" && fetch_main_quietly) >/dev/null 2>&1 || { printf 'manual\n'; return 0; }
    found=$(cd "$1" && rules_word Upgrades)
    case "$found" in patch | minor) printf '%s\n' "$found" ;; *) printf 'manual\n' ;; esac
}

# Settings of the release's rules block ($1: lines "- <Key>: <values> ...") that the
# project's agent rules on its main branch (file $2) have not chosen yet, numbered. A
# project line counts when its key is the same (or, for keys of several words, starts
# with it) and its value is not a placeholder "<...>". Message types are not settings.
new_settings() {
    LC_ALL=C awk '
        function key_of(line) {
            sub(/^[ \t]*-[ \t]*/, "", line)
            line = substr(line, 1, index(line, ":") - 1); sub(/[ \t]+$/, "", line)
            return line
        }
        { sub(/\r$/, "") }
        FNR == NR {
            if ($0 ~ /^[ \t]*-[ \t]*[^:<]+:/) {
                key = key_of($0)
                value = substr($0, index($0, ":") + 1); sub(/^[ \t]+/, "", value)
                if (value != "" && value !~ /^</) chosen[key] = 1
            }
            next
        }
        /^- [^:<]+: </ {
            key = key_of($0)
            if (key == "Message type") next
            if (key in chosen) next
            if (key ~ / /) {
                for (k in chosen) if (index(k, key " ") == 1) next
            }
            value = substr($0, index($0, "<"))
            if (index(value, ">")) value = substr(value, 1, index(value, ">")); else value = value " ..."
            printf "  %d. %s: %s\n", ++count, key, value
        }' "$2" "$1"
}

# The whole script is one function, called from its last line: install.sh replaces this
# file while it runs.
main() {
    check=0
    force=0
    to=""
    dest=tools/multi-agent-protocol
    seconds=${MAP_UPGRADE_SECONDS:-60}
    while [ $# -gt 0 ]; do
        case "$1" in
            --check) check=1 ;;
            --force) force=1 ;;
            --to) [ $# -ge 2 ] || die "--to needs a version"; to=${2#v}; shift ;;
            --dest) [ $# -ge 2 ] || die "--dest needs a value"; dest=$2; shift ;;
            -h | --help) sed -n '2,15s/^# \{0,1\}//p' "$0"; exit 0 ;;
            -*) die "unknown option '$1'" ;;
            *) break ;;
        esac
        shift
    done
    if [ -n "$to" ]; then
        printf '%s\n' "$to" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$' || die "--to takes a version such as 1.6.0 or 2.0.0-rc.1"
    fi
    case "$dest" in "" | . | ./ | /* | *..*) die "--dest must be a folder inside the project" ;; esac
    [ $# -le 1 ] || die "usage: upgrade.sh [--check] [--to X.Y.Z] [--dest DIR] [--force] [<project-directory>]"
    [ "$check" -eq 1 ] || [ $# -eq 1 ] || die "usage: upgrade.sh [--to X.Y.Z] [--dest DIR] [--force] <project-directory>"

    # The version in use: the project's copy, or these scripts.
    project=""
    current=$MAP_VERSION
    old_snippet="${MAP_SCRIPT_DIR}/../AGENTS.md.snippet"
    [ -f "$old_snippet" ] || old_snippet="${MAP_SCRIPT_DIR}/../adapters/AGENTS.md.snippet"
    if [ $# -eq 1 ]; then
        [ -d "$1" ] || die "no such directory: $1"
        project=$(CDPATH='' cd -- "$1" && pwd)
        old_snippet="${project}/${dest}/AGENTS.md.snippet"
        current=""
        if [ -f "${project}/${dest}/VERSION" ]; then
            # "Multi-Agent Protocol X.Y.Z" (or X.Y.Z-rc.N), or X.Y before 1.4.
            current=$(sed -n 's/^Multi-Agent Protocol \([0-9][0-9.]*\(-[0-9A-Za-z.]*\)\{0,1\}\).*$/\1/p' "${project}/${dest}/VERSION" | head -n 1)
            case "$current" in *.*.*) ;; *.*) current="${current}.0" ;; esac
        fi
    fi

    work=$(mktemp -d "${TMPDIR:-/tmp}/map-upgrade.XXXXXX") || die "cannot create a temp directory"
    trap 'rm -rf "$work"' EXIT
    trap 'rm -rf "$work"; exit 130' HUP INT TERM

    # The newest vX.Y.Z tag upstream, and the commit of the target.
    quiet_git "$seconds" "${work}/tags" ls-remote --tags "$MAP_UPSTREAM" 'v*' ||
        die "cannot list the releases of ${MAP_UPSTREAM} (offline?)"
    latest=$(newest_release "${work}/tags" "${current:-$MAP_VERSION}")
    [ -n "$latest" ] || die "no release tags (vX.Y.Z) in ${MAP_UPSTREAM}"
    target=${to:-$latest}
    grep -q "refs/tags/v${target}\$" "${work}/tags" || die "no release v${target} in ${MAP_UPSTREAM}"
    # An annotated tag's commit is on its "^{}" line; a lightweight tag points at it.
    commit=$(sed -n "s|^\([0-9a-f]*\)[[:space:]]*refs/tags/v${target}^{}\$|\1|p" "${work}/tags")
    [ -n "$commit" ] || commit=$(sed -n "s|^\([0-9a-f]*\)[[:space:]]*refs/tags/v${target}\$|\1|p" "${work}/tags")

    quiet_git "$seconds" /dev/null clone --quiet --depth 1 --branch "v${target}" "$MAP_UPSTREAM" "${work}/release" ||
        die "cannot fetch release v${target} from ${MAP_UPSTREAM}"

    if [ "$check" -eq 1 ]; then
        printf 'In use: %s%s. Newest release: %s. Checked release: v%s at commit %s (%s).\n' \
            "${current:-unknown}" "${project:+ (${project}/${dest})}" "$latest" "$target" "$commit" "$MAP_UPSTREAM"
        if [ -n "$current" ] && ! version_newer "$target" "$current"; then
            printf 'Not newer than the version in use: nothing to upgrade.\n'
            exit 1
        fi
        printf '\nChanges after %s up to %s (CHANGELOG.md of v%s):\n\n' "${current:-the version in use}" "$target" "$target"
        LC_ALL=C awk -v from="${current:-0.0.0}" -v to="$target" "${MAP_VERSION_AWK}"'
            /^## [0-9]+\.[0-9]+\.[0-9]+/ { version = $2; show = vcmp(version, from) > 0 && vcmp(version, to) <= 0; if (show) shown = 1 }
            show
            END { if (!shown) print "(no CHANGELOG sections in that range)" }' "${work}/release/CHANGELOG.md"
        rules_change=1
        if [ ! -f "$old_snippet" ]; then
            printf '\nNo earlier copy of the agent rules block to compare with.\n'
        elif cmp -s "$old_snippet" "${work}/release/adapters/AGENTS.md.snippet"; then
            printf '\nThe agent rules block is unchanged.\n'
            rules_change=0
        else
            printf '\nThe agent rules block changes: after the upgrade, apply the changes to the block in the project'"'"'s agent rules file, keeping its own tables.\n'
        fi
        # The project's upgrade policy, from its agent rules on the main branch (12.3).
        policy=manual
        [ -z "$project" ] || policy=$(upgrade_policy "$project")
        reason=""
        # Compare X.Y.Z without a pre-release part; a pre-release target always needs the owner.
        current_core=${current%%-*}
        target_core=${target%%-*}
        case "$policy" in
            patch) [ "${current_core%.*}" = "${target_core%.*}" ] || reason="it is not a patch release" ;;
            minor) [ "${current_core%%.*}" = "${target_core%%.*}" ] || reason="it is a new major version" ;;
            *) reason="the upgrade policy is manual" ;;
        esac
        case "$target" in *-*) reason=${reason:-"it is a pre-release"} ;; esac
        [ -n "$current" ] || reason=${reason:-"the version in use is unknown"}
        [ "$rules_change" -eq 0 ] || reason=${reason:-"the agent rules block changes"}
        # Settings new since the project's version (the owner's decisions of 2026-10-23 and 2026-10-24).
        if [ -n "$project" ]; then
            project_rules=$(cd "$project" && main_rules)
            if [ -z "$project_rules" ]; then
                printf '\nCannot read the agent rules on the project'"'"'s main branch: the lead checks by hand which settings of the new rules block the project has not chosen yet.\n'
            else
                if printf '%s\n' "$project_rules" >"${work}/project-rules" &&
                    settings=$(new_settings "${work}/release/adapters/AGENTS.md.snippet" "${work}/project-rules"); then
                    :
                else
                    settings=""
                    printf '\nCannot compare the settings: the lead checks by hand which settings of the new rules block the project has not chosen yet.\n'
                fi
                if [ -n "$settings" ]; then
                    printf '\nNew settings the project has not chosen yet (the lead asks the owner about each, with the default and a recommendation from the new rules block, and writes the answers into the agent rules file, defaults included; unanswered ones keep their defaults; PROTOCOL.md 12.3):\n%s\n' "$settings"
                    reason=${reason:-"the release adds settings the project has not chosen"}
                fi
            fi
        fi
        printf '\nUpgrade policy: %s (from "- Upgrades:" in the agent rules on %s/%s of the project; manual without a project or when that branch cannot be fetched).\n' "$policy" "$MAP_MAIN_REMOTE" "$MAP_MAIN"
        if [ -n "$reason" ]; then
            printf 'Upgrading needs the owner'"'"'s approval, because %s: the lead asks the owner (PROTOCOL.md 12.3), naming v%s at commit %s. After the approval:\n' "$reason" "$target" "$commit"
        else
            printf 'Within the owner'"'"'s standing authorization: the lead may upgrade to v%s without asking, and tells the owner afterwards (PROTOCOL.md 12.3):\n' "$target"
        fi
        printf '  sh %s/upgrade.sh --to %s <project-directory>\nClaude Code plugin: update the plugin by hand to the same release; keep its auto-update off, because it also installs major versions (PROTOCOL.md 12.3).\n' \
            "$MAP_SCRIPT_DIR" "$target"
        exit 0
    fi

    installed="${project}/${dest}"
    if [ -n "$current" ] && ! version_newer "$target" "$current" && [ "$force" -eq 0 ]; then
        die "v${target} is not newer than the copy in ${installed} (${current}); pass --force to install it anyway"
    fi
    had_copy=0
    if [ -f "${installed}/AGENTS.md.snippet" ]; then
        cp "${installed}/AGENTS.md.snippet" "${work}/old.snippet"
        had_copy=1
    fi
    sh "${work}/release/scripts/install.sh" --dest "$dest" "$project" >"${work}/install.out" 2>&1 ||
        { cat "${work}/install.out" >&2; die "install.sh of v${target} failed"; }
    note "installed v${target} (commit ${commit}) in ${installed}"
    if [ "$had_copy" -eq 0 ]; then
        printf 'No earlier copy in %s: add the agent rules block from %s/AGENTS.md.snippet (adapters/BOOTSTRAP.md, step 6).\n' "$dest" "$dest"
    elif ! cmp -s "${work}/old.snippet" "${installed}/AGENTS.md.snippet"; then
        printf 'The agent rules block changed; apply these changes to the project'"'"'s block, keeping its own tables (owner approval, PROTOCOL.md 3.2):\n'
        diff -u "${work}/old.snippet" "${installed}/AGENTS.md.snippet" | sed '1,2d'
    else
        printf 'The agent rules block is unchanged.\n'
    fi
    printf 'Next: review the changes in %s, commit them on your own branch, and request a release; after it is on the main branch, tell every session to update (UPGRADING.md).\n' "$dest"
}

# One line: bash reads a script as it runs it, and the file may be replaced by now.
main "$@"; exit $?
