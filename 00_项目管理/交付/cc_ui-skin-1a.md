# 交付：cc/ui-skin-1a

- 车道／工作者：B 界面·新界面第 1A 批（主菜单，盘点清册 #21）／cc（Opus＋medium，派单定：主菜单入口改道、分组直接进、七印进度接数据）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·未经审查】新界面第 1A 批：主菜单按新稿重排（dev.待定）

- 玩家可见：无（新界面只在天启篇存档里开，天启篇没对玩家开放；重制版 0.01.x 与西游存档仍是旧主菜单，已逐像素对照）。开发版里进天启篇存档按菜单键，主菜单换成新稿：左边七印意象的环（一组一个球，环心是当前角色的圆头像），中间分组子项（选中的组展开、每项一句话说明，其余组收成一行），右边本局条（第几层 · 难度 · 哪条线、七印首通进度）和队伍条，右上精魂、印屑。
- 依据：界面风格提案 v0.7 样稿 `menu`、README 第一节「主菜单」与第二节横屏铺满（私密设计仓 `重制设定/界面风格提案_v0.7/`）；分组 Kyo 11-15 定 6 组（宠物以后单独第 7 组，现在天启篇隐藏）；文字口径照小A文字审 ba1f7ed（精魂、整队不带宠物、宝珠坊「鉴定、兑换、分解宝珠」、按键提示套框；建议项「查看与使用技能」「闭关突破」「用材料做物品和装备」「分解异化装备、重铸词条」也照改了）。
- 开关：沿用第 0 期 `XUiSkin.ENABLED`（O-467，同一开关不另开）：关掉或不是天启篇存档时 `XMenu` 走旧三个窗口，代码一行不变。
- 新增 `modes/xiyou/ui/skin/skin_main_menu.gd`（`XSkinMainMenu`）：
  - 布局按 `XSkinLayout` 三块（左 416 环、右 360 本局条＋队伍条、中块跟着变宽封顶 720），页面显示时 `request_wide`（宽屏横向铺满），进子页（各页还是旧布局，按 1280×720 排）时还原、回来再铺满；
  - 组读 `XUiSkin.GROUPS`（`visible_groups`，天启篇 6 组）；没选中的组一行（行高 46，组名＋子项名），选中的组展开（组名旧金＋子项 56），**只剩一项的组（物品、装备）不展开、确定直接进**；七组时收起行自动压矮，总高不出中块；
  - 操作：上下在子项间走、到组头尾跨组（按住不循环、单按到底回第一项）；左右、Q／E 换组，环跟着转；确定进入；取消回地图；鼠标点收起的组＝换组、点子项先选中再点确定、滚轮上下；
  - 技能、装备、状态：先到右边队伍条选人（`XMenu._mode`＝actor，按键提示换成「确定 进入／取消 返回」），确定进页、取消回列表；不可用的（反馈还没做、整队不到 2 人、没队员时的物品等）变暗、确定蜂鸣，规则和旧菜单同一份（`XMenu.symbol_enabled`）；
  - 本局条：「第 N 层 · 难度 · 线」（层＝变量 20，现在要打的层；难度、线只有天启篇存档有）；能进七印祭坛的档多一行七印：7 个菱形按祭坛印序，实心＝首通过该印 Boss、空心＝揭开了没打过、暗＝没揭开，右边「首通数 / 7」；
  - 货币：精魂一直显示，印屑只在能进祭坛的档显示（名字读 `qiyin_altar.json` 的 `shards_name`）；
  - 按键提示给右下角版本号（`XVersionLabel`，全局常驻）让位：提示的右边在安全边距和「版本号左边再空 16」里取靠左的，离底仍是 10（协调 11-15 提醒第 0 期陈列图压住了 dev.597）。
- 改 `modes/xiyou/ui/menu.gd`（XMenu）：`_ready` 里 `XUiSkin.on()` 时建 `XSkinMainMenu`、不建旧窗口；`_refresh`／输入在新界面时交给它；把「执行指令」「选人后开页」从 `_ok` 抽成 `run_command(sym)`、`open_actor_page(sym, idx)`（旧菜单也走这两个，行为不变）；加 `symbol_enabled(sym)`；游戏结束页在新界面时把黑底一起显示。
- 改 `modes/xiyou/ui/skin/ui_skin.gd`：`GROUPS` 每个子项加 `cmd`（旧菜单符号）和 `desc`（一句话说明）；异化工坊加隐藏规则 `alien`（＝`XAlienBattle.hidden()`，与旧菜单 `XMenu.commands()` 同口径，发行隐藏异化时工坊组只剩制作、宝珠坊）——小A核第 0 期的 P3；加 `XUiSkin.icon()`／`face()` 图标头像缓存。
- **修第 0 期组件图标画成白块**：`XUI.icon_texture` 每次新建 AtlasTexture，图集贴图只靠它引用，组件在 `_draw` 里取完就被释放、图集跟着卸掉，画出来是白块（旧画布 `XMVCanvas` 有 `_keep` 留引用所以没事）。环、直列表、角色条状态图标、陈列页都改从 `XUiSkin.icon()` 取。第 0 期交付单里猜的「这棵工作树 IconSet_2 导入缓存问题」不对，是这个原因。
- 测试跟着改：`tests/xiyou_tianqi_e2e.gd` `_menu_cmd`、`tests/virtual_player/virtual_player.gd` 换装（天启篇存档里按键找「装备」）遇到新主菜单时按新菜单走（旧菜单路径不变）。
- 小A核查（136851f60）后返工：只一项的组收起时右边写那一项的说明，不再出「物品 物品」「装备 装备」（P2）；「游戏结束」改叫「返回标题」、设置说明改「画面、声音、挂机与操作」、装备说明改「更换角色装备」（协调定）；选人时环不收鼠标、环被点也转回当前组（P3）；`XMenu.symbol_enabled` 改按 `commands()` 判断，被隐藏的（天启篇宠物、异化隐藏时的异化工坊）一律不可用（P3）。
- 工具：`07_开发环境/皮肤关闭对照.py` 的 `--out` 给相对路径时截图写到工程目录里、两边都 0 张，改成先转绝对路径。

## 优化登记草稿

无（沿用第 0 期 O-467，不新增）

## 新增可见文字（交付后派小A文字审）

| 文字 | 在哪 | 说明 |
| --- | --- | --- |
| 菜单 | 页名 | 样稿原文 |
| 物品、装备、角色、工坊、图鉴、系统（宠物以后） | 组名（环、列表） | 第 0 期 `XUiSkin.GROUPS`，小A审过 |
| 物品、装备、状态、技能、真气、种族祝福、整队、宠物、制作、宝珠坊、异化工坊、人物图鉴、怪物图鉴、成就、存档、设置、反馈、返回标题 | 子项名 | 沿用现有入口名；「游戏结束」协调 11-15 定改「返回标题」（只是弹回标题确认窗，跟全灭重名易混） |
| 使用和查看随身物品 | 物品的说明（也是物品组收起行右边的字） | 新写 |
| 更换角色装备 | 装备的说明 | 小A核查改法 |
| 属性、抗性、掌握 | 状态的说明 | 样稿原文 |
| 查看与使用技能 | 技能的说明 | 小A建议改法 |
| 闭关突破 | 真气的说明 | 小A建议改法 |
| 种族加成与进阶 | 种族祝福的说明 | 样稿原文 |
| 调整出战人员和顺序 | 整队的说明 | 新写 |
| 查看和培养宠物 | 宠物的说明 | 新写（天启篇现在隐藏） |
| 用材料做物品和装备 | 制作的说明 | 小A建议改法 |
| 鉴定、兑换、分解宝珠 | 宝珠坊的说明 | 小A必改改法 |
| 分解异化装备、重铸词条 | 异化工坊的说明 | 小A建议改法 |
| 查看角色资料 | 人物图鉴的说明 | 新写 |
| 查看敌人资料 | 怪物图鉴的说明 | 新写 |
| 查看成就 | 成就的说明 | 新写 |
| 保存当前进度 | 存档的说明 | 新写 |
| 画面、声音、挂机与操作 | 设置的说明 | 协调 11-15 定 |
| 提交问题和建议 | 反馈的说明 | 新写（反馈现在主菜单里灰着） |
| 回到标题画面 | 返回标题的说明 | 新写 |
| 第 %d 层 · 难度名 · 线名＋「线」 | 本局条第一行 | 样稿格式（「战争线」等） |
| 七印、「N / 7」 | 本局条第二行 | 样稿原文 |
| 精魂、印屑 | 右上货币 | 精魂照小A必改；印屑读祭坛表 |
| 队伍 | 队伍条标题 | 样稿原文 |
| 确定 进入、取消 回地图、Q / E 换组；选人时 确定 进入、取消 返回 | 右下按键提示 | 样稿原文；「返回」第 0 期陈列页用过 |

## 交接板

- 下一步：1A 完成；1B（模板页＋物品＋技能＋说明卡）可开。组图标仍是占位图标号（`GROUPS` 的 `icon`），co 画好后换号即可。
- 用户试玩说明：无（天启篇没对玩家开放）。开发版进天启篇存档按菜单键看新主菜单；截图见「验证」。
- 需要用户决定：无。

## 进度账

- 天启篇新界面：第 0 期底层完成 → 第 1A 批主菜单完成；页面重排 1/83（主菜单）。

## 验证

- 专项 `tests/xiyou_ui_skin_menu.tscn`（新）：无头 58/58，有窗口 62/62（返工后；多了收起行写说明、系统组名、选人时环锁住、隐藏项按符号不可用）（多 4 项：两张截图、20:9 视口比例、20:9 左边距 56）。覆盖：组都有说明和旧菜单符号、18 个旧指令都有新入口；异化隐藏时工坊只剩两项；本局条文字（天启篇「第 32 层 · 艰险 · 战争线」、西游档只有层）、七印状态（首通 2／揭开 1／没揭开 0）、货币（西游档只有精魂）；按键提示不压版本号（1280、1600 宽）；新菜单建出来、旧窗口不建、环 6 球、铺满；第一组只一项不展开；6 组各自展开都不出中块；展开后行高 46／56、选中条在行上；上下跨组、到头循环、按住不循环；左右、Q／E 换组、环点选带动列表；物品组确定直接进物品页（进子页还原拉伸方式、回来再铺满）；装备先选人、上下选人、取消回列表、确定进装备页且选中的人对；反馈不可用蜂鸣不进；鼠标点组行、点子项；自定义只剩一项的组不展开；取消关菜单、菜单关掉还原拉伸方式；`ENABLED = false` 回旧菜单、西游存档旧菜单。
- 第 0 期专项 `xiyou_ui_skin.tscn` 88/88（图标缓存改动后）。合 main（第 0 期 dev.598）后复跑 `xiyou_ui_skin*` 三个＋`xiyou_tianqi_e2e` 全过、截图重拍。
- **开关关掉与 main 一致**：`python3 03_再刷重制_Godot/07_开发环境/皮肤关闭对照.py --base main`（合入第 0 期后的 main＝c4e5a375a；合之前对 f66cda7a0 也比过一次，同样全 SAME）→ 主菜单、状态、物品、装备、设置 ×「西游存档开关默认」「天启篇存档 ENABLED=false」共 10 张逐像素 SAME。
- 截图（有窗口，git 忽略目录）：`03_再刷重制_Godot/04_验证/本地结果/ui_skin_1a/ui_skin_1a_menu_16x9.png`（1280×720）、`ui_skin_1a_menu_20x9.png`（1600×720）；关闭对照 `ui_skin_1a/关闭对照/base`、`branch` 各 10 张。
- 选测（本地，并发 2）：`选测.py cc/ui-skin-p0 --list`（只算本批改动）列的 42 个去掉事件对照四片，共 38 个场景一次全过（含 `xiyou_tianqi_e2e`、`xiyou_virtual_player`、`xiyou_tianqi_pet_hide`、`xiyou_alien_hide`、`xiyou_ui_skin*` 三个、`xiyou_ui_pixel`、`xiyou_list_paging`），214 秒。日志 `04_验证/本地结果/并行测试/20261115_071112_y14jzcoq/`。
- `工具回归.py`：全部通过（103 秒）。
- `语法检查.py`：0 个问题。
- 给总装：`合并车道.sh --finish --affected --cloud`（事件对照四片 `xiyou_event_compare*` 本地没跑：只动主菜单与皮肤组件，开着新皮肤才走新代码，事件对照不建天启篇存档）。

## 可优化（流程／工具／效率）

- 已做：`皮肤关闭对照.py --out` 相对路径转绝对（回退：删那一行的 `.resolve()`）。
- 已做：`XUiSkin.icon()`／`face()` 缓存，以后新组件取图标都走它（回退：组件改回 `XUI.icon_texture`，会回到白块）。
- 建议：别的新代码在 `_draw` 里直接调 `XUI.icon_texture` 也会白块（只要那张图集没被别处引用）；可以在 `XUI.icon_texture` 里按号缓存一劳永逸，但它是共用文件、影响面大，归总装或界面车道评估。

## 本分支提交

- 90fd3d24f WIP：新界面 1A 主菜单（XSkinMainMenu）、组子项说明与旧指令对照、异化隐藏规则、组件图标缓存修白块、专项测试
- （其余见 git log）

## 小A 乙档核查

- 核查对象：`cc/ui-skin-1a`（交付提交 `6c8a98368`），执行者：小A（ag，只读核查＋轻量前台验证，未改游戏代码）。
- **结论：不通过**（第 1～5 项功能与规则核查全部通过，无 P1；第 6 项文字审发现 **1 处必改**——单项组折叠行右边重复显示组名「物品　物品」「装备　装备」，需先修再合；另有 3 条 P3 与 2 条文案建议不阻塞）。

### 核查项与核实深度

1. **XMenu 分流、旧菜单行为与 10 张对照口径（读代码＋跑无头专项与既有图比对；未重拍有窗截图）**：
   - `modes/xiyou/ui/menu.gd` 仅在 `XUiSkin.on()` 时建 `XSkinMainMenu` 并把 `_refresh`／`_gui_input`／`_unhandled_input` 转交它，旧三窗体不建；`XUiSkin.on()` 为假时 `skin == null`，走回原代码。从 `_ok()` 抽出的 `run_command(sym)`、`open_actor_page(sym, idx)` 逐分支对照 `main`（`c4e5a375a`），17 个指令与选人跳转、音效、可用性规则均与旧菜单一致；`_show_game_end()` 仅在 `skin != null` 时额外恢复 `SkinBackdrop` 显示。
   - `07_开发环境/皮肤关闭对照.py` 改用 `Path(a.out).resolve()` 修正相对路径写偏问题，基线取 `main` 与本分支各跑 `xiyou_ui_skin_offshot.tscn`（10 张：`XMenu`、`XStatusPage`、`XItemScene`、`XEquipScene`、`XOptionsScene` × 西游默认／天启 `ENABLED=false`）逐像素比对。前台实跑 `xiyou_ui_skin_menu.tscn`（51/51）、`xiyou_ui_skin_offshot.tscn`（10/10）及对既有 `ui_skin_1a/关闭对照/{base,branch}` 跑 `--compare`（10/10 SAME）均通过；`语法检查.py` 897 个 `.gd` 0 个问题。
2. **GROUPS、异化隐藏规则 `alien`、单项组直接进（核了规则本身＋读代码＋跑无头专项）**：
   - 对照 `XMenu.commands()`、`XAlienHide.active()`（→ `XAlienBattle.hidden()`：`HIDDEN_V058 or (RELEASE_HIDE and ReleaseEntry.is_release())`）及 `XTianqiPetHide.active(s)`，`XUiSkin.GROUPS` 在天启篇默认隐藏 `pets` 组，呈 6 组（物品｜装备｜角色(状态、技能、真气、种族祝福、整队)｜工坊｜图鉴｜系统）；`hide: "alien"` 调用 `XAlienBattle.hidden()`，发行隐藏异化生效时工坊组仅剩「制作」「宝珠坊」，与旧菜单口径完全一致。
   - `XSkinMainMenu._layout_rows()` 对 `n <= 1` 的当前组直接排 `"item"` 行而不展开 `"header"`，确定即调 `run_command` 直接进（`物品` 直接进 `XItemScene`、`装备` 直接转 `actor` 选人再进 `XEquipScene`）。`xiyou_ui_skin_menu.tscn` 专项通过。
3. **本局条与七印数据来源（核了规则本身＋读代码＋跑无头专项）**：
   - `run_text(s)` 层数取 `maxi(1, int(s.variable(20)))`（对应全库 `FLOOR_VAR = 20` 当前要打的层）、难度取 `XTianqi.difficulty_of(s).name`、线取 `XTianqi.line_info(XTianqi.line_of(s)).name + "线"`，西游档仅显示层数。
   - `seal_states(s)` 与 `currencies(s)` 以 `XTianqiQiyin.allowed(s)` 门控（天启篇＋发行门＋已选线），七印首通按 `XTianqiQiyin.seal_keys()` 序读 `XTianqiQiyin.progress(s).drop.get("first_clear", {})` 统计 `N / 7`（`2`＝首通、`1`＝`unlocked(s, k)` 已揭开、`0`＝未揭开），印屑名读 `qiyin_altar.json` `shards_name`、数量读 `XTianqiQiyin.shards(s)`，口径全部准确。
4. **`tianqi_e2e` 与 `virtual_player` 适配（只看了代码 diff）**：
   - `tests/xiyou_tianqi_e2e.gd` 仅在 `_menu_cmd` 增加 `if menu.skin != null:` 分支按键走到 `cmd == sym` 再回车；`tests/virtual_player/virtual_player.gd` 仅在 `_signature` 把游标签名兼容为 `skin.gi * 100 + skin.ii`、在 `_act_equip` 增加 `menu.skin != null` 时左右换组到 `"equip"` 再确定（仍经 `"actor"` 选人与 `XEquipScene`）。两边均未放松任何断言。
5. **图标白块修复与缓存边界（核了机制本身＋读代码＋跑无头专项）**：
   - 机制成立：`XUI.icon_texture` 对常规 `IconSet_1..4`（以及 `XUI.face_texture`）每次新建 `AtlasTexture`，在新组件 `_draw()` 里作为局部变量用完即释放，底层贴图失去 GDScript 引用后被卸载，导致绘制时变白块（与旧画布 `XMVCanvas._keep` 同理）。
   - `XUiSkin._icon_cache` 键空间为静态有限的图标号 `index: int` 与 `"face:%s#%d"`，上限受静态表与图集总量约束（4 张 IconSet＋角色头像），不会随运行时间或帧数无限增长；`skin/*.gd` 已全部改走 `XUiSkin.icon()`／`face()`。`xiyou_ui_skin.tscn` 88/88 通过。
6. **文字审（核了 `ba1f7ed`《文字审_小A.md》与 `v0.7 README.md`＋源码全量核对）**：
   - `ba1f7ed` 必改与建议项已按要求落实：货币用「精魂」（非「精魄」）、天启篇「宠物」已整组隐藏、宝珠坊用「鉴定、兑换、分解宝珠」、按键提示统一 `XSkinKeyHints` 胶囊框（「[确定] 进入」「[取消] 回地图」「[Q / E] 换组」「[取消] 返回」），以及「查看与使用技能」「闭关突破」「用材料做物品和装备」「分解异化装备、重铸词条」已照改。
   - **必改项（1 处）**：`skin_main_menu.gd:480` `"group"` 行在未选中折叠态把 `group_items(g)` 的 `name` 拼在右边，导致只有 1 项且子项与组同名的「物品」「装备」（及后续「宠物」）在折叠态左右重复显示「物品　物品」「装备　装备」（即协调在截图中看到的问题）。**改法**：当 `group_items(g).size() == 1` 时，折叠行右侧改为显示该项的 `desc`（不再显示 `it.name`）：
     - `物品` 折叠行右侧：`使用和查看随身物品`
     - `装备` 折叠行右侧：`给角色换装备`（或顺手统一下文建议改为 `更换角色装备`）
     - `宠物`（后续放开时）折叠行右侧：`查看和培养宠物`
   - **协调／交付单所问两项定夺建议（非阻塞必改）**：
     - **「游戏结束」叫法**：旧菜单 `XMenu.COMMANDS` 与 `v0.7` 样稿原表均写「游戏结束」，但该入口实为打开「回到标题／取消」确认窗（不退出程序），且与全灭画面 `XGameOverScreen`（游戏结束）重名、易被误解为关闭游戏；按新界面去歧义口径，**建议改叫 `返回标题`**（右侧说明可写 `回到标题画面` 或 `退回标题，注意先存档`），各测试均按 `cmd == "gameEnd"` 定位、改显示名零风险。若协调／Kyo 定照旧版沿用「游戏结束」，有右侧说明「回到标题画面」兜底亦可接受。
     - **「设置」说明要不要写全挂机、通知等**：**不写全**。主菜单说明栏为 15px 单行概览（同「状态」只列三词「属性、抗性、掌握」），可保持 `画面、声音与操作`，或补上常用的「挂机」微调为 `画面、声音、挂机与操作`（非必改）。

### 问题清单（P1/P2/P3）

- **P1**：无。
- **P2（文字／显示必改 1 条）**：`skin_main_menu.gd:480` 单项组折叠行（`物品`、`装备`、未来 `宠物`）右侧重复画了 `it.name`，需改为画 `desc`（改好文字见上「文字审」必改项）。
- **P3-1（选人态左环未拦）**：`skin_main_menu.gd:65-66,356-360` 进入 `host._mode == "actor"` 选人时，`_pane_input` 已拦非 `"command"` 态，但 `ring.changed`（`_on_ring_changed`）与 `ring.activated` 未判 `host._mode == "command"`，鼠标点左环会切组而停留在选人态。建议入口加 `if host == null or host._mode != "command": return`。
- **P3-2（`symbol_enabled` 小差）**：`menu.gd:77-83` `symbol_enabled(sym)` 遍历 `COMMANDS` 而非 `commands()`，对隐藏的 `"pet"`／`"alienation"` 会返回 `true`（新菜单已被 `visible_groups` 滤掉，实际不可达）。
- **P3-3（交付单文字表小遗漏）**：`cc_ui-skin-1a.md`「新增可见文字」表未单列 7 个组名、19 个子项名（沿用自第 0 期／`v0.7`）与队伍条 `Lv %d · 职业名`，文字本身均已核过无问题。

### 没核到的（留给总装 `--affected --cloud`）

- 有窗模式重新跑 `python3 03_再刷重制_Godot/07_开发环境/皮肤关闭对照.py --base main` 与 `xiyou_ui_skin_menu.tscn -- --out=...` 截图（本次仅对已有对照图跑了 `--compare`）；
- 长测试：`xiyou_tianqi_e2e`、`xiyou_virtual_player`、事件对照四段 `xiyou_event_compare*`、完整 `工具回归.py` 与 `选测.py` 全集。

### 返修复核（提交 `4b780b162`，相对 `136851f60`）

- **复核对象**：`cc/ui-skin-1a`（返修提交 `4b780b162` 相对 `136851f60` 的 diff，乙档复核），执行者：小A（只读核查＋前台轻量无头复跑，未改游戏代码）。
- **结论：通过**（上次 1 条 P2 必改、协调定夺 2 处文案、3 条 P3 均已按要求落实，按 `ba1f7ed` 口径核对无误，未带出新问题）。
- **逐项确认**：
  1. **P2 单项组折叠行（`skin_main_menu.gd`、`ui_skin.gd`）**：新增 `XSkinMainMenu.collapsed_text(g)`，单项组（`items.size() == 1`）改返回 `items[0].desc`，多项组用全角空格 `"　"` 拼 `it.name`，`_draw_pane()` `"group"` 行改调它；`物品` 折叠行右侧为 `使用和查看随身物品`、`装备` 为 `更换角色装备`、`宠物`（放开后）为 `查看和培养宠物`，不再重复组名。
  2. **协调定夺文案（`ui_skin.gd`）**：`game_end` 项名称改 `返回标题`（`cmd: "gameEnd"`、`desc: "回到标题画面"`，全局仅影响新主菜单显示名、无测试冲突）；`options` 项说明改 `画面、声音、挂机与操作`；全量 `GROUPS`（6＋1 组名、18 子项名及说明）按 `ba1f7ed` 与协调定夺口径核对全部一致。
  3. **三条 P3 落实与防引入新问题**：
     - P3-1（选人态锁环）：`skin_main_menu.gd` 在 `refresh()` 按 `actor_mode` 设 `ring.mouse_filter`（`IGNORE`／`STOP`）、`ring.activated` 判 `host._mode == "command"`、`_on_ring_changed` 非 `"command"` 时 `ring.select(gi, false)` 兜底转回当前组（对照 `XSkinRingNav.select` 在 `animate=false` 先置 `_arc_t = 1.0` 再 emit `changed`，不会无限递归）。
     - P3-2（隐藏项按符号可用性）：`menu.gd` `symbol_enabled(sym)` 改遍历 `commands()`，隐藏的 `"pet"` 与发行／开关隐藏时的 `"alienation"` 均返回 `false`。
     - P3-3（交付单文字表）：`cc_ui-skin-1a.md`「新增可见文字」表已补全组名、18 个子项名（含 `返回标题`）及同步后的 `装备`、`设置` 说明。
  4. **测试补充与前台复跑**：`tests/xiyou_ui_skin_menu.gd` 新增 7 条断言（`collapsed_single_desc`、`collapsed_multi_names`、`system_names`、`actor_ring_locked`、`ring_mouse_back`、`hidden_symbol_disabled`、`alien_symbol_back`）；前台单跑 `./03_再刷重制_Godot/07_开发环境/godot --headless --path 03_再刷重制_Godot/01_Godot工程 res://tests/xiyou_ui_skin_menu.tscn` 实测 `TEST_RESULT={"passed":58,"total":58}`。

