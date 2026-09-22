# 🔀 Git 工作流（异地双人 · Jam 期间）

> 对象：Ray 与 Illya。**Illya 是 git 新手——本文件只要求照做，不需要理解原理。**
> 三条铁律：`main` 永远可运行 · 小步提交 · **不 force push**。

---

## 一、开工前一次性准备

1. 装 **Godot**，版本与 Ray **完全一致**（版本不一致会出现"场景打不开"）。
2. 装 **GitHub Desktop**，登录你自己的 GitHub 账号。
3. 接受 Ray 发来的 collaborator 邀请（私有仓库只有被邀请的人能看）。
4. GitHub Desktop → `File → Clone repository` → 选本项目的仓库 → 选一个本地目录。
5. 提示：**不要**用 `New repository`，仓库已经存在，用 `Clone`。

---

## 二、每轮工作的四步（每天至少跑一次）

1. **Pull** —— GitHub Desktop 右上角 `Fetch origin`；若有更新，再点 `Pull origin`。
   **开工前必须先做这一步**，能避免九成冲突。
2. **改** —— 在 Godot 里改你负责的场景 / 脚本。别碰 `project.godot` 与 `export_presets.cfg`。
3. **Commit** —— 左侧会列出你改过的文件 → 勾选 → 左下角写一句话 → 点 `Commit to main`。
4. **Push** —— 右上角 `Push origin`。**不 push 等于没做**，Ray 那边看不到。

---

## 三、提交信息怎么写

格式：`类型: 简短描述`（前缀用英文小写，描述用中文英文都行）

| 前缀 | 什么时候用 | 例子 |
|------|-----------|------|
| `feat` | 新增功能 | `feat: 玩家移动与碰撞` |
| `fix` | 修 bug | `fix: 贴墙时角色卡住` |
| `art` | 美术资源（Ray） | `art: 复古 tile 集` |
| `audio` | 音频资源（Ray） | `audio: 跳跃音效` |
| `docs` | 文档 | `docs: 更新 GDD 核心循环` |
| `chore` | 杂项配置 | `chore: 调整重力参数` |

**别写** `update`、`改了一下`、`.` 这类信息 —— 一周后没人知道那次改了什么。

---

## 四、什么时候该提交

1. **一个能跑通的状态 = 一次提交**（按 F5 能正常运行再提交）。
2. **别攒超过半天** —— 攒得越久，冲突越大、越难修。
3. **每天至少 push 一次**，哪怕只做了一点。

---

## 五、绝对不要做的事

1. **不要 force push**（GitHub Desktop 中名为 `Force push`）—— 会覆盖别人的提交。真有需要，先在群里问 Ray。
2. **不要改 `project.godot`、`export_presets.cfg`** —— 工程配置归 Ray 独占，改错会让整个工程打不开。
3. **不要提交 `.godot/` 目录** —— 它是导入缓存，`.gitignore` 已自动忽略，别手动强加。
4. **不要提交导出产物**（`.zip`、`index.html`、`.wasm`、`.pck`、`build/`、`export/`）。
5. **不要改别人负责的场景** —— 一人一场景，谁建谁改。
6. **不要提交大于 10MB 的文件**（音频、图片先问 Ray 统一处理）。

---

## 六、冲突了怎么办

1. **现象**：`Pull` 时提示有冲突（conflict），或 GitHub Desktop 让你选保留哪一边。
2. **动作**：**立刻停下**，在群里说一声，把截图发出来，让 Ray 或项目管理 Agent 处理。
3. **尤其 `.tscn` 场景文件冲突** —— 不要自己选"保留我的/保留对方的"，那会静默丢掉一半内容。
4. **预案**：谁后 push 谁负责解决；场景冲突找建该场景的人拍板；实在乱了就回到最近的 tag 重来。

---

## 七、文件归属速查

| 路径 | 归谁 | 说明 |
|------|------|------|
| `retro-game-jam-2026/scenes/` | Illya 主 | 一人一场景 |
| `retro-game-jam-2026/scripts/` | Illya 主 | 关键类由 Ray 评审 |
| `retro-game-jam-2026/ui/` | Illya 主 | 界面场景 |
| `retro-game-jam-2026/assets/art/` | Ray | 精灵图 |
| `retro-game-jam-2026/assets/audio/` | Ray | 音乐音效（提交前转 ogg） |
| `retro-game-jam-2026/assets/fonts/` | Ray | 字体 |
| `retro-game-jam-2026/autoload/` | Ray | 全局单例（接口约定后定） |
| `retro-game-jam-2026/project.godot` | **Ray 独占** | 改了可能打不开工程 |
| `retro-game-jam-2026/export_presets.cfg` | **Ray 独占** | 网页导出配置 |
| `docs/`、`PROJECT_INDEX.md` | 项目管理 Agent 主 | 走飞书群说一句即可 |

---

## 八、里程碑打 tag（Ray 或 Agent 执行）

| tag | 含义 | 目标时间（UTC+8） |
|-----|------|-----------------|
| `m0-ready` | 准备期完成 | 09-29 |
| `m1-proto` | 可玩原型 | 10-01 |
| `m2-content` | 内容完成 | 10-04 |
| `m3-submit` | 已提交 itch.io | 10-06 12:00 |

---

## 九、出问题时找谁

1. **git 报错 / 冲突 / 不知道怎么选** → 群里发截图，等回复，别自己试。
2. **Godot 报错 / 场景打不开** → 群里描述现象，写清你改了什么。
3. **不确定某个文件该不该提交** → 先问，别猜。
