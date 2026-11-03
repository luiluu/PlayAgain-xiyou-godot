# 交付：cc/bailong-tusu7

- 车道／工作者：白龙（cc），派单 G tusu7：审查第 26 期 P3-1、P3-3 与屠苏画面
- 基线：开工合 main 6adc3f4a（合并 cc/wukong-content2），工作树 `.claude/worktrees/bailong-tusu7`
- 状态：可合并

## 变更记录草稿

## 2026-11-02 【cc·白龙·未经审查】屠苏收尾：强制行动走屠苏 endAction、结束步护阵断言、指令窗与器谱画面（dev.待定）

### 一、审查第 26 期 P3-1：强制行动不走 `XTusu.end_action`

- 原版 BattleManager.processForcedAction 也是 startAction → … → endAction，屠苏的 endAction 包装照跑。重制 `battle_logic.gd` `_forced_run` 在 `execute` 之后补 `XTusu.end_action`，次序同 `act()`（饿狼等 finish 之前）。持武者被事件强制放贯日、敕令时锁定、和鸣照常消费；剑相、锤相持武者被强制行动后放剑气／镇魂，`trigger` 读数照记，`_act` 不再留到下一次行动。
- 参照：`mv_oracle/tusu_battle_probe.cjs` 加 `force` 步骤（`forceAction`＋`BattleManager.forceAction`＋`processForcedAction`，同 state_effects_probe 的写法）和第 13 例 `forced`：弓相锁定后强制贯日（锁定消费）、书相挂和鸣后强制敕令（和鸣消费）、剑相补兵势后强制斩锋（剑气纵横放出、台词「这一下，我自己来。」）。夹具 `tests/fixtures/tusu_battle_oracle.json` 重拷（只多了这一例，前 12 例逐字不变）。重制测试 `force` 步骤走 `_force_action([1, 角色, 技能, 目标])`。
- 修之前新例挂 forced.3～ 的锁定、`trigger`、持武者状态；修之后 4977 项全过。
- 谷雨 `end_action` 在 `_forced_run` 里也没有（审查提过一句，旧代码，不在本期范围），没动。

### 二、审查第 26 期 P3-3：结束步护阵没有断言

- `tests/xiyou_tusu_battle.gd` 结束步两边滤掉护阵再比（参照不走 onBattleEnd）之外，另加只看重制的 `<例>.end.huzhen_cleared`：全队身上没有护阵；再加 `huzhen_end_coverage`：至少有一例结束前身上带着护阵（armdmg 的 8 号），免得断言空转。
- 反向验证：重制有两处删 removeAtBattleEnd 状态（`end_battle` 胜利分支和 onBattleEnd 段），只关一处测试仍全过；两处都对护阵关掉时 `armdmg.11.end.huzhen_cleared` 挂。

### 三、屠苏画面

- **战斗指令窗**（installNativeTusuRuntime.js 第 230～285 行）：
  - 武具态（绑定中）的屠苏：技能栏只有一栏「易武」（addSkillCommands 包装，技能类型 1）；第 2 行插「武相支援」，名字是当前武相的支援技能（剑气纵横、锁定……），没有时写「武相支援」，能用才亮；防御改名「待命」。易武栏只列易武（Window_BattleSkill.includes 包装；易武不设等级门槛）。
  - 选「武相支援」：能用就记进上次技能、开选目标；选目标取消回指令窗（onEnemyCancel／onActorCancel 包装）；不能用就重画指令窗。
  - 持武者：技能栏按技能类型去重（makeCommandList 包装；重制 `traits_set` 本来不重复，这里照包装再滤一次）。
  - 代码：`XTusu.bound_tusu／command_entries／battle_listed`，`battle_scene.gd` `_command_entries`、`_command_for`（`tusuSupport`）、技能栏过滤。
- **器谱**（第 627～663 行，公共事件 9014 `CodexTusu.openForge()` → B.openMenu → Scene_CodexBindMenu）：新页 `ui/tusu_forge.gd`（XTusuForge），菜单背景＋XChoiceWindow（原版 Window_YunChoices，窗体读数早在宝珠坊对过）。首页说明「每次进阶可开刃一相，最多三相；重新开刃消耗人道意志碎片×10」，三道铭文（没进阶到的「（未开放）」灰显）；选铭文后列五相「开刃·x　说明」，已开在别的铭文上的灰显；换已开的相要碎片 ×10，不够提示原文。原版 forgeRows 的标题行「器谱　开刃 n/3」被 forgeMenu 的过滤去掉、画面上看不到，照搬。屠苏不在队时脚本什么都不做（同原版）。`mv_script.gd` 认这句脚本，`map_scene.gd` 加 `open_tusu_forge`。
- **技能页打开器谱**（顺带修的旧缺口）：`skill_scene.gd` 原来用 `XBattleLogic.can_use` 判能不能用，它只认场合 0／1，菜单场合（2）的技能在技能页永远灰；也没有处理效果 44。现在场合 2 照「随时」交给 `can_use` 判其余条件；不对我方的技能（Game_Action.isForFriend 不成立，如器谱 scope 0）不选人直接用、留在列表（Scene_Skill.determineItem）；用后有预约的公共事件就带 `to_map` 关页，主菜单跟着关、回地图执行（同物品页的 checkCommonEvent）。
- 专项 `xiyou_tusu_ui`（新，28 项）：人形与武具态的指令行、支援名与灰显、易武栏、持武者去重、别的队员不受影响；器谱首页／选相页行文与灰显、开刃学被动、占用灰显、重新开刃扣碎片、取消回首页、首页取消关页；技能页用器谱预约 9014 并关页。

优化登记草稿：无

## 待交叉核查

- `battle_logic.gd`（原沙僧核心文件）：`_forced_run` 加 `XTusu.end_action` 一行（P3-1）。
- `skill_scene.gd`：场合 2 可用、不对我方的不选人、效果 44 回地图——影响所有菜单场合技能和不对我方的随时技能，不只屠苏，请重点核。
- `battle_scene.gd` 指令窗与 `tusu_forge.gd` 对原版代码的行文。
- 画面只按原版代码和已对过的窗体复现，没有用 ui_reference 在原版里截图逐像素比（指令窗沿用 XBattleList、器谱沿用 XChoiceWindow，两者窗体都已对过运行时读数）。

## 交接板

- 下一步：屠苏第三～五期与 tusu7 画面已齐；剩谷雨 `end_action` 不进 `_forced_run`（旧代码，审查第 26 期 P3-1 顺带提到）。
- 用户试玩说明：屠苏化武后指令窗是「归形／武相支援／易武／待命／物品／逃跑」；技能页的「器谱」能打开开刃页。
- 需要用户决定：无

## 进度账

- 屠苏：画面部分补齐（指令窗、器谱）。

## 可优化（流程／工具／效率）

- 无

## 验证

- 开工合 main（609c6f55）；`script_census_known.json` 删「CodexTusu.openForge」一行（mv_script 已认，census 的 known_still_unknown 失败即此）；`新建工作树.sh --补齐` 刷新 generated 后重跑。
- 命令：`并行测试.py 07_开发环境/godot 01_Godot工程 --jobs 2` ＋ 39 个场景名（实跑 35 个，按全名匹配，个别名字无同名场景被略去）：xiyou_script_census、xiyou_floor_odds、xiyou_floor_inherit、xiyou_floor_run_c（上轮挂的 4 个）、xiyou_tusu／_battle／_ui、xiyou_wtype、xiyou_event_compare、xiyou_determinism、xiyou_skill_page／_mastery、xiyou_window_rects、xiyou_battle_ui／_log／_options、xiyou_script／_gaps、xiyou_battle、xiyou_combat、xiyou_state_effects、xiyou_rules_d1b／d2c／d3d／d3e／d4b／d5c／d6d（选测抽样）、xiyou_smart_ai／_f／_k／_p、xiyou_map、xiyou_item_list、xiyou_panels。
- 结果：实跑 35 个场景全部通过（用时 1421 秒），无失败、无偶发；xiyou_tusu_battle 4977/4977，xiyou_tusu_ui 28/28，xiyou_tusu 327/327。上轮挂的 floor_odds／floor_inherit／floor_run_c 刷新 generated 后过了，确为旧切片所致。
- 日志：`03_再刷重制_Godot/04_验证/本地结果/并行测试/20261102_235329_tsk2cmd8/`
- 没跑：选测的其余约 180 个场景（含楼层 reach 系列、其余 rules／smart_ai 抽样段）和全量，留总装合并后跑；车道不跑全量。

## 本分支提交

- a6a0b165 P3-1 强制行动走屠苏 endAction（参照 forced 例）、P3-3 护阵断言
- cddc7f26 指令窗与器谱页、专项 xiyou_tusu_ui
- 6562b82b 技能页：场合 2、不对我方的直接用、效果 44 回地图
