# 交付：claude/busy-hopper-53b335

- 车道／工作者：C 规则／八戒（Claude，重制_八戒_37）
- 状态：可合并

## 变更记录草稿

## 2026-10-21 【Claude·八戒·未经Codex检验】装备 `<Custom Parameters>` 加成（dev.待定）

- **起因**：冻结数据 224 件武器／防具带 YEP_EquipCore `<Custom Parameters>`（`evalParamPlus` 在 `paramPlus` 里逐件 eval，`user`＝角色、`v`＝`$gameVariables._data`），Godot 没实现，这些装备能力值偏低（新手水果刀 1595 `atk = user.level * 2` 等），角色 104 天虎令也卡在这里。
- **写法统计（224 件，23 种形状，全部可结构化，没有函数调用或条件分支）**：
  - 只用等级（`<别名> = user.level * N;` 若干行）：209 件。别名出现过 maxhp、maxmp、mhp、mmp、atk、mat、def、mdf、agi、luk；最多的是「maxhp/maxmp/def/mdf」62 件、「luk/agi/def/mdf」28 件、六项 18 件、八项 14 件、「atk/mat」14 件、只 atk 9 件（新手武器）。
  - 等级＋变量（`atk = user.level * N + v[K]*M` 等）：11 件（水果武器 1706～1715 读 v[381]～v[446]，无影剑 1914 读 v[801]～v[808]）。
  - 只读变量：2 件（麒麟对剑 74／75，法宝，读 v[949]～v[956]）。
  - 先读变量、后又被等级覆盖（最后一次赋值为准，只剩 maxhp／maxmp 读变量）：2 件（千古啸*极／*尘 1926／1927，读 v[941]～v[948]）。
  - 无效赋值：戮仙剑 78 有一行 `tp = user.level * 20`（`tp` 不是该函数的局部变量，非严格模式下写成全局变量，对能力值无影响），记 `ignored`。
- **转换器**（`equipment_rules.custom_params`，`xiyou_export.py` 工具版本 20）：照 `processEquipNotetags2` 按行取标签内原文，逐条解析成每项能力的 常数＋等级系数＋Σ变量系数，写进武器／防具记录的 `customParams`；同名变量多次赋值以最后一次为准；别名按 `evalParamPlus` 的 switch 归到 8 项（`all` 加到每项）。认不出的语句整件记 `unsupported` 并进 manifest issues（`unsupportedCustomParams`），不静默当 0；现 224 件全部解析成功。
- **Godot**：`XActor.param_plus` 每件装备加 `custom_param(e, i)`，按当前等级与 `XState.current` 变量求值；不受被动 passiveWPNM／ARMM 放大（原版 dsPassiveSkill 只放大 `item.params`）；dev.111 的法宝 `magic_param` 保留。原件按数据库基础编号取（同 `magic_param`）。
- **参照**：新探针 `custom_params_probe.cjs`（`custom_params.json`）每种写法挑一件（新手水果刀、新手《字典》、死霸装类护甲 4160、铁靴 4162、千古啸 1925、火语项链 4188、戮仙剑 78、无极西瓜刀 1706、千古啸*极 1926、麒麟对剑*极 74），单独装到切片角色身上（其余卸下；专属给切片外角色的直接写槽位并停掉该实例的 releaseUnequippableItems），在 1／20／60 级量 evalParamPlus、paramPlus、param(0..7)；读变量的另在 20 级量「未设」与两组变量值。共 10 例 39 行。
- **测试**：`tests/xiyou_custom_params` 逐行对照，160 项全对（去掉 `custom_param` 后 98/160，确认测试有效）；另查转换器 224 件全部解析。
- **验收**：合 main 后 `同步正式西游.py --accept-additions`（新探针执行、其余沿用，测量不变）；`检查.sh --oracle` 全部通过、无偶发（第一次在 Godot 测试阶段排在别的工作树测试后面，一小时无输出被长任务看门狗停掉，加大 `TASK_IDLE_TIMEOUT` 重跑通过）。
- **与原版不同（建议登记优化登记）**：原版读到从没设过的变量时 `undefined*N` 得 NaN，整项能力值变 NaN；Godot 按 0。这些变量由 CE812、Map005／Map137 的事件设置，正常流程里拿到水果武器时已设；参照「vars_unset」行记 null，测试只要求 Godot 是有限数。

## 交接板

- 下一步：沙僧清单第 9 条「装备 `<Custom Parameters>`」已完成（dev.待定），划掉；角色 104 天虎令（千古啸／布丁）可以加回切片了（`xiyou_actor_p0.gd` 第 17 行的注释届时改掉）。
- 小项：`dual_wield_probe.cjs:66`、`magic_weapon_probe.cjs:41` 的注释仍写「Godot 未实现」，下次改这两个探针时顺手改（这次不改，免得重跑它们）。
- 用户试玩说明：带 `<Custom Parameters>` 的装备（新手武器、各类靴／项链／戒指／护符、坐骑、千古啸等）装上后能力值按等级加成，与原版一致。
- 需要用户决定：无。

## 进度账

- 战斗规则／装备：带 `<Custom Parameters>` 的 224 件装备能力值从偏低改为与原版一致；完成度由总装按进度账口径估。

## 本分支提交

- 009cea6 装备 `<Custom Parameters>`：转换器解析、`XActor.param_plus` 逐件求值、参照探针与测试
