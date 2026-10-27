# 交付：claude/bajie-shop-review-c34c2a-2

- 车道／工作者：B 界面／八戒（Claude），接手八戒_76；期二＝交叉核查沙僧待 Claude 核查的 4 批
- 状态：可合并（期二：4 批核查＋1 处修复）
- 分支从期一头 f1bfb256 拉出；期一已并入 main，本分支已合 main。

## 变更记录草稿

## 2026-10-27 【Claude·八戒】核查 925204b 等（codex/state-effects-2e，dev.136）：通过，修一处边界

- 核查范围：925204b7（合并 codex/state-effects-2e，24 个提交 4bf9996…c572e51）
- 读了：`power.gd`（预演 `XDamage.finish` 补传 `{"variables": vars}`）、`state_effects.gd`（`PhaseValueProgram` 未给变量时取 `XState.current.variable_array()`，`v[...]` 缺值按 `Game_Variables.value` 记 0，通用公式 VM 不变）、`xstate.gd`（`_reserved_common_event_id` 单槽，不存档）、`map_scene.gd`／`menu.gd`（菜单、地图、枫叶回城共用 XState 单槽，按捕获的 owner 消费，先清槽再执行）、`tests/xiyou_review135.gd` 与 `review135_probe.cjs`、`state_effects_tp_context_probe.cjs`、设计文档。别处的生产者也都已迁过来（`item_scene.gd` 道具 44 效果用 `s.reserve_common_event`），没有残留的 `reserved_common_event` 字段。
- 发现并当场修（ade369af，待 Codex 核查）：`run_common_event` 遇到不存在的公共事件时直接返回、不清槽，`_process` 每帧都看到预约 > 0，于是**永远不再查自动执行事件**（原版这里 `reservedCommonEvent().list` 直接报错）。现在 busy 时照旧保留预约；事件不存在时清槽返回。`xiyou_review135` 加 `reservation.missing_event_clears_slot`，修前红 `[999999, false]`，修后 85/85。当前生产者用的 ID（1、2、3、10、169、431 与道具 44 效果）都存在，属于防御性修复。
- 观察（不改）：战斗里的预约仍是 `XBattleLogic` meta `battle_ce`（`battle_common_event.gd`），没并进 XState 单槽。原版是同一个 `$gameTemp` 槽：地图上待执行的预约遇到开战会被 `startBattle` 的 `reserveCommonEvent(1320)` 盖掉，战斗里没消费完的预约回地图后会跑。0b 的范围写明只迁地图／菜单，所以不算缺陷，列进遗留。
- 可优化：`PhaseValueProgram.run_phase` 在 ctx 不带 `variables` 时每次新建 5000 格 `variable_array()`；只有 pure 程序会走到，量不大，需要时可按 XState 缓存。

## 2026-10-27 【Claude·八戒】核查 117ba14（进度核算收工检查：临时裸库关闭 receive.autoGC）：通过

- 核查范围：117ba14
- `测试合并工具.py` 只在本测试自建的裸库 `github.git` 上设 `receive.autoGC false`（外部给 url 时不碰），推送断言不变；文件里只有这一处 `init --bare`，没有别的裸库漏设。
- `python3 测试合并工具.py`：154/154（173 秒）。

## 2026-10-27 【Claude·八戒】核查 8f8c525 等（codex/review-pending-20261024，dev.164 里 Codex 的小修复）：通过

- 核查范围：8f8c525f（合并 codex/review-pending-20261024，21 个提交 1bd0430…2fba4b5；待 Claude 的是沙僧的提交）
- 宠物身份标签 a0425ccc：`pet_name` 用 `is_same(war_pet(s), pet)`，`war_pet` 返回列表里的同一个字典，两只属性相同的宠物只给出战那只加「[出战]」；新回归按原版 GTWar 对象身份参照。
- 制作浮窗遮盖 64469ac5：`_paint_confirm` 只在 confirm／popup 两种模式画内容，列表／类别阶段让金币窗盖住，与 mode 取值（category／list／confirm／popup）对得上。brave083 `f3_soul_no_crowns` 原来 `battles.size() >= 0` 恒真，改成 `== n0`，弱断言已修。
- 雪粒子 87e01f59：`draw_circle((4,4), 4)` 与原版 `Weather._createBitmaps` 的 9×9 位图 `drawCircle(4, 4, 4)` 一致。
- 实验室／要塞回程 dee90b29／fe915372：对照冻结 v0.28 Map111 EV9 第 5 页、Map036 EV2 第 2 页：持有 179 时变量 106＝1 并扣掉 179（没有 179 才随机 1～3），选项 `['进入此门','离开这是非之地']` 第 1 项是「离开」，回 Map031 (8,5)／Map029 (10,31)。专项先给 179、选 [1]、断言 106＝1，路径确定，不再靠随机。
- 新地图专项停音 23aafd61／3999e011、取证入口 86c052c8／1a938bbc（截图前先关工坊层、遮挡算失败）：只改测试与取证工具，读过，没发现问题。
- 专项：crafting 49、pets 29、screen_fx 28、floor_lab111 62、floor_fortress029 71、floor_brave083 101、floor_reach139 74、training 188 全过。

## 2026-10-27 【Claude·八戒】核查 9b140f3 等（codex/stage-review-50-phase2，dev.182）：通过

- 核查范围：9b140f36（合并 codex/stage-review-50-phase2，43 个提交 fc73ed6…7130c9b）
- 读了：`xstate.gd from_dict`（档里没有 `phwarehouse` 且 Map4 EV8 自开关 A 已开时补空「仓库:999」；有字段——哪怕是空字典——就不动；恢复后对每个角色 `param_mark_dirty`＋`param_refresh` 重建状态效果快照，不夹 HP／MP）、`warehouse.gd` 注释、`xiyou_event_compare` `cases_ran` 去掉「有过滤就放过」（空过滤零用例不再假通过）、`xiyou_lobby_shops` 加原版用例 finished／stateUnchanged 断言、`review_system_pages_compare.py` 把浏览器日志错误也算失败（`run_error_checks`＋`测试共性验收.py` 4 例）、`xiyou_stage50_review` 与 `stage50_review_probe.cjs`、同步脚本 PROBES 登记。
- 小意见（不改）：`xiyou_stage50_review` 的 `counter.real_path` 里 `int(ref.counterCalls) == 1`、`counter.origin` 里 `bool(ref.originIsSelf)` 是对参照数据本身的守卫，不是对 Godot 的比较（Godot 那半边另有断言）；审查证据 PNG 有两张 3.3～3.6 MB 进了 Git，以后取证可以先压缩。
- 专项：warehouse 32、stage50_review 10、lobby_shops 94、inlay_book 19、event_compare 5 全过；`python3 测试共性验收.py` 25/25。

## 交接板

- 待交叉核查：ade369af（八戒修 925204b 核查问题）待 Codex。
- 下一步：无新增任务。
- 需要用户决定：无

## 进度账

- 无变化（核查与防御性修复）

## 验证

- 第一轮专项（修复在内）：`并行测试.py … xiyou_review135 xiyou_state_effects xiyou_power xiyou_hud xiyou_item_use xiyou_map xiyou_pets xiyou_crafting xiyou_screen_fx xiyou_floor_lab111 xiyou_floor_fortress029 xiyou_floor_brave083 xiyou_floor_reach139 xiyou_warehouse xiyou_stage50_review xiyou_lobby_shops xiyou_inlay_book xiyou_training xiyou_status_power`：20 个场景全过（state_effects 19949、map 357、power 137、review135 85、hud 34、item_use 11、status_power 36、status_power_panel 11 等），116 秒。
- 修复先红：撤掉 `map_scene.gd` 修复单跑 review135，`reservation.missing_event_clears_slot` 失败 `[999999, false]`；还原后通过。
- 工具：`测试合并工具.py` 154/154，`测试共性验收.py` 25/25。
- 合 main 后 `检查.sh --affected main`（长任务.py 启动）：选测 75 个场景全过（map_scene.gd 改动带出的地图、楼层、挂机、选项等），文档登记、访问守卫、导出排除通过，测试 917 秒。
- 临时输出只在会话草稿目录，未写进工作树；已清理。

## 遗留

- 战斗内公共事件预约（`battle_ce`）与地图／菜单的 XState 单槽还是两套，和原版同一个 `$gameTemp` 槽有两处行为差：①地图预约还没跑就开战，原版会被 1320 盖掉；②战斗里没消费完的预约，原版回地图后会跑。复现：在地图 busy 时 `XState.current.reserve_common_event(10)`，再从事件开战，战斗结束回地图后重制仍执行 10，原版不执行。目前没有已知事件走到这条路，建议留给沙僧在状态／战斗框架里统一（`battle_logic.gd` 是沙僧独占）。

## 可优化（流程／工具／效率）

- `PhaseValueProgram.run_phase` 不带 `variables` 时每次新建 5000 格数组，可缓存（量小，未做）。
- 审查取证 PNG 先压缩再进 Git（本批两张 3.3～3.6 MB）。

## 本分支提交

- ade369af 修复 925204b 核查问题：预约不存在的公共事件时清槽
