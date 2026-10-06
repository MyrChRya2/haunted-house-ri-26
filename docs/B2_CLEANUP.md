# 🚨 B2 清除清单（第三方素材 · 上传前硬闸门）

> 2026-10-06 18:45 由项目管理 Agent 扫描生成 —— **只做定位与方案，不代改任何文件**（AI 红线：代码与美术属游戏本体）。
> 关联：ROADMAP Bug 表 `B2`、`git revert -m 1 84510b2` 可整体回退 PR #2。

**结论先行：真正需要替换的只有 6 张 PNG，不是 14 个场景。**

---

## 一、`resources——temper/` 里到底是什么（21 个文件）

| 类型 | 文件 |
|------|------|
| PNG（6 张，含第三方内容） | `道具ui.png`、`源石虫.png`、`瓦片.png`、`ligh——texture/match_light_cookie.png`、`stairs_art/stair_up_16.png`、`stairs_art/stair_down_16.png` |
| `.import`（6 个，随 PNG 生成） | 上列每张图各一个 |
| `.tres`（9 个，Godot 的 AtlasTexture 中间层） | `key`、`piece`、`pieces`、`scepter`、`weng`、`ghost`、`tarantula`、`vampire`、`victorydoor` |

## 二、引用链（这就是 19 条引用的全貌）

**中间层**：8 个 `.tres` 都是 AtlasTexture，只指向 2 张图 ——
- `key / piece / pieces / scepter / weng` → **`道具ui.png`**
- `ghost / tarantula / vampire` → **`源石虫.png`**

**场景 → 引用点（14 个场景文件）**

| 场景 | 引用 |
|------|------|
| `scenes/door.tscn` | `scepter.tres` |
| `scenes/Player.tscn` | `match_light_cookie.png`（火柴光） |
| `scenes/Stairup.tscn` | `stair_up_16.png` |
| `scenes/Stairdown.tscn` | `stair_down_16.png` |
| `scenes/VictoryDoor.tscn` | `victorydoor.tres` |
| `scenes/text_playground.tscn` | `key.tres`、`瓦片.png`、`scepter.tres`、`weng.tres`、`piece.tres`、`pieces.tres`（6 条） |
| `item/Key.tscn` | `key.tres` |
| `item/Piece.tscn` | `piece.tres` |
| `item/Pieces.tscn` | `pieces.tres` |
| `item/Scepter.tscn` | `scepter.tres` |
| `item/Weng.tscn` | `weng.tres` |
| `monster/Ghost.tscn` | `ghost.tres` |
| `monster/Tarantula.tscn` | `tarantula.tres` |
| `monster/Vampire.tscn` | `vampire.tres` |

## 三、两个关键发现（决定了这活其实很小）

1. **8 个 `.tres` 只是切图中间层**，本身不含画面内容；真正的内容全在那 2 张 PNG 里。
   → 所以替换 PNG 的内容，8 个怪物/道具场景**一个字都不用改**。
2. **`victorydoor.tres` 指向的是 `res://icon.svg`（Godot 自带图标，不是第三方素材）** —— 它只是恰好被放在那个目录里。
   → `scenes/VictoryDoor.tscn` **干净，无需改动**；那个 `.tres` 只要挪出目录即可。

## 四、两条路径（建议都做，顺序不能反）

### 路径 A —— 今晚就能解除违规（约 10 分钟）

**保持文件名与路径不变，直接替换这 6 张 PNG 的内容为自研素材。**
Godot 会自动重新导入，19 条引用全部指向自研素材，**零场景改动、零引用改动**。

### 路径 B —— 赛前的体面整理（可选，别在 P0 时间挤）

在 Godot **文件系统面板**里把 `resources——temper/` 里的文件移到 `assets/` 对应子目录，
并在弹窗里选 **"更新引用"**（Godot 会自动改所有引用）→ 然后删掉空目录。
目录名里的"temper"是教程作者名，留在仓库里对评审不体面，也容易让人误判。

## 五、⚠️ 尺寸必须一致（否则切图错位）

| 图 | 原尺寸 | 用途 |
|----|--------|------|
| `道具ui.png` | **64 × 80** | 5 个道具的**图集**，`.tres` 按 region 切 |
| `源石虫.png` | **96 × 192** | 3 个怪物的**图集**，`.tres` 按 region 切 |
| `瓦片.png` | **64 × 64** | `text_playground` 直接当瓦片用 |
| `match_light_cookie.png` | **128 × 128** | 火柴光遮罩（大概率当光照贴图） |
| `stair_up_16.png` | **16 × 16** | 上楼 |
| `stair_down_16.png` | **16 × 16** | 下楼 |

- 前两张是**图集**：新图必须**同尺寸、同格子排布**，否则 `region` 会切到错的位置（表现是道具/怪物贴图错乱）。
- 其余四张是单图，**改成同尺寸最稳**（瓦片 64×64 与楼梯 16×16 尤其要保持，网格是 16×16）。

## 六、验收（做完逐条打勾）

1. 打开工程**无缺失资源报错**（没有红色提示）。
2. 运行主场景：道具、怪物、门、楼梯、火柴光的贴图**全部正常**。
3. **删掉 `resources——temper/` 后工程仍能打开并运行** —— 这是"引用已全部切走"的硬证据。
4. 导出 Web 包后确认**包内不含** `resources——temper`。

## 七、操作注意

- 目录名含**全角破折号 `——`**，命令行操作极易出错；**优先用 Godot 文件系统面板或文件资源管理器**。
- 在 Godot 里移动/改名时，弹窗一定要选 **"更新引用"**，否则会留下一堆悬空引用（`redraw-fiels-tree` 那次就吃过这个教训）。
- 移动/改名后**连带检查 `.import` 文件**，别留下指向旧路径的孤儿（参见 ROADMAP 2026-10-05 那条教训）。
