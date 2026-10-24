# 交付：claude/wukong-evfix

- 车道／工作者：A 内容·楼层／悟空（Claude，重制_悟空_50）
- 状态：可合并

## 变更记录草稿

## 2026-10-24 【Claude·悟空·未经Codex检验】事件对照 16 条已知不一致清到 6 条（dev.待定）

逐条查了基线里的 16 条 trace 不一致，修掉 10 条，余下 6 条都是原版有而重制版未做的系统，基线保留并在基线说明里写明原因。

- 修好 6 条 m4e41p0～p5：大厅投影（Map004 EV41）「强者名单／超强者名单」是 `if(window.CodexBossDifficulty){CodexBossDifficulty.showRoster(…)}else{…}` 整段脚本，解释器原来整段认不出而不显示。现在 `MVScript` 认这一整段写法，按插件算法出名单：强者 36 人＋导入角色哈基米＝37，超强者 46 人＋备注带 `<CodexSuperStrong>` 的 174／176／177＝49；停用角色（143／144／145／157／160）加「（停用）」，每行不超 24 字，之后接原版固定说明（超强者段含难度压制四行）。强者名单与原版逐字一致（事件对照）；超强者名单在 `xiyou_script` 里测了人数、停用标记与行宽（原版参照引擎手跑未成功，内容据插件源码）。**这是玩家可见的修复：此前大厅投影问名单无反应。**
- 修好 m4e22p0／p1（种族向导 `CodexRaces.openMenu()`）：游戏里早已接界面，只是对照用的替身宿主没有 `open_race_menu`，补上记录 `Scene_CodexBindMenu`。
- 修好 m61e9p0／m65e3p0（七层、十二层辛德瑞）：差异是 O-027 有意的落点修正（原版传水面 (12,18) 走不动，改 (14,23)）。对照测试里把参照的原版落点按 `MVInterpreter.TRANSFER_FIX` 同表换算后再比，今后 O-027／O-062 的落点改动不再被当成不一致。
- 余下 6 条（基线保留）：m4e8p0 仓库（PHWarehouse，`Scene_Warehouse`）、m4e17p0／p1 更衣（`Scene_ChangeClothes`）、m4e40p1／p3 装备镶嵌图鉴（`Scene_EquipInlayBook`）三个界面未接；m4e73p0 商店向导「战力短板」一段来自 CodexZones 五乘区预算，按数值平衡不移植（O-044／O-050）。
- 没做的线索：变更记录里的称号脚本 `ConfigManager.DesignationN[...]`、奇异石碑等与这 16 条无关；`$gameVariables.setValue` 写 900／899／1476 的脚本已经在 `MVScript` 里走 `XState.set_variable`，无需再改。
- 没有新增优化，O-088 未使用，请总装回收。
- 测试：`xiyou_event_compare` 全量 1795 例，一致 1789、登记 6、无退步；`xiyou_script` 21／21；`xiyou_item_marks` 108／108；`xiyou_interp_review` 13／13；`xiyou_transfer` 38／38。未跑 floor_run*（只加了一条脚本写法，不碰楼层路径）。
- 既有问题（与本批无关，main 上同样复现）：`xiyou_lobby_shops` 的 `case_e54p0_base_0-0` 失败，Godot 商店的 inventory 标签为空，参照为「人道碎片相关物品购买」。

## 交接板

- 下一步：事件对照基线只剩 6 条未做系统；`xiyou_lobby_shops` 的 e54p0 inventory 标签差异需要有人看（疑似近期商店改动留下）；仓库、更衣、装备镶嵌图鉴三个界面等用户决定是否做。
- 用户试玩说明：方桌大厅投影（破阵·投影）问「强者名单／超强者名单」现在会显示名单。
- 需要用户决定：仓库、更衣、装备镶嵌图鉴要不要做。

## 进度账

- 无变化。

## 本分支提交

- 见 git log
