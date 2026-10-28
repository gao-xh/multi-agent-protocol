#!/bin/sh
# Reuse the shared JSON hook output; a hook is a summary, never a background worker.
set -u
plugin_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd) || exit 0
# Hooks must not open credential prompts or check the upstream release by default.
GIT_TERMINAL_PROMPT=0
GCM_INTERACTIVE=never
GIT_ASKPASS=false
SSH_ASKPASS=false
SSH_ASKPASS_REQUIRE=never
MAP_UPDATE_CHECK=${MAP_UPDATE_CHECK:-0}
MAP_FETCH_SECONDS=${MAP_FETCH_SECONDS:-3}
if [ -z "${GIT_SSH:-}" ]; then
    ssh_command=${GIT_SSH_COMMAND:-$(git config --get core.sshCommand 2>/dev/null)}
    GIT_SSH_COMMAND="${ssh_command:-ssh} -o BatchMode=yes -o ConnectTimeout=3"
    export GIT_SSH_COMMAND
fi
export GIT_TERMINAL_PROMPT GCM_INTERACTIVE GIT_ASKPASS SSH_ASKPASS SSH_ASKPASS_REQUIRE
export MAP_UPDATE_CHECK MAP_FETCH_SECONDS
sh "$plugin_root/scripts/session-start.sh" --json hook
