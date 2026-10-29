# Contributing to MAP

Thanks for looking. MAP is a protocol (`PROTOCOL.md`) plus small POSIX shell tools, so
the most useful contributions are reports from real use: what your agents did, where a
rule was unclear, and where a script failed.

## Ways to help

- **Report a script bug.** Open an issue with the command you ran, its exit status and
  output, your shell (`sh`, `dash`, `bash`, `zsh`), operating system and git version, and
  `scripts/doctor.sh` output if it is relevant. Leave out host names, user names, paths
  with personal names and anything secret.
- **Ask about or challenge a rule.** Open an issue that names the section (for example
  "PROTOCOL.md 5.6") and describes what your agents did and what you expected. Failure
  modes you hit in practice are especially welcome: the table in PROTOCOL.md 11 grew from
  them.
- **Report compatibility.** If you maintain a tool or orchestrator that reads or writes
  the coordination branch, tell us what you rely on (message headers, file layout, script
  output, exit codes). Interface changes are announced before they merge (PROTOCOL.md
  5.3), and listed in `CHANGELOG.md`.
- **Add notes for an agent tool.** `adapters/` has one file per tool. A new one should say
  how the tool reads the rules, whether it can push, and how a new message wakes it, with
  what you actually checked.

## Pull requests

This repository receives one commit per release; development happens elsewhere and is
exported here. A pull request is still welcome: it is reviewed here, and if it is taken,
the change is applied in the development repository and arrives with the next release,
credited to you in `CHANGELOG.md`. For anything larger than a fix, open an issue first.

Before you open one:

- Run `tests/test-scripts.sh` (and `tests/test-scripts.sh dash` if you can).
- Keep scripts POSIX `sh`; ShellCheck runs in CI.
- Write in plain English; keep `README.zh-CN.md` in step if you change the README.
- Say which version you based the change on (`VERSION` in an installed copy, or the tag).

## Versions

`CHANGELOG.md` explains what makes a change major, minor or patch. Major and minor
releases go out first as release candidates on the `next` branch.

## Conduct

Be kind and specific. Talk about the work, not the person.
