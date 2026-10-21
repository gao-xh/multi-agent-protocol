# Related work

This protocol borrows ideas (not text) from these projects. It is meant to sit on top of
tools like them, not to replace them.

| Project | What it does | What this protocol takes or adds |
| --- | --- | --- |
| [OpenMOSS/claude-codex-handoff](https://github.com/OpenMOSS/claude-codex-handoff) | Serverless Claude Code and Codex collaboration in one folder: append-only message streams, lock files, timer wake-ups, cursors advanced only after side effects | Same crash-safe cursor rule (`Last-read`) and cheap timer polling; moves the board to a git branch so it works across machines, and adds roles, owner authority and a release process |
| [AnastasiyaW/mclaude](https://github.com/AnastasiyaW/mclaude) | File-based coordination for several Claude Code sessions: atomic locks, Markdown handoffs, addressed messages, an identity registry | Handovers that record failed approaches; claims with leases instead of locks; tool-agnostic, so Codex and others take part |
| [OrchestratorInc/agent-orchestrator](https://github.com/OrchestratorInc/agent-orchestrator) (formerly ComposioHQ) | Desktop workspace that plans tasks and runs many coding agents, each with its own branch, worktree and browser, tracked through PRs, CI and review | Complementary: use it to run agents, and this protocol for who approves, how releases are verified and when the main branch may move |
| [gitpcl/openorchestrator](https://github.com/gitpcl/openorchestrator) | Terminal control plane for parallel agents in worktrees, with conflict warnings and merge queuing | Same overlap idea, made a mandatory release step (warn other lines before merging) |
| [andyrewlee/awesome-agent-orchestrators](https://github.com/andyrewlee/awesome-agent-orchestrators) | Curated list of orchestrators, swarms, loop runners and agent infrastructure | Where to find an orchestrator to pair with this protocol |
| [Tessl "agent team operation" rule](https://tessl.io/registry/jbaruch/coding-policy/0.3.186/files/rules/agent-team-operation.md) | Rules for agent team rounds: rotating roles, self-contained briefs, one writer per worktree, report files, a cap on fix attempts, review before a PR | Self-contained messages, one writer per tree, a five-round fix cap, and independent review before release |

What is different here (section numbers refer to [PROTOCOL.md](../PROTOCOL.md)):

- approvals are never relayed (3.1), and standing authorizations are written down and read
  narrowly (3.3);
- a release role verifies against the exact SHA and the real exit status before the main
  branch moves (7);
- interface changes are announced before merge (5.3);
- the rules are tied to a table of failures that actually happened (11).

