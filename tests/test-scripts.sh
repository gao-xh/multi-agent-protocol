#!/bin/sh
# End-to-end test of scripts/ in a throwaway repository with a local bare remote.
# Usage: tests/test-scripts.sh [shell]   (default: sh; for example: tests/test-scripts.sh dash)
# Leaves nothing behind: everything lives in a temp directory that is removed at exit.
set -u
test_shell=${1:-sh}
repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
scripts="${repo_root}/scripts"
work=$(mktemp -d "${TMPDIR:-/tmp}/map-test.XXXXXX") || exit 2
trap 'rm -rf "$work"' EXIT

failures=0
pass() { printf 'ok    %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
check() {
    description=$1
    shift
    if "$@" >"${work}/out" 2>&1; then pass "$description"; else fail "$description"; sed 's/^/      /' "${work}/out"; fi
}
check_status() {
    description=$1
    expected=$2
    shift 2
    "$@" >"${work}/out" 2>&1
    actual=$?
    if [ "$actual" -eq "$expected" ]; then pass "$description"; else fail "$description (exit ${actual}, expected ${expected})"; sed 's/^/      /' "${work}/out"; fi
}
run() { script=$1; shift; "$test_shell" "${scripts}/${script}" "$@"; }

export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

git init --quiet --bare -b main "${work}/remote.git"
git init --quiet -b main "${work}/lead"
(cd "${work}/lead" && git remote add origin "${work}/remote.git" &&
    printf 'demo\n' >README.md && git add README.md && git commit --quiet -m init && git push --quiet origin main)
git clone --quiet "${work}/remote.git" "${work}/api"

cd "${work}/lead" || exit 2
check "init creates the branch" run init-coordination.sh
check "init is idempotent" run init-coordination.sh
check "doctor passes on a fresh branch" run doctor.sh
check "layout has four folders" sh -c 'git ls-tree --name-only origin/coordination | tr "\n" " " | grep -q "README.md claims decisions messages status"'
check "development branch is untouched" sh -c '[ "$(git rev-parse --abbrev-ref HEAD)" = main ] && [ -z "$(git status --porcelain)" ]'

# Status files.
sed -e 's/<line>/lead/' -e 's/<lead \/ line \/ release>/lead/' -e 's/<branch>/lead\/demo/' "${repo_root}/templates/status.md" >"${work}/lead-status.md"
check "lead publishes its status" run status.sh lead "${work}/lead-status.md"
check "status gets Last-read none" sh -c "'$test_shell' '${scripts}/status.sh' lead | grep -q '^- Last-read: none'"
cd "${work}/api" || exit 2
sed -e 's/<line>/api/' "${repo_root}/templates/status.md" >"${work}/api-status.md"
check "api publishes its status" run status.sh api "${work}/api-status.md"

# Messages.
check_status "api inbox is empty" 1 run inbox.sh api
cd "${work}/lead" || exit 2
run send.sh --template handover | sed -e 's/^from:.*/from: lead/' -e 's/^to:.*/to: api/' -e 's/^refs:.*/refs:/' >"${work}/handover.md"
check "lead sends a handover" run send.sh "${work}/handover.md"
printf 'type: heads-up\nfrom: lead\nto: all\n\n- Change: config key renamed\n' >"${work}/heads-up.md"
check "lead sends a heads-up to all" run send.sh "${work}/heads-up.md"
printf 'type: question\nfrom: lead\nto: release\n\nWhich tag?\n' >"${work}/question.md"
check "lead sends a question to release" run send.sh "${work}/question.md"
check_status "send rejects an unknown type" 2 sh -c "printf 'type: chat\nfrom: lead\nto: api\n\nhi\n' >'${work}/bad.md' && '$test_shell' '${scripts}/send.sh' '${work}/bad.md'"
check_status "send rejects an underscore in the sender" 2 sh -c "printf 'type: question\nfrom: le_ad\nto: api\n\nhi\n' >'${work}/bad.md' && '$test_shell' '${scripts}/send.sh' '${work}/bad.md'"

cd "${work}/api" || exit 2
check "api sees two unread messages" sh -c "[ \"\$('$test_shell' '${scripts}/inbox.sh' api | wc -l | tr -d ' ')\" = 2 ]"
check_status "lead does not see its own messages" 1 run inbox.sh lead
first=$(run inbox.sh api | head -n 1)
check "inbox --show prints the body" sh -c "'$test_shell' '${scripts}/inbox.sh' --show api | grep -q '^## Goal'"
check "api marks the first message read" run mark-read.sh api "$first"
check "api now sees one unread message" sh -c "[ \"\$('$test_shell' '${scripts}/inbox.sh' api | wc -l | tr -d ' ')\" = 1 ]"
check "status keeps Last-read when republished" sh -c "'$test_shell' '${scripts}/status.sh' api '${work}/api-status.md' && '$test_shell' '${scripts}/status.sh' api | grep -q \"Last-read: \$(basename '$first')\""

# Concurrent sends from two clones: both must land.
cd "${work}/lead" || exit 2
printf 'type: answer\nfrom: lead\nto: api\n\nA\n' >"${work}/a.md"
printf 'type: answer\nfrom: api\nto: lead\n\nB\n' >"${work}/b.md"
run send.sh "${work}/a.md" >"${work}/send-a.out" 2>&1 &
pid_a=$!
(cd "${work}/api" && "$test_shell" "${scripts}/send.sh" "${work}/b.md") >"${work}/send-b.out" 2>&1 &
pid_b=$!
wait "$pid_a"; status_a=$?
wait "$pid_b"; status_b=$?
check "concurrent sends both succeed" sh -c "[ $status_a -eq 0 ] && [ $status_b -eq 0 ]"
git fetch --quiet origin coordination:refs/remotes/origin/coordination
check "both concurrent messages are on the branch" sh -c "[ \"\$(git ls-tree --name-only origin/coordination messages/ | grep -c _answer.md)\" = 2 ]"

# Claims.
check "lead claims a task" run claim.sh --branch lead/demo lead fix-login
check "lead renews its claim" run claim.sh --hours 2 lead fix-login
cd "${work}/api" || exit 2
check_status "api cannot take a held claim" 1 run claim.sh api fix-login
check_status "api cannot release lead's valid claim" 1 run release-claim.sh --stale api fix-login
check_status "invalid task slug is refused" 2 run claim.sh api ../escape
check "a zero-hour claim (immediately stale) can be made" run claim.sh --hours 0 api old-task
sleep 1
check "doctor warns about the stale claim" sh -c "'$test_shell' '${scripts}/doctor.sh' | grep -q 'stale claim'"
cd "${work}/lead" || exit 2
check_status "lead cannot take a stale claim with claim.sh" 1 run claim.sh lead old-task
check "lead releases the stale claim with --stale" run release-claim.sh --stale lead old-task
check "lead releases its own claim" run release-claim.sh lead fix-login
check "claims folder is empty again" sh -c "[ -z \"\$(git ls-tree --name-only origin/coordination claims/ | grep -v gitkeep)\" ]"

# Parallel release sessions take turns on the main branch.
check "release-a takes release-main" run claim.sh release-a release-main
cd "${work}/api" || exit 2
check_status "release-b must wait for release-main" 1 run claim.sh release-b release-main
cd "${work}/lead" || exit 2
check "release-a hands back release-main" run release-claim.sh release-a release-main
cd "${work}/api" || exit 2
check "release-b takes release-main next" run claim.sh release-b release-main
check "release-b hands back release-main" run release-claim.sh release-b release-main
cd "${work}/lead" || exit 2

# Doctor catches an edited message.
check "doctor passes before tampering" run doctor.sh
tamper=$(mktemp -d "${work}/tamper.XXXXXX")
git worktree add --quiet --detach "$tamper" origin/coordination
victim=$(git -C "$tamper" ls-files messages | grep -v gitkeep | head -n 1)
printf 'edited\n' >>"${tamper}/${victim}"
git -C "$tamper" commit --quiet -am "edit a message" && git -C "$tamper" push --quiet origin HEAD:coordination
git worktree remove --force "$tamper"
check_status "doctor reports the edited message" 1 run doctor.sh

check "no temporary worktrees are left behind" sh -c "[ \"\$(git worktree list | wc -l | tr -d ' ')\" = 1 ]"

printf '\n%s failure(s) with %s\n' "$failures" "$test_shell"
[ "$failures" -eq 0 ]
