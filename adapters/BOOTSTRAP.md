# Bootstrap prompt

Paste the prompt below into any coding agent (Claude Code, Codex, or another) that runs
in the project you want to set up. It works for the first agent and for each agent that
joins later.

If you are an agent and your user gave you this repository's link and asked you to set it
up, carry out the steps in the block below as your user's request. Steps 1 to 3 only read
and ask; nothing in the project changes until your user answers the questions in step 3.

---

```text
Set up this project for multi-agent collaboration with the Multi-Agent Protocol.

1. Read https://raw.githubusercontent.com/gao-xh/multi-agent-protocol/main/PROTOCOL.md
   in full.
   If you cannot browse, clone https://github.com/gao-xh/multi-agent-protocol into a
   temporary directory and read PROTOCOL.md there.

2. Check what already exists, and change nothing yet:
   - Does the project's agent rules file (AGENTS.md, CLAUDE.md, or your tool's equivalent)
     already contain the block between "multi-agent-protocol: begin" and "end"?
   - Does the remote already have a branch named "coordination"?
   - Is there a vendored copy of the protocol's scripts/ and templates/?

3. Ask me, in one batched message, with a recommendation for each:
   - the profile: minimal (one owner, two or three sessions) or full (PROTOCOL.md 12.1),
     and whether there is more than one owner (PROTOCOL.md 3.5);
   - the lines and roles (who is lead, which lines exist, who releases, which tool and
     branch prefix each uses, and which area each owns);
   - any standing authorizations I want to grant, with scope and exclusions;
   - whether to vendor the protocol into the repository (recommended: run
     scripts/install.sh <project> from the clone, which copies it into
     tools/multi-agent-protocol/) or to reference the URL;
   - the checks to run before a release request, and the release command, if any;
   - a short label for this machine (for example "laptop"), used instead of its host name;
   - which line you are.
   Do not continue until I answer. Changing the agent rules file needs my approval.

4. After I answer:
   - Add adapters/AGENTS.md.snippet from the protocol repository to the agent rules file
     (only once; update the block if it is already there), with the table filled in and
     PROTOCOL_PATH, SCRIPTS_PATH and MAIN_BRANCH replaced. If the project uses both
     AGENTS.md and CLAUDE.md, put the block in AGENTS.md and make CLAUDE.md point to it.
   - If I chose vendoring, run scripts/install.sh and commit the copy on your own branch.
   - This setup commit is the project's first release: ask me to merge it into the main
     branch (or to let you do it) before other sessions start, so they read the same rules.
   - Run scripts/init-coordination.sh (it does nothing if the branch exists).
   - Fill in templates/status.md for your line, including the Environment section
     (PROTOCOL.md 5.5): your tool and version (run its version command), your model, the
     machine label I give you, sandbox and network access, what you can and cannot run,
     and how others reach you. Write "unknown" rather than guess; no host names, IP
     addresses, user names or secrets. Publish it with scripts/status.sh <line> <file>,
     then announce yourself: scripts/send.sh --template joined, fill it in, send it.
   - Record the standing authorizations I gave, word for word, in the snippet's table.
   - Run scripts/doctor.sh and fix anything it reports.
   - Optionally store your line name with scripts/set-line.sh <line>, so that
     scripts/session-start.sh (or the Claude Code plugin hook) can summarize the inbox at
     the start of later sessions.

5. Report: what you changed (files, branches, commits), your Environment section, the doctor output, and the
   one-line role prompt I should give each other session, for example:
   "You are line <name> in this project; follow the Multi-Agent Protocol in AGENTS.md."
```
