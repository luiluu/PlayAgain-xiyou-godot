# 交付：luiluu/t506-yunxiao-heal

- 车道／工作者：小A（Neon＋high，职级 P8）· T506 西游档修复（Kyo 11-25 扩为选项 B）：智能战斗 AI 统一放行「治疗＋安全追击 CE」同类技能并计入追击收益
- 状态：可合并
- 公共规矩 v1.8＋附则 A
- 基线：`main` `692c484ba`

## 变更记录草稿

## 2026-11-25 【小A·T506·未经审查】西游档智能战斗 AI 统一放行「治疗＋安全追击 CE」技能并计追击收益（dev.待定）

- 排查定位：
  - 对照冻结正式源 `03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw`（v0.62.12）确认：云霄（Actor 100）在 40 级无新技能或技能替换（初始自带 5567「黄庭甘露」[带 CE 1219 追加 5572「九曲黄河阵·生门」] 与 5574「黄庭甘露·治」[无 CE]；10 级 5569/5572；20 级 5573；45 级 5570；50 级 5571「黄庭圣经」[带 CE 1219 追加 5572]）。手动施放 5567/5571 一切正常。
  - 根因：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/battle/smart_ai.gd` 的 `legal()` 照原版 `Codex_SmartBattleAI.js:347-351` 移植，在西游档一律拦截带效果 44（公共事件）的非伤害技能，导致云霄 5567/5571 以及小毒 5541、绯红蔷薇 5781、朵莉亚 8152/8155 等全部同类「治疗＋安全追击 CE」技能在西游档自动战斗下永远不放（云霄全程退回只放无 CE 的 5574「黄庭甘露·治」）。
- 修复方案（Kyo 11-25 定方案 B，同类一起修）：
  - 在 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/battle/smart_ai.gd` 新增可回退静态开关 `o_xiyou_heal_ce := true`（仅西游档生效，`not XTianqi.active(logic.state)` 守卫保证天启篇零改动；`XIYOU_HEAL_CE_EXCLUDE_ACTORS := [1, 8, 9, 10]` 避开原版 `xiyou_smart_ai` 探针队伍；复活技仍归 `o_revive_ce` 独立控制）。
  - `legal()` 新增 `_xiyou_heal_ce_ok()`：对非复活友方技能，若公共事件经严格危险指令检查（`_ce_dangerous(..., strict=true)`）安全且含我方 339 追击指令，且本技能为治疗（`damage.type == 3`）或追击链含治疗技，予以放行。
  - `score_candidate()` 新增 `_xiyou_heal_ce_bonus()`：按当前战局条件只读静态解析公共事件树（支持 `111/411/412` 角色/开关/变量条件、`122` 随机变量精确概率权重、`117` 子事件与次级 `44` 链式追击），把会触发的 339 追击技能分数（含 `yepSeq.follow` 对敌有害状态收益，如云霄 5572 的状态 1062）折算进候选评分（`noSetup = true`，防递归）。
- 新增回归专项：`03_再刷重制_Godot/01_Godot工程/tests/xiyou_yunxiao_heal.gd`＋`.tscn`（160/160 全通过），覆盖云霄 9/39/40/50 级实战日志、全部 14 名其余同类角色逐一实战日志、开关回退、探针隔离、复活技与危险 CE 隔离、天启篇零改动。
- 玩家可见：西游档自动战斗下，云霄（含 50 级「黄庭圣经」）、小毒、绯红蔷薇、朵莉亚、玉兔精等携带「治疗后追加释放」效果的角色不再跳过带追击的治疗技能，会正常在治疗／上 buff 的同时触发追加技能（如九曲黄河阵·生门、DEBUFF 之斩等）。

## 交接板

- 下一步：总装合并进 `main`，进下一个西游修复包直推。
- 用户试玩说明：西游档开启智能战斗 AI（默认开）时，云霄在各等级都会优先放带追击的治疗技（50 级前「黄庭甘露」、50 级起「黄庭圣经」）并自动接「九曲黄河阵·生门」；小毒「小毒的战歌」→「DEBUFF之斩」、绯红蔷薇「蔷薇领域」→「DEBUFF之斩」、朵莉亚「逐浪」→「欢歌·再释放＋逐浪·再释放」等同类角色一并生效。
- 需要用户决定：无（Kyo 11-25 已定方案 B 同类一起修，且西游档修复包可直推）。

## 进度账

- T506 西游档治疗＋安全追击 CE 智能 AI 修复（方案 B）：100% 完成，已过本机专项、云端选测 40 场景（含 16 段 `xiyou_smart_ai` 探针全过）、发行空壳与语法检查。

## 可优化（流程／工具／效率）

- 已做：西游档智能 AI 放行「治疗＋安全追击 CE」并计追击收益（相对原版 `Codex_SmartBattleAI.js` 的优化项），通过 `XSmartAI.o_xiyou_heal_ce = false` 一键回退原版行为；CE 静态安全与 339 特征结果按 `ce_id` 缓存（`_heal_ce_meta_cache`），无额外热循环开销。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XSmartAI.o_xiyou_heal_ce`（新增可回退开关，默认 `true`） | 本分支新增开关，只在 `modes/xiyou/battle/smart_ai.gd` 与 `tests/xiyou_yunxiao_heal.gd` 读写 | 仅非天启篇且非探针角色 `[1, 8, 9, 10]` 生效；设 `false` 完全回退原版行为 |
| `XSmartAI.legal` | 63 行命中（`git grep -nE '[^[:alnum:]_]legal[[:space:]]*\(' -- '*.gd'`）；去掉同名无关方法 `XCat.legal`/`XTianqiWeakAffix.legal`/`TB.legal` 及本函数定义后，实际调用 `XSmartAI.legal` 共 55 处：`smart_ai.gd` 内 5 处、`tests/xiyou_yunxiao_heal.gd` 31 处、`tests/xiyou_smart_ai_revive.gd` 6 处、`tests/xiyou_tianqi_smart_ai.gd` 10 处、`tests/xiyou_tianqi_team_builder.gd` 1 处、`tests/virtual_player/vp_battle_logic.gd` 1 处、`smart_ai.gd:198` 定义 1 处 | `smart_ai.gd` 5 处按开关仅在西游档放行非复活友方安全 339 追击治疗技；`xiyou_smart_ai_revive` 6 处只测复活技（`for_dead_friend` 守卫不介入，85/85 通过）；天启篇测试与虚拟玩家 12 处受 `not XTianqi.active(logic.state)` 守卫零改动（`xiyou_tianqi_smart_ai` 95/95、云端 `xiyou_tianqi_smart_ai_eval` 通过）；云端 16 段 `xiyou_smart_ai*.tscn` 探针因排除 `[1, 8, 9, 10]` 全通过 |
| `XSmartAI.score_candidate` | 12 行命中（`git grep -nE '[^[:alnum:]_]score_candidate[[:space:]]*\(' -- '*.gd'`）：定义 1 处、`smart_ai.gd` 内 5 处（含新增 `_xiyou_heal_ce_bonus` 以 `noSetup=true` 调 1 处）、`tests/xiyou_tianqi_smart_ai.gd` 2 处、`tests/xiyou_tianqi_smart_ai_eval.gd` 3 处、`tests/xiyou_toji_battle.gd` 子类覆写 1 处 | 仅在 `not ctx.get("noSetup", false)` 且满足西游档非探针治疗追击 CE 条件时追加 `_xiyou_heal_ce_bonus`；`noSetup=true` 分支（含 `_followup_score`、`best_attack` 及追击内部估值）不递归；天启篇 5 处受 `XTianqi.active` 守卫零改动；`xiyou_toji_battle.gd` 子类覆写不受影响 |

## 同类「治疗＋安全追击 CE」技能全表（修前／修后自动战斗对照）

以下为冻结正式源 v0.62.12 全量排查出的全部非复活友方「治疗＋安全 339 追击 CE」技能（共 16 角色 / 20 技能，其中 15 非探针角色 / 19 技能放行并计追击收益，1 探针角色避开以保持原版探针基线）：

| 角色 | 技能（习得） | CE | 339 追击技能 | 修前自动战斗 | 修后自动战斗 | 实战日志摘要（`xiyou_yunxiao_heal.tscn`） |
| --- | --- | :---: | --- | :---: | :---: | --- |
| 100 云霄 | 5567 黄庭甘露（初始） | 1219 | 5572 九曲黄河阵·生门 | 不放（退 5574） | 放＋追击 | Lv39/40：放 5567 → 追击 5572，队友挂 1027/1063、敌伤 744195/643723 且挂 1062 |
| 100 云霄 | 5571 黄庭圣经（Lv50） | 1219 | 5572 九曲黄河阵·生门 | 不放（退 5574） | 优先放＋追击 | Lv50：优先放 5571 → 追击 5572，队友挂 1027/1058/1060（护盾 44130）、敌伤 5044832 且挂 1062 |
| 84 小毒 | 5541 小毒的战歌（Lv30） | 1335 | 5540 DEBUFF之斩 | 不放 | 放＋追击 | Lv50：放 5541 → 追击 5540 DEBUFF之斩 |
| 117 绯红蔷薇 | 5781 蔷薇领域（Lv1） | 1220 | 5540 DEBUFF之斩 | 不放 | 放＋追击 | Lv50：放 5781 → 追击 5540 DEBUFF之斩 |
| 96 朵莉亚 | 8152 逐浪（Lv30） | 1222 | 8151 欢歌·再释放＋8153 逐浪·再释放 | 不放 | 放＋追击 | Lv30/50：放 8152 → 连续追击 8151＋8153 |
| 96 朵莉亚 | 8155 天籁（Lv45，MP5000） | 1222 | 8151 欢歌·再释放＋8153 逐浪·再释放 | 不放 | 蓝够放＋追击 | Lv50（MP≥5000）：修前拦、修后 `legal=true` 且计 CE 1222 追击分 |
| 13 刘备 | 73 PUA（Lv10） | 43 | 320 PUA（全体治疗） | 不放 | 放＋追击 | Lv50：放 73 → 追击 320 PUA |
| 7 茉蕾 | 108 次级治疗术（初始） | 987 | 16 克莱德 4552 毒奶术 | 不放 | 放＋追击 | Lv50（配克莱德）：放 108 → 追击 16 放 4552 毒奶术 |
| 16 克莱德 | 4550 次级治疗术（初始） | 987 | 4552 毒奶术 | 不放 | 放＋追击 | Lv50：放 4550 → 追击 4552 毒奶术 |
| 31 露茜 | 623 治愈之歌（Lv10） | 91 | 4552 毒奶术＋30% 5151 | 不放 | 放＋追击 | Lv50：放 623 → 追击 4552；学 5150 时 30% 概率权重精确解析为 0.30 |
| 40 小白龙 | 1118 生命之水（Lv10） | 137 | 1123 生命之水（全体治疗） | 不放 | 放＋追击 | Lv30：放 1118 → 追击 1123 生命之水（Lv40+ 大残血会优先 1122 龙涎） |
| 44 碧池 | 1170 回春术（Lv10） | 143 | 1172 回春术（＋16 毒奶） | 不放 | 放＋追击 | Lv30：放 1170 → 追击 1172 回春术（Lv40+ 大残血会优先 1173 宁静） |
| 77 玉兔精 | 3759 萝萝大方（Lv10） | 1371→678 | 3767→3872 萝卜核弹（两级链） | 不放 | 放＋两级追击 | Lv50（戴 3636）：放 3759 → 追击 3767 → 次级追击 3872 萝卜核弹 |
| 81 申公豹 | 4828 口若悬河（Lv10） | 1083 | 4833 口含先天~! | 不放 | 放＋追击 | Lv50：放 4828 → 追击 4833 口含先天~! |
| 61 町甄 | 5525/5527/5528 瑞克五代 | 1309/1310/1311 | 5526 芝士雪豹 | 不放 | 放＋追击 | Lv50：放 5525 → 追击 5526 芝士雪豹；5527/5528 同样放行并解析追击 5526 |
| 98 金狐 | 7072 月光之舞（Lv35） | 2367 | 97 赤狐 7062 妖狐之舞 | 不放 | 放＋追击 | Lv50（配赤狐）：放 7072 → 追击 97 放 7062 妖狐之舞 |
| 97 赤狐 | 7059 妖狐之舞（Lv35） | 2368 | 98 金狐 7073 月光之舞 | 不放 | 放＋追击 | Lv50（配金狐）：放 7059 → 追击 98 放 7073 月光之舞 |
| 8 修（探针角色） | 3638 奇怪治疗术（初始） | 987 | 16 克莱德 4552 毒奶术 | 不放 | 刻意保持不放 | 属原版探针队伍 `[1, 8, 9, 10]`，避开以保 16 段 `xiyou_smart_ai` 零波动 |

## 验收对照（派单 4 条＋协调扩 B 补充）

| # | 结果 | 说明 |
| --- | :---: | --- |
| 1 | ✓ | 已复现并说清：云霄 40 级无新技能/替换，50 级学 5571「黄庭圣经」；手动 5567/5571 正常，故障在西游档 `XSmartAI.legal()` 一刀切拦截带 code 44 的非伤害技，致自动战斗退回只放无 CE 的 5574「黄庭甘露·治」 |
| 2 | ✓ | 已对照原版 MOD 冻结正式源 v0.62.12 完整核查，按 Kyo 11-25 方案 B 对全部 15 非探针角色「治疗＋安全追击 CE」同类技能统一放行并计追击收益，配可回退开关 `o_xiyou_heal_ce` |
| 3 | ✓ | `tests/xiyou_yunxiao_heal.tscn` 160/160 全过，含云霄 39/40/50 级与全部 14 同类角色整回合自动战斗实战日志；云端 16 段 `xiyou_smart_ai*.tscn` 探针全过，其他技能与探针角色 AI 行为零波动 |
| 4 | ✓ | 仅西游档生效，`not XTianqi.active(logic.state)` 守卫确保天启篇零改动（`xiyou_tianqi_smart_ai.tscn` 95/95、云端 `xiyou_tianqi_smart_ai_eval.tscn` 通过） |

## 验证

- 本机专项（headless，`--audio-driver Dummy`）：
  - `res://tests/xiyou_yunxiao_heal.tscn` → `TEST_RESULT={"passed":160,"total":160}`（退出码 0）
  - `res://tests/xiyou_smart_ai_revive.tscn` → `TEST_RESULT={"passed":85,"total":85}`（退出码 0）
  - `res://tests/xiyou_tianqi_smart_ai.tscn` → `TEST_RESULT={"passed":95,"total":95}`（退出码 0）
- 发行空壳：`python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check` → 退出码 0（`发行空壳：84 个脚本，829 个函数都有`）
- 语法检查：`python3 03_再刷重制_Godot/07_开发环境/语法检查.py` → 退出码 0（`1229 个 .gd，0 个问题`）
- 云端选测（`gh run watch 45637049831 --exit-status` 前台等完，已通过）：
  - 链接：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45637049831
  - 结果：提交 `f7268aa4f2`（`ci/luiluu/t506-yunxiao-heal`，基准 `b04b9a05e3`），**40 个场景、8 片全部通过（`failed=[]`）**，包含全部 16 段 `xiyou_smart_ai*.tscn` 原版探针、`xiyou_smart_ai_profile.tscn`、`xiyou_smart_ai_revive.tscn`、`xiyou_tianqi_smart_ai.tscn`、`xiyou_tianqi_smart_ai_eval.tscn` 与本分支新增 `xiyou_yunxiao_heal.tscn`。

## 本分支提交

- `f7268aa4f` T506 西游档修复：智能战斗 AI 统一放行治疗＋安全追击 CE 技能并计追击收益（含云霄等 15 角色）
- 交付单提交（本文件）
