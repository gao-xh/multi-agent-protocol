# Multi-Agent Protocol（多 agent 协作协议）

[English](README.md)

这是一套给多个 AI 编程 agent（Claude Code、Codex 等）用的治理和发布协议，适用于它们为同一位人类负责人（owner）并行开发同一个项目的场景。

编排工具（orchestrator）负责启动 agent、分配 worktree、显示进度。谁有权批准、agent 之间怎么交接、改动怎样经过严格验证才能上线，这些通常没有规定，本协议补上这一块。它可以和任何编排工具一起用，也可以只用几个普通的终端会话。

## 核心规则

1. **只有负责人能批准。** 别的 agent 转述的"负责人同意了"一律不算。长期授权可以给，但必须写明日期、范围、例外和负责人的原话，并且按最窄的意思理解。
2. **隔离。** 一个工作目录只有一个写入者；每条开发线用自己的分支；测试用空闲端口和一次性数据库。
3. **专门的发布角色**，严格验证：审查、检查和其他分支的重叠、本地检查、在要发布的那个 commit 上跑 CI、向负责人确认批准、用一条脚本命令部署、看真实的退出码。这些都通过后，才推进主分支。
4. **构建 → 独立审查 → 修复 → 发布**，最多五轮。
5. **接口改动在合并前先公告。**

`PROTOCOL.md` 的最后有一张真实故障的表，每条规则都对应其中至少一种故障。

## 怎么用

- **Claude Code 插件：**
  ```text
  /plugin marketplace add gao-xh/multi-agent-protocol
  /plugin install multi-agent-protocol@gao-xh-agents
  ```
  插件提供 `lead`、`line`、`release`、`coordinate` 四个技能，以及 `builder` 和只读的 `reviewer` 两个子 agent。
- **任何 agent：** 把 [adapters/BOOTSTRAP.md](adapters/BOOTSTRAP.md) 里的提示词贴给它，它会读协议、问你角色分工和长期授权、在 `AGENTS.md` 里加上规则、建好协调分支。Codex 的注意事项见 [adapters/codex.md](adapters/codex.md)。
- **手动：** 把 [adapters/AGENTS.md.snippet](adapters/AGENTS.md.snippet) 复制进项目的 `AGENTS.md`，再把 `scripts/` 和 `templates/` 复制进项目。

agent 之间通过仓库里一个不合并的孤儿分支 `coordination` 通信，里面有状态文件、消息、任务认领和负责人决定。`scripts/` 里的脚本只依赖 git 和 POSIX sh。

完整内容以英文的 [PROTOCOL.md](PROTOCOL.md) 为准。许可证：MIT。
