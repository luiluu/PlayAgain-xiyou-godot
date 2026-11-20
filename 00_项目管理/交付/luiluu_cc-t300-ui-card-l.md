# 交付：luiluu/cc-t300-ui-card-l

- 车道／工作者：T300 卡 L 设置子页（cc，Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·天启篇·未经审查】新界面卡 L：设置子页六页套版型三（dev.待定）

- 依据：T254 3.7、3.0 版型三。画质、消息提醒、屏蔽掉落、角色换装、导入／导出配置、手机按键六个设置子页，新皮肤开着时不再是 1280×720 的旧窗口，而是设置主页本身：左边分类环不动（高亮进来的那一类，不能点），中间列表换成子页的行，列表标题下一行面包屑「画面 › 画质设置」，右边牌是「名字、现在的值、说明、可选、操作」。子页状态机（index／ok／side／cancel）一行没动，键盘仍由各子页自己的 `_unhandled_input` 处理；新件只画并接鼠标／触屏（点非当前行选中、点当前行确定、右键取消）。
- 新通用适配层 `ui/skin/skin_sub_page.gd`（`XSkinSubPage`，套 `XSkinTemplatePage`）：子页提供 `skin_rows/skin_card/skin_name/skin_cat/skin_hints/skin_bars/skin_empty/skin_button`（鸭子类型，缺的用默认），按帧比一下内容、变了才重排。接口见下「给后续卡」，卡 M（挂机子页）直接用。
- 各页：
  - 画质：行＝名字＋行尾当前值（默认档灰、改过金）；右牌说明＝旧说明，「可选」列全部档并标「现在」「默认」，窗口大小只在桌面、像素柔边／顺滑移动／字体两行的回退开关照旧；
  - 消息提醒：9 行，开 `GOLD_LIGHT`、关 `TEXT_2`；左关右开、确定切换；
  - 屏蔽掉落：行名「屏蔽 普通 装备」，行尾 关／开／部分；右牌写「部分」是什么；
  - 角色换装：行＝头像、名字、小字换装卡名（超宽省略号）、行尾启用（绿）／关闭；完整卡名在右牌折行写全；空列表中间一句；
  - 导入／导出：五行；校验结果、导出结果写进右牌「结果」；等确认时那一行行尾写「待确认」，右牌底出现主按钮「导入这 N 项」（点它＝导入；键盘规则不变：同一行再按一次确定），按别的行、上下移动、取消都作废；撤回没有备份时变灰、行尾写「没有可撤回的」；
  - 手机按键：行尾百分比旁 80×6 细条（位置）；对当前布局没用的行变灰、值写「—」；恢复默认走统一确认弹窗（橙边、停在「取消」）；调整位置进拖动态时整页淡出（动效关＝立刻），XTouchControls 自带的按钮栏挪到上沿正中，完成后淡入。
- 设置主页 `options_scene.gd:_open_page_skin`（总装准了）：子页声明 `skin_self_hosted()` 为真时不套 1280×720 外框、不藏底，整屏铺满（20:9 用 XSkinLayout）；挂机设置、测试模式等别的子页一行不变（专项断言开关新皮肤前后一致）。
- 测试：新专项 `tests/xiyou_ui_skin_card_l`（有窗口 269 项含截图；无头 213 项）：六页旧页每一项（行名、值、说明、可选档、颜色）逐行断言、点行／键盘／取消、环同类不可点、面包屑、设置主页进子页不套外框且环跟主页、挂机／测试模式开关新皮肤前后一致、手机按键细条／灰行／恢复默认弹窗／拖动态淡出与按钮栏位置／键盘不穿透、导入待确认按钮与作废、空列表、开关回退与西游存档旧画法。`xiyou_ui_skin_5c` 里「子页套外框」那条断言改成：自带新皮肤的子页直接加在设置页上、挂机仍套外框（89/89）。选测另跑 text_batch23_shots、xiyou_battle_options／config_transfer／costumes／crisp_scale／font_size／graphics_options／hangup_options／list_pager／list_paging／map_hotkeys／notice_options／options_basic／options_misc／party_formation／platform／power／power_hidden／test_mode／tianqi_ring_style／ui_sel_scale／ui_skin_5c／ui_skin_card_e／ui_skin_offshot／whats_new／transfer_touch／ui_skin_shop 全过；`xiyou_event_compare*` 四个没跑（与设置子页无关，留总装选测）。皮肤关闭对照（`--base 10583c7d5`，带 `--audio-driver Dummy`）34 张全 SAME；工具回归、语法检查过。
- 截图：[luiluu_cc-t300-ui-card-l](../归档/交付截图/luiluu_cc-t300-ui-card-l)，专项断言真尺寸（16:9＝800×450、20:9＝1000×450，每张 `shot_size_*` 断言）。页：画质（常态、选帧率、字体 130%）、消息提醒（常态、关一项）、屏蔽掉落（常态、选中二）、角色换装（常态、无卡）、导入导出（常态、待确认、错误）、手机按键（常态、选透明度、灰行、恢复默认确认、拖动态，拖动态 16:9＋20:9 各一）、设置主页进画质（常态，分类＝画面）、旧画法对照（画质）。常态页 16:9＋20:9 各一，其余状态只拍 16:9。
- 开关：`XSkinSubPage.ENABLED = false` 六页全回旧窗口；西游存档、界面风格选「原版」、`XUiSkin.ENABLED = false` 本来就不建新页。
- 玩家可见：天启篇里设置的画质、消息提醒、屏蔽掉落、角色换装、导入／导出、手机按键六个子页换成新界面，右边牌里直接看到这一项的说明和所有可选档。

## 没做／偏离

- 稿「恢复默认走统一确认弹窗」「拖动态只留一枚「完成」胶囊」：按钮栏用的是 XTouchControls 自带的（「恢复位置」＋「完成」两枚，在 `core/touch_controls.gd`，不是独占文件），只把它挪到上沿正中；要只留「完成」一枚得改 core，没动，请定。
- 稿「一屏 11 行」：模板页列表头 56＋翻页脚 44 算下来每页 10 行（面包屑占了列表头里一行，没多占行高）；手机按键 15 行滚动，有翻页脚。
- 稿「焦点：被选中时灰行字提到 #c9cbd0」：灰行（手机按键）鼠标点不中（XSkinList 对 disabled 行不响应点击），键盘照旧能落在上面；没动 skin_list.gd。
- 右牌「可选」里的小字比正文小（XSkinCard 的 lines 样式），字体 130% 时仍偏小，见截图。
- 新增超出独占的文件（总装准了）：`ui/options_scene.gd`（`_open_page_skin` 加 14 行）、`ui/skin/skin_sub_page.gd`（新）；顺带改 `tests/xiyou_ui_skin_5c.gd` 一条断言。

## 交接板

- 下一步：卡 M（挂机设置及子页）可开：用 `XSkinSubPage` 套挂机设置，`options_scene._open_hang_up`／`_open_page_skin` 里挂机页现在仍走旧外框，M 实现 `skin_self_hosted()` 后自动走新路。
- 用户试玩说明：天启篇存档进设置 → 画面「画质设置」、常规「消息提醒」「屏蔽掉落」「角色换装」、其他「导入／导出配置」、挂机与操作「手机按键设置」：右边牌里有说明和可选档；手机按键「调整位置」时页面淡出、上沿只剩按钮栏。
- 需要用户决定：无（稿里未回的默认题按稿默认做）。

## 进度账

- 新界面第 5A／5B 批：卡 L 设置子页六页完成。

## 可优化（流程／工具／效率）

- 建议：`tests/xiyou_ui_skin_offshot.gd` 的 PAGES 再加 XCostumesScene／XConfigTransferScene／XTouchOptionsScene（本单测试文件不在独占范围，没动；画质、消息提醒、屏蔽掉落三页原来就在，对照过）。

## 本分支提交

- 见 `git log`

## 给后续卡（接口）

`XSkinSubPage.attach(owner)`：owner 是子页场景（Control，在树里）。owner 要有 `index`、`select(i)`、`ok()`、`cancel()`、`closed` 信号，再提供（缺了用默认）：

| 方法 | 作用 |
| --- | --- |
| `skin_self_hosted() -> bool` | 返回 `XSkinSubPage.wanted()`；设置页据此不套外框 |
| `skin_rows() -> Array` | 行字典（同 XSkinList：text、right、right_color、sub、icon、disabled…） |
| `skin_card(i) -> Dictionary` | 右牌（同 XSkinCard.setup：title、subtitle、desc、sections、buttons） |
| `skin_name()` / `skin_cat()` | 子页名（列表标题、面包屑最后一段）；单开时环上高亮哪一类（`XSkinOptionsPage.CATS` 的键，其他＝`other`） |
| `skin_hints() / skin_bars() / skin_empty() / skin_button(i)` | 按键提示；每行 0～1 细条（-1 不画）；空列表一句；点牌上按钮 |

- 小工具：`XSkinSubPage.choices_section(labels, 现在序号, 默认序号)`（右牌「可选」一节）、`on_color(开?)`、`fade_out()/fade_in()`。
- 用法：子页 `_ready` 末尾 `if XSkinSubPage.wanted(): oldwin.hide(); skin = XSkinSubPage.attach(self)`；`_gui_input` 里 `if skin != null: return`（点击由列表接）。键盘仍由子页自己处理。
- 主页的环取自 `XSkinOptionsPage.cats／cur`；`XSkinOptionsPage.draw_cat_name(ring, 名字)` 抽成了静态。

## 文字

玩家可见新字，待小A 审：
- 面包屑：「分类名 › 子页名」；右牌小节名「可选」「操作」「结果」「说明」「「部分」是什么」；标「现在」「默认」；
- 画质操作句：「改了立刻生效并保存。确定换到下一档，左右各走一档。」（旧说明里「灰色是默认档」换成「默认」标）；
- 消息提醒按键提示「关／开」；屏蔽掉落：「屏蔽 X 装备」行名、「「部分」：这一档里有的品质屏蔽、有的没屏蔽。确定一次：全关变全开，否则全关。」「开着时，这一档的武器与防具不再掉落。」「确定整档切换，左右键没有作用。」；
- 角色换装：「学会的换装卡：…」「确定切换启用／关闭。」空列表「还没有可以换装的角色」；
- 导入导出：行尾「待确认」「没有可撤回的」，主按钮「导入这 N 项」，提示「导入／不导入」；
- 手机按键：行尾「调整 ›」，各行右牌说明（显示屏幕按键、摇杆拖动翻页、调整位置、恢复默认、百分比范围「范围 70%～170%。」「左右键每次 ∓5%；确定 ＋5%，到顶回最小。」、灰行「只对「改版按键」有用。现在用的是原版虚拟按钮，这一行不能改。」「先把「操作布局」换成「改版按键」。」），恢复默认弹窗「恢复默认？」「按键大小、透明度、位置、显示都会换回默认，不能撤回。」按钮「恢复」「取消」；
- 键位提示：「换下一档」「各走一档」「整档切换」「启用／关闭」「翻页」「执行」「完成」。
