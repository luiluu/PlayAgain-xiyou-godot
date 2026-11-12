# 交付：claude/project-thread-g23xgd

- 车道／工作者：安卓 v0.01 实机反馈（卡顿、虚拟按键、商店）／cc（云端，项目线程「修复 v0.01 安卓卡顿和虚拟按键」）
- 状态：可合并
- 车道路径：无（云端容器，没有 Mac 工作树；本分支不改切片、转换器、探针，不用同步）

## 变更记录草稿

## 2026-11-12 【cc·云端·未经审查】安卓：原版虚拟按钮当默认、可换改版按键；修选技能和商店的卡顿（dev.待定）
- 起因：Kyo 11-12 用 v0.01（dev.470）安卓实机反馈三件事：战斗里放技能（进战斗、选技能、逃跑）卡，没有改版里能换的虚拟按键，商店买东西卡；附截图与两段录屏。Kyo 补充「把那个没装的虚拟按键定为默认按键」，并发了原版 Mehmet 头像摇杆＋A／B 的截图。
- 虚拟按键（`core/touch_controls.gd`、`modes/xiyou/ui/touch_options.gd`）：照改版二合一包 v0.62.09 的 `Codex_AndroidTouchSettings.js` v0.08 与 `Mehmet_GhostButtons.js` v1.0.3：
  - 默认「原版虚拟按钮」（O-待定-4）：左下头像摇杆（直径 280、中心 (220,540)，外圈白描边、内圈半透黑；摇杆头半径 84，白底红芯，正中画地图主角行走图），右侧灰底绿字圆形 A（确认）、B（取消），平时淡、按下实、松开慢慢淡回；Save 键改成暗底绿字。
  - 「手机按键设置」新增：操作布局（原版虚拟按钮／改版按键）、移动方式（轮盘／方向键）、右侧布局（A／B 两键／原多键：Shift、Ctrl、前页、后页、返回、确认／旧的确定取消跑步）、显示跑步键、方向键大小、地图移动（可点击／仅按键）、战斗点击操作（仅屏幕按键／按键＋点击，默认仅按键，照改版 battleTouch）。原版虚拟按钮时，只对改版按键有用的行显示「—」。
  - 地图（`map/mv_player.gd`）与战斗（`battle/battle_scene.gd` `_gui_input`）按这两项挡掉触屏点按；战斗里消息窗翻页照旧。
- 卡顿：
  - O-待定-1 `ui/mv_canvas.gd`：带闪烁光标的窗口原先每帧整块重画（每帧重跑 painter：商店每帧重算整张商品表和价格、战斗技能窗每帧重算每个技能的消耗冷却），手机上掉帧。现在闪烁光标画在背后一层（`show_behind_parent`，与原先先画光标再画字同序），每帧只重画这一层；内容只在 refresh 时重画。影响所有 `canvas.blink = true` 的窗口（46 处）。
  - O-待定-2 `battle/mv_animation.gd`：动画图、音效原先每次播都 `load()`，上一个动画放掉后要重新读包、解码、传显存；现在按路径留住最近 24 个（`MVAnimation.cached_load`，行动序列的音效也走它）。
  - O-待定-3 `ui/shop.gd`：商店说明卡同一件商品不重新排版，只挪位置。
- 量过但没改（见下「可优化」）：云端逐段计时，一次普攻的规则结算 `XBattleLogic.act` 在电脑上就要 20～80 毫秒（第一次 80），其中 `views()` 全员快照 4～10 毫秒，角色 `mhp` 读一次约 0.2 毫秒（角色能力值不走缓存，每次过整条专属模块包装链）。手机上约慢 5 倍，正好对上录屏里放技能停 0.3～0.5 秒；进战斗出指令窗前、逃跑后各停约 0.75 秒，也还没查到底。
- 新专项 `tests/xiyou_android_perf`（11 项）；`tests/xiyou_platform` 加原版／改版按键 30 项（旧三键那一段用回退开关照旧量）。
- 玩家可见：安卓默认换成原版头像摇杆＋A／B 按键，设置里可换改版按键（A／B 或多键、轮盘或方向键、跑步键）；战斗里默认不再响应点屏幕选目标（可在设置打开）；商店、选技能不再每帧重画，翻动列表应该顺一些。
- 未完成／已知问题：行动结算本身的耗时、进战斗与逃跑的停顿没处理；没有实机，帧率要 Kyo 实机确认。

## 交接板

- 下一步：派规则车道做「战斗结算提速」：角色能力值缓存（要对 mv_oracle 严格对照）、`views()` 快照减少重复计算；再查进战斗出指令窗前、逃跑回地图各约 0.75 秒的停顿（录屏 11-12）。
- 用户试玩说明：安卓上看默认按键是不是原版样子；设置→手机按键设置里切改版按键、方向键、跑步键；商店上下翻、选技能是否顺了；战斗里点屏幕不再选目标（可改「战斗点击操作」）。
- 需要用户决定：是否作为热更推给玩家（Kyo 另说）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/ui/mv_canvas.gd` `XMVCanvas.BLINK_FULL_REDRAW`；`tests/xiyou_android_perf.gd` | 重制原先：活动窗口光标闪烁时每帧整块重画内容（原版 MV 只改光标精灵透明度，内容位图不重画） | 光标画在背后单独一层，每帧只重画那层 | Kyo 11-12 安卓实机商店、选技能卡；更接近原版画法 | `XMVCanvas.BLINK_FULL_REDRAW = true` | cc（云端） | 保留 |
| O-待定-2 | `modes/xiyou/battle/mv_animation.gd` `MVAnimation.RES_CACHE`、`cached_load`；`battle/sequence_player.gd`；`tests/xiyou_android_perf.gd` | 原版动画图载入后留在 ImageManager 缓存；重制原先每次 `load()`，没人引用就丢 | 按路径留住最近 24 个动画图／音效 | Kyo 11-12 安卓放技能卡 | `MVAnimation.RES_CACHE = false` | cc（云端） | 保留 |
| O-待定-3 | `modes/xiyou/ui/shop.gd` `XShop.HELP_SAME_SKIP`；`tests/xiyou_android_perf.gd` | 重制原先：商店每次按键都重排说明卡 | 同一件商品不重排，只挪位置 | Kyo 11-12 安卓商店卡 | `XShop.HELP_SAME_SKIP = false` | cc（云端） | 保留 |
| O-待定-4 | `core/touch_controls.gd` `XTouchControls.MODERN_DEFAULT`；`modes/xiyou/ui/touch_options.gd`；`map/mv_player.gd`；`battle/battle_scene.gd`；`tests/xiyou_platform.gd` | 改版二合一包默认「改版按键」（A／B 两键）、可选原版虚拟按钮；重制 v0.01 只有确定／取消／跑步三键 | 默认原版虚拟按钮（Kyo 11-12 指定），改版按键各项可选，战斗点击默认关 | Kyo 11-12「把那个没装的虚拟按键定为默认按键」 | `XTouchControls.MODERN_DEFAULT = false` | cc（云端） | 保留 |

## 进度账

- 安卓扩展账：虚拟按键「原版按钮样式、方向键模式、地图点击移动、战斗点击、A／B 两键、跑步键」由没做改为已做（后台挂机、战力显示在别处）。

## 可优化（流程／工具／效率）

- 建议：战斗结算提速（规则车道，要 oracle 严格对照）：角色 `param` 每次读都过整条专属模块包装链、不走 krz 缓存（敌人走），一次读约 0.2 毫秒；`views()` 每条命中记录都重算行动者和目标的快照。预计每次行动省一半以上耗时。
- 建议：给 `tests/` 加一个战斗逐帧计时的探查场景（本轮临时写过 `zz_prof_battle`，没留），以后量安卓卡顿可直接跑。
- 已做：云端用 workflow_dispatch 在本分支触发云端选测，不推 `ci/` 分支。

## 验证

- 本地（云端容器，Godot 4.7.2，产物 `/mnt/project-files/云端测试/generated.tgz`）：`xiyou_android_perf` 11/11、`xiyou_platform` 146/146、`xiyou_ui_input` 25/25、`xiyou_map_hotkeys` 36/36、`xiyou_version_label` 6/6。
- 云端选测（GitHub Actions workflow_dispatch，提交 756a4c49，基准 origin/main）：选中 160 个场景、5 片全过。运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/43131135815 。之后只加了交付单。
- 本地另跑 `xiyou_shop_buy`、`xiyou_shop_stock`、`xiyou_options_basic` 会挂，换回 main 的代码同样挂（容器里的产物打包比 main 旧），属环境差异；云端用 main 快照都过了。
- `工具回归.py`：只有「选测替身与 检查.sh 解析」一项失败，是已知的云端环境差异（上一个云端车道交付单也记过）。

## 待交叉核查

- 甲档：`ui/mv_canvas.gd`（光标层，影响所有闪烁窗口）、`battle/mv_animation.gd`（资源缓存）、`battle/battle_scene.gd`（战斗点按挡）。
- 乙档：`core/touch_controls.gd`、`ui/touch_options.gd`、`map/mv_player.gd`、`ui/shop.gd`、测试。

## 本分支提交

- 8367e47 WIP：原版虚拟按钮默认、闪烁光标不整块重画、动画资源缓存、商店说明卡不重排
- 756a4c4 圆键类型标注；性能专项取不重名的动画图
- （本提交）交付单
