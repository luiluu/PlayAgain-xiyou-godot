# 交付：cc/nezha-fix4

- 车道／工作者：哪吒；从 main `1072662b`（含 events2）切出，已合 main
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·哪吒·未经审查】修审查 41（P2×1、P3×5）

- P2-1：`xiyou_event_compare` 在 `event_states.json` 缺失时 `check("states_present")` 失败（不再静默跳过变体）；新增 `07_开发环境/补跑事件状态探针.py`（缺失或比预设／探针旧时补量，约 10 秒，探针写 .sandbox 再拷进 generated/oracle；没有参照依赖就跳过不报错），`检查.sh` 在 Godot 测试前、`新建工作树.sh --补齐` 收尾各调一次。
- P3-1（visual2 反向验证）：`xiyou_collapse_fx` 补 sx／op 取值范围（统计 480 块的 min/max）、边长除数（40×40、41×40，/40 与 /41 取整不同）、锚点三处；用 `反向验证.py` 改坏 4 处（/41、sx 范围、锚点 (0,0)、锚点按整块）全部咬住。
- P3-2 量过再改：①网格宽高含缩放——**不成立**：`rpg_core.js:4016` MV 的 `Sprite.width/height` 读 `_frame`（位图尺寸），不含 scale，呼吸不影响网格，探针写死位图尺寸等价，不改。②边缘块锚点——成立：`Sprite._refresh`（4177～4194）把越界裁掉、`texture.frame=_realFrame`，PIXI 锚点按裁剪后的框算；`collapse_fx.gd` 偏移改成 `(-rw/2, -rh)`（裁剪后尺寸），用 333×211 的边缘块测。仍是源码级推断，无实机对照。
- P3-4：`XSvPngFd.scale` 的技能改读 `a.skills()`（与原版 `this.skills()` 一致）；`xiyou_svpngfd` 加技能备注读取用例。
- P3-5：`事件空绿扫描.py` 的 `covered` 不再排除仍空绿的变体（`m84e11p0`、`ce1194` 回到空绿清单），基线更新为 1800 例（含这 2 个）。
- P3-6：`xiyou_event_compare` 不再整段关 `seal_check_fix`，只对修正表里那几扇门的用例关，其余用例走修正生效的路径；5839 例对照仍通过。
- P3-7：量过——`roll_encounter` 只让规则流抽数 +2（奖励流不动），回放按 `encounter` 标志在同位置重掷，确定性不受影响，不用隔离；`xiyou_random_streams` 加两项断言（抽数 +2、遇敌战斗录制回放可用）。

## 交接板

- 清掉审查 41 报告 P2-1、P3-1／2／4／5／6／7 的待办。
- 需要用户决定：无。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 边缘碎块锚点、SV 敌人碎块超出单格的取图（原版用整张位图，重制 `g.x >= w` 丢弃）仍缺实机对照，建议有画面环境时对一次。

## 待交叉核查（改了核心文件）

- 未碰 `damage.gd`、`battle_logic.gd`、`actor.gd` 等核心文件；改了 `sv_png_fd.gd`、`collapse_fx.gd`（画面）。

## 验证

- 专项＋必跑项 36 个场景全通过：选测名单 28 个（collapse_fx、svpngfd、event_compare、random_streams、autosave、common_scripts、dungeon、honghuang_*、lobby_shops、rules 抽样 16 段、script_census、status_power_panel）＋ determinism、preempt、scan2；`测试事件探针分段.py` 通过；语法检查 552 个 .gd 0 问题；`事件空绿扫描.py --check` 通过。
- 没跑全量 `检查.sh`（车道不跑）；没改切片／转换器／探针，不需要重跑同步。
