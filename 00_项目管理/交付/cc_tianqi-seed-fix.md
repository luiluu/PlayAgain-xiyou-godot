# 交付：cc/tianqi-seed-fix

- 车道／工作者：C 规则·机制／cc（天启篇读档重掷修复，Opus＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【cc·读档重掷修复·未经审查】天启篇重铸、异化词条、抽角色候选改存档派生随机（dev.待定）

- 经济返修「同类盘点」里剩下的读档重掷处一次堵上（七印两处已由 cc/tianqi-qiyin-endgame 修）：装备重铸、锁词条重铸、异化词条兜底（`XTianqiAlienGear.create`／`attach` 不传随机流时）、异化重抽、通关抽角色候选。
- 种子＝存档种子 `orb_seed`（随存档；更老的档由存档内容算出）＋对象标识＋该对象随存档的次数：重铸用装备 `instanceId`＋装备上的 `tq_rng_n`；异化兜底用异化账本 `sequence`；重抽用异化 `uid`＋账本 `tq_reroll_n`；候选用第几次抽（`flags.tianqi.draws`）。同一次操作读档后结果相同，不同次、不同装备各自独立；老档缺计数字段当 0 补上。
- 公共入口在 `XTianqi.save_stream`／`save_roll`／`item_roll`（`modes/xiyou/core/tianqi.gd`），开关 `XTianqi.SEED_FROM_SAVE`（O-待定-1），关掉回到全局随机、不写计数字段。
- 西游档不变（全部只在天启篇路径上）；掉落、战斗奖励走的战斗奖励流不在本单（整局既有设计，见下「漏网清单」）。
- 玩家可见：天启篇里重铸、异化重抽、通关抽角色候选，先存档再掷、读档再掷，出来的还是同一个结果。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/tianqi.gd` `XTianqi.SEED_FROM_SAVE`（`save_stream`、`save_roll`、`item_roll`、`draw_offer`）；`modes/xiyou/core/tianqi_reforge.gd`（`reforge`、`reforge_locked` 兜底）；`modes/xiyou/core/tianqi_alien_gear.gd`（`attach` 兜底、`reroll`／`reroll_roll`）；`tests/xiyou_tianqi_seed_fix.gd` | 天启篇重铸、锁词条重铸、异化兜底选词条、异化重抽用全局 `randf`，抽角色候选首次抽用 `randomize()`，都能先存档再掷、不满意读档重掷 | 改由存档种子＋对象标识＋随存档的次数派生，读档后同一次操作结果相同 | cc/tianqi-econ-fix 交付单「同类盘点」；协调派单 cc/tianqi-seed-fix | `XTianqi.SEED_FROM_SAVE = false` | cc | 保留 |

## 改了什么

| 处 | 原来 | 现在（种子 key） | 计数 |
| --- | --- | --- | --- |
| `tianqi_reforge.gd` `reforge` 兜底 | `randf()` | `XTianqi.item_roll(s, item, "reforge")` → `reforge\|<instanceId>\|n` | 装备上 `tq_rng_n`，每次重铸 +1（与金钱重构的 `tq_reforges` 分开：那个只在金钱重构开着时涨，不能当随机计数） |
| `tianqi_reforge.gd` `reforge_locked` 兜底 | `randf()` | `reforge_lock\|<instanceId>\|n` | 同一个 `tq_rng_n` |
| `tianqi_alien_gear.gd` `attach` 兜底（`create` 不给 rng、不指定词条时） | `randf()` | `alien_attach\|<账本 sequence>` | 异化账本 `sequence`（本来每打一件 +1、随存档） |
| `tianqi_alien_gear.gd` `reroll` 的 `pending.next` | `randf()`（`XAlienation.force_roll` 测试钩子照旧优先） | `alien_reroll\|<异化 uid>\|n` | 异化账本 `tq_reroll_n`，每次重抽 +1（放账本不放装备：`resolve` 只改词条，计数放哪都不丢，账本一处好查） |
| `tianqi.gd` `draw_offer` 不传 rng 时 | `rng.randomize()` | `offer\|<draws>` | `flags.tianqi.draws`（本来随存档，每收一位 +1） |

掉落路径（`XTianqiAlienGear` 战斗奖励里的 `create`）照旧传战斗奖励流，不走兜底，不受影响；刻印（`engrave`）指定词条，不随机。

## 漏网清单（rg `randf(`、`randi(`、`randomize(`、`fresh_seed(`、`RandomNumberGenerator.new()`、`pick_random(`、`.shuffle()`；`modes/xiyou/core/tianqi*.gd` 与引用天启篇的 ui／map／battle 脚本）

| 文件:行 | 用途 | 影响玩家可得结果 | 处理 |
| --- | --- | --- | --- |
| `core/tianqi_qiyin.gd:74`（`next_seed` 里 `fresh_seed`） | 七印存档派生的回退路径（O-427 关掉时） | 只在开关关着时 | 已修（qiyin-endgame），不动 |
| `core/tianqi_qiyin_dragon_run.gd:267` | 招募候选：`RandomNumberGenerator.new()` 后用存档派生种子 | 否（已派生） | 不动 |
| `core/tianqi_drop.gd:249` | 掉落账种子 `randi()`，只在 `SEED_FROM_SAVE`（掉落）关着时 | 只在开关关着时 | 已修（econ-fix），不动 |
| `core/tianqi_affix_roll.gd:65` | 新装备掷天启篇词条的兜底 `XGear.roll(s)` → 装备流（`XState.random_master`，运行时、不随存档） | 是，但和战斗掉落、商店进货同一条整局装备流 | **不修**：econ-fix 已注明 `random_master` 只在运行时、不随存档是整局既有设计（掉落、进货、战斗奖励都走它）；要改是全局方案，不是天启篇单点，建议另立题由 Kyo 定 |
| `core/tianqi_qiyin_show.gd:309` | 展示动画抖动，固定种子 | 否（纯表现） | 不修 |
| `map/tianqi_table.gd:56` | 方桌裂纹形状，固定种子 0x7A61 | 否（纯表现） | 不修 |
| `battle/battler_sprite.gd:100、741` | 战斗精灵呼吸相位、视觉抖动 | 否（纯表现） | 不修 |
| `map/mv_event.gd:28` | 地图 NPC 随机走动 | 否（纯表现，原版同样） | 不修 |
| `battle/battle_logic.gd:56、3460` | 没有存档时（测试夹具）现开战斗随机 | 否（正式战斗走 `reserve_battle_random`） | 不修 |

天启篇界面脚本（`ui/alien_workshop.gd` 等）里没有直接取随机的地方。

## 交接板

- 下一步：gpt 甲档核 cc/tianqi-seed-fix（存档、装备随机流）。`tianqi_affix_roll` 新装备词条走运行时装备流可读档重掷，属整局 `random_master` 设计，要不要改由 Kyo 定（见交付单漏网清单）。
- 用户试玩说明：天启篇重铸、异化重抽、通关抽角色候选读档再掷结果不变。
- 需要用户决定：无（`random_master` 那条只是建议，不挡本单）

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- 新专项 `xiyou_tianqi_seed_fix`（真实 `XSave.save`→`XSave.load_slot` 写盘读档）37/37：每处「存→掷→读→再掷相同」（`rf_reload_same`、`al_create_same`、`al_reroll_same`、`of_same`、`of_second_same`）；连掷不全相同、读档后前缀可复现（`rf_runs_differ`、`rf_prefix_same`、`rf_continues`、`al_create_varies`、`al_reroll_varies`、`al_reroll_prefix`、`rf_items_independent`、`of_draws_independent`）；老档去掉计数字段写回存档文件再读能补上（`rf_legacy_*`、`al_legacy_*`），去掉 `orbSeed` 也可复现（`rf_no_orb_same`、`of_no_orb_same`）；开关关掉两次读档结果不同、不写计数（`rf_off_*`、`al_off_*`、`of_off_differs`）；`force_roll` 测试钩子照旧优先。本机连同 `xiyou_tianqi_reforge`、`xiyou_tianqi_alien_gear`、`xiyou_tianqi_party` 全部通过。
- 反向验证（`反向验证.py`，专项 `xiyou_tianqi_seed_fix`）：8 处各改坏一次（重铸／锁词条重铸回到 randf、装备计数不推进、异化兜底回到 randf、重抽计数不推进、重抽回到 randf、候选回到 randomize、开关关时仍派生）全部让专项失败，咬得住；源文件按备份还原。
- 语法检查：846 个 .gd，0 个问题。工具回归 `工具回归.py` 全部通过。
- 选测：合 main 后 `云端选测.py run`（提交 6ae0b0469），471 个场景、16 片全部通过（基准 3b7033b56，名单含 main 新合进的改动，比 `选测.py main --list` 的 54 个多）。不需要 `--oracle`（新机制，没碰原版移植逻辑）。

## 待交叉核查

- 甲档（存档、装备随机流）：`core/tianqi.gd`（`SEED_FROM_SAVE`、`save_stream`、`save_roll`、`item_roll`、`draw_offer`）、`core/tianqi_reforge.gd` 两处兜底、`core/tianqi_alien_gear.gd`（`attach` 兜底、`reroll`、`reroll_roll`）、`tests/xiyou_tianqi_seed_fix.gd`。
- 重点：老档缺计数字段；`tq_rng_n` 写在装备字典上会不会影响别处按字典比较装备（先例：金钱重构的 `tq_reforges`、`tq_buy_price` 也写在装备字典上；本单 rg 没找到按 hash／JSON 比较装备内容的地方，`targets` 等用 `is_same` 认引用）。

## 本分支提交

- 6ae0b0469 合并 main
- 1d4096a5c 天启篇读档重掷修复：重铸、锁词条重铸、异化兜底／重抽、抽角色候选改存档派生随机
