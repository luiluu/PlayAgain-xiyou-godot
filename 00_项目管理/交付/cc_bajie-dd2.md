# 交付：cc/bajie-dd2（集成分支失败表 DD²）

- 车道／工作者：A 内容·楼层／八戒（cc）
- 状态：做完（交回集成分支，不进 main，不标可合并）
- 从 `cc/newsrc-switch` 3948463f 切出，对应失败表 run 42343228257。

## 场景 → 用例 → 根因 → 修法

| 场景 | 用例 | 根因 | 修法 |
| --- | --- | --- | --- |
| xiyou_input_handled | no_direct_set_input_as_handled | `ui/merchant29_page.gd` 是深渊商人页（DG 期一新加的），有两处直接写了 `get_viewport().set_input_as_handled()`：`List29._unhandled_input` 的翻页键，以及页面点翻页条。main 的 O-212 规定一律改走 `XKeyMap.handled`，测试按全工程扫描来拦。 | 两处都换成 `XKeyMap.handled(self)`。改后 10/10。 |
| xiyou_flow | rc=142 超时（拆开看：cmd_enter／alt_enter_not_map_action、floor1_loaded 起一路失败） | 不是游戏卡死。新源大厅 Map4 EV76「时空漩涡_字幕1」是首次进大厅时自动执行的过场（`CodexWhisper.seen('rift1')` 为假才播），要占住地图约 5000 帧。测试只等 3000 帧就去按 ⌘Enter，判成 busy；接着进门的 `run_event(36)` 也因为地图忙被拒掉，没进一层，后面每一步都等到超时。打桩确认 busy 是 EV76 从第 2989 帧占到第 7970 帧。和平台车道在修的 pause_save「并行页算 busy」不是一回事：这里是自动执行页，正常算忙。 | 只改测试：开局前把 XConfig 配置放进测试目录、删掉旧的，再用 `XConfig.whisper_mark("rift1")` 标成看过，做法同 `xiyou_actor_p0`。过场本身由 `xiyou_opening_branches` 的 c_rift_cutscene 单独测。改后 49/49，单跑没超时。顺带让 flow 不再读写默认配置文件。 |

## 验证

- 新源 v0.62.12，按本分支重跑转换器后 import：`xiyou_input_handled` 10/10，`xiyou_flow` 49/49，`语法检查.py` 0 问题。

## 本分支提交

- 见 `git log 3948463f..cc/bajie-dd2`
