# Adapters: agents and platforms

The protocol needs three things from an agent: read the agent rules file (`AGENTS.md`),
run POSIX `sh` scripts that use git, and push its own branches and the `coordination`
branch. This page says how each mainstream agent does that. Facts were checked on
2026-10-22 against each tool's documentation or source; these tools change monthly, so
check the linked docs before relying on a detail. "Unconfirmed" means we could not verify
it.

Per-tool notes with more detail: [Codex](codex.md), [OpenCode](opencode.md),
[Aider](aider.md), [GitHub Copilot](copilot.md), [Gemini CLI](gemini.md),
[Cursor](cursor.md). Operating systems and git hosts: [platforms.md](platforms.md).
Smaller or cheaper models: [compact-rules.md](compact-rules.md). Presets for kinds of
projects: [modes.md](modes.md). Remote work (relays, runners, owner commands):
[remote.md](remote.md).

## 1. Getting the rules to the agent

One `AGENTS.md` at the repository root reaches almost every agent. Exceptions and traps:

| Agent | What to do |
| --- | --- |
| Claude Code | Reads `AGENTS.md` only when there is no `CLAUDE.md` (from 2.1.277). If the project has a `CLAUDE.md`, put the line `@AGENTS.md` in it ([docs](https://code.claude.com/docs/en/memory)). The plugin (README) adds the skills, agents, hooks and the inbox monitor. |
| Codex (CLI, IDE, app) | Reads `AGENTS.md` natively ([docs](https://developers.openai.com/codex/guides/agents-md)). See [codex.md](codex.md) for the sandbox. |
| GitHub Copilot (VS Code, CLI, cloud agent) | Reads `AGENTS.md` natively ([docs](https://docs.github.com/en/copilot/reference/custom-instructions-support)). |
| Cursor | Reads `AGENTS.md` natively, beside `.cursor/rules/` (from search summaries of [its docs](https://docs.cursor.com/context/rules)). |
| Gemini CLI | Reads `GEMINI.md` by default: add `{"context":{"fileName":["AGENTS.md","GEMINI.md"]}}` to `.gemini/settings.json` ([docs](https://github.com/google-gemini/gemini-cli/blob/HEAD/docs/cli/gemini-md.md)). |
| Aider | Reads nothing by default: add `read: AGENTS.md` to `.aider.conf.yml` ([aider.md](aider.md)). |
| Zed | Uses only the first file it finds among `.rules`, `.cursorrules`, ..., `AGENTS.md`, `CLAUDE.md`, so do not keep a `.rules` or `.cursorrules` next to `AGENTS.md` ([docs](https://github.com/zed-industries/zed/blob/HEAD/docs/src/ai/instructions.md)). |
| Windsurf / Devin Desktop, Cline, Kilo Code, Kiro, Amp, OpenCode, Junie, Qwen Code, Kimi Code, Goose, Factory Droid | Read a root `AGENTS.md` natively (Windsurf, Kiro, Amp, Junie and Kilo from search summaries of their docs, Factory from a third-party guide; the others from their docs or source). |

## 2. Skills, hooks and staying informed

The protocol's skills (`skills/`) follow the Agent Skills format. Outside Claude Code,
`npx skills add gao-xh/multi-agent-protocol` installs them into each detected agent's skill
folder ([skills CLI](https://github.com/vercel-labs/skills/blob/HEAD/README.md)); many
agents read `.agents/skills/`. The skills call the scripts through the Claude Code plugin's
path; in other agents, copy the scripts into the project with `scripts/install.sh` first,
and the skills use that copy, as the agent rules file names it.

An agent learns about new messages in one of three ways, best first:

1. **Woken while idle** by the inbox watcher (`scripts/watch.sh`): the Claude Code plugin
   monitor runs it. Other tools need a background task they own (see the per-tool notes).
2. **At session start** through a hook that runs `scripts/session-start.sh` and adds its
   output to the context. Confirmed for Claude Code (plugin), Codex, GitHub Copilot (CLI
   and cloud agent), Gemini CLI, Qwen Code and Kimi Code.
3. **By instruction**: `AGENTS.md` tells the agent to run `scripts/inbox.sh <line>` at
   session start and before each task (the snippet does this). This works everywhere.

| Agent | Session-start hook that reaches the model | Wake an idle session | Headless run for a timer |
| --- | --- | --- | --- |
| Claude Code | Yes (plugin `SessionStart`) | Plugin monitor (`watch.sh`) | `claude -p "..."` |
| Codex | Yes (`SessionStart`, hooks on by default; hooks you add must be trusted first) | Unconfirmed (app automations and the app-server, not the bare CLI) | `codex exec "..."` |
| GitHub Copilot | Yes (`sessionStart` in `.github/hooks/*.json`) | Cloud agent: automations on schedule or repository events | `copilot -p "..."` |
| Cursor | `sessionStart` exists; output to context unconfirmed | Unconfirmed | `agent -p "..." --force` |
| Gemini CLI | Yes (`SessionStart` `additionalContext`) | No | `gemini -p "..."` |
| Cline | Hooks in `.clinerules/hooks/` (details unconfirmed) | `cline schedule` | `cline "..."` |
| OpenCode | Plugin events (needs plugin code) | `opencode serve`, `POST /session/:id/prompt_async` | `opencode run "..."` |
| Aider | No | No | `aider --message "..." --yes-always` |
| Kiro | 3.x `SessionStart` (unconfirmed for 2.x) | Unconfirmed | `kiro-cli chat --no-interactive "..."` |
| Qwen Code, Kimi Code | Qwen: yes; Kimi: stdout "may be appended" (`SessionStart`) | Kimi: finished background tasks notify the agent | `qwen -p`, `kimi -p` |
| Windsurf, Amp, Zed, Junie, Factory, Antigravity | No or unconfirmed | Unconfirmed | Amp `amp -x`, Factory `droid exec`, Junie CLI; Windsurf and Zed: none found |

**What to write in the status file's `Wake` field** (PROTOCOL.md 5.5), starting from the
table and confirming it in the session: `monitor` for Claude Code with the plugin and a
line name set; `background task` where the agent runs `watch.sh --once` as a task it owns
and re-arms it (Cursor, Gemini CLI: unconfirmed); `session-start hook only` for Codex,
GitHub Copilot, Qwen Code and Kimi Code without a wake-up; `timer starts a new run` when a
cron job runs `inbox.sh` and a headless run; `runner` when `scripts/runner.sh` starts a
headless run for each batch of new messages (any agent with a headless mode in the last
column; adapters/modes.md, mode 15); `none` otherwise.

## 3. Pushing: who can maintain the coordination branch

Every session with a line name pushes its own branches and writes the coordination branch
(PROTOCOL.md 2.2, which a project can change). Some agents cannot:

| Agent | Limit | What to do |
| --- | --- | --- |
| GitHub Copilot cloud agent | Pushes only to its own `copilot/` branch and cannot run `git push` itself ([docs](https://docs.github.com/en/copilot/concepts/security-governance-and-network-settings/risks-and-mitigations)) | Use it as a **builder**: the line that assigns it writes the coordination branch for it. See [copilot.md](copilot.md). |
| Codex (`workspace-write`) | No network and a read-only `.git` by default | Allow network for git, or let the session ask for each push. See [codex.md](codex.md). |
| Claude Code on the web | Pushes only to GitHub repositories | Fine on GitHub; for other hosts use a local session. |
| Claude Code with its sandbox on | On macOS, git over SSH fails in the sandbox ([docs](https://code.claude.com/docs/en/sandboxing)) | Use HTTPS remotes, or exclude `git fetch`/`git push` from the sandbox. |
| Zed (sandboxed terminal) | `.git` read-only, network blocked unless approved | Approve git commands, or use another agent for the line. |
| Cursor and other cloud agents | Own VM and branch; push limits unconfirmed | Check before giving them a line; otherwise use them as builders. |

## 4. Windows

The scripts are POSIX `sh`. On Windows, run them with Git for Windows' `sh` (Git Bash) or
in WSL. Claude Code uses Git Bash when Git for Windows is installed. Cursor's agent, Gemini
CLI run commands in PowerShell, and the Copilot CLI requires PowerShell 6 or later: call `sh scripts/<name>.sh ...` (with
Git's `bin` on `PATH`) or `& "C:\Program Files\Git\bin\sh.exe" scripts/<name>.sh ...`.
OpenCode recommends WSL; Codex runs natively in PowerShell with its own sandbox or in WSL2. More in [platforms.md](platforms.md).
