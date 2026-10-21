# 交付：claude/zealous-kepler-332f05

- 车道／工作者：C 规则／八戒（Claude，重制_八戒_39）
- 状态：进行中

## 变更记录草稿

## 2026-10-21 【Claude·八戒·未经Codex检验】护盾运行时（ShieldSystem）（dev.待定）

- 照冻结源 `ShieldSystem.js` v2.8（插件参数 decayRate 0.20、damageReduction 0.5，从 Plugins.json 读）在 Godot 接上护盾：`XBattler.shield`；`add_shield`（正数 ×(1＋护盾加成)，不取整，不低于 0，非有限数按 0）；`shield_effect_bonus`（特性对象备注 `<ShieldEffect:n>` 各取第一处相加，再加真气「金身」）；`absorb_shield`（正伤害先扣护盾，扣完有剩余就 ×0.5 取整）；`decay_shield`（回合末减 floor(护盾×0.2)，倒下的也减）。
- 挂点照原版钩子顺序：`XBattleLogic.execute_hp_damage`（从 `_apply` 抽出，类型 1／3／5）外到内是真气护法／元婴 → 护盾 → 吸取取 min → 扣血、onDamage 充 TP、吸取回血（吸取充 TP 改按取 min 后的扣量，照 executeHpDamage）；`XResourceContext.gain` 扣血吸收护盾（公式 b.gainHp、Establish 附加伤害走这里）；`_regenerate` 流血先按 maxSlipDamage 夹到 hp−1 再经护盾；`end_turn` 每人 `decay_shield`；`end_battle` 全队与敌群清零。
- 原版细节（参照测出）：角色的 gainHp 是 krz_state_re 在 Game_Actor 上的自有方法，盖过后装的 ShieldSystem gainHp 钩子，由 setHp 钩子吸收——**角色结果槽／弹字记原值、实际扣量是减免后**；敌人结果槽记减免后。流血弹字顺带改成按 maxSlipDamage 夹后的值（原来记未夹的），生命 1 时夹成 0 不弹字。
- 转换器 `formula_program.py`：`a/b.addShield(x)` 翻成 `shield` 步骤（能力 `write.shield`，参数必须 1 个），`a.shield` 可读；VM（`formula_program.gd`／`formula_execution.gd`）执行与预览（预览在副本上，不写真护盾），逐句记录 resource 记 `shield`。切片外 107 钟离、131 椎名立希的 9 条护盾公式（5648～5651、5670～5674）全部翻译，全库未翻译 90 → 81。`XResourceContext.supported` 去掉 shield_resource_pending。
- 智能 AI（Codex_SmartBattleAI）：shieldPoints 只算原生护盾；伤害效用与急需度按 HP＋护盾，长战判定同；对友方的加盾技能按 shieldEstimate（同原版正则与「只含能力值和 Math」的限制，数值用公式预演的护盾增量，已含受益者加成）×缺口（生命上限 80%−现有护盾）加分。
- 侧栏状态（Window_BattleSideHP 钩子）：护盾大于 0 时 HP 条上叠蓝段（按 max(生命上限, HP＋护盾) 折算），HP 字样后写「盾＋数值」（万／亿…一位小数）；`view_of` 带 shield。
- 参照：新探针 `mv_oracle/shield_probe.cjs` → `shield.json` 103 例（grant 36、read 12、hit 19、gain 12、regen 24），Godot `tests/xiyou_shield` 逐例比 HP、TP、护盾、倒下、结果槽、护盾加成与公式值，另查预览不写护盾、回合末倒下的也衰减、战斗结束清零、addShield 边界、9 条程序已翻译。改动后 formula_effects／formula_program／formula_equipment／rules 十二份／smart_ai／zhenqi／actor_p0 专项通过。
- 没做：来源护盾账本（installSourceShieldLedgerRuntime，175 谷雨／176 屠苏／177 玄用，期限护盾分账）与 YEP 吸收屏障；107／131 加回切片由总装另派（actor_p0 里剔出说明仍写「护盾运行时未做」，加回时一并改）。

## 交接板

- 下一步：107 钟离、131 椎名立希可加回切片（护盾已通，派 A 车道）；期二「变身其余能力值」（原沙僧清单第 7 条，KNOWN_TRANSFORM_GAPS）本车道未开工，下周另派。
- 用户试玩说明：带护盾技能的角色（加回切片后）放盾后侧栏 HP 条出现蓝段和「盾N」，受击先扣盾、击穿后伤害减半，每回合盾衰减两成，战斗结束清零。
- 已知：`xiyou_battle_ui`（4 项）、`xiyou_battle_options`（1 项）在本工作树失败，换回 main 的 `modes/xiyou` 代码也同样失败，不是本分支引入（疑为机器忙时的界面时序），待总装在主工作区复核。

## 进度账

- 共性战斗规则：护盾系统从无到有（参照对照齐），角色 107／131 的阻碍解除；完成度由总装按账本口径评估。

## 本分支提交

- 5d8527d 护盾运行时第一步（吸收／减半／衰减／清零，公式 addShield 与 a.shield）
- fa51c4c 护盾参照探针与 Godot 逐例对照
- 27d1cac 智能 AI 护盾估算、侧栏护盾条
- （收尾提交）交付单、README、同步指纹
