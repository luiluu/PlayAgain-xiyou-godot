# 交付：luiluu/cc-t307-ui-card-o

- 车道／工作者：T307 新界面卡 O：名单版型（进阶、修炼场、技能遗忘）＋版型二通用件（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T307·未经审查】新界面卡 O：版型二「名单页」通用件＋进阶、修炼场、技能遗忘新布局（dev.待定）

- 依据：私密设计仓 T254 剩余页细节设计第〇节、3.0「版型二」、3.10 进阶、3.11 修炼场、3.12 技能遗忘、实现卡表「卡 O」行；未决问题 5AB-5（修炼场八项平时收起、Y／点牌底展开）、5AB-6（菜单名单不显示 TP）按推荐默认做。卡 I 通用件（确认弹窗、面包屑）只用不改。
- 版型二通用件 `ui/skin/skin_roster_page.gd`（XSkinRosterPage，新，extends XSkinTemplatePage）：左名单（宽 360：头像、名字、小字 Lv、行尾一句）、中块（模板页列表，或页面自画 `center_draw`）、右牌（宽 336），20:9 左贴左、右贴右、中间居中不拉宽；名单不是焦点时当前那一行名字改旧金；右牌底「展开 ▾」条（整条可点、Y 键同样切换）；中间列表面包屑；统一确认弹窗；行走图／侧视战斗图画法（纹理留引用，不画成白块）。接口见下「给后续卡」。
- 进阶（`ui/actor_advanced.gd`）：左名单「进阶 n / N」（到顶「已到顶」灰字）；中块法阵上的侧视战斗图（照旧 0,1,2,1 每 12 帧）、名字、Lv、职业、「进阶 ◆◇◇ 1 / 3」、现在的能力八项、进阶后学会（三招以上两列，130% 字号时小人上收）；右牌「要求」清单（✓ 绿 ✗ 橙、持有 / 需要），缺项一直写着「还差：…」（字取 XAdvance.missing，同旧提示），主按钮「进阶」（旧底部窗：名单确定后焦点落到这枚按钮，状态机 list → bottom → confirm 一行不改）；确认窗换统一确认弹窗（标题＝旧确认窗字，正文列这次扣的东西）；已满右牌只写「已达最大进阶次数」、按钮变灰。云裳：要求列等级、人道意志碎片、天衣 n / N（照 XYunshangOrders.requirements），两行小字进右牌；按进阶后中间换天衣列表逐件选（面包屑「进阶 › 选天衣」，旧 XYunChoicesWindow 不开）。五条悟：试炼一行 ✓／✗；只缺试炼时主按钮写「挑战试炼」。
- 修炼场（`ui/training_scene.gd`）：左名单＝队员目录；中间列表一行「名字、每级 +N、第 N 级、行尾下一级费用」，修满的变灰写「修满了」，天启篇本层没开到的写「本层开到 N 级」（橙）；右牌只写这次会变的那一项「现值 → 练完 ▲差」（临时把等级加 1 读能力值再还原，和真练完一致）＋下一级费用＋主按钮「修炼」；八项平时收起，Y 或点牌底「展开八项 ▾」展开。目录确定直接进列表（少一层底部「修炼」窗），列表确定就修，取消回目录；提示照旧走 XToast。
- 技能遗忘（`ui/forget_skill_scene.gd`）：版型一不画环（借 XSkinRosterPage、左块不放名单）：左块这个角色的像素小人（3 倍）＋名字；中间列表图标、名字（品质色）、小字类型、行尾「记着」／「已遗忘」（橙）；右牌技能说明＋「遗忘了会怎样」，主按钮跟着写「遗忘」／「记回来」。确定翻转不退出、按住连续翻、Q／E 翻页、滚轮、取消关闭全是旧代码。
- 回退：`XSkinRosterPage.ENABLED = false`（卡 O 一个开关，三页一起回旧页）；西游存档、`XUiSkin.ENABLED = false` 本来就是旧页。三页的新界面都是「旧窗藏起、旧状态机不动、新页按状态重画」，旧专项（含新皮肤开着跑的 xiyou_gojo_trials、xiyou_list_pager）不用改。
- 测试：新专项 `tests/xiyou_ui_skin_card_o`（无头 124 项、带窗口 214 项含 45 张截图）；`tests/xiyou_ui_skin_offshot` 加 `PAGES_O`（进阶、修炼场），皮肤关闭对照从此覆盖这两页（技能遗忘要先 setup 角色，offshot 的 `_make` 建不了，由新专项的开关段核旧页）。
- 玩家可见：天启篇里进阶、修炼场、技能遗忘换成新界面：进阶缺什么一直写在右边牌上，修炼场直接看到这次能涨多少，技能遗忘能看技能说明。
- 验证：见下「验证」。
- 未完成／已知问题：见「没做／偏离」。

## 验证

- 选测（`选测.py main --list` 列出的 23 个全跑，另加 `xiyou_advance_reads`）：24 个场景全部通过（670 秒，并行 2，无偶发；结果记在 e18f0e6fe 名下）。含新皮肤开着跑旧页的 `xiyou_gojo_trials`、`xiyou_list_pager`（训练目录、遗忘翻页件）一条没改照样过。
- `工具回归.py` 全部通过。
- 新专项 `xiyou_ui_skin_card_o`：无头 124/124；带窗口 214/214（含 45 张截图的真尺寸断言：800×450／1000×450）。（初交 111/194，小A核返修后加 13 项。）
- 皮肤关闭对照：`python3 07_开发环境/皮肤关闭对照.py --base github/main`（0c4c6a194）跑了 3 次：第 1 次 49/50 有 1 张不同（没留下是哪一张，输出被 tail 截掉了），第 2、3 次 50/50 全 SAME（含新加的西游／天启关皮肤 × 进阶、修炼场 4 张）。我猜第 1 次是偶发，没查实。
- `语法检查.py` 0 问题。
- 截图：[luiluu_cc-t307-ui-card-o](../归档/交付截图/luiluu_cc-t307-ui-card-o)（新页每张 16:9 800×450＋20:9 1000×450；旧画法对照只有 16:9，旧页不铺横屏）：
  - 进阶：条件不够 `adv_lacking`、焦点在主按钮 `adv_bottom`、条件够了 `adv_ready`、确认弹窗 `adv_confirm`、名单一屏放不下 `adv_full_roster`、五条悟只缺试炼 `adv_gojo`、云裳选天衣 `adv_yun_pick`、字体 130% `adv_font130`／`adv_gojo_font130`、旧画法 `adv_old_16x9`。已到顶（灰字「已到顶」）在每张进阶图的名单第 3 行。
  - 修炼场：目录上 `tr_roster`、列表上 `tr_list`、八项展开 `tr_expanded`、修满了 `tr_full`、字体 130% `tr_font130`、旧画法 `tr_old_16x9`。
  - 技能遗忘：常态 `fg_normal`、已遗忘一行 `fg_forgotten`、翻到第 2 页 `fg_paged`、空列表 `fg_empty`、字体 130% `fg_font130`、旧画法 `fg_old_16x9`。

## T254 对应表逐行断言（新专项里的名字）

- 3.10 进阶：名单名字／Lv／头像 `adv_roster_names`、行尾进阶次数 `adv_roster_rank`、到顶灰字 `adv_roster_top_gray`；旧状态窗用 RecCanvas 画一遍收字，逐角色核 名字 `advN_name`、等级 `advN_level`、进阶次数 `advN_rank`、最大进阶次数 `advN_max`、八项 `advN_params`、战斗图 `advN_battler`、需求物品与 xN `advN_items`、等级需求 `advN_need_level`、金钱 `advN_gold`、进化技能 `advN_learn`、已满 `advN_full`；还差一直写着 `advN_lack_always_shown`、主按钮 `advN_button`、✓／✗ `advN_checks_marks`；底部 → 主按钮焦点 `adv_bottom_focus_card`、条件不够提示 `adv_fail_toast`、确认弹窗 `adv_confirm_dialog`、进阶完成 `adv_done`、弹窗取消 `adv_confirm_cancel`、触屏主按钮 `adv_touch_button_confirm`、金钱窗→右上货币（截图）。
- 云裳：`yun_req_robes`（等级、碎片、天衣 n / N、两行小字）、`yun_center_list`（中间列表＋面包屑、旧选择窗不开）、`yun_labels_same`（天衣行字＝旧选择窗的行）、`yun_pick1`、`yun_dialog`、`yun_same_result`（新旧两条路选同样三件，进阶结果、碎片、剩下的天衣、提示全一样）、`yun_cancel`。
- 五条悟：`gojo_trial_line`、`gojo_button_trial`、`gojo_confirm`（弹窗标题＝「挑战试炼「怀玉」」）、`gojo_request`、`gojo_trial_passed`、`gojo_no_trial_in_shop`。
- 3.11 修炼场：`tr_roster`、`tr_rows_from_lines`（每行名字、等级、费用都在 XTraining.line 的旧行文里）、`tr_classic_rows`（西游表同样核）、`tr_eight_folded`、`tr_into_list`、`tr_change_line`＋`tr_preview_matches`／`tr_classic_preview`（预览值＝真练完）、`tr_train`、`tr_stays_in_list`、`tr_y_expand`（八项全在）、`tr_strip_collapse`、`tr_cancel_to_roster`、`tr_not_open_row`、`tr_full_row`、`tr_full_card`、`tr_close`。
- 3.12 技能遗忘：`fg_rows`、`fg_card_button`、`fg_toggle`（翻转不退出、行尾橙「已遗忘」）、`fg_card_recall`、`fg_hold_repeat`（按住连发）、`fg_move`、`fg_page`（Q／E）、`fg_touch_button`、`fg_close`、`fg_empty`。
- 开关：`gates`（西游存档／天启篇 × 开关开／关，三页 skin 与旧窗显隐）、`old_adv`、`old_tr`、`old_fg`。

## 给后续卡（版型二：名单页 `XSkinRosterPage`）

`ui/skin/skin_roster_page.gd`，extends XSkinTemplatePage。三页都用「旧页状态机不动、旧窗藏起、新页按状态重画」的套法：

```gdscript
var skin: XSkinRosterPage
# _ready（旧窗建好之后、第一次 _refresh 之前）：
if XUiSkin.on() and <你的卡的开关>:
    skin = XSkinRosterPage.new()
    skin.title = "页名"
    # skin.show_roster = false; skin.focus = "list"   # 版型一不画环、左块自画（技能遗忘）
    # skin.currencies = []                            # 默认 null＝右上写精魂
    add_child(skin)
    skin.roster_changed.connect(...); skin.roster_activated.connect(...)
    skin.card_button.connect(...)
# _refresh 末尾：if skin != null: _skin_sync()   # 里面先把旧窗 visible = false
# _unhandled_input 开头：if skin != null and skin.input(event): XKeyMap.handled(self); return
# _gui_input：有新页时只接右键＝取消，其余 return（点击由各组件自己接）
```

- 名单：`set_roster(rows, index)`，行用 `XSkinRosterPage.roster_row(actor, 行尾字, 行尾色)`（头像、名字、小字「Lv N」、行尾 right2；不画 TP、量条，5AB-6）；`roster_changed(i)`（换行，同步时不发）、`roster_activated(i)`（点当前行）。名单不是焦点时当前行名字自动改旧金。`roster_title` 可给名单面板加一行旧金小标题（默认空）。
- 焦点：`set_focus("roster" | "list" | "card")`；名单 `roster`（XSkinList）、中间 `list`（模板页那张）、右牌 `card` 都是现成组件，`handle_input` 照用。
- 中块自画：`center_draw = func(ctrl: Control)`，`show_center_list(false)` 显示自画层（`center_view`，要动画就每隔几帧 `center_view.queue_redraw()`）；`show_center_list(true)` 回列表。
- 左块自画（不放名单时）：`show_roster = false`（`_ready` 前设）＋`left_draw = func(ctrl: Control)`。
- 面包屑：`set_crumb(["进阶", "选天衣"])` 列表整体下移一行；`set_crumb([])` 收起。
- 右牌底展开条：`set_strip("展开八项", open)`（空字＝不显示）；点这一条或按 Y 发 `strip_toggled(新状态)`，页面改自己的状态后重画牌。
- 确认弹窗：`ask({title, body, buttons, danger, index})` 返回 XSkinConfirm（第一次建时页面接 chosen／index_changed／cancelled），`close_dialog()` 收掉；弹窗开着时 `input()` 把按键全交给它。
- 画像素：`XSkinRosterPage.draw_walker(ci, characterName, characterIndex, 脚底, 整数倍)`、`draw_battler(ci, battlerName, 格 0～2, 脚底, 最高)`、`draw_seal(ci, 中心, 半径)`；纹理经 `keep_tex` 留在静态表里（T304 卡 M 的白块坑）。
- 开关 `XSkinRosterPage.ENABLED` 是卡 O 的；别的页套用时另设自己的开关。

## 文字（玩家可见，新写的都是草稿，待小A 审）

- 进阶：
  - 页名「进阶」；名单行尾「进阶 n / N」「已到顶」；中块「Lv N　职业」「进阶 ◆◇◇ n / N」、节名「现在的能力」「进阶后学会」、没有学的写「无」；八项能力名沿用旧页（生命、魔法、力量、物防、智力、魔防、敏捷、幸运）。
  - 右牌：节名「要求」；行「✓／✗ 物品名」「✓／✗ 等级」（右「Lv a / b」）「✓／✗ 精魂」（取系统货币单位）、云裳「✓／✗ 人道意志碎片」「✓／✗ 天衣」，五条悟「✓／✗ 试炼：怀玉（已通过／未通过）」（旧字前加 ✓／✗）；「还差：」＋旧缺项字；主按钮「进阶」「挑战试炼」；已满「已达最大进阶次数」（旧字）。
  - 确认弹窗：标题沿用旧确认窗（「是否进阶」「挑战试炼「X」」「消耗N件天衣，确认进阶」），正文新写「消耗：魂灯 ×1、精魂 100,000」，按钮「确定」「取消」。
  - 云裳选天衣：面包屑「进阶 › 选天衣」，列表标题＝旧选择窗第一行「选择进阶所需天衣 n/N」。
  - 按键提示：「进阶」「离开」「返回」「选这件」「切换」「选择」。
- 修炼场：
  - 页名「修炼场」；列表标题「修炼项」；行「每级 +N」（天启篇「每级 +1%」）「第 N 级」「修满了」「本层开到 N 级」、费用「N万」（旧行文同款）。
  - 右牌：牌头小字「角色名 · 修炼 N / M 级」；节名「这次修炼」，行「能力名　现值 → 练完 ▲差」「下一级费用」（右值「N万 精魂」，列表行尾仍「N万」放得下），天启篇另一行「全队X +1%」（旧行文那一段）；修满「修满了」；本层没开到「本层只开放到 N 级（每 3 层开 1 级）」（旧提示原文）；展开节名「八项能力」（能力名沿用旧页：生命、魔法、物理攻击…）；主按钮「修炼」；展开条「展开八项 ▾」「收起八项 ▴」（键盘时前面带「Y」）。
  - 按键提示：「选修炼项」「修炼」「展开八项」「收起八项」「离开」「返回」。
- 技能遗忘：
  - 页名「技能遗忘」；列表标题＝角色名；行尾「记着」「已遗忘」；空列表「没有可以遗忘的技能」。
  - 右牌：节名「说明」「遗忘了会怎样」；记着时「遗忘后不能再使用这个技能，如果它带有被动效果也会暂时失效；随时可以再来记回来。」，已遗忘时「已经遗忘，现在用不了，如果它带有被动效果也已失效；点「记回来」就能恢复。」（以上按小A文字审改）；牌头小字类型后加「已遗忘」；主按钮「遗忘」「记回来」。
  - 按键提示：「遗忘 / 记回来」「翻页」「离开」。

## 没做／偏离

- 云裳的「要求」照 XYunshangOrders.requirements 列真实条件（等级、人道意志碎片、天衣），**不再列**旧状态窗里进阶表那一行的物品、等级、金钱：云裳进阶不走那一行（不扣物品、金钱，见旧页头注释），旧页那几行是摆着看的、会误导。对应表「旧页每项新页都取得到」在云裳这一格是有意偏离，请核查方看一眼。
- 修炼场的「目录确定 → 底部「修炼」→ 修炼项」在新页少了中间一层（稿写的）：新页 mode 从 index 直接到 list，取消从 list 直接回 index；旧页照旧三层。
- 修炼场右牌「这次修炼」的练完值是临时把等级加 1 读能力值再还原（不在战斗里，能力值不走缓存）；会不会被别的被动缓存挡住没有全量查，专项里天启篇和西游表各核了一次＝真练完的值。
- 技能遗忘不进 `xiyou_ui_skin_offshot`（要先 setup 角色），旧页由新专项 `gates`、`old_fg` 核。
- 旧画法对照只拍 16:9（旧页不铺横屏）。
- **合并冲突（协调定 B）**：已 merge github/main（cdd47586c）无冲突；交付自检对本机 main（2ad519a18，含未推送的卡 M T304 合并）报唯一冲突在 `tests/xiyou_ui_skin_offshot.gd` 循环行。解法：两边都留，写成 `for cls in PAGES + PAGES_K + PAGES_M + PAGES_O:`（`PAGES_M`、`PAGES_O` 两个常量都留；卡 M 的 `XHangUpSubPage` setup 分支照留）。
- 「遗忘了会怎样」两句已按小A文字审改。

## 小A核返修（T307 r1，P1×0）

- P2-1：`skin_template_page.gd`（共用件，只加判断）`_process` 列表藏起时不再 `pager.set_state`、翻页件藏起；`_draw_list_panel` 列表藏起时不画页脚。云裳带 ≥12 件天衣进选天衣再取消，翻页件不再叠在立绘上（用例 `yun_many_pager_on`／`yun_many_pager_hidden_after_cancel`，截图 `adv_yun_cancel_back`）。
- P2-2：饿狼（173）单列真实条件（等级、累计突破 n / N、四臂进星空的神之触媒），不列精魂；确认正文只在 5→6 写「消耗：神之触媒 ×1」。缺项改走 `XActorAdvancedScene.lack_of`：饿狼只认 `XGarou.reason`。**注意这也改了旧页**（同一个底部确定分支）：天启篇金钱重构给饿狼每行也套了进阶金钱，`XAdvance.missing` 会报「精魂不足」把饿狼挡住，而 `XGarou.advance` 本来不扣钱；西游存档里饿狼表行金钱为 0、物品只有星空的神之触媒，和 reason 查的一样，旧页行为不变。用例 `garou_*` 6 项，截图 `adv_garou_lacking`。根上 `XAdvance.row` 对饿狼套天启篇进阶金钱不是本卡文件，没动。
- P2-3：`_place_targets` 加上展开条高度后把目标列表重摆到条上面（用例 `strip_targets_no_overlap`）。
- P3：修炼预览只读（money 节原来没有就读完连节删掉，用例 `tr_preview_readonly`）；本层没开到、精魂不够时修炼主按钮置灰（按确定照旧出原提示），点灰钮蜂鸣（名单页通用件统一做，进阶页同样）（用例 `tr_not_open_button_gray`）。
- 文字按小A 审：云裳确认弹窗标题新页写「消耗 3 件天衣，确认进阶」（旧确认窗字不动，xiyou_yunshang_shop 参照比它）；修炼牌头、费用、全队一行、遗忘两句见上「文字」。
- 返修后实跑：`xiyou_ui_skin_card_o`、`xiyou_gojo_trials`、`xiyou_list_pager`、`xiyou_actor_advanced`、`xiyou_training`、`xiyou_yunshang_shop`、`xiyou_ui_skin_card_e`／`card_j`／`card_k`／`card_l`、`xiyou_ui_skin_shop`、`xiyou_ui_skin_1b`／`1c`／`5c`、`xiyou_ui_skin_offshot` 15 个场景全部通过（132 秒）；皮肤关闭对照 50/50 全 SAME。
- 卡 M、N 的专项不在 github/main 上，本树跑不了；模板页这处判断请总装合并时随卡 M、N 专项一起看。

## 交接板

- 下一步：卡 O 合并后，版型二名单页可供别的「左名单＋中间角色」页套（交付单「给后续卡」）。
- 用户试玩说明：天启篇存档里找奉神老妪进阶、魔塔教师修炼、用遗忘河之水，看三页新界面；设置里界面风格选「原版」回旧页。
- 需要用户决定：无（5AB-5、5AB-6 按推荐默认做）。

## 进度账

- 新界面第 5 批（5A／5B 功能页）：卡 O 三页（进阶、修炼场、技能遗忘）完成。

## 可优化（流程／工具／效率）

- 建议：`皮肤关闭对照.py` 有不同时把不同的文件名单独打一行到末尾（现在混在几十行 SAME 里，tail 截掉就看不到是哪张），归工具车道，几分钟的事。

## 本分支提交

- 0ac9ea8a5 小A核返修（P2-1～3、P3、文字）

- d116c68d9 WIP：XSkinRosterPage＋三页新界面、新专项
- e18f0e6fe WIP：面包屑进通用件、云裳要求照真实条件、130% 中块上收、修炼行尾放费用、offshot 加 PAGES_O
- b34a18198 交付单、交付截图
- 合并 github/main（cdd47586c）
- （本提交）交付单补冲突解法
