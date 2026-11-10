# 交付：cc/battle-me1

- 车道／工作者：C 规则／机制（音频）／cc（悟空）
- 状态：可合并
- 分支基点：本地 main f2d3fdf8f，交付前合进 main 48a285fa9

## 变更记录草稿

## 2026-11-10 【cc·悟空·未经审查】战斗胜利／全灭 ME 与战后音乐接续（dev.待定）

- 对照 v0.62.12：`rpg_managers.js` AudioManager.playMe／stopMe／playBgm／replayBgm（`_replayFadeTime` 0.5）、BattleManager.processDefeat／playVictoryMe／playDefeatMe／replayBgmAndBgs，`Olivia_VictorySequenceUI` processVictory／playVictoryBgm／endVictoryPhase；System.json victoryMe＝Victory2、defeatMe＝Defeat2（音量 90）。数据里没有 133／139 换 ME 的事件，也没有 Disable/EnableVictoryMusic 插件命令；XdRs_HangUp 只包了胜利／失败消息，挂机、快速战斗照样放 ME。
- **胜利**：重制原来直接放胜利画面曲 Ship3，没有 Victory2。现在 `XBattleScene._victory` 先 `play_me(victoryMe)`，Ship3 只换上不开始（原版 ME 在放时 playBgm 不 play），ME 放完从头放、0.5 秒淡入。
- **全灭**：重制原来没有 Defeat2。现在 `_defeat` 一开始 `_defeat_me()`：Defeat2 与「被击败了」消息窗同时出（原版 displayDefeatMessage 只排文字、紧接 playDefeatMe），战斗曲停，ME 放完也不回来；快速战斗跳过消息也照放。
- **通用 playMe／stopMe**（`XBattleScene.play_me`／`_me_finished`）：在放的 BGM 暂停在原位置，ME 放完接着放并 0.5 秒淡入；停掉的 BGM 不会被 ME 放完带起来；ME 期间敌群事件 241 换曲只换上、ME 放完才放。新 ME 播放器走 ME 总线（设置里的 ME 音量生效）。
- **回地图**：原版 ME 不随场景结束停。`XMapScene.take_battle_me` 把战斗里没放完的 ME 接到地图自己的 `me` 上（同一首、位置接着），地图曲等它放完再淡入（挂机胜利、可败全灭都会走到）；下一场开战照旧 `me.stop()`（stopAudioOnBattleStart）。
- **战后地图曲淡入**：原版 replayBgmAndBgs 在战斗收场时（早于 Scene_Battle 淡出）就停战斗曲、地图曲／环境音从原位置接着放并淡入 0.5 秒；重制原来是回到地图才直接取消暂停、不淡入。现在 `start_battle` 收到结果就 `battle.stop_bgm()`、接 ME、`_replay_map_audio()`。地图事件 249 放 ME 后的地图曲接续也一起改成 0.5 秒淡入（同 stopMe）。
- 新增 `XAudio.fade_in`（按线性增益 0→原音量，同 WebAudio.fadeIn）、`XAudio.stop_fade`（换歌／改音量前收掉没淡完的淡入，地图 play_bgm／play_bgs 与战斗 _change_bgm 已调用）。
- 测试：新增 `tests/xiyou_battle_me.gd`（38 项）：系统 ME 名与文件；通用暂停／接续／淡入到目标音量；空 ME 不动 BGM；停掉的 BGM 不被带起；ME 期间 241 换曲排队；胜利 Victory2＋Ship3 排队、ME 后从头放并淡入；全灭 Defeat2、战斗曲停且不回来、整条 `_defeat` 走一遍 ME 与消息同出；地图接 ME（位置不倒回）；真打一场可败战斗（敌群 4、1 血、自动）后 Defeat2 在地图上放、地图曲等 ME 放完再淡入；换歌不被没淡完的淡入改音量。反向验证：去掉胜利／全灭的 play_me，4 项失败（已还原）。
- 玩家可见：打赢先响胜利号角再进胜利画面曲，全灭有失败短曲；战斗结束回地图，地图音乐淡入接上（号角没放完时等它放完）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·逃跑后地图曲时机 | `XBattleScene` 逃跑收场 | processEscape 成功时 displayEscapeSuccessMessage 只排文字、紧接 processAbort → replayBgmAndBgs，地图曲在「开始逃跑了」消息显示时就淡入 | 未改：重制等逃跑消息窗关掉、战斗发 finished 后才换回地图曲（晚一个消息窗的时间） | 偏差，不是优化；要对齐需把 `_replay_map_audio` 挪到逃跑消息之前，跨战斗／地图两处 | 对齐时在 `_escape` 的 message.run 前发信号让地图先换曲 | cc（悟空） | 待定（偏差记录，Kyo 定要不要对齐） |

## 交接板

- 用户试玩说明：打赢一场战斗，先听到胜利号角（约 7.6 秒），之后胜利画面音乐淡入；全灭时有失败短曲；回地图时地图音乐淡入。挂机连战时号角会在地图上接着放完，下一场开战即停。
- 需要用户决定：O-待定·逃跑后地图曲时机（逃跑后地图曲晚一个消息窗才回来，要不要对齐原版）。默认不改。
- 下一步：无。

## 进度账

- 无（音频补齐，不改完成度）。

## 可优化（流程／工具／效率）

- 无。

## 验证

- `语法检查.py` 通过；`工具回归.py` 全过（64 秒）。
- 本机专项 19 个全过（合 main 前一轮 18／19，唯一失败 xiyou_game_over 2c 在未改的 main 文件上同样失败，main 48a285fa9 已修测试；合 main 后单跑 27／27 过）：xiyou_battle_me、xiyou_battle_bgm、xiyou_battle_transition、xiyou_game_over、xiyou_battle_end_ce、xiyou_determinism、xiyou_hangup、xiyou_hangup_auto、xiyou_victory_text_flow、xiyou_battle_events、xiyou_battle_log、xiyou_battle_ui、xiyou_battle_pace、xiyou_map、xiyou_flow、xiyou_movie、xiyou_poison_collapse、xiyou_event_compare、xiyou_dungeon。
- `选测.py main --list` 列 157 个场景（battle_scene／map_scene 被大量引用）；只改音频播放、不改战斗数值与随机数（xiyou_determinism 过），其余楼层／地图专项交总装合并选测。
- 没跑同步：没改切片、转换器、探针。

## 待交叉核查

- 甲：`modes/xiyou/battle/battle_scene.gd`（`me`、`play_me`、`_me_finished`、`_defeat_me`、`stop_bgm`、`_victory`、`_change_bgm`）
- 乙：`modes/xiyou/map/map_scene.gd`（`_me_finished`、`take_battle_me`、`_replay_map_audio`、`start_battle` 收场次序、play_bgm／play_bgs 收淡入）、`modes/xiyou/core/audio.gd`（fade_in／stop_fade）、`tests/xiyou_battle_me.gd`

## 本分支提交

- 00b05765f WIP：战斗胜利／全灭 ME
- b194d7eb7 WIP：回地图 replayBgmAndBgs 淡入、真战斗交接测试
- 2df65136b WIP：收场即换回地图曲、ME 期间换曲排队
- 4575ad8ac 合并 main
- （本提交）交付单
