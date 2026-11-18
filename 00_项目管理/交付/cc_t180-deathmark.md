# 交付：cc/t180-deathmark

- 车道／工作者：C 规则·机制／cc 车道（Opus＋medium，P8），T180＝T086-b 死期认人＋画面守卫
- 状态：可合并

## 变更记录草稿

## 2026-11-18 【cc·T180·未经审查】T086-b 死期认人＋画面守卫：死期跟着人走，换到助力位照样到点死，倒下演出目标没图只记日志（dev.待定）

- 依据：私密设计仓 `重制设定/天启篇_发作真换人_v0.2.md`（c285c65）第二节第 1～3 件、第三节第 5 条、第十节 T086-b、第十三节 P1-3／P2-1／P2-2；D201 第 2 件。
- **先复现**：main（9b0112d24）上用真战斗画面（死亡线宣判者 omen，敌群 291）给一人挂宣判者死期，手动换到助力位，回合末 `_play` 当场报错：
  `SCRIPT ERROR: Invalid access to property or key '<RefCounted#…>' on a base object of type 'Dictionary'. at: XBattleScene._play (res://modes/xiyou/battle/battle_scene.gd:2212)`（倒下演出 `sprites[l.target]`，被换下去的人已经没有图）。修后同一步只打一行 `[战斗画面] collapse 的目标 … 不在场上（没有角色图），只记日志不演出`，人照样倒下。
- `core/tianqi_horsemen.gd`：新开关 `DOOM_FOLLOW`（O-待定-1，默认开）；`doom_people(logic)`＝场上 actors＋不在场上的助力位；四骑士回合末在场上那一轮之后再扫被挂死期、不在场上的人（到点照样死、报「…的死期到了」、记不能复活；灼烧、疫病这些持续掉血照现行只扫场上，日志次序对场上的人不变）；35 层影子「死去的人本场不能复活」认 5 个人；新 `lose_revive(s)`：允许失败的战斗打输后复活到 1 血扫出战成员＋助力位。
- `core/tianqi_death_alien.gd`：新开关 `DIE_ENTRY`（O-待定-2，默认开）：死期、丧钟、替身带走人统一走倒下入口 `logic._die`（免即死照旧先判；倒下入口只因死亡抵抗特性没加上阵亡时仍直接加；谷雨代命、云裳衣魂、五条悟试炼兜底这些倒下包装现在起作用，同四骑士死期）；收尸人 `_scan_deaths` 扫 5 个人（死在助力位照喂，设计稿「我定的一条」）；「不能复活」认 5 个人（跟 `DOOM_FOLLOW`）。
- `core/tianqi_qiyin_dragon_run.gd`：只补注释——灰印缓期是「到点就死」三种之一，本来就记人（被换到助力位照样到点倒下，走 `logic._die`、不发倒下演出），打输复活由 `lose_revive` 扫到。
- `battle/battle_scene.gd`：画面守卫 `_offstage_target`：倒下、掉血弹字（regen）、熟练度动画、谷雨特效这四类记录的目标没有角色图时只打日志、不演出（不设开关，设计稿第九节）；打输复活改调 `XTianqiHorsemen.lose_revive`。
- 场上被宣判者死期带走的表现（设计稿第九节风险 11）：专项 `entry_onfield_*` 开关两边对比，倒下、阵亡状态、生命 0、倒下演出记录、「死期：…倒下了」日志、收尸登记都一样；差别只在带倒下包装的角色（谷雨、云裳、五条悟试炼）现在会被包装接住，日志里不再先报「倒下了」。
- 新专项 `xiyou_tianqi_doom_follow`（64 项）：四骑士死期（开／关）、宣判者助力位死期、倒下入口场上对比（开／关）、收尸人喂助力位（开／关）、影子不能复活（开／关）、打输复活（开／关）、七首之龙缓期换到助力位倒下＋打输复活（开／关）、真战斗画面守卫（换下挂死期的人回合末不报错、场上倒下照常演出）。
- 玩家可见：死亡线、四骑士战里把挂着死期的人换下去，回合末他照样倒下（以前四骑士的死期会被躲掉、宣判者的会让战斗画面卡住）；允许失败的战斗输了，助力位上倒下的人也扶起来。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `core/tianqi_horsemen.gd` `XTianqiHorsemen.DOOM_FOLLOW`、`doom_people`、`lose_revive`；`core/tianqi_death_alien.gd` `_scan_deaths`、`blocks_revive`；`battle/battle_scene.gd` 打输复活 | 天启篇新机制（原版无）：四骑士死期、收尸人、影子与宣判者「不能复活」只认场上 4 格；允许失败的战斗打输只复活出战成员 | 死期挂人不挂格子：这几处认场上 4 格＋助力位 | 发作真换人 v0.2 第三节第 5 条、D201 第 2 件：手动换人不能躲死期；死在助力位要喂收尸人、打输要扶起来 | `XTianqiHorsemen.DOOM_FOLLOW = false` | cc | 保留 |
| O-待定-2 | `core/tianqi_death_alien.gd` `XTianqiDeathAlien.DIE_ENTRY`、`_kill` | 天启篇新机制（原版无）：死亡线异化死期、丧钟、替身带走人时直接写阵亡状态（add_new_state），绕过倒下包装 | 走战斗倒下入口 `logic._die`；只因死亡抵抗特性没加上时仍直接加 | 发作真换人 v0.2 第三节第 5 条①、P2-1：和四骑士死期、七首之龙缓期同一个入口 | `XTianqiDeathAlien.DIE_ENTRY = false` | cc | 保留 |

## 交接板

- 下一步：T181（T086-a 逻辑层）、T182（T086-c 画面）可以接着派；本卡合并后它们改同几个文件。
- 用户试玩说明：死亡线／四骑士战里，给挂了死期的人点「换人」换下去，回合末他在助力位照样倒下，画面不再卡住；允许失败的战斗输了，助力位倒下的人也会被扶起。
- 需要用户决定：无

## 进度账

- 天启篇发作真换人（T086）：T086-b 完成；a、c、d、e 未开。

## 可优化（流程／工具／效率）

- 建议：车道分支常比 GitHub main 新几十个提交（本轮本地 main 比 github/main 多 38 个），`云端选测.py run` 推 `ci/<分支>` 会把未推送的 main 提交一起推上公开仓，车道不敢用，只能本机跑子集；可以让 `云端选测.py` 在 HEAD 含未推送 main 提交时提示，或由总装每次合并后及时推 main（归工具车道）。

## 验证

- 复现（修前 main）与修后对比：见变更记录草稿第二条。
- 新专项 `xiyou_tianqi_doom_follow` 单跑 64/64。
- 选测：`选测.py main --list` 列出 175 个场景；本机跑其中战斗核心、战斗画面与天启篇相关的 65 个（含 `xiyou_determinism`、`xiyou_battle_*`、`xiyou_tianqi_*`、`xiyou_rift_alien`、`xiyou_poison_collapse`、`xiyou_regen_popup` 等）：65/65 通过；偶发 2 个单跑通过：`xiyou_battle_pace`（累计第 3 次，与本卡无关，建议另修）、`xiyou_hp_gauge_visible`（第 1 次）。没跑的 110 个是楼层 `xiyou_floor_*`、事件对照 `xiyou_event_compare*`、地图 186 等（因为改了 `battle_scene.gd` 被选上，本卡只加了一个只在目标没图时生效的守卫和打输复活一个调用，原版档 `DOOM_FOLLOW` 下与原来逐字等价：天启篇不活动时 `helper()` 为空）；云端选测没跑，原因见「可优化」。
- `--oracle`：没跑。改动只在天启篇模块（原版档不进这些路径）和画面守卫（目标有图时不生效），没有改到原版移植来的底层逻辑。
- 语法检查通过；工具回归全部通过（100 秒）；交付自检见回执。

## 本分支提交

- 见回执
