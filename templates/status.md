# Status: <line>

- Role: <lead / line / release>
- Branch: <branch>
- Task: <current task, or "idle">
- Area: <files or directories this line is changing>
- State: <building / in review / waiting for release / blocked: reason / idle>
- Last-read: <last fully handled message file, or "none">
- Updated: <UTC timestamp, YYYY-MM-DDTHH:MM:SSZ>

## Environment

- Agent: <tool and version, for example "Codex CLI 0.150" or "Claude Code 2.1.304"; "unknown" if unsure>
- Model: <model as the tool reports it, or "unknown">
- Machine: <label the owner chose, for example "laptop">; <operating system and version>
- Sandbox: <none / read-only / workspace-write / other>; network: <yes / no / asks first>
- Can run: <for example unit tests, end-to-end tests, a browser, a mobile simulator, GPU jobs>
- Cannot: <for example push without approval, reach the production server, read local data>
- Reachable by: <coordination branch only, or also direct session messages in <tool>>; checks the inbox <at session start / every N minutes>
