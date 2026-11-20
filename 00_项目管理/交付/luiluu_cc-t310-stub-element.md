# 交付：luiluu/cc-t310-stub-element

- 车道／工作者：T310 发行空壳 map_element_id（cc，Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T310·未经审查】发行空壳 map_element_id 不再把属性号抹成 0（dev.待定）

- 真脚本 `XTianqiElements.map_element_id` 首句 `if deck_on(s) and e == 1: return 0`，空壳规则 2 照抄首句返回值，发行包里恒 `return 0`，招式属性号全按无属性（抗性／弱点、克制、属性增伤、元素附加等失效）。已发补丁线不含此函数，玩家未受影响；下次从 main 出整包会带上，故先修。
- `发行空壳特例.json` 加 `"XTianqiElements.map_element_id": "e"`（原样返回）；`测试发行空壳.py` 加 `test_map_element_id_stub_passes_element_through`（含去掉特例变回恒 0 的反向验证）。
- 扫描规则 2「照搬关着时的返回」共 269 个函数：首句返回常量、而函数末尾实际透传参数的只有 map_element_id 一个，其余（`if not on(): return 参数` 等）首句本来就返回参数，或常量是「关着」的正确值。无拿不准项。

## 交接板

- 下一步：无
- 用户试玩说明：无（发行包下次出包后属性抗性／弱点等恢复）
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：发行空壳.py 规则 2 可加一条自动告警——首句返回常量、末尾 return 的是参数名时报警（预计收益：防同类漏，归工具车道）；本单没做。

## 本分支提交

- 见 git log
