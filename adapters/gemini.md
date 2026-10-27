# Gemini CLI

Checked on 2026-10-22 against the gemini-cli repository's docs.

- **Rules:** Gemini reads `GEMINI.md`. Add `AGENTS.md` in `.gemini/settings.json`:
  `{"context": {"fileName": ["AGENTS.md", "GEMINI.md"]}}`
  ([docs](https://github.com/google-gemini/gemini-cli/blob/HEAD/docs/cli/gemini-md.md)).
- **Skills:** `.gemini/skills/` or `.agents/skills/`; `gemini skills install <git URL>`.
- **Session start:** a `SessionStart` hook's `hookSpecificOutput.additionalContext` becomes
  the first turn ([docs](https://github.com/google-gemini/gemini-cli/blob/HEAD/docs/hooks/reference.md)).
  Have it run `scripts/session-start.sh --json hook` with `MAP_LINE` set: that prints the
  summary in this JSON form.
- **Waking an idle session:** no mechanism found. Use a timer that runs
  `scripts/inbox.sh <line>` and starts `gemini -p "..."` only when it exits 0, as
  [codex.md](codex.md) section 4 shows for Codex. `--approval-mode auto_edit` approves only
  edits, so the run cannot call the scripts or `git push` unattended; use
  `--approval-mode yolo` only inside a sandbox, or an allowed-tools list.
- **Windows:** the shell tool runs PowerShell
  ([docs](https://github.com/google-gemini/gemini-cli/blob/HEAD/docs/tools/shell.md)); call
  `sh scripts/<name>.sh` with Git for Windows' `bin` on `PATH`.
- **Sandbox:** off unless `--sandbox` or `GEMINI_SANDBOX` is set; when on, check that git can
  reach the remote.
