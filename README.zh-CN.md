# Multi-Agent Protocol（多 agent 协作协议）

[English](README.md) · [Changelog](CHANGELOG.md)

Multi-Agent Protocol 让一组 AI 编程 agent（Claude Code、Codex 等）真正一起替你做项目，像一个团队：lead 规划和分派任务，其他 agent 并行完成各自的部分、互相审查，你只在需要决定时出场。

> **2.0 即将发布：** 候选版在 [`next`](https://github.com/gao-xh/multi-agent-protocol/tree/next) 分支（tag [`v2.0.0-rc.1`](https://github.com/gao-xh/multi-agent-protocol/releases/tag/v2.0.0-rc.1)），新增了配置和加入提示词、新消息自动唤醒 agent、远程工作。本页介绍的是稳定版 1.3。

## 团队怎么协作

- **分工。** lead 把任务拆成几块，分给不同的开发线：每条线是一个 agent，有自己的分支和负责的区域，写在角色表里。各条线并行开发，任何角色都可以同时开多个会话。
- **派活和交接。** 工作以书面消息的形式在你自己仓库的协调分支上流转：交接单写明目标、已确认的事实和要跑的检查；认领保证两个 agent 不会做同一件事；状态文件写明谁在做什么。一整条线也可以转给另一个 agent 或另一台机器接着做。
- **接着别人的进度干。** 每个会话开始时会列出自己的未读消息和认领；agent 也可以定时检查收件箱，不调用模型。
- **工具和机器不限。** Claude Code、Codex、OpenCode、Aider 等可以在同一个团队里协作，只靠 git。

## 质量可以核对

- **独立审查。** 改动由没参与开发的 agent 审查，给出分级的问题和证据。
- **专门的发布角色**才能推进主分支，而且要在要发布的那个 commit 上检查通过、批准都确认过之后。
- **"完成"** 的意思是：一个已推送的 commit SHA，加上实际跑过的检查和结果。

## 你始终说了算

- **只有你能批准。** 别的 agent 转述的"负责人同意了"一律不算。
- **长期授权**可以给，按你的原话记录范围和例外；不在场时，可以用自己的 SSH 密钥签名的记录来批准。

## 背后的规则

为了让并行开发不互相打架，团队协作建立在几条朴素的规则上：一个工作目录只有一个写入者；每条线用自己的分支；先认领再动手；接口改动在合并前先公告。`PROTOCOL.md` 的最后有一张真实故障的表，每条规则都对应其中至少一种故障。它是一套规则加几个小工具，可以和任何编排工具一起用，也可以只用几个普通的终端会话。

## 开始使用

### 1. 配置项目

在你的项目里，对要当 lead 的 agent（Claude Code、Codex 或其他）说一句："用 https://github.com/gao-xh/multi-agent-protocol 配置这个项目"。它会自己按 [adapters/BOOTSTRAP.md](adapters/BOOTSTRAP.md) 做：读协议、问你角色分工和长期授权、在 `AGENTS.md` 里加上规则、建好协调分支、发布自己的状态。

可以从小规模开始：一个负责人、两三个会话，只需要几条核心规则；会话、机器、工具或负责人变多时，再加上协调分支和发布角色（见 PROTOCOL.md 12.1）。多个负责人共同管理时，按 PROTOCOL.md 3.5 在角色表里写明每个人的批准范围。

### 2. 启动其他 agent

在各自的工作目录里打开每个 agent，告诉它是哪条线："你是这个项目的 `api` 线，按 AGENTS.md 里的 Multi-Agent Protocol 工作。"用 Claude Code 插件时，改用对应的角色启动（见下）。

### 3. Claude Code 插件（可选）

```text
/plugin marketplace add gao-xh/multi-agent-protocol
/plugin install multi-agent-protocol@gao-xh-agents
/multi-agent-protocol:coordinate set-line api      # 每个工作目录设一次
```

每个会话用自己的角色启动（`/multi-agent-protocol:lead`、`/multi-agent-protocol:line api`、`/multi-agent-protocol:release`）；`/multi-agent-protocol:coordinate` 负责收件箱、消息和认领，`builder` 和只读的 `reviewer` 两个子 agent 可以接委派的工作。设好线名后，每次会话开始会列出未读消息和认领。

### 4. 手动安装

clone 本仓库后运行 `scripts/install.sh <你的项目>`，它把协议、脚本和模板复制到项目的 `tools/multi-agent-protocol/`，以后重新运行即可更新；再把规则片段贴进 `AGENTS.md`，填好角色表，运行 `tools/multi-agent-protocol/scripts/init-coordination.sh`。

各工具的注意事项见 [Codex](adapters/codex.md)、[OpenCode](adapters/opencode.md) 和 [Aider](adapters/aider.md)。用较小或较便宜的模型（比如 DeepSeek 的快速版）时，再加上 [adapters/compact-rules.md](adapters/compact-rules.md) 里的简短会话卡片。

## 工作原理

角色是职责，不是进程：同一个角色可以开多个会话并行（多条开发线、多个 builder 和 reviewer；多个 lead 按区域分工；多个发布会话通过 `release-main` 认领轮流推进主分支），项目也可以自己加角色（比如测试、文档、安全审计），但批准权只在负责人，只有发布角色能推进主分支。见 PROTOCOL.md 2.1。

agent 之间通过仓库里一个不合并的孤儿分支 `coordination` 通信，里面有状态文件、消息、任务认领和负责人决定。整条线也可以转交给另一个 agent 或另一台机器：交出方提交并推送所有改动，给自己的线名留一份 `transfer` 交接单后结束；接手方用同一个线名启动，先读交接单并核对每个分支的 SHA（PROTOCOL.md 5.7）。每个会话接入时会在状态文件里写明自己的环境（工具和版本、模型、机器标签、沙箱和网络权限、能跑什么不能跑什么），并通知所有人；不写主机名、IP 和任何密钥。`scripts/` 里的脚本只依赖 git 和 POSIX sh。

完整内容以英文的 [PROTOCOL.md](PROTOCOL.md) 为准。许可证：MIT。
