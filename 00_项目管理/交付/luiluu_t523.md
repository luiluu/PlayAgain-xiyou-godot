# 交付：luiluu/t523

- 车道／工作者：天启篇丙档查证与修复／小A（Hydrogen＋high，P7）
- 状态：可合并

## 变更记录草稿

## 2026-11-26 【小A·未经审查】T523 天启篇修凛冬刺击附加冰冷II并收口未实装天虎令天熄乱舞／气伤链（dev.待定）

- 依据 T519 查出的两处原有疑点，先起天启篇实战战斗（`--headless --audio-driver Dummy`）实测查证，向协调回报后按决议（1A＋2A）落码，西游档零改动：
  1. **凛冬刺击（Skill 169，小痔）→ 1A 改天启篇数据、保留卡面**：原版 `Skills.json` 引用状态 23（冰冷II）的技能共 16 招：15 招是附加，唯独 169 凛冬刺击误写成效果码 22（移除状态），天启篇未覆写导致实测放 169 不仅无法挂上冰冷II，还会主动驱散敌人身上已有的冰冷II（敏捷 18→20）。在 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/skill_rework.json` 第 146 行 169 条补 `"effects_remove": [[22, 23]]` 与 `"effects_add": [{"code": 21, "dataId": 23, "value1": 1, "value2": 0}]`，并在合入 `main`（T519）后顺手为修复后的 169 补回 `"tags": ["减益"]`；卡面文案保持不变；西游档不套用 `skill_rework.json` 保持原样。
  2. **天虎令气伤（State 1341／3550 烽舞／7510～7513 天熄乱舞／7492 气傲天苍／红尘一步四招）→ 2A 天启篇收口未实装链路**：实测确认 `skill_rework.json` 的 `gear["armor:3550"]` 虽已将天熄乱舞收进 `_hidden_desc`（暂未实装），但运行期 `XMagicWeapon.item_skills` 仍从原版备注给天虎令塞入未改写的 7510～7513 旧卡并开战挂 1337～1340，红尘一步动作序列仍给敌方挂上 1341 气伤，而 `state_effects.gd` 守卫 `not XTianqi.active` 导致 1341 在天启篇沦为空壳死状态且持续报 `untranslated js`（直接放开西游档百万级公式则会击穿天启篇平衡）。按协调 2A 决议：
     - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/magic_weapon.gd` 新增可回退开关 `XMagicWeapon.TIANQI_SKIP_LEARN_SKILL := true`，在 `item_skills` 内仅对天启篇存档（`XTianqi.active(XState.current)`）返回空数组（全库仅 3550 烽舞带 `<Magic Weapon Learn Skill>`），不再露出 7510～7513 旧卡与开战 1337～1340；西游档路径一字未动；`state_effects.gd` 零改动。
     - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/skill_rework.json` 对红尘一步四招（7485／7508／7486／7487）的 `seq` 补 `drop_if` 去掉 `includes(1337)`～`includes(1340)` 挂 1341（保持 5 段不变），新增 7492 气傲天苍条目沿用 `"desc": ["效果：原效果已移除"]`（由 `XTianqiSkills.is_shell` 在技能列表自动隐藏）并保留原文于 `_hidden_desc`。
- 返修（小o 核查退回，cc 接手）：红尘一步 7485、7508 保留的公共事件 1406、1408 仍会让天启篇天虎令学会空壳 7492 并弹「天虎令领悟技能:气傲天苍」。`modes/xiyou/core/battle_common_event.gd` 新增 `command_list` 与开关 `TIANQI_SKIP_SHELL_LEARN := true`：仅天启篇存档，对这两个事件的指令副本删掉领悟 7492 的那一支（条件、领悟、记开关 2243、提示整段），剑思、业火不尽与其余 13 支领悟照跑，数据库原表不改，西游档拿原表。
- 玩家可见：天启篇里天虎令放红尘一步不再领悟没有效果的「气傲天苍」、不再弹它的领悟提示。天启篇中，小痔的「凛冬刺击」现已按技能说明正常对目标附加冰冷减速效果，不再误清除目标已有的冰冷状态；天虎令专属法宝「烽舞」暂未实装的旧版「天熄乱舞」与无效「气伤」标记已从天启篇隐藏清理，不再显示无效状态图标。
- 验证：
  - 新增专项 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_t523_lindong_qishang.tscn`：30/30 通过（返修补的 9 条：固定种子真跑 CE1406／1408 各 3000 次，天启篇抽到过第 3 号分支但不学 7492、不弹提示、不记开关 2243，其余 13 招与提示照常；关开关恢复；西游档两事件照学 7492 并弹提示、指令表与原表相同。原有 21 条覆盖：覆盖凛冬刺击天启篇场景 A/B、D200 开关与 `tags: ["减益"]`、天虎令不领悟 7510～7513、7492 空壳隐藏、红尘一步四招不挂 1341、强制 1340 防御、队友命中零诊断、回退开关 `TIANQI_SKIP_LEARN_SKILL = false` 及西游档 169/3550/7492/1341 零改动与 T491 原版公式气伤弹字总额核对回归）。
  - 本机回归（`--headless --audio-driver Dummy`）：`xiyou_caocao_tianhu_states.tscn` 36/36、`xiyou_magic_weapon_level.tscn` 63/63、`xiyou_magic_weapon.tscn` 43/43、`xiyou_fabao_99_scale.tscn` 113/113、`xiyou_tianqi_skills.tscn` 248/248 全部通过。
  - 返修本机回归：`xiyou_battle_common_events.tscn` 95/95、`xiyou_battle_common_event_child.tscn` 13/13；语法检查 0 问题。
  - 工具检查：`python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check` 退出码 0（86 个脚本，845 个函数都有）；`python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py` 退出码 0（全部通过）。
  - 返修后云端选测（提交 `54b927024`，已并入 `main` 的 `2059e79b2`；基准 `2059e79b24`，65 个场景、2 片，最长一片 17.4 分钟）：通过，运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45725913088 。工具回归全部通过。
  - 返修前云端选测（提交 `68be85aeb`，基准 `c6c4303175`，53 个场景、2 片，最长一片 10.1 分钟，零偶发）：通过，运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45721925823 ；合入 `main` 前首轮提交 `9644a68fc`（96 场景、2 片）亦已通过，运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45718322805 。
- 提交：9644a68fc、68be85aeb、返修提交（见下「本分支提交」）
- 未完成／已知问题：天启篇量级的天虎令「天熄乱舞／气伤」重做（2B）按协调决议留待 T522 全局数值预算定稿后单开卡设计，不在本单。

## 交接板

- 下一步：合并 `luiluu/t523` 进 `main`；后续 T522 全局数值预算定稿后，如需在天启篇启用天虎令气伤重做（2B），另开卡设计天启篇公式与卡面。
- 用户试玩说明：天启篇里小痔放「凛冬刺击」现在会正常给敌人挂上冰冷减速；天虎令穿「烽舞」不再出现旧版无用的「天熄乱舞」技能卡和空壳「气伤」图标。西游篇无任何变化。
- 需要用户决定：无

## 进度账

- 天启篇技能与状态一致性修复：本单收口 T519 查出的 2 处历史疑点（169 凛冬刺击、1341 气伤链），西游档零改动。

## 可优化（流程／工具／效率）

- 已做：首轮云端选测发现 `xiyou_t523_lindong_qishang.tscn` 在西游档混沌难度下未钉随机种子且未清敌护盾偶发 1 次，已在提交 `68be85aeb` 钉死 `XBattleRandom` 种子、清敌护盾并按 T491 原版公式核对气伤弹字总额，二轮云端选测（`45721925823`）零偶发通过（回退：移除 `setup` 的随机流参数即可）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XBattleCommonEvent.command_list` / 开关 `TIANQI_SKIP_SHELL_LEARN`（返修新增；`battle_common_event.gd` 不在派单独占清单里，见下） | `git grep -n 'command_list(' -- '*.gd'`：生产 2 处（`run_or_reserve`、`take`），专项 1 处 | 两处都是公共事件取指令表的入口；非 1406／1408 或西游档原样返回原表。偏离：领悟与提示在公共事件里，派单列的三个独占文件改不到，只能在这里加天启篇分支（改前查过没有别的未合并分支在改它）。 |
| `XMagicWeapon.item_skills` / 新增开关 `XMagicWeapon.TIANQI_SKIP_LEARN_SKILL` | 10 处（`git grep -nE '[^[:alnum:]_]item_skills[[:space:]]*\(' -- '*.gd'`，含定义行 1 处；加 1 处外部转发 `XMagicWeapon.skills` → `modes/xiyou/core/actor.gd:610`） | 调用方 9 处逐处结论（不含自身定义行）：① `modes/xiyou/core/magic_weapon.gd:444`（`XMagicWeapon.skills` 唯一生产转发点，经 `actor.gd:610` 进入 `XActor.native_skill_ids()`）：仅在天启篇存档且开关为真时返回 `[]`，全库仅 3550 烽舞带 `<Magic Weapon Learn Skill>`，西游档恒走原逻辑不受影响；② `tests/virtual_player/fabao_survey.gd:63`：调查脚本读 `note_skills`，天启篇如实反映不再领悟旧技能，西游档不变；③ `tests/xiyou_fabao_99_scale.gd:95, 102, 104, 454, 457`（5 处）：均为西游档测试上下文，实跑 113/113 全过；④ `tests/xiyou_t523_lindong_qishang.gd:200, 298, 326`（3 处）：本单专项，分别验证天启篇停用、回退开关关闭恢复与西游档原样领悟。 |

## 本分支提交

- 9644a68fc T523：天启篇修凛冬刺击附加冰冷II（1A）并收口未实装天虎令天熄乱舞／气伤链（2A）
- d006e5f23 T523：提交交付单 luiluu_t523.md（含本机与云端选测 45718322805 全绿结果）
- 68be85aeb Merge main (dfe1291cc) into luiluu/t523：解 skill_rework.json 冲突、为修复后的 169 补回「减益」标并钉死专项随机种子
- 9bec94761 T523：更新交付单（首轮交付）
- f256dd2cf T523 返修：天启篇 CE1406／1408 不再领悟空壳 7492 气傲天苍；交付单冰冷II 招数改 16
- 54b927024 合并 main（2059e79b2）进本分支
