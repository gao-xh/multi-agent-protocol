# Setting up remote work: relays, runners and owner commands

This page is the setup guide for task mode 15, "Remote lead, local agents"
([modes.md](modes.md)), and for driving a relay with owner commands (PROTOCOL.md 2.3). The setup session ([BOOTSTRAP.md](BOOTSTRAP.md)) and each joining session
([JOIN.md](JOIN.md)) use it to check the environment they run in and to guide the owner
through the choices that depend on it. Each piece is set up on the machine where it runs,
so most of this happens when that machine's session joins, not in the first setup.

| Piece | Runs on | Set up by |
| --- | --- | --- |
| Remote lead (or any line that sends work) | the web, a phone, another machine | the setup session or its own join |
| Relay or local line with `scripts/runner.sh` | the machine with the data, hardware or environment | that machine's join (section 2) |
| Owner commands with `scripts/remote.sh` | each computer the owner sends commands from | the owner, guided by any session on that computer (section 3) |

Check everything below without installing or changing anything; propose each change and
make it only after the owner approves it (PROTOCOL.md 3.2). Write the result into the
status file (`Wake`, `Can run`, `Owner present`).

## 1. What the setup asks

In the setup proposal (BOOTSTRAP.md, item 14) or the join report, one line each:

1. The relays and local lines: line name, machine label, agent tool, and the area (what
   it may run, read and write). A relay's area goes into its row in the role table.
2. For each, the runner command built for its tool (section 2.2) and how it stays running
   (section 2.4).
3. Whether the owner will drive relays with commands, and how they are checked: the line
   `- Owner commands:` (PROTOCOL.md 2.3). Explain the choice before asking:
   - **lenient**: no key; the owner types commands and they go unsigned. Quick to set
     up, but every session that can push the coordination branch (each agent of the
     project, and anything that misleads one of them) can then command the relays as
     the owner. Suits a private repository whose sessions the owner trusts, and relays
     whose permission settings already keep them from harm.
   - **strict** (the default): every command carries the owner's signature; one key per
     computer the owner sends from (section 3).
   - **off**: relays take only ordinary requests within their area.
   Then: which computers the owner sends from, and the default expiry.
4. How the remote lead waits for replies (section 4).
5. The approvals to ask for up front ([modes.md](modes.md), mode 15).

## 2. On the relay machine

### 2.1 Check

- Where to work: a folder that this machine's own rules allow (the agent's user-level
  rules file, a list of allowed folders, a shared machine's policy). Do not assume the
  home folder. Where a step of this guide would break such a rule, ask the owner and
  follow the machine's rule; make no exception on your own. Use a clone of the project in
  that folder (for Codex a clone, not a git worktree: section 2.2).
- Operating system and shell: macOS, Linux, or Windows with Git Bash (the scripts need a
  POSIX sh; PowerShell and cmd cannot run them).
- `git --version`; whether this checkout can fetch and push the coordination branch
  without a prompt (`scripts/inbox.sh <line>` exits 0 or 1, not 2). The runner never
  answers a credential prompt, so push access must work unattended (an SSH key or a
  credential helper).
- The agent tools present, with versions: `claude --version`, `opencode --version`,
  `codex --version`. Whether each is signed in or connected to its model provider (the
  owner does that in the tool; never put a key in a file or a message).
- Whether each tool is a program on the PATH or only a shell alias or function (`type
  claude`): the runner starts programs, so give an alias's full path instead (for
  example `~/.local/bin/claude`; the runner reports exit 127, "command not found",
  otherwise).
- `ssh-keygen` (the runner calls `verify.sh` for owner commands): `ssh -V` shows OpenSSH
  8.1 or later, which has `ssh-keygen -Y`.
- How the machine stays awake (section 2.4).
- On Windows: run every script, and the runner, in Git Bash; paths there look like
  `/c/Users/...`. Find a tool's full path with `command -v claude` (or `where claude` in
  cmd), and give the runner that path if `claude` or `codex` is not found in Git Bash.
  Windows has no `caffeinate`: the owner turns sleep off in the power settings.

### 2.2 Build the runner command

Start from the row for the tool, run in the relay's own worktree:

| Tool | Runner command | Keeps context (`--continue-args`) | Permission rules from `allow:` (`--allow-flag`) | Permissions for unattended runs |
| --- | --- | --- | --- | --- |
| Claude Code | `scripts/runner.sh <line> --continue-args --continue --allow-flag --allowedTools= -- claude -p` | `--continue` (checked with 2.1.308) | `--allowedTools=` with the `=` (checked: a separate value swallows the prompt) | `permissions.allow` and `deny` in the checkout's `.claude/settings.local.json` (not committed; never the user-level `~/.claude/` settings) |
| OpenCode | `scripts/runner.sh <line> --continue-args --continue -- opencode run` | `--continue` (documented; unverified with the runner) | none: `allow:` lines are logged and ignored | `permission` in `opencode.json` ([opencode.md](opencode.md), section 2) |
| Codex | `scripts/runner.sh <line> -- codex exec --sandbox workspace-write -c sandbox_workspace_write.network_access=true -c 'sandbox_workspace_write.writable_roots=["<clone>/.git"]'`, in a clone of its own (not a git worktree, whose metadata lies outside the sandbox) | `resume --last` would continue, but its order with `exec` options is unverified: leave it out | none | the sandbox mode and approval policy ([codex.md](codex.md)); `workspace-write` keeps `.git` read-only, so the clone's `.git` must be an extra writable root for fetch, commit and the coordination scripts |
| Aider | not suited to a relay: it does not run commands on its own ([aider.md](aider.md)) | | | |

Then add the options that fit:

- `--interval 10` when the owner sends commands and waits for them (default 30 seconds);
  each round is one `git fetch`.
- `--progress 5` to publish the run's output on the branch `<line>/progress`, which
  `remote.sh` shows while it waits. The output goes to the repository: leave it off when
  the agent may print secrets or private data.
- `--timeout <seconds>` for the longest run that makes sense (default one hour).
- `--wake-on-all` only if the agent must also run for messages that are only to `all`.
  By default those wait for the next run that a message addressed to the line or an
  owner command starts, so that broadcasts do not cost a model run on every relay.
- `MAP_STRICT=1` in the environment, and the session card of
  [compact-rules.md](compact-rules.md), for smaller or cheaper models.

Write the permission settings so that the relay's area runs without a prompt and nothing
else does: allow the protocol scripts, git on the line's branches and the commands of
the area; deny force-push and the actions of PROTOCOL.md 3.2. An unattended run that hits
a prompt stops until the timeout. These settings change what the agent may do without
asking, so the owner approves them. Write them in this checkout only (for Claude Code
`.claude/settings.local.json`, which git ignores; for OpenCode the checkout's
`opencode.json`), never in user-wide settings that every project on the machine shares.

### 2.3 Try it

Before leaving it unattended, run it once in a terminal with `--max-runs 1`, send the
relay a `question` from another session (or, with owner commands, `remote.sh` with "print
the date and the current branch"), and check `<git dir>/map-runner-<line>.log` and the
reply.

### 2.4 Keep it running

The runner is a long-running process: the owner approves how it runs (PROTOCOL.md 3.2).

| System | In a terminal (simplest) | Keep the machine awake | As a service (owner's choice) |
| --- | --- | --- | --- |
| macOS | run it in a terminal tab | `caffeinate -i scripts/runner.sh ...` keeps the machine awake while it runs (not with the lid closed on battery) | a LaunchAgent in `~/Library/LaunchAgents/` |
| Linux | a terminal, `tmux` or `screen` | `systemd-inhibit --what=idle:sleep scripts/runner.sh ...` | a systemd user unit |
| Windows (Git Bash) | a Git Bash window | the power settings, changed by the owner | a Task Scheduler task that starts Git Bash's `sh` |

A service starts after a reboot, but it needs unattended git and tool access as well;
If a runner or watcher stopped without cleaning up, its lock in the git directory
(`map-runner-<line>.lock` or `map-watch-<line>.lock`) is treated as stale once its process
is gone or runs another program; when a script still refuses, it names the lock and the
command that removes it. check the log after the first restart. Record the choice in the status file
(`Wake: runner`) and in the log the owner keeps for machine changes, with how to undo it.

## 3. On the owner's computer: commands

Check: a clone of the project with fetch and push access to the coordination branch,
and a POSIX sh (macOS, Linux, or Git Bash on Windows).

**Lenient (no key).** `scripts/remote.sh <relay>` opens the console; with no key it
sends commands unsigned and says so. When a reply asks for permission rules, the console
offers to allow them for one run and try again. Try one command (section 2.3) and stop here.

**Strict (signed).** Only the owner does these steps; an agent on that computer may guide
and check, but never writes or reads the private key.

1. Check: `ssh -V` shows OpenSSH 8.1 or later (Windows' own OpenSSH or Git Bash's both
   work when new enough).
2. Make one key per computer, with a passphrase, outside every repository and worktree:
   `ssh-keygen -t ed25519 -f ~/.ssh/map_owner -C "map owner, <computer label>"`.
   On Windows in Git Bash, `~` is the user's home folder.
3. Add its public key to the agent rules file on the main branch, one line per key:
   `- Owner signing key: <owner name> <contents of map_owner.pub without the comment>`.
   This changes who can approve as the owner: the owner approves it, and it reaches the
   main branch like any change to the rules (PROTOCOL.md 3.6). To revoke a lost key,
   remove its line the same way.
4. Test without sending: `scripts/remote.sh --key ~/.ssh/map_owner --print <relay> "test"
   >/tmp/command.md` and `scripts/verify.sh --file /tmp/command.md` prints the owner's
   name once the key is on the main branch.
5. Use: `MAP_SIGNING_KEY=~/.ssh/map_owner scripts/remote.sh <relay>` opens the console;
   `--expires <minutes>` (default 60) limits how long a command stays valid. When a
   reply asks for permission rules (lines `Rule needed: <rule>`), the console lists them and
   asks whether to allow them for one run and try again; only `y` sends the retry. To send from
   somewhere without the scripts, `--print` and paste the signed text into a session that
   sends it unchanged, or commit it as `messages/<UTC time>_owner_command.md` on the
   coordination branch.

## 3a. Sessions on the web

A relay or lead in Claude Code on the web runs in a fresh cloud container each time. If
it should run the project's full checks there, give its cloud environment a setup
script that installs the tools first, for example
`apt-get update && apt-get install -y openssh-client shellcheck dash ruby`;
`sh tests/test-scripts.sh` names a missing ssh-keygen (it skips those sections and exits
3). Such a session
waits for messages with `scripts/watch.sh --once <line>` as a background task instead of a
runner, and stops answering when its container is reclaimed.

## 4. The remote lead

A remote lead hands work to relays with `handover` or `question` messages and waits for
replies with `scripts/watch.sh --once <its line>` as a background task (Claude Code on the
web: a background shell command; it wakes the session when the reply arrives). Its
environment needs network access to the git host. When its container is reclaimed, the
owner reopens the session; the messages wait on the coordination branch.
