# 交付：cc/bajie-dd3（集成失败表第二批，云端整轮 f5561574，run 42352510071）

- 车道／工作者：A 内容·楼层／八戒（cc）
- 状态：做完（交回集成分支，不进 main，不标可合并）
- 从 `cc/newsrc-switch` 628d001a（含 rules-newsrc6）切出。

## 场景 → 用例 → 根因 → 修法

| 场景 | 用例 | 根因 | 修法 |
| --- | --- | --- | --- |
| xiyou_walk_speed | run.frames（331，应约 40）、run.frames_per_tile [331,4] | 跑步计时放在大厅 Map004 里测。新源大厅首次进入会自动播漩涡过场（Map4 EV76，`CodexWhisper.seen('rift1')` 为假才播），播的时候占住地图，玩家走不动，计时就把等过场的帧数也算了进去。根因和 DD² 的 xiyou_flow 一样。 | 只改测试：配置已经在测试目录里了，开局前删掉旧配置，再 `XConfig.whisper_mark("rift1")` 标成看过。改后 9/9。 |
| xiyou_map_dispatch | par.m32e10.transfer:no_anim_after（动画 136→事件 75 第 1036 帧，678→事件 77 第 1291 帧） | **是新源数据变了，重制没有 bug。** 这例从 Map032 换到大厅 Map004，看到达之后还有没有动画。报出来的两条动画查了大厅数据：EV76 漩涡过场里有 `212 [75, 136]` 和 `212 [77, 678]`，就是到达大厅后过场在放的动画，不是旧图 EV10 的并行页没停。旧解释器取消（old_interp_cancelled）这一项本来就过了。 | 同上，标 rift1 看过。断言不用改：标了以后到达大厅没有过场，「旧图并行在新图放动画」照样能拦住。改后 49/49。 |

## 验证

- 新源 v0.62.12，按本分支重跑转换器后 import：`xiyou_walk_speed` 9/9，`xiyou_map_dispatch` 49/49。只改了两个测试文件，没跑别的场景。

## 本分支提交

- 见 `git log 628d001a..cc/bajie-dd3`
