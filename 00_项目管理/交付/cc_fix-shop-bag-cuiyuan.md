# 交付：cc/fix-shop-bag-cuiyuan

- 车道／工作者：B 界面＋物品／cc（Orca worker，Opus＋medium）
- 状态：可合并（已交付，ag 甲档核查通过、P3 已补）

依据：v0.01.09 玩家反馈①「随便开一个商店，退出后自动又打开背包」、③「淬元丹无法使用」（Kyo 11-14 转述）；协调追加「PC 按键好像按一次会响应多次」。
v0.01.09 补丁线（`release/v0.01`，`966c578f4`）上这三处代码与 main 相同（`_add_scene_page` 没有关页面记帧、`mv_player.gd` 物理帧轮询确认键、物品页没有淬元丹分支），所以在 main 上复现即可。

## 根因与修法

| 问题 | 根因（证据） | 修法 |
| --- | --- | --- |
| ① 退出商店又开菜单 | 商店 `_unhandled_input` 收到 ui_cancel（Esc、手柄 B、触屏「取消」键都发这个动作）当场 `closed.emit()`，事件协程同步收尾、放开 busy；同一帧地图 `_process` 还看得到 `Input.is_action_just_pressed("ui_cancel")`，就 `open_menu()`。关菜单早有同帧保护（`_menu_closed_frame`＋`XKeyMap.menu_call_blocked`），事件开的页面没有。新专项修前 `esc_no_menu_after_shop`、`pad_b_no_menu_after_shop` 都是 `[true,true]`（菜单开了）；右键走 `_gui_input` 已 accept，不触发。玩家说的「背包」就是主菜单（第一项「物品」）。原版 popScene 回 Scene_Map 至少隔一帧，`isTriggered` 已过，不会再开 | `map_scene.gd` `_add_scene_page`：页面有 `closed` 信号就连一个一次性回调，关的那帧记进 `_menu_closed_frame`，本帧不开菜单。所有事件页面（商店、宝珠商店、云裳商店、存档页等 20 多处）一起受益 |
| 追加：PC 按一次键响应多次 | 和①同类（界面在输入阶段用掉了按键、地图还按「轮询」再响应一次），但是另一处：`MVPlayer.update_character`（在 `_physics_process` 里）用 `Input.is_action_just_pressed("ui_accept")` 轮询确认键，轮询不看 `set_input_as_handled`。商店里按确认选「取消」→ 关店、事件当帧收尾放开 busy → 紧接着的物理帧玩家看到「刚按下」→ 再调查一次 NPC（又开对话，再按就又开店）。逐帧追踪：关店在第 116 帧，`_on_action` 在第 118 帧（物理帧比处理帧晚，处理帧那一侧的拦截挡不住；高刷新率显示器处理帧多于物理帧，更容易撞上）。新专项修前 `kb_no_retalk`、`pad_no_retalk` 失败。按住连发照原版（`xiyou_key_repeat` 管：按下触发、24 帧后每 6 帧，系统回显吞掉），没发现「回显当成新按下」或一键绑两动作的重复 | `mv_player.gd`：确认键改成 `_unhandled_input` 收到（没被界面用掉）才记一下，下一个物理帧用掉；走动中、不收输入时按的作废（同原版 `isTriggered` 只在按下那帧为真）。⌘／Alt+Enter 切全屏照旧排除 |
| ③ 淬元丹无法使用 | 淬元丹 2882～2887 数据库效果栏为空，效果全在正式版插件 `js/plugins/Codex_PercentPills.js`（plugins.js 第 172 个、启用）：`hasItemAnyValidEffects`、`applyItemUserEffect`、`Game_Actor.param` 三个包装。重制只移植了它的商店追加（`XItemMarks`），使用部分漏了 → 物品页 `_effective`（testApply）遍历空效果判无效 → 选人后只蜂鸣 | 新 `core/percent_pills.gd`（`XPercentPills`）照插件移植：对象是角色且该种没满 20 颗才有效；吃下计数 +1（存 `state_data._codexPills`，随存档，键名同原版）、刷新、提示「名字 属性 +N%（n/20）」；能力值 `round(min(paramMax, 值×(1+2%×颗数)))`，接在 `XActor.param_before_alien` 里紧贴插件层 `super.param`（插件在 main.js 装各 Codex 运行时之前载入，所以在专属模块等运行时包装之内）。`item_scene.gd` `_effective` 先问淬元丹、`_use` 对每个目标调 `apply` |

①和追加项同根：界面（商店、菜单、对话框）在输入阶段用掉一下按键并关掉，地图这边按「轮询」又看到这一下——菜单键在处理帧轮询（①），确认键在物理帧轮询（追加项），所以分两处修。

不是原版 bug（原版这三处都正常），是移植缺漏／重制自己的问题，所以没加回退开关、没占 O 号。

## 验证

专项（本机，全部通过）：

| 场景 | 内容 | 断言数 |
| --- | --- | --- |
| `xiyou_percent_pills`（新） | 六颗认得出、菜单对单人；物品页真走「使用→选人」：消耗 1、计数 1、能力值 ×1.02、提示文字、别人不变；19→20 颗 +40%；满 20 颗判无效、蜂鸣不消耗、别的种照吃；存读档走 `XSave` 真实写盘读档（测试目录）计数与能力值保留、老存档删掉 `_codexPills` 键读进来计数 0／能力值不加成／照样能吃；发行模式（`ReleaseEntry.simulate_release`）复跑一颗 | 65 |
| `xiyou_shop_exit_menu`（新） | 真地图、事件开店（busy）：键盘 Esc、手柄 B、鼠标右键关店后菜单不开；发行模式 Esc 复跑；关店后正常按 Esc 仍能开菜单 | 14 |
| `xiyou_one_press`（新） | 真地图、真按键（按下→3 帧→松开），键盘、手柄、触屏虚拟键（动作事件，同 `XTouchControls._send_action`）各一遍：调查 NPC 一下出一页对话、出选项前不开店、选「购买武器」只开一次店、商店光标每下挪一格、选「取消」关店后不再调查 NPC；菜单开一次、光标每下一格、进物品页后分类每下一格、取消只退一层回菜单、关菜单后不再开 | 50 |
| `xiyou_key_repeat` | 按住连发节奏照原版（按下触发、24 帧后每 6 帧、系统回显吞掉） | 通过 |
| `xiyou_item_use`、`xiyou_bulk_pills`、`xiyou_key_map`、`xiyou_entry_release` | 相关回归 | 通过 |

- 反向验证（`07_开发环境/反向验证.py`）7 项全咬住：去掉可用判定（＝修前）、去掉吃下计数、去掉能力值包装、去掉 20 颗上限、步长改 3%、去掉关页面记帧（＝修前，`xiyou_shop_exit_menu` 咬住）、玩家改回轮询 just_pressed（＝修前，`xiyou_one_press` 咬住）。
- `选测.py main --list` 选中 420 个（改了 `actor.gd`），走 `云端选测.py run`：云端判整轮 591 个场景（基准取上次云端通过的祖先 `fbb2d9b96`）：提交 `52f59180b`，592 个场景、15 片，591 个通过（`xiyou_star_warehouse` 并行偶发、单跑通过），失败 1 个 `xiyou_tianqi_alien_gear`（`review6_tier_again`／`review6_huaxing_same_again`／`review6_o-off`，天启篇异化词条文案的 O 号开关）。这是本分支基准 `d45643f0b` 上已有的问题，main 已在 `1b4a6fb9f`（合并 cc/tianqi-review-fixes 收尾，手补 `tianqi_alien_gear.gd` 与该专项）修好；本分支没碰天启篇异化装备代码，合并后随 main 一起通过。运行页 actions/runs/43604071774。
- 语法检查 853 个 .gd 0 问题；工具回归全部通过。
- 触屏：虚拟键是 `XTouchControls._send_action`（动作事件），`xiyou_one_press` 用同样的动作事件走了一遍；没有安卓实机测。
- `--oracle`：淬元丹没有现成参照探针（插件逻辑 50 行，按源码逐行移植；数值断言照插件公式），云端整轮里的参照对照场景照跑。

## 变更记录草稿

## 2026-11-14 【cc·未经审查】修玩家反馈：退出商店又开菜单、按一次键响应多次、淬元丹无法使用（dev.待定）

- 退出商店后又自动打开菜单：Esc／手柄 B／触屏「取消」关店的同一帧，地图把这次取消键又当成呼出菜单。事件开的页面（商店等）关掉那帧记下，本帧不开菜单，同关菜单的做法（`map_scene.gd` `_add_scene_page`）。专项 `xiyou_shop_exit_menu`。
- 淬元丹（生命／物攻／物防／魔攻／魔防／敏捷）无法使用：重制只移植了正式版插件 Codex_PercentPills 的商店追加，使用效果漏了。新 `XPercentPills` 照插件补上：每颗该属性永久 +2%，每人每种最多 20 颗，计数随存档。专项 `xiyou_percent_pills`。
- PC 按一次键响应多次：地图上的确认键原来在物理帧轮询「刚按下」，不管这一下是不是已经被商店等界面用掉，关店那一下会再调查一次 NPC（又开对话、又开店）。改成只认真正落到地图上的按下（`mv_player.gd`）。专项 `xiyou_one_press`。
- 玩家可见：关商店不再弹出菜单，也不会又跟商人说上话；淬元丹能对队友使用，属性永久 +2%（每人每种最多 20 颗），吃时有提示。

## 交接板

- 下一步：两处修复如要进 v0.01.09 补丁线，需要摘到 `release/v0.01`（本分支从 main 切出；改动只在 `map_scene.gd` `_add_scene_page`、`mv_player.gd` 确认键、`item_scene.gd` 两处、`actor.gd` 一行与新文件 `percent_pills.gd`，补丁线上这几处代码与 main 相同）。出补丁由 Kyo 点名。
- 用户试玩说明：
  - 商店：到任意商店（如方桌大厅的商人）打开，按 Esc（或手柄 B、触屏「取消」）退出，应直接回到地图，不再弹出菜单；之后再按 Esc 照常能开菜单。
  - 按一次只响应一次：在商店用 Enter（或手柄 A、触屏「确定」）选「取消」退出，应回到地图、不会又跟商人说话；菜单里按一下方向键光标只走一格，物品页按一下取消只退一层。
  - 淬元丹：在卖养血丹的商店（方桌大厅、蜜雪冰城）买一颗「淬元丹·生命」等，菜单→物品→使用→选一名队友，应提示「名字 最大生命值 +2%（1/20）」，状态页该属性变高；同一人同一种吃满 20 颗后再用会蜂鸣、不消耗。存档读档后加成还在。
- 需要用户决定：无。

## 进度账

- 无（修缺漏，不改完成度）

## 可优化（流程／工具／效率）

- 建议：插件备注覆盖（`插件备注覆盖.py`）这次没报出 `<CodexPill>` 的使用部分没移植——它只看标签有没有被读到，商店追加读了标签就算覆盖。可以给「一个插件包了多个原型方法」的情况按方法逐个登记（预计能早发现这类半移植；归工具车道）。

## 本分支提交

- 小A 甲档核查 P3（存读档只做了内存往返）已补：`xiyou_percent_pills` 改走 XSave 真实写盘读档＋老存档缺键，65/65 通过

- 4f686ec87 修淬元丹无法使用：移植 Codex_PercentPills 的使用效果
- 749a48599 修退出商店后又开菜单：事件页面关闭那帧不许地图开菜单
- b54792ebb 专项补发行模式（simulate_release）复跑
- 52f59180b 修 PC 按一次键响应多次：地图确认键只认没被界面用掉的按下
