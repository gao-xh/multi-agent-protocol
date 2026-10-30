# MAP: Multi-Agent Protocol（多 agent 协作协议）

[English](README.md) · [Changelog](CHANGELOG.md)

**让 Claude Code、Codex 等编程 agent 组成一个团队，一起开发同一个项目：只用 git，任何工具、任何机器、任何模型。**

在同一个仓库里同时跑几个 agent，翻车的方式就那么几种：两个会话改同一个工作目录，两个 agent 抢着做同一件事，新开的会话不知道上一个会话查到了什么，所谓"做完了"其实只是"推了点代码"。MAP 是一套协议加几个 POSIX shell 脚本：agent 之间通过 git 分支上的书面交接单协作，不同工具里的 agent 因此可以分工、交接、互相审查，再一起发布。它是架在各个 agent harness 之上的协调和决策层：工具由 harness 去跑，谁做什么、什么能合并、什么要你批准，由 MAP 来定。

<p align="center">
  <img src="docs/images/map-flow.svg" width="760"
       alt="你把目标告诉 lead。lead 把工作分给 data 线（Codex）和 fit 线（Claude Code）；data 把某个具体 commit 上的读取代码交给 fit。lead 把这个 commit 交给没参与开发的审查者，审查者把结果报给 lead。fit 提出发布申请，并注明是哪次审查；发布角色在这个 commit 上把检查跑通后合进 main，再回报给 lead。打 tag 和公开发布由你批准。每一根实线箭头都是协调分支上的一个文件。">
</p>

**快速开始：** 对打算让它当 lead 的 agent 说一句"用 https://github.com/gao-xh/multi-agent-protocol 配置这个项目"（[详细步骤](#开始使用)）。
**演示：** [map-demo](https://github.com/gao-xh/map-demo) 一条命令就能把下面的流程完整跑一遍；[75 秒的视频](https://github.com/gao-xh/map-demo/blob/main/docs/runs/2026-10-29-real-agents-zh.mp4)记录了 Claude Code 和 Codex 的一次真实运行。

https://github.com/user-attachments/assets/a0283c93-604e-49ec-8a53-b35d3cb21e5f

## 一个功能是怎么做出来的

1. 你告诉 lead 想做什么。lead 把工作拆成几条**开发线**：每条线由一个 agent 负责，有自己的分支和负责的代码范围。lead 给每条线发一份交接单（`handover`），写清目标、已知情况和怎样才算做完。
2. 每条线动手前先**认领**任务，免得两个 agent 撞车，然后在自己的工作目录里开发。
3. 以演示项目为例：`data` 线（Codex）写好读取测量文件的代码，交给 `fit` 线（Claude Code），交接单里写明分支、具体是哪个 commit、跑了哪些测试；`fit` 接着在上面写衰减拟合。
4. lead 找一个没参与开发的 agent 来**审查**这个 commit，审查者把问题按轻重排好、附上证据，报给 lead。
5. 开发线提出发布申请（`release-request`），注明是哪次审查。**发布角色**先在这个 commit 上把检查跑通，才把它合进 `main`，然后回报结果；打 tag 和公开发布要等你点头。
6. 会话结束或上下文用完时，会留下一份 `transfer` 交接单；下一个会话不管用什么工具、在哪台机器上，都先核对每个分支的 SHA，再接着干。

在一次真实运行中，Codex 作为审查者发现了 Claude Code 写的拟合有 bug（时间轴不从零开始时会失败）；Claude Code 修好后，Codex 批准了新的 commit，然后才发布。[查看这次运行的时间线](https://github.com/gao-xh/map-demo/blob/main/docs/runs/2026-10-29-real-agents.html)。

你只需要回答问题、做批准，其余交给 agent；你不在时冒出来的问题，会先放在 lead 那里，等你回来一起问。

## 协调分支上有什么

图里每一根实线箭头，都对应你自己仓库里 `coordination` 分支上的一个文件：

```
coordination
├── status/fit.md                                   谁在做什么、在什么环境里
├── claims/decay-fit.md                             哪个任务被谁认领了、到什么时候
├── messages/20261029T023533Z_data_handover.md      一条消息一个文件，推送后不再改
└── decisions/<日期>_<主题>.md                       你的决定，用你的原话记下来
```

<details>
<summary>交接单长这样（取自演示）</summary>

```
type: handover
from: data
to: fit
refs: messages/20261029T023527Z_lead_handover.md

## Goal
Fit a decay time with its uncertainty for every run, using the new loader.

## Current state
- Branch: data/loader at 6bb4ab2c1681e262d600d7e4afa1ba7aceb94886 (pushed: yes)
- Code changed so far: src/decay_fit/load.py, tests/test_load.py

## Confirmed facts
- load_runs("data/sample") returns one Run per file with arrays t_s, signal, sigma
- Rows with missing values are dropped; tested with tests/test_load.py (7 passed)

## Suggested approach
- Branch from data/loader at the SHA above

## Blockers and decisions needed
- none

## Done means
- Tests: tests/test_fit.py recovers the known decay time of data/sample/run-03.csv
- Report back with: branch, SHA, checks run and results
```

</details>

## 为什么有这些规则

| 不这样做会出什么事 | MAP 的做法 |
| --- | --- |
| 一个会话跑测试时，读到了另一个会话写了一半的文件 | 一个工作目录只允许一个会话写，每条线一个分支 |
| 两个 agent 做了同一个任务 | 动手前先认领，认领有过期时间 |
| 新会话把上一个会话查清楚的事又查一遍，或者把失败过的办法又试一遍 | 留下书面的交接单或 `transfer`：写明 SHA、已确认的事实、下一步和试过不行的办法 |
| "做完了"其实只是"推了点代码" | "做完"指的是：一个已推送的 commit SHA，加上实际跑过的检查和结果 |
| 审查通过后又推了新代码，结果拿旧的审查结论就发布了 | 审查结论只对它写明的那个 commit 有效 |
| 某个 agent 说"负责人已经同意了" | 只有你本人能批准，别人转达的一律不算 |

表里每一行都是我们真遇到过的问题；完整的表见 [PROTOCOL.md](PROTOCOL.md#11-known-failure-modes)。

## 亮点

- **跨工具、跨机器组成一个团队。** Claude Code、Codex、OpenCode、Copilot、Gemini CLI、Cursor、Aider 都能加入，靠的只是 git：除了你的 git 远端，不需要别的服务器或服务，脚本只依赖 `git` 和 `sh`；Claude Code 和 Codex 还有插件，提供各个角色的技能。MAP 也不需要调度器，用普通终端会话、任何会话管理工具，或者自带的可选 runner 都行。
- **交接不随会话消失。** 哪怕只有一个 agent，`transfer` 也能让下一个会话（换个工具、换台机器都行）从核对过的事实接着做，不用靠手动粘贴的总结。
- **不用一直盯着。** 新消息不用你转达：可选的 runner 收到消息会启动一个无界面的 agent（Claude Code、Codex、OpenCode），Claude Code 的 monitor 会提醒已经打开的会话，还可以再接上即时通知。
- **始终由你拍板。** 批准只能来自你本人：当面说，或者用你的 SSH 密钥签名；长期授权也按你的原话记下适用范围。
- **跨项目沟通。** 其他项目的 agent（比如实现了这套协议的下游工具）可以登记为外部通信方，读你的协调分支，给你的 lead 发问题和兼容性通知；它不会改动你项目里的任何东西，两个项目各由自己的负责人批准。

## 背后的文件

- **[PROTOCOL.md](PROTOCOL.md)**：协议正文（英文，采用 RFC 2119 的措辞），一切以它为准。
- **[docs/how-it-works.zh-CN.md](docs/how-it-works.zh-CN.md)**：各个角色、agent 怎样通过协调分支沟通、怎么升级（[英文版](docs/how-it-works.md)里还有脚本命令）。
- **[UPGRADING.md](UPGRADING.md)**：怎么查看当前版本，多个会话同时在用时怎么升级项目。
- **[scripts/](scripts/)**：协调分支用的 POSIX `sh` 脚本，只依赖 git。
- **[templates/](templates/)**：各类消息的模板。
- **[adapters/](adapters/)**：`AGENTS.md` 规则片段、适用于任何 agent 的配置和加入说明，以及各个工具的使用说明。
- **Claude Code 插件**：角色技能（`lead`、`line`、`release`、`liaison`、`relay`、`coordinate`），以及 `builder`、`reviewer` 两个子 agent。

## 开始使用

> **给 AI agent：** 如果有人给你这个链接，让你在项目里配置这套协议，请按 [adapters/BOOTSTRAP.md](adapters/BOOTSTRAP.md) 一步步做（纯文本：<https://raw.githubusercontent.com/gao-xh/multi-agent-protocol/main/adapters/BOOTSTRAP.md>）。它会告诉你先检查什么、要问负责人什么，以及哪些改动要等负责人答复后才能做。如果项目已经配置好，你只是要加入，请改按 [adapters/JOIN.md](adapters/JOIN.md) 做。

### 1. 配置项目

在你的项目里，对打算当 lead 的 agent（Claude Code、Codex 或其他）说一句"用 https://github.com/gao-xh/multi-agent-protocol 配置这个项目"。它会照着 [adapters/BOOTSTRAP.md](adapters/BOOTSTRAP.md) 一步步来：

1. 先看仓库、项目的检查命令和自己的运行环境，这一步不改任何东西；
2. 问你三件事：配置要看多细、这是哪一类项目（[任务模式](adapters/modes.md)）、有哪些 agent 参与；
3. 把所有设置列成一页带编号的方案，每一项注明是查到的、建议的还是假定的；你回"同意"，或者按编号修改；
4. 写入前先把规则片段给你看，再写进 `AGENTS.md`，建好协调分支，自己以 lead 身份加入；
5. 给其他每个 agent 准备一张启动卡片：在哪里打开、贴什么话。

刚开始可以小规模：一个负责人、两三个会话，用几条核心规则就够了；会话、机器、工具或负责人多起来以后，再加上协调分支和发布角色（见 [PROTOCOL.md 12.1](PROTOCOL.md#121-profiles)）。MAP 是为一位负责人和不太多的并行会话设计的：会话多了以后，先成为瓶颈的是审查、只有一个的 `release-main` 发布队列和负责人的批准，而不是文件。worktree 只隔离文件，不隔离端口和已安装的环境（PROTOCOL.md 4 的"Runtime isolation"）。

### 2. 加入其他 agent

在每个 agent 自己的 checkout（工作目录）里打开它，对它说"加入这个项目"（已经知道它负责哪条线的话，就加一句"作为 `api` 线"）。lead 写进 `AGENTS.md` 的规则会引导它去读 [adapters/JOIN.md](adapters/JOIN.md)，它会照着做：读取项目设置、检查自己的环境、只配置它自己，然后向团队报到，通常不用问你任何问题。每个 agent 在哪里打开，lead 给的启动卡片上都写着。角色表里还没有的 agent，要经你批准才能加入。以后想改某项设置，把 [adapters/CHANGE.md](adapters/CHANGE.md) 交给 lead 就行。

### 3. Claude Code 插件（可选）

```text
/plugin marketplace add gao-xh/multi-agent-protocol
/plugin install multi-agent-protocol@gao-xh-agents
/multi-agent-protocol:coordinate set-line api      # 每个工作目录设置一次
```

每个会话启动时带上自己的角色（`/multi-agent-protocol:lead`、`/multi-agent-protocol:line api`、`/multi-agent-protocol:release`）；`/multi-agent-protocol:coordinate` 负责收件箱、消息和认领，`builder` 和 `reviewer` 两个子 agent 可以接手委派出去的工作。设好线名以后，每次开会话都会先列出未读消息和认领情况，有新消息时 monitor 会提醒。插件一共有六个技能：`lead`、`line`、`release`、`liaison`（替负责人传话）、`relay`（替其他会话在本机执行命令）和 `coordinate`。

### Codex 插件（可选）

这个仓库同时也是一个 Codex 插件，提供角色技能，还可以在会话开始时列出收件箱：先运行 `codex plugin marketplace add <克隆的路径>`，再运行 `codex plugin add multi-agent-protocol@gao-xh-map-codex`（见 [codex/README.md](codex/README.md)）。

### 4. 远程工作（可选）

当你或 lead 不在存放数据、运行环境的那台电脑旁边时，那台电脑上的 agent 照样可以通过协调分支接活（任务模式 15）。`scripts/runner.sh` 收到新消息就启动一个无界面的 agent（Claude Code、Codex、OpenCode）；`relay` 在本机执行其他会话要求的命令；你也可以在另一台电脑上用 `scripts/remote.sh` 直接遥控 relay，命令用 SSH 密钥签名，项目允许的话也可以不签。relay 缺权限时，`remote.sh` 会列出它需要的规则，你按 `y` 才放行这一次。配置方法见 [adapters/remote.md](adapters/remote.md)。

### 5. 手动安装

```sh
git clone https://github.com/gao-xh/multi-agent-protocol
multi-agent-protocol/scripts/install.sh path/to/your-project   # 以后再运行一次就能更新
```

这会把协议、脚本和模板复制到项目的 `tools/multi-agent-protocol/` 下，不动其他文件。然后把规则片段贴进 `AGENTS.md`（Claude Code 用的 `CLAUDE.md` 指向它即可），填好角色表，运行 `tools/multi-agent-protocol/scripts/init-coordination.sh`。

### 参考

- 各类项目及各自需要的设置：[adapters/modes.md](adapters/modes.md)。
- 各个 agent 工具（怎么读规则、能不能推送、怎么唤醒）：[adapters/README.md](adapters/README.md)，以及 [Codex](adapters/codex.md)、[OpenCode](adapters/opencode.md)、[Aider](adapters/aider.md)、[GitHub Copilot](adapters/copilot.md)、[Gemini CLI](adapters/gemini.md)、[Cursor](adapters/cursor.md) 的说明。
- Windows、macOS、Linux 和各家 git 托管平台：[adapters/platforms.md](adapters/platforms.md)。
- 用较小或较便宜的模型：[adapters/compact-rules.md](adapters/compact-rules.md)。
- 升级项目：[UPGRADING.md](UPGRADING.md)。

## 和常见标准的关系

MAP 建立在常见的 agent 标准之上：它会用到这些标准，但不取代其中任何一个。

| 层次 | 管什么 | 例子 |
| --- | --- | --- |
| 单个 agent 的规则 | agent 每次开会话时读的规则 | `AGENTS.md`、`CLAUDE.md`：MAP 的规则片段就写在这里 |
| 工具和数据 | agent 怎样调用工具、读取数据 | MCP |
| agent 之间直接通信 | agent 互相调用时的消息格式 | A2A、ACP |
| **多个 agent 与负责人之间的协作** | 谁能批准什么、谁在哪里干活、怎么交接、改动怎么进入主分支 | **MAP**，只用 git |

MAP 项目里的 agent 照样可以用 MCP 服务器，也可以用 A2A 通信；MAP 只要求交接、批准和发布遵守它的规则，并经过协调分支。

## 测试

```sh
tests/test-scripts.sh        # 用 sh
tests/test-scripts.sh dash   # 换另一个 POSIX shell
```

测试会创建一个临时仓库，带本地裸远端、两个克隆和并发推送，逐个检查每个脚本，包括 doctor 能不能发现被改动过的消息。CI（[.github/workflows/check.yml](.github/workflows/check.yml)）在 Linux（dash 和 bash）和 macOS 上运行这些测试，另外还跑 ShellCheck 和 `claude plugin validate --strict`。

## 许可证

[MIT](LICENSE) © 2026 Xuehan Gao
