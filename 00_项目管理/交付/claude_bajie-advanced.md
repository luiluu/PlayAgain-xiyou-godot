# 交付：claude/bajie-advanced

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_68）
- 状态：可合并
- 期一：角色进阶范围与参照（本节）；期二：实现（已完成，见「期二：实现」）

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

## 期二：实现（照期一提案，一期做完）

- `core/advance.gd`（XAdvance）：进阶表（插件参数 462 行＋经济合并 184～187→188；参数里两条不是合法 JSON——末尾逗号 `[1244,5846,]` 与逗号表达式 `[[2793,1]],[[180,1]]`——照 JS eval 读成 `[1244,5846]`、`[[180,1]]`）、`rank`／`row`／`max_text`、条件 `missing`、`advance`（遗忘→学会→次数+1→扣金钱物品→刷新被动）。
- 存档：`XState.actor_advance`，键 `actorAdvance`（{角色ID: 次数}，旧档没有为空＝全 0，坏值丢掉）。没有改 actor.gd，也没有改已有字段。
- `ui/actor_advanced.gd`（XActorAdvancedScene）：五窗按参照几何；SV 战斗图每 12 帧 0,1,2,1；确认窗下层清底（同存读档页）；底部 44 空格与「xN」「能力值」的横坐标按原版空格宽（修炼页 SPACE_W、`XActorBook.js_width`）。
- 接线：`mv_script.gd`（`SceneManager.push(Scene_ActorAdvanced)` → `host.open_actor_advanced`）、`map_scene.gd`（`open_actor_advanced`）、事件对照宿主补同名函数，基线删 m132e6p0（手改：只删这一条、match +1；用 `--update-baseline` 会顺带改写别的车道带来的用例数，没用）。
- O-094 写进 `00_设计/优化登记.md` 与 `界面风格.md`「界面类优化」。

## 变更记录草稿

## 2026-10-24 【Claude·八戒·未经Codex检验】角色进阶界面（dev.待定）

- 范围（期一）：读冻结源 `Star_ActorAdvanced.js` 与引用它的 20 余个专属运行时。入口三处：Map132 EV6、Map137 EV4（不在切片）的奉神老妪「进阶」，公共事件 9008「饿狼进阶入口」（没有调用者，不接）。基础进阶只遗忘／学会技能、次数 +1、扣金钱物品；进阶后能力变化全来自学会的被动技能（如 1240 超越极限I），重制被动解析已能算，所以不改 actor.gd。
- 新 `core/advance.gd`（XAdvance）：进阶表取插件参数 462 行，照 installNativeEconomyRuntime 把物品 184～187 合成 188（魂灯）；两条畸形参数照 JS eval 读。条件（等级、金钱、物品）、进阶、进阶次数读写；别的模块以后读进阶次数都走 `XAdvance.rank`。
- 存档：`XState.actor_advance`，新键 `actorAdvance`（旧档没有为空＝全 0），没有改已有字段。
- 新界面 `ui/actor_advanced.gd`（XActorAdvancedScene）：名单 (0,0,426,720)、状态 (426,0,854,720)（SV 战斗图动画、名字等级进阶次数、8 项能力、进阶需求与进化技能／已达最大）、金钱 (0,656,426,64)、底部「进阶」、确认窗「是否进阶」；提示「进阶条件未达成／进阶完成」。
- 接线：`mv_script.gd`、`map_scene.gd` 的 `open_actor_advanced`；事件对照基线删 m132e6p0（现存 1 例）。
- 优化 O-094（待用户决定）：条件不足时提示列出缺项；已满时确定放蜂鸣（`XAdvance.SHOW_MISSING`／`MAX_BUZZER` 可回退）。
- 参照：`review_system_pages.js` 新页 `actor_advanced`（11 态），压成 `tests/fixtures/actor_advanced_oracle.json`；专项 `xiyou_actor_advanced`。
- 未做（钩子清单见交付单期一）：饿狼、云裳、渡鸦、甚尔等专属运行时（角色 167～177 不在切片）；切片内要接进阶次数的读点：小猫 178 `cat.gd advanced()`、角色图鉴 `advance_max`、`dungeon.gd` 甚尔／宿傩进阶石、战力签名。

## 交接板

- 下一步：角色进阶已接（兑换大厅奉神老妪）。后续可接进阶次数的读点：小猫进阶（`cat.gd advanced()` 恒假，要小猫进阶石＋35 级＋学会 10444）、角色图鉴「最大进阶次数」按当前阶取行、甚尔／宿傩进阶石按实际阶；专属角色运行时钩子随这些角色进切片时做。
- 用户试玩说明：兑换大厅奉神老妪选「进阶」打开角色进阶：左边选队员，右边看需求（物品、等级、精魂）与进化技能，底部「进阶」→「是否进阶」确认后学会技能、扣材料；进阶次数随存档。
- 需要用户决定：O-094（进阶条件不足列缺项、已满确定蜂鸣）。

## 进度账

- 界面：角色进阶已接；事件对照里因界面未接的不一致 1 → 0（基线只剩 m4e73p0，按数值平衡不移植）。

## 验证

- 参照：`python3 review_system_pages.py <冻结 app.nw> <目录>` ＋ `node review_system_pages.cjs <目录> actor_advanced`（新页 actor_advanced，11 态，无报错），压成 `tests/fixtures/actor_advanced_oracle.json`。
- 成对截图：原版 11 态与 Godot 同态（`xiyou_actor_advanced -- --out=<目录>`）目视一致（五窗、SV 图、能力值、需求与技能、确认窗清底）。
- `并行测试.py` 相关专项＋必跑项全部通过：`xiyou_actor_advanced` 33/33（11 态窗口文字／矩形／光标、提示、金钱物品、队伍 8 项能力值含进阶后 685/400/62/35/15/35/35/20、精灵；O-094；进阶表；遗忘技能；存读档；Map132 EV6 分支）、`xiyou_event_compare` 5/5（删 m132e6p0 后无退步）、`xiyou_save_page` 40/40、`xiyou_change_clothes` 32/32。车道未跑全量 `检查.sh`；没改切片、转换器、探针，不需同步。
- 已合 main（只带进来交接板登记，不重跑）。
- 已清理：参照服务已停，原版与 Godot 截图等临时输出已删。

## 本分支提交

- eb5ca834 进阶期一：范围清单、参照页 actor_advanced 与夹具
- 2f161298 期一交付单可合并
- 44163d2b 进阶期二：XAdvance／界面／存档字段／接线／专项／事件对照
- （本提交）O-094 登记、交付单定稿
