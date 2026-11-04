# 交付：cc/wukong-scan2

- 车道／工作者：A 内容／悟空（cc，Sonnet）；从 main（038f9292）起
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·悟空·未经审查】scan2：插件备注覆盖扫尾（Max Item 封顶、SvPngFd 立绘放大、豁免清单）（dev.待定）

现跑 `插件备注覆盖.py`，「没读」＋「拿不准」共 25 项（数据里有用量的）。总装已划掉的不做：Multi-Element Rule、Max State Floor（已量）、先制／偷袭（哪吒）、SV 敌人四标签与 STATE ANIMATION（白龙）、技能树 pSTCatName（Kyo 定删）。其余逐个读插件代码＋数据＋重制代码，必要时用 `mv_oracle/scan2_probe.cjs`（产物 `scan2.json`，已登记 PROBES／oracle_additions，报错字段用 `sourceErrors`）量原版。

**做了（2 项真缺）**
- **`<Max Item: x>`（物品 2933 练型者雷枝、2934 苦寒晶壳）**：原版运行时默认每种物品 9999，这两个封顶 130（`maxItems`＝130，`gainItem` 500 得 130）。重制 `_gain_raw` 一律 clamp 9999。改为 `XState.item_max(id)`：备注 `Max Item` 取 max(1, x)，否则 9999。
- **dsPassiveSkill `<SvPngFd: N>`（防具 2937、4279、5198、5200～5203，状态 1120 人鱼化身）**：战斗里角色立绘（`Sprite_Actor` 主图）放大 N 倍。实测：解析顺序装备→技能→状态，后者盖前者（带 1120 状态一律 2 倍；单戴 5198＝3 倍，5200＝2 倍）；缓存只在开战时刷新（`addState` 的单状态解析不处理它）、且只会改写不会复位，所以重制在建立立绘时取一次。`XActor.sv_png_scale()`＋`XBattlerSprite.png_scale`（只放大主图，影子、武器、状态图标不动，呼吸也乘上）。注意 2937／4279／5201～5203 在探针里这个职业戴不上（原版 `forceChangeEquip` 后缓存仍 1），专项只比戴得上的 5198、5200 和状态。**画面效果没有截图核对**，只比了倍数。

**不用做（已核，写进 `07_开发环境/插件备注豁免.json`，工具现在显示「已核」＋依据）**
| 标签 | 判断 | 依据 |
| --- | --- | --- |
| `not independent item`（11 个物品） | 无运行效果 | YEP_ItemCore `Max Items` 参数为 0，物品本来就不独立 |
| `SkillKillGoon`（11 个技能） | **无运行效果（原版死代码）** | Olivia_BattleSysOTB 击杀追击条件要求 `_subjectActorId` 为真且 `_subjectEnemyIndex !== -1`，角色行动的 `_subjectEnemyIndex` 恒为 -1、敌人行动的 `_subjectActorId` 恒为 0，永不成立。`scan2_probe killgoon` 8 例（乘胜追击 2061、落日矢 2192、被动俱灭 2035，打死／没打死第一只、另有 2 只活敌）都不追击；专项 `xiyou_scan2` 守着，冻结源变了才会挂 |
| `ANCHOR X`（角色 167、168） | 无运行效果 | `<Anchor X: 0.5>`／`<Anchor Y: 1.0>` 等于 BEC 默认 0.50／1.00 |
| `Codex Guide v1`（Map004#71） | 无运行效果 | 只在读旧档后把向导事件摆回地图位置；重制不迁移 MV 旧存档 |
| `CodexRandomWeakAura`（技能 10453） | 暂缓（已登记 O-035） | 轮回「随机角色」模式整体暂缓，弱者协力只在该模式生效 |
| `State Can Added Floor`（6 个状态） | 无运行效果 | 层数叠不上去（battle_logic.gd `_push_rows` 上方已有说明），同 Max State Floor |
| 插件命令 `item`、`show` | 工具误报 | 数据里是 `itemslot show/hide`（MKR_MapItemSlot，不在 plugins.js，未启用）和 `ShowActiveQuestWindow` |
| `dh`、`SHOW HP GAUGE`、`ChangeTo[10]`、`UPGRADE WEAPON／ARMOR TYPE`、`book`、`sv`／`SVzs0`、`atkk` | 已由别处实现 | `drop_popup.gd`、`enemy.gd hp_gauge_visible`、`battle_logic.change_to`、`equipment_rules.py`＋`gear_upgrade.gd`、`enemy_book.gd`、`appearance.gd`、`attack_times_add`；工具因标签太短、写在注释里或改名而没认出 |
| `Multi-Element Rule`、`pSTCatName`、SV 敌人四标签、`STATE ANIMATION`、`Max State Floor` | 总装已划掉 | 同上，一并写进豁免（reason 注明归属） |

**工具**：`插件备注覆盖.py` 新增豁免机制（`插件备注豁免.json`，每条必须有 reason＋evidence，只改「没读／拿不准」不碰「已读」，判定显示「已核」）；`测试插件备注覆盖.py` 新增 2 个用例（豁免键必须真的存在于插件标签里、`skillkillgoon` 显示已核），已知「没读」例改为 `codexweaknewgame`。

**扫完后真缺还剩几项：1 项**——`CodexWeakNewGame`（技能 10357「你才是真正的强者」，installWeakChallengeRuntime 的弱者挑战）：五名「弱者」通关混沌难度最终守层者鸿蒙老祖（Map157 敌群 469）得成就 142，之后每个新游戏的弱者角色自动带 10357——八项基础属性 +500%、伤害 ×3、物理／魔法承伤 ×0.5。重制只有成就 142 的条目和徽章，没有「最终战判定、`ConfigManager._codexWeakFiveClearV2` 全局标记、新游戏发技能」这条线，所以成就拿不到、10357 永远没人学。这是一整个玩法模块（难度 9 判定、弱者分类 CE1345、成就、全局配置、新游戏），建议单独开一期，先问 Kyo 要不要做。另有 5 项由白龙在做（SV 敌人四标签＋STATE ANIMATION）、先制／偷袭由哪吒在做，不计入。

**没有新优化，不占优化号**（全部按原版测量实现）。

## 交接板

- 下一步：弱者挑战（CodexWeakNewGame）要不要做、谁做，请总装问 Kyo；其余无。
- 用户试玩说明：练型者雷枝、苦寒晶壳最多持有 130 个（原版如此）；穿「巨大化／巨人」类防具（5198 起）或带人鱼化身状态的角色，战斗里立绘放大 2～3 倍。
- 需要用户决定：弱者挑战是否做（见上）。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：插件备注覆盖加了豁免清单（回退：删 `插件备注豁免.json` 即恢复原先的「没读／拿不准」报告）。

## 待交叉核查（改了核心文件）

- `core/xstate.gd`：`_gain_raw` 封顶改读 `item_max`。
- `core/actor.gd`：新增 `sv_png_scale()`；`battle/battler_sprite.gd`：`png_scale` 乘进 `_apply_scale` 与呼吸。没改战斗核心（battle_logic、damage）。

## 验证

- 专项 `xiyou_scan2`（新，57 项，对照 scan2.json）通过；`测试插件备注覆盖.py` 14 项 OK；`语法检查.py` 通过。
- 同步 `--accept-additions` 退出码 0。云端选测结果见末尾。

## 本分支提交

- scan2 主提交：Max Item、SvPngFd、豁免清单、探针、专项
- 本期：交付单
