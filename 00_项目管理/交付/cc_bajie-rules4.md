# 交付：cc/bajie-rules4

- 车道／工作者：C 规则／八戒（cc，唐僧总装十九派）
- 状态：可合并
- 基于 cc/bajie-rules3，合并时直接合本分支。

## 变更记录草稿

## 2026-11-04 【cc·八戒·未经审查】伤害 react／confirm 切片可达 15 块翻成原生实现（dev.待定）

- **原版行为**（`state_effects_probe` 新用例 `effect.blocks` 实测，单块 1440 行、实战 60 例）：15 个状态写法各不相同，逐块实测。要点：
  - 甘露护体 1060 的 `_Shield` **不是**护盾系统的护盾，只有这个状态的块读写：获得时加 `mhp*10`，React 时用它抵伤。普通 `gainHp` 不会被它吸收。
  - 不死之躯 2554 写错了方法名 `target.RemoveState`，TypeError 被外层接住：回血、弹字都做了，状态留着，所以这个状态不会被用掉。同名的 1580 正常，用一次就没。
  - 护体罡气 2562 破盾时移除的是 1662，不是自己（2562）；MP 归零后状态仍在。照原版。
  - 智识 1450 的条件是 `value>0 且魔法 或 物理`（物理不看 value），循环 `变量+1` 次，每次 value 累积变化、抽一次随机，最多 11 次；循环后变量清零。
  - 永世乐土 1302、剑道争锋 2575 只写 `_zuizhongshanghai`、`jqsbt`，冻结源 js 与数据里没有别处读，也不改 value，**在原版就没有效果**。
- **转换器**（`xiyou_export.py`、`formula_program.py`）：`MEASURED_EFFECT_BLOCKS` 13 个整块 token 白名单（另加 1060 获得、1450 行动开始，共 15 块）译成 `effect_program`；`UNREAD_FIELD_BLOCKS` 6 块译成 `noop`（1302 一块、2575 五块）。不在表里一律退回 js。公式编译器只在 `phase_effects` 时多认弹字、清结果、移状态、变量写入、`for` 计次循环，伤害公式不受影响。生成数据 `op: js` 284 → 263。
- **运行时**（`state_effects.gd`）：`PhaseValueProgram` 带 `effects` 时可跑副作用程序，副作用只在 execute 时做、走行动资源上下文，预览只算 value。字段 `_Shield`、`_xmx` 存 `state_data`（`_xmx` 在角色身上跨战斗保留，同原版字段）。
- **攻击者弹字与倒下**（`battle_logic.gd`、`battle_scene.gd`）：原版 `invokeAction` 收尾有 `subject().startDamagePopup()`，以前重制没做。现在 `apply` 记 `user_popups`、`user_died`，场景弹字并播倒下（混元护体反弹打死攻击者等）。这条对所有会动到行动者结果槽的技能都生效，属于原版行为补齐。
- **报数**：`xiyou_state_effects_tp` 的未翻译块改 `inventory.untranslated_121`（换装 142 不变）。
- 测试：`xiyou_state_effects` 加 `_effect_blocks`；`测试状态js翻译.py` 加 `EffectBlockTranslationTests`；`测试未翻译块清单.py` 换还没翻的例子。

## 交接板

- 下一步：未翻译状态块剩 263（换装 142 不用翻，真未翻 121）；切片可达里伤害 react／confirm 已清零，按 `未翻译块清单.py --detail` 接下一族（切片可达总数 47，含换装）。全游戏可达、不可达的同族 28 块没动。
- 用户试玩说明：甘露护体、混元护体、半步真仙效果、太乙、智识、不死之躯、千刃乱雨、均衡、五绝神功、血梅香、护体罡气现在按原版生效。攻击者吃反弹时会弹伤害数字，被打死会倒下。
- 需要用户决定（原版疑似笔误，都默认照原版，要改请总装分配优化登记号）：
  1. 不死之躯 2554 因方法名写错，无限次复活（同名 1580 只有一次）。
  2. 永世乐土 1302、剑道争锋 2575 的「最终伤害」累积字段没人读，这两个状态的这部分效果等于没有。
  3. 护体罡气 2562 破盾时移除 1662 而不是自己，破不了盾。

## 进度账

- 战斗规则：未翻译状态块 284 → 263（真未翻 142 → 121）；切片可达「伤害 react／confirm」15 块清零。

## 可优化（流程／工具／效率）

- rules3 评估 `value_query` 时说「等第二族用到再抽公共部分」，这次确实用到了：`effect_program` 比 `revive` 的 `steps` 更通用（条件、表达式都走公式 IR）。`revive` 的 17 块以后可以并进来，收益小，不急；新的族直接加白名单就行，单块成本低了很多。

## 验证

- 云端选测：提交 c36246a08b，210 个场景 7 片，全过（Actions run 41751521215）；`xiyou_rules` 按选测抽样，没关抽样。
- 专项（本机）：`xiyou_state_effects` 24688、`xiyou_state_effects_tp` 538、`xiyou_state_js` 1733、`xiyou_formulas` 7、`xiyou_honghuang_curse_battle` 344、`xiyou_determinism` 372、`xiyou_battle_events` 108、`xiyou_boss_state_origin` 15723、`xiyou_battle_ui` 155、`xiyou_battle_log` 50，全过。
- 工具：`测试状态js翻译.py`、`测试未翻译块清单.py`、`测试公式程序.py` 过；`语法检查.py` 0 问题；`内容覆盖检查.py` hard 0、new 0。
- 同步：`同步正式西游.py --accept-additions` 退出码 0；同步后只提交了测试文件和本交付单，产物指纹仍有效。
- 没测：攻击者倒下的实际画面只查了逻辑记录（`user_died`），场景分支没有专门的画面断言。

## 本分支提交

- b81386b9 WIP: rules4 伤害一族 21 块翻成 effect_program／noop，探针 effect.blocks，攻击者弹字与倒下
- c36246a0 未翻译块清单测试换还没翻的例子
- 本交付单收尾提交

## 待交叉核查（核心文件）

- `state_effects.gd`（`effect_program`、`PhaseValueProgram` 的副作用）、`battle_logic.gd`（`user_popups`、`user_died`）、`battle_scene.gd`、`formula_program.py`（`phase_effects` 不影响其它公式）。
