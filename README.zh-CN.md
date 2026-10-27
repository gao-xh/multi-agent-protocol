# MAP: Multi-Agent Protocol（多 agent 协作协议）

[English](README.md) · [Changelog](CHANGELOG.md)

> **候选版 2.0.0-rc.1** 在 `next` 分支（tag `v2.0.0-rc.1`）；正式版 2.0.0 发布前，`main` 和插件市场仍是 1.3.1。想试用：`git clone --branch v2.0.0-rc.1 https://github.com/gao-xh/multi-agent-protocol`，再把这个文件夹添加为插件市场（`/plugin marketplace add ./multi-agent-protocol`），或者用其中的 `scripts/install.sh` 装进你的项目，并告诉做配置的 agent 读这个 tag 里的文件，而不是 `main` 上的。改了什么见 [CHANGELOG.md](CHANGELOG.md)。

这是一套给多个 AI 编程 agent（Claude Code、Codex 等）用的治理和发布协议，适用于它们为同一位人类负责人（owner）并行开发同一个项目的场景。

编排工具（orchestrator）负责启动 agent、分配 worktree、显示进度。谁有权批准、agent 之间怎么交接、改动怎样经过严格验证才能上线，这些通常没有规定，本协议补上这一块。它可以和任何编排工具一起用，也可以只用几个普通的终端会话。

## 核心规则

1. **只有负责人能批准。** 别的 agent 转述的"负责人同意了"一律不算。长期授权可以给，但必须写明日期、范围、例外和负责人的原话，并且按最窄的意思理解。负责人不在 agent 的会话里时，可以用自己的 SSH 密钥签名的记录来批准（PROTOCOL.md 3.6，`scripts/verify.sh` 核对签名）。
2. **隔离。** 一个工作目录只有一个写入者；每条开发线用自己的分支；测试用空闲端口和一次性数据库。
3. **专门的发布角色**，严格验证：审查、检查和其他分支的重叠、本地检查、在要发布的那个 commit 上跑 CI、向负责人确认批准、用一条脚本命令部署、看真实的退出码。这些都通过后，才推进主分支。
4. **构建 → 独立审查 → 修复 → 发布**，最多五轮。
5. **接口改动在合并前先公告。**

`PROTOCOL.md` 的最后有一张真实故障的表，每条规则都对应其中至少一种故障。

## 和常见标准的关系

MAP 建在常见的 agent 标准之上，会用到它们，但不替代其中任何一个。

| 层次 | 管什么 | 例子 |
| --- | --- | --- |
| 单个 agent 的规则 | agent 每次开会话时读的规则 | `AGENTS.md`、`CLAUDE.md`：MAP 的规则块就写在这里 |
| 工具和数据 | agent 怎么调用工具、读取数据 | MCP |
| agent 之间直接通信 | agent 互相调用时的消息格式 | A2A、ACP |
| **多个 agent 和负责人之间的分工** | 谁能批准什么、谁在哪里干活、怎么交接、改动怎么进主分支 | **MAP**，只用 git |

MAP 项目里的 agent 照样可以用 MCP 服务器，也可以用 A2A 通信；MAP 只要求交接、批准和发布按它的规则、经过 coordination 分支。

## 怎么用

- **Claude Code 插件：**
  ```text
  /plugin marketplace add gao-xh/multi-agent-protocol
  /plugin install multi-agent-protocol@gao-xh-agents
  ```
  插件提供 `lead`、`line`、`release`、`liaison`（替负责人传话）、`relay`（替别的会话在本机执行命令）、`coordinate` 六个技能，以及 `builder` 和只读的 `reviewer` 两个子 agent。
- **任何 agent：** 首次配置时把 [adapters/BOOTSTRAP.md](adapters/BOOTSTRAP.md) 里的提示词贴给它：它先自己查清项目情况，把所有配置列成一页编号方案（你回"同意"或按编号改），写入前给你预览规则段，建好协调分支，自己加入，再给每个其他 agent 一张启动卡片。之后加入的 agent 贴 [adapters/JOIN.md](adapters/JOIN.md)：读项目配置、只配置自己，通常一个问题都不用问；角色表里没有的 agent，你在场就当场登记，不在场就以"待登记"身份报到，等 lead 问过你再登记。以后改某一项配置，用 [adapters/CHANGE.md](adapters/CHANGE.md) 交给 lead。初始化时先问配置要多详细（快速、标准、详细三档），再问哪种任务模式最合适（[adapters/modes.md](adapters/modes.md)：简单 GitHub 协作、私有开发公开发布、服务器部署、App 发布、负责人联络 agent、软件包发布、文档或网站、数据流水线、多服务单仓库、有外部贡献者的开源项目、研究或原型、重构或迁移、安全审计或代码审查、故障应急、远程 lead 加本地 agent），按选择给出建议。主流 agent（Claude Code、Codex、GitHub Copilot、Cursor、Gemini CLI、Windsurf、Cline、Kiro、Amp、OpenCode、Aider、Zed 等）怎么读规则、能不能推送协调分支、怎么叫醒，见 [adapters/README.md](adapters/README.md)；Windows、macOS、Linux 和 GitHub、GitLab、Bitbucket、Gitea、Azure DevOps 的注意事项见 [adapters/platforms.md](adapters/platforms.md)。各工具的详细说明见 [Codex](adapters/codex.md)、[GitHub Copilot](adapters/copilot.md)、[Gemini CLI](adapters/gemini.md)、[Cursor](adapters/cursor.md)、[OpenCode](adapters/opencode.md) 和 [Aider](adapters/aider.md)。用较小或较便宜的模型（比如 DeepSeek 的快速版）时，再加上 [adapters/compact-rules.md](adapters/compact-rules.md) 里的简短会话卡片。
- **手动：** clone 本仓库后运行 `scripts/install.sh <你的项目>`，它把协议、脚本和模板复制到项目的 `tools/multi-agent-protocol/`，以后重新运行即可更新；再把规则片段贴进项目的 `AGENTS.md`。

可以从**最小配置**开始（一个负责人、两三个会话），只需遵守批准、隔离、交接和汇报几条规则；会话、机器、工具或负责人变多时，再升级到**完整配置**（见 PROTOCOL.md 12.1）。多个负责人共同管理时，按 PROTOCOL.md 3.5 在角色表里写明每个人的批准范围。

插件可以在每次会话开始时自动列出未读消息，并在有新消息时叫醒会话（即使它正停在输入提示处空闲；这一点还没在真实会话里验证过）：插件的 monitor 运行 `scripts/watch.sh`，每 30 秒拉取一次协调分支，有发给这条线的新消息就提醒，不调用模型。在该工作目录运行一次 `/multi-agent-protocol:coordinate set-line <线名>` 即可开启，不设置就什么都不做。其他工具可以把 `scripts/watch.sh --once <线名>` 当作后台任务：先输出还没提醒过的未读消息；没有的话就等下一条新消息，输出后退出。一次来了三条以上新消息时，只输出一行汇总。

**远程工作：** 负责人或 lead 不在放数据、跑环境的那台电脑旁边时，那台电脑上的 agent 仍然可以通过协调分支接活（[adapters/modes.md](adapters/modes.md) 的模式 15）。`scripts/runner.sh` 在有新消息时启动一个无界面的 agent（Claude Code、Codex、OpenCode）；`relay` 角色在本机执行别的会话要求的命令；负责人还可以在另一台电脑上用 `scripts/remote.sh` 直接遥控 relay，命令用 SSH 密钥签名，或在项目允许时不签名（`- Owner commands:`）。relay 缺权限时，`remote.sh` 会列出它要的规则，负责人按 `y` 才放行这一次。配置指南见 [adapters/remote.md](adapters/remote.md)。

角色是职责，不是进程：同一个角色可以开多个会话并行（多条开发线、多个 builder 和 reviewer；多个 lead 按区域分工；多个发布会话通过 `release-main` 认领轮流推进主分支），项目也可以自己加角色（比如测试、文档、安全审计），但批准权只在负责人，只有发布角色能推进主分支。见 PROTOCOL.md 2.1。

角色和权限都有默认设置，项目可以在 `AGENTS.md` 里改：给角色改名、合并或去掉角色、调整谁能做什么，还可以自定义消息类型（审批方式在初始化时选，默认由 lead 汇总后请负责人批准），没写的就用默认值。有几条不能改：只有负责人能批准，同一时刻只有一个会话推进主分支，一个工作目录只有一个写入者，审查者不审自己的改动。见 PROTOCOL.md 2.2。

agent 之间通过仓库里一个不合并的孤儿分支 `coordination` 通信，里面有状态文件、消息、任务认领和负责人决定。整条线也可以转交给另一个 agent 或另一台机器：交出方提交并推送所有改动，给自己的线名留一份 `transfer` 交接单后结束；接手方用同一个线名启动，先读交接单并核对每个分支的 SHA（PROTOCOL.md 5.7）。每个会话接入时会在状态文件里写明自己的环境（工具和版本、模型、机器标签、沙箱和网络权限、能跑什么不能跑什么、新消息怎样唤醒它、能否推送 coordination 分支、负责人是否通常在场、用什么 git 身份提交：默认用线名，也可以配置成全部用负责人的名字），并通知所有人；不写主机名、IP 和任何密钥。`scripts/` 里的脚本只依赖 git 和 POSIX sh。

升级方法见 [UPGRADING.md](UPGRADING.md)：从 1.4 起，`session-start.sh` 和 `doctor.sh` 会在有新版本时提示一行（`MAP_UPDATE_CHECK=0` 关闭），`doctor.sh` 还会在各会话版本不一致时警告。升级由 lead 处理：用 `upgrade.sh --check <项目>` 列出改动，再问负责人；配置时可以选升级策略（手动、自动装补丁版本、自动装次版本），主版本和规则段有变化时总是要问负责人（PROTOCOL.md 12.3）。

完整内容以英文的 [PROTOCOL.md](PROTOCOL.md) 为准。许可证：MIT。
