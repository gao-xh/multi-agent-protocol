# Platforms: operating systems and git hosts

Checked on 2026-10-22. The scripts need only git and a POSIX `sh` with the usual tools
(`awk`, `sed`, `grep`, `sort`, `mktemp`, `ps`). The tests run on Linux with dash and bash and
on macOS with its `/bin/sh` (CI).

## Operating systems

| System | Notes |
| --- | --- |
| Linux | Debian and Ubuntu use dash as `/bin/sh` and mawk as `awk`; the scripts are tested with both. |
| macOS | `/bin/sh` is bash 3.2 in POSIX mode, and `awk` is not GNU awk; tested in CI. Install Git from Xcode's command line tools or Homebrew. |
| Windows | Use Git for Windows (its `sh`, "Git Bash") or WSL. PowerShell alone cannot run the scripts: call `sh scripts/<name>.sh` from PowerShell with Git's `bin` on `PATH`. Git for Windows converts line endings to CRLF by default, which breaks `.sh` files (`$'\r': command not found`): this repository's `.gitattributes` keeps them LF, and `install.sh` writes the same rule into the copied folder. With an older copy, run `git config core.autocrlf input` or add `*.sh text eol=lf` to `.gitattributes`, then `git add --renormalize .` ([GitHub docs](https://docs.github.com/en/get-started/git-basics/configuring-git-to-handle-line-endings)). Git Bash's `ps` lacks some options: `watch.sh` then stops only the git process of a fetch that hangs, not its helpers (unconfirmed in practice). |

## Git hosts

All hosts store the orphan `coordination` branch like any other branch. Two settings help:
keep agents from pushing to the main branch (by default only the release role advances
it, PROTOCOL.md 2.2), and run `scripts/doctor.sh` in CI when the coordination branch changes.

`doctor.sh` needs the coordination branch: in CI, fetch it with
`git fetch origin coordination:refs/remotes/origin/coordination` and run
`MAP_UPDATE_CHECK=0 sh scripts/doctor.sh --no-fetch` from a checkout of the main branch
(the coordination branch itself holds no scripts).

| Host | Keep agents off the main branch | Run doctor on pushes to `coordination` |
| --- | --- | --- |
| GitHub | Ruleset "Restrict updates" with a GitHub App that only the release session uses as the only bypass actor, plus "Block force pushes". Bypass actors are roles, teams, GitHub Apps and Dependabot, not single user accounts; sessions that push with the owner's credentials are one actor, so this separates the release session only when it pushes as its own App ([docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)). On the Free plan, rulesets cover public repositories only. | A workflow in the **main branch** with `on: push: branches: [coordination]` runs from the workflow file on the pushed branch, which has none; use `on: schedule` or `workflow_dispatch` on the main branch instead, or run doctor in the release role's checks ([events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows)). |
| GitLab | Protected branch with "Allowed to push and merge: No one" (or only the release account) ([docs](https://gitlab.com/gitlab-org/gitlab/-/blob/master/doc/user/project/repository/branches/protected.md)). | A scheduled pipeline on the main branch that fetches `coordination` and runs doctor (the coordination branch has no `.gitlab-ci.yml`). |
| Bitbucket Cloud | Branch restrictions on the main branch (unconfirmed details). | A scheduled pipeline on the main branch, as above (unconfirmed for this host). |
| Gitea / Forgejo | Protected branch with a push allowlist (unconfirmed details). | A scheduled workflow (`.gitea/workflows` or `.forgejo/workflows`) on the main branch (unconfirmed for this host). |
| Azure DevOps | Branch permissions: deny "Contribute" on the main branch for agent accounts ([docs](https://github.com/MicrosoftDocs/azure-devops-docs/blob/HEAD/docs/repos/git/branch-permissions.md)). | A scheduled pipeline on the main branch. |

Claude Code on the web pushes only to GitHub; other hosts need local sessions or other
agents for lines that push.

## Private repositories and CI minutes

macOS and Windows runners cost more than Linux ones in private repositories (on GitHub,
about ten and two times the Linux rate; GitLab's free tier has no macOS runners). This
repository runs its macOS job on demand in the private development repository for that
reason.

## A private coordination branch for a public repository

On a public repository the coordination branch, and with it every status file and
message, is public. To keep it private, put it in a separate private repository:

1. Create an empty private repository and add it as a remote in every session's checkout,
   for example `git remote add coord <url>`.
2. Set `MAP_REMOTE=coord` for every session (the coordination scripts then fetch and push
   the coordination branch there) and run `scripts/init-coordination.sh` once.
3. Leave `MAP_MAIN_REMOTE` unset if the main branch lives on that same remote; otherwise
   set it to the public repository's remote (for example `MAP_MAIN_REMOTE=origin`), so
   that `verify.sh` and the project's message types are read from the real main branch.

Every session needs read and write access to the private repository. Claude Code on the
web pushes only to repositories on GitHub that its GitHub connection covers.
