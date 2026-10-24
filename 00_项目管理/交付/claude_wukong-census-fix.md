# 交付：claude/wukong-census-fix

- 车道／工作者：A 内容·楼层／悟空（Claude，重制_悟空_51）
- 状态：可合并

## 变更记录草稿

## 2026-10-24 【Claude·悟空·未经Codex检验】商店专项复查与盘点表述修正（答沙僧 P3-C3）（dev.待定）

- **`xiyou_lobby_shops` 的 `case_e54p0_base_0-0`**：在本车道工作树（main 15bc6b30，含 dev.158 金钱／商店改动与 dev.159 事件对照修复）复现，`xiyou_lobby_shops` 92/92 通过，参照 `generated/oracle/lobby_shops.json` 与旧 wukong-evfix 工作树逐字节相同（sha1 653cff85…）。没有代码问题要改。上一轮在 evfix 里的失败最可能是当时该工作树中 `xiyou_event_compare.gd` 的 EventHost 正在改动（本测试的 LobbyHost 继承它，事件对照修复期间 shop 钩子出入一度不一致），改定后已恢复；未能事后复现，如再现请带完整输出回报。未改测试。
- **P3-C3**：`census.py` 与 `盘点_未接地图_20261023.md` 的“原版里没有任何可达来源”改为“静态扫描没找到可达来源”，加“扫描范围”一节列出已覆盖与没覆盖的来源类型（变量指定 201、脚本其它传送写法、插件传送、事件页条件等；冻结源中变量指定 201 与脚本 reserveTransfer 均为 0 处）。补充扫描两类来源：公共事件的间接调用（物品／技能效果 44、切片敌群战斗页的 117、自动／并行触发的公共事件，按宽口径）与 MapTransferPlugin 传送菜单（从 `plugins.js` 的 Map Settings 读 canTransfer 条目，余下地图中 0 张在菜单里）。数字变化：静态可能可达由 10 张升到 46 张（旧口径只算直接 201），仍未找到来源 54 张（旧 100）。这是口径变宽而不是新接图；不排除内容、不扣总工作量。只改文档与脚本，没接新地图。
- 优化登记 O-088 本轮未用。

## 交接板

- 下一步：无新增；若要看 54 张“未找到来源”的真实可达性，需逐个查 MapTransferPlugin 解锁条件与脚本传送。
- 用户试玩说明：无玩家可见变化。
- 需要用户决定：无。

## 进度账

- 无变化。

## 本分支提交

- 见 `git log main..HEAD`（含删除已并入的 evfix 交付单）；专项 xiyou_lobby_shops 92、xiyou_shop_buy 5714、xiyou_event_compare 5、xiyou_census1 47 全过

本车道临时输出已清理（无本地输出文件）。
