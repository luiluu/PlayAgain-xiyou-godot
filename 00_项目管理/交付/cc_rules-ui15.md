# 交付：cc/rules-ui15

- 车道／工作者：B 界面／rules 线程（cc，ui15；接手会话完成）
- 状态：可合并（选测结果见文末「验证」）

## 做了什么

### ① 小猫剑圣一族说明卡改走 XCharacterHelp（17 个）

- 新探针 `mv_oracle/cat_help_probe.cjs`（原版 Sprite_ItemHelp.setItem 实际画出的行），夹具 `tests/fixtures/cat_help_oracle.json`，量技能 10437～10450、物品 2899／2900、法宝 7999，分「没有 178」「178 在、10 级」两种，每种 17 个。
- 实测：旧近似（help_card 里 `XCat.is_cat_item` 分支）只对得上 10 个，差在：10445 至圣剑影「段数／冷却」没拆开；10447／10449／10450 的「伤害属性」行原文带 `\C[200x]` 着色码，近似去掉了；物品 2899／2900、法宝 7999 的行结构（说明行留在抬头、消耗品标记、来源／专属行、成长行）都不对。
- 改法：`XCharacterHelp.target／actor／current_text／view` 认 `<CodexCat:`（actor 取 `XCat.help_actor()`，行文取 `XCat.help_text`；技能才去掉「说明」行，物品、法宝留在抬头；不套 dyn2／nowGrowth）。`XHelpCard.content` 对物品、法宝也按 `XCat.is_cat_item` 走它。删掉 `_generic_view` 里三处小猫近似分支。
- 新专项 `xiyou_cat_help`（35 项：夹具来源核对＋34 张卡逐行文字／字号／颜色／对齐／y／卡高）全过；`xiyou_cat`、`xiyou_cat_trial`、`xiyou_help_card` 照旧全过。

### ② 光标音扫描

- `tests/xiyou_list_paging.gd` 加 `_scan_cursor_sound`：`ui/`、`battle/` 下名叫 `_move／move／_move_list／page／_page／_scroll` 的函数，本身或同文件调到的函数里要有 `XSound.system(0)`；豁免写明原因（`CURSOR_EXEMPT`）。
- 扫出 6 处，全部核对后是「本来就不该响」，没有漏项要补：menu.gd 的 `_move`／`page` 是静态纯函数、音在输入处；achievement／battle_list 的 `_scroll` 是鼠标滚轮（processWheel 不响）；battle_list `page` 在 `_unhandled_input` 末尾 `index != last` 统一响。
- **status_page `_scroll` 核对原版**：JAH_StatusMenuCore.js:2105 的 PageSelect 是横排命令窗，上下键 cursorUp/Down 因 index < maxCols 不改下标，rpg_windows.js:1018 processCursorMove 只在下标变了才 playCursor → 上下滚动本来就不响，只有左右换页响（重制 `set_page` 已响）。所以不改，豁免写明。

## 变更记录草稿

## 2026-11-05 【cc·rules·未经审查】ui15：小猫剑圣一族说明卡改走 characterHelpView、光标音扫描（dev.待定）

- 小猫剑圣一族（备注含 `<CodexCat:`，技能 10437～10450、物品 2899／2900、法宝 7999）的说明卡用原版夹具量过（新探针 `cat_help_probe.cjs`），旧近似只对上 10 个；改成走 `XCharacterHelp`（原版 characterHelpTarget 就认它们），删掉 help_card 里的近似分支；新专项 `xiyou_cat_help` 34 张卡（有／无 178 两态）逐行对照。
- 光标音扫描：`xiyou_list_paging` 加 `_scan_cursor_sound`，列表移动／翻页函数必须响光标音，6 处豁免都核对过原版（status_page 上下滚动在原版不响）。

## 优化登记草稿

无新增（说明卡是对齐原版，不是改行为）。

## 交接板

- 下一步：ui15 两项完成。接地图事件的话先问总装要哪一段（别和 dead eventsreg2、悟空 accept5 撞）。
- 用户试玩说明：看小猫剑圣的技能／号角／进阶石／抱剑喵铃说明卡，有没有 178 都应与原版一致。
- 需要用户决定：无。

## 进度账

- 部分：无新增。

## 可优化（流程／工具／效率）

- 无


## 验证

- 全过：xiyou_cat_help 35、xiyou_cat 1033、xiyou_cat_trial、xiyou_help_card 1054、xiyou_list_paging 145、xiyou_actor_book、xiyou_battle_ui、xiyou_character_help_cost、xiyou_growth_help、xiyou_toji、xiyou_mira_battle、xiyou_battle_gaps、xiyou_ui_page_details、xiyou_guyu_ui、xiyou_black_flash_ui。
- 选测列了 58 个场景，共用测试槽排队太慢（十个就等了 63 分钟），只跑了与说明卡、角色技能卡、翻页直接相关的 15 个；其余（floor_reach、shop、warehouse 等）未跑，合并时由总装全量／选测补。
- 探针登记检查通过；`cat_help_probe.cjs` 夹具 `cat_help_oracle.json` 是 .sandbox 产物的手工拷贝（头注释写了命令）。
