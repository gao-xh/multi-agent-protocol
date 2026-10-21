#!/bin/sh
# Create the orphan coordination branch (PROTOCOL.md 5.2) and push it.
# Usage: init-coordination.sh
# Safe to rerun: does nothing when the branch already exists on the remote.
set -u
PROG=init-coordination.sh
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

case "${1:-}" in
    -h | --help) sed -n '2,4s/^# \{0,1\}//p' "$0"; exit 0 ;;
esac

require_repo
git remote get-url "$MAP_REMOTE" >/dev/null 2>&1 || die "no remote named '${MAP_REMOTE}' (set MAP_REMOTE)"

if git ls-remote --exit-code --heads "$MAP_REMOTE" "$MAP_BRANCH" >/dev/null 2>&1; then
    note "'${MAP_BRANCH}' already exists on '${MAP_REMOTE}'; nothing to do"
    fetch_coordination
    exit 0
fi

write_readme() {
    cat <<'README'
# Coordination branch

This orphan branch is the message board for the agents working on this project,
following the Multi-Agent Protocol (PROTOCOL.md, section 5). It is never merged.

    status/<line>.md                            one file per line, changed only by that line
    messages/<UTC timestamp>_<from>_<type>.md   one file per message, never changed after push
    claims/<task-slug>.md                       one file per claimed task
    decisions/<YYYY-MM-DD>_<topic>.md           owner decisions and standing authorizations

Read and write it with the protocol's scripts (inbox.sh, send.sh, claim.sh, ...),
or from a separate temporary worktree, never from a development checkout.
README
}

readme_blob=$(write_readme | git hash-object -w --stdin) || die "cannot write the README blob"

keep_blob=$(git hash-object -w --stdin </dev/null) || die "cannot write an empty blob"
keep_tree=$(printf '100644 blob %s\t.gitkeep\n' "$keep_blob" | git mktree) || die "cannot write a tree"

root_tree=$(
    {
        printf '100644 blob %s\tREADME.md\n' "$readme_blob"
        for folder in claims decisions messages status; do
            printf '040000 tree %s\t%s\n' "$keep_tree" "$folder"
        done
    } | git mktree
) || die "cannot write the root tree"

commit=$(git commit-tree "$root_tree" -m "chore: initialize coordination branch") || die "cannot create the commit"
git push --quiet "$MAP_REMOTE" "${commit}:refs/heads/${MAP_BRANCH}" || die "push to '${MAP_REMOTE}' failed"
fetch_coordination
note "created '${MAP_BRANCH}' on '${MAP_REMOTE}' at ${commit}"
