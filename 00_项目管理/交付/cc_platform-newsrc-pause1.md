# 交付：cc/platform-newsrc-pause1

- 车道／工作者：平台（cc，项目线程「完成再刷西游Godot引擎重制」；总装失败表）
- 状态：可合并
- 基于：cc/newsrc-switch 3948463f（集成分支）。合回集成分支，不进 main。内容提交 7b9fe57b（旧 f5a52fd4 误带 generated.oldsrc，已重做、没推过）。

## 变更记录草稿

## 2026-11-07 【cc·平台·未经审查】集成分支 xiyou_pause_save 修夹具：新源方桌大厅的自动执行字幕事件（dev.待定）

- 场景 `xiyou_pause_save` → 用例 map_saves、no_popup、dedup_focus_out、dedup_paused_again、after_window_saves、focus_out_saves（run 42343228257 shard-3，全是 `skip:event`）→ 根因：不是并行事件。新源（v0.62.12）方桌大厅 Map004 多了事件 76「时空漩涡_字幕1」，第 0 页无条件自动执行（47 条：字幕、等待、`CodexWhisper.mark('rift1')`，最后开独立开关 A）。测试进图后只等 4 帧，演出还在跑、地图 busy，切后台照规矩跳过。集成分支（3948463f）的地图场景根本没有跑并行页（trigger 4）的代码，所以「并行页一直算 busy」不成立。→ 修法：测试夹具跟 20 号一样先开 76 的独立开关 A；加前提断言 map_idle_after_setup，以后再有新的自动执行事件会直接报在这一项。游戏代码不动：演出在跑时跳过切后台存档是对的。
- main 上：v0.28 的 Map004 没有 76 号事件，main 也没有跑并行页的代码，不受影响，不用另开分支。

## 交接板

- 下一步：无
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- 本机用新源产物（从 cc/wukong-newsrc10 工作树克隆 generated，重导入）跑 `xiyou_pause_save`：35/35。
- 反向：去掉 76 号开关那一行，正好复现云端失败表那 6 项（map_saves、no_popup、dedup_focus_out、dedup_paused_again、after_window_saves、focus_out_saves，全是 `skip:event`），新加的 map_idle_after_setup 也挂。
- 只改了测试文件，没跑云端。
