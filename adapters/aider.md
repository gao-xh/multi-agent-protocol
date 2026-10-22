# Using the protocol with Aider

Aider is an open-source pair-programming tool for the terminal that works with many model
providers, DeepSeek among them. It edits files and commits them, but it is built around a
person at the keyboard rather than an agent that runs commands on its own. That shapes how
it fits the protocol: Aider does the code, and the coordination steps are run by the
person or by a small wrapper script.

The Aider facts below were checked against its documentation (aider.chat/docs) on
2026-10-21. Check the linked pages if something does not behave as described. For smaller
or cheaper models, also use [compact-rules.md](compact-rules.md).

## 1. Which roles fit

- **Good fit:** a `builder`, or a `line` with a narrow area, where the owner or a wrapper
  reads the inbox, gives Aider the task, and sends the report.
- **Poor fit:** `lead`, `release` and `reviewer`. They need to run the coordination
  scripts, checks and deployment commands themselves and to judge the results; use an
  agent that runs commands (OpenCode, Codex, Claude Code) for them.

## 2. Rules: load `AGENTS.md` explicitly

Aider does not read `AGENTS.md` by itself; it reads the files you pass with `--read`
(read-only, and cached when prompt caching is on). See
[conventions](https://aider.chat/docs/usage/conventions.html). Put this in the
worktree's `.aider.conf.yml`:

```yaml
read: [AGENTS.md, tools/multi-agent-protocol/PROTOCOL.md]
```

or pass `--read AGENTS.md --read tools/multi-agent-protocol/PROTOCOL.md`. Add the session
card from [compact-rules.md](compact-rules.md) to `AGENTS.md` if the model needs it.

## 3. Git behaviour

By default Aider commits every edit it makes, and first commits any uncommitted changes it
finds in a file before editing it. See [git](https://aider.chat/docs/git.html). Under the
protocol:

- Run Aider only in the line's own worktree, on the line's branch (PROTOCOL.md 4). Its
  automatic commits are then harmless; in a shared worktree, the "dirty commits" would
  sweep another writer's changes into Aider's commits.
- Never open the coordination branch in Aider; it is read and written only through the
  scripts (PROTOCOL.md 5.1).
- Aider appends "(aider)" to the commit author or committer name by default. Projects
  that want commits under the owner's name only turn this off with
  `--no-attribute-author --no-attribute-committer` (or `attribute-author: false` and
  `attribute-committer: false` in `.aider.conf.yml`).
- `--no-auto-commits` leaves committing to the person; the report then names the commit
  the person made.

## 4. Choosing a model

For DeepSeek, set `DEEPSEEK_API_KEY` in the environment and pass
`--model deepseek/<model>`, with the model name from DeepSeek's current model list. See
[DeepSeek](https://aider.chat/docs/llms/deepseek.html). Keep the key in the environment or
the system keychain, never in `.aider.conf.yml`, the repository or a message.

## 5. A wrapper for one inbox message

`aider --message "<text>"` (or `--message-file <file>`) does one request, applies the
edits and exits. See [scripting](https://aider.chat/docs/scripting.html). A wrapper can
then run the coordination steps around it:

```sh
#!/bin/sh
# aider-line.sh: handle the oldest unread message for one line with Aider.
set -u
line=api
worktree="$HOME/code/project-api"
scripts="$worktree/tools/multi-agent-protocol/scripts"
work=$(mktemp -d) || exit 2
trap 'rm -rf "$work"' EXIT

cd "$worktree" || exit 2
message=$("$scripts/inbox.sh" "$line" | head -n 1)
[ -n "$message" ] || exit 0                         # nothing new: no model call
git show "origin/coordination:$message" >"$work/task.md" || exit 2

aider --read "$work/task.md" --message "You are line $line. Do the task in the message
you were given, within this line's area, following AGENTS.md. Edit only the files the
task needs. Do not change files on the coordination branch." || exit 2

git push origin HEAD || exit 2
printf 'Handled %s; pushed %s. Review the result, send the report, then run:\n' \
    "$message" "$(git rev-parse HEAD)"
printf '  %s/mark-read.sh %s %s\n' "$scripts" "$line" "$message"
```

The wrapper leaves the report (`send.sh`) and `mark-read.sh` to the person, after they
have looked at the result: Aider does not run the project's checks unless asked, and
`Last-read` moves only after a message has really been handled (PROTOCOL.md 5.2).

**Unverified:** how Aider handles shell commands it suggests during a non-interactive
`--message` run, and whether `--yes` makes it run them. Do not rely on Aider to run the
coordination scripts itself.

## 6. Describing an Aider session's environment

```
- Agent: Aider <output of aider --version>
- Model: deepseek/<model>
- Machine: laptop; macOS 26.6
- Sandbox: none; edits files in this worktree and commits them; network: yes (model API)
- Can run: code edits on the line branch; checks only when the person runs them
- Cannot: run the coordination scripts on its own; review or release
- Reachable by: coordination branch, through the wrapper or the person
```
