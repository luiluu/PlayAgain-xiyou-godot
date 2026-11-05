# 交付：cc/rules-ui14

- 车道／工作者：B 界面／rules 线程（cc，ui14）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·rules·未经审查】商店、物品页、结束游戏补原版系统音；技能遗忘窗照原版重画 ui14（dev.待定）

接 ui8～ui13，按页过了一遍零散页面（差异表见下）。这一期做了最确定的四项，都是向原版对齐的缺陷修正，没有新 O 号。

- **商店整页没有声音**（`shop.gd`，原来一个 `XSound` 都没有）：照 `Window_Selectable`／`Scene_Shop`／YEP_ShopMenuCore 补上。换行光标音、确定音、不可选的蜂鸣（买不起、只买不卖的店点出售）、取消音。数量窗确定不响确定音（`Window_ShopNumber.playOkSound` 是空的），只响商店音 21（`onNumberOk` 的 `playShop`）。数量变了才响光标音。数量窗取消响两次取消音（`processCancel` 一次，`onNumberCancel` 又一次）。装备商品左右换队员响光标音，物品不响（YEP `Window_ShopStatus.updateParamSwitch` 只管装备）。锁定物品出售仍是先确定音再提示「已锁定 无法出售」，同原版。鼠标：点别的行响光标音，点已选中的行算确定。
- **物品页移动不响光标音**（`item_scene.gd`）：分类、列表、指令、升级、强化、选人这几个窗口换行，Q／E 翻页，点别的行，现在都响光标音。光标没动的时候不响，比如到头按住。确定、蜂鸣、使用音原来就有。
- **结束游戏**（`game_end_panel.gd`，原来无声）：补上换行光标音、确定音、取消音（含右键）。
- **技能遗忘**（`forget_skill_scene.gd`，原注释写着「外观暂用通用选择窗……留给界面车道」）：原来借的是宽 760 的 XChoiceWindow，名字和状态拼成一行，地图上没有背景，确定还会响确定音。现在照 `Star_Window_ForgetSkill`（Window_Command）重画：
  - 有菜单背景（Scene_MenuBase），窗宽 400，高是 fittingHeight(min(项数, 12))，放在正中。
  - 名字左对齐，宽是内容宽−12−120；「未遗忘／已遗忘」右对齐，x 等于名字宽，宽 120。原版这里没加 rect.x，所以状态列比名字列起点左偏 6，照原版保留。
  - `processOk` 被整段覆写，所以确定不响确定音，按住确定键会连续翻转（isRepeated）。
  - 列表为空时，原版确定会读 `GetSkills[0]` 抛错，这里改成不动作（避开报错，不算优化）。
  - 翻页、滚轮跟 `XMenu.LIST_PAGING` 走。`xiyou_list_paging` 扫描里给它的豁免已删掉，它现在自己接了滚轮和翻页。
- 新专项 `xiyou_ui_page_details`（46 项）：商店 19、物品页 8、结束游戏 5、技能遗忘 14。反向验证 8 处全咬住：去掉商店音、数量窗取消只响一次、物品页去掉光标音、结束游戏去掉确定音、遗忘窗宽改回 760、状态列 x 加 6、遗忘确定响确定音、确定不认连发。

## 怎么盘的（以及没盘到的）

- 方法：在 `modes/xiyou/ui/` 下逐个脚本扫 `XSound.system(0/1/2/3)` 的调用，找出移动、翻页、选中函数里有没有光标音，再看滚轮和翻页有没有接。缺的再对照冻结源 `rpg_windows.js`／`rpg_scenes.js`／插件确认原版行为。ui8 已经逐像素比过主菜单、装备、物品说明卡、设置、商店买入。图鉴和进阶页的立绘 portrait1 核过。这几页这次没再截图。
- 原版浏览器夹具（`tests/fixtures/*_oracle.json`）已有的页：actor_book、actor_advanced、actor_warehouse、crafting、enemy_book、item_list、item_bag、orb_shop_ui、orb_ui、party_skills、pet、save_page、shop_stock_ui、star_warehouse、status_page、training_ui、warehouse、window_rects、zhenqi_page_ui、power_panel、power_books_ui、book_capacity_ui、gear_search、inlay_book。这些页的版面在跑逐项对照，这次只核了操作类细节（声音、翻页、滚轮）。
- **没做**：本期没开原版浏览器重截。声音这一类全是读码对照（MV 的声音调用在原版源码里写死，读码就能确定），没有实听。

## 差异表

| # | 页面 | 原版 | 重制（改前） | 证据 | 处理 | 大小 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 商店 | Window_Selectable 光标、确定、蜂鸣、取消音；数量窗商店音；装备换队员光标音 | 整页无声 | 读码（`shop.gd` 无 XSound；`rpg_scenes.js:2022-2040`、`rpg_windows.js:3220`、YEP_ShopMenuCore 1074-1088） | **本期做** | 小 |
| 2 | 物品页 | 换行、翻页、点选响光标音 | 不响（`_move`／`_page`／点选无 system(0)） | 读码＋扫描 | **本期做** | 小 |
| 3 | 结束游戏 | Window_Command 三种音 | 无声 | 读码 | **本期做** | 小 |
| 4 | 技能遗忘 | 400 宽命令窗、名字／状态两列、菜单背景、确定无声 | 760 宽通用选择窗、拼成一行、地图上无背景、确定有声 | 读码（Star_ForgetSkills.js 全文） | **本期做** | 中 |
| 5 | 任务页 | 冻结 v0.28 没有任务插件（plugins.js 里没有任何 Quest） | 无 | 读码 | 无差异，关闭 | — |
| 6 | 仓库、星级仓库、角色仓库、图鉴（角色、怪物、镶嵌）、成就、更衣、训练、宠物、设置、存读档、整队、传送 | — | 移动、翻页都有光标音，确定、取消、蜂鸣都有；滚轮、翻页 ui9／ui11 已接 | 扫描（每页的 select／_move／page 函数里都有 system(0)，或经 select 间接调到） | 无差异 | — |
| 7 | 战斗内窗口（指令、技能、物品列表） | — | `XBattleList` 统一处理光标、确定、蜂鸣、取消 | 读码；ui8b 已截图比过 | 无差异 | — |
| 8 | 宝珠坊、种族祝福、付费遗忘心法、器谱、星谱、天衣铺 | Codex 原生选择窗（Window_YunChoices 一类） | 前五个走 XChoiceWindow，天衣铺走 XYunChoicesWindow（继承 XBattleList），声音都有 | 读码 | 无差异 | — |
| 9 | DOM 覆盖层（战力面板、装备检索、异化工坊、批量抽奖） | 原版是 HTML 覆盖层，没有 MV 系统音 | 没有系统音 | 读码（installEquipmentStatusRuntime 等走 DOM） | 一致，不做 | — |
| 10 | 角色技能说明卡 | `characterHelpView` 完整版 | `help_card.gd:520` 注释：只对了 10437／10438，完整版留给界面车道 | 读码 | **下期候选**，要先开夹具量 | 中 |
| 11 | 商店：物品左右键 | 原版只在装备商品时换队员 | 物品时也换（`_actor_index` 变，画面不显示，无声） | 读码 | 不做，玩家看不到 | — |

## 交接板

- 下一步：差异表 #10（角色技能说明卡完整版）要先在原版夹具量 characterHelpView，再定做不做；零散页面细节剩下的基本只有这一项。
- 用户试玩说明：商店里换行、买卖、取消都有声音了，买入或卖出成交时响商店音；物品页移动光标有声音；「结束游戏」窗有声音；用遗忘河之水打开的技能遗忘页换成原版的 400 宽窗口，名字和状态分两列，有菜单背景，确定时不响确定音。
- 需要用户决定：无。

## 进度账

- 部分：界面「零散页面细节」1.05 → 剩差异表 #10 一项（说明卡完整版），依据：本期做了四项，其余页逐页扫过没有差异。

## 可优化（流程／工具／效率）

- 建议：`xiyou_list_paging` 的扫描再加一类「移动／翻页函数里要有光标音」（grep 级，检查 `_move`／`page` 函数体或其调用的 `select` 里有 `XSound.system(0)`），防新页漏声音（这次商店、物品页都漏了）。预计收益：新页自带检查；归界面车道，小。

## 待交叉核查

- 只改了界面脚本（`shop.gd`、`item_scene.gd`、`game_end_panel.gd`、`forget_skill_scene.gd`）和测试，没碰 `battle_logic.gd` 等核心文件、切片、转换器、探针。

## 验证

- 新专项 `xiyou_ui_page_details` 46/46；反向验证 8 项全咬住。
- `语法检查.py` 0 问题；`工具回归.py` 全过。
- 选测：`选测.py main --list` 列 44 个场景，超过 40 个，本该走 `云端选测.py`。提交 54d2ddb8 的那轮云端在准备步骤就失败了：GitHub 下载 Godot 时临时出故障（总装查过，实际回的是 504），12 片都没开始跑。所以改在本机 `并行测试.py --full` 跑这 44 个，**全部通过**，用了 774 秒，没有偶发。

## 本分支提交

- 54d2ddb8 WIP: ui14 商店／物品页／结束游戏补系统音，技能遗忘窗照原版重画，新专项 xiyou_ui_page_details
