# Bootstrap prompt

Paste the prompt below into any coding agent (Claude Code, Codex, or another) that runs
in the project you want to set up. It works for the first agent and for each agent that
joins later.

---

```text
Set up this project for multi-agent collaboration with the Multi-Agent Protocol.

1. Read https://github.com/gao-xh/multi-agent-protocol/blob/main/PROTOCOL.md in full.
   If you cannot browse, clone https://github.com/gao-xh/multi-agent-protocol into a
   temporary directory and read PROTOCOL.md there.

2. Check what already exists, and change nothing yet:
   - Does the project's agent rules file (AGENTS.md, CLAUDE.md, or your tool's equivalent)
     already contain the block between "multi-agent-protocol: begin" and "end"?
   - Does the remote already have a branch named "coordination"?
   - Is there a vendored copy of the protocol's scripts/ and templates/?

3. Ask me, in one batched message, with a recommendation for each:
   - the lines and roles (who is lead, which lines exist, who releases, which tool and
     branch prefix each uses, and which area each owns);
   - any standing authorizations I want to grant, with scope and exclusions;
   - whether to vendor the protocol into the repository (recommended: copy PROTOCOL.md,
     scripts/ and templates/ into tools/multi-agent-protocol/) or to reference the URL;
   - the checks to run before a release request, and the release command, if any;
   - which line you are.
   Do not continue until I answer. Changing the agent rules file needs my approval.

4. After I answer:
   - Add adapters/AGENTS.md.snippet from the protocol repository to the agent rules file
     (only once; update the block if it is already there), with the table filled in and
     PROTOCOL_PATH, SCRIPTS_PATH and MAIN_BRANCH replaced. If the project uses both
     AGENTS.md and CLAUDE.md, put the block in AGENTS.md and make CLAUDE.md point to it.
   - If I chose vendoring, copy the files and commit them on your own branch.
   - Run scripts/init-coordination.sh (it does nothing if the branch exists).
   - Fill in templates/status.md for your line and publish it with
     scripts/status.sh <line> <file>.
   - Record the standing authorizations I gave, word for word, in the snippet's table.
   - Run scripts/doctor.sh and fix anything it reports.

5. Report: what you changed (files, branches, commits), the doctor output, and the
   one-line role prompt I should give each other session, for example:
   "You are line <name> in this project; follow the Multi-Agent Protocol in AGENTS.md."
```
