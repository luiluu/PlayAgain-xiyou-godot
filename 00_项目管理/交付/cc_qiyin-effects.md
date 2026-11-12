# 交付：cc/qiyin-effects

- 车道／工作者：天启篇·七印祭坛战斗效果／cc（云端项目线程「实装七印套装与毕业武器效果」）
- 状态：可合并

## 合并顺序

1. 先合 `cc/pro-qiyin-data`（本分支已把它并进来，`XTianqiQiyinGear` 与 `qiyin_gear.json` 是本车道的唯一数据来源；它先合，本分支合并时这几份文件没有差异）。
2. 再合本分支。和 `cc/pro-qiyin-drop`、`cc/pro-qiyin-dragon` 不碰同一文件，先后都行。
3. `cc/qiyin-altar`（祭坛入口、里副本规则）在本分支之后合最省事：它造装备实例时调 `XTianqiQiyinEffects.mark(inst, 掉落描述)` 打标记，七印书卷揭的规则读 `XTianqiQiyinEffects.enemy_only_rule(logic)`，死期结算时置 `XTianqiQiyinEffects.doom_kill`。

## 变更记录草稿

## 2026-11-12 【cc·未经审查】天启篇：七印祭坛套装、毕业武器、神器的战斗效果（dev.待定）
- 起因：Kyo 11-12「按能力多开车道做天启篇内容」，总装派本车道只做七印祭坛的效果（方案 v0.4 第 4.2、5.2、5.3、6.4 节；数值是占位，照表写）。
- 新增 `modes/xiyou/core/tianqi_qiyin_effects.gd`（`XTianqiQiyinEffects`，开关 O-待定 `ENABLED`）：
  - 只对天启篇存档生效（`XTianqi.active`），发行构建另要 `XTianqi.RELEASE_OPEN`；原版档、开关关着时一条都不跑。
  - 认装备：装备实例上的 `qiyin` 标记（同异化的 `alien` 标记）。`mark(inst, 描述)` 认掉落描述（`{kind, seal, part|wtype, true_seal}`），毕业武器按印＋武器类（键或中文名）找武器键；不立文字没给 `unique` 时从另外 12 把里随机刻一条。专属武器刻印打 `{"kind": "engrave", "key"}`，只带独有效果。
  - 效果一律读 `XTianqiQiyinGear`（`qiyin_gear.json`）的参数；表里没有的手感参数集中在 `TUNE`（群体技能的 scope、疫暴击倍率、连斩上限、舍身门槛、落星元素、补刀上限、默印附带技能号）。
  - 套装按件数开 2／3／5 档；毕业武器带流派印记、真印再带追加、每把一条独有效果；神器全队只生效一件（出战顺序第一个戴的人）。同一效果码一人只生效一条，判决按「被攻击／攻击时」分开。
  - 已接：白印（持续伤害 +20%、看减益加伤、回合末再结算）、红印（群体 +15%、击倒叠层、击倒再动）、黑印（消耗 −15%、砝码、满层必暴）、灰印（斩杀线、背水、免死）、殉印（生命 +15%、替挡一半、被攻击判决）、震印（元素 +15%、换系叠层、每 3 回合放两次）、默印（治疗 +20%、庇护、附带技能的效果函数）；七个流派印记、真印追加、13 条独有效果；弓与冠、夺和大刀、天平、灰镰的效果与代价。
- 接入（各一行）：`battle/battle_logic.gd` 开战、回合开始／结束、行动开始／结束、连击段数、死目标转段、每次 apply 前后、扣血入口、技能消耗、暴击率、沉默不能用技能、战斗结束；`core/actor_damage_hooks.gd` 伤害乘区（`damage_ops`，写入清单加 `healingMultiplier`）；`core/actor.gd` 最大生命倍率；`core/battler.gd` 灰镰不能复活。
- 新专项 `tests/xiyou_tianqi_qiyin_effects.tscn`。
- 玩家可见：无（天启篇还没开放；七印装备要等祭坛与掉落接入后才拿得到）。
- 未完成／已知问题：见下「交接板」。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_qiyin_effects.gd` `XTianqiQiyinEffects.ENABLED`；`battle/battle_logic.gd`、`core/actor_damage_hooks.gd`、`core/actor.gd`、`core/battler.gd` 各一行接入 | 原版没有七印祭坛装备 | 天启篇存档里七套套装、13 把毕业武器、5 件神器的战斗效果（方案 v0.4，数值占位） | Kyo 11-11 定七印祭坛方案，11-12 派车道实装 | `XTianqiQiyinEffects.ENABLED = false`：七印装备在战斗里没有效果 | cc | 保留 |

## 交接板

- 下一步：
  - 祭坛／掉落接入时用 `XTianqiQiyinEffects.mark()` 给装备实例打标记（套装件放头、甲、手、腰、裤、鞋，毕业武器放武器格，神器放类型 17 的神器栏，神器栏白名单要加这 5 件）。
  - 默印 5 件「附带技能」要在数据库里分配一个技能号，填 `TUNE.silence_skill_id`，技能效果调 `use_silence_all(logic, u)`（现在函数和沉默判定都做好了，没有技能入口）。
  - 七印书卷揭的规则只记在 `enemy_only_rule(logic)`，规则本身由里副本规则车道（cc/qiyin-altar）按「只对敌方」实现。
  - 灰印 5 件「对死期无效」：死期结算方在结算前后置 `XTianqiQiyinEffects.doom_kill`。
  - 数值阶段按方案第 7 节预算反推套装和武器的数，改 `qiyin_gear.json`（本车道代码不写死数）。
- 用户试玩说明：无（本轮没有玩家能看到的变化）。
- 需要用户决定：无（下面几处口径按默认做了，Kyo 想改直接说）：
  - 白印 2 件、5 件的「持续伤害」只算七印的「疫」，原版状态类持续伤害（XExtDot）不吃。
  - 「目标身上的减益」按能力减益每项一种＋疫＋元素抗性降低＋少动一次算，原版状态不分好坏、暂不算。
  - 战流派「攻击次数 +1」对所有伤害技能生效（不只普攻）；「最后一段翻倍」认非行动序列技能的每个目标最后一段。
  - 判决、落星、溢出、处决、疫按「真实伤害」直接扣（护盾先吸收），不吃增伤和防御；落星每次行动最多掷一次。
  - 击倒后再行动：红印 5 件、灰真印、夺和大刀同名只算一条，每回合一次。
  - 无字「普攻算技能」只让普攻吃七印自己的技能类加成（天平、群体），原版被动的技能伤害加成还不吃。

## 进度账

- 天启篇扩展账：七印祭坛「战斗效果」完成第一版（全部效果码都有实现或接口，默印附带技能缺技能号）；不写主表。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 云端容器（Godot 4.7.2 headless，转换产物是项目文件夹里 10-18 的旧快照）：
  - 新专项 `xiyou_tianqi_qiyin_effects`：48/48。反向验证（手改后用备份还原）：伤害乘区不出 `finalMultiplier`、击倒不插队，各掉 6 项，还原后 48/48。
  - 相关旧专项 `xiyou_tianqi_qiyin_gear`、`xiyou_tianqi_swap_init`、`xiyou_tianqi_gear` 全过；`xiyou_determinism` 370/370。
  - `xiyou_actor_modules`（raven.advance_rows）、`xiyou_module_hooks`（view.same_source、oracle.exists）、`xiyou_tianqi_party`（all_draws）各有失败，把四个接入文件换回 origin/main 原样再跑，失败项一模一样，是云端旧产物、没有参照数据的环境差异；另各场景都有 `XDB: 读取失败 db/CodexMerchants.json`（旧快照缺文件），并行测试因此判失败。
- **需要总装在 Mac 上跑**：改了 `battle_logic.gd`，`选测.py origin/main --list` 选中 360 个场景（等于整轮），云端容器跑不动也没有新产物；请按影响面跑选测（至少 `xiyou_rules*`、`xiyou_determinism`、`xiyou_module_hooks`、`xiyou_actor_modules`、`xiyou_tianqi*`、`xiyou_status_power_panel`）。非天启篇存档每个钩子都早退，原版对照不应有变化。
- 没跑：`工具回归.py`（云端没 zsh 固定挂 3 项，与本分支无关；本分支没改工具和检查）、`同步正式西游.py`（没改切片、转换器、探针）。
- `.uid`：只提交本车道两个新脚本的；数据层 `tianqi_qiyin_gear.gd.uid`、`xiyou_tianqi_qiyin_gear.gd.uid` 照它的交付单留给总装。

## 待交叉核查

- 甲档（战斗核心）：`battle/battle_logic.gd`（14 处一行接入，`execute` 的目标循环改成可转段）、`core/actor_damage_hooks.gd`、`core/actor.gd`、`core/battler.gd`；`core/tianqi_qiyin_effects.gd` 全文；`tests/xiyou_tianqi_qiyin_effects.gd`。
- 重点：非天启篇存档每个钩子都是早退（原版对照不应有任何变化）；`damage_ops` 只在 `XAlienBattle.active_logic()` 带本模块数据时出操作，`end_battle` 清数据。

## 本分支提交

- 合并 `origin/cc/pro-qiyin-data`（数据层，先合它）
- WIP 与收尾提交：效果模块、战斗接入、专项、交付单
