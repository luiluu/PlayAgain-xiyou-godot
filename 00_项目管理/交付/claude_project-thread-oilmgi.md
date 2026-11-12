# 交付：claude/project-thread-oilmgi

- 车道／工作者：天启篇·七首之龙流程与七印演出／cc（云端项目线程「实装七首之龙流程与掉落演出」）
- 状态：可合并

## 依赖与合并顺序

- 从 main（dev.489，e3df19b）切出；只依赖 main 上已有的 `XTianqiQiyin`（cc/qiyin-altar）、`XTianqiQiyinDragon`（cc/pro-qiyin-dragon）、`XTianqiQiyinDrop`、`XTianqiQiyinGear`、`XTianqiQiyinRule`。
- **和并行的「七印装备化与熔炼兑换」车道（Mac）**：两边都可能碰 `core/tianqi_qiyin.gd`。本分支在那里只加了 7 行单行挂钩（`run_altar` 的 match 加一个 `_:` 分支、`altar_options` 在「离开」前加一行、`run_dungeon` 结算前后各一行、`settle` 掉落／神器／当场揭各一行、`run_reveal` 一行），都紧挨原行；冲突时两边并排保留即可。另在 `core/actor.gd` 第 604 行（`param_rate` 那一长行）末尾乘了 `XTianqiQiyinDragonRun.param_rate`，若装备车道也改这一行，保留两边的乘项。
- `battle/battle_logic.gd` 加 4 行，都紧挨七印规则的行（setup、start_turn、end_action、execute_hp_damage 账本）。
- 发行开关 `XTianqi.RELEASE_OPEN` 没动：发行版天启篇整个不开，龙隙也不出（KYO RULE 11-12：天启篇只进 main，不推玩家）。

## 变更记录草稿

## 2026-11-12 【cc·七首之龙·未经审查】天启篇七首之龙：龙隙、七段揭印战、奖励与龙血、首杀招募；七印掉落／揭开／龙隙演出（dev.待定）

- 按设计仓库《天启篇_七印祭坛_里副本套装毕业武器方案 v0.4》第 3.1、6.1（第 6 条）、6.4 节和《七印祭坛美术素材清单 v0.2》（S1、P1～P6、E1）。只在天启篇存档且选了线，发行构建里还要 `XTianqi.RELEASE_OPEN`；西游原版档一处不动。
- 新模块 `core/tianqi_qiyin_dragon_run.gd`（XTianqiQiyinDragonRun，开关 `ENABLED`）＋流程表 `tianqi_data/qiyin_dragon_run.json`：
  - 龙隙：里副本 Boss 打赢后、结算之前调 `XTianqiQiyinDragon.roll_rift`（寻常 3%～证道 10%，连空 30 次必出）；出了先演「地面裂开、七道印一起灭」，掉落照常结算，再当场问「进去／先存着」。存着的龙隙在祭坛菜单多一项「进龙隙」；不要印钥，输了合上。
  - 战斗：借 19 层副本古龙祭坛的普拉顿（敌群 221、敌人 238）换名「七首之龙」，生命取 `fight_data` 的本档最大生命（艰险 250 万），能力值按里副本参照敌人（537）× 测试倍率，每回合 3 次行动，不掉东西、不给经验。生命分七段：开场揭白印，每断一首揭下一道印（`XTianqiQiyinRule` 的七条规则照用、敌我都算），第六首断掉揭默印；一次行动的伤害最多打到本段底（每道印都要打一段）。灰印那段给我方随机一人挂「缓期」，2 回合后倒下，之前再断一首就解除。战斗日志报揭印、断首、缓期。
  - 奖励（`XTianqiQiyinDragon.reward`）：先选一印（七印都能选），给该印真印套装件（部位随机，成色全「极」）、龙血 1 瓶、33% 真印毕业武器（类型在该印里随机）、3% 神器；东西照里副本进印库（封着、红光），可以当场揭。首杀多招一人：当场在祭坛按本档 30 层那一档的招募表（`XTianqi.DRAW_TABLE` 第 6 次）抽，可以「稍后再选」，留到下次开祭坛（菜单「龙的馈赠」）；候选掷定不重抽。
  - 龙血：祭坛菜单「龙血（N 瓶）」给一名角色喝，全属性 +3%／瓶，每人最多 3 瓶（`XActor.param_rate` 乘 `XTianqiQiyinDragonRun.param_rate`）。只在本档。
- 新模块 `core/tianqi_qiyin_show.gd`（XTianqiQiyinShow，开关 `ENABLED`）＋参数表 `tianqi_data/qiyin_show.json`（七印颜色照美术清单主色、借原版 SE、时长）：套装件掉落闪本印色＋印徽；毕业武器全屏压暗定格；真印红边＋震屏；神器整屏变暗、七道印依次亮起、亮出神器大图；揭开时封印碎开（真印再加红光小震）；龙隙裂缝＋七印一起灭＋震屏。美术没到先由引擎画占位（色块圆印、文字、折线裂缝）；图放进 `res://content/tianqi/qiyin/`（`seals/<印>.png`、`artifacts/<神器键>.png`、`rift.png`）就自动换上。
- 挂钩：`core/tianqi_qiyin.gd`（祭坛菜单、run_dungeon、settle、run_reveal 各一行）、`battle/battle_logic.gd`（setup、start_turn、end_action、伤害账本各一行）、`core/actor.gd`（param_rate 乘龙血）。
- 新专项 `tests/xiyou_tianqi_qiyin_dragon_run`。
- 玩家可见：开发版天启篇存档（选了线）打赢里副本 Boss 时有小概率祭坛裂开、出龙隙，进去打七首之龙（七段、每段一条里副本规则），赢了拿自选印的真印套装件和龙血，首杀多招一个伙伴；掉落和揭开有了演出（闪印色、定格、红光震屏、七印亮起）。发行版看不到（天启篇关着）。

### 未做（下一单）

- 七首之龙新画（美术 E1，七个头拆件、断一首藏一个头）：现在借普拉顿外观，断首只在战斗日志里报；新画到了要在战斗场景里按 `XTianqiQiyinDragonRun.fight(logic).cut` 藏头。
- 七首之龙的专属招式：现在照普拉顿的行动；数值（攻击、防御）是测试倍率（`qiyin_dragon_run.json` 的 `fight.rate`），进数值阶段按「36 层普通首领一击约 8.5 万」校。
- 战斗里的规则状态图标（美术 O1、O2，含「缓期」「龙血」）：可选项，没画。
- 神器拿到后进神器栏、龙血之外的装备生效：归装备化车道（这里只照里副本进印库、记 `artifacts`）。
- 演出的专属音效：先借原版 SE（Saint3、Sword5、Thunder9、Saint5、Break、Earth5），要换改 `qiyin_show.json`。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/tianqi_qiyin_dragon_run.gd` `XTianqiQiyinDragonRun.ENABLED`；`core/tianqi_qiyin.gd`、`battle/battle_logic.gd`、`core/actor.gd` 单行接入 | 原版没有七首之龙 | 天启篇存档里里副本 Boss 打赢后小概率出龙隙，七段揭印的七首之龙战、真印奖励、龙血、首杀多招一人（方案 v0.4 第 3.1 节，数值占位） | Kyo 11-11 定七印祭坛方案，11-12 定稿并派车道 | `XTianqiQiyinDragonRun.ENABLED = false`：不判龙隙、菜单不出、龙血不加成（已存的留在存档里） | cc | 保留 |
| O-待定-2 | `modes/xiyou/core/tianqi_qiyin_show.gd` `XTianqiQiyinShow.ENABLED`；`core/tianqi_qiyin.gd` 单行接入 | 原版没有七印掉落 | 七印掉落、揭开、神器、龙隙的演出（闪印色、定格、红光震屏、七印亮起、裂缝），缺图引擎占位 | 方案 v0.4 第 6.1 节第 6 条「演出实装时不要省」 | `XTianqiQiyinShow.ENABLED = false`：不演出，文字照出 | cc | 保留 |

## 交接板

- 下一步：美术 E1（七首之龙拆件）、S1、P1～P6 到了放进 `content/tianqi/qiyin/`；E1 到了在战斗场景按断首数藏头；数值阶段校 `qiyin_dragon_run.json` 的 `fight.rate`。
- 用户试玩说明：开发版天启篇档选了线、变量 20 调到 32 进七印祭坛打里副本；想马上见龙，可以在存档里把 `flags.tianqi.qiyin.dragon.misses` 改成 30，下一次打赢 Boss 必出龙隙。
- 需要用户决定（都先按现在的做法继续）：①七段怎么揭：现在「开场就揭白印、第六首断掉揭默印」，一场把七条规则都过一遍（方案「一场打完等于把七个里副本的规则依次过一遍」）；方案表格的字面是「第 i 首断掉揭第 i 道印」，那样默印要到龙倒下才揭、等于不生效。`fight.open_reveal = false` 可切回字面。②一次行动最多打到本段底（每道印都要打一段，不能一下跳过几段）；`fight.segment_lock = false` 可关。③首杀招募当场在祭坛抽（方案写「回大厅额外抽一次」），省一趟；④奖励的自选印七印都能选（含还没揭开的）。

## 进度账

- 天启篇七印祭坛（扩展账）：七首之龙流程 0 → 龙隙（判定、演出、当场问、存放）、七段揭印战、缓期、奖励进印库、龙血、首杀招募已接；七印掉落／揭开／神器／龙隙演出已接（缺图占位）。未做：七首之龙新画拆件、专属招式、数值校准。不写主表。

## 可优化（流程／工具／效率）

- 已做：龙的战斗搭法、台词全放 `qiyin_dragon_run.json`，演出的颜色、音效、时长、美术路径全放 `qiyin_show.json`，美术到了只放文件不改代码（回退：两个模块的 `ENABLED = false`）。
- 已做：龙隙判定和龙的奖励用自己的随机流（`XTianqiQiyinDragonRun.rng_override`；祭坛专项注入测试流时用固定种子），不动祭坛那条流的消耗，祭坛专项不受影响。

## 验证

- 新专项 `xiyou_tianqi_qiyin_dragon_run`：90/90（云端，连跑三次都过）。覆盖：数据（数字 4、借的敌群敌人、七印颜色、SE 在）；龙隙（暗保底必出、演出、存着、菜单、输了合上、开关关掉不判）；接在 run_dungeon 里（龙隙演出在掉落之前、固定种子掷不中时流程照旧）；战斗（换名、本档最大生命、3 次行动、不带普拉顿的 `<hp>`／掉落／捕获标签、不被按段异化、开场揭白印、段底锁、断首揭印、一下连断几首、缓期到点倒下／断首解除、第六首默印、字面口径开关、炼狱生命、没 prepare 的普拉顿照旧）；奖励（自选印真印件进印库、龙血、首杀招募只一次、当场揭、武器和神器物品格式、稍后再选不重抽、30 层那一档）；龙血（3 瓶上限、+9%、能力值真的变、开关关掉）；演出在真的场景节点上跑一遍（闪屏、震屏、SE、层释放）；原版档一概不动。
- 七印相关专项（云端）：`xiyou_tianqi_qiyin_dragon` 92/92、`_drop` 151/151、`_gear` 234/234、`_effects` 48/48、`_altar` 170/173（3 项是云端转换产物旧、没有 Map085／156／157，main 上同样 170/173）。
- 和 main 逐项对比（云端，同一份转换产物，先跑本分支、再把三处挂钩文件换回 main 版本跑同一批）：`xiyou_tianqi*` 27 个、`xiyou_determinism`（370/370）、`xiyou_event_compare`／`_b`／`_c`／`_d`、`xiyou_rules`、`xiyou_rules_d1b`、`xiyou_battle_end_ce` 共 35 个场景，**每个场景通过数和失败项与 main 完全一致**。云端那份转换产物是 10-18 的 v0.28（缺 v0.62 的地图、CodexMerchants 等），所以事件对照、rules、几条天启篇专项在两边都有同样的失败，不是本分支带来的；请总装在 Mac 上按选测照常跑（`选测.py` 因 `battle_logic.gd`、`actor.gd` 判整轮）。
- `语法检查.py`：0 个问题。
- `工具回归.py`：17/18，挂的「选测替身与 检查.sh 解析」是云端 Linux 的 `mktemp` 模板差异（`too few X's in template`），本分支没改工具。
- 本分支的挂钩全受门控：七首之龙只在 `prepare` 过的那场生效（`XTianqiQiyinDragonRun.active`），龙血只在有 `flags.tianqi.qiyin.dragon.blood` 的天启篇档生效，演出只在祭坛流程里调。

## 本分支提交

- d6c5c86 七首之龙流程、七印演出、祭坛与战斗挂钩、专项
