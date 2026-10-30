# Join prompt: an agent joins a project that is set up

Paste the prompt below into the agent that should join, or give it this file's raw link
in the release the project uses, with its full tag (the `VERSION` file of the project's
copy, for example `tools/multi-agent-protocol/VERSION`, names it, such as 2.1.0-rc.1):
`https://raw.githubusercontent.com/gao-xh/multi-agent-protocol/v<X.Y.Z or X.Y.Z-rc.N>/adapters/JOIN.md`.
In a project whose rules block points to adapters/JOIN.md (2.0 and later), "Join this
project as line <name>." is enough. The
project was set up with [BOOTSTRAP.md](BOOTSTRAP.md); everything about the project is in
its agent rules file, so the joining agent configures only itself and usually asks
nothing. Add the line name when you know it: "Join as line scripts."

---

```text
Join this project as an agent under the Multi-Agent Protocol. The project is already set
up: read its settings, configure only yourself, and ask me only what you cannot find out.
Answer me in the language I write in.

1. Read the project's agent rules file (AGENTS.md, CLAUDE.md or your tool's equivalent):
   the block between "multi-agent-protocol: begin" and "end", its role table, owners,
   standing authorizations and the lines "- Commit author:", "- Upgrades:" and
   "- Approval records:", and the section "## Project conventions" after the block if there
   is one: every agent follows it. Then read PROTOCOL.md where the block says (a copy in the
   repository, or the URL), at least sections 1 to 5 and the section of your role, and,
   with the scripts the block names, the recent owner decisions and the active claims
   (scripts/status.sh --decisions, scripts/status.sh --claims). If there is no such
   block, the project is not set up: stop and tell me to use adapters/BOOTSTRAP.md.

2. Decide which line you are, changing nothing yet:
   - if I named your line, take that row only if it exists in the role table and has no
     session yet (no status file under status/ on the coordination branch), or is being
     transferred to you (below); otherwise ask me, or follow the no-row cases below. Two
     sessions never share a line;
   - otherwise match your tool and machine against the rows that have no session yet; if
     exactly one matches, take it, except that without me in this session you take a
     matched row only when its role is line (a lead, release or project role row needs
     me to name it); if several match, ask me which when I am in this session, otherwise
     join as pending (below);
   - a line whose status says "transferring" is taken over only by the session that I
     name, or that its transfer handover names by tool and machine; then read that
     handover first (PROTOCOL.md 5.7);
   - if no row fits and I am in this session (the owner the rules file names), ask me
     for the line name, role and area, and say that this adds a row to the role table,
     which needs my approval; check that the area does not overlap another row's, and
     tell me if it does;
   - if no row fits and I am not here, you join as pending: choose a line name from your
     tool and machine label (for example "codex-laptop") that is neither a row of the
     table nor a status file under status/.

3. Set your git identity in this checkout before any commit, as "- Commit author:" says:
   "line" (or no such line): your line name, with `git config user.name <line>` in your
   own clone, or, in a repository with several worktrees,
   `git config extensions.worktreeConfig true` once and then
   `git config --worktree user.name <line>`; "owner": the owner's name. Use the email the
   rules file names, if any.

4. Register, if you have no row yet:
   - with my answer from step 2: record it with scripts/decide.sh in my words, add the
     row on your own branch and request that it be merged into the main branch as the
     project releases changes. You may start in that area once the record exists (with
     "- Approval records: strict", other sessions rely on it only once it is signed or on
     the main branch); the lead confirms it with me at its next contact;
   - pending (PROTOCOL.md 5.5): set "Role: pending", change no code, push no branch other
     than the coordination branch, claim nothing, and ask the lead to register you in
     step 7. The lead asks me; you start when your row is on the main branch. If the
     lead registers you under another name, join again under that name.

5. Check your environment yourself; write "unknown" for anything you cannot check, and no
   host names, IP addresses, user names or secrets:
   - tool and version (run its version command), model, operating system, the machine
     label from your row;
   - sandbox and network access; what you can and cannot run (try the project's checks
     from the rules file if they are cheap);
   - optional, where you can tell: your toolchain (git, sh, the project's runtimes), your
     permission or approval mode, whether you work in your own clone or a worktree, the
     session id others can send direct messages to, and your limits (context window,
     usage limits);
   - how a new message wakes you: start from your tool's row in adapters/README.md and
     confirm it. If your tool can be woken, arm it whenever you wait for an answer
     (PROTOCOL.md 5.5); "none" is only for tools that cannot be woken;
   - whether I am usually present in this session;
   - the tools and plugins you need, without installing anything, each as found (with
     its version), missing, or cannot check: git and a POSIX sh; ssh-keygen if the
     project uses owner signing keys; your tool's protocol integration (for Claude Code
     the plugin multi-agent-protocol, for the session-start hook and the inbox monitor;
     for other tools what adapters/README.md lists); and whether the project's checks
     run. For anything missing, propose the exact install command, or "skip" with what
     is lost. Installing software needs my approval (PROTOCOL.md 3.2): if I am in this
     session, ask me, item by item, install exactly what I approve, and check again; if
     I am not, send the list to the lead as a `question` (PROTOCOL.md 3.4) and join
     without the missing parts. Write what you can actually do afterwards into your
     status file (Can run, Wake).
   - whether your tool reads the project's agent rules file by itself (adapters/README.md,
     section 1). If it needs a setting (for Claude Code a `CLAUDE.md` with the line
     `@AGENTS.md`, for Gemini CLI `.gemini/settings.json`, for Aider
     `.aider.conf.yml`), propose it: the file belongs to the project, so it goes on your branch and reaches the main
     branch with my approval, and the next agent with the same tool finds it there;
   - if you will run unattended (started by a runner or a timer): the permission settings
     your tool needs to do your area's work without prompts and nothing more
     (adapters/remote.md, section 2.2); propose them and set them only with my approval;
   - this machine's own rules (your user-level rules file, allowed folders, settings you
     must not change): they come first. Where a step here would break them, for example
     a folder outside the allowed ones or a user-wide settings file, ask me and follow the
     machine's rules; do not make an exception on your own;
   - if you are a relay, a line started by scripts/runner.sh, or a session on a computer
     I send owner commands from: check this machine as adapters/remote.md says (section
     2 or 3), propose the runner command built for your tool, its permission settings
     and how it keeps running (or the signing key steps), and set up only what I
     approve; try one run before leaving it unattended.

6. Fill in templates/status.md for your line (the scripts are where the rules file says,
   often tools/multi-agent-protocol/scripts): Role, Branch, Area from your row; the
   Environment section from step 5, "Pushes coordination branch" and "Git identity".
   Publish it with scripts/status.sh <line> <file>. If the push fails, you cannot push
   the coordination branch: write "Pushes coordination branch: no", tell me, and work as
   a builder whose line reports for you.

7. Announce yourself: scripts/send.sh --template joined, fill it in and send it to all
   (pending: to the lead, saying what you can do and asking to be registered). Then run
   scripts/set-line.sh <line> in every checkout this line works in: the one you joined
   from, each further clone or worktree, including worktrees that a desktop app creates,
   and again in a new checkout after a transfer. It marks the checkout as this line's,
   so later sessions start with an inbox summary and tools can find the checkout
   (PROTOCOL.md 5.5). Then run scripts/doctor.sh.

8. Report to me in a few lines: your line, role and area; what you can and cannot do; the
   unread messages in your inbox (scripts/inbox.sh <line>); and what you will do next.
   Then follow your role's routine (PROTOCOL.md, or the role skill of the Claude Code
   plugin).
```
