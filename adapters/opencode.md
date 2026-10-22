# Using the protocol with OpenCode

OpenCode is an open-source coding agent for the terminal that works with many model
providers, DeepSeek among them. It takes part like any other agent: through the project's
`AGENTS.md` and the `coordination` branch.

The OpenCode facts below were checked against its documentation (opencode.ai/docs) on
2026-10-21. OpenCode changes quickly; check the linked pages if something does not behave
as described. For smaller or cheaper models, also use [compact-rules.md](compact-rules.md).

## 1. Rules: `AGENTS.md`

OpenCode reads `AGENTS.md` from the working directory upwards, and a global
`~/.config/opencode/AGENTS.md`. `CLAUDE.md` (and `~/.claude/CLAUDE.md`) are fallbacks,
read only when there is no `AGENTS.md` in that place. Further files can be added with the
`instructions` key in `opencode.json` (paths, globs or URLs); they are combined with
`AGENTS.md`. See [rules](https://opencode.ai/docs/rules/).

So: put the protocol snippet (`AGENTS.md.snippet`) in the project's root `AGENTS.md`, as
for every other tool. If a project keeps its rules in `CLAUDE.md` and also has an
`AGENTS.md`, OpenCode does not read the `CLAUDE.md`: move the rules into `AGENTS.md` and
have `CLAUDE.md` point to it. To have every session load the protocol itself, add it to
`instructions`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["tools/multi-agent-protocol/PROTOCOL.md"]
}
```

## 2. Permissions

OpenCode asks before actions according to the `permission` block in `opencode.json`. Each
rule is `allow`, `ask` or `deny`; for shell commands, the last matching pattern wins, so
the catch-all comes first. See [permissions](https://opencode.ai/docs/permissions/). A
setup that lets a line run the coordination scripts and plain git without prompts, and
asks for everything else:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "shell": {
      "*": "ask",
      "git *": "allow",
      "tools/multi-agent-protocol/scripts/*": "allow",
      "git push --force*": "deny",
      "git push -f*": "deny"
    }
  }
}
```

Committing this file to the project changes what every OpenCode session may do without
asking, so the owner decides (PROTOCOL.md 3.2). `opencode run --auto` approves every
permission that is not explicitly denied; use it only with deny rules for the actions in
PROTOCOL.md 3.2, and never for the release role.

## 3. Choosing a model

Connect a provider with `/connect` (for DeepSeek, search for it and enter the API key),
then choose a model with `/models`. See [providers](https://opencode.ai/docs/providers/).
The key is stored by OpenCode, not in the project; never put it in `opencode.json`, the
repository or a message (PROTOCOL.md 5.5).

## 4. Starting a session with a role

Interactive: start OpenCode in the line's own worktree and say
"You are line `<name>` in this project; follow the Multi-Agent Protocol in AGENTS.md."

Non-interactive: `opencode run "<prompt>"` runs one prompt without the terminal interface.
`--dir <worktree>` sets the directory, `--model <provider>/<model>` (`-m`) the model,
`--continue` (`-c`) continues the last session and `--session <id>` (`-s`) a given one.
See [CLI](https://opencode.ai/docs/cli/). `opencode models` lists the exact
`provider/model` names of the connected providers; copy the DeepSeek one from there.

## 5. Checking the inbox on a timer

As in [codex.md](codex.md), section 4: check with `inbox.sh` first (no model call; exit 0
means unread messages) and start OpenCode only when there is something new.

```sh
#!/bin/sh
# check-inbox.sh: run from cron or launchd, for example every 15 minutes.
set -u
line=api
worktree="$HOME/code/project-api"
scripts="$worktree/tools/multi-agent-protocol/scripts"

cd "$worktree" || exit 2
"$scripts/inbox.sh" "$line" >/dev/null
case $? in
    0) ;;
    1) exit 0 ;;
    *) echo "inbox check failed" >&2; exit 2 ;;
esac

opencode run --dir "$worktree" \
  "You are line $line. Follow the Multi-Agent Protocol in AGENTS.md. Run
   $scripts/inbox.sh --show $line, handle each message in order, run
   $scripts/mark-read.sh $line <message> after handling each one, and report."
```

A non-interactive run cannot answer permission prompts, so the commands it needs must be
allowed in section 2. Adding a scheduled job needs the owner's approval (PROTOCOL.md 3.2).

## 6. Skills and agents

OpenCode loads skills (`<name>/SKILL.md` with `name` and `description`) from
`.opencode/skills/`, `.claude/skills/` and `.agents/skills/` in the project, and from the
matching folders in the user's home directory. Skill names must be lowercase words joined
by single hyphens and match their folder. See [skills](https://opencode.ai/docs/skills/).
The role skills in this repository (`skills/coordinate`, `lead`, `line`, `release`) meet
these rules and can be copied into `.agents/skills/`. Replace `${CLAUDE_PLUGIN_ROOT}`
paths with the vendored path when copying. **Unverified:** whether OpenCode ignores the
Claude Code-only frontmatter field `argument-hint` cleanly.

The `builder` and `reviewer` agents in `agents/` are written for Claude Code. In OpenCode,
start them as separate sessions with their instructions as the prompt; for a read-only
review, deny `edit` in that session's permissions.

## 7. Describing an OpenCode session's environment

When an OpenCode session joins (PROTOCOL.md 5.5), its status file could read:

```
- Agent: OpenCode <output of opencode --version>
- Model: <provider/model shown by OpenCode for this session>
- Machine: laptop; macOS 26.6
- Sandbox: no OS sandbox; shell commands ask unless allowed in opencode.json; network: yes
- Can run: unit tests, coordination scripts
- Cannot: deploy; approve its own prompts in non-interactive runs
- Reachable by: coordination branch only; checks the inbox every 15 minutes (cron)
```
