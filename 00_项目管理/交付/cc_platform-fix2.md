# 交付：cc/platform-fix2

- 车道／工作者：平台（cc，项目线程「完成再刷西游Godot引擎重制」；EH 单，来源 Codex 审查报告）
- 状态：可合并
- 基于：main d1ef2932（dev.384 收尾）

## 变更记录草稿

## 2026-11-07 【cc·平台·未经审查】补跑结束恢复正常速度；手机进主菜单、开战前存自动存档检查点（dev.待定）

- 玩家可见：手机切回前台补跑完后游戏回到正常速度；开菜单、打仗时被系统杀掉，也能从标题页「继续」回到进菜单／开战前
- 报告第 6 项 → 复现测试 `xiyou_platform` 的 catch_up_natural_end_restores、catch_up_twice_natural_end_restores、catch_up_repeat_stop_restores、catch_up_stop_twice_harmless（旧代码 4 项挂：time_scale 停在 8、物理帧率 480）→ 修法：`core/platform.gd` 加独立活动标记 `_catch_up_active`，`is_catching_up()` 看它、不看剩余秒数；补跑中再补跑只续时、不重存原始设置，所以不会把八倍速存成「原始设置」。补跑倍率改成相对开始时的引擎设置（基准×8，基准就是入口设好的值），停下回到那份基准，不写死 1 倍：XSpeedGear（cc/ui-battlefix2，未合）把基准设成 96 帧／1.6 倍时，补跑是 768 帧／12.8 倍，停下回到 96／1.6（测试 catch_up_relative_to_base、catch_up_restores_base_gear 用 96／1.6 模拟）。没加 base_time_scale() 占位接口：开始补跑时存下的当前设置就是基准，跟 battlefix2 谁先合都对。这是重制自己的缺陷，修好不挂开关。
- 报告第 5 项（O-215）→ 复现测试 `xiyou_pause_save` 的 checkpoint_*（10 项）、battle_checkpoint_before_battle_state、menu_checkpoint_saves（旧代码直接解析失败）→ 修法：`XAutoSave.checkpoint(map, what)`，`open_menu` 在置 `_menu_open` 前、`start_battle` 第一行（置 `_in_battle`、第一个 await 之前）各调一次，存到同一个自动存档 `XSave.save_auto`；沿用 `blocker()`：只在手机、地图上、事件没在跑时存，所以不存战斗中间态，事件里开的战斗不存（事件只跑一半，读回来会从头重跑）；不占切后台的去重窗口。开关 `XAutoSave.CHECKPOINTS`（O-待定·自动存档检查点，默认开，false＝只在切后台时存）。标题页按钮的说明从「自动存档（切后台时）」改成「自动存档」。
- 验证：见下。

## 交接板

- 下一步：无
- 用户试玩说明：手机上开菜单或进战斗时直接杀掉游戏，再开标题页有「继续」，回到开菜单／开战前那一刻。
- 需要用户决定：O-待定·自动存档检查点 采用与否（默认开）。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- 直接跑 godot（并行测试排共用槽 30 多分钟一项没轮到，停掉改单跑）：`xiyou_platform` 95/95、`xiyou_pause_save` 34/34、`xiyou_autosave` 10/10、`xiyou_save_page` 42/42、`xiyou_entry_release` 16/16、`xiyou_input_handled` 10/10、`xiyou_map_hotkeys` 36/36、`xiyou_battle_transition` 20/20。
- 交付前已 merge main。没跑 `xiyou_determinism`：start_battle 只加了一行检查点调用，桌面上 blocker 先返回 desktop、不写文件；请总装合并选测时带上。
- `语法检查.py` 通过；`事件空绿扫描.py --check` 55 例均在基线内。
- `选测.py main --list` 因 map_scene／xsave 列出 167 个场景；改动在桌面上不生效（`blocker()` 先判 desktop），所以只跑上面这组，没跑全量（车道规则）。

## 本分支提交

- WIP：补跑恢复倍速＋测试；自动存档检查点＋测试＋优化登记
- 交付单 cc_platform-fix2（本提交）
