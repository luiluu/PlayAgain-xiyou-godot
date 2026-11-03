# 交付：cc/bailong-tusu8

- 车道／工作者：白龙（cc），派单 tusu8：审查第 28 期 P3-1／P3-2／P3-3（tusu7 的 `skill_scene.gd`）
- 基线：cc/bailong-ui1 末端（1d4d330d）→ 含 tails1、ui1 两条未合分支的提交
- 状态：可合并

## 变更记录草稿

## 2026-11-03 【cc·白龙·未经审查】技能页：星谱先不可用、直接用后刷新、菜单技能公共事件走查专项（dev.待定）

- **P3-1 星谱（技能 10349，CE9015 `CodexXuan.openStarchart()`）**：重制没有星谱页（`rg -i starchart` 只在数据里），脚本不认。`XSkillScene.MENU_UNBUILT = [10349]`，`usable()` 对它返回 false（蜂鸣，同改动前），免得玩家点了关菜单却什么都不发生。**星谱页缺，待派**；做好后从 `MENU_UNBUILT` 去掉、`mv_script.gd` 认那句、`map_scene.gd` 打开。census 已知清单里那条仍归 E，没动（审查建议改 D，等星谱页时一起）。
- **P3-2**：`ok()` 的 list 分支不对我方的技能 `use_skill()` 后补 `_refresh()`（同 Scene_Skill.useItem 之后刷新状态窗与列表灰显）。
- **P3-3 专项 `xiyou_skill_menu_events`（新，10 项）**：取切片里场合 0／2 且带效果 44 的全部技能的公共事件（80 个以上），除含战斗处理 301（含 117 调用）的 6 个外，共 74 个逐个预约后交给地图 `run_reserved_common_event` 跑完，断言 `skipped_log` 为空。**结果：只有 CE9015（星谱）一条跳过**，其余 73 个没有被跳过的指令；9015 对应的技能已按 P3-1 不可用，专项里单独排除并有 `star.unusable` 断言。
  - 没跑的 6 个（开战斗，地图解释器要等战斗场景）：1554、1555、1556、1561、1597、1600。
  - 同专项里 P3-2 断言：用不对我方的随时技能后状态窗重画（反向验证：去掉 `_refresh()` 后 `refresh.redrawn` 挂，装回后过）。

优化登记草稿：无

## 待交叉核查

- `skill_scene.gd`：`MENU_UNBUILT` 白名单与 `usable()` 的一行判断。
- 专项用地图解释器直接跑公共事件，不经过技能页的 `use_skill`（技能页入口已由 `xiyou_tusu_ui` 的器谱例与本专项 P3-2 例覆盖）。

## 交接板

- 下一步：星谱页（璇，CE9015）待派；做完后去掉 `MENU_UNBUILT`、认脚本、census 改 D。
- 需要用户决定：无

## 可优化（流程／工具／效率）

- 无

## 验证

- 语法检查 0 个问题。
- 并行测试（--jobs 2，不跑全量）：xiyou_skill_menu_events 10、xiyou_skill_page 21、xiyou_skill_mastery 306、xiyou_tusu_ui 28、xiyou_battle_log 50、xiyou_window_rects 9、xiyou_event_compare 5，全过。
- 日志：`03_再刷重制_Godot/04_验证/本地结果/并行测试/20261103_054046_hcg6hzdb/`
- 没跑：选测名单其余场景与全量，留总装。

## 本分支提交

- 见 `git log cc/bailong-ui1..cc/bailong-tusu8`
