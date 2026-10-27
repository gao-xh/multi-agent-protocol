# GitHub Copilot

Checked on 2026-10-22 against GitHub's documentation. Covers Copilot in VS Code (agent
mode), the Copilot CLI and the Copilot cloud agent (formerly "coding agent").

## Rules and skills

- All three read `AGENTS.md` natively, beside `.github/copilot-instructions.md`
  ([docs](https://docs.github.com/en/copilot/reference/custom-instructions-support)).
- Skills: `.github/skills/`, `.claude/skills/` or `.agents/skills/` in the repository.

## Session start

A `sessionStart` hook in `.github/hooks/<name>.json` can run the summary. Only the
`additionalContext` of its JSON output reaches the model, and in the cloud agent it fires
once per job and runs only the `bash` command
([docs](https://docs.github.com/en/copilot/reference/hooks-reference)). Point it at
`sh tools/multi-agent-protocol/scripts/session-start.sh --json` (or your copy's path) with
`MAP_LINE` set for that session: `--json` prints the summary as
`{"additionalContext": "..."}`. Check the hook file format in the linked reference.

## The cloud agent cannot keep a line

The cloud agent pushes only to its own `copilot/` branch (or the pull request's branch) and
cannot run `git push` itself
([docs](https://docs.github.com/en/copilot/concepts/security-governance-and-network-settings/risks-and-mitigations)).
So it cannot write the coordination branch. Use it as a **builder** (PROTOCOL.md 2):

1. A line or the lead assigns it an issue with a self-contained task (the handover
   template's content works well) and the checks to run. Its branch will be `copilot/...`,
   not the line's prefix.
2. Its result is a pull request. The assigning line reviews it like any builder's work,
   from the diff and the check output, and reports on the coordination branch for it.

## Copilot CLI and VS Code

They run as your user and can run the scripts and push, like any local session. On
Windows the Copilot CLI requires PowerShell 6 or later; if its shell is PowerShell, call
`sh scripts/<name>.sh` with Git for Windows' `bin` on `PATH` (see platforms.md).
Headless: `copilot -p "..." -s --allow-tool='shell(git:*), write' --no-ask-user`.
