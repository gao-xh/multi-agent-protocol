type: released
from: release
to: <requester>
refs: <release-request message>

- Production: <full SHA>
- Main branch: <full SHA>
- Went live: <short list>
- Migrations: none | <applied after rehearsal: yes/no>
- Checks: gate <result>, end-to-end <result>, CI <run link or id, result>, post-release smoke check <result>
- Backup: <location>
- Rollback: <exact command>
- Follow-ups for the requester: <e.g. publish change summary, merge main before next branch>
