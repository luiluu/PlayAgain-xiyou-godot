# 交付：claude/bajie-advanced

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_68）
- 状态：可合并
- 期一：角色进阶范围与参照（本节）；期二：实现（见「期二提案」）

## 期一：范围清单（Scene_ActorAdvanced）

**入口**
- `SceneManager.push(Scene_ActorAdvanced)` 全游戏只三处：Map132 EV6 p0、Map137 EV4 p0（都是「奉神老妪」：101 对话＋102「进阶／离开」，选进阶开界面），公共事件 9008「饿狼进阶入口」。
- 切片里只有 Map132（Map137 不在切片）。公共事件 9008 **没有调用者**（地图、公共事件、物品／技能效果、插件参数都查过），是孤立入口，不接。
- 事件对照基线现有 `m132e6p0`（未翻译的脚本 355），接好后删除。

**数据（插件参数 `Advanced 1`～`Advanced 1000`，struct<Advanced>）**
- 冻结源实有 462 条。每条：`AdvancedActId` 角色、`AdvancedActNum` 当前次数（从 N 进到 N+1 的那条）、`AdvancedActNumMaX` 最大次数（只用来显示）、`AdvancedActLevel` 需求等级、`AdvancedGold` 需求金钱、`AdvancedItem` `[[物品ID, 数量], …]`、`AdvancedSkiId` 学会技能、`AdvancedForId` 遗忘技能（447 条为空）。名称、备注游戏内不用。
- 行的匹配：`AdvancedActId == 角色 && AdvancedActNum == 角色._AdvancedNum`，取第一条（filter(...)[0]）。没有匹配＝已达最大。
- 运行时改表（导出时要照做）：
  - `installNativeEconomyRuntime.normalizeAdvanceCosts`：物品 184～187 一律换成 188（魂灯），同 ID 合并数量（货币合并）。参照里角色 1 第 0 阶的 `[[186,1]]` 实际要 188×1。
  - `installNativeRavenRuntime`：渡鸦（167）缺的 0～4 阶补 5 条（最大 5，等级 15/25/35/45/45，进阶印×1）。渡鸦不在切片。
- 导出：不新开数据表，`XDB.plugin("Star_ActorAdvanced")` 已能读到参数（`actor_book.advance_max` 就这么读）；新核心载入时解析一次并照上面两条改表。

**进阶效果（基础插件 onConfirmOk）**
- 先遗忘 `AdvancedForId`、再学会 `AdvancedSkiId`，`_AdvancedNum += 1`，扣金钱、扣物品，提示「进阶完成」，金钱窗与状态窗重画。
- **基础插件不改职业、能力值、外观**：参照里进阶后生命 485→685、魔法 200→400、攻防等 +15，全来自学会的被动技能（如 1240 超越极限I 备注里的被动加成），重制 `actor.gd` 已有的被动解析就能算。所以期二不改 actor.gd（只调它已有的 `learn_skill`／`forget_skill`），用参照的能力值读数验证。
- 条件检查（底部「进阶」确定时）：等级 ≥ 需求、金钱 ≥ 需求、每种物品够数。不满足提示「进阶条件未达成」并回到名单。

**存档**
- 原版：`Game_Actor._AdvancedNum`（随角色进存档；未进阶过的是 undefined，状态窗第一次画时设 0）。另有状态窗画时顺手写的 `Actor.pushattribute`（8 组 [0,0]，全游戏没人读，不存）。
- 重制提案：XState 新增顶层字段 `actor_advance := {}`（角色 ID → 次数，存档键 `actorAdvance`，旧档缺省为空＝全 0），由新核心 `XAdvance.rank(state, id)` 读写。**不改 actor.gd，也不改已有角色行的结构**。别的模块要读进阶次数时都走 `XAdvance.rank`。

**界面（冻结 v0.28 读数，`tests/fixtures/actor_advanced_oracle.json`，11 态）**
- 名单窗 Window_ActorAdvancedIndex (0,0,426,720)：队伍全体（`$gameParty.members()`，含后备）一列，名字 x=6，行高 36。开场选第 1 行、活动。
- 状态窗 Window_ActorAdvancedStatus (426,0,854,720)，内边距 14、内容宽 826，column2x＝826/2＋7＝420：
  - SV 战斗图（`loadSvActor(battlerName)`，9×6 格，第 0 行），锚点中心、放在窗口底层，位置 (内容宽/10, 内容宽/10)＝(82.6,82.6)，格宽大于内容宽一半才缩小；每 12 帧换一格 0→1→2→1。
  - 文字：x=column2x/3=140 起：名字、「等级:N」、「进阶次数:N」、「最大进阶次数:M」（有匹配行用其 Max，否则用当前次数）；四行之后（饿狼另插一行「累计突破」）是 8 项能力：系统色标签在 x=0／252／504，值在标签宽＋两空格后，第 1 行第三列写「当前值」，敏捷／幸运在第三列。
  - y=能力起点＋4 行：有匹配行时「进阶需求:」、各物品（图标＋名字，后接「xN」）、「等级:N」、金钱（图标 3781＋「N精魂」）；同一 y 起第二栏 x=420「进化技能:」与学会技能（图标＋名字）。没有匹配行时只写「已达最大进阶次数」。
- 金钱窗 Window_ActorAdvancedGold (0,656,426,64)：图标 3781＋「N精魂」。
- 底部 Window_AAdvBottomConfirm (426.67,656,853.33→854,64)：一项「进阶」（前面 44 个空格居中），开场无光标、不活动；压在状态窗下沿上。
- 确认窗 Window_SaveConfirm (568,292,144,136)：标题「是否进阶」，「是」「否」，打开时选「是」。
- 窗口不透明度同其他菜单（opacity 30、back 192，MOG 菜单底图）。

**操作**
- 名单：上下移动→状态窗与金钱窗按新行重画；确定→有匹配行：开底部（选「进阶」、活动），没有（已满）：名单原地重新活动、不提示；取消→关闭界面。
- 底部确定：条件满足→开确认窗「是否进阶」；不满足→提示「进阶条件未达成」、回名单。底部取消→回名单。
- 确认窗「是」→进阶（见上）、关确认窗、回名单；「否」／取消→关确认窗、回名单。
- 提示都是 `$.toaster`（重制 XToast）。

**专属运行时钩子（只记清单，本批不做）**
- 改界面流程：`installNativeGarouRuntime`（饿狼 173：底部前查 `G.reason`、确认时走 `G.advance` 可回滚；状态窗多一行「累计突破」）、`installNativeYunshangRuntime`（云裳：底部改成从背包挑天衣、确认走 `Y.advance`；状态窗加两行说明、SV 图缩放）。
- 进阶后同步：`installNativeRavenRuntime`（渡鸦 167：同步阶位、清灵魂、发进阶印；另补 5 条进阶行）、`installNativeTojiRuntime`（甚尔 171 修复）、`installNativeSukunaRuntime`、`installNativeGuyuRuntime`、`installNativeSkillProgressionRuntime`（167／168 技能进度）。
- 只读进阶次数：`installNativeXuan／Tusu／Mira／YomiJingliu／Yunshang` 的 stage、`Codex_SmartBattleAI`（≥3 阶）、`Codex_MiraRavenMultiFrame`、`installMiraRavenNumberBoostRuntime`、`installThreeGrowthRelicRuntime`、`installImportedBalanceRuntime`（≥1 阶）、`installDisplayPreferencesRuntime`（角色说明的进阶技能）、`installCombatPowerRuntime`／`installNativePowerZonesRuntime`（战力签名）、`Star_ActorsBook`（图鉴「最大进阶次数」）。
- 以上专属角色（167～177）都不在切片；切片里受影响的只有：小猫 178（`cat.gd` 的 `advanced()` 恒假，接上要改 cat.gd）、角色图鉴 `actor_book.advance_max`（恒按 0 阶取行）、`dungeon.gd` 甚尔／宿傩进阶石（按 0 阶）、战力签名。期二只提供 `XAdvance.rank`，这些读点留给后续逐个接。

**原版缺陷（O-094 候选，做成可回退）**
1. 条件不足只提示「进阶条件未达成」，不说缺什么（等级／金钱／哪种物品），玩家要自己对照右栏。提案：提示里列出缺的项（如「进阶条件未达成：魂灯 0/1、精魂不足」），开关关掉即回原文。
2. 已满时按确定没有任何反馈（名单原地重新活动）。提案：放蜂鸣音。可回退。
3. 底部失败时确定音放两次（`onBottomConfirmOk` 开头一次、失败分支又一次）。属音效细节，不改，照原版。

**要动到的文件**：新增 `core/advance.gd`（XAdvance：表、条件、进阶、存档字段读写）、`ui/actor_advanced.gd`（XActorAdvancedScene）、专项 `tests/xiyou_actor_advanced.gd/.tscn`；`xstate.gd` 新增 `actor_advance`／`actorAdvance`；`mv_script.gd`（`SceneManager.push(Scene_ActorAdvanced)` → `host.open_actor_advanced`）；`map_scene.gd`（`open_actor_advanced`）；`xiyou_event_compare.gd` 宿主补 `open_actor_advanced`、基线删 m132e6p0。**不动** actor.gd、battler.gd 等沙僧独占文件，也不动悟空独占的切片与转换器。

## 期二提案

工作量与更衣期二相当（核心约 150 行、界面约 350 行、专项一份），一期能做完：
1. `XAdvance`：解析插件参数＋经济改表、`row(state, actor)`、`check(state, actor)`（返回缺项）、`advance(state, actor)`（遗忘→学会→次数+1→扣金钱物品）、存档字段。
2. 界面五窗按参照几何复现，SV 图动画、确认窗、提示；O-094 两项做成可回退开关（默认开优化，`XConfig` 不加键，模块常量开关，交付单写明）。
3. 接线：mv_script、map_scene、事件对照宿主与基线。
4. 专项 `xiyou_actor_advanced`：逐态对照参照的窗口矩形、文字、光标与活动；进阶后能力值对照参照（685/400/62/35/15/35/35/20）；存读档往返；旧档缺字段为 0。

## 变更记录草稿

## 2026-10-24 【Claude·八戒·未经Codex检验】角色进阶期一：范围与参照（dev.待定）

- 读冻结源 `Star_ActorAdvanced.js` 与引用它的 20 余个专属运行时，写出范围清单（见交付单「期一」）：入口三处（切片里只 Map132 EV6；公共事件 9008 无调用者）、进阶表 462 条与两处运行时改表（经济合并 184～187→188、渡鸦补 5 条）、基础进阶只遗忘／学会技能、次数 +1、扣金钱物品，能力变化全来自被动技能，不需改 actor.gd；存档提案为 XState 顶层新字段 `actorAdvance`。
- 原版参照：`ui_reference/review_system_pages.js` 新页 actor_advanced（11 态：开场、换行、底部、条件不足、补料、确认窗、取消、完成、已满），压成 `tests/fixtures/actor_advanced_oracle.json`。
- 优化候选 O-094：条件不足时列出缺项、已满时放蜂鸣音（期二做成可回退）。
- 专属运行时（饿狼、云裳、渡鸦、甚尔等，角色 167～177 都不在切片）的钩子只记清单。

## 交接板

- 下一步：八戒_68 继续角色进阶期二（XAdvance 核心、界面、接线、专项）。

## 进度账

- 不变（期一只有范围与参照）。

## 验证

- 参照：`python3 review_system_pages.py <冻结 app.nw> <目录>` ＋ `node review_system_pages.cjs <目录> actor_advanced`（新页 actor_advanced，11 态，无报错），压成 `tests/fixtures/actor_advanced_oracle.json`。

## 本分支提交

- （见 git log）
