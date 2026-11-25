# 交付：luiluu/t523

- 车道／工作者：天启篇丙档查证与修复／小A（Hydrogen＋high，P7）
- 状态：可合并

## 变更记录草稿

## 2026-11-26 【小A·未经审查】T523 天启篇修凛冬刺击附加冰冷II并收口未实装天虎令天熄乱舞／气伤链（dev.待定）

- 依据 T519 查出的两处原有疑点，先起天启篇实战战斗（`--headless --audio-driver Dummy`）实测查证，向协调回报后按决议（1A＋2A）落码，西游档零改动：
  1. **凛冬刺击（Skill 169，小痔）→ 1A 改天启篇数据、保留卡面**：原版 `Skills.json` 引用状态 23（冰冷II）的 15 个技能中，唯独 169 误写成效果码 22（移除状态），天启篇未覆写导致实测放 169 不仅无法挂上冰冷II，还会主动驱散敌人身上已有的冰冷II（敏捷 18→20）。在 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/skill_rework.json` 第 146 行 169 条补 `"effects_remove": [[22, 23]]` 与 `"effects_add": [{"code": 21, "dataId": 23, "value1": 1, "value2": 0}]`；卡面文案保持不变；西游档不套用 `skill_rework.json` 保持原样。
  2. **天虎令气伤（State 1341／3550 烽舞／7510～7513 天熄乱舞／7492 气傲天苍／红尘一步四招）→ 2A 天启篇收口未实装链路**：实测确认 `skill_rework.json` 的 `gear["armor:3550"]` 虽已将天熄乱舞收进 `_hidden_desc`（暂未实装），但运行期 `XMagicWeapon.item_skills` 仍从原版备注给天虎令塞入未改写的 7510～7513 旧卡并开战挂 1337～1340，红尘一步动作序列仍给敌方挂上 1341 气伤，而 `state_effects.gd` 守卫 `not XTianqi.active` 导致 1341 在天启篇沦为空壳死状态且持续报 `untranslated js`（直接放开西游档百万级公式则会击穿天启篇平衡）。按协调 2A 决议：
     - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/magic_weapon.gd` 新增可回退开关 `XMagicWeapon.TIANQI_SKIP_LEARN_SKILL := true`，在 `item_skills` 内仅对天启篇存档（`XTianqi.active(XState.current)`）返回空数组（全库仅 3550 烽舞带 `<Magic Weapon Learn Skill>`），不再露出 7510～7513 旧卡与开战 1337～1340；西游档路径一字未动；`state_effects.gd` 零改动。
     - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/skill_rework.json` 对红尘一步四招（7485／7508／7486／7487）的 `seq` 补 `drop_if` 去掉 `includes(1337)`～`includes(1340)` 挂 1341（保持 5 段不变），新增 7492 气傲天苍条目沿用 `"desc": ["效果：原效果已移除"]`（由 `XTianqiSkills.is_shell` 在技能列表自动隐藏）并保留原文于 `_hidden_desc`。
- 玩家可见：天启篇中，小痔的「凛冬刺击」现已按技能说明正常对目标附加冰冷减速效果，不再误清除目标已有的冰冷状态；天虎令专属法宝「烽舞」暂未实装的旧版「天熄乱舞」与无效「气伤」标记已从天启篇隐藏清理，不再显示无效状态图标。
- 验证：
  - 新增专项 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_t523_lindong_qishang.tscn`：20/20 通过（覆盖凛冬刺击天启篇场景 A/B 与 D200 开关、天虎令不领悟 7510～7513、7492 空壳隐藏、红尘一步四招不挂 1341、强制 1340 防御、队友命中零诊断、回退开关 `TIANQI_SKIP_LEARN_SKILL = false` 及西游档 169/3550/7492/1341 零改动回归）。
  - 本机回归（`--headless --audio-driver Dummy`）：`xiyou_caocao_tianhu_states.tscn` 36/36、`xiyou_magic_weapon_level.tscn` 63/63、`xiyou_magic_weapon.tscn` 43/43、`xiyou_fabao_99_scale.tscn` 113/113、`xiyou_tianqi_skills.tscn` 248/248 全部通过。
  - 工具检查：`python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check` 退出码 0（86 个脚本，845 个函数都有）；`python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py` 退出码 0（全部通过）。
  - 云端选测（提交 `9644a68fc`，基准 `a328b32697`，96 个场景、2 片，最长一片 15.9 分钟）：通过，运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45718322805 。注：云端并行阶段 `xiyou_t523_lindong_qishang.tscn` 偶发 1 次失败（rc=1），单独重跑 20/20 通过（原因：`XTianqi.start_new_game` 默认随机种子未钉死，场景 A 魔法技能 169 受天启篇随机检定波动影响，详见可优化节）。
- 提交：9644a68fc
- 未完成／已知问题：天启篇量级的天虎令「天熄乱舞／气伤」重做（2B）按协调决议留待 T522 全局数值预算定稿后单开卡设计，不在本单。

## 交接板

- 下一步：合并 `luiluu/t523` 进 `main`；后续 T522 全局数值预算定稿后，如需在天启篇启用天虎令气伤重做（2B），另开卡设计天启篇公式与卡面。
- 用户试玩说明：天启篇里小痔放「凛冬刺击」现在会正常给敌人挂上冰冷减速；天虎令穿「烽舞」不再出现旧版无用的「天熄乱舞」技能卡和空壳「气伤」图标。西游篇无任何变化。
- 需要用户决定：无

## 进度账

- 天启篇技能与状态一致性修复：本单收口 T519 查出的 2 处历史疑点（169 凛冬刺击、1341 气伤链），西游档零改动。

## 可优化（流程／工具／效率）

- 建议：`03_再刷重制_Godot/01_Godot工程/tests/xiyou_t523_lindong_qishang.gd` 的天启篇战局目前使用 `XTianqi.start_new_game` 默认随机种子，并行高并发云端跑测时曾出现 1 次偶发（单跑通过）；后续若再动该专项，可在 `lg.setup(2, s, XBattleRandom.create(...))` 传入固定种子消除随机波动（预计收益：消除偶发重跑约 10 秒）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XMagicWeapon.item_skills` / 新增开关 `XMagicWeapon.TIANQI_SKIP_LEARN_SKILL` | 10 处（`git grep -nE '[^[:alnum:]_]item_skills[[:space:]]*\(' -- '*.gd'`，含定义行 1 处；加 1 处外部转发 `XMagicWeapon.skills` → `modes/xiyou/core/actor.gd:610`） | 调用方 9 处逐处结论（不含自身定义行）：① `modes/xiyou/core/magic_weapon.gd:444`（`XMagicWeapon.skills` 唯一生产转发点，经 `actor.gd:610` 进入 `XActor.native_skill_ids()`）：仅在天启篇存档且开关为真时返回 `[]`，全库仅 3550 烽舞带 `<Magic Weapon Learn Skill>`，西游档恒走原逻辑不受影响；② `tests/virtual_player/fabao_survey.gd:63`：调查脚本读 `note_skills`，天启篇如实反映不再领悟旧技能，西游档不变；③ `tests/xiyou_fabao_99_scale.gd:95, 102, 104, 454, 457`（5 处）：均为西游档测试上下文，实跑 113/113 全过；④ `tests/xiyou_t523_lindong_qishang.gd:199, 297, 325`（3 处）：本单专项，分别验证天启篇停用、回退开关关闭恢复与西游档原样领悟。 |

## 本分支提交

- 9644a68fc T523：天启篇修凛冬刺击附加冰冷II（1A）并收口未实装天虎令天熄乱舞／气伤链（2A）
