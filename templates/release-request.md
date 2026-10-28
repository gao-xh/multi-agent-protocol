type: release-request
from: <line or role>
to: release
refs: <optional>

- Branch: <branch>
- Commit: <full SHA> (merged with main at <SHA>: yes/no)
- Migrations: none | <each operation, and whether it changes existing rows>
- Configuration, secrets or scheduled-job changes: none | <list>
- Reviews: <review messages and the SHA each one reviewed, or none>
- Owner approvals: <what was approved, for which SHA, when, in which session; or "standing authorization: <ref>">
- What it changes: <short list>
- Interfaces changed: none | <each interface, and the heads-up that announced it (PROTOCOL.md 5.3)>
- Checks run: <command or check, result> (not checks that exist)
- Known limits: <unverified parts, simulated-only checks>
