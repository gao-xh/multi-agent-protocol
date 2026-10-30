# MAP: Multi-Agent Protocol

[![check](https://github.com/gao-xh/multi-agent-protocol/actions/workflows/check.yml/badge.svg)](https://github.com/gao-xh/multi-agent-protocol/actions/workflows/check.yml)
[![stable](https://img.shields.io/github/v/release/gao-xh/multi-agent-protocol?label=stable)](https://github.com/gao-xh/multi-agent-protocol/releases/latest)
[![pre-release](https://img.shields.io/github/v/release/gao-xh/multi-agent-protocol?include_prereleases&label=pre-release&color=orange)](https://github.com/gao-xh/multi-agent-protocol/releases)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

[中文说明](README.zh-CN.md)

**Run Claude Code, Codex and other coding agents on one project as a team: plain git, any
tool, any machine and any model.**

Several agents on one repository go wrong in predictable ways: two sessions edit the same
working tree, two agents take the same task, a new session does not know what the last one
found, and "done" means "I pushed something". MAP is a protocol and a few POSIX shell
scripts that fix this with written handovers on a git branch, so agents from different
tools can split the work, hand it over, review each other and release. It is a
coordination and decision layer above your agent harnesses: they run the tools, and MAP
decides who does what, what may merge and what needs your approval.

<p align="center">
  <img src="docs/images/map-flow.svg" width="760"
       alt="You give the lead a goal. The lead hands work to line data (Codex) and line fit (Claude Code); data hands its loader to fit at an exact commit. The lead sends a review packet for that commit to a reviewer that did not build it, which reports its findings to the lead. Fit sends a release-request that names the review; the release role merges into main after the checks pass on that commit and reports back to the lead. You approve tags and publishing. Every solid arrow is a file on the coordination branch.">
</p>

**Quick start:** tell the agent that will lead "Set up this project with
https://github.com/gao-xh/multi-agent-protocol" ([details](#getting-started)).
**See it run:** [map-demo](https://github.com/gao-xh/map-demo) replays the story below in
one command, and [a 75-second video](https://github.com/gao-xh/map-demo/blob/main/docs/runs/2026-10-29-real-agents.mp4)
shows a real run with Claude Code and Codex.

https://github.com/user-attachments/assets/3dd7fc8b-3a6b-4d9c-9ed3-26bc05d11cc6

## How a feature gets built

1. You tell the lead what you want. It splits the work into **lines**, each one agent with
   its own branch and area, and sends each a `handover`: the goal, what is known, and what
   "done" means.
2. Each line **claims** its task, so no two agents start the same work, and builds in its
   own worktree.
3. In the demo project, the `data` line, in Codex, finishes the loader for the measurement
   files and hands it to the `fit` line, in Claude Code, naming the branch, the exact
   commit and the tests it ran. `fit` builds the decay fit on top of it.
4. The lead asks an agent that did not build the change to **review** that commit; the
   reviewer reports ranked findings with evidence back to the lead.
5. The line sends a release-request that names the review. The **release** role merges
   into `main` only after the checks pass on that exact commit, and reports back; tags and
   publishing wait for your approval.
6. When a session ends or runs out of context, it leaves a `transfer` handover; the next
   session, in any tool or on another machine, checks every branch SHA and carries on.

In a real run, Codex as the reviewer found a bug in Claude Code's fit (it failed when
the time axis did not start at zero); Claude Code fixed it and Codex approved the new
commit before release. [Timeline of that run](https://github.com/gao-xh/map-demo/blob/main/docs/runs/2026-10-29-real-agents.html).

You answer questions and approve; the agents do the rest, and a question that comes up
while you are away waits for you at the lead.

## What is on the branch

Every solid arrow in the picture is a file on a `coordination` branch in your own repository:

```
coordination
├── status/fit.md                                   who does what, in which environment
├── claims/decay-fit.md                             a task taken, until when
├── messages/20261029T023533Z_data_handover.md      one file per message, never edited
└── decisions/<date>_<topic>.md                     your decisions, in your words
```

<details>
<summary>What a handover looks like (from the demo)</summary>

```
type: handover
from: data
to: fit
refs: messages/20261029T023527Z_lead_handover.md

## Goal
Fit a decay time with its uncertainty for every run, using the new loader.

## Current state
- Branch: data/loader at 6bb4ab2c1681e262d600d7e4afa1ba7aceb94886 (pushed: yes)
- Code changed so far: src/decay_fit/load.py, tests/test_load.py

## Confirmed facts
- load_runs("data/sample") returns one Run per file with arrays t_s, signal, sigma
- Rows with missing values are dropped; tested with tests/test_load.py (7 passed)

## Suggested approach
- Branch from data/loader at the SHA above

## Blockers and decisions needed
- none

## Done means
- Tests: tests/test_fit.py recovers the known decay time of data/sample/run-03.csv
- Report back with: branch, SHA, checks run and results
```

</details>

## Why the rules exist

| What goes wrong without it | What MAP does |
| --- | --- |
| One session's tests pick up another session's half-written files | One writer per working tree, one branch per line |
| Two agents start the same task | A claim with an expiry before work starts |
| A new session redoes what the last one already found, or tried and failed | A written `handover` or `transfer` with SHAs, facts, the next step and what failed |
| "Done" turns out to mean "pushed something" | Done means a pushed commit SHA plus the checks that ran and their results |
| A review passed, then more code landed and shipped on it | A verdict covers only the commit it names |
| An agent says "the owner approved" | Only you approve; a relayed approval never counts |

Each row is a failure mode we hit; [PROTOCOL.md](PROTOCOL.md#11-known-failure-modes) has
the full table.

## Highlights

- **One team across tools and machines.** Claude Code, Codex, OpenCode, Copilot, Gemini
  CLI, Cursor and Aider work on the same project through plain git, with nothing to host
  beyond your git remote; the scripts need `git` and `sh`, and plugins for Claude Code and
  Codex add role skills. MAP needs no orchestrator: use it with plain terminal sessions,
  with any session manager, or with its optional runner.
- **Handoff that outlasts the session.** Even with a single agent, a `transfer` lets the
  next session, tool or machine continue from verified facts instead of a pasted summary.
- **No babysitting.** New messages reach the agents without you: an optional runner starts
  a headless agent (Claude Code, Codex, OpenCode) when a message arrives, a Claude Code
  monitor notifies an open session, and optional instant notifications can be added.
- **You stay in charge.** Approvals come only from you, directly or as a record signed
  with your SSH key; standing authorizations are written in your words with their scope.
- **Across projects.** An agent of another project, for example a downstream tool that
  implements the protocol, can follow your coordination branch as a listed outside
  correspondent and send questions and compatibility notices to your lead; it changes
  nothing in your project, and each project's owner approves only for their own project.

## Under the hood

- **[PROTOCOL.md](PROTOCOL.md)**: the protocol, in RFC 2119 wording.
- **[docs/how-it-works.md](docs/how-it-works.md)**: the roles, how agents talk on the
  coordination branch, and the script commands.
- **[UPGRADING.md](UPGRADING.md)**: how to find your version and update a project, with several sessions.
- **[scripts/](scripts/)**: POSIX `sh` tools for the git-based coordination branch. They need only git.
- **[templates/](templates/)**: message templates (handover, release request, released, returned, review, heads-up, joined, transfer, command, status, review packet; `send.sh --template question` and `answer` print the short ones).
- **[adapters/](adapters/)**: the `AGENTS.md` snippet, setup and join prompts for any agent, and notes per tool.
- **Claude Code plugin**: role skills (`lead`, `line`, `release`, `liaison`, `relay`, `coordinate`) and `builder` / `reviewer` agents.

## Getting started

> **For AI agents:** if you were given this link and asked to set the protocol up in a
> project, follow [adapters/BOOTSTRAP.md](adapters/BOOTSTRAP.md) step by step (raw text:
> https://raw.githubusercontent.com/gao-xh/multi-agent-protocol/main/adapters/BOOTSTRAP.md).
> It tells you what to check, what to ask the owner, and what to change only after they answer.
> If the project is already set up and you are asked to join it, follow
> [adapters/JOIN.md](adapters/JOIN.md) instead.

### 1. Set up the project

In your project, tell the agent that will lead (Claude Code, Codex or another): "Set up
this project with https://github.com/gao-xh/multi-agent-protocol". It follows
[adapters/BOOTSTRAP.md](adapters/BOOTSTRAP.md) by itself:

1. looks at the repository, its checks and its own environment, and changes nothing yet;
2. asks you three things: how much detail you want to see, what kind of project this is
   (a [task mode](adapters/modes.md)), and which agents will work on it;
3. proposes every setting on one numbered page, each marked as found, recommended or
   assumed: you answer "ok" or change items by number;
4. shows the rules block before writing it, writes it into `AGENTS.md`, creates the
   coordination branch and joins as the lead;
5. gives you a start card for each other agent: where to open it and what to paste.

Start small: one owner and two or three sessions need only the core rules; the
coordination branch and the release role come in as you add sessions, machines, tools or
owners ([profiles](PROTOCOL.md#121-profiles)). MAP is written for one owner and a modest
number of parallel sessions: with many more, review, the single `release-main` queue and
the owner's approvals become the limit before files do. Worktrees isolate files, not ports
or installed environments (PROTOCOL.md 4, "Runtime isolation").

### 2. Add the other agents

Open each agent in its own checkout of the project and tell it: "Join this project" (add
"as line `api`" if you know its line). The rules the lead wrote into `AGENTS.md` send it to
[adapters/JOIN.md](adapters/JOIN.md), which it follows by itself: it reads the project's
settings, checks its own environment, configures only itself and announces itself to the
team; usually it asks nothing. The lead's start cards say where to open each agent. An
agent that is not in the role table yet is added with your approval. To change a setting
later, give the lead [adapters/CHANGE.md](adapters/CHANGE.md).

### 3. Claude Code plugin (optional)

```text
/plugin marketplace add gao-xh/multi-agent-protocol
/plugin install multi-agent-protocol@gao-xh-agents
/multi-agent-protocol:coordinate set-line api      # once per worktree
```

Start each session with its role (`/multi-agent-protocol:lead`, `/multi-agent-protocol:line
api`, `/multi-agent-protocol:release`); `/multi-agent-protocol:coordinate` handles the
inbox, messages and claims, and `builder` and `reviewer` agents take delegated work. With a
line name set, each session starts with its unread messages and claims, and a monitor
notifies it when a new message arrives.

### Codex plugin (optional)

The same repository is a Codex plugin with the role skills and an optional session-start
inbox summary: `codex plugin marketplace add <path to a clone>`, then
`codex plugin add multi-agent-protocol@gao-xh-map-codex` ([codex/README.md](codex/README.md)).

### 4. Remote work (optional)

When you or the lead work away from the machine that has the data or the environment,
agents there still take work through the coordination branch (task mode 15).
`scripts/runner.sh` starts a headless agent (Claude Code, Codex, OpenCode) whenever new
messages arrive for its line; a `relay` runs the commands other sessions ask for on that
machine; and you can drive a relay from another computer with `scripts/remote.sh`, signed
with an SSH key or, where the project allows it, unsigned. When a relay lacks a
permission, `remote.sh` shows the rule it asks for and allows it for one run on your `y`.
Setup guide: [adapters/remote.md](adapters/remote.md).

### 5. By hand

```sh
git clone https://github.com/gao-xh/multi-agent-protocol
multi-agent-protocol/scripts/install.sh path/to/your-project   # rerun later to update
```

This copies the protocol, scripts and templates into `tools/multi-agent-protocol/` and
changes nothing else. Paste the snippet into `AGENTS.md` (point `CLAUDE.md` to it for
Claude Code), fill in the role table, and run
`tools/multi-agent-protocol/scripts/init-coordination.sh`.

### Reference

- Kinds of project and what each needs: [adapters/modes.md](adapters/modes.md).
- Agent tools (rules, pushing, waking): [adapters/README.md](adapters/README.md), with notes
  for [Codex](adapters/codex.md), [OpenCode](adapters/opencode.md),
  [Aider](adapters/aider.md), [GitHub Copilot](adapters/copilot.md),
  [Gemini CLI](adapters/gemini.md) and [Cursor](adapters/cursor.md).
- Windows, macOS, Linux and git hosts: [adapters/platforms.md](adapters/platforms.md).
- Smaller or cheaper models: [adapters/compact-rules.md](adapters/compact-rules.md).
- Upgrading a project: [UPGRADING.md](UPGRADING.md).

## Where it fits

MAP works above the common agent standards and uses them; it replaces none of them.

| Layer | What it covers | Examples |
| --- | --- | --- |
| Rules for one agent | What an agent reads at the start of a session | `AGENTS.md`, `CLAUDE.md`: MAP's rules block goes there |
| Tools and data | How an agent calls tools and reads data | MCP |
| Agent to agent | Message formats for agents that call each other directly | A2A, ACP |
| **Work between agents and their owner** | Who may approve what, who works where, how work is handed over, and how a change reaches the main branch | **MAP**, over plain git |

Agents in a MAP project may use MCP servers and talk over A2A as well; MAP only asks that
handovers, approvals and releases go through its rules and its coordination branch.

## Tests

```sh
tests/test-scripts.sh        # with sh
tests/test-scripts.sh dash   # with another POSIX shell
```

The test builds a throwaway repository with a local bare remote, two clones and concurrent
pushes, and checks every script, including the doctor catching an edited message. CI
([.github/workflows/check.yml](.github/workflows/check.yml)) runs it on Linux (dash and bash)
and macOS, plus ShellCheck and `claude plugin validate --strict`.

## License

[MIT](LICENSE) © 2026 Xuehan Gao
