# 全库游戏文字审查——批 19（`battle/*.gd`、`map/*.gd`、`rift_alien.json`、`alienation.json`）

> 所属总单：[xa_text-audit.md](xa_text-audit.md)
> 范围：`modes/xiyou/battle/*.gd`（非天启篇 33 个文件，12 个含中文，约 133 段）、`modes/xiyou/map/*.gd`（非天启篇 19 个文件，8 个含中文，约 89 段）、`modes/xiyou/rift_alien.json`（11 段）与 `modes/xiyou/alienation.json`（73 段），合计约 306 段。

| 序号 | 位置 | 原文 | 问题 | 建议改成 | 级别 | 版本 |
| --- | --- | --- | --- | --- | --- | --- |
| 19-001 | `modes/xiyou/map/map_scene.gd:1293` | `"\\c[2]（首期尚未开放这张地图：Map%03d）" % id` | 向玩家直出内部开发分期词「首期」与原始地图 ID `Map%03d`，破坏沉浸感（同 1-011、2-005） | `"\\c[2]（该区域暂未开放）"`（或展示地图显示名 `"\\c[2]（%s 暂未开放）"`） | 必改 | 两边都有 |
| 19-002 | `modes/xiyou/map/mv_script.gd:578` | `"【区域已移除】%s因地图文件损坏，已从当前版本移除。" % REMOVED_MAPS[...]` | 向玩家直出「因地图文件损坏」技术故障字眼，虽沿用原版 `CodexMapRemoval.notice`，易误导玩家以为本地安装包损坏 | `"（%s 区域暂未开放。）" % REMOVED_MAPS[...]`（若需严格保留原版公告可维持） | 建议 | 两边都有 |
| 19-003 | `modes/xiyou/map/hang_up_overlay.gd:144, 178` | `"挂机时间:"` / `"每 %d 次战斗后卖出的装备品质:"` | 地图挂机浮层标签使用英文半角冒号 `:`，与全库全角冒号 `：` 不统一；且 L144/L178 字号 `14` 略小 | `"挂机时间："` / `"每 %d 次战斗后卖出的装备品质："` | 建议 | 两边都有 |
| 19-004 | `modes/xiyou/map/map_hud.gd:100` | `"坐标<%d,%d> "` | 地图 HUD 坐标标签使用尖括号 `<>`，带程序调试感 | `"坐标（%d, %d） "`（或 `"坐标 %d, %d "`） | 建议 | 天启篇 |
| 19-005 | `modes/xiyou/battle/boss_status_panel.gd:336, 479, 481` | `"收起 ▴"` / `"详情 ▾"` / `"‹ 上一页"` / `"下一页 ›"`（字号 `13`） | 战斗中 Boss 状态面板交互按钮字号仅 `13`，1280×720 与手机端偏小难辨认（同 1-013、13-009、15-003） | 建议调大至 `15`～`16` | 建议 | 两边都有 |
| 19-006 | `modes/xiyou/battle/battle_scene.gd:635, 639` | `"变速 " + XConfig.battle_speed_text()` | 配合 18-006，未加速时战斗按钮显示 `"变速 OFF"` 中英混排；若 18-006 改用 `"关闭"` 可同步消解 | 随 18-006 联动；若维持原版选项则可不改 | 可不改 | 两边都有 |

> 批 19 复核：本批已逐一核对 `battle/*.gd`（含 `battle_event_runner.gd`、`battle_logic.gd`、`battle_scene.gd`、`boss_hp_bar.gd`、`boss_status_panel.gd`、`damage_popup.gd`、`damage_record.gd`、`otb_bar.gd`、`side_status.gd`、`smart_ai.gd` 等）、`map/*.gd`（含 `fest_lobby.gd`、`hang_up_overlay.gd`、`lobby_corruption.gd`、`map_hud.gd`、`map_scene.gd`、`mv_interpreter.gd`、`mv_script.gd` 等）以及 `rift_alien.json`、`alienation.json`。其中大厅异变（`lobby_corruption.gd`）、漩涡五阶段异化（`rift_alien.json`）、异化词条配置（`alienation.json`）及战斗数值单位均表达准确、风格统一。
