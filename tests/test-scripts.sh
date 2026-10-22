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

# Review fixes: roles, read order, CRLF, names, numbers, listings.
sed -e 's/<line>/release-a/' -e 's/<lead \/ line \/ release>/release/' "${repo_root}/templates/status.md" >"${work}/release-a-status.md"
check "release-a publishes a status with Role: release" run status.sh release-a "${work}/release-a-status.md"
printf 'type: release-request\r\nfrom: lead\r\nto: release\r\n\r\n- Branch: lead/demo\r\n' >"${work}/crlf.md"
check "send accepts a CRLF message" run send.sh "${work}/crlf.md"
check "a message to the role reaches release-a" sh -c "'$test_shell' '${scripts}/inbox.sh' release-a | grep -q _lead_release-request.md"
check "status.sh --claims lists nothing stale yet" run status.sh --claims
check "status.sh --decisions runs" run status.sh --decisions
check_status "an option-like line name is refused" 2 run claim.sh lead -fix
check "claim.sh accepts --hours 08" run claim.sh --hours 08 lead octal-test
check "release the octal-test claim" run release-claim.sh lead octal-test

# mark-read keeps the order.
printf 'type: question\nfrom: lead\nto: api\n\nOne?\n' >"${work}/q1.md"
printf 'type: question\nfrom: lead\nto: api\n\nTwo?\n' >"${work}/q2.md"
q1=$(run send.sh "${work}/q1.md" 2>/dev/null)
sleep 1
q2=$(run send.sh "${work}/q2.md" 2>/dev/null)
cd "${work}/api" || exit 2
for pending in $(run inbox.sh api); do
    [ "$pending" = "$q1" ] && break
    run mark-read.sh api "$pending" >/dev/null 2>&1
done
check_status "mark-read refuses to skip an unread message" 2 run mark-read.sh api "$q2"
check "mark-read accepts the first unread message" run mark-read.sh api "$q1"
check "mark-read then accepts the next one" run mark-read.sh api "$q2"
check_status "mark-read refuses to move backwards" 2 run mark-read.sh api "$q1"
check "mark-read --force moves backwards" run mark-read.sh --force api "$q1"
check "mark-read --force moves forward again" run mark-read.sh --force api "$q2"
cd "${work}/lead" || exit 2

# Environment section and privacy checks.
check "the joined template is available" sh -c "'$test_shell' '${scripts}/send.sh' --template joined | grep -q '^type: heads-up'"
sed -e 's/<line>/env-test/' -e 's/^- Machine:.*/- Machine: build box at 10.0.0.12/' "${repo_root}/templates/status.md" >"${work}/env-status.md"
check "a status with an IP address can be published" run status.sh env-test "${work}/env-status.md"
check "doctor warns about the IP address" sh -c "'$test_shell' '${scripts}/doctor.sh' | grep -q 'env-test.md: looks like it contains an IP address'"
grep -v '^- Agent:' "${work}/env-status.md" | sed 's/^- Machine:.*/- Machine: laptop; macOS/' >"${work}/env-status-2.md"
check "a status without Agent can be published" run status.sh env-test "${work}/env-status-2.md"
check "doctor warns about the missing Agent field" sh -c "'$test_shell' '${scripts}/doctor.sh' | grep -q 'env-test.md: environment field'"
check "doctor no longer warns about privacy" sh -c "! '$test_shell' '${scripts}/doctor.sh' | grep -q 'env-test.md: looks like'"

# Line transfer: a handover addressed to the line itself reaches its successor.
printf 'type: handover\nfrom: transfer-test\nto: transfer-test\n\n## Transfer of line transfer-test\n' >"${work}/transfer.md"
printf 'type: heads-up\nfrom: transfer-test\nto: all\n\n- Change: own broadcast\n' >"${work}/own.md"
check "the transfer template is available" sh -c "'$test_shell' '${scripts}/send.sh' --template transfer | grep -q '^to: <line>'"
run send.sh "${work}/own.md" >/dev/null 2>&1
run send.sh "${work}/transfer.md" >/dev/null 2>&1
check "a line sees a handover addressed to itself, not its own broadcast" sh -c "[ \"\$('$test_shell' '${scripts}/inbox.sh' transfer-test | grep -c _transfer-test_)\" = 1 ] && '$test_shell' '${scripts}/inbox.sh' transfer-test | grep -q _handover.md"

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

# Session-start summary and line names.
check "session-start is silent without a line" sh -c "[ -z \"\$('$test_shell' '${scripts}/session-start.sh')\" ]"
check "set-line stores the line name" run set-line.sh api
check "set-line prints it back" sh -c "[ \"\$('$test_shell' '${scripts}/set-line.sh' 2>/dev/null)\" = api ]"
check "session-start reports unread messages" sh -c "'$test_shell' '${scripts}/session-start.sh' | grep -q 'unread coordination message'"
check "MAP_LINE overrides the stored name" sh -c "MAP_LINE=lead '$test_shell' '${scripts}/session-start.sh' | grep -q 'line \"lead\"'"
check "set-line --clear forgets it" run set-line.sh --clear

# Install into another project.
mkdir -p "${work}/other"
check "install copies the protocol into a project" run install.sh "${work}/other"
check "installed scripts are executable" test -x "${work}/other/tools/multi-agent-protocol/scripts/inbox.sh"
check "installed copy has templates and VERSION" sh -c "[ -f '${work}/other/tools/multi-agent-protocol/templates/handover.md' ] && grep -q '^Multi-Agent Protocol [0-9]' '${work}/other/tools/multi-agent-protocol/VERSION'"
check "installed send.sh finds its templates" sh -c "'$test_shell' '${work}/other/tools/multi-agent-protocol/scripts/send.sh' --template handover | grep -q '^type: handover'"
check "install updates an earlier copy" sh -c "'$test_shell' '${scripts}/install.sh' '${work}/other' 2>&1 | grep -q updated"
check_status "install refuses a path outside the project" 2 run install.sh --dest ../x "${work}/other"

# Decisions and signed owner records.
ssh-keygen -q -t ed25519 -N "" -C test-owner -f "${work}/owner_key"
printf '# Rules\n\n- Owner signing key: alice %s\n' "$(cut -d' ' -f1,2 "${work}/owner_key.pub")" >AGENTS.md
git add AGENTS.md && git commit --quiet -m "add owner key" && git push --quiet origin main
printf 'Owner decision: lead may release docs-only changes.\nScope: docs/ only. Exclusions: none.\n' >"${work}/decision.md"
ssh-keygen -q -Y sign -f "${work}/owner_key" -n map-approval "${work}/decision.md" 2>/dev/null
cat "${work}/decision.md.sig" >>"${work}/decision.md"
decision=$(run decide.sh docs-releases "${work}/decision.md" 2>/dev/null)
check "decide.sh publishes a decision" test -n "$decision"
check "verify.sh accepts the owner signature" sh -c "[ \"\$('$test_shell' '${scripts}/verify.sh' '$decision')\" = alice ]"
check_status "decide.sh refuses a second decision with the same topic today" 1 run decide.sh docs-releases "${work}/decision.md"
sed 's/docs\/ only/everything/' "${work}/decision.md" >"${work}/forged.md"
check_status "verify.sh rejects edited content" 1 run verify.sh --file "${work}/forged.md"
printf 'Owner says yes.\n' >"${work}/unsigned.md"
check_status "verify.sh rejects an unsigned record" 1 run verify.sh --file "${work}/unsigned.md"
ssh-keygen -q -t ed25519 -N "" -C other -f "${work}/other_key"
printf 'Owner decision: anything goes.\n' >"${work}/other.md"
ssh-keygen -q -Y sign -f "${work}/other_key" -n map-approval "${work}/other.md" 2>/dev/null
cat "${work}/other.md.sig" >>"${work}/other.md"
check_status "verify.sh rejects a signature by another key" 1 run verify.sh --file "${work}/other.md"
printf 'Second decision.\n' >"${work}/decision-2.md"
check "decide.sh --supersede marks the old decision" sh -c "'$test_shell' '${scripts}/decide.sh' --supersede '$(basename "$decision")' docs-releases-v2 '${work}/decision-2.md' >/dev/null 2>&1 && git show origin/coordination:'$decision' | grep -q '^superseded-by: '"
check "verify.sh still accepts the superseded decision" run verify.sh "$decision"

# Speed: a thousand messages pushed in one commit.
bulk=$(mktemp -d "${work}/bulk.XXXXXX")
git worktree add --quiet --detach "$bulk" origin/coordination
index=0
while [ "$index" -lt 1000 ]; do
    printf 'type: heads-up\nfrom: lead\nto: all\n\nBulk %s\n' "$index" >"${bulk}/messages/20261001T$(printf '%06d' "$index")Z_lead_heads-up.md"
    index=$((index + 1))
done
git -C "$bulk" add -A && git -C "$bulk" commit --quiet -m "bulk messages" && git -C "$bulk" push --quiet origin HEAD:coordination
git worktree remove --force "$bulk"
started=$(date +%s)
run inbox.sh lead >/dev/null 2>&1
elapsed=$(($(date +%s) - started))
check "inbox.sh handles 1000 new messages in under 10 s (took ${elapsed} s)" test "$elapsed" -lt 10
started=$(date +%s)
run doctor.sh >/dev/null 2>&1
elapsed=$(($(date +%s) - started))
check "doctor.sh handles them in under 15 s (took ${elapsed} s)" test "$elapsed" -lt 15

# Error messages.
check "a missing branch is reported as missing" sh -c "MAP_BRANCH=nope '$test_shell' '${scripts}/inbox.sh' lead 2>&1 | grep -q 'does not exist'"

check "no temporary worktrees are left behind" sh -c "[ \"\$(git worktree list | wc -l | tr -d ' ')\" = 1 ]"

printf '\n%s failure(s) with %s\n' "$failures" "$test_shell"
[ "$failures" -eq 0 ]
