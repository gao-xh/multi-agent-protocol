# Upgrading

## Find your version

- Scripts: `MAP_VERSION` in `scripts/lib.sh`; a vendored copy also has `VERSION` next to
  `PROTOCOL.md` (`tools/multi-agent-protocol/VERSION` by default).
- Each session: the `Protocol:` field of its status file, which `status.sh` fills in.
- Claude Code plugin: `/plugin`, Installed.
- Agent rules file: the begin marker of the block, `multi-agent-protocol: begin v1.4`
  (blocks written before 1.4 have no version).

From 1.4 on, `session-start.sh` and `doctor.sh` print one line when a newer release exists
(one `git ls-remote` of the public repository, stopped after `MAP_UPDATE_SECONDS`, default
5; set `MAP_UPSTREAM` to use another repository, or `MAP_UPDATE_CHECK=0` to turn the check
off; `doctor.sh --no-fetch` skips it). `doctor.sh` also warns when sessions report
different versions, and lists sessions on scripts before 1.4, which report none.

## Update

Upgrading needs the owner's approval (PROTOCOL.md 12.3), and the lead asks for it, unless
the project's upgrade policy covers the release. The policy is the `- Upgrades:` line of
the agent rules file, chosen by the owner: `manual` (default, ask about every release),
`patch` or `minor`. It never covers a new major version or a release whose rules block
changes.

1. A session sees the notice (or the owner asks). The lead runs
   `scripts/upgrade.sh --check <your-project>`: it prints the version of the project's
   copy, the newest release and its commit, the CHANGELOG sections in between, and whether
   the agent rules block changes. Copies before 1.6 have no `upgrade.sh`: clone the
   protocol repository anywhere and run its `scripts/upgrade.sh --check <your-project>`.
2. `--check` also says whether the policy covers the release. If it does, the lead goes on
   to step 3 and tells the owner afterwards. Otherwise the lead asks the owner whether to
   upgrade, naming the release, with that list and a recommendation. `--check` also lists
   the settings the release adds that the project has not chosen yet (lines such as
   `- Commit author:`): the lead asks the owner about each in the same message, with its
   default, and writes every answer into the agent rules file, defaults included; a
   setting the owner leaves unanswered keeps its default. When a
   release renames a setting, it is listed as new: replace the old line. Other
   sessions do not upgrade on their own. If the owner is not
   present, the question waits with the lead's other questions (PROTOCOL.md 3.4).
3. After the owner's approval, or within the policy:
   - **Copied into the project:** on your own branch, `scripts/upgrade.sh --to X.Y.Z
     <your-project>` with the approved release. It installs that release with its own
     `install.sh`, overwriting `tools/multi-agent-protocol/` (local edits there are lost),
     and shows how the rules block changed. It refuses a release that is not newer than
     the copy unless you pass `--force`. Add `--commit <SHA>`, the commit `upgrade.sh --check`
     printed, so that the install refuses a tag that moved since you checked. Commit, and
     request a release.
   - **Claude Code plugin:** update by hand in `/plugin`. Keep the marketplace's
     auto-update off under every policy: it installs every release, major versions
     included, without the lead. Turn it on only if the owner grants exactly that as a
     standing authorization (PROTOCOL.md 3.3).
   - **Agent rules file:** apply the rules block changes that `upgrade.sh` shows, keeping
     your role table, owners, keys, standing authorizations and message types. Changing
     the agent rules file needs the owner's approval too (PROTOCOL.md 3.2).

## Upgrading a project with several sessions

Sessions on different versions can disagree, for example about message types.

1. After the approved upgrade is on the main branch, the lead sends a `heads-up` to
   `all`: the version, what changes, and what each session does.
2. Each session updates its copy from the main branch (pull, or update the plugin by hand
   to the same release) and publishes its status again, so the `Protocol:` field shows
   the new version. Sessions upgrade only to the release on the main branch.
3. Run `scripts/doctor.sh`: it warns while sessions still report different versions.
4. Use new features (new message types, new headers) only after every session has
   upgraded, unless the release notes say that older versions tolerate them.

## Trying a release candidate

Release candidates are on the branch `next` with a tag `vX.Y.Z-rc.N`; `main` and the
plugin marketplace keep the stable release. To try one in a project you can reset:

1. Clone the candidate: `git clone --branch v2.0.0-rc.N https://github.com/gao-xh/multi-agent-protocol map-rc`.
   A 1.3 copy has no `upgrade.sh`, so use the clone's.
2. See what changes: `map-rc/scripts/upgrade.sh --check --to 2.0.0-rc.N <your-project>`.
3. Install it on a branch of your project: `map-rc/scripts/upgrade.sh --to 2.0.0-rc.N <your-project>`.
4. For the Claude Code plugin, remove the stable marketplace first
   (`/plugin marketplace remove gao-xh-agents`), then `/plugin marketplace add ./map-rc`
   and install the plugin again.
5. Tell setup and join agents to read the files of the candidate's tag, not `main`.

## Notes for 2.0

Coming from 1.3, after the upgrade steps above:

- Replace the rules block with the new snippet, keeping the role table, owners, keys and
  standing authorizations. `upgrade.sh --check` lists the new settings (`- Approval
  records:`, `- Upgrades:`, `- Commit author:`, `- Owner commands:` and who approves
  changes to roles); the lead asks the owner about each. Unanswered ones keep their
  defaults.
- Every session publishes its status again (`status.sh`), so the `Protocol:` field and the
  Environment section show the new version and how the session is woken.
- Commit author: to have commits under each line's name checked, add `- Commit author:
  line` and set each session's git identity (PROTOCOL.md 5.5). `doctor.sh` then warns
  about older messages committed under other names until 100 newer commits of messages
  have passed (`MAP_AUTHOR_CHECK` sets the number), and about each status file until its
  line publishes it again under its own name. `- Commit author: owner` keeps everything
  under the owner's name, and nothing is checked.
- New behaviour sessions must follow: the lead asks every open question while the owner is
  present (PROTOCOL.md 3.4); reviews and approvals cover only the commit they name (3.1,
  9). The CHANGELOG section of 2.0.0 lists everything else.

## Compatibility promise

- Patch and minor releases never invalidate an existing coordination branch or existing
  messages, never remove or rename a script, and keep environment variables working.
- Older scripts tolerate what newer ones add: an unknown message type is a warning in
  `doctor.sh`, and `inbox.sh` still lists it (from 1.4 on).
- A change to the coordination branch layout ships with a migration script.
- Incompatible changes happen only in a major release, announced one release ahead in
  CHANGELOG.md.
