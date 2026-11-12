# 交付：cc/tianqi-alien-gear

- 车道／工作者：天启篇·异化装备（掉落、取核、刻印、净化、族内重抽）／cc（项目线程「完成再刷西游 Godot 引擎重制」）
- 状态：可合并

## 依赖与合并顺序

- 从 main（dev.490）切出，交付前合过 main（含 cc/qiyin-equip、七首之龙，dev.492）。只依赖已在 main 的 `XAlienation`、`XAlienBattle`、`XTianqiRewards`（终焉异化核和每线 4 条词条）、各线异化模块（`XTianqiWarAlien` 等本场 `units`）。
- 和词条战斗车道（cc/tianqi-affix-battle）：本分支在 `battle_logic.gd` 只加一行（`grant` 里原版异化发奖之后调 `XTianqiAlienGear.grant`），没碰战斗结算；别的改动在 `alienation.gd`（四个函数开头遇到天启篇异化装备转给新模块）和 `ui/alien_workshop.gd`（天启篇存档多出按钮），词条车道不碰这两处。

## 变更记录草稿

## 2026-11-12 【cc·天启篇·未经审查】天启篇异化装备：本线异化怪掉装备、按级分解、取核、刻印、净化（dev.待定）

- 按设计仓库《天启篇序章_四线异化与异化装备重构 v0.8》第 4 节、《天启篇_四线剧情与关卡设计稿 v0.4》第 3.4、6 节。只在天启篇存档，发行构建里还要 `XTianqi.RELEASE_OPEN`；原版异化整套隐藏时（`XAlienBattle.hidden`）也不出。
- 新数据表 `modes/xiyou/tianqi_data/alien_gear.json`（只读，`draft: true`）：四级掉率（侵染 3%、蚀骨 8%、化形 20%、终焉必掉）、分解能量（1／2／5／8，设计稿化形是 4，避开 4 写 5）、净化退还（1／1／3／5）、共生／夺舍／寄生化形起才出、重抽／刻印／净化各 1 颗异化石、四条新词条的说明。每线 4 条词条和新名字读 `rewards.json` 的 finale（和终焉异化核同一份）。
- 新模块 `core/tianqi_alien_gear.gd`（XTianqiAlienGear，开关 `ENABLED`）：
  - 掉落：赢了以后，各线异化模块本场记下的异化怪（开场、使徒、按段异化）倒下的按级掷一次；本体从那只怪自己掉落表里的武器、防具里挑（排除专属武器、法宝、灵兽、坐骑、神器栏、七印装备、净印、遗物）。终焉怪掉落表里没有能用的本体时，改给一颗同级异化核；其余级不给。掷数走战斗的奖励随机流（`tianqi_alien_gear`），不动别的掉落。
  - 装备：沿用原版异化标记（`alien`：uid、affix、pool、config…），另加 `tq = {line, level}`；原有 12 条词条（血铠＝空壳、共生＝连命等）的战斗效果直接走原版异化那一套，名字「级·新词条名·原名」。四条本线新词条（临终、再动、节俭、带毒）只记在装备上，详情写「未生效」。
  - 工坊：分解按级给能量；重抽只在本线本级内抽，沿用原版的新旧二选一；取核（装备没了，得一颗记着线、词条、级的异化核，和终焉异化核放在同一张表 `flags.tianqi.rewards.cores`）；刻印（花 1 颗异化石把核刻到背包里任何一件能异化的武器、防具上，已有词条的替换）；净化（花 1 颗异化石去掉词条还原，退还一部分能量）。
- `core/alienation.gd`：`details`、`relabel`、`reroll`、`dismantle` 遇到天启篇异化装备转给新模块，原版异化装备照旧。
- `ui/alien_workshop.gd`：天启篇存档里详情多「取核」（要确认）、「使用1颗异化石净化」，分解按钮按级写能量，页底多「异化核（N）」一节（选刻到哪件、每颗核一个「刻上」）；没有异化装备时的说明换成天启篇的；待选重抽的两张卡在天启篇存档里用新名字。原版档的页面不变（`xiyou_alien_workshop` 照原版节点树比对通过）。
- `battle/battle_logic.gd`：`grant` 里原版异化发奖之后一行调 `XTianqiAlienGear.grant`。
- 新专项 `tests/xiyou_tianqi_alien_gear`（49 项）。
- 玩家可见：开发版天启篇存档里，本线异化怪会掉「蚀骨·装甲冲击·草帽」这样的异化装备；异化工坊能取核、刻印、净化；骑士和 34～36 层给的终焉异化核也能刻了。发行版看不到（天启篇关着）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_alien_gear.gd` `XTianqiAlienGear.ENABLED`；`core/alienation.gd`（四个函数转接）、`ui/alien_workshop.gd`（天启篇按钮）、`battle/battle_logic.gd`（`grant` 一行）各接一处 | 原版异化装备只从 1% 的异化遭遇来，每件词条从 20 条里出，工坊只有重抽、分解 | 天启篇存档里本线异化怪按级掉异化装备（每线 4 条、名字带级），分解按级给能量，重抽限本线本级，新增取核、刻印、净化 | Kyo 11-08 定异化装备精简与刻印（v0.8 第 4 节，「每线 4 条和刻印」回「可以」） | `XTianqiAlienGear.ENABLED = false`：天启篇的怪不掉异化装备，工坊没有取核、刻印、净化（已有的天启篇异化装备仍按原版异化规则在） | cc | 已接受（Kyo 11-11 优化直接接受） |

## 交接板

- 下一步：①四条本线新词条（临终、再动、节俭、带毒）的战斗效果（要接 battle_logic，可并进词条战斗车道或下一条天启篇车道）；②四级数值分档（原 12 条是开关式，按级分档的数在数值阶段定）；③异化图鉴本线页、宠物系统在天启篇隐藏（v0.8 第 2.4 节）、结局演出与可轮回标记。
- 用户试玩说明：开发版天启篇档选了线、打完开场，去 6 层以上打稀有怪或守层者（被异化时名字带「侵染·」「蚀骨·」），赢了有几率掉异化装备；主菜单「异化工坊」里选中它，能分解、重抽、取核、净化；页底「异化核」一节选一件背包里的装备「刻上」。
- 需要用户决定：无（化形分解能量 4→5、净化退还按「一半」取整后避开 4，是测试参数）。

## 进度账

- 天启篇异化装备（扩展账）：0 → 掉落、名字、按级分解、族内重抽、取核、刻印、净化已接，原 12 条词条效果沿用原版；新四条词条效果、四级数值分档、配置弹窗（v0.8 第 4.3 节「装备时直接弹配置窗」）未做。不写主表。

## 可优化（流程／工具／效率）

- 建议：`天启篇数据校验.py` 加一张 `alien_gear.json` 的检查（数字避开 4、四级齐、几率 0～1）；现在只有专项里查（归工具车道）。
- 建议：同 cc/qiyin-equip 那条，`battle_logic.gd` 只加一行受开关门控的 `XTianqi*` 调用也会被选测判成 248 个场景，`选测.py` 可以认这种改动降档（归工具车道）。

## 验证

- `xiyou_tianqi_alien_gear`：49/49。
- 相关专项（Mac，本工作树，`并行测试.py`，25 个场景，228 秒，全部通过）：`xiyou_tianqi_alien_gear`、`xiyou_alien_affix`、`xiyou_alien_battle`、`xiyou_alien_config`、`xiyou_alien_hide`、`xiyou_alien_workshop`、`xiyou_battle_drop`、`xiyou_drop_record`、`xiyou_determinism`、`xiyou_battle`、`xiyou_random_streams`、`xiyou_tianqi_rewards`、`xiyou_tianqi_seg_alien`、`xiyou_tianqi_war`、`xiyou_tianqi_famine`、`xiyou_tianqi_plague`、`xiyou_tianqi_death`、`xiyou_tianqi_summit`、`xiyou_tianqi_qiyin_altar`、`xiyou_tianqi_qiyin_effects`、`xiyou_tianqi_horsemen_battle`、`xiyou_tianqi_party`、`xiyou_star_warehouse`、`xiyou_item_list`、`xiyou_rules`；合 main 后另跑 `xiyou_tianqi_alien_gear`、`xiyou_tianqi_qiyin_equip`、`xiyou_tianqi_qiyin_dragon_run` 全过。
- 没跑的：`选测.py main --list` 因 `battle_logic.gd` 判整轮 252 个场景；本单在 `battle_logic.gd` 只加一行，只对天启篇存档、有本线异化怪且赢了的战斗起作用（原版档 `plain_none`、开关关掉 `off_none` 两条覆盖），随机数单用一条新流 `tianqi_alien_gear`，不动原有掉落顺序（`xiyou_determinism`、`xiyou_battle_drop`、`xiyou_drop_record` 已过）；其余请总装合并时按选测照常跑。
- 反向验证（`反向验证.py`，单跑本专项）：不看倒下、低级也出共生、刻印不扣石、本体不筛法宝、终焉无本体不给核、分解不按级，6 处全部咬住。
- `语法检查.py`：通过。`工具回归.py`：全部通过（87 秒）。
- `交付自检.py`：提交后跑，见回报。

## 本分支提交

- WIP: 天启篇异化装备（掉落、取核、刻印、净化、族内重抽）与专项
- 合并 main
- 七印装备不当异化本体（认七印标记）；交付单
