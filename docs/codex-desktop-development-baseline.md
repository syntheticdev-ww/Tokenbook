# Tokenbook × Codex 桌面端开发前置条件基线

> 历史探测记录：本文保留 2026-09-09 的环境与能力证据，不代表后续版本已验证。产品方案现以 [产品与开发设计 v0.4](Tokenbook_产品与开发设计_v0.4.md) 为准：采用独立 Godot 原生游戏窗口与可选 Codex 插件。下文的 iframe 主界面建议及相关验收门槛已被替代；账户总量不再作为本机奖励对账依据，Hook 状态和版本支持也须按新稿边界重新验证。

更新时间：2026-09-09
验证环境：macOS 26.4（arm64）、ChatGPT/Codex Desktop 26.903.61454、内置 Codex CLI 0.153.4

## 1. 结论

Tokenbook 可以基于 Codex 桌面端开发，但应采用“Codex 桌面端作为唯一工作入口，Tokenbook 作为本地插件与游戏运行时”的结构，而不是重新实现一个 Codex 客户端。

推荐形态：

1. Codex 桌面端继续负责对话、任务、审批、账号登录和工作区。
2. Tokenbook 插件提供 MCP 工具、对话内游戏 UI 和经过用户信任的生命周期 Hooks。
3. 一个本地 Tokenbook 运行时负责模拟、SQLite 状态、奖励账本、幂等与崩溃恢复；UI 只是视图，不是计时器或权威状态源。
4. 对话内 iframe 负责“展开的书本/农场”界面；如果产品必须有始终置顶的小窗，再增加一个只显示游戏状态的伴随窗口。这个窗口不是自定义 Codex 客户端，也不接管 Codex 对话或审批。
5. Codex Pet 只能作为可选状态吉祥物。它的标准语义是 Running、Needs input、Ready、Blocked，不能代替完整农场游戏。

因此，MVP 的核心玩法、离线推进、任务状态映射和用量奖励均可实现。唯一需要明确接受的技术边界是：目前没有受支持的方式让外部进程直接附着到桌面端正在运行的私有 App Server；精确的“未缓存输入 + 输出”也不能只靠稳定的账户用量接口获得。

## 2. 当前机器已满足的基础条件

| 条件 | 当前状态 | 开发要求 |
| --- | --- | --- |
| macOS | 26.4，arm64 | 桌面端最低要求为 macOS 13 |
| Codex Desktop | 26.903.61454 | 开发期间固定记录桌面端与 CLI 版本 |
| 内置 Codex CLI | 0.153.4 | 优先调用应用内置或明确配置的 CLI，不假设全局版本一致 |
| Node.js | 24.18.0 | 插件 UI 构建建议 Node 18+ |
| Git | 2.50.1 | 已满足 |
| Codex 登录 | ChatGPT/Codex 服务登录可复用 | 稳定账户用量接口不要求另配 API Key；仅 API Key 登录不一定提供该接口 |
| 功能开关 | Hooks、Plugins、Apps 已启用 | Apps 列表仍包含实验性协议，不应成为核心运行依赖 |
| Git 提交邮箱 | 仓库级个人 GitHub noreply 邮箱 | 与游戏运行无关；不会把个人真实邮箱写进提交 |

## 3. 能力与边界矩阵

| 需求 | 判定 | 推荐实现 |
| --- | --- | --- |
| 继续使用 Codex 桌面端开发 | 支持 | 桌面端保持唯一工作入口 |
| 获取账户累计和每日 token | 稳定支持 | App Server `account/usage/read`，用于展示与对账 |
| 获取当前任务稳定的分项 token | 当前账号返回空 | 不把 `threadUsage` 当作必有字段 |
| 按“未缓存输入 + 输出”精确奖励 | 可实现，但依赖版本化适配 | 从本地 rollout 的数值记录提取，并以稳定账户总量做对账 |
| 实时任务开始/结束/中断 | 支持 | 插件 Hooks；崩溃后用 rollout/账本恢复 |
| 权限请求状态 | 支持 | `PermissionRequest` Hook 只更新状态，Tokenbook 永不代替用户批准 |
| 子任务/并行任务 | 支持但必须建模 | 用 session/thread/turn/response 多级 ID 去重，不能只靠“完成次数” |
| 在对话旁显示展开游戏 | 支持 | MCP App/UI iframe |
| 始终置顶紧凑游戏窗 | 桌面插件 UI 本身不能保证 | 可选本地伴随窗口，读取同一 SQLite 状态 |
| 用 Codex Pet 承载完整游戏 | 不支持 | 只把 Pet 当外观或任务状态提示 |
| 外部进程接入桌面端现有 App Server | 无受支持入口 | 不连接私有 socket/pipe；使用插件 MCP、Hooks 和独立 App Server 查询 |
| 依赖桌面端私有管道 | 禁止作为产品方案 | 不使用 `CODEX_APP_TOOLS_PIPE_PATH` 等内部桥接细节 |

## 4. 用量奖励的数据方案

设计稿中的口径在当前精细记录里成立：

```text
未缓存输入 = input_tokens - cached_input_tokens
灵感奖励基数 = 未缓存输入 + output_tokens
总记录量 = input_tokens + output_tokens
```

本机历史审计结果：

- 扫描 136 个 Codex 桌面会话文件，没有格式损坏行。
- 只有较新的 7 个会话包含 `token_usage_record` 精细记录，说明它不是可无条件依赖的长期公共格式。
- 这 7 个会话全部满足缓存、推理输出和总量关系，且按唯一 `response_id` 累加后全部等于最新线程累计值。
- 历史 CLI 版本横跨 0.142.5 到 0.153.4，因此生产适配器必须按版本识别并“失败关闭”，不能在未知格式下猜数。

生产实现应分两层：

1. 稳定层：用 `account/usage/read` 获取账户累计和每日桶，只做全局展示、连接起点和最终对账。它是账户级数据，不能天然归属于某个项目；每日桶的时区语义也不能替代 Tokenbook 自己的本地时间账本。
2. 精确层：对当前支持版本的本地 rollout 只提取 session、turn、response ID、时间和 token 数值。奖励账本以 `response_id` 为幂等键，稳定接口的变化不能再次发奖。

若精确层遇到未知 CLI 版本、缺字段、重复 ID 数值冲突或累计校验失败：停止新增奖励、保留原始数值校验摘要、提示需要更新适配器。不能退化为可能重复发奖的估算。

当前 M0 探针为了验证格式会把单个文件读入内存；它不是生产隐私实现。生产适配器应增量读取，只在行明确属于允许的元数据或 token 记录时解析，绝不持久化、打印或传输 prompt、代码、工具输入、完整回复与 `last_agent_message`。

## 5. 生命周期与离线推进

Hooks 负责低延迟状态，账本负责最终一致性：

```text
SessionStart / UserPromptSubmit
        ↓
任务运行中 ── PermissionRequest → 需要用户输入
        ↓
Stop / Interrupt / SessionEnd
        ↓
结算唯一 response → 写入奖励账本 → 推进游戏状态
```

需要考虑的事实：

- 后台 Hooks 最多可并行运行并可能乱序完成，事件必须有 ID 和时间戳，不能假设到达顺序。
- 项目 Hooks 只有在项目受信任、且具体 Hook 定义被用户信任后才运行。插件安装也不会自动信任 Hooks。
- transcript 路径可以存在，但格式不稳定且包含私密内容；Tokenbook 不应读取它来分析文字。
- 本机历史中有开始、完成、中断和仍未收敛的任务，崩溃、退出或当前进行中状态都必须通过超时与恢复规则结算。
- UI iframe 可能随对话切换而卸载，所以所有生产、远征和农作物推进都按“最后结算时间 + 当前时间”重算，不能依赖前端定时器持续存活。

建议最小事件载荷：

```json
{
  "schemaVersion": 1,
  "eventId": "...",
  "sessionId": "...",
  "threadId": "...",
  "turnId": "...",
  "eventType": "turn.started",
  "occurredAt": "2026-09-09T00:00:00Z"
}
```

不包含 prompt、代码、文件正文、工具参数或回复正文。

## 6. 插件与 UI 的开发前置条件

本地开发包应至少包含插件清单、MCP 服务定义、UI 资源和需要的 Hooks。开发流程为：

1. 从本地个人 marketplace 安装 Tokenbook 插件。
2. 在 Codex 中检查插件权限和 Hook 的准确命令定义，用户明确授信。
3. 安装或更新后开启一个新对话并启用插件；旧对话不能作为完整加载验证依据。
4. MCP 工具返回 `text/html;profile=mcp-app` UI 资源，在桌面端 iframe 中显示游戏。
5. SQLite 和运行时数据写入插件数据目录或 Application Support，不能写入 Git 仓库。
6. UI widget state 只保存临时视图状态；金币、作物、远征、奖励流水等权威数据全部由本地运行时持久化。

游戏 UI 不应依赖 Apps 目录接口。该接口当前为实验性且本机枚举耗时明显高于其他稳定接口；Tokenbook 自己的 MCP 插件加载与运行才是关键路径。

## 7. 隐私与本机权限

GitHub 的 noreply 邮箱只解决提交公开邮箱的问题，与 Codex 本机对话隐私是两件事。

当前检查发现：

- `~/.codex/auth.json` 与主要配置文件权限为仅本人读写。
- `~/.codex/ipc` 目录与 socket 权限较严格。
- 但 `~/.codex/sessions` 目录当前为 755，rollout 文件为 644；在共享 Mac 上，其他可遍历父目录且属于相应组的本地账号可能读到对话记录。

开发硬性规则：

- Tokenbook 的数据目录使用 700，SQLite、日志和账本文件使用 600。
- 日志默认只记录事件 ID、版本、数值、错误码和时间，不记录用户文字或文件路径。
- 不上传 rollout、账号用量、游戏账本或 Codex 身份信息；未来如加云同步，必须单独获得明确同意并设计加密与删除机制。
- 不扩大 `~/.codex` 现有权限。是否收紧 Codex 原目录权限应在单独验证桌面端兼容后由用户决定，不在 Tokenbook 安装时静默修改。
- 测试夹具只能使用伪造 prompt 哨兵，确保输出中不会泄漏内容。

## 8. 开始正式玩法开发前的硬门槛

以下验证通过后，才能把桌面集成标记为可发布：

- 在一个新 Codex 对话中完成本地插件安装、MCP 工具调用和 iframe UI 渲染的端到端冒烟测试。
- 验证 `Stop`、`Interrupt`、`PermissionRequest`、`SessionEnd` 和子任务 Hooks；验证未授信时能清楚降级而不是丢奖励。
- 同时运行多个任务，验证乱序事件、重复事件、响应重试和单写者 SQLite 事务。
- 在任务进行中强制退出并重启桌面端，验证孤儿任务恢复和奖励不重复。
- 跨本地午夜、修改时区并等待账户用量后台延迟，验证日账本不依赖服务端桶的未声明时区。
- 升级一次 Codex Desktop，验证未知 CLI 版本会停止精确发奖并提示兼容性检查。
- 断网、账号退出、App Server 查询超时下，游戏可离线运行且不会制造假用量。

其中第一项必须在“安装插件后新开的对话”中进行，无法由当前已经运行的对话证明。其余可在仓库测试与后续集成测试中自动化。

## 9. 当前 M0 证据

仓库已包含以下只读探针：

- `npm run probe:account`：验证稳定账户用量接口。
- `npm run probe:desktop`：验证账户、任务、Hooks、插件和实验性 Apps 能力；输出经过脱敏，不显示对话标题、预览或 Hook 命令。
- `npm run probe:codex`：验证当前项目最新桌面 rollout 的精确 token 语义。
- `npm run audit:codex`：跨本机历史会话做结构与累计一致性审计。
- `npm test`：验证奖励公式、重复响应去重、冲突拒绝和内容哨兵不进入摘要。

当前测试：3/3 通过；历史精细用量文件：7/7 语义与累计校验通过。

## 10. 官方依据

- [Codex App Server](https://learn.chatgpt.com/docs/app-server)
- [Codex Hooks](https://learn.chatgpt.com/docs/hooks)
- [Codex Pets](https://learn.chatgpt.com/docs/pets)
- [Plugin UI / MCP Apps](https://developers.openai.com/plugins/build/chatgpt-ui)
- [Plugin packaging](https://developers.openai.com/plugins/build/plugins)
- [Connect and test a plugin](https://developers.openai.com/plugins/deploy/connect-chatgpt)
