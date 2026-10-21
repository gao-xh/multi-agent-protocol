type: release-request
from: <line or role>
to: release
refs: <optional>

- Branch: <branch>
- Commit: <full SHA> (merged with main at <SHA>: yes/no)
- Migrations: none | <each operation, and whether it changes existing rows>
- Configuration, secrets or scheduled-job changes: none | <list>
- Owner approvals: <what was approved, when, in which session; or "standing authorization: <ref>">
- What it changes: <short list>
- Checks run: <command or check, result> (not checks that exist)
- Known limits: <unverified parts, simulated-only checks>
