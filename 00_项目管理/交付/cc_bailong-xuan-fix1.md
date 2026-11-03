# 交付：cc/bailong-xuan-fix1

- 车道／工作者：E 角色专属／白龙（cc，xuan-fix1）
- 状态：可合并

## 变更记录草稿

## 2026-11-03 【cc·白龙·未经审查】修审查 32：满级星纹操作页、读档后命主名册、选原件说明卡字号（dev.待定）

- **P1-1 满级星纹打不开操作页**（`core/xuan_chart.gd`）：`mark_rows` 在 3 级时读 `COST[3]` 越界，页面一行都不出。强化行的文字抽到 `learn_label`：满级时写「强化（已满级）」，三行照出，强化不可选，配入、回收照常（同原版 installNativeXuanRuntime.js:548～551）。原版此处文字是「强化（星砂undefined）」，登记 O-待定，回退 `XXuanChart.MAX_LABEL_FIX = false` 就照原版文字。
- **P2-1 读档后名册移不出人**（`core/xuan_chart.gd` `toggle_roster`）：存档走 JSON，读回后名册是 `[8.0]`，`find(8)` 找不到，点已在名册的人变成再加一遍。现在先把名册归成整数再找；名册里存的也就一直是整数，璇的战斗机制以后读名单不会读到重复的人。
- **P3-1 选原件说明卡字号**（`ui/crafting.gd` `_sync_source`）：查实原版压 14 号被冲掉——原件都是成长装备，`Sprite_ItemHelp.setItem` 包装走 `helpView`（installNativeHubrisRuntime.js:175），`RJO.HE.getDescParams` 把 `descParams` 清空重建（HelpExtend.js:150），所以原版按原字号显示。照原版去掉 `cap_size(14)`，不登记优化。
- 测试：`xiyou_xuan_chart` 加 `roster.after_load_remove`、`roster.after_load_mixed`（两次存读档往返后再点）、`max.rows`、`max.rows_original_label`（回退支）、`max.refund`；`xiyou_growth_forge` 的 `ui.source_card` 改成断言有大于 14 号的行。
- 没改探针：审查建议探针加一例学满再打开的流程；原版那一行文字是 undefined、重制默认改了文字，加了也只能在测试里特判，规则层断言已覆盖三行的可选状态与回收，就没动探针，省一轮同步。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 星谱满级星纹操作页的强化行（`core/xuan_chart.gd` `learn_label`；installNativeXuanRuntime.js:550） | 星纹 3 级时读 `cost[3]` 得 undefined，强化行写「强化（星砂undefined）」（本就不可选，配入、回收照常） | 写「强化（已满级）」 | 原版是越界的副作用，文字不像话 | `XXuanChart.MAX_LABEL_FIX = false` | cc（白龙） | 待用户确认 |

## 待交叉核查

- 改了 `core/xuan_chart.gd`、`ui/crafting.gd`（都不是原沙僧核心文件）。请核 P3-1 的结论（原版 14 号确实被冲掉）是否成立。

## 交接板

- 下一步：删掉「审查 32 P1、P2 待修」（如交接板有）；O-149／150 列数（审查 32 P3-3）、探针正则（P3-2）不在本车道，归哪吒 tools52。
- 用户试玩说明：星纹学满后再点它能看到三行（强化写「已满级」），能回收强化星砂；读档后命主名册点人能正常移出；锻造选原件时按 Shift 的说明卡字号和平常说明卡一样大。
- 需要用户决定：O-待定（满级强化行写「已满级」还是照原版「星砂undefined」），默认写「已满级」。

## 进度账

- 无变化（修缺陷）。

## 可优化（流程／工具／效率）

- 无新增（审查 32 已提的「flags 里取出的数组 find／has 用 int 找不到」扫描建议，仍归工具车道）。

## 验证

- `语法检查.py` 通过。
- 选测（`选测.py main --list` 列出的 7 个全跑，全过）：`xiyou_xuan_chart` 133／133（原 128＋新 5）、`xiyou_growth_forge` 538／538、`xiyou_xuan_battle` 246／246、`xiyou_crafting` 49／49、`xiyou_gold_cap` 37／37、`xiyou_system_evidence` 15／15、`xiyou_event_compare` 5／5。没跑反向验证：P2 两条断言在旧代码下名册会是 `[8.0, 8]`／`[9.0, 10, 9]`，P1 旧代码 `mark_rows` 直接越界返回空，读码可确认咬得住。

## 本分支提交

- 9a97f0f9 修 P1-1、P2-1、P3-1，加测试，登记 O-待定
- 本提交：交付单填验证、标可合并
