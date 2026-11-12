# 交付：claude/project-thread-yzaqle

- 车道／工作者：天启篇·装备栏第二批／cc（Pro，项目线程「实装装备栏下一批」，云端容器）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·Pro·未经审查】天启篇装备栏第二批：删除栏位物品不上架、掉落重抽；坐骑管速度先手；神器成长上限（dev.待定）

- 依据：设计仓库交接单「天启篇装备栏下一批」（Max 发，Kyo 11-08 规则：数值重构方案第八节第 9 条；删除栏位角色专属物清单 v0.1 第 56、78 行「成长型神器加上限」）。上一批的交付后续第①②④条。
- 全部只在天启篇存档生效（`XTianqiGear.on(s)`），原版档、原版对照不变；每件一个开关（`static var`，默认 true）。
- 新数据表 `modes/xiyou/tianqi_data/gear_table.json`（都是占位、标 `draft`，不带 4）：坐骑七档敏捷％ 5／10／15／20／25／30／33、先制％ 3／5／6／8／10／12／15、先制总上限 33％；神器上限心钢阶 10、狂妄阶 10、"头顶" 300％；掉落重抽等级段 10 级一段。
- **A 删除栏位清理**（`XTianqiGear.CLEAN_DELETED`）：
  - 商店：`XShopStock.prepare_policy`（Scene_Shop.prepare 外层）里去掉装备类型属于删除栏位（宝物、护符、灵兽、圣器、宝宝、形态）的防具，按装备类型判断，不写死编号。
  - 随机掉落：`XBattleLogic.drops_of` 在屏蔽掉落之前调 `XTianqiGear.reroll_drops`：抽到删除栏位的防具，在「敌人掉落表里出现过的、同七档品质、同等级段（`req_level` ÷10）、保留栏位（不含神器栏）、不是专属」的武器防具里重抽一件（战斗奖励流 `tianqi_reroll`）；池空才不给。掉落条目带 `tianqi_reroll` 记原编号。
  - 事件、宝箱、任务直接发放的删除栏位物品本批不改，搬图时处理。深渊商人没碰：它的「饰品」组含装备类型 11、12（宝物、护符），**会卖删除栏位物品**，归深渊商人那条线处理。
- **B 坐骑管速度和先手**（`XTianqiGear.MOUNT_STATS`）：
  - 坐骑栏（类型 16）的装备在天启篇都当普通坐骑：原来的特性（`stat_equips`）、属性（`_param_plus` 含自定参数、法宝升级值）、开战状态标签都不算；白马、嘶风逐日驹及洪荒版一样处理，不改原版数据。
  - 敏捷：`XActor.param_before_alien` 链上加一层 `XTianqiGear.param`（心钢、狂妄、小猫剑圣之外，云裳夹值之内），敏捷 ×(1＋表里百分比)，取整。
  - 先制：`XBattleLogic.roll_encounter` 一行：`XPreempt.rates` 之后 `XTianqiGear.apply_preempt`，加上「上场 4 人（`battle_members`，助力位不算）身上坐骑最高一件」的先制几率，不相加；加完不超过 33％，原来已经超过 33％ 的不往下压。偷袭率不变。
- **C 神器成长上限**（`XTianqiGear.ARTIFACT_CAP`）：
  - 心之钢／杰作利维坦：`XHeartsteel.eff_stage`（生命倍率、巨人吞噬倍率、说明与锻造预览）阶数最多 10；狂妄／杰作无我：`XHubris.rate_for` 阶数最多 10；"头顶"：`XDemonCrown.describe` 的八项倍率按成长最多 300％。
  - 层数、盛名、"头顶"成长账本照常往上记，不截断；只在算效果时夹。到上限时说明写「成长：…（已达上限）」，心钢／狂妄的进度行改成「进度：心钢（盛名）已达上限，层数照常累积」。
- 新专项 `xiyou_tianqi_gear2`（47 项）；`03_转换工具/天启篇数据校验.py` 加 `gear_table` 检查（七档齐全、随品质不降、单件先制不超过总上限、上限是正整数、标 draft、不带 4）。
- 玩家可见：天启篇存档里商店不再卖宝物、护符、灵兽、圣器、宝宝、形态；打怪掉到这些会换成同品质的别的装备；坐骑只加速度（敏捷）和先手几率；心之钢、狂妄、"头顶"成长到上限后说明写「已达上限」，效果不再变大。

## 交接板

- 下一步：天启篇装备栏剩下的后续：③光环只出在项链和法宝（词条重构一起做）；⑤套装、精华液／内丹镶嵌部位；⑥绑技能物品改技能熟练度；独特坐骑（候选见下）；事件直接发放的删除栏位物品（搬图时）；深渊商人「饰品」组不再出宝物、护符（深渊商人线）。
- 用户试玩说明：天启篇新开一局 → 方桌大厅等商店里没有宝物、护符、形态类；穿白马看状态页敏捷 +5％（按品质）；随机遇敌先制略多。
- 需要用户决定（按占位继续，不停工）：
  1. 坐骑表、先制上限 33％、神器上限（心钢、狂妄 10 阶，"头顶" +300％）、重抽等级段 10 级：都是 Max 起草的占位，要不要改。
  2. 独特坐骑候选（专属物清单第 57、58 行，本批不做）：再动类——圣器雷鸣、冤魄、星辰耀光（再动 +10%～+30%）、神武黎明—破晓（再动 +1）、护符繁育的虫卵（再动 +1、攻击次数 +3）、终末的未来、宝物传承:猪之歌（攻击次数 +1）；不死／复活类——护符开拓的旅人（开局 3 回合免死）、不朽的龙鳞（60% 复活）、丰饶的赐福（75% 免死）、存护的坚墙（掩护）。挑哪几件做成独特坐骑。
  3. 坐骑原来的属性在天启篇全部不算（本批默认）；要不要保留基础属性只去掉特殊效果。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·删除栏位清理 | `modes/xiyou/core/tianqi_gear.gd` `XTianqiGear.CLEAN_DELETED` | 商店照卖、掉落照给删除栏位物品 | 天启篇存档商店不上架，随机掉落在同品质、同等级段、保留栏位里重抽 | Kyo 定天启篇删栏位，交接单 A | `XTianqiGear.CLEAN_DELETED = false` | cc（Pro） | 默认开 |
| O-待定·坐骑速度先手 | `modes/xiyou/core/tianqi_gear.gd` `XTianqiGear.MOUNT_STATS` | 坐骑照原版数据生效 | 天启篇存档坐骑只给敏捷％和先制几率（按品质查表，上场最高一件，总上限 33％） | Kyo 11-08 坐骑管速度、先手 | `XTianqiGear.MOUNT_STATS = false` | cc（Pro） | 默认开 |
| O-待定·神器成长上限 | `modes/xiyou/core/tianqi_gear.gd` `XTianqiGear.ARTIFACT_CAP` | 心钢、狂妄阶数无上限，"头顶"趋近 +1000％ | 天启篇存档算效果时夹上限（10 阶、10 阶、+300％），存档里的数不截 | 专属物清单第 56、78 行 | `XTianqiGear.ARTIFACT_CAP = false` | cc（Pro） | 默认开 |

## 进度账

- 无（天启篇改版，不计重制完成度）

## 可优化（流程／工具／效率）

- 建议：`工具回归.py` 的「选测替身与 检查.sh 解析」在 Linux 云端容器失败 13 项，原因是 `检查.sh` 里 `mktemp -t xiyou_check_failed` 这类写法在 GNU mktemp 要求模板带 `XXX`（macOS 不要求），与本分支无关；改成 `mktemp -t xiyou_check_failed.XXXXXX` 两边都能用（工具车道）。
- 上一批交付单提过的两条仍在：`语法检查.py` 不认环境变量 `GODOT`（本次照样临时建了不入 Git 的 `当前Godot.app` 链接）；项目文件夹没有 `云端测试/generated.tgz`，云端跑不了要数据的专项。

## 验证

- `语法检查.py`：687 个 .gd 0 个问题（云端容器，Godot 4.7.2 Linux）。
- `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`：balance_table、gear_table 全部通过；反向验证（手改表后跑、再还原）：神话敏捷改 34 → 挂（带 4）、单件先制改 35 → 挂（超总上限）、draft 改 false → 挂；心钢上限改 15 → 数据校验不管，靠 Godot 专项的 `table_cap` 咬。
- `工具回归.py`：16 项 15 过，失败那项是上面的 mktemp 环境差异。
- **没跑**：`xiyou_tianqi_gear2` 与相关旧专项要转换产物，云端容器没有（见下「需要对方做什么」）。

## 需要对方做什么（Max）

1. 在 Mac 上跑专项：`xiyou_tianqi_gear2`（新）、`xiyou_tianqi_gear`、`xiyou_heartsteel`、`xiyou_growth_help`、`xiyou_demon_crown`、`xiyou_preempt`、`xiyou_shop_stock`、`xiyou_lobby_shops`、`xiyou_determinism`、`xiyou_power*`；本分支改了 `actor.gd`、`battle_logic.gd`，`选测.py main --list` 选中 477 个场景（整轮），按总装的影响面选测决定。原版档逻辑只多一次 `XTianqiGear.on()` 判断，理论上原版对照不变。
2. 反向验证：`python3 03_再刷重制_Godot/07_开发环境/反向验证.py 03_再刷重制_Godot/04_验证/反向验证清单/xiyou_tianqi_gear2.json`（10 处：神话敏捷 34、心钢上限 15、先制相加、助力位算先制、去掉总上限、商店不过滤、池空给原物、坐骑原属性照算、狂妄不夹、"头顶"不夹），应全部「咬住」。
3. 专项里写死的物品：白马 4472、屈服的嘤嘤怪 3582（灵兽）、品质旧档 1／2／3／4／6／8／12 对应七档 0～6；`_drops` 用 Armors 表里和 3582 同组的保留栏位防具当重抽池，如果这一组在数据里为空，`reroll_pool_found` 会挂，换一件删除栏位防具即可。
4. `选测对照.json` 登记新专项 `xiyou_tianqi_gear2`（跟 `xiyou_tianqi_gear` 同组：`core/tianqi_gear.gd`、`tianqi_data/gear_table.json`）。

## 待交叉核查

- 甲档（战斗核心、装备核心）：
  - `modes/xiyou/battle/battle_logic.gd`：`roll_encounter` 一行（坐骑先制）、`drops_of` 一行（掉落重抽，用奖励流 `tianqi_reroll`，只在天启篇抽）。
  - `modes/xiyou/core/actor.gd`：`stat_equips`、`_param_plus`、`battle_start_state_tags` 过 `XTianqiGear.stat_list`；`param_before_alien` 链上加 `XTianqiGear.param`（敏捷％）。
  - `modes/xiyou/core/heartsteel.gd`（`eff_stage`）、`hubris.gd`（`rate_for`）、`demon_crown.gd`（`describe`）。
- 乙档：`core/tianqi_gear.gd`（第二批段）、`core/shop_stock.gd`、`core/growth_forge.gd`、`ui/growth_help.gd`、`tianqi_data/gear_table.json`、`tests/xiyou_tianqi_gear2.gd`。
- 丙档：`03_转换工具/天启篇数据校验.py`（gear_table 检查）、`04_验证/反向验证清单/xiyou_tianqi_gear2.json`。
- 已知没覆盖：法宝升级特性对象（`XMagicWeapon.trait_objects` 直接读 `equips`）不过滤坐骑；坐骑没有法宝等级，实际不影响。其它直接读装备备注的系统（套装、宝珠等）照旧看得到坐骑。

## 本分支提交

- 2516b03 WIP: 天启篇装备栏第二批：删除栏位物品不上架、掉落重抽；坐骑管速度先手；神器成长上限；专项 xiyou_tianqi_gear2
