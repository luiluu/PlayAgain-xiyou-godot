# 交付：luiluu/t491-caocao-tianhu-port

- 车道／工作者：T491 西游档战斗效果移植／小A（Gemini 4 Neon＋high，职级 P8）
- 状态：可合并

## 变更记录草稿

### 2026-11-25 【小A·未经审查】T491 西游档移植曹操霸道真气 Regenerate 与天虎令气伤 Apply／React（dev.待定）

- 玩家可见：西游篇中，曹操的「霸道真气」回合结束伤害与天虎令的「气伤」受击追加伤害现已按原版效果正常生效，且随 99 级专属法宝等比例折算至原版满级强度。
- 改动：
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/state_effects.gd`：新增开关 `XStateEffects.PORT_CAOCAO_TIANHU := true` 与西游档守卫 `_caocao_tianhu_active()`（要求 `PORT_CAOCAO_TIANHU and XState.current != null and not XTianqi.active(XState.current)`），在 `XStateEffects.run_one` 中按原版 v0.62.12 逐行移植两项原本仍停留在未翻译 `op: "js"` 的状态效果：
    1. **曹操霸道真气（State 106）`regenerate`**：`_caocao_regenerate_106`。`origin` 非 `XActor` 时等价原版 `origin.equips()` 抛 TypeError 直接中止（不写 `_stackingPoison`、不扣血、不播动画）；否则经 T490 共用读口 `XEquipmentView.first_armor_level(origin.equip_list(), 3640)` 读「暗涌」战斗等级（99 级等价 888，楼层上限先压实际等级再折算），按 `stacks = _stackingPoison || 1`、`damage = stacks * (origin.atk + origin.mat) * origin.level * (1 + level)` 扣血并走护盾吸收、死亡结算、动画 130、弹字与 `clearResult`。
    2. **天虎令气伤（State 1341）`apply`／`react`**：`_tianhu_apply_1341` 按原版执行 `_stateCounter["1341"] = clamp((cur || 0) + 1, 0, 10000)`（移除状态时由 `battler.gd` 清空计数）；`_tianhu_react_1341` 不修改主伤害 `value`，先按原版顺序抽 1 次 `XRandomStream`（对应 `Math.random(1) < origin.cri`），若 `value > 0` 且当前行动为技能（`item.has("stypeId")`）则按 `dmm = max(0, origin.atk * 2 + origin.mhp)`、`ddd = ceil(target.elementRate(1) * origin.mdr * dmm * (1 + d * 0.25) / 2)`（`d == 0` 时不乘 `1 + d * 0.25`）算基伤，当 `origin.skillMasteryLevel(7485) >= 1` 时经 T490 共用读口 `XEquipmentView.first_armor_level(origin.equip_list(), 3550)` 读「烽舞」战斗等级并追加 `ceil(ddd * (mastery + level))`，随后经 `XResourceContext` 直接 `gain(target, "hp", -ddd)` 与 `start_damage_popup(target)`。
  - 天启篇（`XTianqi.active(XState.current)` 为真）与无存档静态参照（`XState.current == null`）完全走原 `op == "js"` 分支，零改动；不修改 `States.json`（保留 `inventory.untranslated_46` 与 `xiyou_state_js` 既有基线）；关闭 `XStateEffects.PORT_CAOCAO_TIANHU = false` 立即回退到未移植现状。
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_caocao_tianhu_states.gd`（及 `.tscn`、`.gd.uid`）：新增原版 v0.62.12 固定种子（`hex64(491)`）与固定面板对拍专项测试（35/35）。
- 原版 v0.62.12 对拍数据（参照 `03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw` 实测，固定面板与固定种子 `hex64(491)`）：

| 样本 | 原版公式与条件 | 原版 888 级实测数 | 本分支 99 级实测数 | 结论 |
| --- | --- | --- | --- | --- |
| 曹操 106（暗涌满级，3 层） | `3 × (500 + 300) × 60 × (1 + 888)` | `128,016,000`（动画 130） | `128,016,000`（动画 130） | 一致 |
| 曹操 106（0 层兜底 1 层） | `1 × (500 + 300) × 60 × (1 + 888)` | `42,672,000`（写回 1 层） | `42,672,000`（写回 1 层） | 一致 |
| 曹操 106（护盾 1,000,000） | `(42,672,000 - 1,000,000) / 2` | `20,836,000`（盾归 0） | `20,836,000`（盾归 0） | 一致 |
| 曹操 106（无暗涌，2 层） | `2 × (500 + 300) × 60 × (1 + 0)` | `96,000` | `96,000` | 一致 |
| 曹操 106（敌人来源） | `origin.equips()` 抛 TypeError 中止 | `0`（不改层数／无动画） | `0`（不改层数／无动画） | 一致 |
| 天虎令 1341（熟练 5、1 层、烽舞满级） | `ddd0 = ceil(1.33×0.77×20800×1.25/2) = 13314`；`13314 + ceil(13314×(5+888))` | `11,902,716`（主伤 `1000` 不变，抽 RNG 1 次） | `11,902,716`（主伤 `1000` 不变，抽 RNG 1 次） | 一致 |
| 天虎令 1341（熟练 5、3 层、护盾 500,000） | `ddd0 = ceil(1.33×0.77×20800×1.75/2) = 18639`；`(18639×894 - 500,000)/2` | `8,081,633`（盾归 0） | `8,081,633`（盾归 0） | 一致 |
| 天虎令 1341（熟练 0、3 层） | `ceil(1.33×0.77×20800×1.75/2)` | `18,639` | `18,639` | 一致 |
| 天虎令 1341（熟练 2、0 层、无烽舞） | `ddd0 = ceil(1.25×0.8×20800/2) = 10400`；`10400 + 10400×2` | `31,200` | `31,200` | 一致 |
| 天虎令 1341（物品／`value == 0`） | `value > 0 && isSkill()` 不满足 | `0`（抽 RNG 1 次） | `0`（抽 RNG 1 次） | 一致 |

- 验证：
  - 本机前台逐项（均带 `--audio-driver Dummy`）：
    - `tests/xiyou_caocao_tianhu_states.tscn`：`35/35`（退出码 0）
    - `tests/xiyou_fabao_99_scale.tscn`：`113/113`（退出码 0）
    - `tests/xiyou_state_effects_tp.tscn`：`544/544`（退出码 0）
    - `tests/xiyou_state_js.tscn`：`1733/1733`（退出码 0）
    - `tests/xiyou_state_effects.tscn`：`32816/32816`（退出码 0）
    - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：82 个脚本，812 个函数都有（退出码 0）
    - `python3 03_再刷重制_Godot/07_开发环境/随机守卫.py`：85 个天启篇脚本没有未注明的全局随机（退出码 0）
  - 云端选测（提交 `da42bcfbcb`，基准 `7bb22d62b2`，95 个场景、9 片，全绿通过，最长一片 13.6 分钟）：
    - https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45538661038

## 交接板

- 下一步：合并后可安排小o 复核 T491（甲档第二道），并将两状态表现纳入后续西游档曹操／天虎令实机核验。
- 用户试玩说明：西游篇中，曹操的「霸道真气」在敌方回合结束时会正常结算真气持续伤害与 130 号特效，天虎令的「气伤」在技能命中受击目标时会正常触发额外气伤伤害段，且两者均随 99 级专属法宝等比例折算至原版满级强度。
- 需要用户决定：无

## 进度账

- 西游档战斗状态效果移植（续 T490）：补齐 State 106（曹操霸道真气 Regenerate）与 State 1341（天虎令气伤 Apply／React），天启篇零改动。

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XStateEffects.run_one` | 94 处调用（含定义共 95 行：`git grep -nE '[^[:alnum:]_]run_one[[:space:]]*\(' -- '*.gd'`） | 调用方 94 处逐处结论：生产 5 处中 `battler.gd:803/806`（`apply`/`remove`/`leave`）仅对西游档 State 1341 `apply` 走新增计数器分支、`state_effects.gd:328`（`run` 总分发）仅对西游档 State 106 `regenerate` 与 State 1341 `react` 走新增移植分支，`nanoha.gd:180`（`battle` 阶段）与 `tianqi_ledger.gd:392`（天启篇 `confirm` 阶段）均不命中 `106/1341` 且天启篇被 `XTianqi.active` 守卫排除；测试 89 处（`xiyou_state_effects.gd`、`xiyou_state_effects_tp.gd`、`xiyou_state_js.gd`、`xiyou_fabao_99_scale.gd` 等）在无存档或非 106/1341 场景下完全走原路径，实跑及云端 95 场景全绿无回归。 |
| `XStateEffects.PORT_CAOCAO_TIANHU` | 新增开关（默认 `true`，`git grep -n 'PORT_CAOCAO_TIANHU' -- '*.gd'`） | 仅由 `state_effects.gd` 内部 `_caocao_tianhu_active()` 读取与 `tests/xiyou_caocao_tianhu_states.gd` 覆盖回退支；设 `false` 可秒级回退到未移植现状。 |

## 本分支提交

- `da42bcfbc` T491：西游档移植曹操霸道真气 Regenerate 与天虎令气伤 Apply/React
