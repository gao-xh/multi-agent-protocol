# MAP for Codex

This is the Codex integration of MAP. It uses the shared protocol, scripts and
templates in this repository. The Claude integration remains separate.

The native entry point is `.codex-plugin/plugin.json`; its explicit skill and
hook paths select this directory rather than the Claude skills and hook file.
This supported compatibility layout lets both integrations share one package
without duplicating the shell scripts. Keep its version synchronized with the
Claude manifest when the release role changes the project version.

## Install and join

From a clone containing this implementation, review the plugin, then install it
with the user's authorization:

```sh
codex plugin marketplace add /absolute/path/to/multi-agent-protocol
codex plugin add multi-agent-protocol@gao-xh-map-codex
```

These commands update Codex's plugin cache and enablement settings. They are
instructions for an intentional installation, not a development-test prerequisite.
The marketplace entry is available to install; it does not install by default.

Start a new Codex session in the target project's own checkout. Use the project's
normal join prompt, such as "Join this project as line api." The project's
AGENTS.md and chosen protocol copy govern line assignment and permissions.
Installing a plugin does not assign a role or change the project's shared rules.

The plugin exposes these skills in the `multi-agent-protocol` namespace:

| Skill | Use |
| --- | --- |
| `map-coordinate` | Join or resume an assigned line, check the inbox, publish status and coordinate tasks |
| `map-lead` | Perform an assigned lead role |
| `map-line` | Develop an assigned area on an isolated branch |
| `map-release` | Verify and release an assigned exact commit |
| `map-liaison` | Carry questions and the owner's answers without making decisions |
| `map-relay` | Run bounded machine requests in the relay's permitted area |

Skill files resolve bundled resources from their own installed location, so they
do not depend on a hook-only environment variable or a fixed cache path. Prefer
project-vendored scripts when AGENTS.md specifies them. Otherwise the bundled
bridge is available as:

```sh
sh /installed/plugin/root/codex/map.sh inbox --show api
sh /installed/plugin/root/codex/map.sh send --strict /path/to/message.md
```

The bridge preserves script arguments and exit statuses. Inbox exit 1 means no
unread messages; exit 2 is an error. It does not grant permissions or bypass the
Codex sandbox. Git metadata or network operations may need normal approval.

## Optional session-start summary

After the project assigns the checkout to a line, store that name using its
selected `set-line.sh`, or the bundled `codex/map.sh set-line LINE`. Run one live
session per line and checkout. A later session in the same checkout sees that
stored identity too; it must not become a second writer for that line.

Open `/hooks` in Codex, inspect the plugin's SessionStart definition and script,
and trust it only when you intend to enable this integration. Installation does
not trust hooks. Changes to the hook definition require review again.

The hook delegates to the shared `session-start.sh --json hook` and returns the
Codex SessionStart context shape. It runs in the target session's working
directory. It is silent outside git or without a stored line, summarizes unread
messages and claims, and does not handle messages, mark them read, install a
watcher or start another agent. Its fetch uses the shared script's bounded wait;
when fetching is unavailable it can summarize the previously fetched copy.
Always run the normal inbox routine before acting on messages.

Credential prompts are disabled for this hook process. The default fetch wait is
three seconds, the hook timeout is fifteen seconds, and the optional upstream
release check is off by default. `MAP_FETCH_SECONDS` and `MAP_UPDATE_CHECK` can
be set explicitly when that behavior is wanted. The shared scripts retain their
normal defaults when invoked outside this wrapper.

Report `Wake: none` unless another wake mechanism has actually been configured
and verified. A SessionStart summary does not demonstrate idle wake, busy-session
delivery, or unattended headless execution. Hook availability also depends on
the Codex surface and the script's presence in its execution environment.

## Development checks

Runtime dependencies are git and POSIX sh. The deterministic integration suite
uses Ruby's standard library; no gem installation is needed:

```sh
ruby codex/test-plugin.rb
shellcheck --shell=sh codex/map.sh codex/session-start.sh
```

The suite uses disposable local bare remotes. It checks argument/exit-status
handling, worktree-specific line bindings, real inbox contents in hook JSON,
offline cached summaries and installed paths containing spaces. It never uses
the developer's git identity configuration or an external fixture remote.

When Codex is available, inspect the package through its native read-only API:

```sh
ruby codex/check-runtime.rb
```

This starts a bounded stdio app-server, requests `plugin/read`, and checks the six
namespaced skills and native session-start hook. It does not install the plugin,
change enabled state, trust a hook or start a model run. The Codex process may
need ordinary tool approval to access its own runtime state. Run the project's
normal gate as well before requesting integration.

Native discovery and direct hook execution do not prove an installed, trusted
hook ran in a live model session. Record that distinction in verification reports.

Official formats: [plugin packaging](https://developers.openai.com/plugins/build/plugins)
and [Codex hooks](https://learn.chatgpt.com/docs/hooks).
