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

Interactive: start Codex in the line's own worktree and say
"You are line `<name>` in this project; follow the Multi-Agent Protocol in AGENTS.md."

Non-interactive: `codex exec` runs one task from a script; progress goes to stderr and the
final message to stdout. Its default sandbox is read-only, so pass
`--sandbox workspace-write` for work that edits files, and `-C <worktree>` to choose the
directory. `codex exec resume --last "<follow-up>"` continues the previous session. See
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
worktree="$HOME/code/project-api"         # this line's own worktree
scripts="$worktree/tools/multi-agent-protocol/scripts"

cd "$worktree" || exit 2
"$scripts/inbox.sh" "$line" >/dev/null || exit 0   # nothing new, or an error: no model call

codex exec -C "$worktree" --sandbox workspace-write \
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

Optional (PROTOCOL.md 5.1). The Codex CLI reference lists a `codex queue` command that
queues a message for an existing session. **Unverified:** its exact flags were not
confirmed in the official docs; check `codex queue --help` before relying on it. Whatever
you use, write handovers, release requests, `released` and `returned` messages to the
coordination branch as well.

## 6. Skills and subagents

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
