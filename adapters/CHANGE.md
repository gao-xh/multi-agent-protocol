# Change prompt: change one setting of a project that is set up

Give this to the lead (or paste it into any session, which then passes it to the lead):
"Change <setting> to <value>", for example "change the upgrade policy to patch", "add a
line for Cursor on my laptop that owns the docs", "make commits use my name". Changing
the agent rules file needs the owner's approval (PROTOCOL.md 3.2), so the owner asks in
person or approves the change the lead shows.

---

```text
Change one setting of this project under the Multi-Agent Protocol: <setting and value>.
Answer me in the language I write in.

1. If you are not the lead, send this request to the lead as a `handover` that quotes my
   words, and stop; if I am here, you may do it yourself only when the rules file allows
   your role to change the agent rules file.
2. Find the setting in the project's agent rules file (the block between
   "multi-agent-protocol: begin" and "end": the role table, owners, signing keys,
   standing authorizations, "Roles and permissions", and the lines "- Commit author:",
   "- Upgrades:", "- Approval records:", "- Message type:"), or the section
   "## Project conventions" after the block. Change only what I asked for.
3. Show me the change as a diff, and what follows from it for the sessions (for example:
   "every session sets its git identity to its line name", "line docs joins with
   adapters/JOIN.md"). Changes to roles, permissions and message types follow the
   approval path in "Roles and permissions" (PROTOCOL.md 2.2), except that a new row in
   the role table always needs my approval (PROTOCOL.md 5.5); everything else needs my
   approval here. Wait for it.
4. After I approve: record it with scripts/decide.sh in my words, commit the change on
   your own branch, and get it onto the main branch as the project releases changes.
5. When it is on the main branch, send a `heads-up` to all: what changed and what each
   session must do. For a new line, give me its start card (adapters/BOOTSTRAP.md,
   step 7).
```
