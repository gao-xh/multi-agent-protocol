#!/bin/sh
# Check the owner signature of a decision or message (PROTOCOL.md 3.6).
# Usage: verify.sh <coordination-path>      for example decisions/2026-10-21_releases.md
#        verify.sh --file <local-file>
# Owner keys are read from lines "- Owner signing key: <name> <public key>" in AGENTS.md,
# CLAUDE.md and .claude/CLAUDE.md on the main branch (MAP_MAIN on MAP_MAIN_REMOTE), never
# from the coordination branch. Prints the signing owner's name.
# The signed text is everything before the signature block; after the block only blank
# lines and, except in an owner command, "superseded-by: <YYYY-MM-DD>_<topic>.md" lines
# (decide.sh --supersede) may follow. Anything else is refused, so that no unsigned text
# passes as the owner's words.
# Exit status: 0 valid signature, 1 unsigned or invalid, 2 on error.
set -u
PROG=verify.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

local_file=""
case "${1:-}" in
    -h | --help | "") sed -n '2,13s/^# \{0,1\}//p' "$0"; [ $# -gt 0 ]; exit $? ;;
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
    # Without prompts and with a time limit: runner.sh calls this with nobody there.
    quiet_git "${MAP_FETCH_SECONDS:-10}" /dev/null fetch --quiet "$MAP_REMOTE" "+refs/heads/${MAP_BRANCH}:$(coordination_ref)" ||
        die "cannot fetch '${MAP_BRANCH}' from '${MAP_REMOTE}' (offline, no access, timed out, or no such branch)"
    show_file "$1" >"${work}/record" || die "no file '$1' on '${MAP_BRANCH}'"
fi

fetch_main_quietly || die "cannot fetch '${MAP_MAIN}' from '${MAP_MAIN_REMOTE}' (offline, no access or timed out)"
# Any OpenSSH key type: ssh-ed25519, ssh-rsa, ecdsa-sha2-nistp256, and security keys
# (sk-ssh-ed25519@openssh.com, sk-ecdsa-sha2-nistp256@openssh.com).
main_rules | sed -n 's/^[[:space:]]*-[[:space:]]*Owner signing key:[[:space:]]*\([A-Za-z0-9._-][A-Za-z0-9._-]*\)[[:space:]][[:space:]]*\([a-z][a-z0-9@.-]* [A-Za-z0-9+/=]*\).*$/\1 \2/p' >"${work}/allowed_signers"
[ -s "${work}/allowed_signers" ] || die "no '- Owner signing key:' line in the agent rules files on ${MAP_MAIN_REMOTE}/${MAP_MAIN}"

# The signed content is everything before the signature block, byte for byte (CRLF line
# endings included); the block itself is read with any CR removed, so a record whose
# line endings were converted to CRLF after signing still finds its signature.
LC_ALL=C awk '{ line = $0; sub(/\r$/, "", line) } line == "-----BEGIN SSH SIGNATURE-----" { exit } { print }' \
    "${work}/record" >"${work}/content"
LC_ALL=C awk '
    { line = $0; sub(/\r$/, "", line) }
    line == "-----BEGIN SSH SIGNATURE-----" { inside = 1 }
    inside { print line }
    inside && line == "-----END SSH SIGNATURE-----" { exit }' "${work}/record" >"${work}/signature"
if [ ! -s "${work}/signature" ]; then
    note "not signed"
    exit 1
fi
# One complete block, and nothing after it but blank lines and, except in an owner
# command (never superseded), lines exactly as decide.sh --supersede writes them.
supersedable=1
[ "$(header_value type <"${work}/content")" != command ] || supersedable=0
trailing=$(LC_ALL=C awk -v supersedable="$supersedable" '
    { line = $0; sub(/\r$/, "", line) }
    !ended { if (line == "-----END SSH SIGNATURE-----") ended = 1; next }
    line ~ /^[ \t]*$/ { next }
    supersedable && line ~ /^superseded-by: [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[A-Za-z0-9.-]+\.md$/ { next }
    { bad = 1; exit }
    END { if (!ended) print "unterminated"; else if (bad) print "trailing" }' "${work}/record")
case "$trailing" in
    unterminated) note "the signature block has no '-----END SSH SIGNATURE-----' line"; exit 1 ;;
    trailing) note "text after the signature block is not signed; only blank lines and, in a decision, 'superseded-by: <YYYY-MM-DD>_<topic>.md' lines may follow it"; exit 1 ;;
esac
# On the branch, each superseded-by: line names a decision that exists.
if [ -z "$local_file" ]; then
    for successor in $(LC_ALL=C awk '{ line = $0; sub(/\r$/, "", line) } ended && sub(/^superseded-by: /, "", line) { print line } line == "-----END SSH SIGNATURE-----" { ended = 1 }' "${work}/record"); do
        git cat-file -e "$(coordination_ref):decisions/${successor}" 2>/dev/null || {
            note "superseded-by: names decisions/${successor}, which does not exist on '${MAP_BRANCH}'"
            exit 1
        }
    done
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
