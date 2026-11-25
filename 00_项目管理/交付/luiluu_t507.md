# 交付：luiluu/t507

- 车道／工作者：西游档修复／cc（Opus＋medium，T507）
- 状态：可合并

## 变更记录草稿

## 2026-11-25 【cc·T507·未经审查】有预约的公共事件先跑：快捷回程不再先触发面前的对话（dev.待定）

- 玩家反馈（v0.04，安卓，Kyo 转）：站在传送门／NPC 前「按 1 快捷回程」，先弹出面前的对话，回程排在对话后面；连点就会选进深渊、回程等于没了。
- 根因：快捷键（YEP_ButtonCommonEvents，1＝CE10 回大厅）在地图的物理帧里只预约公共事件，要到这一帧的 `_process` 才开跑。玩家节点的物理帧排在地图后面，同一帧里的确认键、点到目的地、撞上或踩上事件只看 `busy`，就先把面前的事件跑起来；预约的回城要等对话结束才轮到。预约已经挂着、还没开跑的时候按确认也一样。原版 `Game_Map.update` 先 `setupStartingEvent`（预约的公共事件优先），解释器一跑，玩家这一帧就动不了。
- 修法：`XMapScene.RESERVED_FIRST`（默认开）。有预约的公共事件（快捷键、枫叶、物品）还没开跑时，`_on_action`（确认键／点前方一格）、`_on_touch_arrived`（点地走到停下）、`_on_player_step`（踩上接触事件）、撞上同层接触事件这四处都先跑预约事件，这一下不调查地图事件。`false` 回到旧行为（专项末尾有一段验证开关关掉的旧行为）。
- 专项 `xiyou_item_transfer_no_talk`（新，115 条）：大厅两处（EV004 李老嗨面前、EV075 时空漩涡＝深渊入口面前）各先确认「按确认会调查到它」。然后测三组：①背包用指路灯，键盘、手柄、虚拟确定键、真触屏点旧物品页「使用」、按住到菜单关掉后才抬手、各种连点，以及新界面物品页点牌上「使用」；②真触屏点枫叶回城和连点；③快捷键 1 单按、1 和确认同一帧按、预约挂着时按确认；④（返修）1 和点按面前一格同一批到达，先 1 后点、先点后 1 两种顺序，加上「只点不按 1 照常调查」的对照。断言都是「传到了、面前的事件一次都没跑、没开店」。另有一条断言：传完之后正常对话照旧能触发。
- 返修（小o 核 P1-1）：地图点按（鼠标、触屏仿出的左键）点自己脚下或前方一格当确认（D1／D2），原来在输入回调里当场发出调查，比地图物理帧采样快捷键 1 还早。1 和点按同一批到达时，会先开漩涡／NPC，busy 之后热键不再预约，回城请求被吞掉。`MVPlayer.DEFER_CLICK_ACTION`（默认开）：这一下像确认键一样先记下，到玩家自己的物理帧（排在地图采样并预约快捷键之后）再发，预约的回城就先跑。走动中点按只当目的地，走到停下（D1）或走不过去（D2）再按确认，同原版 triggerTouchAction 在 updateNonmoving 里。`false` 回到当场发。
- 热修（小o R2 P1-2）：第一版返修在走动／滑行中点按只当目的地，记下的一下如果下一帧仍在动也会被清掉；飞艇滑进可降落格时点脚下，到达信号对载具不处理，结果这一下被吞、要停稳后再点一次。现在点中脚下／前方一格照旧记下，走动／滑行中保留到停稳那一帧再发，只在不收输入（事件、菜单、挂机、升降）时作废。`xiyou_airship_view` 补「滑行中点脚下、不用再点就降落」回归（修前版本这条失败）。
- 改了 `modes/xiyou/map/map_scene.gd`、`modes/xiyou/map/mv_player.gd`。这四个入口西游档和天启篇共用，天启篇地图同样受益，行为一样；没有预约事件时一行不变。
- 玩家可见：站在传送门或 NPC 面前按快捷回程（1／枫叶），直接回城，不再先弹面前的对话，连点也不会误进传送门。

## 交接板

- 下一步：无
- 用户试玩说明：在大厅漩涡或任一 NPC 面前按 1（或点左下枫叶），同时或紧接着按确认，应直接放光柱回城，不出对话。
- 需要用户决定：无

## 进度账

- 无（玩家反馈修复）

## 可优化（流程／工具／效率）

- 建议：测试里 `load_map` 会换一个玩家节点，挂在旧 `player.action_pressed` 上的计数会悄悄失效（本单专项起初就因此误判过）。写地图专项时，要么每次换图后重挂，要么改盯 `running_event_id`。可以在 `tests/xiyou_test_env.gd` 加一个辅助函数，归工具车道。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XMapScene._on_action`／`_on_touch_arrived`／`_on_player_step`、物理帧撞上接触事件 | 信号连接 3 处＋物理帧 1 处（`git grep -n "_on_action\|_on_touch_arrived\|_on_player_step" -- '*.gd'`） | 只在有预约公共事件、地图不忙、菜单没开时多一步「先跑预约」，其余路径不变；`run_reserved_common_event` 本身已判 busy／菜单／存档对不上 |
| 新开关 `XMapScene.RESERVED_FIRST` | 1 处（`git grep -n RESERVED_FIRST -- '*.gd'`） | 默认 true；专项两边都跑 |
| `MVPlayer.click_cell`（返修）＋新开关 `DEFER_CLICK_ACTION` | 调用 3 处（`git grep -n click_cell -- '*.gd'`）：`mv_player.gd` 自身的点按、`tests/xiyou_airship_view.gd` 2 处、`tests/xiyou_step_encounter_stop.gd` 1 处 | 点脚下／前方一格的调查晚一个物理帧发出；`xiyou_airship_view` 点脚下降落的断言改成等两个物理帧再看（63/63）；`xiyou_step_encounter_stop` 只留目的地，不受影响（7/7） |

## 验证

- 热修本机：`xiyou_airship_view` 72/72、`xiyou_item_transfer_no_talk` 115/115、`xiyou_step_encounter_stop` 7/7、`xiyou_transfer_touch` 12/12、`xiyou_one_press` 51/51；语法检查通过。
- 返修本机：`xiyou_item_transfer_no_talk` 115/115（`DEFER_CLICK_ACTION=false` 时两种顺序 8 条失败、回城被吞，复现了小o 的 P1-1），`xiyou_airship_view` 63/63，`xiyou_step_encounter_stop` 7/7，`xiyou_transfer_touch` 12/12，`xiyou_map_hotkeys` 36/36，`xiyou_hud` 34/34，`xiyou_platform` 162/162，`xiyou_feedback_v001` 32/32，`xiyou_map_dispatch` 49/49，`xiyou_one_press` 51/51；工具回归全过。
- 首轮本机专项：`xiyou_item_transfer_no_talk` 104/104。反向验证：`RESERVED_FIRST=false` 时 1＋确认同帧那 4 条失败（99/103），开回来全过。
- `语法检查.py`：1229 个 .gd，0 个问题。
- 云端选测：通过，见下方「云端选测」。
- 没复现的：背包用传送道具（指路灯）这条路径，各种输入方式在本机无头都没复现。用了道具后菜单一关，同一帧就开跑公共事件，busy 全程挡着调查；派单原话说的「背包」，玩家后来更正为快捷回程。本修法对背包路径同样兜底：物品预约后若有任何空档，也是先跑预约。

## 云端选测

- ✓ 热修通过：提交 6ba5a2d5e，基准 7627e0246，83 个场景、4 片，最长一片 8.8 分钟；`gh run watch` 前台等完。运行页：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45651289015
- ✓ 返修通过：提交 f83cb3f59，基准 dd4b611fd，83 个场景、4 片，最长一片 8.8 分钟；`gh run watch` 前台等完。运行页：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45647960381
- ✓ 通过：提交 2b06286cc，基准 85f097acd，171 个场景、6 片，最长一片 9.2 分钟；`gh run watch` 前台等完退出 0。运行页：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45639899377
- 工具回归.py 全过（146 秒）；发行空壳.py check 退出 0（84 个脚本、829 个函数）。

## 本分支提交

- 56c622d83 WIP: 复现专项
- 2b06286cc 有预约的公共事件先跑（RESERVED_FIRST）＋专项
- f83cb3f59 返修：点按当确认留到玩家物理帧（DEFER_CLICK_ACTION）＋专项两种顺序
- 6ba5a2d5e 热修：延后的点按滑行中不丢＋飞艇滑行中点降落回归
