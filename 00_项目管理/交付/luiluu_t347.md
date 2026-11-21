# 交付：luiluu/t347

- 车道／工作者：T347 测试工具修复／cc（Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-21 【cc·T347·未经审查】证道配队量数工具不再把超强者踢出（dev.待定）

- 原因：`tests/virtual_player/c_tier.gd` 的 `build_state` 写死艰险（super_cap=0），证道配队 95,43,105,130 的超强者 95 三笠被踢出 battle_members，`floor_gears` 取 `chosen[95]` 越界，该队掷不出装备。
- 改动：`build_state`、`floor_gears` 末位加 `difficulty` 参数（缺省艰险，旧调用不变）；`baseline_dps.gd` 把自己的 `--difficulty` 传下去；`floor_gears` 对「没掷出一套」「队员不在 battle_members」加断言，不再静默越界。只改测试工具，没动游戏本体。
- 专项：`xiyou_tianqi_c_tier` 加 5 项证道配队检查，本机 40/40。改前（艰险档）该队 battle_members 不含 95；改后（证道）为 [95,43,105,130]，每人都掷出装备。
- 没做：云端选测没跑（本机跑了专项）；其余调用方（xinmo_probe 等）仍是缺省艰险，要量证道自行传参。

## 交接板

- 下一步：无
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：xinmo_probe、brand_calib 调 build_state 时也传 difficulty（量证道时才需要，归量数车道）

## 本分支提交

- 见 git log
