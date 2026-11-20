# 交付：luiluu/cc-t291-handoff-drops

- 车道／工作者：T291 战斗结算衔接两处遗留＋卡 U 核查 P3-1～4（cc，Sonnet＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T291·未经审查】战斗结算衔接遗留：掉落当帧快照、结算页清场；卡 U 核查 P3-1～4（dev.待定）

- **发现①掉落飞不起来**：掉落图标落地约 1 秒就淡出（alpha 0，节点还在），等待期满再扫就全被筛掉。改成 `_victory()` 当帧 `Handoff.snapshot_drops(field)` 把场上所有史诗以上掉落（含已淡出的）拍进快照，位置记成 field 坐标，建结算页时按 field 当时的位置（镜头已推近）换算。开关 `XSkin2C.HANDOFF_DROP_SNAP`（关＝回到建结算页才扫、淡出的飞不了）。
- **发现②结算页被压**：`_victory()` 在 0.5 秒隐藏 `ui` 那一刻顺手隐藏敌人名字／血条／状态图标画布（`gauges` 的 box），并让首领状态胶囊 `boss_panel` 隐藏且停 `process_mode`（它每帧把自己显示回来）。新旧皮肤都生效。开关 `XSkin2C.RESULT_CLEAR`（关＝照旧留着）。
- P3-1 补测自动战斗 `v.automatic` 路径（不飞、0.12 秒淡出）；P3-2 全灭 `_defeat()` 开头印盘按稿 0.12 秒淡出（动效关直接隐藏），开关 `XSkin2C.DEFEAT_FADE`；P3-3 `damage_record._ui_path()` 设置路径为空串时返回空串、读取跳过；P3-4 `skin_boss_arc._draw()` 开头清 `last_name_rect`。
- 玩家可见：真实战斗里首领战的好掉落也会飞进结算大圆章；结算页上不再压着敌人名字、血条、首领状态胶囊；全灭时印盘淡出。

## 交接板

- 下一步：无
- 用户试玩说明：同「玩家可见」
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：`xiyou_ui_skin_2c` 的 `u_same_total_t_close` 用墙钟 0.05 秒容差，并行满载时偶发失败（本轮并行时挂一次，单跑重跑通过）；可放宽到 0.12 或改按帧数，归测试工具车道。`xiyou_battle_ui` 的 `action_log_shown` 同次并行里也失败过一次，单跑 182/182，同属负载偶发。

## 本分支提交

- 见 git log（WIP 与交付两个提交）

## 验证

- 专项 `xiyou_ui_skin_2c` 181/181（单跑）；窗口模式 `--only=u` 274/274（含 `u_shot_size_*`：16:9 为 800×450、20:9 为 1000×450，新增「首领战掉落已淡出」每 0.1 秒一张）；`xiyou_battle_ui` 182/182（单跑）、`xiyou_determinism` 372/372、`xiyou_drop_record` 26/26、`xiyou_boss_hp_bar` 100/100、`xiyou_enemy_state_icon` 19/19、`xiyou_victory_text_flow` 4/4、`xiyou_config_transfer` 67/67；语法检查 0 问题。
- 偶发：并行时 `xiyou_ui_skin_2c`（`u_same_total_t_close`）、`xiyou_battle_ui`（`action_log_shown`）各挂一次，单跑均通过。
- 待交叉核查：`battle/battle_scene.gd`（`_victory`、`_defeat`、新增两个小函数）。
