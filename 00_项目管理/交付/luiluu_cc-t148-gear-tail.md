# 交付：luiluu/cc-t148-gear-tail

- 车道／工作者：T148 T104 尾巴（cc，Sonnet＋medium，P6；从 T104 分支切出，合并时总装先合 T104 再合本单）
- 状态：可合并

## 变更记录草稿

## 2026-11-17 【cc·T148·未经审查】T104 尾巴：掉落详情接 effective_params、差值退路不夹 0、upgrade_fixed current 判定、发行空壳补 XTianqiRandom.create_gear（dev.待定）

- `ui/map_transfer.gd` 掉落详情「基础属性」改读 `XTianqiGear.effective_params(item)`（小A 甲核 P2 漏接）；PHASE4 关着返回原数组，显示不变。
- `core/tianqi_gear.gd` 差值退路：新底子 `nb[i]==0` 的项（MP、副属性）原来 ±0 夹成 0，符文之语／随机石 1826～1828 加在这些项上的数全丢；现在这类项不夹，直接 `换算比×剩余`（`nb≠0` 的项仍夹 ±10%）。
- `upgrade_fixed` 的 `current` 判定改看「模板值＋前面已镶固定值」，与 `XGearUpgrade.apply_effects` 顺序执行时读 `gear.params[i]` 一致（原来只看镶前静态值）。随机镶嵌项在 apply 里也能把 0 变非 0，这里不知道掷值，仍按 0 处理（只在 `random` 项先于 `current` 项镶、且该项原值为 0 时有差，已记 `has_random`，随后差值退路兜底）。
- **发行空壳**：`发行空壳.py` 把 `XTianqiRandom.create_gear` 生成成 `return {}`；`XState.gain_gear` 无条件调用它，`inst.is_empty()` 时直接不发装备。**发行包里会走到**（所有 `gain_gear`：商店买、掉落、任务奖励），所以不是理论问题，是发行版得不到装备。`发行空壳特例.json` 补 `XTianqiRandom.create_gear → XGear.create(kind, base_id, s)`（天启篇关着时真函数 `source=="" or not gear_base_on` 的结果就是这条）。`发行空壳.py check` 通过，show 核对生成体正确。
- 测试：`xiyou_tianqi_gear_params` 加 `resid_zero_base_passes`（MP 上的符文之语差值按换算比放行）、`upgrade_fixed_empty`。

## 验证
- 语法检查 0 问题；`发行空壳.py check` 通过；并行测试 `xiyou_tianqi_gear_params`＋`xiyou_determinism` 全过。
- 选测（相对 T104 提交 62ce45ff3 的 `选测.py` 名单，20 个场景＋`xiyou_determinism`）21 个全过；工具回归全过；交付自检退出码 0。
- **`检查.sh --affected main` 没跑完**：本分支叠在未合 main 的 T104 上，相对 main 选中 449 个场景，本机约 40 分钟只完成 32 个（估 9 小时），已停。改用相对 T104 的增量选测代替；总装合并时（T104 先合）影响面会缩回本单这 3 个文件，按那时的 `--affected` 跑即可。

## 我不同意的地方
- 无大分歧。`current` 一项我只做了顺序累加，没有做完整模拟（随机项、百分比项的先后），理由见上；加断言 `upgrade_fixed_empty` 只是冒烟，没有为「0 → 非 0 后 current 块生效」造专门用例（需要真实带 current 的石头数据，未去找）。

## 待交叉核查
- 提交见分支；`tianqi_gear.gd` 差值退路、发行空壳特例。
