# 交付：claude/wukong-floor15

- 车道／工作者：A 内容·楼层／悟空（Claude，重制_悟空_4，接 重制_悟空_3）
- 状态：进行中（地图循环已完成；下一步十五层 Map032）

## 变更记录草稿

### 2026-10-15 【Claude·悟空·未经Codex检验】地图循环（scrollType）：十四层守层者原版走得到（dev.待定）

- **更正 dev.047 的「守层者走不到」**：十四层 Map030 是横向循环地图（scrollType 2，正式版 231 张图里只有它一张），MV 的 `Game_Map.roundXWithDirection` 让玩家从 x=0 往左一步到 x=59。dev.047 用的是不带循环的 `isMapPassable` BFS，才得出 616／276 两块不连通。正式引擎改用 `$gamePlayer.canPass`＋`roundX/YWithDirection` 复测：从入口 (18,30) 能到 888 格，含守层者 (44,23) 的下、左、右三格；`locate(0,16)` 后 `moveStraight(4)` 到 (59,16)。原版没坏，是 Godot 缺「地图循环」，所以**不做 O-034 优化**（预分配的 O-034 未用），改为照原版实现循环。
- 实现（照 MV）：`MVTilemap` 按 scrollType 设 `loop_x/loop_y`，`round_cell`（roundX/Y）、`is_valid`、`delta`（deltaX/Y，取较短一边）、`tile()` 环绕；绘制在循环方向两侧多画一屏（28／16 格，Tilemap horizontalWrap）。`MVCharacter.can_pass` 先绕回再判，`step_by` 走一格（格子绕回、real 平移一整张图，同 moveStraight 的 `_realX = xWithDirection(_x, 反方向)`）；跟随者 chase 用 `delta`（deltaXFrom）；玩家点按格、前方格（调查／接触事件）绕回，点按寻路 `_toward` 用 `delta`；循环地图上每帧把各角色画在离玩家最近的那一份（adjustX）；镜头在循环方向不限边。挂机回原点照 moveTowardPosition 的 deltaXFrom（`XHangUp.next_dirs` 加可选 `back_to`），范围仍照 distanceX 直接相减。
- 参照：`map_probe.cjs` 对循环地图另记 `loop`［横, 纵］与越过边缘那一步（`wrapLeft`／`wrapUp`，每行／列一位）；`xiyou_map` 比这两项（37/37）。`xiyou_floor_run` 去掉 `UNREACHABLE_BOSS`，寻路认循环；十四层完整模式真正走到守层者，并检查路上越过了边缘（`WRAP_BOSS`）。
- 验证：`xiyou_map` 37/37；`xiyou_floor_run_d`（13～14 层）167/167；`xiyou_hangup`／`_auto`／`_options`、`xiyou_hud`、`xiyou_transfer` 全过；临时场景截图看 x=2 与 x=57 处两侧绕回的图块与守层者显示正常（截图未入库）。
- 未完成／已知问题：跳跃（MV jump 也不绕回）与事件「接近玩家」类移动路线（Godot 尚未支持）在循环地图上未专门处理。

## 交接板

- 下一步：（进行中）
- 用户试玩说明：（进行中）
- 需要用户决定：无（dev.047 记的「十四层守层者走不到」是误判，O-034 未用，可从预分配里收回）

## 进度账

- （进行中）

## 本分支提交

- （进行中）
