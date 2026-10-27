#!/bin/sh
# Check the owner signature of a decision or message (PROTOCOL.md 3.6).
# Usage: verify.sh <coordination-path>      for example decisions/2026-10-21_releases.md
#        verify.sh --file <local-file>
# Owner keys are read from lines "- Owner signing key: <name> <public key>" in AGENTS.md,
# CLAUDE.md and .claude/CLAUDE.md on the main branch (MAP_MAIN on MAP_MAIN_REMOTE), never
# from the coordination branch. Prints the signing owner's name.
# Exit status: 0 valid signature, 1 unsigned or invalid, 2 on error.
set -u
PROG=verify.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

local_file=""
case "${1:-}" in
    -h | --help | "") sed -n '2,9s/^# \{0,1\}//p' "$0"; [ $# -gt 0 ]; exit $? ;;
    --file) [ $# -eq 2 ] || die "usage: verify.sh --file <local-file>"; local_file=$2 ;;
    *) [ $# -eq 1 ] || die "usage: verify.sh <coordination-path>" ;;
esac
command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen is needed to verify signatures"
require_repo

work=$(mktemp -d "${TMPDIR:-/tmp}/map-verify.XXXXXX") || die "cannot create a temp directory"
trap 'rm -rf "$work"' EXIT

if [ -n "$local_file" ]; then
    [ -f "$local_file" ] || die "no such file: ${local_file}"
    cp "$local_file" "${work}/record" || die "cannot read ${local_file}"
else
    fetch_coordination
    show_file "$1" >"${work}/record" || die "no file '$1' on '${MAP_BRANCH}'"
fi

git fetch --quiet "$MAP_MAIN_REMOTE" "+refs/heads/${MAP_MAIN}:$(main_ref)" 2>/dev/null ||
    die "cannot fetch '${MAP_MAIN}' from '${MAP_MAIN_REMOTE}'"
main_rules | sed -n 's/^[[:space:]]*-[[:space:]]*Owner signing key:[[:space:]]*\([A-Za-z0-9._-][A-Za-z0-9._-]*\)[[:space:]][[:space:]]*\(ssh-[a-z0-9-]* [A-Za-z0-9+/=]*\).*$/\1 \2/p' >"${work}/allowed_signers"
[ -s "${work}/allowed_signers" ] || die "no '- Owner signing key:' line in the agent rules files on ${MAP_MAIN_REMOTE}/${MAP_MAIN}"

# The signed content is everything before the signature block.
sed '/^-----BEGIN SSH SIGNATURE-----$/,$d' "${work}/record" >"${work}/content"
sed -n '/^-----BEGIN SSH SIGNATURE-----$/,/^-----END SSH SIGNATURE-----$/p' "${work}/record" >"${work}/signature"
if [ ! -s "${work}/signature" ]; then
    note "not signed"
    exit 1
fi

while read -r owner _; do
    if ssh-keygen -Y verify -f "${work}/allowed_signers" -I "$owner" -n map-approval \
        -s "${work}/signature" <"${work}/content" >/dev/null 2>&1; then
        printf '%s\n' "$owner"
        exit 0
    fi
done <"${work}/allowed_signers"
note "signature does not match any owner key"
exit 1
