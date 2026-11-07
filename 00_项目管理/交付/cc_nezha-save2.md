# 交付：cc/nezha-save2

- 车道／工作者：存档／哪吒（cc，项目线程「完成再刷西游Godot引擎重制」）
- 状态：进行中（接续）
- 基于：cc/nezha-save1 头（1c45a467，EF 还没合进 main）。合 main 时 EF 已在里面就不会冲突。

## 接续要点（哪吒上一会话上下文到线，只建了分支，没写代码）

派单两项，停手条件：两项做完，或上下文到 40%。

1. **报告第 10 项：读档校验**
   - 位置：`modes/xiyou/core/xsave.gd` 的 `valid_data`（约 127 行）只查了顶层和 actors 的部分字段；`modes/xiyou/core/xstate.gd` 的 `from_dict`（834 行起）读得更多。例如 885 行 `var os: Dictionary = d.get("orbState", {})`：存档里 orbState 是数组时会报类型错。
   - `_load_data` 先 `XState.from_dict(d)`，from_dict 里把 `XState.current` 换掉，之后才跑各包装。要改成两步：先完整构建出新状态，成功后才替换 `XState.current`，再报成功。
   - 做法：先写损坏样例测试（把 orbState 改成数组，以及 from_dict 里其它实际读取的字段各挑代表）。测试要走真实写盘：写 save_N.json，再经 `XSave.load_slot`／存档页读档。断言读档返回失败、当前状态不变、没有脚本错误。确认旧代码上会挂，再修。
   - 校验范围：把 from_dict 实际读取的每个字段逐一列出来补进 valid_data，或者让 from_dict 返回 null 表示失败。只校验、不改档案格式。
2. **Map004 漩涡过场 rift1 残留 options.json**
   - 现象：从 Map004 起跑、用 `XSave.dir_override` 的测试，首跑和再跑结果不一致。原因是上一轮在临时目录留下的 options.json（XConfig）里带着 rift1（漩涡过场看过）的标记。
   - 做法：这类测试开头先删掉临时目录里的 options.json，再显式标上 rift1。已知例：lobby_shops 的 `case_e54p0_base_0-0`，以及 `recruit_11`。用 grep 找全：`tests/` 里设了 dir_override、又起在 Map004 的。
   - 复现：同一场景连跑两次，结果要一致。

## 本分支提交

- （只建了分支）
