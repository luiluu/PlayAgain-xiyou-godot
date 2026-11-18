# 交付：luiluu/t189

- 车道／工作者：T189 T188 收尾：停在 wait 帧的角色按 wait 第 0 帧量身高（cc，Sonnet＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-18 【cc·天启篇·未经审查】T189 停在 wait 第 0 帧的角色（谷雨、哈基米等）按 wait 第 0 帧量待机身高（dev.待定）

- 起因：T188 小A 核 P2-1。`_guyu_planted()` 角色（谷雨、小猫剑圣＝哈基米、`XXuanTusuArt.planted` 的屠苏／璇）实际停在 wait 第 0 帧，T188 却只量 walk 帧最高可见高（哈基米 walk 68／wait0 72，实站约 105；谷雨 walk 62／wait0 60，实站 96）。
- 改法：`battle_layout.gd` `idle_height(look, planted := false)`，planted 时只量 wait 第 0 帧；`battler_sprite.gd` 新增 `_idle_planted()`（`_guyu_planted` 的判据去掉 `_moving`），`_measure_idle` 据此量高、`_idle_asset` 同取 wait 帧，`_guyu_planted()` 改为 `not _moving and _idle_planted()`。
- 随之重算：屠苏（176）、璇（177）同属 planted，倍数也按 wait0 重算（src_h 73，倍数约 1.356，屏高 99）；谷雨 src_h 60、倍数 1.65，哈基米（178）src_h 72、倍数 1.375，均屏高 99。其他非 planted 角色不变。
- 专项 `tests/xiyou_battle_actor_size`：`_screen_h`、全员行 src_h 同口径读 `_idle_planted()`，全员 98～102 断言保持。
- 回退：`XBattleLayout.TARGET_H＝0` 照旧回 T174。
- 玩家可见：战斗里谷雨、哈基米、屠苏、璇的身高与其他人一致（约 99 像素）。

## 交接板

- 下一步：无
- 用户试玩说明：同变更记录草稿「玩家可见」
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 测试

- `xiyou_battle_actor_size`：无头 160/160，带窗口 173/173。
- 附图：`luiluu_t189附图/谷雨_A组_首领战.png`、`哈基米_B组_首领战.png`（1280×720 整场图，归档由总装挪）。

## 本分支提交

- 9f01e710f T189 改法与专项
