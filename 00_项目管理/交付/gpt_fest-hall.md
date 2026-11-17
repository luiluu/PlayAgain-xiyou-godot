# 交付：gpt/fest-hall

- 车道／工作者：小o（co），gpt-6.1-sol＋medium，T071
- 状态：进行中

## 变更记录草稿

## 2026-11-17 【co·未经审查】T071 大厅庆典布置调整（dev.待定）

- 奖杯脚底对齐原金甲 NPC (14,10)，报名处 (12,10)、使者 (16,10) 分列两侧；仍保留异化圈外断言。
- 横幅上移北墙；庆典期间移除中央红桌与烛台，结束或关闭后恢复原图。
- 按 Kyo 后续决定：金甲 NPC 放 (17,5) 两位女孩正中；派蒙移到北墙 (11,5)，保留全部事件页与对话。派蒙只在宝宝难度（2496）或宝宝巴士（2481）开启时出现。
- 玩家可见：大厅奖杯居中、横幅上墙、红桌撤除；金甲 NPC 与派蒙换位。（发行文字请小A审）

## 验收与验证

- `active.cells`、`active.trophy_center_on_original_npc`：奖杯原位、两侧庆典 NPC。
- `active.banner_north_wall`：横幅在北墙。
- `active.only_table_tiles_changed`、`layout.*.table_removed.*`：仅删除桌与烛台；`grace.original_npc_and_tiles` 验证恢复。
- `active.gold_npc_moved`、`active.paimon_moved`、`layout.baby.paimon_visible`：新位置和宝宝难度显隐。
- `active.route.*`、原有对话专项与 `active.outside_corruption_circle.*`：通行、对话、圈外限制保留。
- 专项最新本机结果 155/155；语法检查 988 个脚本 0 问题；工具回归 22 项通过。
- 初次新增路线断言误向原有讨债人小弟方向行走，失败后已改为桌下横向连续绕行路线，未放宽通行规则。
- 实机截图与原始日志：私密设计仓 `协作交接/附图/T071/交付/`（游戏 content 内无交付图片）。
- 首轮 `检查.sh --affected main --cloud` 自动扩为 658 场景（上次通过祖先较旧），已被最终提交的新云端批次替代。最终提交 512a21baa（派蒙贴北墙）按明确基准 bf2caff449 选测 69 场景，正在运行；非 Godot 检查已完成。云端结果未通过前不可合并。

## 交接板

- 下一步：跨模型核查后合入 main；同批 v0.03.01 补丁线由总装摘取本车道提交。
- 不改补丁线；仅代码与测试提交需要摘取，交付单由总装归档处理。

## 可优化（流程／工具／效率）

- 建议（总装／工具车道）：`检查.sh --affected main --cloud` 本机选中 69 场景，但 cloud run 未传 --base，默认另取旧祖先，扩为 658；本单另显式指定基准纠正。建议未来统一本机与云端基准，避免重复扩测。

- 已做：专项增加 `--capture-only --out=<私密目录>` 实机取景入口，避免跑完全部对话才能取得三种默认设置截图；可删除该入口回退。

## 本分支提交

- d21fc4c02 布置补丁与验收测试。
- 9fd7b2d1a 修正桌下连续绕行路线验证。
- b075d03e8 修复北墙画像遮挡横幅，补默认设置取景、派蒙标注图与二阶段全景。
- 512a21baa 按 Kyo 最新决定把派蒙移至北墙 (11,5)，重截宝宝难度标注图，静音运行。

## 截图清单

- `fest_lobby_default_xiyou.png`、`fest_lobby_default_tianqi.png`：同视角 (14,8)，各档默认皮肤，漩涡二阶段启用。
- `fest_lobby_annotated_baby.png`：宝宝难度开启，紫框标出派蒙 (11,5)，文字说明显示条件。
- `fest_lobby_rift2_on.png`：下移视角，展示奖杯与二阶段漩涡同图共存。
- 调用：`godot --audio-driver Dummy --path <工程> res://tests/xiyou_fest_lobby.tscn -- --capture-only --out=<私密交付目录>`；后续截图一律静音。
- 取景入口用 `RenderingServer.force_draw()`，避免 macOS 遮挡窗口时 `frame_post_draw` 不唤醒；取景前隐藏初始成就提示，防止遮住布置。

## 云端阻塞（待协调授权）

- 最终批次 43985970712 的第 3 片中 `xiyou_map` 424/425，首次与重跑一致失败。
- 唯一差异：`MISMATCH map4.passable [[13,11,15,0],[14,11,15,0],[15,11,15,0]]`，即撤除红桌后新增可通行三格。
- 原版地图对照在 `_ready()` 已关闭漩涡二阶段等重制优化，却没有关闭庆典；当前真实日期在庆典内，故把本单有意变更与只读原版 oracle 比较。
- 建议在 `tests/xiyou_map.gd` 原版对照初始化中加 `XFestLobby.ENABLED = false`（不动 oracle、不放宽断言），大厅庆典行为由本单专项 155 项覆盖。该文件超出独占范围，已准备向协调询问；授权前不修改。
