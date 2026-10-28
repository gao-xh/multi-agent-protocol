# MAP: Multi-Agent Protocol（多 agent 协作协议）

[English](README.md) · [Changelog](CHANGELOG.md)

MAP 让一组 AI 编程 agent（Claude Code、Codex 等）真正一起替你做项目，像一个团队：lead 规划和分派任务，其他 agent 并行完成各自的部分、互相审查，你只在需要决定时出场。

## 团队怎么协作

- **分工。** lead 把任务拆成几块，分给不同的开发线：每条线是一个 agent，有自己的分支和负责的区域，写在角色表里。各条线并行开发，任何角色都可以同时开多个会话。
- **派活和交接。** 工作以书面消息的形式在你自己仓库的协调分支上流转：交接单写明目标、已确认的事实和要跑的检查；认领保证两个 agent 不会做同一件事；状态文件写明谁在做什么。一整条线也可以转给另一个 agent 或另一台机器接着做。
- **不用盯着。** 新消息不用你转达：runner 会为它们启动一个无界面的 agent，Claude Code 的 monitor 会提醒已打开的会话。你不在时，问题交给 lead，等你回来一次问完。
- **工具和机器不限。** Claude Code、Codex、OpenCode、Copilot 等可以在同一个团队里协作，只靠 git；网页上的 lead 也可以把活派给你工作站上的 agent（见下面的"远程工作"）。

## 质量可以核对

- **独立审查。** 改动由没参与开发的 agent 审查，给出分级的问题和证据；审查结论只对它写明的那个 commit 有效。
- **专门的发布角色**才能推进主分支，而且要在要发布的那个 commit 上检查通过、批准都确认过之后。
- **"完成"** 的意思是：一个已推送的 commit SHA，加上实际跑过的检查和结果。

## 你始终说了算

- **只有你能批准。** 别的 agent 转述的"负责人同意了"一律不算。
- **长期授权**可以给，按你的原话记录范围和例外；不在场时，可以用自己的 SSH 密钥签名的记录来批准。
- **配置只问一次**：所有设置列成一页编号方案，每项都有建议。

## 背后的规则

为了让并行开发不互相打架，团队协作建立在几条朴素的规则上：一个工作目录只有一个写入者；每条线用自己的分支；先认领再动手；接口改动在合并前先公告。`PROTOCOL.md` 的最后有一张真实故障的表，每条规则都对应其中至少一种故障。MAP 是一套规则加几个小工具，可以和任何编排工具一起用，也可以只用几个普通的终端会话。

## 开始使用

### 1. 配置项目

在你的项目里，对要当 lead 的 agent（Claude Code、Codex 或其他）说一句："用 https://github.com/gao-xh/multi-agent-protocol 配置这个项目"。它会自己按 [adapters/BOOTSTRAP.md](adapters/BOOTSTRAP.md) 做：

1. 查看仓库、项目的检查命令和它自己的环境，这一步不改任何东西；
2. 问你三件事：想看多详细的配置、这是哪类项目（[任务模式](adapters/modes.md)）、哪些 agent 会参与；
3. 把所有设置列成一页编号方案，每项注明是查到的、推荐的还是假定的：你回"同意"，或者按编号改；
4. 写入前先给你看规则段，然后写进 `AGENTS.md`，建好协调分支，自己以 lead 身份加入；
5. 给每个其他 agent 一张启动卡片：在哪里打开、贴什么。

可以从小规模开始：一个负责人、两三个会话，只需要几条核心规则；会话、机器、工具或负责人变多时，再加上协调分支和发布角色（见 [PROTOCOL.md 12.1](PROTOCOL.md#121-profiles)）。

### 2. 加入其他 agent

在项目的工作目录里打开每个 agent，对它说一句："加入这个项目"（知道它负责哪条线，就加上"作为 `api` 线"）。lead 写进 `AGENTS.md` 的规则会让它去读 [adapters/JOIN.md](adapters/JOIN.md)，它会自己照着做：读取项目设置、检查自己的环境、只配置自己，然后向团队报到，通常一个问题都不用问。lead 给的启动卡片会写明每个 agent 在哪里打开。角色表里还没有的 agent，经你批准后加入。以后要改某项设置，把 [adapters/CHANGE.md](adapters/CHANGE.md) 交给 lead。

### 3. Claude Code 插件（可选）

```text
/plugin marketplace add gao-xh/multi-agent-protocol
/plugin install multi-agent-protocol@gao-xh-agents
/multi-agent-protocol:coordinate set-line api      # 每个工作目录设一次
```

每个会话用自己的角色启动（`/multi-agent-protocol:lead`、`/multi-agent-protocol:line api`、`/multi-agent-protocol:release`）；`/multi-agent-protocol:coordinate` 负责收件箱、消息和认领，`builder` 和 `reviewer` 两个子 agent 可以接委派的工作。设好线名后，每次会话开始会列出未读消息和认领，有新消息时 monitor 会提醒会话。插件一共有 `lead`、`line`、`release`、`liaison`（替负责人传话）、`relay`（替别的会话在本机执行命令）、`coordinate` 六个技能。

### Codex 插件（可选）

这个仓库同时也是一个 Codex 插件，带角色技能和可选的会话开始时列出收件箱的功能：先 `codex plugin marketplace add <克隆的路径>`，再 `codex plugin add multi-agent-protocol@gao-xh-map-codex`（见 [codex/README.md](codex/README.md)）。

### 4. 远程工作（可选）

你或 lead 不在放数据、跑环境的那台电脑旁边时，那台电脑上的 agent 仍然可以通过协调分支接活（任务模式 15）。`scripts/runner.sh` 在有新消息时启动一个无界面的 agent（Claude Code、Codex、OpenCode）；`relay` 在本机执行别的会话要求的命令；你还可以在另一台电脑上用 `scripts/remote.sh` 直接遥控 relay，命令用 SSH 密钥签名，或在项目允许时不签名。relay 缺权限时，`remote.sh` 会列出它要的规则，你按 `y` 才放行这一次。配置指南见 [adapters/remote.md](adapters/remote.md)。

### 5. 手动安装

```sh
git clone https://github.com/gao-xh/multi-agent-protocol
multi-agent-protocol/scripts/install.sh path/to/your-project   # 以后重新运行即可更新
```

它把协议、脚本和模板复制到项目的 `tools/multi-agent-protocol/`，不改别的。再把规则片段贴进 `AGENTS.md`（Claude Code 用的 `CLAUDE.md` 指向它），填好角色表，运行 `tools/multi-agent-protocol/scripts/init-coordination.sh`。

### 参考

- 各类项目和各自需要的设置：[adapters/modes.md](adapters/modes.md)。
- 各种 agent 工具（怎么读规则、能不能推送、怎么叫醒）：[adapters/README.md](adapters/README.md)，以及 [Codex](adapters/codex.md)、[OpenCode](adapters/opencode.md)、[Aider](adapters/aider.md)、[GitHub Copilot](adapters/copilot.md)、[Gemini CLI](adapters/gemini.md)、[Cursor](adapters/cursor.md) 的说明。
- Windows、macOS、Linux 和各家 git 托管：[adapters/platforms.md](adapters/platforms.md)。
- 较小或较便宜的模型：[adapters/compact-rules.md](adapters/compact-rules.md)。
- 升级项目：[UPGRADING.md](UPGRADING.md)。

## 和常见标准的关系

MAP 建在常见的 agent 标准之上，会用到它们，但不替代其中任何一个。

| 层次 | 管什么 | 例子 |
| --- | --- | --- |
| 单个 agent 的规则 | agent 每次开会话时读的规则 | `AGENTS.md`、`CLAUDE.md`：MAP 的规则块就写在这里 |
| 工具和数据 | agent 怎么调用工具、读取数据 | MCP |
| agent 之间直接通信 | agent 互相调用时的消息格式 | A2A、ACP |
| **多个 agent 和负责人之间的分工** | 谁能批准什么、谁在哪里干活、怎么交接、改动怎么进主分支 | **MAP**，只用 git |

MAP 项目里的 agent 照样可以用 MCP 服务器，也可以用 A2A 通信；MAP 只要求交接、批准和发布按它的规则、经过 coordination 分支。

## 工作原理

角色是职责，不是进程：同一个角色可以开多个会话并行（多条开发线、多个 builder 和 reviewer；多个 lead 按区域分工；多个发布会话通过 `release-main` 认领轮流推进主分支），项目也可以自己加角色（比如测试、文档、安全审计），但批准权只在负责人，只有发布角色能推进主分支。见 PROTOCOL.md 2.1。

角色和权限都有默认设置，项目可以在 `AGENTS.md` 里改：给角色改名、合并或去掉角色、调整谁能做什么，还可以自定义消息类型（审批方式在初始化时选，默认由 lead 汇总后请负责人批准），没写的就用默认值。有几条不能改：只有负责人能批准，同一时刻只有一个会话推进主分支，一个工作目录只有一个写入者，审查者不审自己的改动。见 PROTOCOL.md 2.2。

agent 之间通过仓库里一个不合并的孤儿分支 `coordination` 通信，里面有状态文件、消息、任务认领和负责人决定。整条线也可以转交给另一个 agent 或另一台机器：交出方提交并推送所有改动，给自己的线名留一份 `transfer` 交接单后结束；接手方用同一个线名启动，先读交接单并核对每个分支的 SHA（PROTOCOL.md 5.7）。每个会话接入时会在状态文件里写明自己的环境（工具和版本、模型、机器标签、沙箱和网络权限、能跑什么不能跑什么、新消息怎样唤醒它、能否推送 coordination 分支、负责人是否通常在场、用什么 git 身份提交：默认用线名，也可以配置成全部用负责人的名字），并通知所有人；不写主机名、IP 和任何密钥。`scripts/` 里的脚本只依赖 git 和 POSIX sh。

升级方法见 [UPGRADING.md](UPGRADING.md)：从 1.4 起，`session-start.sh` 和 `doctor.sh` 会在有新版本时提示一行（`MAP_UPDATE_CHECK=0` 关闭），`doctor.sh` 还会在各会话版本不一致时警告。升级由 lead 处理：用 `upgrade.sh --check <项目>` 列出改动，再问负责人；配置时可以选升级策略（手动、自动装补丁版本、自动装次版本），主版本和规则段有变化时总是要问负责人（PROTOCOL.md 12.3）。

完整内容以英文的 [PROTOCOL.md](PROTOCOL.md) 为准。许可证：MIT。
