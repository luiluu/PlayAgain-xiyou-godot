# 交付：cc/quality-blend-fix

- 车道／工作者：B 界面·画质设置／cc（画质线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·画质·未经审查】修像素柔边带出的 anim_blend 取到空值（dev.待定）

- dev.532 的像素柔边让战斗图身体材质常在；`XBattlerSprite.anim_blend` 原先默认「有材质就设过 blend」，没设过时 `get_shader_parameter` 返回 null，`xiyou_mv_animation` 整轮挂在这里。改成取不到颜色就回透明色。
- 是我交付时漏跑了 `xiyou_mv_animation`（选测名单里有，我只挑了一部分跑）。`xiyou_crisp_scale` 补一条断言：材质在、blend 没设过时 `anim_blend` 是透明色。
- 地图人物的同名读取（`mv_character.gd`）不受影响：它的材质只在设 blend 时才建。
- 玩家可见：无（没设过闪光色时读取只在测试与技能动画收尾用到，不改画面）。

## 交接板

- 下一步：无。
- 用户试玩说明：无。
- 需要用户决定：无。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 无。

## 验证

- `语法检查.py` 通过；`xiyou_mv_animation`、`xiyou_crisp_scale`、`xiyou_battle_ui`、`xiyou_determinism` 全过。

## 本分支提交

- 见分支头：修 anim_blend 空值＋专项断言
