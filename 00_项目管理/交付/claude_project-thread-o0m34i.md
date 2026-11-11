# 交付：claude/project-thread-o0m34i（天启篇瘟疫线）

- 车道／工作者：天启篇车道「丙：瘟疫线（混子）」／cc（云端线程「实装天启篇瘟疫线」）
- 状态：可合并（Mac 必跑项见下）

## 依赖与合并顺序

- **基于饥荒线分支 `claude/project-thread-bjkwzm`**（f0cdb05，含四线共用的 XTianqiLine；它又基于 `cc/pro-tianqi-war`、`cc/pro-tianqi-horsemen`）。**先合饥荒线，再合本分支**；直接合本分支会把饥荒线一起带进 main。
- 和死亡线车道并行：共享文件只加了本线的行，冲突留给总装（见下「共享文件」）。
- **按段异化车道（丁，`claude/project-thread-rswno9`）的接口**：本线异化模块照它要的给了 `XTianqiPlagueAlien.apply(logic, s, key, list)` 和 `kinds()`，种类键用它占的位（gland、chaos、taunt、contagion、source），不用改 `seg_alien.json`。那三处入口（`XTianqiLine.alien_apply`、`alien_kinds`、`alien_active`）只在丁的分支里有，本分支没有，**合丁之后请总装各加一行 "plague"**：
  - `alien_apply`：`"plague": return XTianqiPlagueAlien.apply(logic, s, "segment", list)`
  - `alien_kinds`：`"plague": return XTianqiPlagueAlien.kinds()`
  - `alien_active`：末尾加 `or XTianqiPlagueAlien.active(logic)`
- 发行开关 `XTianqi.RELEASE_OPEN` 没动（仍是 false）：发行构建里看不到。

## 变更记录草稿

## 2026-11-11 【cc·未经审查】天启篇瘟疫线（混子）：开场三节、楼层节点、使徒、五种异化与病灶／病弱、生存战与影子（dev.待定）

- 按设计仓库《天启篇四线剧情与关卡设计稿 v0.4》第 2、4.4、5.1、5.5、5.7、9.2 节实装瘟疫线；异化规则按《四线异化与异化装备重构 v0.8》第 2.2、3.4 节，带 4 的测试参数按 v0.4 附录换（挑衅者自身双攻 −33%、双防 +20／30／60／100%）；附录没列的疫源净化失败 40% 照避开 4 改 33%。
- 新数据表 `tianqi_data/plague_line.json`（只读，照 famine_line.json 的格式）：地点与坐标、门、开场步骤、楼层节点、盾碎片、异化级与种类数值、五个预设、全部台词。混子的台词照原稿与第 9.2 节，其余由 cc 照方向补。
- 新模块 `core/tianqi_plague_line.gd`（XTianqiPlagueLine，开关 `ENABLED`）：
  - 开场三节：1「异兆」大厅时空漩涡飘出绿雾 → 七层荒废的猪猪农场（61），侵染·毒腺的野猪头目（敌群 247 第三只），教病灶和病弱；2「蔓延」农场深处，蚀骨·混乱者的「指挥官」拉布（敌群 248 第三只；设计稿写「农场首领名字待查」，cc 选的，待核），雾里有盾的影子喊「不服来打我」；3「天外裂」天外天瘟疫骑士生存战。
  - 使徒：10 层侵染·毒腺、20 层蚀骨·挑衅者、30 层化形·疫源（灵狼祭祀、石日天、玉皇大帝）。15 层黑暗废墟「不服」两个字越写越歪；25 层上行天传闻之后可选捡「混子之盾的碎片」（记 `flags.tianqi.plague.shard`），36 层决战打碎盾要的累计伤害 ×0.67。
  - 35 层影子、36 层决战与结局（「你也不服？」「嗯。」）照 XTianqiLine，地图入口等 31～36 层重做。
- 新模块 `core/tianqi_plague_alien.gd`（XTianqiPlagueAlien）：级同另外两线（生命 ×1.25／×1.5／×2）；毒腺（中毒 3 回合，每回合扣最大生命 3／5／8%，化形起叠 3 层）；混乱者（20／35／50% 混乱 1 回合）；挑衅者（我方单体只能打它、打它的人「不服」物攻魔攻 −20% 2 回合、自己是坦克，化形起群攻打它减半）；传染者（回合末把一人身上的 1／1／2 个减益复制给另一人，化形起 +1 回合）；疫源（减益 +1／+1／+2 回合，我方净化 0／20／33% 失败，化形起净化成功时施放者染上）。线规则「病弱」：我方每个减益八项属性 −3%，上限 −30%。计量「病灶」：我方减益总层数，满 12 爆发一次（中毒立刻结算、混乱多 1 回合）。计量只在战斗日志里报。
- 四骑士（XTianqiHorsemen）：生存战、影子收瘟疫线（`MODE_LINES`）；生存战照本体规则开场即疫病、嘲讽常驻，撑过 6 回合混子「放低了盾」退场；影子每回合一次弱化的「不服来打我」（我方全体 +1 不服，再盾击一人，`horsemen.json` 瘟疫加 `shadow_cry`）；盾碎片让 `_shield_hit` 的阈值 ×0.67。
- `天启篇数据校验.py` 加 plague_line 一组。
- 新专项 `tests/xiyou_tianqi_plague`；`xiyou_tianqi_war`、`xiyou_tianqi_numbers` 里拿瘟疫当「没做好的线」的两处改用死亡线。
- 玩家可见：开发版天启篇存档能选瘟疫线并打完开场三节，之后 10～30 层有混子的声音和使徒；发行版看不到。

### 未做（下一单）

- 终焉效果（毒腺禁疗、混乱 2 回合、传染两次、疫源免疫无效、挑衅全体）和终焉在场时病灶 8、病弱上限 −60%：终焉只给骑士和 31～36 层 Boss，等 31～36 层重做。
- 混乱者化形「混乱的人优先打队友」：要改 XConfusion 的目标选择，没动。
- 减益只数本模块的中毒、不服和 XBossStatus 判为减益的状态、能力弱化；四骑士自己的疫病、不服（XTianqiHorsemen 的标记）不进本线病灶（两边不会同场）。
- 七层农场的异化装饰（菌丝、绿雾色调）、病灶计量条：归画面车道。
- 35、36 层入口、奖励（净印、遗物、生存战额外奖励）：同另外两线。

## 共享文件（每处只加本线的行）

- `core/tianqi_line.gd`：`KEYS` 加 "plague"；`enabled()`、`alien_prepare()` 各加一支；`run_arrival` 加一行 `XTianqiPlagueLine.after_beat`。
- `battle/battle_logic.gd`：setup、开战日志、start_turn、act 末尾、end_turn、targets_for、生命伤害、效果 21（挂状态后）、效果 22（解除前）、end_battle 各一行 XTianqiPlagueAlien。
- `core/actor.gd`：param 链最内层在 `XTianqiHorsemen.actor_param` 外面包一层 `XTianqiPlagueAlien.actor_param`（病弱、不服）。
- `core/tianqi_horsemen.gd`：`MODE_LINES` 加 "plague"；退场台词加一项；影子 decide／perform 加 `defy_cry`；`_shield_hit` 乘盾碎片倍率。`tianqi_data/horsemen.json`：瘟疫加 `shadow_cry`。

## 交接板

- 下一步：先合饥荒线再合本分支；合按段异化（丁）后按上面加三行 "plague"。
- 用户试玩说明：开发版新开天启篇档，通关 5 层回大厅选瘟疫线，会去七层猪猪农场打两场异化战、再到天外天撑 6 回合；之后 10／20／30 层守层者前会听到混子的声音。
- 需要用户决定：无（开场第 2 节首领 cc 选了「指挥官」拉布，想换直接改 `plague_line.json` 的 `presets.spread`）。

## 进度账

- 天启篇（扩展账）：瘟疫线关卡流程、事件、对话、异化 0 → 开场三节、楼层节点、使徒、五种异化、病灶／病弱、生存战、影子已接；终焉效果、35／36 层入口、奖励、画面未做。

## 可优化（流程／工具／效率）

- 建议：三条线的异化模块（战争、饥荒、瘟疫）里 prepare、setup、apply 的级处理、_pick_units、take_logs、end 几乎一样，可抽成共用基类，每线只写种类规则（归天启篇车道，四线做完后做）。
- 发现：`云端准备.sh` 的 `godot --import` 有 900 秒超时，冷缓存时导入到 75% 被杀，要手动再跑一次 `--import`（归工具车道：冷导入时放宽或分两步）。
- 发现：项目文件夹 `天启篇/数值测算/参数.json` 和 `horsemen.json` 对照有 90 项「≠ null」（本分支改动前就有，格式和设计仓库那份不同），校验要用设计仓库的参数.json。

## 在 Mac 上要跑的专项

本分支改了 `battle_logic.gd`、`actor.gd`（战斗核心），`选测.py main --list` 会判整轮。

- 必跑（云端没跑过的标 ＊）：＊`xiyou_rules*`、＊`xiyou_event_compare*`、`xiyou_tianqi_plague`（新）、`xiyou_tianqi_famine`、`xiyou_tianqi_war`、`xiyou_tianqi_horsemen*`、`xiyou_tianqi_numbers`。
- 画面：开发版天启篇档变量 20 调到 6，回大厅选瘟疫线，看七层两场（名字「侵染·」「蚀骨·」，日志里的中毒、混乱、病灶）、天外天生存战第 6 回合混子退场、回大厅后门能进 6 层。

## 验证

云端容器（Godot 4.7.2 Linux，转换产物取自项目文件夹 `云端测试/generated.tgz`）：

- 新专项 `xiyou_tianqi_plague` 98/98。
- （批量结果见下一次提交）

## 本分支提交

- WIP: 瘟疫线数据表、两个模块、共享文件挂钩、专项
- WIP: 专项 98/98（混乱新挂按本线回合、按段异化开战后能力值缓存变冷）
