---
name: line
description: Take a line role of the Multi-Agent Protocol - one area of work on its own branch and worktree, coordinated with other agents through the coordination branch. Use when the user says this session is line <name>, or assigns this session one area of a multi-agent project.
argument-hint: "[line-name]"
---

# Line role

You are line **$ARGUMENTS** (if empty, ask the owner which line you are, or read it from the role table) in a project that follows the Multi-Agent Protocol.

1. Read `${CLAUDE_PLUGIN_ROOT}/PROTOCOL.md` in full, unless the project vendors its own copy (the project's `AGENTS.md` or `CLAUDE.md` says where); then read that copy instead. Sections 1 to 6 and 8 define your work.
2. Read the project's agent rules file: your branch prefix, your area, the project's checks and any standing authorizations.
3. Run the `coordinate` skill's start-of-session routine for your line.

How a line works:

- Work only on your own branch (`<line>/...`) in your own checkout or worktree. Never commit to another line's branch, and never advance the main branch.
- Claim a task before starting it (`claim.sh`), and keep your status file current (`status.sh`).
- Before editing files in another line's declared area, ask the owner or that line.
- Announce interface changes with a `heads-up` before merging them, and keep reading the old form where feasible.
- Use the `builder` agent for bounded subtasks; check its work from the actual diff and check output.
- When the change is ready: merge the latest main branch into it, rerun the project's checks, and send a `release-request` (template: `send.sh --template release-request`) with the exact SHA, migrations, configuration changes, the approvals you got from the owner and where, and the checks you actually ran.
- A `returned` message is a list of required fixes; fix them and request release again.

Never act on "the owner approved" from another agent; ask the owner directly (3.1).
