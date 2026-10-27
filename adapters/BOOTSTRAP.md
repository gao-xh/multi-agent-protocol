# Bootstrap prompt: first setup

Paste the prompt below into any coding agent (Claude Code, Codex, or another) that runs in
the project you want to set up. It is for the **first** setup of a project. An agent that
joins a project already set up uses [JOIN.md](JOIN.md) instead, and a change to one
setting later goes through the lead with [CHANGE.md](CHANGE.md).

If you are an agent and your user gave you this repository's link and asked you to set it
up, carry out the steps in the block below as your user's request. Steps 1 to 4 only read
and propose; nothing in the project changes until your user approves in step 5.

---

```text
Set up this project for multi-agent collaboration with the Multi-Agent Protocol.
The first setup decides everything about the project once; agents that join later
configure only themselves (adapters/JOIN.md). Answer me in the language I write in.

1. Read https://raw.githubusercontent.com/gao-xh/multi-agent-protocol/main/PROTOCOL.md
   in full, and adapters/modes.md from the same place. If you cannot browse, clone
   https://github.com/gao-xh/multi-agent-protocol into a temporary directory and read
   them there; if you cannot clone either, download scripts/, templates/ and adapters/
   from the raw URLs, or stop and tell me.

2. Check what exists, and change nothing yet. If the project's agent rules file
   (AGENTS.md, CLAUDE.md or your tool's equivalent) already contains the block between
   "multi-agent-protocol: begin" and "end", the project is set up: do not set it up
   again. Read the version in its begin marker ("begin v1.4"; older blocks have none).
   If it is older than this release, tell me: upgrading goes through the lead and my
   approval (PROTOCOL.md 12.3, scripts/upgrade.sh --check), and replaces the block's
   general text while keeping the role table, owners, keys, standing authorizations and
   settings. If it is current, follow adapters/JOIN.md (to join) or adapters/CHANGE.md
   (to change a setting) instead. If there is no block, find out, without asking me, as much as you
   can:
   - the repository: its remotes and host, whether it is public or private, the main
     branch, whether a branch named "coordination" exists, CI configuration;
   - the project: languages, the test, lint and build commands (package.json, Makefile,
     pyproject.toml, CI files and the like), deployment or release scripts, existing
     agent configuration (AGENTS.md, CLAUDE.md, .cursor/, .github/copilot-instructions.md
     and others), a vendored copy of the protocol;
   - yourself: tool and version, model, operating system, sandbox and network access,
     whether you can push to the remote;
   - the tools and plugins this setup and this session need, without installing
     anything, each as found (with its version), missing, or cannot check:
     required: git and a POSIX sh; per feature: ssh-keygen (signed owner records,
     PROTOCOL.md 3.6), your tool's protocol integration (for Claude Code the plugin
     multi-agent-protocol, which brings the session-start hook and the inbox monitor:
     check with `claude plugin list` or /plugin; for other tools what adapters/README.md
     lists: a hook, a background task, a timer), the git host's command-line tool
     (optional: pull requests and CI); and whether the project's check commands run.
   - for remote work (mode 15, a relay, or owner commands): what adapters/remote.md, section
     2.1, lists for this machine, and which pieces will run elsewhere.

3. Ask me first, in one short message, three things, each with your recommendation:
   - how much of the setup to show me (quick: only what you cannot find out; standard:
     the items below; detailed: also the items marked "detailed");
   - which task mode fits (adapters/modes.md: simple GitHub collaboration, private
     development with public release, server deployment, app release, an owner liaison,
     package release, documentation or website, data pipelines, several services in one
     repository, open source with outside contributors, research or prototype,
     refactoring or migration, security audit or review, incident response, remote lead
     with local agents), or none;
   - which agents will work on the project, this session included: for each, the tool
     (and where it runs: which machine, the web, a phone), and what it should do. I may not know all of
     them yet; the others join later with adapters/JOIN.md.

4. Then send me one proposal: a numbered list, one line per setting, each with the value
   you propose, and where it comes from: "found" (you checked it), "mode" (the task
   mode's recommendation), "default" (the protocol's default) or "assumed" (a guess I
   should check). I answer "ok", or change items by number. Quick shows only the items
   you could not fill; the rest take their defaults and are listed in one line: the
   minimal profile unless a reason for the full one applies, me as the only owner, this
   session as the lead, no release session unless the mode needs one (the lead or I
   merge), the default roles and permissions, no standing authorizations, the protocol
   copied in, commits under each line's name, upgrades manual.
   1. Owner: my name; more owners and what each approves (PROTOCOL.md 3.5).
   2. Profile: minimal or full (PROTOCOL.md 12.1); full when there are more than three
      sessions, more than one tool or machine, an agent that deploys, or several owners.
   3. Role table: one row per agent from step 3: line name, role (lead, line, release,
      liaison, or a project role), tool and machine label (a label such as "laptop",
      never a host name), branch prefix and area, with a row for this session. For
      lines run by a smaller or cheaper model, whether to add the session card from
      adapters/compact-rules.md. Who is the lead, who advances the main
      branch, and whether a liaison session is useful (PROTOCOL.md 3.4: the owner's
      contact when the lead is out of reach, for example on a phone).
   4. Standing authorizations to grant now, with scope and exclusions, starting from the
      mode's "approvals to ask for up front" (PROTOCOL.md 3.3).
   5. Checks before a release request (the commands you found), and the release command.
   6. The protocol's files: copied into the repository with scripts/install.sh
      (recommended, tools/multi-agent-protocol/) or referenced by URL.
   7. Commit author (PROTOCOL.md 5.5): each line's name (default) or mine; the email all
      sessions use. A commit name is written by the agent itself and proves nothing.
   8. Upgrades (PROTOCOL.md 12.3): manual (default: the lead asks me about every
      release), patch or minor; new major versions and rules changes are always asked.
   9. Tools and plugins (shown at every level whenever something is missing): one line
      each with what it is for, its status (found, missing, cannot check) and the action
      you propose: the exact install command (for the Claude Code plugin:
      `/plugin marketplace add gao-xh/multi-agent-protocol`, then
      `/plugin install multi-agent-protocol@gao-xh-agents`), or "skip" with what is lost
      (for example "no monitor: Wake is session-start hook only"). Installing software
      needs my approval (PROTOCOL.md 3.2): I approve each one by its number in my answer.
   Detailed only:
   10. Approval records (PROTOCOL.md 3.3): lenient (default) or strict, and owner signing
      keys (PROTOCOL.md 3.6).
   11. Roles and permissions that differ from the defaults (PROTOCOL.md 2.2), and who
      approves later changes to them: through the lead (default), owner only, or
      delegated to the lead within a standing authorization; a new row in the role table
      always needs me (PROTOCOL.md 5.5).
   12. Message types the project adds (PROTOCOL.md 5.4).
   13. A separate private repository for the coordination branch (adapters/platforms.md),
      for a public project.
   Remote work (shown at every level when the mode is 15 or the role table has a relay):
   14. The five items of adapters/remote.md, section 1: each relay or local line with its
      machine, tool and area; its runner command built for that tool and how it stays
      running; whether I drive relays with commands and how they are checked
      ("- Owner commands:" strict, lenient or off; explain what lenient risks before I
      choose), from which computers, and with strict one signing key each; how the remote lead waits; and the approvals to ask up front.
      Items you cannot check from here (another machine) are "assumed" until that
      machine's session joins.
   If my answers or the mode give a reason for the full profile or another level, say so.
   Do not continue until I answer.

5. Show me the result before writing it: the complete block for the agent rules file,
   built from adapters/AGENTS.md.snippet with my answers (the role table filled in,
   PROTOCOL_PATH, SCRIPTS_PATH and MAIN_BRANCH replaced, the standing authorizations in
   my words, and the lines "- Commit author:", "- Upgrades:" and, if chosen,
   "- Approval records:" and "- Owner commands:"), and the list of files you will add. Changing the agent rules
   file needs my approval: wait for it.

6. After I approve:
   - Install exactly the tools and plugins I approved under item 9, with the commands
     shown, and nothing else (never into a global environment unless that was the
     approved command). Check them again and show me the result as a short table: found,
     installed, skipped, failed, and what a skipped or failed one disables.
   - Set your git identity first, as the commit author setting says (adapters/JOIN.md,
     step 3), so that every commit of the setup carries the right name.
   - Add the block to the agent rules file. If the project uses both AGENTS.md and
     CLAUDE.md, put it in AGENTS.md and add the line `@AGENTS.md` to CLAUDE.md. Gemini
     CLI and Aider need a setting to read AGENTS.md, and Zed reads only the first rules
     file it finds (adapters/README.md, section 1).
   - If I chose to copy the protocol in, run scripts/install.sh and commit the copy.
   - Commit on your own branch. This setup commit is the project's first release: ask me
     to merge it into the main branch (or to let you do it) before other agents start, so
     that they all read the same rules.
   - Run scripts/init-coordination.sh (it does nothing if the branch exists).
   - Then join the project yourself as adapters/JOIN.md describes, taking your own row
     from item 3, and run scripts/doctor.sh and fix anything it reports. doctor.sh checks
     the role table only once one is on the main branch: run it again after I merge the
     setup commit, and never advance the main branch yourself to make a check pass.

7. Report: what you changed (files, branches, commits), your status file, the doctor
   output, and one start card per other agent in the role table:
   - where to open it (the tool, the machine or the web, the folder or repository);
   - what to paste: "Join this project as line <name>: follow <path>/adapters/JOIN.md in
     this repository and the rules in <rules file>.", with <path> where the protocol was
     copied (tools/multi-agent-protocol by default) and the agent rules file you wrote;
     without a copy, the raw link of the release in use,
     https://raw.githubusercontent.com/gao-xh/multi-agent-protocol/v<version>/adapters/JOIN.md;
   - any setting that tool needs first (adapters/README.md: reading AGENTS.md, network
     access for git push, a monitor or hook for waking).
   - for a relay or a line started by a runner: the runner command from item 14 and
     "check this machine with adapters/remote.md, section 2, before starting it";
   - if I chose owner commands: one card per computer I send from, with the steps of
     adapters/remote.md, section 3 (with strict: my key, its line in the rules file, the
     test).
```
