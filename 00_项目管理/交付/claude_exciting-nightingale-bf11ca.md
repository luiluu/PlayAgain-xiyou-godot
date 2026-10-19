# 交付：claude/exciting-nightingale-bf11ca

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_23）
- 状态：可合并

## 变更记录草稿

## 2026-10-19 【Claude·八戒·未经Codex检验】装备检索关闭存排序核对与主菜单空队灰显（dev.待定）

- 装备检索：对照冻结 v0.28 `installEquipmentStatusRuntime.js`，原版 `close()` 不存排序；排序只在下拉改变（`setSort`）和「应用到装备列表」（`applyFilter`）时保存，打开面板时排序回到配置值。Godot `gear_search.gd` 本来就是这样（`_on_sort`、`apply_filter` 存，`close` 不存），云端审查的「关闭也存排序」不成立，代码不改。`xiyou_gear_search` 补回归 `close_keeps_saved_sort`（面板内只改条件、临时排序不入配置，Esc 关闭后配置排序不变），58/58。
- 主菜单灰显：按冻结版主菜单运行时与空队运行时核对。有队员时 18 项全部可用（Godot 里种族祝福、宠物、制作、异化工坊、图鉴、成就、反馈尚未接入系统，仍灰显，属未做项，不动）；空队时物品／技能／装备／状态／真气／整队 6 项灰显，其余不变。Godot 原来只按「已重制」灰显，空队时这 6 项仍可点（点技能／装备／状态会因 clampi 到 -1 出错）。`ui/menu.gd` 新增 `NEEDS_MEMBERS` 与 `command_enabled(i)`，绘制与确定都走它。`xiyou_panels` 补 3 项（有队员可用性、空队灰显清单、灰显项点确定不打开页面），33/33。

## 交接板

- 下一步：随接入种族祝福、宠物、制作等系统逐项把 `menu.gd COMMANDS` 第三列改 true（空队规则已就位）。
- 用户试玩说明：队伍被事件清空时，主菜单物品／技能／装备／状态／真气／整队变灰且点不开；其余无变化。
- 需要用户决定：无。

## 进度账

- 无完成度变化（核对为主）。

## 本分支提交

- 见 git log
