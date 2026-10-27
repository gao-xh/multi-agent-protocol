# Status: <line>

- Role: <lead / line / release / liaison / relay>
- Branch: <branch>
- Task: <current task, or "idle">
- Area: <files or directories this line is changing>
- State: <building / in review / waiting for release / blocked: reason / idle>
- Last-read: <last fully handled message file, or "none">
- Updated: <UTC timestamp, YYYY-MM-DDTHH:MM:SSZ>

## Environment

- Protocol: <filled in by status.sh: the version of the protocol's scripts>
- Agent: <tool and version, for example "Codex CLI 0.150" or "Claude Code 2.1.304"; "unknown" if unsure>
- Model: <model as the tool reports it, or "unknown">
- Machine: <label the owner chose, for example "laptop">; <operating system and version>
- Sandbox: <none / read-only / workspace-write / other>; network: <yes / no / asks first>
- Can run: <for example unit tests, end-to-end tests, a browser, a mobile simulator, GPU jobs>
- Cannot: <for example push without approval, reach the production server, read local data>
- Reachable by: <coordination branch only, or also direct session messages in <tool>>; checks the inbox <at session start / every N minutes>
- Wake: <how a new message reaches this session while it runs: monitor (watch.sh in the Claude Code plugin) / background task (watch.sh --once) / runner (scripts/runner.sh starts the agent) / session-start hook only / timer starts a new run / none; see adapters/README.md>
- Pushes coordination branch: <yes / no (then it works as a builder and a line reports for it)>
- Owner present: <usually / sometimes / never (runs unattended)>
- Git identity: <the name this session commits under: its line name with "- Commit author: line" (the default), the owner's name with "owner"; no email needed>

## Open questions for the owner

<lead only: questions waiting for the owner, with the asking message; or "none". Other roles delete this section>
