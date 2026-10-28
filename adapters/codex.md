# Using the protocol with Codex

Codex sessions take part like any other agent: through the project's `AGENTS.md` and the
`coordination` branch. Nothing in the protocol depends on Claude Code.

The Codex facts below were checked against OpenAI's Codex documentation on 2026-10-21
(the developers.openai.com/codex pages now redirect to learn.chatgpt.com/docs). Codex
changes quickly; check the linked pages if something does not behave as described.

## 1. Rules: `AGENTS.md`

Codex reads `AGENTS.md` files on its own: a global one in `~/.codex/` (or `$CODEX_HOME`),
then one per directory from the project root down to the working directory, with closer
files taking precedence. The combined text is capped by `project_doc_max_bytes`
(32 KiB by default). See [AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

So: put the protocol snippet (`AGENTS.md.snippet`) in the project's root `AGENTS.md`. Keep
the snippet short and link to `PROTOCOL.md` instead of pasting it, so the size cap is not
reached. If the project also has a `CLAUDE.md`, keep the rules in `AGENTS.md` and have
`CLAUDE.md` point to it (or make it a symlink), so all agents read the same rules.

## 2. Network access for `git push`

The coordination scripts fetch and push. In Codex's `workspace-write` sandbox, network
access is off by default, so `git fetch` and `git push` fail. Either approve those
commands when Codex asks, or enable network access for the sandbox:

```toml
# ~/.codex/config.toml
[sandbox_workspace_write]
network_access = true
```

or for one run: `-c 'sandbox_workspace_write.network_access=true'`. See
[approvals and security](https://learn.chatgpt.com/docs/agent-approvals-security). This is
a configuration change on the owner's machine, so the owner decides (PROTOCOL.md 3.2).

## 3. Starting a session with a role

Use a clone of the project of its own for each Codex line, not a git worktree: in the
`workspace-write` sandbox `.git` is read-only, and a worktree keeps its git data in the
main checkout's `.git`, outside the sandbox, so commits and the coordination scripts fail.
In the clone, add its `.git` as a writable root for each run:
`-c 'sandbox_workspace_write.writable_roots=["<clone>/.git"]'`, together with
`-c sandbox_workspace_write.network_access=true` for fetch and push (section 2).

Interactive: start Codex in the line's own clone and say
"You are line `<name>` in this project; follow the Multi-Agent Protocol in AGENTS.md."

Non-interactive: `codex exec` runs one task from a script; progress goes to stderr and the
final message to stdout. Its default sandbox is read-only, so pass
`--sandbox workspace-write` for work that edits files, and `-C <clone>` to choose the
directory, with the two `-c` options above. `codex exec resume --last "<follow-up>"`
continues the previous session. See
[non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode).

## 4. Checking the inbox on a timer

The Codex CLI has no built-in scheduler, and Codex has no access to the coordination branch
other than git. Check the inbox with a cheap script first and wake Codex only when there
is something new (PROTOCOL.md 5.3). `inbox.sh` exits 0 when there are unread messages and
1 when there are none, and makes no model call.

```sh
#!/bin/sh
# check-inbox.sh: run from cron or launchd, for example every 15 minutes.
set -u
line=api                                  # this session's line
clone="$HOME/code/project-api"            # this line's own clone (not a worktree)
scripts="$clone/tools/multi-agent-protocol/scripts"

cd "$clone" || exit 2
"$scripts/inbox.sh" "$line" >/dev/null
case $? in
    0) ;;                                   # unread messages: wake the agent
    1) exit 0 ;;                            # nothing new: no model call
    *) echo "inbox check failed" >&2; exit 2 ;;  # surface errors (network, sandbox)
esac

codex exec -C "$clone" --sandbox workspace-write \
  -c sandbox_workspace_write.network_access=true \
  -c "sandbox_workspace_write.writable_roots=[\"$clone/.git\"]" \
  "You are line $line. Follow the Multi-Agent Protocol in AGENTS.md. Run
   $scripts/inbox.sh --show $line, handle each message in order, run
   $scripts/mark-read.sh $line <message> after handling each one, and report."
```

Adding a scheduled job is an action that needs the owner's approval (PROTOCOL.md 3.2).
Tell the owner what will run, how often, and how to remove it.

The ChatGPT/Codex apps have their own scheduled tasks
([automations](https://learn.chatgpt.com/docs/automations)); per that page they are not
available from the CLI. A shell timer like the one above works with any agent.

## 5. Direct messages between sessions

Optional (PROTOCOL.md 5.1). `codex queue --thread <session id> --message <text>` queues a
message for an existing Codex session (thread). Tested with Codex CLI 0.162.0-alpha.17.2 on
2026-10-27, between two local sessions:

- **Verified:** the receiving session was an interactive (TUI) session, resumed by hand
  and idle: it got the queued message as a user message in its next turn and replied.
  The sender needed the tool's normal permission escalation to reach the local Codex
  service.
- **Not verified:** delivery to a session that is busy in a turn, to one that is not
  loaded, or to a headless `codex exec` run (one attempt reported the message as queued,
  but no `exec` turn received it). Do not rely on `codex queue` to wake those.

Check `codex queue --help` on your version. Whatever you use, write handovers, release
requests, `released` and `returned` messages to the coordination branch as well.

## 6. The Codex plugin

This repository is also a Codex plugin: `.codex-plugin/plugin.json` with role skills
(`map-coordinate`, `map-lead`, `map-line`, `map-release`, `map-liaison`, `map-relay`) and
an optional session-start inbox summary. Install it from a clone with
`codex plugin marketplace add <path to the clone>` and
`codex plugin add multi-agent-protocol@gao-xh-map-codex`; details in
[codex/README.md](../codex/README.md). The hook runs only after you review and trust it.

## 7. Skills and subagents

- Codex supports skills: folders with a `SKILL.md` (`name`, `description`), found in
  `.agents/skills/` in the repository or `~/.agents/skills/` for the user. See
  [skills](https://learn.chatgpt.com/docs/build-skills). The role skills in this
  repository's `skills/` folder are written for Claude Code but are plain Markdown; they
  can be copied there. **Unverified:** whether every Claude Code-specific line in them
  (for example `${CLAUDE_PLUGIN_ROOT}`) is ignored cleanly by Codex; replace those paths
  with the vendored path when copying.
- Codex supports subagents, defined as TOML files in `.codex/agents/` or
  `~/.codex/agents/` (`name`, `description`, `developer_instructions`). Subagents inherit
  the parent's sandbox and approval settings. See
  [subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents). To use the
  builder and reviewer roles, put the instructions from `agents/builder.md` and
  `agents/reviewer.md` into `developer_instructions`. Because a subagent cannot loosen or
  tighten the parent's sandbox, a reviewer subagent can still write if its parent can: for
  a strictly read-only review, run the reviewer as its own session with
  `--sandbox read-only`.

## 8. Describing a Codex session's environment

When a Codex session joins (PROTOCOL.md 5.5), its status file could read, for example:

```
- Agent: Codex CLI <output of codex --version>
- Model: <model shown by Codex for this session, or "unknown">
- Machine: laptop; macOS 26.6
- Sandbox: workspace-write; network: no (pushes need approval)
- Can run: unit tests
- Cannot: push to the coordination branch without approval; reach the production server
- Reachable by: coordination branch only; checks the inbox every 15 minutes (cron)
```

The sandbox and network values matter most: with network off, the session cannot push
its status or messages without an approval (section 2), so other sessions should not
expect a quick reply from it.
