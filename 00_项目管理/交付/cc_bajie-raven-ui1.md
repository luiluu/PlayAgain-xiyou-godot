# 交付：cc/bajie-raven-ui1

- 车道／工作者：B 界面（总装十一派给八戒）／八戒（cc，八戒）
- 状态：可合并
- 分支从 cc/bajie-sukuna3 末端 a4fa629d 切（要先合 guyu4→guyu5→sukuna3）。**只有本交付单，没有代码改动。**

## 变更记录草稿

## 2026-11-01 【cc·八戒·未经审查】渡鸦遗留（白龙_8 dev.244）画面与养成逐项核对：已做或无从做，本期无代码（dev.待定）

- 交接板「渡鸦遗留（白龙_8 dev.244）」派来的六项逐项 rg 核对：
  - 神话形态战斗图 Raven_Mythic_SV：已做（`XRaven.battler_name`、逐帧图 UserSV_RavenMythic 走 `XAppearance` 状态外观；专项 `xiyou_actor_looks` raven.*）。
  - 收割／回响战斗日志与特效：已做（悟空 38465517：battle_scene 渡鸦 directDamage 弹字＋受击、R.Fx ring／slash／harvest／echo；专项 `xiyou_battle_log`）。
  - 技能说明里的灵魂进度行：已做（悟空 fce8198e：`XRaven.ledger_help`，技能页说明卡下方；`xiyou_battle_log`）。
  - 技能分类与指令窗：已做（悟空 fce8198e／768e3515，dev.255：`XActorModules.MENU_SKILL_TYPES` 167＝[2,1,5,3,4]、`BATTLE_SKILL_TYPES` 167＝[2,1,5]）。
  - 法宝 4001 每级成长与上限 888：已做（悟空 raven4，dev.257：`XRaven.param_plus`，参照 raven_artifact_probe，专项 `xiyou_raven_artifact` module.*／params.*）。
  - 熟练度上限（变量 8，`R.masteryCap`＝min(999, 变量 8 或 8)）：**没法单做**——重制没有技能熟练度系统（`XBattler.skillMasteryLevel` 恒 0，见 battler.gd 209），上限夹的是恒 0 的值，无可见差别。等熟练度系统移植时一并做（原版还把渡鸦带 <CodexRavenDamage> 的技能 masteryMaxLevel 设成这个上限、skillMasteryLevel 取 min）。
- 交接板那一条另提到的「掉率图鉴、商店价格」不在本次派单里：raven4 已把亡魂汲取接进 `team_drop_factor`；商店价格与限购字段转换器已导出（raven.gd 文件头）。`XRaven` 文件头「未移植」里「收割／回响等特效（R.Fx）」一句已过时（38465517 做了），留给改 raven.gd 的车道顺手删。

## 交接板

- 下一步：删掉「渡鸦遗留（白龙_8 dev.244）」这一条；熟练度上限并进「技能熟练度系统未移植」（如果还没有这条，就新开一条：YEP_SkillMasteryLevels 整套，重制恒 0）。
- 用户试玩说明：无变化。
- 需要用户决定：无。

## 进度账

- 渡鸦 167：画面与养成遗留核清（除熟练度上限依赖未移植的熟练度系统）。

## 验证

- 只改交付单，没跑 Godot 测试；核对依据是上面列的提交、函数与专项。

## 可优化（流程／工具／效率）

- 同 sukuna3：交接板遗留条目常已被别的车道做掉，派之前先 rg，或车道交付单「交接板」节顺手写明删哪条。

## 本分支提交

- 本交付单
