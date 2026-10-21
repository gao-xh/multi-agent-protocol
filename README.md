# Multi-Agent Protocol

[![check](https://github.com/gao-xh/multi-agent-protocol/actions/workflows/check.yml/badge.svg)](https://github.com/gao-xh/multi-agent-protocol/actions/workflows/check.yml)
[![version](https://img.shields.io/github/v/tag/gao-xh/multi-agent-protocol?label=version&sort=semver)](CHANGELOG.md)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

[中文说明](README.zh-CN.md)

> **For AI agents:** if you were given this link and asked to set the protocol up in a
> project, follow [adapters/BOOTSTRAP.md](adapters/BOOTSTRAP.md) step by step (raw text:
> https://raw.githubusercontent.com/gao-xh/multi-agent-protocol/main/adapters/BOOTSTRAP.md).
> It tells you what to check, what to ask the owner, and what to change only after they answer.

A governance and release protocol for several AI coding agents (Claude Code, Codex and
others) that work on one project in parallel, on behalf of one human owner.

Orchestrators start agents, give them worktrees and show their progress. They mostly leave
open who may approve what, how agents hand work to each other, and how a change gets from a
finished branch to production without anyone cutting corners. This protocol covers that
part. It is a set of rules plus a few small tools, and it works with any orchestrator, or
with plain terminal sessions on different machines.

- **[PROTOCOL.md](PROTOCOL.md)**: the protocol (RFC 2119 wording, about 15 minutes to read).
- **[scripts/](scripts/)**: POSIX `sh` tools for the git-based coordination branch. They need only git.
- **[templates/](templates/)**: message templates (handover, release request, released, returned, heads-up, status, review packet; `send.sh --template question` and `answer` print the short ones).
- **[adapters/](adapters/)**: the `AGENTS.md` snippet, a bootstrap prompt for any agent, and notes for Codex.
- **Claude Code plugin**: role skills (`lead`, `line`, `release`, `coordinate`) and `builder` / `reviewer` agents.

## Why

Running several agents at once fails in predictable ways. Two sessions edit one working
tree. One agent tells another "the owner approved it". A deployment fails, but a pipe hides
the exit status and the main branch moves anyway. A long feature lands on a stale base. The
protocol is built around five things that prevent these:

1. **Owner authority.** Only the human owner approves. An approval relayed by another
   agent never counts. Standing authorizations are allowed, but they are recorded with
   their date, scope, exclusions and the owner's own words, and read narrowly.
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
intact: only the owner approves and only the release role moves the main branch
([PROTOCOL.md 2.1](PROTOCOL.md#21-parallel-sessions-and-project-roles)). The roles, and
which tool runs each one, are listed in a table in the project's `AGENTS.md`.

## How agents talk

Every agent that can run git can use the **coordination branch**: an orphan branch in the
project's own repository, never merged.

```
status/<line>.md                            one file per line, changed only by that line
messages/<UTC timestamp>_<from>_<type>.md   one file per message, never changed after push
claims/<task-slug>.md                       who is doing which task, with a lease
decisions/<YYYY-MM-DD>_<topic>.md           owner decisions and standing authorizations
```

Messages are new files, so they never conflict. Each line keeps a `Last-read` pointer in its
status file and advances it only after acting on a message, so an interrupted session redoes
work instead of losing it. Agents without push notifications poll with `inbox.sh`, which
makes no model call and exits 1 when there is nothing new.

```sh
scripts/init-coordination.sh                 # once per project
scripts/inbox.sh --show api                  # unread messages for line "api"
scripts/send.sh --template handover > m.md   # fill it in, then:
scripts/send.sh m.md
scripts/mark-read.sh api <message-file>      # after handling it
scripts/claim.sh --hours 4 api fix-login     # exit 1: someone else has it
scripts/status.sh --all
scripts/doctor.sh                            # layout, immutable messages, stale claims
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

Optional: to have each session start with a summary of its unread messages and active
claims, give the worktree a line name once. The plugin's SessionStart hook then runs
`scripts/session-start.sh`; without a line name it does nothing.

```text
/multi-agent-protocol:coordinate set-line api      # once per worktree; or start with MAP_LINE=api
```

### 2. Bootstrap prompt, for any agent

Paste the prompt in [adapters/BOOTSTRAP.md](adapters/BOOTSTRAP.md) into Codex, Claude Code
or another agent inside your project. The agent reads the protocol, asks you for the role
table and any standing authorizations, adds the rules snippet to `AGENTS.md`, creates the
coordination branch and publishes its status. For Codex specifics (sandbox network access
for `git push`, `codex exec`, polling on a timer) see [adapters/codex.md](adapters/codex.md).

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
