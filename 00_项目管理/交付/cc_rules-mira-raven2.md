# 交付：cc/rules-mira-raven2

- 车道／工作者：C 规则·机制／八戒（cc，GB13）
- 状态：可合并

## 变更记录草稿

## 2026-11-10 【cc·八戒·未经审查】米拉／渡鸦数值池二期、340 中止对齐原版、智能 AI 霸体估分、状态格缓存（dev.待定）

- 米拉／渡鸦数值池二期（`installMiraRavenNumberBoostRuntime.js` 的 itemHit／itemEva／itemCri 包装）：168 用米拉攻击表、167 用渡鸦攻击表的技能打敌人时必中、不闪避（`XBattleLogic.item_hit`／`item_eva`，在甚尔包装里面，次序同 main.js）；渡鸦用普攻、非专属技能或目标不是敌人时，itemCri 内层读面板暴击不带魂海 +10×灵魂进度（`XNumberBoost.item_cri`／`suppress_raven`，面板照实显示）。归属技能暴击率夹 0～1 由外层 DamageElement 的夹值覆盖，不另做。新参照 `mv_oracle/mira_raven_hit_probe.cjs`（30 例：168／167 × 归属攻击／普攻 × 敌人 1／敌人 303（闪避、暴击闪避 100%）／挂无光黑雾的 1 号角色，行动者挂致盲）→ `tests/xiyou_mira_raven_hit`，已登记进 `同步正式西游.py` 的 PROBES。
- 340 中止战斗对齐原版（审查第 76 期 P3-1）：command340 只 `BattleManager.abort()` 并返回 true，本页同一帧照常往下跑；跑到第一条会等待的指令（文字照常显示，确认后丢掉游标；230 等待、淡入淡出、339 强制行动等在它之前停）后解释器不再更新。本页同一帧跑完（`XBattleLogic.abort_checks_end`）时原版 checkBattleEnd 里 checkAbort 恒返回 false，processAbort 之后接着判：我方全灭 → processDefeat，301 分支结果改写成 2，但 `_escaped` 已置，预约 1308、不复活、不去结束画面（`XMapScene.last_battle_escaped`，301 与随机遇敌都看它）；敌群全灭 → processVictory，结果 0。340 之后又 353 时按游戏结束收场。原版这两种 endBattle 要跑两遍（先 1 后 2／0），重制只按最后结果跑一遍（O-待定，`XBattleScene.ABORT_DOUBLE_END`）。现有数据没有用到 340。
- 智能 AI（`Codex_SmartBattleAI.js` 390／396）：有霸体的难度 Boss（`boss_difficulty_boss` 且 `boss_hyper_armor`）不估附加控制状态（`XEnemy.boss_control_state`）的分，也不估解除霸体 2651 的分。
- 14 处 `addState(非整数字面量)`（`未翻译块清单.py`）逐个核：状态 292～317 单号「暴击时」`user.addState(param, turns)` 原版各层 addState 只认第一个参数，回合数不生效，重制翻成 `add_state criticalOnly`，状态号与对象 11 处全对；319 对目标加 318 对；1431 巡猎（`addState(1430 + k)`）补专项 `xiyou_state_effects` fix.1431；1711 秩序、1716 同谐已有 fix.tiers。工具里记成已核（`UNRESOLVED_CHECKED`），报告改成「全部已核」。
- 状态格 `XSideStatus.state_kind` 按状态号缓存（被动恒「常驻」不进缓存；`states()` 换过的视图，如破阵·真气改倍率，不是数据库原条就现算）。
- 全灭当下状态格「i」（像素对照二期的已知问题）查明不是战斗结束清状态：参照里用 setHp(0) 打倒全员，krz_state_re 的 `Game_Actor.states` 缓存（`_statescache2`）没刷新，states() 还是空表才画「i」；processDefeat 之后缓存刷新，就有无法战斗。实战里受伤倒下同样走 setHp→refresh→addState(1)（参照里单独 addState(1) 也不刷新缓存，已实测），推断原版全灭当下画的是倒下前缓存的状态，属缓存过期（实战全灭没另录参照）。重制照实时状态显示，不照搬（见 O-待定第二行）。
- 玩家可见：米拉、渡鸦的专属攻击打敌人不会再被闪避；渡鸦普攻的暴击率不再吃魂海加成（面板数值不变）。智能 AI（自动战斗）不再对有霸体的 Boss 选控制技能。
- 验证：语法检查 0 问题；工具回归全过；本机专项 `xiyou_mira_raven_hit` 212/212、`xiyou_battle_end_ce` 46/46、`xiyou_smart_ai` 5355/5355、`xiyou_state_effects` 32816/32816、`xiyou_side_status_order` 15/15；`同步正式西游.py --accept-additions` 测量不变（新参照 mira_raven_hit.json）；云端选测 386 个场景全过（提交 91949fb06，16 片）。
- 未完成／已知问题：`last_battle_escaped` 改的 301／随机遇敌分支没有专项（原来的 `last_battle_game_over` 也没有）；340 后停在 230 等淡入淡出前，画面差那一条指令的效果；CritFloor（installCritFloorRuntime，外层）判「攻击方暴击率 ≤0」时读的是带魂海加成的面板，渡鸦负暴击率、目标暴击回避超过 100% 时原版仍会负负得正，重制内层按压制后的值夹 0（极端组合，没另开关）。

## 优化登记草稿（O-待定，表格行）

| O-待定 | `XBattleScene._abort_battle` `ABORT_DOUBLE_END` | 340 中止所在页同一帧跑完、又同帧全灭／全歼时，checkBattleEnd 先 processAbort（endBattle(1)）再 processDefeat／processVictory（endBattle(2／0)），endBattle 及各模块包装跑两遍 | 只按最后的结果跑一遍 `logic.end_battle` | 两遍是 checkAbort 恒返回 false 的副作用，各模块清理与奖励钩子重复跑；现有数据没用到 340 | `XBattleScene.ABORT_DOUBLE_END = true`：先补跑一遍 `end_battle(1)` | cc（八戒） | 待用户决定 |
| O-待定 | `XSideStatus.cell_rows`（不改代码） | krz_state_re 的 `Game_Actor.states` 缓存在 setHp 打倒（addState 1）后不刷新，全灭当下状态格画倒下前缓存的状态（参照里是空表「i」），processDefeat 后才刷新 | 照实时状态画（倒下显示无法战斗） | 缓存过期是原版缺陷，画面只差全灭那一瞬 | 无开关（要照搬需引入整套 krz 状态缓存） | cc（八戒） | 待用户决定 |

## 交接板

- 下一步：删掉「米拉／渡鸦数值池二期」「340 中止对齐原版」「全灭状态格 i」「智能 AI 霸体估分」「14 处非整数 addState」「state_kind 缓存」这几条遗留
- 用户试玩说明：米拉、渡鸦的专属攻击不会被闪避；渡鸦普攻暴击不吃魂海加成
- 需要用户决定：无（两条 O-待定照默认）

## 进度账

- 战斗规则（专属角色模块）：米拉／渡鸦数值池从「一期（暴击、伤害钩子）」到「二期完（命中三件）」；`number_boost.gd` 头注已改

## 可优化（流程／工具／效率）

- 已做：`未翻译块清单.py` 加 `UNRESOLVED_CHECKED`，核过的 addState 来源不再列为待查（回退：清空该集合）
- 建议：单独 new 的 MV 敌人不在敌群里时 `states()` 取不到 `_states`（krz 缓存），写探针给敌人挂状态要先进敌群；可写进 `mv_oracle/README.md` 的坑（归工具车道）

## 本分支提交

- e6a3abb5e 米拉／渡鸦数值池二期
- 5cb1655ba 340 中止战斗对齐原版
- d724f1533 智能 AI 霸体估分
- c93949a48 核 14 处 addState(非整数字面量)
- 2e1bdc533 状态格 state_kind 缓存
- 91949fb06 合并 main
