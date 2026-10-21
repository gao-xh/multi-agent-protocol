#!/bin/sh
# Copy the protocol, scripts and templates into a project, or update an earlier copy.
# Usage: install.sh [--dest DIR] <project-directory>
#   --dest DIR  folder inside the project (default: tools/multi-agent-protocol)
# Changes only files inside that folder; never edits AGENTS.md, commits or pushes.
set -u
PROG=install.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

dest=tools/multi-agent-protocol
while [ $# -gt 0 ]; do
    case "$1" in
        --dest) [ $# -ge 2 ] || die "--dest needs a value"; dest=$2; shift ;;
        -h | --help) sed -n '2,5s/^# \{0,1\}//p' "$0"; exit 0 ;;
        -*) die "unknown option '$1'" ;;
        *) break ;;
    esac
    shift
done
[ $# -eq 1 ] || die "usage: install.sh [--dest DIR] <project-directory>"
case "$dest" in /* | *..*) die "--dest must be a relative path inside the project" ;; esac
[ -d "$1" ] || die "no such directory: $1"
project=$(CDPATH='' cd -- "$1" && pwd)
source_root=$(CDPATH='' cd -- "${MAP_SCRIPT_DIR}/.." && pwd)
[ -f "${source_root}/PROTOCOL.md" ] || die "cannot find PROTOCOL.md next to ${MAP_SCRIPT_DIR}"
[ "$project" != "$source_root" ] || die "the project is the protocol repository itself"
target="${project}/${dest}"

action=installed
[ ! -e "${target}/PROTOCOL.md" ] || action=updated
mkdir -p "${target}/scripts" "${target}/templates" || die "cannot create ${target}"
cp "${source_root}/PROTOCOL.md" "${source_root}/LICENSE" "${target}/" || die "copy failed"
cp "${source_root}/adapters/AGENTS.md.snippet" "${target}/" || die "copy failed"
cp "${source_root}"/scripts/*.sh "${target}/scripts/" || die "copy failed"
cp "${source_root}"/templates/*.md "${target}/templates/" || die "copy failed"
chmod +x "${target}"/scripts/*.sh && chmod -x "${target}/scripts/lib.sh"

protocol_version=$(sed -n 's/^Version \([0-9.]*[0-9]\)\.*$/\1/p' "${source_root}/PROTOCOL.md" | head -n 1)
source_commit=$(git -C "$source_root" rev-parse --short HEAD 2>/dev/null || printf 'unknown')
{
    printf 'Multi-Agent Protocol %s\n' "$protocol_version"
    printf 'Source: https://github.com/gao-xh/multi-agent-protocol (commit %s)\n' "$source_commit"
    printf 'Installed: %s\n' "$(utc_now)"
    printf 'Update: rerun scripts/install.sh from a newer clone; local edits to these files are overwritten.\n'
} >"${target}/VERSION"

note "${action} Multi-Agent Protocol ${protocol_version} in ${target}"
cat <<NEXT
Next steps:
  1. Paste ${dest}/AGENTS.md.snippet into the project's AGENTS.md (or CLAUDE.md) and fill it in;
     use PROTOCOL_PATH=${dest}/PROTOCOL.md and SCRIPTS_PATH=${dest}/scripts.
  2. ${dest}/scripts/init-coordination.sh   (once per project)
  3. Commit ${dest}/ on your own branch.
NEXT
