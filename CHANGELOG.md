# Changelog

The protocol, the scripts and the Claude Code plugin share one version number, following
[Semantic Versioning](https://semver.org/): a major version changes a rule incompatibly, a
minor version adds rules, roles or tools, and a patch fixes wording or bugs.
`PROTOCOL.md` states the protocol version as `MAJOR.MINOR`.

## 1.2.0 - 2026-10-21

### Added

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
