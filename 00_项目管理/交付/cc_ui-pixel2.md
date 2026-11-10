# 交付：cc/ui-pixel2

- 车道／工作者：B 界面／白龙（cc，派单第十七批追加三 GF5；临时 clone 车道，见文末）
- 状态：可合并
- 车道路径：/private/tmp/claude-501/-Users-kyo-Documents--------/d69e8956-96f5-4de6-84f3-981810e9ecac/scratchpad/uipx2

## 变更记录草稿

## 2026-11-10 【cc·白龙·未经审查】界面像素对照二期：一期没配上的 5 个矩形认定；养成页 71 态对照；宠物技能卡不带品质框、窗口宽高向上取整（dev.待定）

- 一期没配上的 5 个矩形都查清了，没有新的真差，改成配对规则里的「已认定」（`ui_pixel_compare.py` 的 `KNOWN` 表：按原版类型、Godot 类型、四边差逐条认定并写原因，差值对不上照旧列为没配上）：
  - 物品页、商店的 `Window_ItemHelp`（2 个）：原版品质框是单独的窗口，Godot 画成说明卡的子节点 `frame`，一期的读数没收它。现在读数把框记成 `XHelpCardFrame`，四边差和卡本体一样。
  - 物品页、商店的 `Sprite_ItemHelp`（2 个）：x−6 是 O-008 贴行放，高＋2 是 O-007 最小字号，都已登记。
  - 状态页参数窗：战力先藏（Kyo 11-08）让出 36 像素。`xiyou_ui_pixel` 加了断言：开战力时参数窗 (0,108,1280,612)，和原版一样。
- 养成页对照：原版 `review_system_pages` 现成的 pets、pet_synth、training、inlay_book、actor_advanced、crafting、magic_level、change_clothes、skill_page、equip_detail、item_detail 共 71 态，对 Godot 各专项 `--out` 的同态截图。新增 `tests/ui_pixel_dump.gd`，各专项截图时顺手写 `<名>.win.json`（窗口全局矩形），`ui_pixel_compare.py` 优先读它，并支持图名通配（如 `'pet_*' 'adv_*'`）。
- 结论（逐张看过热图和成对截图）：
  - 宠物 5 态、修炼、镶嵌 4 态、进阶 11 态、制作 4 态、换装 12 态、技能 2 态、装备详情 4 态、物品详情 1 态：窗口矩形全部配上（技能页说明卡高＋1 是 O-007，把 `MIN_FONT` 设 0 实测为 247，与原版相同，已认定）。剩下的像素差是菜单粒子、角色行走帧相位、光标闪烁相位、彩色字的轻微色差。
  - 成就弹窗和提示条两边都会出现，但弹出、消失的帧不一样（进阶 4 态原版有成就弹窗、Godot 没有；别的几态反过来；进阶失败的提示条 Godot 多留一态）。对照时单列成「时序噪声」，不算差。
  - 法宝三态（magic_*）：`xiyou_system_evidence` 为了对 v0.28 参照，关掉了装备页／物品页的新详情版面，所以和 v0.62.12 的详情窗对不上。这是测试设置问题，新版面由 `xiyou_gear_detail` 对照（equip_detail／item_detail 已配上）。商店说明卡少一行「装备战力」（战力先藏），出售价格 1→0（O-049 写实际卖价），描述换行早一个字（O-007），都是已登记的。
- 修：宠物技能卡不带品质框。原版 `Window_PetSkillList.updateHelp` 先 `setItem`（ItemQuality 建品质框），再 `hide()`（hide 会拆掉品质框），然后 `visible=true`，所以原版宠物技能卡没有框（v0.62.12 实跑 pet_1_skills 只有 Sprite_ItemHelp）。Godot 原来带金框。照原版去掉，开关 `XPetScene.SKILL_CARD_NO_FRAME`（默认开；关＝和物品页一样带框）。不占 O 号。
- 修：窗口宽高向上取整。原版 YEP_CoreEngine 的 `Window._roundWhUp` 每次刷新都把窗口宽高向上取整，制作完成弹窗按文字算出来宽 296.24，原版画成 297，Godot 画成 296.24。`XMVWindow` 照原版取整（留 0.001 余量，浮点误差不算小数），开关 `XMVWindow.ROUND_WH_UP`（默认开）。不占 O 号。
- 取整牵动所有 MV 窗口：宽是 1280/3 这类小数的窗口（挂机设置格子 426⅔→427）现在和原版一样取整；`xiyou_hangup_options` 原本就按 427 断言。
- 测试：`xiyou_ui_pixel` 32 项（新增状态页开、关战力两条，取整和取整回退三条）；`xiyou_pets` 31 项（新增宠物技能卡无框和回退）；`xiyou_gear_detail` 物品页截图前拆掉探针的详情窗（原来叠在物品页下面，会混进读数）。
- 玩家可见：宠物页「查看技能」的说明卡不再有金色品质框（和原版一样）；制作完成弹窗右边宽 1 像素。

## 交接板

- 下一步：界面像素对照还没做的页：种族（race_* 已有读数，要补 Godot 侧同名）、怪物图鉴、星级／角色仓库、整队、成就、设置、存档。照本单的做法：原版 `review_system_pages.js` 有页就直接用，Godot 专项截图点已经会写 `.win.json`，跑 `ui_pixel_compare.py 原版 Godot 输出 '图名*'` 就行。
- 用户试玩说明：宠物页选一只宠物 → 查看技能，看说明卡是不是没有金框了。
- 需要用户决定：无（两处都是照原版改，带开关）。

## 进度账

- 界面页面：88% → 89%（+1）。依据：养成、装备 71 态做了矩形配对和像素差，一期 5 个没配上的都认定了，真差两处已修。进度核定「其余」行「装备、养成像素对照」这部分算做完，「转换只覆盖切片」不动。

## 可优化（流程／工具／效率）

- 已做：`tests/ui_pixel_dump.gd` 让各专项的 `--out` 截图自带窗口读数，后面的页不用再在 `xiyou_ui_pixel` 里重搭场面（回退：删各专项里那一行 `dump` 调用）。
- 已做：`ui_pixel_compare.py` 的 `KNOWN` 已认定表和弹窗噪声单列，热图看完一次的差不用每次重查（回退：清空 `KNOWN`）。
- 建议：Godot 专项和原版的截图名不一致（`training_2_bottom`／`training_bottom`、`技能_列表`／`skill_1_list`、`gear_detail_0N`／`equip_detail_N`），这次手工复制改名。以后可以在 `ui_pixel_compare.py` 里加一张别名表（界面车道，小）。
- 建议：截图模式下关掉菜单粒子、固定行走帧，热图噪声能少一大块（一期已提，界面车道）。

## 验证

- 语法检查通过（661 个 .gd，0 问题）；工具回归全过（63 秒）。
- 本机窗口模式：`xiyou_ui_pixel` 32/32、`xiyou_pets` 31/31、`xiyou_system_evidence` 16/16、`xiyou_training` 188/188、`xiyou_inlay_book` 19/19、`xiyou_actor_advanced` 33/33、`xiyou_crafting` 49/49、`xiyou_skill_page` 27/27、`xiyou_gear_detail` 60/60、`xiyou_change_clothes` 32/32。
- 云端选测（`选测.py main --list` 82 个场景，--no-upload，基准 c16afc841）：第一次 a2dffe962 挂了 `xiyou_hangup_options`（取整后提前 return，窗口不在树里时不再发 resized，挂机设置 1280/3 宽的格子内容区为 0），改成取整后接着排版；重跑 3a0d929ac 82 个全过，2 片、最长 9.4 分钟（Actions run 42771827612）。含 xiyou_battle_ui、xiyou_window_rects、xiyou_help_card、xiyou_pets、xiyou_crafting、xiyou_ui_pixel。选测名单里没有战斗核心类场景。

## 本分支提交

- 本分支从 cc/ui-pixel1 头 d06bcd04b 切出，带着 ui-pixel1 的提交（它的交付单 `cc_ui-pixel1.md` 也在）；ui-pixel1 先合的话这里只剩本期的改动。
- dc8f66d3e 合 main
- f655089d4 一期五个没配上的矩形认定
- a2dffe962 养成页像素对照；宠物技能卡不带品质框；窗口宽高向上取整
- 3a0d929ac 取整后接着排版（修挂机设置）
- （本提交）交付单

## 车道位置

- 本会话在主工作区启动，不能自建 worktree，照 11-07 做法在 scratchpad 里 `git clone --shared`，用主工作区的 `新建工作树.sh --补齐` 补环境，分支推回本库 `cc/ui-pixel2`。clone 留到总装合并完再删。
