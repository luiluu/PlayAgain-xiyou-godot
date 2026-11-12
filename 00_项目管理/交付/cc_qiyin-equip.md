# 交付：cc/qiyin-equip

- 车道／工作者：天启篇·七印祭坛装备接入（揭开生成装备、熔、分解、兑换、献武器）／cc（项目线程「完成再刷西游 Godot 引擎重制」）
- 状态：可合并

## 依赖与合并顺序

- 从 main（dev.489，七印五条、奖励都已合）切出，只依赖已在 main 的 `XTianqiQiyin`、`XTianqiQiyinDrop`、`XTianqiQiyinGear`、`XTianqiQiyinEffects`。
- 和并行的云端车道（七首之龙流程、掉落演出）：本分支在 `tianqi_qiyin.gd` 只改了 `sync`（守层者首杀件记 75 级、末尾调 `claim`）、`run_altar` 循环开头调 `claim`／菜单多一项、`_ask_offering`、`run_dungeon` 扣献的武器（一处）、`_owned_by_seal`、`revealed_label`、`reveal`、`equip_ready`；**没碰 `settle`**。七首之龙给神器／真印件时可以直接用 `XTianqiQiyinEquip.make(desc, 难度, rng)`＋`give(s, item)`，或者照现在把神器键放进 `progress.artifacts`、套装件放进印库，回祭坛时 `claim`／揭开自动生成。

## 变更记录草稿

## 2026-11-12 【cc·七印装备·未经审查】天启篇七印祭坛：揭开生成能穿的装备、熔、分解、印屑兑换、献武器（dev.待定）

- 按设计仓库《天启篇_七印祭坛_里副本套装毕业武器方案 v0.4》第 4.1、5.1、6.1、6.3、6.4 节，接上 cc/qiyin-altar 交付单「未做」的前两条。只在天启篇存档且选了线，发行构建里还要 `XTianqi.RELEASE_OPEN`。
- 新底子表 `modes/xiyou/tianqi_data/qiyin_equip.json`（只读，`draft: true`）：六个部位、12 类武器的同级参照底子（占位）、借图标的原版编号、神器借图标的编号（同骑士遗物 4537）、菜单台词。
- 新模块 `core/tianqi_qiyin_equip.gd`（XTianqiQiyinEquip，开关 `ENABLED`）：
  - 生成：照骑士遗物的做法借原版那件的图标和栏位，属性、特性、原版词缀、备注清空，换成七印的名字、说明、底子；神话品质（`<quality:14>`）、80 级（31、32 层守层者首杀那件 75 级）；武器底子 ×1.1，真印套装件底子 ×1.1，名字前加【真印】。调 `XTianqiQiyinEffects.mark()` 打七印标记，套装件数、流派印记、独有效果、不立文字刻印、神器都由战斗效果模块认。
  - 词条：揭开时按天启篇词条表掷三条（神话三槽，套装件防具组、武器兵器组，四阶）；每槽按难度的层几率抽层，特效最多 2 条、传说最多 1 条，同名不重复，随机系的词条掷系；成色用掉落时掷定的那三条。词条记在装备的七印标记里、写进说明。
  - 揭开：揭开就生成装备进背包，印库里只留封着的（回祭坛时清掉已揭开的）；Boss 掉的神器回祭坛时进背包，放神器栏（`XTianqiGear.allows` 认七印标记）。
  - 套装件不分甲种，谁都能穿（`XActor.can_equip` 一行）。
  - 「已有部位减半」改成认背包和身上的七印套装件，加上印库里封着的。
  - 祭坛菜单多一项「熔炼、分解、兑换」：熔（同印同部位两件、武器同类、真印配真印，副件一条词条换到主件第几条由玩家挑，副件消失，3 个印屑；主件可以穿在身上）、分解（背包里的，套装件 2、武器 10、真印 ×5）、印屑兑换（20 个一件随机部位的套装件，100 个一把自选流派的毕业武器，换来的封着进印库）。判定和数量照 `XTianqiQiyinDrop` 的 `melt_check`／`dismantle_value`／`exchange`。
  - 献武器：进里副本前「献」多一项，从背包挑一把本印毕业武器，进去时拿掉，这一场毕业武器几率翻倍、必是同类（掉落逻辑原有）。
- `qiyin_gear.json` 的 12 类武器填上原版 `System.weaponTypes` 编号（`wtype_id`，加进数字豁免键），`xiyou_tianqi_qiyin_gear` 原来那条「先留 null」改成核对编号对得上原版名字，豁免键名单加 `wtype_id`。
- 新专项 `tests/xiyou_tianqi_qiyin_equip`（104 项）。
- 玩家可见：开发版天启篇存档里，七印祭坛揭开的套装件、毕业武器能穿了（带三条词条），套装件数和流派效果在战斗里生效；祭坛能熔、分解、用印屑兑换，进副本前能献武器；发行版看不到（天启篇关着）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_qiyin_equip.gd` `XTianqiQiyinEquip.ENABLED`；`core/tianqi_qiyin.gd`（揭开、祭坛菜单、献）、`core/actor.gd`（不分甲种）、`core/tianqi_gear.gd`（神器栏）各接一处 | 原版没有七印祭坛装备 | 天启篇存档里七印祭坛揭开的件生成能穿的装备（三条天启篇词条）、熔／分解／印屑兑换、献武器；熔时副件里主件已有的同名词条不给选（同名只生效一条） | Kyo 11-11 定七印祭坛方案，11-12 派车道接装备 | `XTianqiQiyinEquip.ENABLED = false`：揭开只亮成色、不生成装备，祭坛没有熔炼、兑换，献只剩印屑，套装件回到按甲种判 | cc | 已接受（Kyo 11-11 优化直接接受） |

## 交接板

- 下一步：七首之龙接流程（并行云端车道）给的真印件、神器用 `XTianqiQiyinEquip.make`／`give`；天启篇词条的战斗效果（现在只写在说明里，没有模块按词条算数）归词条实装那一步；底子数值进数值阶段再定。
- 用户试玩说明：开发版天启篇档选了线、变量 20 调到 33 回大厅，找 EV048 进七印祭坛：选「揭开封着的」，揭开的件进背包，装备界面能穿（谁都能穿套装件）；穿两件同印的看战斗里 2 件效果；再进「熔炼、分解、兑换」试分解换印屑、20 个印屑换一件；背包里有本印毕业武器时，进副本前「献」能选「献一把」。
- 需要用户决定：①套装件和毕业武器的底子（`qiyin_equip.json` 的 params）是占位，方案只说「比同级神话高一成」，原版 80 级神话装大多靠词缀出数，没有可直接照搬的底子；②神器、套装件借的图标是原版现成的（等美术清单 v0.2 出图再换）。都先按现在的做法继续。

## 进度账

- 天启篇七印祭坛（扩展账）：装备接入 0 → 揭开生成装备、词条、熔／分解／兑换、献武器、神器进神器栏已接；天启篇词条战斗效果、专属武器刻印（方案 6.5 第 2 条）、集齐外观（6.5 第 6 条）、演出、七首之龙流程未做。不写主表。

## 可优化（流程／工具／效率）

- 已做：七印装备的底子、借图标编号、菜单台词全放 `qiyin_equip.json`，换数换图只改表（回退见优化登记）。
- 建议：选测把 `actor.gd` 一律判整轮（本单只在 `can_equip` 加了一行受开关和七印标记门控的判断，也选中 315 个场景）。和 cc/qiyin-altar 交付单提的 `battle_logic.gd` 那条同类，可以一起让 `选测.py` 认「改动行只调 `XTianqi*`」时降档（归工具车道）。

## 验证

- `xiyou_tianqi_qiyin_equip`：104/104；`xiyou_tianqi_qiyin_gear`：234/234（改了两条断言后单跑）。
- 相关专项（Mac，本工作树，`并行测试.py`，45 个场景，1193 秒）：`xiyou_tianqi*`（天启篇全部，含 qiyin 五条、gear、gear2、rewards、party）、`xiyou_determinism`、`xiyou_event_compare*`、`xiyou_equipment`、`xiyou_equipment_clone_state`、`xiyou_formula_equipment`、`xiyou_wtype`、`xiyou_rules` 难度 1 八段（`xiyou_rules`、`xiyou_rules_d1b`～`d1h`）、`xiyou_battle_end_ce`：44 个过，`xiyou_tianqi_qiyin_gear` 挂豁免键名单那条（本分支加了 `wtype_id`），改断言后单跑过；另单跑 `xiyou_equipment_admission` 7/7。
- 没跑的：`选测.py main --list` 因 `actor.gd` 判整轮 317 个场景；本单在 `actor.gd` 只加一行 `XTianqiQiyinEquip.any_class(item)`，只对带七印套装标记的装备成立（原版档、天启篇别的装备都走原判定，专项 `any_class` 两条覆盖），所以只跑上面这组，其余请总装合并时按选测照常跑。
- 反向验证（`反向验证.py`，单跑本专项）：特效层不设上限、熔不过滤同名、熔不扣印屑、分解身上的也收、不分甲种关掉、献武器不拿掉、已有部位不认装备、守层者件不记 75 级，8 处全部咬住。
- `语法检查.py`：0 个问题。
- `工具回归.py`：全部通过（86 秒）。
- `交付自检.py`：提交后跑，见回报。

## 本分支提交

- 2d2834549 WIP: 七印装备生成、熔分解兑换、献武器
- 七印装备专项 xiyou_tianqi_qiyin_equip；守层者首杀件 75 级
- 七印武器豁免键断言、交付单
