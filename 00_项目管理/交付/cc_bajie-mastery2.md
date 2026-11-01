# 交付：cc/bajie-mastery2

- 车道／工作者：B 界面／规则（总装十二派给八戒）／八戒（cc，八戒）
- 状态：可合并
- 分支从 cc/bajie-ui-gaps1 末端 ddc78186 切（链式：先合 ui-gaps1，总装只合链尾）。

## 变更记录草稿

## 2026-11-01 【cc·八戒·未经审查】技能熟练度期二：技能升级通告、菜单技能窗量条与 LV、熟练度进战力（dev.待定）

- **技能升级通告**（installSkillLevelNoticeRuntime v1.0.0）：新 `modes/xiyou/ui/skill_notice.gd`（XSkillNotice）。`XSkillMastery.set_level`／`gain_level` 改等级后调 `report`：
  - 只报角色、等级升高才报；设置「消息提醒 → 技能升级通告」关掉不报；标题画面（没有 XState.current）不报；新局、读档不经 set_level，也不报（原版 suppressed）。
  - 同一帧里同一角色同一技能合并成一行 from→to（原版 Promise 微任务，重制 call_deferred）。
  - 右上角竖排、最多 3 条、每条 5.5 秒；`XState._become_current` 清空（原版 setupNewGame／loadGame 的 clear）。
- **菜单技能窗**（YEP_SkillMasteryLevels 包过的 Window_Base.drawItemName）：`skill_scene.gd` 名字前画量条，名字后在图标格写「LV.n」；0 级不画。
  - 量条：x+36、宽 名字宽−36、高 10、y+24；底色字色 19，填充按本级已用÷所需，字色 6→10 渐变。
  - 「LV.n」：(x+2, y−8)、宽 32、右对齐、15 号、字色 29。
  - 战斗技能窗被 Olivia_SideBattleUI 整个换掉了 drawItemName（不调原链），原版战斗里不画，重制也不画。
- **战力**：`XEquipment.clone` 带上 mastery_levels／mastery_uses（原版 JsonEx 深拷贝），战力和装备预览的伤害预演读得到熟练度。CombatPower 的签名里有 `_skillMasteryLevels`，但原版不强制时照旧返回缓存值（参照 power：808→不强制 808→强制 811）。重制签名不加熟练度，照原版。
- 参照：`skill_mastery_probe.cjs` 加了 notice.battle、notice.set、power 三例。power 照 power_probe 关掉 CodexZones（installNativePowerZonesRuntime 重制没有移植，它的「技能熟练度」乘区 masteryRate 也随它不做）。

## 交接板

- 下一步：熟练度期三。范围：
  - 渡鸦 10122～10139／10170 运行时熟练度设定，以及 `R.masteryCap`
  - 饿狼：追击／反击借主拳熟练度、进阶继承（继承期间不报通告，`_garouAdvancing`）
  - 异化 affix 23 取 min
  - 宿傩、甚尔 `_actionMastery`，云裳派生伤害，米拉
  - MP／TP／HP 费用与冷却的熟练度公式
  - 核一下 OTB 即时施放有没有走 onAllActionsEnd（原版测试模式注释说 OTB instant cast 可能不经 onAllActionsEnd，重制在每次行动结束计次）
- 不做，依赖未移植的系统：测试模式上限（重制没有测试模式，设置页「测试模式」未重制）；战力区 CodexZones 的 masteryRate（重制没有 CodexZones）。
- 用户试玩说明：技能升级时右上角弹「技能升级 / 角色 · 技能 / Lv.a → Lv.b」；菜单技能页里有熟练度的技能在名字下方显示进度条，图标左上写 LV.n。
- 需要用户决定：无（照原版，不用 O 号）。

## 进度账

- 战斗核心／界面：技能熟练度期二（通告、技能窗显示、战力）。

## 待交叉核查

- 甲档：`equipment.gd`（clone 带熟练度）、`xstate.gd`（_become_current 清通告）、`skill_mastery.gd`（report、rate）。
- 乙档：新 `skill_notice.gd`、`skill_scene.gd` 量条与 LV。

## 验证

- 专项 `xiyou_skill_mastery` 244/244（期一 216 条，加 notice、power 共 28 条）。power 三个值与原版逐值相等（808／808／811）。
- 反向：
  - 去掉 clone 带熟练度：243/244。
  - 去掉同帧合并：243/244。
  - 去掉「只报角色」那个判断抓不到：XEnemy 没有 actor_id，读取会出运行时错，函数直接中断，所以结果一样不报。这个判断等于双保险。
- 没逐字对浏览器：通告浮框的行高（CSS line-height: normal 取字体正常行高）、技能窗量条与 LV 字只按插件参数和 CSS 写，没在浏览器参照里截图核对。可以排一次 ui_reference 成对截图（右上角通告＋技能页一个有熟练度的技能）。
- 选测 12 个全过：skill_mastery、skill_page、status_power、status_power_panel、power、determinism、event_compare、rules、rules_d3、notice_options、equipment、save_page。语法检查 471 个 0 问题。没合 main（基于 ui-gaps1 链，ui-gaps1 已合 main 22238e0b）。

## 可优化（流程／工具／效率）

- 无新增（期一交付单的两条仍有效）。

## 本分支提交

- WIP: 通告、技能窗量条与 LV、clone 带熟练度；探针扩 notice／power
- WIP: 期二专项 244/244
- 本交付单
