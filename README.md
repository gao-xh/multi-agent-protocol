# MAP: Multi-Agent Protocol

[![check](https://github.com/gao-xh/multi-agent-protocol/actions/workflows/check.yml/badge.svg)](https://github.com/gao-xh/multi-agent-protocol/actions/workflows/check.yml)
[![stable](https://img.shields.io/github/v/release/gao-xh/multi-agent-protocol?label=stable)](https://github.com/gao-xh/multi-agent-protocol/releases/latest)
[![pre-release](https://img.shields.io/github/v/release/gao-xh/multi-agent-protocol?include_prereleases&label=pre-release&color=orange)](https://github.com/gao-xh/multi-agent-protocol/releases)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

[中文说明](README.zh-CN.md)

> **For AI agents:** if you were given this link and asked to set the protocol up in a
> project, follow [adapters/BOOTSTRAP.md](adapters/BOOTSTRAP.md) step by step (raw text:
> https://raw.githubusercontent.com/gao-xh/multi-agent-protocol/main/adapters/BOOTSTRAP.md).
> It tells you what to check, what to ask the owner, and what to change only after they answer.
> If the project is already set up and you are asked to join it, follow
> [adapters/JOIN.md](adapters/JOIN.md) instead.

A governance and release protocol for several AI coding agents (Claude Code, Codex and
others) that work on one project in parallel, on behalf of one human owner.

Orchestrators start agents, give them worktrees and show their progress. They mostly leave
open who may approve what, how agents hand work to each other, and how a change gets from a
finished branch to production without anyone cutting corners. This protocol covers that
part. It is a set of rules plus a few small tools, and it works with any orchestrator, or
with plain terminal sessions on different machines.

- **[PROTOCOL.md](PROTOCOL.md)**: the protocol (RFC 2119 wording, about 15 minutes to read).
- **[UPGRADING.md](UPGRADING.md)**: how to find your version and update a project, with several sessions.
- **[scripts/](scripts/)**: POSIX `sh` tools for the git-based coordination branch. They need only git.
- **[templates/](templates/)**: message templates (handover, release request, released, returned, review, heads-up, joined, transfer, status, review packet; `send.sh --template question` and `answer` print the short ones).
- **[adapters/](adapters/)**: the `AGENTS.md` snippet, a bootstrap prompt for any agent, and notes for Codex.
- **Claude Code plugin**: role skills (`lead`, `line`, `release`, `liaison`, `relay`, `coordinate`) and `builder` / `reviewer` agents.

> **Release candidate 2.0.0-rc.1** is on the branch `next` (tag `v2.0.0-rc.1`); `main` and
> the plugin marketplace stay on 1.3.1 until 2.0.0. To try it, take the files from the tag:
> `git clone --branch v2.0.0-rc.1 https://github.com/gao-xh/multi-agent-protocol`, then
> add that folder as the marketplace (`/plugin marketplace add ./multi-agent-protocol`), or
> run its `scripts/install.sh` on your project, and tell a setup agent to read the files
> of the tag instead of `main`. What changed: [CHANGELOG.md](CHANGELOG.md).

## Why

Running several agents at once fails in predictable ways. Two sessions edit one working
tree. One agent tells another "the owner approved it". A deployment fails, but a pipe hides
the exit status and the main branch moves anyway. A long feature lands on a stale base. The
protocol is built around five things that prevent these:

1. **Owner authority.** Only the human owner approves. An approval relayed by another
   agent never counts. Standing authorizations are allowed, but they are recorded with
   their date, scope, exclusions and the owner's own words, and read narrowly. An owner who
   is not in the agent's session can approve with a record signed by their SSH key.
2. **Isolation.** One writer per working tree, one branch per line of work, free ports and
   disposable databases for every test run.
3. **A dedicated release role** that verifies strictly: review, overlap check, local gate,
   CI on the exact SHA, approvals confirmed with the owner, one scripted deploy, success
   read from the real exit status, and only then the main branch moves.
4. **Build → independent review → fix → release.** New features are reviewed by an agent
   that did not build them, with ranked findings and evidence, for at most five rounds.
5. **Interface changes are announced before merge**, and the old form keeps working where
   feasible.

The protocol ends with a [table of real failure modes](PROTOCOL.md#11-known-failure-modes)
and the rule that prevents each one.

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

## Roles

```mermaid
flowchart TB
    owner(["<b>Owner</b><br/>human<br/>decides and approves"])

    subgraph dev["Development sessions"]
        direction TB
        lead["<b>Lead</b><br/>architecture, contracts,<br/>review, integration"]
        lines["<b>Lines</b><br/>one area each,<br/>running in parallel"]
    end

    subgraph helpers["Short-lived agents"]
        direction TB
        builder["<b>Builder</b><br/>one task, fresh worktree"]
        reviewer["<b>Reviewer</b><br/>read-only, ranked findings"]
    end

    board[("<b>coordination branch</b><br/>status, messages,<br/>claims, decisions")]
    release["<b>Release</b><br/>review, verify,<br/>deploy, record"]
    main[["<b>main branch</b>"]]

    owner == "requests, approvals" ==> dev
    dev -- "delegate, review" --> helpers
    dev <-- "handover, heads-up,<br/>release-request" --> board
    board <-- "released / returned" --> release
    owner -. "approvals, asked directly" .-> release
    release == "verified deploy" ==> main

    classDef ownerNode fill:#fef3c7,stroke:#b45309,stroke-width:2px,color:#1c1917
    classDef sessionNode fill:#e0f2fe,stroke:#0369a1,stroke-width:1.5px,color:#0c1a26
    classDef releaseNode fill:#dcfce7,stroke:#15803d,stroke-width:2px,color:#052e16
    classDef helperNode fill:#f4f4f5,stroke:#71717a,stroke-width:1.5px,stroke-dasharray:5 3,color:#18181b
    classDef boardNode fill:#ede9fe,stroke:#6d28d9,stroke-width:1.5px,color:#1e1b4b
    classDef mainNode fill:#f0fdf4,stroke:#15803d,stroke-width:2px,color:#052e16
    class owner ownerNode
    class lead,lines sessionNode
    class release releaseNode
    class builder,reviewer helperNode
    class board boardNode
    class main mainNode
    style dev fill:transparent,stroke:#0369a1,stroke-width:1px,stroke-dasharray:4 4
    style helpers fill:transparent,stroke:#71717a,stroke-width:1px,stroke-dasharray:4 4
```

Roles are responsibilities, not processes. One session may hold several roles in a small
project; in a larger one any role can run as several parallel sessions (many lines,
builders and reviewers at once; several leads split by area; several release sessions that
take turns on the main branch through a claim). A project can also add its own roles, such
as tester, documentation or security audit, as long as they keep the reserved powers
intact: only the owner approves and only the release role (or the role the project names
for that work) moves the main branch
([PROTOCOL.md 2.1](PROTOCOL.md#21-parallel-sessions-and-project-roles)). The roles, and
which tool runs each one, are listed in a table in the project's `AGENTS.md`. The roles
and permissions are defaults: a project may rename, combine or leave out roles and change
who may do what, and add their own message types, in the same file, approved the way the
project chose at setup (by default proposals go through the lead to the owner); approvals, the single
session that moves the main branch and independent review stay as they are
([PROTOCOL.md 2.2](PROTOCOL.md#22-customizing-roles-and-permissions)).

## How agents talk

Every agent that can run git can use the **coordination branch**: an orphan branch in the
project's own repository, never merged.

```
status/<line>.md                            one file per line, changed only by that line
messages/<UTC timestamp>_<from>_<type>.md   one file per message, never changed after push
claims/<task-slug>.md                       who is doing which task, with a lease
decisions/<YYYY-MM-DD>_<topic>.md           owner decisions and standing authorizations
```

A whole line can also move to another agent or machine: the giving session pushes
everything and leaves a `transfer` handover addressed to its own line name, and the
receiving session, under the same name, reads it first and checks every branch SHA.

When a session joins, its status file describes its environment (tool, model, a machine
label, sandbox and network access, what it can and cannot run, how a new message wakes it,
whether it can push the coordination branch, whether the owner is usually present, the
git identity it commits under: by default its line name) and it
announces itself to all, so the others know what to hand it. Messages are new files, so they never conflict. Each line keeps a `Last-read` pointer in its
status file and advances it only after acting on a message, so an interrupted session redoes
work instead of losing it. Agents without push notifications poll with `inbox.sh`, which
makes no model call and exits 1 when there is nothing new, or run `watch.sh`, which prints
one line per new message (one summary line when more than three arrive at once) for a
tool that turns output into a notification.

```sh
scripts/init-coordination.sh                 # once per project
scripts/inbox.sh --show api                  # unread messages for line "api"
scripts/watch.sh --once api                  # print what is new (or wait for it), then exit
scripts/send.sh --template handover > m.md   # fill it in, then:
scripts/send.sh m.md
scripts/mark-read.sh api <message-file>      # after handling it
scripts/claim.sh --hours 4 api fix-login     # exit 1: someone else has it
scripts/status.sh --all
scripts/doctor.sh                            # layout, immutable messages, stale claims
scripts/decide.sh <topic> decision.md        # record an owner decision
scripts/verify.sh decisions/<file>           # is this approval really signed by the owner?
```

Tools that have their own messaging between sessions can use it for speed, but handovers,
release requests and their answers are still written to the branch.

## Three ways to use it

Start small. The **minimal profile** (one owner, two or three sessions) needs only the
authority, isolation, handover and report rules; the coordination branch and the release
role come in with the **full profile** when you add more sessions, machines, tools or
owners ([PROTOCOL.md 12.1](PROTOCOL.md#121-profiles)).

### 1. Claude Code plugin

```text
/plugin marketplace add gao-xh/multi-agent-protocol
/plugin install multi-agent-protocol@gao-xh-agents
```

Then start each session with its role: `/multi-agent-protocol:lead`,
`/multi-agent-protocol:line api`, `/multi-agent-protocol:release`, and use
`/multi-agent-protocol:coordinate` for the inbox, messages and claims. The `builder` and
`reviewer` agents become available for delegation. The reviewer has no file-editing tools
and cannot start other agents; it does have Bash to run the change, and is read-only by
instruction.

Optional: give the worktree a line name once. Each session then starts with a summary of
its unread messages and active claims (the plugin's SessionStart hook runs
`scripts/session-start.sh`), and the plugin's monitor runs `scripts/watch.sh`, which fetches
the coordination branch every 30 seconds and is meant to wake the session, even when it is idle at
the prompt, when a new message arrives for its line (not yet checked in a real Claude Code
session). Without a line name both do nothing. The stored name binds every later
session in that worktree to the line; only one watcher per line runs in a worktree, and a
second one exits with a one-line notice.

```text
/multi-agent-protocol:coordinate set-line api      # once per worktree; or start with MAP_LINE=api
```

### 2. Bootstrap prompt, for any agent

Paste the prompt in [adapters/BOOTSTRAP.md](adapters/BOOTSTRAP.md) into Codex, Claude Code
or another agent inside your project, once. The agent finds out what it can about the
project, proposes every setting on one numbered page (you answer "ok" or change items by
number), shows the rules block before writing it, creates the coordination branch, joins
itself, and gives you a start card for each other agent. Agents that join later paste
[adapters/JOIN.md](adapters/JOIN.md): they read the project's settings, configure only
themselves and usually ask nothing; an agent with no row in the role table is registered
by you in its session, or joins as pending until the lead registers it with your
approval. Change one setting later through the lead with
[adapters/CHANGE.md](adapters/CHANGE.md). Which mainstream agents read the rules, can
push the coordination branch and can be woken, and what to set for each:
[adapters/README.md](adapters/README.md); Windows, macOS, Linux and the git hosts (GitHub,
GitLab, Bitbucket, Gitea/Forgejo, Azure DevOps): [adapters/platforms.md](adapters/platforms.md).
The setup first asks how detailed it should be (quick, standard or detailed) and which task
mode fits the project ([adapters/modes.md](adapters/modes.md): simple GitHub
collaboration, private development with public release, server deployment, app release,
an owner liaison, package release, documentation, data pipelines, several services in one
repository, open source with outside contributors, research or prototype, refactoring or
migration, security audit or review, incident response, remote lead with local agents).
Tool notes: [GitHub Copilot](adapters/copilot.md), [Gemini CLI](adapters/gemini.md),
[Cursor](adapters/cursor.md), [Codex](adapters/codex.md) (sandbox network access for `git push`, `codex exec`, polling
on a timer), [OpenCode](adapters/opencode.md) (rules, permissions, `opencode run`) and
[Aider](adapters/aider.md) (loading the rules, automatic commits, a wrapper). For smaller
or cheaper models, such as the fast tiers of DeepSeek, add the short session card from
[adapters/compact-rules.md](adapters/compact-rules.md).

### Remote work

When the owner or the lead works away from the machine that has the data or the
environment, agents there can still take work through the coordination branch: task
mode 15 in [adapters/modes.md](adapters/modes.md). `scripts/runner.sh` starts a
headless agent (Claude Code, Codex, OpenCode) whenever new messages arrive for its line;
a `relay` runs the commands other sessions ask for on that machine; and the owner can
drive a relay directly from another computer with `scripts/remote.sh`, signed with an SSH
key or, where the project allows it, unsigned (`- Owner commands:`). When a relay lacks
a permission, `remote.sh` shows the rule it asks for and allows it for one run only on
the owner's `y`. Setup guide: [adapters/remote.md](adapters/remote.md).

### 3. Install into the project by hand

```sh
git clone https://github.com/gao-xh/multi-agent-protocol
multi-agent-protocol/scripts/install.sh path/to/your-project   # rerun later to update
```

This copies the protocol, scripts, templates and the rules snippet into
`tools/multi-agent-protocol/` and changes nothing else. Then paste the snippet into your
project's `AGENTS.md` (Codex reads it; point `CLAUDE.md` to it for Claude Code), fill in
the table, and run `tools/multi-agent-protocol/scripts/init-coordination.sh`.

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
