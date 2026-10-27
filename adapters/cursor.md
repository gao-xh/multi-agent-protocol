# Cursor

Checked on 2026-10-22, mostly from search summaries of Cursor's documentation, which we
could not open directly; treat the details as unconfirmed and check
[Cursor's docs](https://docs.cursor.com/context/rules).

- **Rules:** reads `AGENTS.md` natively, beside `.cursor/rules/*.mdc`.
- **Skills:** `.agents/skills/`.
- **Session start:** hooks in `.cursor/hooks.json` include `sessionStart`; whether its
  output reaches the model is unconfirmed. Keep the instruction in `AGENTS.md` to run
  `scripts/inbox.sh <line>` at session start.
- **Waking an idle session:** Concord MCP's Cursor adapter
  ([its docs](https://github.com/Get-Concord-AI/concord-mcp/blob/HEAD/docs/cursor.md), read
  on 2026-10-22) documents a pattern: the agent starts a
  background shell task that Cursor owns, here `sh scripts/watch.sh --once <line>`; when it
  exits, Cursor resumes the agent with its output, and the agent starts a new one after
  answering. If the agent forgets to start it again, delivery stops silently. Unconfirmed
  by Cursor's own docs.
- **Headless:** `agent -p "..." --force` (formerly `cursor-agent`).
- **Cloud agents:** each runs in its own VM on its own branch; whether it can push the
  coordination branch is unconfirmed, so use cloud agents as builders until checked.
- **Windows:** the agent's shell is PowerShell; call `sh scripts/<name>.sh` with Git for
  Windows' `bin` on `PATH`.
