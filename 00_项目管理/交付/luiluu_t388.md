# 交付：luiluu/t388

- 车道／工作者：T388 发行空壳字符串扫描补漏（T385 核 P2-1/P2-2/P3-1）／cc 车道（Sonnet＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-22 【cc·天启篇·未经审查】发行空壳字符串扫描补漏（T388，dev.待定）

- `TIANQI_WORDS` 补「侵染、蚀骨｜本线异化图鉴｜确认取核｜战商｜装备环纹」（单独「取核」在 alien_workshop `DANGER_RE`，不收）。新命中照 `MIXED_STR` 登记：alien_workshop.gd 13→17、boss_status.gd 2、options_scene.gd 1、skin_six_dim_radar.gd 1；逐处核过都在天启篇开关后面（tq_on／confirming_core／XTianqiAlienCodex.on／XTianqiSixDim.active／XUiSkin.on）。
- `is_stub_tree` 改用 `tianqi_string_hits`：任何不换空壳的脚本只要还有命中就报错，不再只查登记文件；`发行内容审计.py --tree` 因此能检出未登记文件的新命中。
- `_STR_LIT` 认 `r"..."`／`r'...'`（占位保留 r 前缀）；`_strip_comment` 按引号前连续反斜杠奇偶判断是否转义。
- 游戏脚本零改动，只改 `发行空壳.py`、`测试发行空壳.py`。

## 验收逐条

1. P2-1：见上，新命中已登记。
2. P2-2：测试 `test_t388_new_words_unregistered_tree_and_lexer` 断言未登记文件命中时 `is_stub_tree` 报错。
3. P3-1：同测试覆盖 `r"战商\n"` 命中与保留 r 前缀、偶数反斜杠后注释不算。
4. `测试发行空壳.py` 27/27 OK；西游档零变化（游戏脚本零改动；make_tree 克隆上 `发行内容审计.py --tree` 退出码 0）。
5. 交付单＋自检见回执。

## 验证

- `发行空壳.py check`：81 个脚本，775 个函数都有；`测试发行空壳.py` 27/27；`发行内容审计.py --tree`（make_tree 克隆）0。

- 替换后能编译（补验）：make_tree 克隆里对 alien_workshop、boss_status、options_scene、skin_six_dim_radar 四个脚本无头 Godot（--audio-driver Dummy）load()＋reload()，4/4 OK、无 SCRIPT ERROR；`发行空壳.py smoke` 跑 xiyou_battle＋xiyou_battle_ui 通过。云端选测 0 场景，免。

## 没做／偏离

- 「战商」在 skin_six_dim_radar.gd 的 `DIM_NAMES` 常量里，克隆里变空串；只在天启篇六维引用，发行不会走到。已补加载验证，见下。

## 优化登记草稿

无。
