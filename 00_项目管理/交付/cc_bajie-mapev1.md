# 交付：cc/bajie-mapev1

- 车道／工作者：A 内容·地图事件／八戒（cc，项目线程「完成再刷西游Godot引擎重制」）
- 状态：进行中

## 逐条对照（Codex 审查报告）

- 报告第 11 项（`map_scene.gd:578`，地图不执行触发 4 的并行事件）→ 复现测试 `xiyou_map_dispatch` 的 `par.m152e8:*`、`par.m32e10.toggle:*`、`par.m32e10.transfer:*`（旧代码上全挂：并行页从不启动）→ 修法：每个并行页一个独立 `MVInterpreter`（`parallel = true`），由 `MVEvent._update_parallel` 在事件每帧更新后调 `XMapScene.start_parallel` 起；不占 `busy`、不进 `run_event`，不触发 `XDungeon.event_finished`；跑完置空、下一帧从头再跑（同原版第 N 帧跑完、第 N＋1 帧重 setup）；换页、消除（`MVEvent.refresh` → `stop_parallel`）、换图（`load_map` → `_stop_parallels`）、离开地图（`_exit_tree`）时 `cancel()`，解释器在下一个等待点结束（230 等待、205 等路线、212 等动画、213 等气泡、223 等色调都查取消；父子游标共用 token）。并行的 230 按物理帧数，菜单、战斗、各种画面、传送页开着时不往下数（`parallel_active()`）；并行里的文字等主事件结束再显示，显示期间同样锁住玩家（`show_parallel_message`；切片里两处并行页都没有文字，备而不用）。
- 报告第 12 项（`mv_event.gd:95`，自主移动只有类型 1）→ 复现测试 `xiyou_map_dispatch` 的 `auto2.m142e4`、`auto2.m93e3`、`auto2.m142e4.forced`、`auto3.m149e33`、`auto3.m149e33.forced`、`auto3.m149e33.skip#original`、`auto3.m88e3.flee`（旧代码上全挂）→ 修法：
  - `MVCharacter.update_character` 停着时走 `_update_stop`（Game_Character.updateStop）：停步计数 `_idle_count`（MV `_stopCount` 的自主移动用途：停一帧加一，转向、走成、跳跃清零）、有强制路线走强制路线；`MVEvent._update_stop` 再在没有强制路线时走自主移动。
  - 类型 2 接近玩家（`moveTypeTowardPlayer`：不到 20 格时 4/6 接近、1/6 随机、1/6 往前，远了随机）；类型 3 自定义路线（页的 moveRoute，`updateRoutineMove` 同强制路线一套）。
  - 自主与强制的区别：频率只管自主（停步超过 30×(5－频率) 帧才走，类型 2／3）；强制路线每停一帧就走下一条；强制期间自主停下、走完从记下的那条接着走（`force_move_route` 只在没记过时记原路线，同正式版）；确定键／接触启动的事件执行期间该事件 `locked`，自主停下、停步计数清零，强制路线照走；换页 `set_move_route` 取消强制路线、新页路线从头走（setupPageSettings）；不在画面附近不自主移动（`XMapScene.near_screen`，一屏以内）。
  - 补上路线指令 5～8 斜走、9 随机、10／11 接近／远离玩家、20／21／23 转 90 度、24 随机转向、25／26 面向／背对玩家、45 脚本（只认 YEP_EventChasePlayer 的 `this._fleeRange = N` 类设定）。
  - YEP_EventChasePlayer 的逃离（Map088 四团鬼火）：看见玩家（面朝玩家方向、5 格内）锁定 300 帧，逃离中每停一帧就远离（5/6）或随机（1/6），冒警觉气泡；锁定结束后等 180 帧往原位走，到了恢复原朝向。追逐（要寻路）全游戏没用到，没做，路线脚本写了会在 event_compare 变红。
  - 类型 1 随机移动的节奏沿用重制原有写法（没换成原版的停步计数），只加了强制路线、锁定、离屏时停下。
  - 存档：类型 3 记下自定义路线走到哪一条（`customRoute`），读档接着走。
- 原版缺陷（O-待定，已登优化登记）：强制路线结束后自定义路线跳过一条、换页不清记下的原路线 → `MVCharacter.route_resume_fix`，默认修好。复现测试 `auto3.m149e33.skip#original`（关开关逐行等于原版的偏移）与 `auto3.m149e33.skip#fixed:no_drift`（开着不偏）。
- 走路速度（总装 11-07 定案，复现原版、不登 O 号）：正式版 `js/rpg_οbjects.js`（文件名里是希腊字母 ο）`Game_CharacterBase.distancePerFrame` 写成 `2*Math.pow(2, this.realMoveSpeed()) / 256`（冻结 v0.28 第 6549 行、v0.62.12 第 6550 行），每帧距离比 MV 默认翻倍；重制原来按 MV 默认，整体慢一倍。`MVCharacter.move_distance_scale` 默认 2.0，设 1.0 回退。和 Drill_SpeedGear 的 1.6 倍帧率相乘才是原版实际速度，两边各自对齐。专项断言 `tile_frames_speed3`：速度 3 走一格 16 帧（参照 Map093 事件 3）。
- event_compare：原有用例只单独执行一页，量不到分发；新加三项守覆盖面：`dispatch_parallel_pages_covered`（切片每个并行页都要有 `par.m<地图>e<事件>` 分发用例）、`dispatch_route_codes_known`（类型 3 路线与 205 用到的移动指令都要是 MVCharacter 认得的）、`dispatch_route_scripts_known`（路线脚本只认 YEP 逃离设定）。

## 变更记录草稿

## 2026-11-07 【cc·八戒·未经审查】地图并行事件、自主移动类型 2／3、YEP 逃离，强制路线与自主路线分开；走路速度同正式版（Codex 审查第 11、12 项；O-待定，dev.待定）

- 起因：Codex 审查报告第 11 项（地图不执行触发 4 的并行事件，用例 Map152 事件 8、Map032 事件 10）、第 12 项（自主移动缺类型 2 接近玩家 22 页、类型 3 自定义路线 5 页，强制与自主路线不分）。
- 新参照探针 `mv_oracle/map_dispatch_probe.cjs`（冻结正式源真跑 `$gameMap.update`，10 例），夹具 `tests/fixtures/map_dispatch_oracle.json`；新专项 `tests/xiyou_map_dispatch`（真实地图场景，自主移动逐帧逐行对照、并行事件看起停与动画）。
- 并行事件：独立解释器、不锁地图，换页／消除／换图安全终止（见交付单逐条对照）。`modes/xiyou/map/map_scene.gd`、`mv_event.gd`、`mv_interpreter.gd`。
- 自主移动：类型 2、类型 3、路线指令补全、YEP_EventChasePlayer 逃离；频率只管自主，强制期间自主停下、走完接着走，事件执行期间锁住。`modes/xiyou/map/mv_character.gd`、`mv_event.gd`。
- 原版缺陷 O-待定（`MVCharacter.route_resume_fix`，默认修好）：强制路线结束后自定义路线跳一条、换页不清记下的原路线。
- 走路速度：正式版 `js/rpg_οbjects.js` 的 distancePerFrame 是 MV 默认的两倍（冻结 v0.28 第 6549 行、v0.62.12 第 6550 行），重制改成一致（`MVCharacter.move_distance_scale = 2.0`，设 1.0 回退）。复现原版，不登 O 号（总装 11-07 定）。
- 玩家可见：Map152、Map032 的并行事件会动了；接近玩家的鬼火、按路线乱跑的小动物、看见人就逃的鬼火都会动了；人物和事件走路比之前快一倍（和原版一样）。
- event_compare 加三项覆盖面守卫（并行页都有分发用例、路线指令与脚本都认得）。

## 交接板

- 下一步：battlefix2 交付全局 1.6 倍（Drill_SpeedGear）后，实机看一次走路速度是否和原版一致（两者相乘）。YEP 追逐（要寻路）全游戏没用到，暂不做。
- 用户试玩说明：Map152（开关 2307＋79）、Map032（开关 2285）的并行动画会播；Map142／143／169／192／220 等地图上的鬼火会朝玩家走；Map149 背包小动物会按路线乱跑跳；魂河畔 Map088 的鬼火看见你会逃。走路速度比之前快一倍。
- 需要用户决定：O-待定（强制路线后自定义路线不跳条），默认修好。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：类型 1 随机移动仍是重制自己的节奏（每次等 (5－频率)×30＋0～60 帧），没换成原版「停步超过阈值后 2/6 随机、3/6 往前、1/6 重新计数」；要对齐原版可照类型 2 的写法改，参照探针加一个类型 1 用例即可（归地图事件车道）。
- 建议：原版事件启动时 lock 会让事件转向玩家、结束 unlock 恢复原朝向；重制只在确定键事件开头转向、不恢复。这轮只做了 lock 的「停下自主移动」部分（归地图事件车道）。

## 验证

- 新专项 `xiyou_map_dispatch` 49／49（并行 3 例、自主 7 例＋两边开关、走一格 16 帧）。旧代码（main 版四个文件，只补测试要读的几个字段）上跑 44 项挂 21 项：并行页从不启动、所有自主移动用例、走一格帧数。
- 选测：待填
- `语法检查.py` 通过；`工具回归.py` 全部通过（78 秒）；`事件空绿扫描.py --check` 通过（空绿 55 例均在基线内）；`探针登记检查.py` 通过（新探针有夹具）。

## 待交叉核查

- `map/mv_character.gd`：`update_character` 改走 `_update_stop`；`set_direction` 清停步计数；`force_move_route` 改成只在没记过时记原路线；`_update_route` 的结束分支还原原路线。玩家、跟随者、飞艇走的也是这条路，请重点核强制路线（门事件、205 等待完成）行为没变。
- `map/mv_event.gd`：`refresh` 换页时 `set_move_route` 会取消正在走的强制路线（同原版 setupPageSettings）——以前重制换页后强制路线还接着走。
- `map/mv_interpreter.gd`：`run` 循环查取消；并行解释器不调 `XDungeon.event_finished`。

## 本分支提交

- a619bd11 WIP：参照探针 map_dispatch_probe 与夹具
- f84bfef5 WIP：并行事件、自主移动、专项
- bc8ffaf1 WIP：走路速度同正式版
- 896f46a8 WIP：专项按原版比强制路线、event_compare 覆盖守卫
- 合并 main（交付前）
- 交付单 cc_bajie-mapev1（本提交）
