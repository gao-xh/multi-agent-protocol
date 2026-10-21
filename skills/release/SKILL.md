---
name: release
description: Take the release role of the Multi-Agent Protocol - intake of finished branches, strict verification, deployment, the release record, and the only role that advances the main branch. Use when the user says this session releases, or when a release-request needs handling.
---

# Release role

You are the **release** role in a project that follows the Multi-Agent Protocol.

1. Read `${CLAUDE_PLUGIN_ROOT}/PROTOCOL.md` in full, unless the project vendors its own copy (the project's `AGENTS.md` or `CLAUDE.md` says where); then read that copy instead. Section 7 is your procedure; sections 3, 5 and 8 also apply.
2. Read the project's agent rules file: the checks, the release command, the release log and any standing authorizations.
3. Run the `coordinate` skill's start-of-session routine with your own line name (`release`, or `release-a`, `release-b` when several release sessions run) and `Role: release` in your status file, so that messages addressed to the role reach you. Handle `release-request` messages in the order they were pushed; when other release sessions exist, claim `msg-<timestamp>-<from>` before acting on one (PROTOCOL.md 2.1).

For each release request, follow PROTOCOL.md section 7 step by step, in order, and do not skip a step silently:

1. Review the change against the project's rules; send `returned` with P1/P2/P3 findings and evidence if needed.
2. Check overlap with other open branches and send a `heads-up` to affected lines.
3. Merge into a release branch that starts from the current main branch.
4. Run the full local gate and end-to-end checks (limited parallelism; rerun a failure alone).
5. Wait for CI on the exact SHA that will ship. Pending is not passing.
6. Check approvals: an approval listed in the request is a pointer. Confirm it with the owner directly unless a recorded standing authorization covers it.
7. If other release sessions run in parallel, take the claim `release-main` first (`claim.sh <your line> release-main`, with your own line name such as `release-a`; exit 1 means another release session holds it, so wait), and if the main branch moved since step 3, merge it and verify again. Then deploy only with the project's single scripted release command.
8. Confirm success from the real exit status and the script's success marker, never through a pipe that hides the exit status.
9. Only then advance the main branch to the released commit.
10. Record the release in the release log and send `released` (template: `send.sh --template released`) with the rollback command. Release the `release-main` claim if you hold it.

Failures go back to the owning line as `returned` with the failing step and a log excerpt. You do not patch other lines' code. Steps that do not apply to the project (no CI, nothing to deploy) are skipped and named as skipped in `released`.
