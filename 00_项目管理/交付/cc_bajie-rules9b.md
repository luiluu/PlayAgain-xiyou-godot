# 交付：cc/bajie-rules9b

- 车道／工作者：C 规则／八戒（cc）
- 状态：等云端选测

（接着 `cc_bajie-rules9.md` 的任务一；原接续单的内容并在这里，接续单已删。）

## 变更记录草稿

## 2026-11-04 【cc·八戒·未经审查】插件备注真缺三项：多属性核对无差异、防具 4998 属性反弹、隐月叠层结论（dev.待定）

- **Multi-Element Rule（16 个技能）：重制本来就对，没改伤害代码。** 新探针 `multi_element_probe.cjs`（产物 `multi_element.json`，228 例）对 16 个技能逐个量：每个属性轮流当最优、吸收、部分免疫、全免疫、全低抗、单属性增幅、原公式对两个真实敌人，重制全部逐例相等。原版 `installDamageElementRuntime` 第 176 行就是取对攻击方最有利的一个属性，和 `damage.gd` 相同；把 `elementMultiRule` 改成五种规则数值都不变，标签本身无效。
- **更正上一位的判断**：接续单说「7006 含属性 2 却是 1734，单属性 2 是 1856，所以原版不是取最大」，这是拿不同技能比出来的。对照用的技能 1 是物理（`hitType 2`）、公式也不同，防御权重不一样；同条件下 7006 三个属性轮流当最优都是同一个数。原版没有「平均」合并，第 131 行的平均只在治疗分支。
- **Element Reflect（防具 4998 圣光の屌丝，小明专属）：已实现。** 原版 `YEP_ElementCore` 的 `itemMrf` 把行动每个属性的反弹率加到反射率上，没被 codex 运行时接管，而且**不看命中类型**：魔法、必中、物理的神圣技能都反弹（实测 `reflect.*`）；含属性 8 的多属性技能（10007、10008）也反弹，不含的不反弹。转换器导出 `yep.elementReflect`，`XDamage.element_reflect_rate` 算反弹率，`_invoke` 加到反射率上，必中（certain_hit）照旧不反弹。数据里没有 `<Bypass Element Reflect>`，不实现。
- **Max State Floor（隐月 1323～1327、2521）：不用实现。** 上一位实测原版恒 1 层（已带着的状态不重挂），`_push_rows` 补注释，`xiyou_pushstate` 补断言（连命中 4 次 `state_ids` 里 1323 只有一份）。

**玩家看到的变化只有一处**：小明穿 4998 时，受到含神圣属性的行动会反弹回施放者（之前重制没有这个效果）。多属性伤害和隐月数值不变。

改到的核心文件（请重点核）：`battle_logic.gd`（`_invoke` 一行、`_push_rows` 注释）、`damage.gd`（新增 `element_reflect_rate`、一行注释）、转换器 `xiyou_export.py`（`parse_yep` 加反弹）。没动回合结束段和吸血钩子。

## 验证

- 专项 `xiyou_multi_element`（新，675 项）、`xiyou_pushstate`（91 项）全部通过。
- 反向验证（`反向验证.py`）4 项全咬住：多属性改成取第一个、反弹只认魔法、不读反弹、已带着也重挂。
- `语法检查.py` 通过。
- 云端选测：待填。
- **同步没有干净退出**：`同步正式西游.py --accept-additions` 第一次卡在别的车道合入的 `dot.json`（见「可优化」）。我从 `cc/wukong-dot1` 工作树只读拷了一份 `dot.json`（用例与我本地探针结果逐字相同），之后同步跑完，但退出码 2、结果「有变化，请人工查看」，唯一的变化是 `dot.json` 新增参照，`issues` 为空。所以这条分支**没留下可免重跑的干净指纹**，合并时要看 `dot.json` 这一项。

## 交接板

- 下一步：无（三项都完）。
- 用户试玩说明：小明穿圣光の屌丝，让敌人用神圣技能打他，技能应反弹回敌人。
- 需要用户决定：隐月（技能 7489、7503～7506、10119 剑饮空月）说明写「每层 +2%…可无限叠加」，原版代码实际只有 1 层。默认照原版保持 1 层，说明不改；Kyo 决定要不要改成真能叠。

## 进度账

- 插件备注真缺：Multi-Element Rule、Max State Floor、Element Reflect 三项处理完。`插件备注覆盖.py` 里 Max State Floor、State Can Added Floor 仍显示「拿不准（仅测试／探针里出现）」，没查它为什么不认 `battle_logic.gd` 里的注释；这两个标签结论是不用实现。

## 可优化（流程／工具／效率）

- **`dot_probe.cjs` 的产物会挡同步（归总装／悟空，建议先看）**：`dot.json` 的 `observed.*.errors` 故意记录原版公式报错，`has_error` 把它当探针错误；主工作区的 `generated/oracle` 又还没有这份文件，合并了 main 的分支第一次同步就报「探针产物有新增或变化的错误：dot.json」。合并收尾时可能碰到同样的问题。可把这个字段改名（如 `codeErrors`），或给它加豁免。
- 接续单里的旧参照建议（`--补齐` 比较 oracle 修改时间）在这轮没复现：开工时 `state_effects.json` 与主工作区一致。
- 没查的小事：原版 `$gameActors.actor(1).changeLevel(50, false)` 后等级读出来还是 10，重制 `change_level(50)` 是 50。探针改用新局默认等级绕开了，正常流程有没有影响没核。

## 本分支提交

- 见 `git log main..cc/bajie-rules9b`。
