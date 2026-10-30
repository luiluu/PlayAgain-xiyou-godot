# 交付：claude/wukong-airship3

- 状态：WIP（勿合并；用户 10-30 收工，停在验证前）
- 车道／工作者：A 内容·地图／悟空_70（Claude）
- 本期：天之上飞艇方案甲三（图像与表现）
- 基线：从甲二交付末 e2918504 切出，已合 main（528dba63，含甲二合并与八戒蚀术）。

## 现状

**已做（代码已提交）**
- `mv_character.gd`：新字段 `altitude`（Game_Vehicle._altitude），`_sync_position` 的 y 减去它（screenY）；优先级 2（角色上方）的 z_index 从 1 改成 `ABOVE_UPPER_Z` 11，压在上层图块（10）之上，照原版 screenZ 5 > 上层图块 z 4。**这一条对所有优先级 2 的事件都生效**（原来画在星号图块下面，和原版不同）。
- `map_scene.gd`：飞艇影子（Spriteset_Map.createShadow／updateShadow，`system/Shadow1`，锚点底边中点，挂在飞艇精灵下，位置减回高度、含行走图上移 6／物件 0，透明度＝高度÷48，z 12 在飞艇之上）；飞艇精灵速度 6（Game_Vehicle.initMoveSpeed）——修了甲二留下的问题：飞艇精灵每帧先抄玩家上一帧位置、再按自己的速度 4 走一帧，飞行中和玩家对不齐。
- `mv_player.gd`：拆出 `click_cell`（鼠标点格）；飞行中点前方一格是飞过去，不再降落（原版 triggerTouchActionD2 只对小船大船上下、事件被 canStartLocalEvents 拦住）；点脚下仍是降落（D1）；飞行中飞不过去（只有图边）也不当调查。触屏（InputEventScreenTouch）原来就只设目的地、不判 D1／D2，没动。寻路仍是重制原有的直线靠近（原版 findDirectionTo 是 A*，飞行中全图可过，结果一样）。
- `mv_event_core.gd`：323 注释更新（换图已显示）。
- 切片 `extraImages` 加改造包 7 张行走图（Vehicle2、SF_Vehicle、SF_Vehicle2、Nature2_mvt、tg-cm03-chr-01、$Ravendel's Wyvern、!$occ01jp_mv03_georgette_tv；后两张原来就因别的事件导出了，显式列上）。
- 新专项 `tests/xiyou_airship_view`（.gd、.tscn、.gd.uid 都已提交）：停泊默认图；上艇逐帧采样高度 0→48 每帧 +1、精灵与影子位置、透明度、层级；飞行中点前方飞过去；空中存读档；323 换直升机后存读档；点脚下降落逐帧 48→0；降落中、升空中存读档读回高度一致并接着降／升；萌物（! 物件图）影子不上移。带 `--out=<目录>` 时（非无头）在升空 24、飞到 (65,52)、降落 24 截图。
- 同步：`同步正式西游.py --accept-additions --accept-changes 04_验证/测量接受/claude_bajie-alien-erode.json` 通过（退出码 0，留了产物指纹）。输入只多 5 张飞艇图；接受的 alien_affix 27→28 是 main 上八戒蚀术那步，不是本车道改的。
- 原版截图（`ui_reference/serve.py` ＋内置浏览器，静音，`?map_ref=1` 后自己建内存新局到 69 (65,56)、停解释器）：`04_验证/本地结果/原版参照/airship3/` 下 mv_parked、mv_first_rise_24、mv_flying_65_52、mv_land_24（已换 SF_Vehicle 3）、mv_landed（不入 Git）。原版读数：高度 24 时 screenY 354、shadowY 378、透明度 127.5、screenZ 5；飞到 (65,52) 时 screenY 330、shadowY 378。截图底部压着一条进图提示消息窗（清了 $gameMessage 但窗口没关），不影响飞艇那块。

**没验证**
- `xiyou_airship_view` 同步后**还没跑**（同步前跑过一次 55/57，只差 SF_Vehicle 图未导出的两项）。
- Godot 侧三张截图没截，没和原版并排比。
- `xiyou_airship_fly`、`xiyou_airship_state` 及选测（地图／事件、触控 `xiyou_options_basic`、存档类、`xiyou_map*`、`xiyou_event_compare` 等必跑项）都没跑。优先级 2 层级改动要靠地图类专项回归。
- `内容覆盖检查.py` 没跑（只加了 extraImages，预计 new 0）。

**下一步**
1. 跑 `并行测试.py <godot> 01_Godot工程 xiyou_airship_view xiyou_airship_fly xiyou_airship_state` ＋地图／触控／存档选测与必跑项。
2. 非无头跑 `xiyou_airship_view -- --out=<目录>` 截三张，与 `原版参照/airship3/` 并排看（镜头位置两边算法可能不同，只比飞艇、影子相对格子）。
3. 补「变更记录草稿」「验证」，状态改「可合并」。

## 变更记录草稿

（收尾时补）

## 待交叉核查

- 优先级 2 的 z_index 改动影响所有「角色上方」事件，请核是否有事件因此盖住了本该在上面的东西。
- 飞艇速度 6 对飞艇精灵自身行走动画速度也有影响（照原版）。

## 可优化（流程／工具／效率）

- 发现（约 1 行，归 B 车道或写 ui_reference 的人）：原版网页里有插件用了全局变量 `i`，页面内 JS 用 `var i` 写循环会被改掉（我的 4 步循环变成飞了 56 格）。`ui_reference/README.md` 可加一句「页面内 JS 循环用 let」。
- 原版画面夹具可以做成 `?airship_ref=1`，省得每次手敲；本期先不做。

## 本分支提交

- WIP：高度偏移、影子、层级、触控、切片加图
- WIP：影子挂飞艇精灵、飞艇速度 6、click_cell、新专项
- 合 main 528dba63
- （本提交）WIP：专项加 --out 截图、交付单现状
