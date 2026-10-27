# Changelog

The protocol, the scripts and the Claude Code plugin share one version number, following
[Semantic Versioning](https://semver.org/). `PROTOCOL.md` states it as `MAJOR.MINOR`.

- **Major** (2.0.0): a project that followed the previous version must change something to
  stay compliant or keep working: a new or stricter required rule (MUST, REQUIRED), a
  changed default, a script, option, environment variable, file format, message header,
  template field or plugin name removed or renamed, or a changed install path.
- **Minor** (1.4.0): additions that change nothing for a project that ignores them:
  optional rules (SHOULD, MAY, or opt-in lines in the agent rules file), new scripts,
  options, message types, templates and adapters.
- **Patch** (1.3.2): wording, bug fixes and corrected facts, with no new rule or option.

Major and minor releases are published first as release candidates (`vX.Y.0-rc.N`).

## 2.0.0-rc.1 - 2026-10-27

The first release candidate of 2.0.0. It collects everything since 1.3.1, including the
interim versions 1.4.0 to 1.8.0, which were never published. Try it in a project you can
reset; report problems as issues.

### Highlights

- **Setup in three prompts**: first setup (adapters/BOOTSTRAP.md) proposes every setting
  on one numbered page; agents that join later use adapters/JOIN.md; one setting changes
  through adapters/CHANGE.md. Tools and plugins are checked and installed only with the
  owner's approval.
- **Waking agents**: `watch.sh` and a Claude Code plugin monitor announce new messages to
  an idle session; `runner.sh` starts a headless agent for each batch of new messages.
- **Remote work**: task mode 15 (a remote lead with agents on a local machine), the
  optional `relay` role, and owner commands sent with `remote.sh`, signed or (where the
  project allows it) unsigned. Setup guide: adapters/remote.md.
- **More roles and settings**: optional roles `liaison` and `relay`; customizable roles,
  permissions and project message types; settings for approval records, upgrades, commit
  author and owner commands; 15 task modes (adapters/modes.md).
- **Stricter verification**: reviews and approvals cover only the commit they name; a
  `review` message type; `send.sh --strict`.

### Upgrading from 1.3

Upgrade through the lead, with the owner's approval (PROTOCOL.md 12.3; UPGRADING.md).

1. Replace the rules block in the agent rules file with the new
   `adapters/AGENTS.md.snippet`, keeping the role table, owners, keys and standing
   authorizations. `scripts/upgrade.sh --check <project>` lists the new settings the
   project has not chosen; the lead asks the owner about each (unanswered ones keep
   their defaults): `- Approval records:`, `- Upgrades:`, `- Commit author:`,
   `- Owner commands:` and who approves changes to roles and permissions.
2. Replace the copied scripts and templates (`scripts/install.sh`), and the Claude Code
   plugin if you use it.
3. Rules that change what sessions must do: the lead asks every open question while the
   owner is present, and an absent owner's questions go to the lead (PROTOCOL.md 3.4);
   reviews and approvals are bound to a commit (3.1, 9); the release role checks those
   commits before merging (7).

### Reviews and approvals bound to a commit

#### Changed

- A review verdict and an owner approval of a specific change cover only the commit they
  name, and later commits that merge the main branch without conflicts or change
  documentation only; anything else needs a new review or approval (PROTOCOL.md 3.1, 9).
  The release role checks this before merging (PROTOCOL.md 7, step 6; skills/release),
  and a `release-request` lists its reviews with their SHAs. A new failure-mode row.
- Section 2.3 (Relays) sits under section 2 again.
- `runner.sh` takes its options before or after the line name. adapters/remote.md: give a
  tool that is only a shell alias by its full path (the runner reports exit 127).
- A relay asks for a missing permission with one line `Rule needed: <rule>` per rule
  (PROTOCOL.md 2.3, skills/relay, the runner's prompt); `remote.sh` lists them and asks
  whether to allow them for one run and try again (only `y` sends the retry).
- The scripts set `GIT_PAGER=cat`: in a terminal, `remote.sh` (and `inbox.sh --show`)
  stopped in git's pager when showing a message.
- Tests: the owner-command tests give each runner its own output file and wait up to 60
  seconds, so a slow first run no longer fails them under load.

#### Added

- README: "Where it fits", how MAP relates to AGENTS.md, MCP and A2A/ACP (English and
  Chinese).
- adapters/codex.md: `codex queue --thread <id> --message <text>` verified with Codex CLI
  0.162.0-alpha.17.2 for an idle, resumed interactive session; busy, unloaded and headless
  sessions remain unverified.

The work below was merged on the private development branch on 2026-10-22 under interim
version numbers 1.4.0 to 1.8.0, which were never published. It ships as one release,
2.0.0, because it contains incompatible changes, at least:

- Commit author (PROTOCOL.md 5.5): the default `line` changes whose name commits carry.
- Reserved names: `all` and `owner` can no longer be line or role names (2.1), and
  `Role:` holds a single name.
- `status.sh` refuses a `Last-read` that is neither `none` nor an existing message.
- New required behaviour for absent owners (3.4): a session without the owner present
  must not wait on a question only the owner can answer.
- Message type `review`: sessions on 1.3 scripts report it as an error, so every session
  upgrades before anyone sends one (UPGRADING.md).
- A new row in the role table always needs the owner's approval (5.5), even where a
  project delegated approval of role changes to the lead (2.2).

The owner reviewed every rule change on 2026-10-22 and kept all of them; 3.4 was
shortened, with its edge cases moved to the new Appendix A of PROTOCOL.md.

### Name

- The project's name is now written "MAP: Multi-Agent Protocol" (titles of PROTOCOL.md and
  the READMEs, the plugin description). The repository, plugin and install path keep their
  names.

### Remote lead, local agents

#### Added

- `scripts/runner.sh <line> -- <agent command>`: waits for new coordination messages for a
  line without a model call (`watch.sh`), starts the agent once per batch with a prompt
  that names the line and the messages (appended as the last argument), logs each run in
  the git directory, and waits again. One runner per line and worktree, `--timeout` per
  run (default one hour, child processes stopped), `--max-runs`, `--prompt-file`; it stops
  cleanly on a signal while it waits. Works with any agent that has a headless mode
  (OpenCode, Codex, Claude Code, Aider).
- Task mode 15, "Remote lead, local agents" (adapters/modes.md, BOOTSTRAP): a lead the
  owner can reach anywhere hands work to agents on a local machine (for example OpenCode
  with DeepSeek) through the coordination branch. `Wake: runner` in status files
  (PROTOCOL.md 5.5).
- Optional role relay (PROTOCOL.md 2, 2.3; skills/relay; snippet row): acts on one
  machine for a session that cannot reach it, running only the commands, checks and data
  reads its row in the role table allows and reporting the output with `answer` or
  `review`; it writes no implementation code and decides nothing. Mode 15 uses relays by
  default. Where a liaison speaks for the owner, a relay works for a session.
- Owner remote control of a relay (PROTOCOL.md 2.3, 5.4): a new message type `command`,
  signed with an owner signing key, with `id:`, `expires:` and optional `allow:` lines. A
  verified command counts as the owner speaking in the relay's session. `runner.sh`
  checks each command (signature, recipient, expiry, unused id) before the agent starts
  and names the verified and refused ones in the prompt. New `scripts/remote.sh`: signs,
  sends and follows commands from the owner's computer (a console, or `--print` to send
  through another session or a browser). New runner options: `--continue-args` (the
  agent continues its last session), `--allow-flag` (the `allow:` rules become the
  agent's permission options), `--progress` (the run's output on the branch
  `<line>/progress`, shown by `remote.sh`).
- `- Owner commands: strict | lenient | off` in the agent rules file (PROTOCOL.md 2.3, 3.1;
  snippet): strict (default) accepts only signed commands; lenient also accepts unsigned
  commands `from: owner`, so the owner needs no key; off accepts none. `remote.sh`
  without a key sends unsigned commands only where lenient is set.
- adapters/remote.md: the setup guide for remote work. What to check on the relay machine
  and on the owner's computers, the runner command for each agent tool (Claude Code,
  OpenCode, Codex), keeping the runner running on macOS, Linux and Windows, and the
  signing key steps. BOOTSTRAP (item 14, start cards) and JOIN (step 5) follow it.

### Since 1.8.0

#### Fixed

- Pre-release versions follow Semantic Versioning order: `version_newer` treats 2.0.0 as
  newer than 2.0.0-rc.1 and 2.0.0-rc.10 as newer than 2.0.0-rc.2. The update check and
  `upgrade.sh --check` offer release candidates (`vX.Y.Z-rc.N` tags) only to sessions on a
  pre-release. `upgrade.sh --to`, `dev/export-release.sh` and `dev/bump-version.sh` accept
  `X.Y.Z-rc.N`; an upgrade to a pre-release always needs the owner's approval. The version
  tests compare `X.Y` without the pre-release part.
- One watcher per line and worktree: `watch.sh` takes a lock in the worktree's git
  directory (`map-watch-<line>.lock`, holding its PID; stale when that process is gone). A
  second watcher for the same line there prints one line and exits 0, so two sessions in
  one worktree no longer both act as the line. `set-line.sh` binds every later session in
  the worktree (README, coordinate skill).

### Setup, join and change prompts

#### Changed

- The setup is split into three prompts. `adapters/BOOTSTRAP.md` (first setup) finds out
  what it can about the project and the agent itself, asks only the level, the task mode
  and which agents will work on it, then proposes every setting on one numbered page,
  each marked found, mode, default or assumed, which the owner accepts or changes by
  number; it shows the rules block before writing it, registers every known agent in
  the role table, joins itself, and ends with a start card per agent.
  `adapters/JOIN.md` (new) lets a later agent configure only itself from the project's
  rules: it takes its row in the role table, checks its environment, sets its git
  identity, publishes its status and announces itself, usually without a question.
  `adapters/CHANGE.md` (new) changes one setting through the lead, with a diff the owner
  approves.

#### Added

- Registering an agent with no row in the role table (PROTOCOL.md 5.5): with the owner in
  its session, the owner names its line there, which approves the new row; without the
  owner, it joins as pending (`Role: pending`), changes nothing, and the lead registers
  it after asking the owner. `doctor.sh` warns about status files whose line is not in
  the role table on the main branch, and names pending ones. The lead and coordinate
  skills follow. A transferring line is taken over only by the session the owner or the
  handover names, and a new row always needs the owner's approval.
- `install.sh` also copies `adapters/JOIN.md`, `adapters/CHANGE.md` and
  `adapters/README.md`, so that start cards can point to the copy in the project.
- Tools and plugins (the owner's request of 2026-10-23): the first setup and every joining
  session check what they need without installing anything (git, sh, ssh-keygen, the
  Claude Code plugin with its hook and monitor or the tool's equivalent, the git host's
  command-line tool, the project's checks), show it as a numbered item with each status
  and the exact install command or what skipping loses, install only what the owner
  approves item by item, and check again. A joining session without the owner sends the
  list to the lead as a question and joins without the missing parts.

### Upgrades ask about new settings

#### Added

- `upgrade.sh --check <project>` lists the settings of the new rules block (lines such
  as `- Commit author:`) that the project's rules on the main branch do not have yet; the
  lead asks the owner about each together with the upgrade, with its default and a
  recommendation, and
  writes every answer into the agent rules file, defaults included; a setting the owner
  leaves unanswered keeps its default (PROTOCOL.md 12.3, the owner's decisions of
  2026-10-23 and 2026-10-24). New settings always make the upgrade a question
  for the owner, whatever the upgrade policy.

### Merged on the private main branch as 1.8.0 (2026-10-22)

#### Added

- Optional role `liaison` (PROTOCOL.md 2, 3.4): a session the owner can open when the
  lead is out of reach, for example on a phone. It asks the owner the lead's open
  questions and the messages addressed `to: owner`, records the owner's answers and
  instructions in `decisions/` with the owner's words, and passes them on to the lead; it
  changes no code, starts no agents and decides nothing. Its records count like any
  record in `decisions/` (3.3), and the lead acts on a liaison's `handover` only within
  the record it names. `inbox.sh` delivers messages addressed `to: owner` to lead and
  liaison sessions, which share them like a role (the first to claim the message handles
  it); `doctor.sh` warns when such messages have no receiver. `all` and `owner` are
  reserved recipients: `status.sh` refuses them as line names. `doctor.sh` warns about a
  `Role:` that is not a single name, since messages to that role never reach it. New `liaison` skill in the Claude Code plugin; the snippet's
  role table, BOOTSTRAP (standard level) and mode 5 of
  `adapters/modes.md` follow.

### Merged on the private main branch as 1.7.0 (2026-10-22)

#### Added

- Commit author (PROTOCOL.md 5.5): `- Commit author: line | owner` in the agent rules
  file, chosen at setup. With `line` (the default), each session commits under its line
  name, so the history shows which line wrote what; with `owner`, under the owner's name.
  Status files and the `joined` heads-up gain `Git identity:`. The coordination scripts
  commit under the session's own identity (`git var`, so per-worktree configuration and
  `GIT_AUTHOR_NAME` count). When the rules file contains `- Commit author: line`,
  `doctor.sh` warns, once per name, about status files and messages in the last 100
  commits that added messages (`MAP_AUTHOR_CHECK`) committed under another name than
  their line's; projects without the line get no warnings. A commit name is
  self-declared: it tells honest sessions apart and proves nothing more.
- Four more task modes in `adapters/modes.md`: research or prototype, refactoring or
  migrating existing code, security audit or code review, and incident response.
- `- Upgrades:` and `- Commit author:` read the first word of their value, so the note in
  parentheses may continue on the next line, and capital letters are accepted.
  BOOTSTRAP asks for the choice (quick: line) and tells each session to set its identity.

### Merged on the private main branch as 1.6.0 (2026-10-22)

Rule changes requested by the owner on 2026-10-22, decided by line cloud under the owner's
standing authorization of that day; the owner reviews them before any public release.
Every session should upgrade (UPGRADING.md) before anyone sends a project message type.

#### Added

- Status files record how a session can be reached and what it can do: `Wake` (monitor,
  background task, session-start hook only, timer, none), `Pushes coordination branch`
  and `Owner present` (PROTOCOL.md 5.5, `templates/status.md`); the lead's status file
  gains "Open questions for the owner". `adapters/README.md` says what to write for each
  agent. Leads give work that cannot wait only to sessions that can be woken, and use
  sessions that cannot push the coordination branch as builders.
- Project message types (PROTOCOL.md 5.4): lines `- Message type: <name>: <purpose>` in
  `AGENTS.md`, `CLAUDE.md` or `.claude/CLAUDE.md` on the main branch. `send.sh` accepts
  them (after one quick fetch of the main branch when the local copy does not know them
  yet) and prints a template that names the purpose; `doctor.sh` treats them as known. A
  type only in a working tree is refused, a type must match one name exactly, and a line
  that reuses a protocol type's name is ignored.
- `adapters/modes.md`: ten task modes (simple GitHub collaboration, private development
  with public release, server deployment, app release, an owner liaison, package release,
  documentation or website, data pipelines, several services in one repository, open
  source with outside contributors), each with roles, where the code lives, release
  steps, the approvals to ask for up front and what to watch for.
- Upgrades go through the owner (PROTOCOL.md 12.3): when a newer release exists, the lead
  runs `scripts/upgrade.sh --check <project>` (the project's version, the newest release
  and its commit, the CHANGELOG sections in between, whether the rules block changes) and
  asks the owner; the approval covers that release only, and other sessions do not upgrade
  on their own. After the approval, `scripts/upgrade.sh --to X.Y.Z <project>` installs
  that release with its own `install.sh` and shows how the rules block changed; it refuses
  a release that is not newer unless `--force`, and never edits the rules file, commits
  or pushes; it runs safely from the copy it replaces. Plugin auto-update stays off
  unless the owner grants it as a standing authorization. The update notice, the lead
  skill, the snippet and UPGRADING.md say so.
- Upgrade policy (PROTOCOL.md 12.3), chosen at setup: `- Upgrades: manual | patch | minor`
  in the agent rules file. With `patch` or `minor`, `upgrade.sh --check` says when a
  release is within the owner's standing authorization, and the lead upgrades and tells
  the owner afterwards; new major versions and changes to the rules block are always
  asked about. BOOTSTRAP asks for it at the standard and detailed levels (quick: manual).
- `- Approval records: lenient | strict` in the agent rules file (PROTOCOL.md 3.3), chosen
  at setup: lenient (the default, as before) lets standing authorizations recorded
  unsigned in `decisions/` count; strict accepts, for the actions of 3.2, only
  authorizations in the agent rules file on the main branch or signed records.
- `MAP_MAIN` and `MAP_MAIN_REMOTE` (default: `MAP_REMOTE`) name the branch and remote
  that hold the agent rules, for a coordination branch kept in a separate private
  repository (`adapters/platforms.md`). `verify.sh` also reads `.claude/CLAUDE.md`.
- `dev/bump-version.sh X.Y.Z` (private) sets every version field and the CHANGELOG date.

#### Changed

- PROTOCOL.md 3.4: when the owner gives a task, the lead (or the session that plans it)
  asks every open question at once while the owner is present, and lists the approvals
  the plan will need so the owner can grant them up front. A session in which the owner
  is not present does not wait on a question for the owner: it sends a `question` to the
  lead (or to the owner's routine contact named in the rules file), which answers from
  the records or asks the owner and records the answer, and it works on something else
  meanwhile. An answer settles scope and behaviour; an action of 3.2 still needs the
  owner in the session, a signed record or a standing authorization that covers it, never
  an `answer` message alone. The lead does not block either: it
  keeps open questions in its status file. "Owner present" means present now; unknown
  counts as absent. Unattended sessions avoid commands that need permission prompts. The
  snippet, the compact rules and the lead and line skills follow.
- How changes to roles, permissions and message types are approved is chosen at setup
  (PROTOCOL.md 2.2, 12.2): owner only, through the lead (default: proposals go to the
  lead, the owner approves), or delegated to the lead within a standing authorization in
  the agent rules file, which never covers permissions for other actions of 3.2, owners,
  keys, standing authorizations, the lead and release roles, the owner's routine contact
  or the choice itself; the lead records its approvals in `decisions/`, and the session
  that advances the main branch checks them against the authorization on main. The snippet gets the setting and a section for message types.
- `adapters/BOOTSTRAP.md` asks first how detailed the setup should be (quick, standard or
  detailed) and which task mode fits, then asks only that level's questions, with
  recommendations from the mode. The detailed level adds several owners and signing keys,
  custom roles and permissions, the approval path, message types, how each session is
  woken and a private coordination repository.

### Merged on the private main branch as 1.5.0 (2026-10-22)

Rule changes, decided by line cloud under the owner's standing authorization of
2026-10-22 and to be reviewed by the owner before anything reaches the public repository.

#### Added

- Message type `review` (PROTOCOL.md 5.4 and 9, `templates/review.md`): review findings
  that send nothing back, for example a line's review of another line's work or a
  re-check. `returned` still sends work back. Scripts from 1.4.0 on list such messages
  and report the unknown type only as a warning; 1.3 scripts report it as an error, so
  upgrade every session to 1.4.0 before anyone sends `review` (UPGRADING.md). PROTOCOL.md
  5.1 lists reviews among the messages that must reach the coordination branch.
- Customizable roles and permissions (PROTOCOL.md 2.2): the roles of section 2, a new
  table of default permissions and the actions of 3.2 are defaults. A project may rename,
  combine, leave out or add roles and change permissions per role in the "Roles and
  permissions" part of its agent rules file; where it says nothing, the defaults apply.
  Not customizable: approvals only from owners, one session at a time advancing the main
  branch, one writer per working tree, independent review of new features and redesigns,
  and handovers, release requests, releases and returned work reaching every session. A
  permission that covers an action in 3.2 is a standing authorization of the owner;
  changes to roles and permissions always need the owner's direct approval. A renamed
  role keeps the default name in `Role:`. `adapters/AGENTS.md.snippet`, the lead, line and
  release skills, README files and section 4's main-branch rule follow.
- `adapters/README.md`: how mainstream agents (Claude Code, Codex, GitHub Copilot, Cursor,
  Gemini CLI, Windsurf, Cline, Kiro, Amp, OpenCode, Aider, Zed and others) read the rules,
  install the skills, learn about new messages, and whether they can push the
  coordination branch; checked on 2026-10-22, with unconfirmed points marked.
- `adapters/platforms.md`: Linux, macOS and Windows notes, and branch protection and a
  doctor check for GitHub, GitLab, Bitbucket, Gitea/Forgejo and Azure DevOps.
- `adapters/copilot.md` (the cloud agent works as a builder), `adapters/gemini.md`,
  `adapters/cursor.md`.
- `session-start.sh --json` prints the summary as `{"additionalContext": "..."}` for
  GitHub Copilot hooks, and `--json hook` as `hookSpecificOutput` for Gemini CLI.

#### Fixed

- Line endings: `.gitattributes` keeps `*.sh` LF, and `install.sh` writes the same rule into
  the copied folder, so the scripts run on Windows with Git's default `core.autocrlf`.

### Merged on the private main branch as 1.4.0 (2026-10-22)

No new obligations: PROTOCOL.md gains an optional `corrects:` header; its other edits
describe what the scripts do.

#### Added

- `scripts/watch.sh`: watches the coordination branch and prints one line per new message
  for a line (one summary line when more than `MAP_WATCH_MAX`, default 3, arrive at once),
  so that a tool which turns output into a notification can wake an idle agent. No model
  call: one bounded, non-interactive `git fetch` per round (`MAP_WATCH_SECONDS`, default
  30; `MAP_FETCH_SECONDS`, default 10). Each message is announced once per worktree, with
  a reminder every `MAP_WATCH_REMIND` seconds (default 3600) while it stays unread.
  `--once` prints what is new, or waits for it, then exits; `--rounds N` stops after N
  rounds.
- Claude Code plugin monitor (`monitors/monitors.json`): runs `watch.sh` for the line
  stored with `set-line.sh`, one interval after the session-start summary. It does nothing
  until a line name is set. Not yet checked in a real session.
- Optional message header `corrects: messages/<file>[, ...]`: `doctor.sh` reports the
  problems of a corrected message as warnings that name the correction; `send.sh` refuses
  a correction that names no message (PROTOCOL.md 5.2, 5.4).
- Update check: `session-start.sh` and `doctor.sh` print one line when `MAP_UPSTREAM`
  (default: the public repository) has a newer `vX.Y.Z` tag. One `git ls-remote`, at most
  `MAP_UPDATE_SECONDS` (default 5), silent when offline, off with `MAP_UPDATE_CHECK=0`;
  `doctor.sh --no-fetch` skips it.
- Versions across sessions: `status.sh` fills in a `- Protocol:` field (also in
  `templates/status.md`); `doctor.sh` warns when sessions report different versions,
  listing sessions on scripts before 1.4 (no `Protocol` field) as well;
  `init-coordination.sh` writes the version into the branch README; `MAP_VERSION` in
  `scripts/lib.sh`.
- `UPGRADING.md`: finding your version, updating, upgrading a project with several
  sessions, and the compatibility promise.
- `send.sh --strict` (or `MAP_STRICT=1`): refuses, with exit status 1, a message that still
  contains template placeholders `<...>` in the header or in a `- Field: <...>` line, still
  has a line of its template unchanged, or lacks a `## ` heading of its type's template
  (`templates/transfer.md` for a transfer handover), and lists what is missing. A partly
  edited line is not caught. `MAP_STRICT` also takes `yes` or `true`. Without it,
  `send.sh` only warns, as before.
  `adapters/compact-rules.md` recommends it for smaller models.

#### Changed

- `doctor.sh` reports a message type outside the known list as a warning (was an error),
  so older scripts tolerate types added later; a missing type is still an error.
  `inbox.sh` lists such messages, and `send.sh` still refuses them (PROTOCOL.md 5.4).
- `session-start.sh` records the messages it lists, so the monitor does not announce them
  again.
- `install.sh` writes the full version (for example 1.4.0) into `VERSION`.
- The begin marker of `adapters/AGENTS.md.snippet` carries the protocol version
  (`multi-agent-protocol: begin v1.4`); `adapters/BOOTSTRAP.md` accepts blocks with and
  without it.
- PROTOCOL.md 5.3 mentions `scripts/watch.sh` (approved by the owner on 2026-10-22).

#### Fixed

- `status.sh` refuses to publish a `Last-read` that is neither `none` nor a message on the
  branch, and says where the value came from (PROTOCOL.md 5.2).

## 1.3.1 - 2026-10-21

### Added

- `adapters/opencode.md` and `adapters/aider.md`: rules files, permissions or git
  behaviour, model choice (including DeepSeek), non-interactive runs, inbox polling and an
  environment example for each tool.
- `adapters/compact-rules.md`: how to assign work to smaller or cheaper models, and a
  short session card of exact script commands for their rules or first prompt.

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
