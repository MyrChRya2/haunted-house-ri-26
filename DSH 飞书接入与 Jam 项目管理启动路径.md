# DSH 飞书接入与 Jam 项目管理启动路径

> 本文档供 Agent 读取并执行。前置条件：DSH 已部署完成，`dsh` 命令可用。
> **本文件已按 2026-09-22 的实际执行结果修订**：原稿中与实际不符的步骤已标注并改正，
> 修订理由见文末「第 9 节 · 与原稿的差异」。
>
> 当前状态：**步骤 1–5 已完成，步骤 6（重启 + 扫码）待用户执行。**

---

## 0. 最终形态（一图看懂）

```
飞书（私聊 / 群聊 / 话题）
      │  流式富卡片 · 一键审批 · 费用计量
      ▼
dsh-feishu-channel 插件（web profile）
      │  每个聊天映射一个独立 DSH Agent 会话
      │  cwd   = D:\Fox_n\!PROJECTS\#teamwork\FirstProject
      │  preset = jam-manager          ← 专门为 Jam 复制的项目管理 Agent
      ▼
「Game Jam 项目管理」Agent  ←── 只在这个工作区里读写
      │
      ├─ project-management skill（方法论：开场审查 / 收尾日志 / 决策 / Bug / 索引 / 提交）
      ├─ PROJECT_INDEX.md（本项目唯一配置入口，细节全在这里）
      └─ team-comms 团队接口（已挂载；当前队里只有自己，未来加人即可用）
```

**与长期项目（EndlessRegret）的关系：完全隔离。**
两者 cwd 不同 → team-comms 天然不会互相投递；`jam-manager` 是复制体，改动不影响原「项目管理」preset。

---

## 1. 安装飞书通道插件 ✅ 已完成

**原稿命令（本机失败）**：

```bash
dsh plugin --profile web add github:whoisjiahao/dsh-feishu-channel
```

**失败原因**：本机 git 全局配置了 `socks5://127.0.0.1:7890` 代理，而该代理当时未运行，
`git ls-remote` 连不上 GitHub（PowerShell 直连却正常）。这是**环境问题，不是插件问题**。

**实际采用的命令（官方 Release 包，绕开 git）**：

```powershell
# 1) 下载 Release 资产（直连 HTTPS，不走 git）
Invoke-WebRequest -Uri "https://github.com/whoisjiahao/dsh-feishu-channel/releases/download/v0.9.0/dsh-feishu-channel-0.9.0.tgz" `
  -OutFile "$env:USERPROFILE\.dsh\plugins\artifacts\dsh-feishu-channel-0.9.0.tgz"

# 2) 从本地 tgz 安装
dsh plugin --profile web add "$env:USERPROFILE\.dsh\plugins\artifacts\dsh-feishu-channel-0.9.0.tgz"
```

> tgz 特意存在 `~/.dsh/plugins/artifacts/` 而不是临时目录：profile 的 `package.json` 记的是
> `file:` 绝对路径，放临时目录会因清理而让后续 `pnpm install` 失败。

**安装中会遇到 `ERR_PNPM_IGNORED_BUILDS (protobufjs)`** —— 这是插件的依赖链
（feishu-channel → `@larksuite/channel` → protobufjs）触发的 pnpm 构建门禁，属预期现象。
按 pnpm 提示把 profile 的 `pnpm-workspace.yaml` 里那行占位改掉即可：

```yaml
# ~/.dsh/profiles/web/pnpm-workspace.yaml
allowBuilds:
  protobufjs: true      # 原为 "set this to true or false"
```

然后重跑安装命令。protobufjs 的 postinstall 只打印版本提示。

**若将来想恢复 git 安装方式**：先启动代理客户端（让 7890 可用），或临时清掉 git 代理：
`git config --global --unset http.proxy`。

**完成标志**（已验证）：

- `~/.dsh/profiles/web/package.json` → `dependencies` 含 `dsh-feishu-channel`
- 同文件 → `dsh.profile.bundles` 含 `"dsh-feishu-channel"`
- `node -e "console.log(require(process.env.USERPROFILE+'/.dsh/profiles/web/node_modules/dsh-feishu-channel/package.json').version)"` → `0.9.0`

---

## 2. 配置飞书 Agent 的身份与工作目录 ✅ 已完成

这一步原稿没有，但**是本方案的关键**。飞书插件的两个配置项决定了它是谁、在哪工作：

| 配置项 | 默认值 | 本项目设为 | 为什么必须改 |
|--------|--------|-----------|-------------|
| `preset` | 宿主默认 preset | `jam-manager` | 不改的话飞书 Agent 不属于任何团队角色，`team_*` 工具调用会直接报"本会话不属于团队" |
| `cwd` | `~/.dsh-feishu` | `D:\Fox_n\!PROJECTS\#teamwork\FirstProject` | team-comms **按 cwd 分队**；不改的话飞书 Agent 与项目里的角色永远互相投递不到，文档也会写到那个隐藏目录里 |

写进 `~/.dsh/profiles/web/cordis.patch.yml`：

```yaml
- id: feishu-channel
  name: dsh-feishu-channel
  config:
    cwd: 'D:\Fox_n\!PROJECTS\#teamwork\FirstProject'
    preset: jam-manager
    requireMention: true
```

> ⚠️ **补丁语义陷阱**：非 `insert` 的补丁项会**整个替换**目标行的 `config`
> （`applyEntryPatches` 里执行的是 `target[key] = value`），**不是深合并**。
> 所以必须把该行需要的每个键都列全，漏掉的键会变成 schema 默认值。
>
> 验证方法：`dsh --profile web --dump-config`，输出里应出现
> `# == dsh-feishu-channel, patched by C:\Users\RayChan\.dsh\profiles\web\cordis.patch.yml`，
> 且其下 `cwd` / `preset` 与预期一致。若显示 `patch: entry ... not found` 或 `name mismatch` 则补丁被跳过。

---

## 3. 新建 Jam 专用项目管理 preset ✅ 已完成

**决策**：单独**复制**一个项目管理 Agent，而不是复用长期项目的「项目管理」。
理由：两个项目必须隔离；且 Jam 结束后要把经验反哺回原 Agent，复制体是干净的试验田。

- **preset id**：`jam-manager`（显示名「Game Jam 项目管理」）
- **位置**：`~/.dsh/.agent-presets/jam-manager/`
- **来源**：由 `project-manager` 整目录复制，人设改写为「独立 Jam 工作区 + 方法论」
- **保留**：`project-management` skill 全套能力 + team-comms 团队接口
- **剥离**：所有长期项目专属内容（`.dsh/team/TEAM.md` 引用、五人固定名册、「站会/值班室」约定）

人设只写方法论，**项目细节一律以工作区 `PROJECT_INDEX.md` 为准** ——
这样同一个 preset 可以复用到下一次 Jam。

**挂载校验（已通过）**：通过动态 Cordis 插件调用宿主 `agentPresets` 服务：

```js
await presets.standingKeyFor('jam-manager')
```

结果：`OK preset id="jam-manager" trust=user path=C:\Users\RayChan\.dsh\.agent-presets\jam-manager\agent.cordis.yml`
—— 组合可正常挂载。这是权威校验手段（比"文件能解析成 YAML"强得多）。

---

## 4. 保留团队接口 ✅ 已完成

在 `~/.dsh/plugins/team-comms.mjs` 的角色表里**增量**加了一行（原有 5 个角色定义一字未动）：

```js
'jam-manager': 'Jam 项目管理',
```

- 该文件是 team-comms 的**唯一真本**，各 preset 目录下的同名文件只是一行 re-export 转接头。
- 用「Jam 项目管理」而不是复用「项目管理」，是为了即使两者落在同一 cwd 也不会撞角色
  （同角色之间 team-comms 会拒绝投递并提示"不要发给自己"）。
- **当前队里只有本 Agent 一个角色**，`team_status()` 会显示只有自己。这是预期状态，
  不代表故障；等以后把开发辅助/剧情设计等角色开进同一工作区，直投即可用。
- **对长期项目的唯一影响**：长期项目会话里 `team_status()` 的名册会多列一行
  `Jam 项目管理 — jam-manager — D:\...\FirstProject`（名册本来就跨 cwd 列出全部团队角色）。
  若不想看到，把上面那行删掉即可，其余功能不受影响。

---

## 5. Jam 项目文档骨架 ✅ 已完成

Jam 项目管理 Agent 的第一句话就是"读 `PROJECT_INDEX.md`"，所以骨架必须先落地。

已创建并提交（`master` 分支，2 个提交）：

| 文件 | 作用 |
|------|------|
| `PROJECT_INDEX.md` | 项目唯一配置入口；含**队员分工表**与**多人协作附加约定** |
| `docs/GDD.md` | 设计文档骨架（含"范围控制"与"待决策清单"） |
| `docs/ROADMAP.md` | 里程碑 + 带**归属**列的任务表 + 决策记录 + Bug 跟踪 |
| `docs/devlog/TEMPLATE.md` | 每日日志模板 |
| `docs/devlog/2026-09-22.md` | 本次搭建的日志（含全部决策与踩坑） |
| `.gitignore` / `.gitattributes` | 忽略规则（引擎段待定后裁剪）+ 换行符统一 |

> ⚠️ **`PROJECT_INDEX.md` 里多处是 `⚠️ 待填写` 占位**：Jam 名称、截止时间、主题、搭档分工、
> 引擎与目录结构。这些只有你知道，请尽快补上——它们是 Agent 做时间盒取舍的依据。

---

## 6. 重启 DSH Web 并扫码 ✅ 已完成

> **Agent 无法代为完成这一步**：插件配置**只在启动时读取一次**，必须重启；
> 而重启会终止当前正在跑这个会话的 DSH 进程。扫码也必须由人完成。

```powershell
# 1) 在终端里停掉当前 dsh web（当前监听 127.0.0.1:3080 的那个进程）
# 2) 重新启动
dsh web
```

启动后终端应出现：

```
feishu-channel: 请用飞书扫码创建应用…
```

**用飞书 App 扫描二维码**，确认创建应用。凭据会自动持久化，以后启动直连、无需再扫。

再往后启动日志应出现授权声明行（确认配置已生效）：

```
feishu-channel: direct messages: anyone the app is visible to (narrow with senderAllowlist); groups: ...
```

> 若已有企业应用凭据，也可跳过扫码，把 `appId` / `appSecret` 直接写进上面第 2 节的 `config`。

---

## 7. 验证连通性 ⏳ 待用户执行

> ⚠️ **前置条件：先把机器人拉进群**（群设置 → 群机器人 → 添加机器人）。
> 2026-09-22 查过：机器人当时**不在任何群里**（`GET /im/v1/chats` 返回 0 条），
> 所以在此之前 @ 它不会有任何反应。

在飞书群里 @ 机器人发任意消息。

**预期结果**：

1. 机器人的回复以**流式富卡片**呈现：加载中实时步骤 → 结论优先正文 → 失败可重试。
2. **Agent 应自称「Game Jam 项目管理」**。这是验证 `preset` 配置生效的关键信号；
   如果它表现成一个通用编码 Agent，说明 `preset` 没生效，检查第 2 节的补丁是否被跳过。
3. 展开卡片详情应看到 `model / input tokens / output tokens / cost / context`。
4. 让它回答"我的工作目录是哪里" —— 应答出 Jam 项目路径，而不是 `~/.dsh-feishu`。
5. 让它说"审查进度" —— 应触发 session-start 流程，读 `PROJECT_INDEX.md` 并给出进度报告。

**若没反应**：

- 看 DSH 终端有没有 `feishu-channel:` 开头的错误行。
- 群聊默认要求 @（`requireMention: true`）。
- 私聊受 `senderAllowlist` 控制；默认空 = 应用可见范围内的人都能私聊。

---

## 8. 在飞书中做 Jam 项目管理

### 可用命令

| 命令 | 作用 |
|------|------|
| `/new` / `/reset` | 新建 / 重置当前会话 |
| `/stop` | 停止当前任务 |
| `/model` | 查看或切换当前会话模型 |
| `/effort` | 查看或调整推理强度 |
| `/help` | 列出可用命令（**权威清单以此为准**） |

> 直接发送裸命令会弹出**交互卡片**（下拉框 / 输入框 / 确认按钮），不必记参数。
> 其余 `/xxx` 来自 DSH 宿主命令运行时，同样走交互卡片流程。
>
> 📌 原稿列了 `/status` 和 `/cd <项目名>` —— 这两个在插件 README 的命令表中**没有**，
> 未经验证。请以 `/help` 的实际输出为准。切换工作区目前只能通过改配置 + 重启。

### 日常节奏（由 project-management skill 驱动）

| 你说 | Agent 做什么 |
|------|-------------|
| "审查进度" / "开始" | 读 PROJECT_INDEX → `git log`/`git status` → 读 GDD/ROADMAP → 核对文档与代码一致性 → 输出进度报告 + 今日建议 |
| "记录决策" + 内容 | 方向性决策先落当日 devlog，再同步 ROADMAP/GDD |
| "发现bug" / "修复了bug" | 登记 / 关闭 ROADMAP 的 Bug 跟踪表 |
| "同步索引" | 路径或结构变更后更新 `PROJECT_INDEX.md` |
| "提交代码" | 按 `<type>: <subject>` 规范小步提交 |
| "今天任务已结束" | 读 TEMPLATE.md 生成当日 devlog |

### 审批

- Agent 需要审批工具调用时，飞书侧发**交互卡片**，点「允许 / 拒绝」即可。
- 默认禁用 `ask_user_question` 和 `exit_plan_mode` —— 它们的答案到不了聊天窗口，
  只会挂起到超时。禁用后 Agent 会改用文字提问、文字给计划。

### 多 Agent（未来）

当前队里只有「Jam 项目管理」一个角色。想拉人组队时：在**同一个工作区**
（cwd 必须是 `D:\Fox_n\!PROJECTS\#teamwork\FirstProject`）另开一个会话，
用已有的团队 preset（`dev-coder` / `story-writer` 等）启动即可，team-comms 会自动认队。

`subagent` / `subagent_fork` / `workflow` 仍然可用，但定位是**一次性并行任务**
（互不干扰的子任务、批量同质任务），不是常驻角色 —— 它们没有跨会话记忆、
不落盘、不参与决策队列。**不要**用它们替代 team-comms。

### 群聊接入方式

- **把机器人拉进群**（群设置 → 群机器人 → 添加机器人）。
- `requireMention: true` 已是当前配置，**群聊必须 @ 才响应**，@ 即用，无需改配置。
- `groupAllowlist` 目前为空 = 机器人所在的任何群都能用。机器人只在你这个群里，
  所以实际等价于只有你们能用；想显式收窄可填该群的 `oc_...` id。
- ⚠️ **一个飞书聊天 = 一个独立 Agent 会话**。所以请**统一只用那个群**：
  如果你私下 DM 机器人、搭档也私下 DM，会产生**两个同角色的「Jam 项目管理」Agent**
  —— 它们会并发改同一批文档和 `decisions.md`，而且 team-comms 拒绝同角色互投。
  用群 = 两人驱动**同一个** Agent，这才是双人 Jam 该有的形态。

### 多维表格（Jam 项目总表）

飞书通道插件只做**对话**，不做多维表格。为此单独写了一个插件
`~/.dsh/plugins/feishu-bitable.mjs`，**只挂在 `jam-manager` 上**（长期项目的 preset 不受影响）。

四个工具：

| 工具 | 作用 |
|------|------|
| `bitable_setup` | 幂等建立「Jam 项目总表」：一块多维表格，内含**任务表 / Bug 表 / 决策表**；返回链接 |
| `bitable_add` | 往某张表加一条记录 |
| `bitable_update` | 改一条记录（只改传入的字段） |
| `bitable_list` | 列出记录，顺带拿 `record_id` |

设计要点：

- **凭据不重复配**：从宿主 `settings` 的 `feishu-channel` 命名空间读 —— 就是扫码落盘的那一份。
- **状态跟项目走**：`app_token` 与各表 id 记在 `<工作目录>/.dsh/bitable.json`。
- **状态/严重度用单选字段**：工具参数带 enum，模型写不出 `"doing"` 这种值 —— 文本字段早筛就废了。
- 三张表与 `docs/ROADMAP.md` 是**镜像关系**：对话里写文档，群里看表。

**权限前置条件**（飞书自建应用默认没有）：

```
https://open.feishu.cn/app/cli_aa3b42f79df8dbe7/auth?q=bitable:app,drive:drive
```

开通 `bitable:app`（建表与读写）和 `drive:drive`（把表共享给群成员），
然后**必须到「版本管理与发布」发布一个新版本**，权限才生效 —— 这一步最容易漏。

> 为什么不用现成插件：[`dsh-feishu-mcp`](https://github.com/zhengjy01/dsh-feishu-mcp)
> （封装官方 lark-mcp，功能更全）要求 DSH ≥ 0.1.5-rc.1，本机是 **0.1.0-rc.6**，版本不符；
> [`dsh-feishu-reader`](https://github.com/Mr-SYGao/dsh-feishu-reader) 只读且面向 desktop
> profile。所以按"项目管理刚好需要的那三张表"写了这个窄工具面的插件。

---

## 9. 与原稿的差异（为什么改）

| # | 原稿 | 实际做法 | 理由 |
|---|------|---------|------|
| 1 | `dsh plugin add github:...` | Release tgz 本地安装 | 本机 git 走了未运行的 socks5 代理，git 通道不通 |
| 2 | 未提及 preset / cwd 配置 | 显式配 `preset: jam-manager` + `cwd: <Jam 工作区>` | 不改则 Agent 无团队身份、且与项目角色投递不到 |
| 3 | 第 5 节主张用 `subagent`/`workflow` 做编排核心 | 以 team-comms 常驻角色为准，subagent 仅作补充 | 常驻角色有跨会话记忆、落盘、离线补收、决策队列，是一次性 subagent 做不到的 |
| 4 | 第 5.4 建议装 `dsh-plugin-subagent-director` | **不装** | 它会引入第三套 preset→角色映射，与 team-comms 的角色表直接打架 |
| 5 | 假定飞书接入现有 Agent 团队 | 复制独立 Agent，与长期项目隔离 | 用户明确要求：Jam 是独立项目，不污染长期项目；经验日后再反哺 |
| 6 | 第 6 节列 `/status`、`/cd <项目名>` | 未验证，已标注以 `/help` 为准 | 插件 README 的命令表中没有这两个 |
| 7 | 未提及重启时机 | 明确"改配置必须重启，且会中断当前会话" | 配置只在启动时读一次 |
| 8 | 未做项目骨架 | 创建 PROJECT_INDEX/GDD/ROADMAP/devlog | Agent 开工第一句就是读 PROJECT_INDEX |

---

## 10. 快速启动清单

- [x] 安装 `dsh-feishu-channel@0.9.0` 到 web profile（tgz 路径）
- [x] 放行 `protobufjs` 构建门禁
- [x] 新建 `jam-manager` preset 并挂载校验通过
- [x] team-comms 增量登记「Jam 项目管理」角色
- [x] 配置飞书通道 `cwd` + `preset`，`--dump-config` 验证补丁生效
- [x] Jam 项目文档骨架 + `git init` + 首次提交
- [x] **重启 `dsh web`**（12:05，新 PID 936）
- [x] **飞书扫码创建应用**（凭据已落盘 `settings.yaml`，长连接已建立）
- [x] 写 `feishu-bitable` 插件（4 个工具，逻辑已冒烟测试）+ 挂载校验通过
- [ ] **把机器人拉进群**（群设置 → 群机器人 → 添加机器人）
- [ ] 群里 @ 机器人发消息验证：Agent 自称「Game Jam 项目管理」、cwd 正确
- [ ] **开通多维表格权限并发布新版本**，重启后验证 `bitable_setup`
- [ ] 填写 `PROJECT_INDEX.md` 的 Jam 信息与搭档分工
- [ ] 确定引擎与目录结构，同步 `PROJECT_INDEX.md` 第三节并裁剪 `.gitignore`
- [ ] **收紧飞书安全配置**（见下）
- [ ] Jam 结束后：导出飞书记录与 DSH 日志复盘，把经验反哺回 `project-manager` preset

---

## 11. 安全提醒（上线前必做）

本插件让飞书消息驱动一个**有文件读写与 shell 权限的 Agent**。当前是**默认放行**状态：

- `senderAllowlist` 空 → 任何"应用可见范围内"的人都能私聊并驱使这个 Agent
- `groupAllowlist` 空 → 任何把机器人拉进去的群都能用（需 @）
- `approvers` 空 → 能驱动该聊天的人都能点审批

**至少做一件事**：收紧应用的可见范围，或填上 `senderAllowlist` / `groupAllowlist` / `approvers`。
在一个双人 Jam 里，建议建一个**专用群**、把机器人拉进去、再填 `groupAllowlist`，
这样搭档和你都在群里协作，而外部人员无法触达。

---

## 12. 回滚

```powershell
# 卸载插件
dsh plugin --profile web remove dsh-feishu-channel
# 从 ~/.dsh/profiles/web/package.json 的 dsh.profile.bundles 数组里删掉 "dsh-feishu-channel"
# 从 ~/.dsh/profiles/web/cordis.patch.yml 删掉 feishu-channel 补丁项
# 重启 dsh web
```

只回滚 preset：删掉 `~/.dsh/.agent-presets/jam-manager/` 目录，并把 `cordis.patch.yml` 的
`preset` 改成 `project-manager` 或删掉该行。

只回滚团队接口：删掉 `~/.dsh/plugins/team-comms.mjs` 里的 `'jam-manager': 'Jam 项目管理',` 一行。

---

**Agent 注意事项：**

- 所有终端命令在 DSH 所在环境执行；路径为 Windows 形式。
- 重启 `dsh web` 与扫码**必须由用户完成**，Agent 不可代做。
- 改飞书插件配置后**必须重启**才生效（配置只在启动时读一次）。
- 改 `cordis.patch.yml` 后先跑 `dsh --profile web --dump-config` 确认补丁生效再重启。
- 改 preset 后用 `agentPresets.standingKeyFor(id)` 做挂载校验，别只看 YAML 能不能解析。
- 派发子任务时明确边界与产出格式；不要用 subagent 替代常驻团队角色。
