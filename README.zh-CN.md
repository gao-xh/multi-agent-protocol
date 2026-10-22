# Multi-Agent Protocol（多 agent 协作协议）

[English](README.md) · [Changelog](CHANGELOG.md)

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
- **手动：** clone 本仓库后运行 `scripts/install.sh <你的项目>`，它把协议、脚本和模板复制到项目的 `tools/multi-agent-protocol/`，以后重新运行即可更新；再把规则片段贴进项目的 `AGENTS.md`。

可以从**最小配置**开始（一个负责人、两三个会话），只需遵守批准、隔离、交接和汇报几条规则；会话、机器、工具或负责人变多时，再升级到**完整配置**（见 PROTOCOL.md 12.1）。多个负责人共同管理时，按 PROTOCOL.md 3.5 在角色表里写明每个人的批准范围。

插件可以在每次会话开始时自动列出未读消息：在该工作目录运行一次 `/multi-agent-protocol:coordinate set-line <线名>` 即可开启，不设置就什么都不做。

角色是职责，不是进程：同一个角色可以开多个会话并行（多条开发线、多个 builder 和 reviewer；多个 lead 按区域分工；多个发布会话通过 `release-main` 认领轮流推进主分支），项目也可以自己加角色（比如测试、文档、安全审计），但批准权只在负责人，只有发布角色能推进主分支。见 PROTOCOL.md 2.1。

agent 之间通过仓库里一个不合并的孤儿分支 `coordination` 通信，里面有状态文件、消息、任务认领和负责人决定。整条线也可以转交给另一个 agent 或另一台机器：交出方提交并推送所有改动，给自己的线名留一份 `transfer` 交接单后结束；接手方用同一个线名启动，先读交接单并核对每个分支的 SHA（PROTOCOL.md 5.7）。每个会话接入时会在状态文件里写明自己的环境（工具和版本、模型、机器标签、沙箱和网络权限、能跑什么不能跑什么），并通知所有人；不写主机名、IP 和任何密钥。`scripts/` 里的脚本只依赖 git 和 POSIX sh。

完整内容以英文的 [PROTOCOL.md](PROTOCOL.md) 为准。许可证：MIT。
