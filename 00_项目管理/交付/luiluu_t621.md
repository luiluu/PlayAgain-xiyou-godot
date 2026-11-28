# 交付：luiluu/t621

- 车道／工作者：T621 西游档三处小修（cc，claude-opus-5-5＋medium，P8）
- 状态：进行中

## 变更记录草稿

## 2026-11-28 【cc·T621·未经审查】深渊商人不强制弹出、卡墙里的七张图站位挪出、装备检索下拉限高能滚（dev.待定）

- 依据：Kyo 11-28「深渊商人强制跳出来影响体验，深渊商人位置可能不对，装备检索显示不全还不能滑动。」（截图：私密设计仓 `协作交接/附图/装备检索下拉显示不全_1128.png`，安卓横屏 v0.04.08，「部位」下拉从屏顶伸到屏底、下半截切掉）。
- **深渊商人强制弹出**：原版就是强制的——CE1439（首领奖励公共事件）末条 `CodexAbyssMerchant.complete` 里商人一出现就 `openCurrent`（正式源 v0.62.12 `js/codex/runtime/installAbyssMerchantRuntime.js` 第 31 行），重制照搬。改成只提示「…深渊商人出现了，走过去和他对话就能交易。」（不朽商人同句），商人事件第 2 页照旧成立、站在图上，玩家走过去对话（第 2 页本来就是 `openCurrent`）才打开。本轮在这张图里一直在，离开这张图才走；没去找也不扣点，点数照存。开关 O-待定 `XAbyssMerchant.NO_FORCE_OPEN`（默认开；false＝原版出现就弹出）。项目经理cc 11-28 转 Kyo 后同意。
- **深渊商人站位**：32 张商人路线图逐张核（游戏自己的通行判断、穿墙设置关着，从首领格出发看商人四邻走不走得到；带窗口截图核）。7 张原版把商人摆在墙里：

  | 图 | 形状 | 原位 | 问题 | 新位 |
  | --- | --- | --- | --- | --- |
  | 174、184、211、216 | 39×35 十字 | (13,20) | 站在左下墙沿上，只有北面一格挨得到 | (16,14) |
  | 177、210、223 | 19×19 菱形 | (13,17) | 整个埋在墙里，四面都走不到，对不上话 | (4,7) |

  新位是同形状其它深渊图商人的位置（37 等 18 张十字图都在 (16,14)，141、152 等菱形图在 (3,8)／(4,7)），四邻两面可走、不挡路、格上没有别的事件。其余 25 张原位正常：不挡路、不站传送点或首领格，不动。新建事件和读旧档（存档里记着墙里原位）都挪。216 不在切片（无入口、不入包），表里照写、没实测。开关 O-待定 `XAbyssMerchant.MOVE_STUCK`（默认开；false＝原版站位）。
- **装备检索下拉**：截图是网页版（皮肤关）检索页，「部位」下拉是 OptionButton 弹出菜单，项多时撑满整屏、在安卓上下截被切，触屏拖不动菜单。改成西游档六个下拉（分类、部位、品质、位置、指定词条、排序）都放进可见区域：触屏一律用 T409 那种可拖动列表（原来只有指定词条），下面放得下 9 行就往下开，放不下翻到上面，上下都不够就挑空的一边限到整行数，拖动或滚轮滚；桌面 OptionButton 弹出时限高到窗口内（菜单自带滚动条，滚轮滚），下面放不下翻到按钮上面。新皮肤 T368 版（筛选小块）本来就是固定挑选框，不受影响。启封档（天启篇）不走这里。开关 O-待定 `XGearSearch.XIYOU_SELECT_FIT`（默认开；false＝回到 T409：只指定词条可拖、菜单不限高）。
- 专项：`xiyou_t621_select_fit` 29/29（手机比例 1920×864、电脑 1280×720 各一轮，按钮在中部与靠底两处，桌面菜单在窗口内且比内容矮＝要滚、触屏是可拖动列表且拖 170 像素会滚不选中；回退支）；反向验证：开关关掉 8 条失败。`xiyou_t621_merchant` 45/45（不弹出、对话才开、未知存在同样、不出现时提示没有商人那句、回退支弹出；6 张在包里的图原位走不到或只挨一格、新位两面以上走得到、格上无别的事件、新建与读档都挪过去；37、175 不动；回退支）。
- 改了的旧专项：`xiyou_merchant29`（原版参照对照）开头设 `NO_FORCE_OPEN = false`，照旧 140/140；`xiyou_gear_search` 触屏词条下拉那段改成按项数挑指定词条那个弹框（六个都是弹框了），照旧 68/68。
- 截图：`00_项目管理/归档/交付截图/luiluu_t621/`——`t621_phone_*`／`t621_pc_*`（下拉，desktop＝鼠标、touch＝触屏，mid／low＝按钮在中部／靠底）；`t621_map174/177/184/210/211/223_before|after`（商人站位，before＝原版）；`t621_map037/141_参照_原位正常`。截图工具 `tests/t621_merchant_shots.tscn`（要真窗口）。
- 玩家可见：打完深渊／未知存在首领商人出现时不再直接弹商店，提示后自己走过去找他；7 张图的商人从墙里挪到走得到的地方；装备词条检索的下拉在手机和电脑上都完整显示、能拖能滚。新提示文字「深渊商人出现了，走过去和他对话就能交易。」待小A 审。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/abyss_merchant.gd` `XAbyssMerchant.NO_FORCE_OPEN`（`complete`） | 首领打完商人一出现就直接弹出商人界面 | 只提示，商人站在图上，玩家对话才打开 | Kyo 11-28「强制跳出来影响体验」 | `XAbyssMerchant.NO_FORCE_OPEN = false` | cc（T621） | 保留 |
| O-待定 | `modes/xiyou/core/abyss_merchant.gd` `XAbyssMerchant.MOVE_STUCK`／`STUCK_POS`、`modes/xiyou/map/mv_event.gd` `setup_event`／`restore_state` | 174/184/211/216 商人在 (13,20) 墙沿、177/210/223 在 (13,17) 墙里 | 挪到 (16,14)／(4,7)，读旧档也挪 | Kyo 11-28「位置可能不对」，四张只一面挨得到、三张对不上话 | `XAbyssMerchant.MOVE_STUCK = false` | cc（T621） | 保留 |
| O-待定 | `modes/xiyou/ui/gear_search.gd` `XGearSearch.XIYOU_SELECT_FIT`（`_select`、`_install_term_picker`、`_fit_popup_height`） | 下拉菜单不限高，项多时撑满屏、安卓切掉下半截、触屏拖不动（T409 只修了指定词条） | 西游档六个下拉限高到可见区域；触屏都用可拖动列表，桌面菜单限高带滚动条 | Kyo 11-28「装备检索显示不全还不能滑动」 | `XGearSearch.XIYOU_SELECT_FIT = false` | cc（T621） | 保留 |

## 交接板

- 下一步：53、107、110、113、175 五张商人路线图的首领事件不调 CE1439（没有 `complete`），商人在这几张图原版就从不出现（159 同样，不在切片）。项目经理cc 已转 Kyo 定要不要补，本单没动。
- 用户试玩说明：深渊商人不再强制弹出，走过去对话交易；7 张深渊图商人不再卡墙里；装备检索下拉手机上能拖、电脑上能滚。
- 需要用户决定：上面五张图要不要补商人（项目经理cc 已转）。

## 进度账

- 无（体验修正）

## 可优化（流程／工具／效率）

- 已做：`tests/t621_merchant_shots.tscn` 商人站位截图工具（任意商人图、`--before` 拍原版站位，打印商人格与四邻通行），以后核事件站位可照抄。
- 建议：本机设置里穿墙（cq）开着时，用 `MVTilemap.is_passable` 做通行核查会全图可走；探针要 `XConfig.path_override` 到干净设置（本单踩过一次）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `MVEvent.setup_event`、`MVEvent.restore_state`（加商人站位改写） | `setup_event` 4 处（map_scene.gd 建事件、tests/xiyou_map、tests/xiyou_tianqi_sect_geng、新专项），`restore_state` 2 处（map_scene.gd 读档套回、新专项）（`git grep -nE 'setup_event\(|restore_state\(' -- '*.gd'`） | 调用方 6 处逐处结论：只有备注带 `<CodexMerchant29>`、图在 STUCK_POS 表里、数据原位等于表里原位的事件才改坐标，其余事件一行不变；读档只在存档坐标还是墙里原位时改，商人不会动，所以不会误挪别人。 |
| `XAbyssMerchant.complete`（出现时不再 `open_current`） | 8 处：mv_script.gd CE1439 末条 1 处，其余 7 处在 tests（xiyou_merchant29 已设回原版开关、xiyou_ui_skin_card_n 只看商人界面、新专项）（`git grep -n 'XAbyssMerchant.complete' -- '*.gd'`） | 调用方 8 处逐处结论：游戏里只有 CE1439 一处；返回值与记账、提示时机不变，只是出现时不再等商人界面关掉；CE1439 之后的 2490、1027 照旧接着跑。 |
| `XGearSearch._select`（触屏非指定词条下拉也成 Button＋PopupPanel） | gear_search.gd 内 13 处（含定义 1 行）（`git grep -n '_select(' -- 'modes/xiyou/ui/gear_search.gd'`）；`_sort_select` 4 处 | 调用方 13 处逐处结论（12 处调用＋定义）：返回的 box 结构不变（标签＋按钮两个子节点）；`_sort_select` 改成 `as OptionButton`，触屏时为 null，`_sort_text` 本来就有 null 分支照条件现取排序字。 |

## 云端与验证

- 本机：`xiyou_t621_select_fit` 29/29、`xiyou_t621_merchant` 45/45、`xiyou_merchant29` 140/140、`xiyou_gear_search` 68/68；`语法检查.py` 1292 个 .gd 0 问题。
- 云端选测：待写
- `发行空壳.py check` 0（89 个脚本 880 个函数）。

## 本分支提交

- c33360848 装备检索下拉限高能滚（XIYOU_SELECT_FIT）
- d27c2d06c 深渊商人不强制弹出（NO_FORCE_OPEN）、卡墙里的七张图站位挪出（MOVE_STUCK）
