# Changelog

The protocol, the scripts and the Claude Code plugin share one version number, following
[Semantic Versioning](https://semver.org/): a major version changes a rule incompatibly, a
minor version adds rules, roles or tools, and a patch fixes wording or bugs.
`PROTOCOL.md` states the protocol version as `MAJOR.MINOR`.

## 1.3.0 - 2026-10-21

### Added

- Signed owner records (PROTOCOL.md 3.6): owner decisions and messages signed with the
  owner's SSH key (`ssh-keygen -Y`, namespace `map-approval`) count as direct approval;
  keys are listed in the agent rules file on the main branch.
- Transferring a line (PROTOCOL.md 5.7): a line moves to another agent, tool or machine
  under the same name; `templates/transfer.md`; a line now sees messages addressed to it
  by name even when it sent them, so the handover reaches its successor.
- `scripts/decide.sh` records decisions (with `--supersede`), `scripts/verify.sh` checks
  owner signatures.

### Changed

- Approvals may come from the owner's session or from a signed owner record (3.1, 3.5);
  the snippet, bootstrap prompt and skills say so.

## 1.2.0 - 2026-10-21

### Added

- Joining and environment (PROTOCOL.md 5.5): each session describes its tool, model,
  machine label, sandbox and network access, and what it can and cannot run in its status
  file, and announces itself with a `joined` heads-up (`templates/joined.md`). Privacy
  rules: machine labels instead of host names, no IP addresses, user names or secrets;
  `doctor.sh` warns about missing environment fields and likely private details.
  Claims moved to 5.6.
- Profiles (PROTOCOL.md 12.1): a minimal profile for one owner and two or three sessions,
  and the full profile with the conditions for moving up.
- Several owners (PROTOCOL.md 3.5): approval scopes per owner in the role table.
- `scripts/install.sh`: copy the protocol, scripts and templates into a project, or update
  an earlier copy; writes a `VERSION` file.
- `scripts/set-line.sh` and `scripts/session-start.sh`: remember a worktree's line name and
  print unread messages and active claims at session start.
- Claude Code plugin: an opt-in SessionStart hook that runs `session-start.sh` when the
  checkout has a line name; silent otherwise.
- `CHANGELOG.md`.

### Changed

- README: redrawn role diagram; related-work section removed.
- Messages addressed to a role reach every session whose status has that `Role:`; when
  several sessions hold it, the first to claim `msg-<timestamp>-<from>` handles it.
- A reviewer reports to whoever started it, who sends `returned`; reviewers never write to
  the coordination branch.
- Parallel release sessions use their own branch prefixes; the setup commit is the first
  release; the coordination branch is pulled with rebase.
- Claim files have an exact documented format.

### Fixed

- `inbox.sh` and `doctor.sh` read all message headers in one pass: 1000 messages now take
  about a second instead of minutes, so the session-start hook stays within its timeout.
- `mark-read.sh` refuses to skip an earlier unread message or move backwards (`--force`).
- CRLF line endings and different key case in headers, status and claim files are accepted.
- Fetch, push and remote errors are reported as such, not as a missing branch.
- Leftover temporary worktrees are pruned, and `doctor.sh` reports any that remain.
- `send.sh` returns the error status when publishing fails; fewer false placeholder warnings.
- Line names starting with `-` are refused; `claim.sh --hours 08` works.
- `status.sh --claims` and `--decisions` replace raw git commands in the coordinate skill.

## 1.1.0 - 2026-10-21

### Added

- Parallel sessions and project roles (PROTOCOL.md 2.1): unique line names per session,
  several leads by area, parallel release sessions serialized by the claim `release-main`,
  and project-defined roles that keep the reserved powers intact.
- GitHub Actions: script tests on Linux (dash, bash) and macOS, ShellCheck, and
  `claude plugin validate --strict`.

## 1.0.0 - 2026-10-21

First public version: PROTOCOL.md, message templates, coordination branch scripts with an
end-to-end test, the AGENTS.md snippet, the bootstrap prompt, Codex notes, and the Claude
Code plugin (lead, line, release and coordinate skills; builder and reviewer agents).
