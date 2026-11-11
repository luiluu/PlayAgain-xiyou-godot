# 交付：claude/project-thread-bjkwzm

- 车道／工作者：A 内容·楼层＋C 规则／cc（云端线程「推进天启篇内容实装」，天启篇四线车道甲·饥荒线）
- 状态：可合并

## 依赖与合并顺序

- **依赖 `cc/pro-tianqi-war`（战争线，它又依赖 `cc/pro-tianqi-horsemen`），都未合 main**：本分支从 `cc/pro-tianqi-war` 头 504b0af 切出。
- **合并顺序：`cc/pro-tianqi-horsemen` → `cc/pro-tianqi-war` → 本分支。** 直接合本分支会把前两支一起带进 main（它们的交付单也在本分支里）。
- **周六整包出完前不合 main**（协调 11-11）。发行开关 `XTianqi.RELEASE_OPEN` 没动（仍是 false）：发行构建里天启篇整个不开，本分支的饥荒线、序幕、按线分派的门和楼层节点都只认天启篇存档且发行已开放。

## 变更记录草稿

## 2026-11-11 【cc·天启篇四线·未经审查】天启篇饥荒线（小镇做题家）：四线共用流程 XTianqiLine、开场三节、吕茂序幕、使徒、五种异化与饥饿／口粮、生存战与影子（dev.待定）

- 按设计仓库《天启篇四线剧情与关卡设计稿 v0.4》（Kyo 11-11 09:41 第 8 节全部定完，「首期先做饥荒线」，原身是三层的吕茂）第 4.3、5.1、5.4、5.7 节实装饥荒线；异化规则按《四线异化与异化装备重构 v0.8》第 2.2、3.3 节（口粮、绝粮 Kyo 11-08 已确认）。
- **四线共用流程 `core/tianqi_line.gd`（XTianqiLine）**：照战争线交付单「可优化」的建议，把 XTianqiWarLine 里和线无关的部分（进度 `flags.tianqi.<线>`、门锁、台词、开场、10／20／30 层使徒、楼层节点、35／36 层）抽出来，每条线只给一张 `tianqi_data/<线>_line.json` 和本线的异化模块。开场改成表里的步骤（`opening`：`say`／`go`／`fight`，最后一节固定是天外裂生存战），楼层节点改成表里的 `beats`。`XTianqiWarLine` 留成薄壳（开关和原来的调用名都在，转给 XTianqiLine），`war_line.json` 加 `opening`、`beats` 两项，战争线行为不变（专项照过）。地图场景的门、换图节点、开战前使徒改调 XTianqiLine，按本档的线分派；选线 `XTianqi.line_playable` 改看 `XTianqiLine.playable`，选定后统一走 `XTianqiLine.on_chosen`。
- 新数据表 `tianqi_data/famine_line.json`（只读）：地点与坐标、开场步骤、五个异化预设、模拟考三道题、全部台词。吕茂的「噫~我中了！」「今日方知我是我」「再刷一套就够了」照原稿／设计稿；其余是 cc 照第 4.3 节方向补的（标在表的 `_note` 里）。
- 新模块 `core/tianqi_famine_line.gd`（XTianqiFamineLine，开关 `ENABLED`）：
  - 开场三节（选定饥荒线后接着跑；前两节可输，输了回大厅，再走大厅的门接着打）：第 1 节「异兆」三层训练场（6），侵染·枯竭者的哥布林巫师（敌群 11 第一只，十分罕见），教饥饿和口粮；第 2 节「蔓延」伐木者小屋（126），节末精英蚀骨·荒年者的光头强（敌群 430；设计稿写首领名字待查，cc 选的，待核），打完回头孩子不见了、只剩答题卡；第 3 节「天外裂」天外天（借 158），饥荒骑士生存战。
  - 序幕：天启篇存档第一次到三层训练场，吕茂在做题（「再刷一套就够了。」），所有线都有；饥荒线通关后再到三层说一次「这次我慢慢做。」
  - 使徒：10 层侵染·枯竭者（灵狼祭祀）、20 层蚀骨·掠夺者（石日天）、30 层化形·透支者（玉皇大帝），开战前放「饥荒骑士的声音」。15 层黑暗废墟的卷子回声、25 层上行天的传闻，各一次；25 层传闻后可选「模拟考」三道题，答对题数记 `flags.tianqi.famine.quiz`（余粮还没有物品，先只记分）。
  - 35 层影子、36 层决战与结局（`run_shadow`／`run_final`，赢了记通关和可轮回、放「我是改卷子的」）：和战争线一样，地图上还没有入口（等 31～36 层重做车道）。
- 新模块 `core/tianqi_famine_alien.gd`（XTianqiFamineAlien）：饥荒线异化怪的战斗规则，只给上面几场用（`prepare` 预约，没预约的战斗一概不动）。级同战争线（生命 ×1.25／1.5／2／3，名字前加「级·」）；种类：枯竭者（我方 MP／TP 消耗 +30／50／80／120%，化形起生命消耗也提高）、荒年者（我方受到的回复 −20／30／50／70%，化形起再生失效）、掠夺者（命中夺目标 5／10／15／25% 的 MP、TP，化形起转成自己的护盾）、熬夜者（我方 TP 获得 −30／50／70／100%，化形起每回合结束 TP −10）、透支者（每放一次技能另扣 2／3／6／10% 当前生命，化形起按最大生命；第 2 档照「避开 4」从 4% 改 3%）。饥饿：消耗倍率、回复倍率由场上饥荒异化怪相加，开战和每回合开始在战斗日志里报。口粮：零消耗技能（原生攻击、防御除外）每次扣最大 MP 的 3／5／8／12%（按场上最高级），MP 不够扣同样比例的当前生命（不会扣死）。
- 挂钩：`battle_logic.gd`（setup、开战日志、回合开始、`skill_cost` 最外层、`skill_hp_cost`、`pay_skill_cost` 付费后、两处静默 TP 获得、`_regenerate`、`execute_hp_damage`、行动后日志、回合结束、结束战斗各加一行）、`resource_context.gd`（`_gain` 里降回复）。`skill_cost` 原来的函数体改名 `_skill_cost_floor`，外面包一层；面板（`panel=true`）不动。
- 四骑士（`tianqi_horsemen.gd`、`horsemen.json`）：生存战、影子加饥荒线。生存战开场即绝粮，3 只「饿出来的小怪」借三层伐木场的伐木哥布林 514 原数值 × 本档敌人倍率，骑士吃它们来打你，资历照涨、没有突破，撑过 6 回合「合上了卷子」退场；影子每回合一招题海战术，带绝粮，没有小怪。`survival` 一节加 `add_enemy_famine`。
- `天启篇数据校验.py`：战争线的检查推广到全部 `<线>_line.json`（`line_rules`：另查开场步骤用到的台词、地图、坐标、预设都在表里，楼层节点有图有台词），加 famine_line 一组。
- 新专项 `tests/xiyou_tianqi_famine`；`xiyou_tianqi_war` 两处跟着改（饥荒线现在能选；门锁「没有能选的线」要两条线都关）。
- 玩家可见：开发版天启篇存档到三层能看到吕茂做题；通关 5 层后选线里饥荒线也能选，接着打三层、伐木者小屋两场饥荒异化战和天外天的生存战，之后 10～30 层有饥荒骑士的声音和使徒、15／25 层有剧情和模拟考；发行版看不到（天启篇关着）。

### 未做（下一单）

- 1～30 层按段异化（车道丁在做）：普通楼层的怪还不会异化；熬夜者只在规则和专项里，没有固定出场的战斗（11～15 层按段异化才教）。
- 35、36 层入口（车道戊 31～36 层重做）：到时在 35、36 层的事件里调 `XTianqiLine.run_shadow`／`run_final`（本档的线）。
- 饥荒细则：减耗、免耗效果打折；自带资源角色（层数、点数）的获得量降低（要逐个角色模块接）；荒年的掉落减少与余粮（没有物品）；各种类的终焉效果（终焉只给骑士和 31～36 层 Boss）；绝粮下「消耗再提高一档」和口粮 12%（四骑士本体战里还没接，本分支只接了异化战）。
- 奖励：净印·存粮、骑士遗物「没写完的卷子」、生存战撑过的额外奖励（`survived` 已记），等装备栏和词条出包后的奖励车道。
- 画面：饥饿计量条（现在只在战斗日志里报）、方桌裂纹的旧纸黄、楼层异化色调和空碗、试卷装饰、吕茂骑士形态的立绘。

## 交接板

- 下一步：先合 `cc/pro-tianqi-horsemen`、`cc/pro-tianqi-war`，再合本分支（周六整包之后）；死亡线（乙）、瘟疫线（丙）从本分支切，照 famine_line.json 的格式各加一张表和一个异化模块；按段异化（丁）、31～36 层重做（戊）做完后接各线 35、36 层入口和按段异化。
- 用户试玩说明：开发版新开天启篇档，路过三层会看到吕茂做题；通关 5 层回大厅抽完角色后选饥荒线，接着打三层训练场、伐木者小屋两场饥荒异化战（战斗日志里报饥饿和口粮）和天外天的生存战；之后到 10／20／30 层守层者前会听到饥荒骑士的声音，25 层能做模拟考。
- 需要用户决定：无（台词是 cc 照设计稿第 4.3 节起草的，Kyo 想改直接改 `famine_line.json`；第 2 节首领用光头强、透支者第 2 档 3% 是 cc 定的，待核）。

## 进度账

- 天启篇（扩展账）：饥荒线关卡流程、事件、对话 0 → 开场三节、序幕、楼层节点、使徒、模拟考、生存战、影子、五种异化已接；35／36 层入口、按段异化、奖励、画面未做。四线共用流程 XTianqiLine 抽出（战争线改走它）。

## 可优化（流程／工具／效率）

- 已做：四线共用流程 XTianqiLine，另外两条线只要一张表、一个异化模块和几行登记（回退：关 `XTianqiFamineLine.ENABLED`／`XTianqiWarLine.ENABLED`；整块回退把 `XTianqiWarLine` 换回 cc/pro-tianqi-war 的版本）。
- 已做：云端线程跑专项用轻量工程（不带 img／audio／movies，generated 其余用链接），导入约 40 秒；整份工程导入在容器里 15 分钟只到 35%。
- 建议：XTianqiWarAlien 和 XTianqiFamineAlien 的「级」「挑敌人」「名字前缀」「日志队列」是同一套，死亡、瘟疫线开工前可以抽一个 XTianqiAlienBase（归四线车道，按段异化车道丁会用到同一个入口）。

## 在 Mac 上要跑的专项

本分支改了 `battle_logic.gd`（技能消耗、付费、再生、TP 获得、伤害）、`resource_context.gd`（回复）和 `map_scene.gd`，`选测.py main --list` 会判整轮。云端只跑了下面「验证」里列的，**合并前请在 Mac 上跑**：

- 必跑（云端没跑过的标 ＊）：＊`xiyou_rules*`、＊`xiyou_event_compare*`、`xiyou_tianqi_famine`（新专项）、`xiyou_tianqi_war`、`xiyou_tianqi_horsemen`、`xiyou_tianqi_horsemen_battle`、`xiyou_tianqi_numbers`、`xiyou_determinism`、`xiyou_alien_battle`。
- 战斗核心、地图整组：`选测.py main --list` 列出的组，或直接 `检查.sh --full`。
- 画面（云端没有画面）：开发版新开天启篇档，到三层看吕茂的两句；把变量 20 调到 6 回大厅选饥荒线，看三层、伐木者小屋两场异化战（名字「侵染·」「蚀骨·」，战斗日志里的饥饿、口粮）、天外天生存战（饿出来的小怪被吃、第 6 回合后骑士退场）、回大厅后门能进 6 层。

## 验证

云端容器（Godot 4.7.2 Linux，转换产物取自 `refs/ci/generated/main`，轻量工程：不带 img／audio／movies）：

- 新专项 `xiyou_tianqi_famine` 99/99；`xiyou_tianqi_war` 96/96（XTianqiLine 抽出后照过）。
- `并行测试.py` 一批 40 个：38 个过（`xiyou_tianqi_*` 14 个、`xiyou_alien_battle`、`xiyou_alien_affix`、`xiyou_boss_lifecycle`、`xiyou_boss_output`、`xiyou_boss_status`、`xiyou_action_sequence`、`xiyou_actor1_damage`、`xiyou_attack_query`、`xiyou_battle_pace`、`xiyou_lobby_corruption`、`xiyou_map_dispatch`、`xiyou_regen_popup`、`xiyou_battle_gaps`、`xiyou_challenge_passives`、`xiyou_guyu`、`xiyou_imported_balance`、`xiyou_loose_fixes`、`xiyou_mira_battle`、`xiyou_nanoha`、`xiyou_race_battle`、`xiyou_shield`、`xiyou_skill_mastery`、`xiyou_sukuna_battle`、`xiyou_target_eval`、`xiyou_tusu_battle`、`xiyou_wtype`、`xiyou_smart_ai`）。
- 2 个失败是轻量工程的环境差异，不是本分支：`xiyou_determinism` 只挂 `real_animation_audio`（轻量工程没有音频）；`xiyou_tianqi_title_flow` 只挂触屏读档 `tc_loaded`，在没改过的 `cc/pro-tianqi-war` 上同样的轻量工程也挂（两次各挂 1～2 项）。请在 Mac 上照常跑。
- `天启篇数据校验.py` 全过（war_line、famine_line 规则自检；horsemen 对照参数这次没给 `--params`）。
- 没跑全量 `检查.sh`（车道规则）；`xiyou_rules*`、`xiyou_event_compare*` 云端跑不了，见上「在 Mac 上要跑的专项」。

## 本分支提交

- 53031ff WIP: 四线共用 XTianqiLine（战争线改走它）、famine_line.json、XTianqiFamineLine／XTianqiFamineAlien、生存战与影子、专项
- f0cdb05 WIP: 口粮豁免按整数比；专项跑通
- 本次：交付单可合并
