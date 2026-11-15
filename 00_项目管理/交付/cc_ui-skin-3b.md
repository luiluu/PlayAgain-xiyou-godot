# 交付：cc/ui-skin-3b

- 车道／工作者：B 界面·新界面第 3B 批（天启篇标题、选线卡、方桌提示、异化工坊）／cc（claude-opus-5-5＋medium，派单定：天启篇入口界面手工排、接选线和异化工坊数据）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·未经审查】新界面第 3B 批：天启篇标题、四线选线卡、方桌提示、异化工坊（dev.待定）

- 玩家可见：无（重制版 0.01.x 发行构建里标题照旧、选线和天启篇异化工坊不开放；西游存档的异化工坊照旧，已逐像素对照）。开发版里：标题的选中项换成红乙选中条、角落按钮换黑面板细线、底部有按键提示；天启篇存档的选线四卡、异化工坊换新界面；大厅方桌面前浮一枚调查提示。
- 依据：派单（3B 行，第 0 期交付单「第 1～6 期拆批建议」）；设计稿私密设计仓 `重制设定/界面风格提案_v0.7/` 第二～四节（这四页稿里没有样稿，按红乙规则与第 0 期组件排）；盘点清册 `xa/ui-audit` 35b648209 #4、#76、#77、#78 与第四节的问题（工坊列表半高、操作区跟着词条行数跳、选线卡小字太小、「再想想」热区小）；小A文字审 ba1f7ed 口径（按键提示套框）。
- 开关：同一个 `XUiSkin.ENABLED`（不另开）。选线卡、方桌提示、异化工坊按 `XUiSkin.on()`（天启篇存档＋发行门）；**标题例外**：标题还没读档，`XTianqiTitle.skin_on()` 按构建判断——开发构建开、发行构建（含 `simulate_release`）不开，`ENABLED`／`FORCE`／`--ui-skin=` 同 `XUiSkin`。`XUiSkin.on()` 本身在标题照旧为假（第 0 期口径不变）。
- 改的文件（都只在开关开着时走新分支，关着时原代码路径不变）：
  - `modes/xiyou/ui/tianqi_title.gd`（#4）：标题美术（底图、Logo、五项两态字图、进场）照旧；T4 光标藏起（位置照算，测试照旧），换成 `XSkinSelectBar` 垫在选中项后、0.09 秒滑动；extras 里的按钮（返回版本选择、继续、导入导出、反馈群号与问卷）换黑面板细线、悬停红乙，**大小不变**（思源黑体行高高，撑高时先压上下内边距、再降字号，不低于 14；entry.gd 按原大小上下叠放的反馈两行不挤）；文字标签换思源黑体次要色；不是触屏时底部居中按键提示。选中、执行、selectLast、进场一律照旧。
  - `modes/xiyou/ui/tianqi_line_cards.gd`（#76）：同样四张卡、同样的字和选择逻辑；黑底＋绯红底光＋火星、卡是黑面板细线（本线颜色留在人像光、分隔线、名字上）、选中卡朱红描边（脉动）＋绯红外晕＋顶上朱红光标、小标题旧金、字换思源黑体／宋体且最小 14（原「骑士遗物」13）、「再想想」黑面板按钮 180×40 居中贴底、右下按键提示；`request_wide`，宽屏卡距 26→最多 48、卡组在安全边距内居中。
  - `modes/xiyou/map/tianqi_table.gd`（#77）：玩家面朝方桌、地图没在跑事件时，桌子上方浮一枚提示胶囊（黑面板细线，左边「确定」键名框，右边旧金字：还没到选线「调查」、该选线「选一条路」、选过了「<线名>之路」；触屏不画键名框），画在人物之上。调查逻辑不动。
  - `modes/xiyou/ui/alien_workshop.gd`（#78，独立样式整页改）：`build()` 节点树、`flatten`、`click`、全部操作一行不改，只换排法：页名「异化工坊」左上（宋体旧金）、资源（淡金）＋合成＋返回右上；一排页签（异化装备／异化核（N）／装备重铸／本线异化图鉴（N／M）／最近异化掉落（N），按 build 里有哪几节，名字取那一节自己的标题），Q／E 换页、可点；「异化装备」页左边全高列表（下面一行说明）、右边详情可滚＋**底部常驻操作栏**（重抽、分解、取核、净化、配置异化，不再随词条行数跳）、确认框和配置在详情最下面（打开时滚到底、焦点放在「确认…」或第一个下拉框）；其余页各一整块面板（不再套盒子）；待选重抽只有两张选择卡居中。颜色：收益→提升绿、代价／出错／分解取核按钮→橙（红只表示选中）、合成重抽确认类按钮旧金细线、说明次要字；列表里当前选中的那件画红乙选中条（旧版照原版首次打开不标，新界面按现在选中的标，节点树不动）。**连带收掉 1C 交付单 P3-1 的异化工坊半换色**：开着新皮肤时工坊不再用 `#16161f` 底、Window 皮肤边框、青色按钮，也不读 `XWebPanel` 的颜色（1C 合入后 `XWebPanel` 换皮对工坊新排法没有影响；关着时工坊仍走 `XWebPanel` 原样）。
  - 新增 `modes/xiyou/ui/skin/skin_button.gd`（`XSkinButton`）：独立小按钮的新界面样式（黑面板细线、主按钮旧金线、危险橙、悬停／焦点红乙选中条且内边距同平时那档，换状态字不跳）。标题、选线、工坊共用；文件名和头注释不带天启篇字样（标题在发行包里是真脚本，会引用它）。
  - `tests/xiyou_ui_skin_3b.gd`／`.tscn`（新专项）；`tests/xiyou_ui_skin_offshot.gd`（关闭对照加 `XTianqiTitle`、`XTianqiLineCards`、`XAlienWorkshop` 三页：标题在西游情形下按发行构建拍，选线卡把脉动钉在同一相位再拍）。
- 发行：标题 `XTianqiTitle` 是 KEEP（真脚本进包），新分支只引用 `XUiSkin`、`XSkinSelectBar`、`XSkinKeyHints`、`XSkinButton`、`ReleaseEntry`，没有直接调天启篇专属类；选线卡、方桌在发行包里本来就是空壳；工坊只调 `XUiSkin`／`XSkin*`。`发行空壳.py check` 通过。发行隐藏（`XAlienHide`／`RELEASE_HIDE`）在主菜单入口那层，工坊页本身没动显隐。
- 返修（小A 乙档核查 5fd436890）：**改了共用组件** `modes/xiyou/ui/skin/skin_key_hints.gd`——1A 主菜单的「让出右下角版本号」（原 `XSkinMainMenu.hint_right`）收进 `XSkinKeyHints.right_edge`，`place()` 自带让位；`XSkinMainMenu.hint_right` 留作转调。受影响的页：主菜单（`skin_main_menu.gd` 改用 `place`，位置不变）、模板页及套它的物品／技能页（`skin_template_page.gd` 改用 `place`，位置不变）、组件陈列页、选线四卡、异化工坊（这三页原来不让位，现在让出版本号）；以后 2B／5C 等用 `place()` 的页自动让位。选线卡未开放的线标「暂未开放」（原「还没修好」，旧画法也一起改，文字审必改，与 xa/text-audit 同字）。工坊换页加 `ui_page_up`／`ui_page_down`（手柄肩键），没绑动作的 Q／E 键照认。
- 验证：见「验证」。

## 新增可见文字（合前请小A文字审）

| 文字 | 在哪 | 说明 |
| --- | --- | --- |
| `↑ / ↓` 选择、`确定` 进入 | 标题底部按键提示（非触屏） | 键名套框 |
| `← / →` 选择、`确定` 选定、`取消` 再想想 | 选线四卡右下按键提示 | 「再想想」沿用原按钮字 |
| 调查、选一条路、「<线名>之路」（如「战争之路」）；键名框「确定」 | 大厅方桌提示胶囊 | 「…之路」沿用调查方桌后小小鱼那句「桌上只剩%s之路的那一道裂纹」的叫法 |
| 异化装备 | 异化工坊第一个页签 | 其余页签名取各节原有标题（异化核（N）、装备重铸、本线异化图鉴（N／M）、最近异化掉落（N）） |
| `Q / E` 换页、`确定` 选择、`取消` 返回 | 异化工坊右下按键提示 | 只有一页时不显示 Q / E |
| 暂未开放（改原「还没修好」） | 选线卡上没做好的线 | 返修：文字审必改；新旧画法都改 |

原有文字只改了「还没修好」→「暂未开放」一处（返修）。

## 交接板

- 下一步：3B 完成（1C 已在 main；新皮肤开着时工坊不读 `XWebPanel` 颜色，1C 的 P3-1 工坊部分收掉）；`xiyou_input_handled` 挂在 `skin_showcase.gd`（见「验证」），main 上同样挂，待修。
- 用户试玩说明：无（天启篇没对玩家开放；发行构建标题照旧）。开发版进标题、天启篇存档在方桌选线、开异化工坊能看到；截图见「验证」。
- 需要用户决定：无。

## 进度账

- 天启篇新界面：页面重排 + 4 项（清册 #4、#76、#77、#78）。

## 验证

- **返修复验（合 main 到 c66438ebc／dev.606 后）**：`xiyou_ui_skin_3b` 有窗口 51/51（新加：选线卡与工坊按键提示右边不超过 `right_edge`、「暂未开放」、工坊 `ui_page_up` 换回第一页）；`xiyou_ui_skin`（p0 的 `hints_place` 改按 `right_edge` 断言，另加版本号关掉时贴安全边距）、`xiyou_ui_skin_menu`（1A 主菜单）、`xiyou_ui_skin_1b`／`1c`／`battle`／`offshot`、`xiyou_tianqi_look`、`xiyou_alien_workshop`、`xiyou_alien_config`、`xiyou_tianqi_title*`、`xiyou_tianqi_alien_gear`、`xiyou_tianqi_e2e`、`xiyou_input_handled` 共 15 个全过（日志 `03_再刷重制_Godot/04_验证/本地结果/并行测试/20261115_111319_ms72okeo/`；`xiyou_input_handled` main 上已修好，现在通过）。`语法检查.py` 0 问题，`发行空壳.py check` 通过。
- **皮肤关闭对照（返修后，基线 main c66438ebc）**：22 张里 21 张 SAME；`xiyou_XTianqiLineCards`、`tq_off_XTianqiLineCards` 各 1119 像素不同，**就是「还没修好」→「暂未开放」这四个字**（文字审必改，旧画法也显示这行字，看过截图，别处无差）。其余页（含主菜单、模板页、装备检索、战斗三张）逐像素一致——关掉皮肤时按键提示不出现，让位搬家不影响。
- 选测对照：`07_开发环境/选测对照.json`（**共用文件**）`ui_skin` 组加 `xiyou_ui_skin_3b.tscn`，改皮肤组件时一起跑 3B 专项。

- 新专项 `tests/xiyou_ui_skin_3b.tscn`：有窗口 48/48（含 12 张截图）、无头 36/36。覆盖：标题 `skin_on()` 开发开／发行关／`ENABLED = false` 关、`XUiSkin.on()` 在标题照旧为假、选中条垫在选中项后且跟着走、extras 换皮且大小不变、按键提示、确定执行同旧、关掉没有选中条且光标照旧；选线卡开着 skin 画法、字不小于 14、卡在安全边距内、左右循环、确定／取消返回值同旧、关掉走旧画法；方桌提示三种字、面朝方桌才显示、忙时／背对／关掉不显示；工坊开着页签（异化装备、异化核、装备重铸…）、列表与操作栏、Q／E 换页再换回、**点屏上的「分解为…」出确认框、焦点在「确认分解」、点「确认分解」真的分解掉一件**、关掉照旧（PaneFrame）、开关两边节点树结构一致。
- **开关关掉与 main 一致**：`python3 03_再刷重制_Godot/07_开发环境/皮肤关闭对照.py --base main`（合 main 后，main＝e3ffadf43，含 1A、1B、1C）→ 主菜单、状态、物品、技能、装备、设置、装备检索、天启篇标题、选线四卡、异化工坊 × 西游存档默认／天启篇存档 `ENABLED = false` 共 20 张逐像素 SAME。合 main 前对分支切出点 17c4ba6b2 也是 16 张全 SAME。
- 选测（本地，`选测.py main --list` 78 个里挑和改动直接相关的 23 个）：ui_smoke、xiyou_alien_config、xiyou_alien_workshop、xiyou_tianqi_alien_gear、xiyou_tianqi_e2e、xiyou_tianqi_ending、xiyou_tianqi_look、xiyou_tianqi_reforge、xiyou_tianqi_title*、xiyou_ui_skin*（含 1a、1b、3b、offshot）、xiyou_ui_input、xiyou_input_handled、xiyou_newgame_back、xiyou_update_check、xiyou_map、xiyou_map_dispatch、xiyou_flow、xiyou_splash_autosave：22 个通过；**`xiyou_input_handled` 挂在 `modes/xiyou/ui/skin/skin_showcase.gd` 直接调 `set_input_as_handled`（1A 带进 main 的，本分支没改这个文件，main 上同样会挂）**——请总装或 1A 返工改成 `XKeyMap.handled(self)`。日志 `03_再刷重制_Godot/04_验证/本地结果/并行测试/20261115_084800_r6j56xxy/`。其余 55 个（楼层、事件对照四片、地图）是因为改了 `modes/xiyou/map/tianqi_table.gd` 被按目录选上，本地没跑：方桌只多一个只在 `XUiSkin.on()` 时显示的胶囊节点，调查逻辑没动。
- 给总装：`合并车道.sh --finish --affected --cloud`。
- `语法检查.py`：0 个问题。`发行空壳.py check`：通过。`工具回归.py`：全部通过（96 秒）。
- 截图（git 忽略目录 `03_再刷重制_Godot/04_验证/本地结果/ui_skin_3b/`）：`ui_skin_3b_title_16x9.png`／`_20x9.png`、`ui_skin_3b_line_cards_16x9.png`／`_20x9.png`、`ui_skin_3b_table_chip_16x9.png`／`_20x9.png`（黑底上看胶囊）、`ui_skin_3b_alien_workshop_16x9.png`／`_20x9.png`、`ui_skin_3b_alien_workshop_tab2_*`（异化核页）、`ui_skin_3b_alien_workshop_confirm_*`（分解确认框）；`关闭对照/base`、`关闭对照/branch` 各 20 张。

## 要注意的

- 标题按构建开新界面（开发构建就开），和别的页「天启篇存档才开」不同：标题没读档，没法按存档判断；发行构建恒关，重制版玩家看到的不变。若 Kyo 要开发版标题也默认旧样子，把 `XTianqiTitle.skin_on()` 最后一行改成 `return false` 即可。
- 选线卡、标题在 20:9 下：选线卡 `request_wide` 横向铺开；标题没有 `request_wide`（底图本来按 cover 铺满，菜单居中），20:9 截图是窗口按原拉伸方式显示的样子。
- 已合 main 到 e3ffadf43（1A、1B、1C 都在）：`tests/xiyou_ui_skin_offshot.gd` 和 1B、1C 的冲突已解（页名单并在一起）；合 1C 后重跑 3B 专项、1b／1c 专项、装备检索、工坊三个旧专项、关闭对照，全过。

## 可优化（流程／工具／效率）

- 已做：`tests/xiyou_ui_skin_offshot.gd` 对带时间动画的页（选线卡）钉住相位再拍，免得关闭对照因动画相位误报（回退：删那四行）。
- 建议：`皮肤关闭对照.py --base main` 在本地 main 比车道新（别的批已合进 main）时，基线克隆拷的是车道的 `.godot` 缓存，main 新增的全局类（如 `XSkinSkillPage`）认不出、整页编不过；建议脚本在基线克隆里先跑一次 `--import` 或只在 `--base` 是车道祖先时直接拷缓存（小，归工具车道）。车道先合 main 再比可绕开。

## 本分支提交

- 返修：见 `git log 5fd436890..cc/ui-skin-3b`（按键提示让位收进 XSkinKeyHints.place、暂未开放、工坊手柄换页、选测对照；合并 main 到 dev.606）。

- 见 `git log main..cc/ui-skin-3b`（WIP 标题、选线卡、方桌提示、异化工坊新界面；专项与版面修正；关闭对照加三页；合并 main；标题角落按钮保持原大小）。

## 小A 乙档核查

- 核查对象：`cc/ui-skin-3b`（交付提交 `c3f3ce8bc`，已合 `main` `e3ffadf43`），执行者：小A（只读核查、未改游戏代码，仅前台运行轻量检查）。
- **结论：不通过**（P1 零条、**P2 1 条**、P3 2 条；**文字必改 1 条**；`xiyou_input_handled` 挂在 `main` 既有 `skin_showcase.gd` 属实，待 1A 或总装修）。

### 核查项与核实深度

1. **开关与标题发行安全（核了规则本身＋跑专项＋跑发行空壳检查）**：
   - 皮肤关时四页走旧分支：实跑无头 `tests/xiyou_ui_skin_offshot.tscn` 20/20 通过，`--compare` 比对既有 `关闭对照/base` 与 `branch` 20/20 全 `SAME`；源码对照 `e3ffadf43` diff 确认 `ENABLED = false` 或西游档下四页均不建／不显 `skin_*` 节点。
   - 标题按构建开新皮肤（`XTianqiTitle.skin_on()`，`modes/xiyou/ui/tianqi_title.gd:96-104`）：标题在读档前运行（`XState.current == null`，此时 `XUiSkin.on()` 恒为 `false`），按构建切换（开发构建开、发行构建 `ReleaseEntry.is_release()` 恒关；`XUiSkin.cli_mode()` 在发行构建亦忽略 CLI 参数）做法正确。实跑 `tests/xiyou_ui_skin_3b.tscn` 36/36、`tests/xiyou_tianqi_title.tscn` 46/46、`tests/xiyou_entry_release.tscn` 16/16 通过。
   - 发行包不会露天启篇或新皮肤内容：实跑 `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check` 通过（58 脚本、493 函数），`syntax` 校验 `python3 03_再刷重制_Godot/07_开发环境/语法检查.py` 0 问题（908 `.gd`）；`XTianqiTitle` 为 `KEEP`，本次改动与新增 `XSkinButton`（`modes/xiyou/ui/skin/skin_button.gd`，文件名与头注释无天启字样）仅引用 `XUiSkin`/`XSkinSelectBar`/`XSkinKeyHints`/`XSkinButton`/`ReleaseEntry`/`XPlatform`/`XSound`，未引入天启篇专属类或资源，发行构建下 `skin_on()` 恒假不加载 `content/ui_skin/*`（且已由 `发行内容审计.py` `DENY` 排除）。
2. **操作逻辑未改与方桌提示（只看 `e3ffadf43..c3f3ce8bc` 全量 diff＋跑专项）**：
   - `tianqi_line_cards.gd` 的 `_handle`、`pick`、`decided` 信号与按键／鼠标选择逻辑未改；`alien_workshop.gd` 的 `build()`、`flatten()`、`click()`、重抽／分解／取核／净化／配置（`_act`、`_select`、`_confirm`、`_confirm_core`、`_dismantle`、`_extract_core`、`_core_section`、`_reforge_section`、`_codex_section`、`_config_section`、`set_value` 等）一行未改，仅在 `skin` 分支重排同棵 DOM 节点并收掉 1C P3-1 工坊半换色（改用 `XUiSkin.panel_style()` 与 `XSkinButton`，不再读 `XWebPanel` 配色、`#16161f` 底与青色按钮）；`modes/xiyou/map/tianqi_table.gd` 仅新增 `chip`（`_Chip`，`z_index = 200`）、`chip_text()` 与 `_update_chip()`，调查逻辑、`wanted`、`refresh` 未动。实跑 `xiyou_alien_workshop.tscn`（45/45）、`xiyou_alien_config.tscn`（95/95）、`xiyou_tianqi_reforge.tscn`（16/16）通过。
3. **异化工坊发行隐藏（只看源码）**：
   - 全库检索确认 `XAlienBattle.RELEASE_HIDE := true`、`XAlienBattle.hidden()`（`alien_battle.gd:69-74`）、`XAlienHide`（`alien_hide.gd`）、`XMenu.commands()`（`menu.gd:63,496`）与 `XUiSkin.hide_rule("alien")`（`ui_skin.gd:592`）均未修改，发行隐藏未被破坏。
4. **协调截图发现两项（只看源码＋git 历史追溯）**：
   - **① 选线卡「瘟疫·混子」剪影写「还没修好」**：位于 `modes/xiyou/ui/tianqi_line_cards.gd:282`，为旧代码既有文案，**非 3B 新写**。`github/ci/xa/text-audit`（`10577b912` 文字审 `1-012`）已将该处改为 **`暂未开放`**（并同步在 `1-011` 将 `tianqi.gd:697` 改为 `……这条路暂未开放，换一条吧。`），但 `xa/text-audit`（`565fbeeb7`）尚未合入 `main`／本分支。改好文字：**`暂未开放`**。
   - **② 选线卡、异化工坊右下按键提示压住版本号 `dev.601`**：确认属实，详情见下 **P2-1**。
5. **`xiyou_input_handled` 挂在 `skin_showcase.gd`（跑专项＋只看源码与 git diff）**：
   - 实跑 `tests/xiyou_input_handled.tscn` 9/10，唯一失败为 `no_direct_set_input_as_handled ["res://modes/xiyou/ui/skin/skin_showcase.gd"]`（第 162、166、169 行直接调用 `get_viewport().set_input_as_handled()`）；`git diff e3ffadf43..c3f3ce8bc` 确认本分支未触碰 `skin_showcase.gd`（1A 带入 `main`），车道说明属实。
6. **文字审（按 `ba1f7ed` 口径核交付单表＋四页可见字串＋字集检查）**：
   - **交付单表与新字**：`tianqi_title.gd:183`（`[["↑ / ↓", "选择"], ["确定", "进入"]]`）、`tianqi_line_cards.gd:124`（`[["← / →", "选择"], ["确定", "选定"], ["取消", "再想想"]]`）、`tianqi_table.gd:108-117`（`"调查"`、`"选一条路"`、`"<线名>之路"`、键名框 `"确定"`）、`alien_workshop.gd:1278,1300-1302`（`"异化装备"`、`异化核（N）`、`装备重铸`、`本线异化图鉴（N／M）`、`最近异化掉落（N）`、`[["Q / E", "换页"], ["确定", "选择"], ["取消", "返回"]]`）表码一致；键名框、斜杠空格（`Q / E`、`↑ / ↓`、`← / →`）与 `确定`/`取消` 口径符合 `ba1f7ed`；`tianqi.gd:623-637` `LINES` 传闻与本线特点无问题；全部新增可见字均在 `charset_hei.txt`／`charset_song.txt` 中（缺失 0 字）。
   - **既有未合入文字**：除必改 **`"还没修好"` → `"暂未开放"`**（`tianqi_line_cards.gd:282`）外，`alien_workshop.gd` 旧 `build()` 内的 `金钱`→`精魂`、`几率`→`概率`、`穿着的`→`已装备` 等修改已在未合入的 `github/ci/xa/text-audit`（`565fbeeb7`）中，待文字审分支合入。

### 问题清单（P1/P2/P3）与文字必改

- **P1**：无。
- **P2-1（右下按键提示压住版本号 `dev.601`）**：`XVersionLabel`（`core/version_label.gd:8-9,35-39`）固定显示在视口右下（`MARGIN = (10, 6)`，`FONT_SIZE = 14`）；而 `XSkinKeyHints.place(view)`（`modes/xiyou/ui/skin/skin_key_hints.gd:35-36`）直接贴安全右边距 `view.x - XSkinLayout.margin_for(view.x) - total_width()`（`y` 落在 `view.y - 32..view.y - 10`），未给版本号让位，导致 `tianqi_line_cards.gd:168`、`alien_workshop.gd:1304`（及 `skin_showcase.gd:132`）的提示压住 `dev.601`；1A（`skin_main_menu.gd:245,252-257`）与 1B/1C/2B（`skin_template_page.gd:179`）此前是通过 `XSkinMainMenu.hint_right(view)` 各自绕开。**建议**：将让位逻辑统一收口进 `XSkinKeyHints.place(view)`（`modes/xiyou/ui/skin/skin_key_hints.gd:35-36`，当 `XVersionLabel.SHOW` 时取 `minf(safe_right, view.x - XVersionLabel.MARGIN.x - vw - 16.0)`），并让 `skin_main_menu.gd:245` 与 `skin_template_page.gd:179` 改调 `hints.place(view)`，统一解决各页（含 1A/2B/3B）重叠问题。
- **P3-1（工坊页签未绑手柄换页动作）**：`alien_workshop.gd:111-113` 仅处理 `KEY_Q` / `KEY_E`，未同步绑定 `ui_page_up` / `ui_page_down`。
- **P3-2（选测对照分组未收录）**：`03_再刷重制_Godot/07_开发环境/选测对照.json` 的 `ui_skin` 分组暂未加入 `xiyou_ui_skin_3b.tscn`。
- **文字必改（1 条）**：`modes/xiyou/ui/tianqi_line_cards.gd:282` `"还没修好"` → **`"暂未开放"`**（需合入 `xa/text-audit` 或就地改正，避免玩家在未开放路线看到「还没修好」）。

### 没核到的（留给总装 `--affected --cloud`）

- 有窗截图实观与重拍比对（本次未装 PIL、未跑 `xiyou_ui_skin_3b.tscn -- --out=...` 与 `皮肤关闭对照.py --base main` 重拍，仅就既有 `关闭对照` 运行 `--compare` 20/20 `SAME` 并以源码核坐标）；
- 其余长测试：选测余下 55 个场景（楼层、事件对照四段、地图等）与 `并行测试.py`、`工具回归.py`。

## 小A 复核

- **复核对象**：`cc/ui-skin-3b` 返修提交 `7d9e77eb4`（含返修代码 `6be4844a9` 及合并 `main` `c66438ebc`/dev.606 的 `dff5eb3de`；对比上次核查提交 `5fd436890`），执行者：小A（只读复核、未改游戏代码）。
- **结论：通过**（**P1 0 条**、**P2 0 条**、**P3 0 条**、**文字必改 0 条**；原 P2-1、P3-1、P3-2 及文字必改「暂未开放」全部解决，未带入新问题）。
- **逐项复核**：
  1. **按键提示让位收进共用组件（通过）**：`modes/xiyou/ui/skin/skin_key_hints.gd:35-46` 新增静态方法 `right_edge(view)`（与原 `XSkinMainMenu.hint_right(view)` 算法一致：`minf(view.x - XSkinLayout.margin_for(view.x), view.x - XVersionLabel.MARGIN.x - vw - 16.0)`），`place(view)` 改按 `right_edge(view) - total_width()` 定位；`skin_main_menu.gd:245,252-253`（`hint_right` 留作转调 `XSkinKeyHints.right_edge`）与 `skin_template_page.gd:178` 均改调 `hints.place(view)`，位置不变；选线卡（`tianqi_line_cards.gd:168`）、异化工坊（`alien_workshop.gd:1312`）及组件陈列页（`skin_showcase.gd:132`）均调用 `place(view)`，现已全部让出右下角版本号（`xiyou_ui_skin.gd:318-322`、`xiyou_ui_skin_3b.gd:171,313`、`xiyou_ui_skin_menu.gd:125` 实测通过）。
     - **给总装的跨分支影响面**：
       - **1B／1C（已在 `main`：`skin_item_page.gd`、`skin_skill_page.gd`、`skin_status_page.gd`、`skin_equip_page.gd`）**：均继承 `XSkinTemplatePage` 且子类 `relayout()` 只调 `super()` 后排自身左右区域、不覆写 `hints.position`，此前已套 `XSkinMainMenu.hint_right`，改用 `hints.place(view)` 后**位置完全不变**。
       - **5C（`cc/ui-skin-5c` 设置页 `skin_options_page.gd`）**：继承 `XSkinTemplatePage` 且未覆写 `relayout()`，此前走模板页 `XSkinMainMenu.hint_right`，合流后**位置完全不变**，且未改 `tests/xiyou_ui_skin.gd:317`，无冲突。
       - **2B（`cc/ui-skin-2b` 战斗中查看状态页 `skin_party_status.gd:115`）**：`_relayout()` 直接调用 `hints.place(view)`（2B 其余 `skin_battle*`/`skin_boss_*`/`skin_otb_bar`/`skin_side_status` 不用 `XSkinKeyHints`）。3B 合 `main` 后，2B 状态页右下按键提示会**自动左移让出右下角版本号**（修掉其原本可能压版本号的隐患）；`cc/ui-skin-2b` 测试未断言 `hints.position` 精确像素，也不冲突。
       - **3A（`cc/ui-skin-3a` 祭坛页 `tianqi_skin_altar.gd:217`）**：直接调 `XSkinMainMenu.hint_right(v)`，因留作转调，**位置不变**且兼容。
       - **天启篇标题（`tianqi_title.gd:305`）**：底部居中摆放，不调 `place()`，**位置不变**。
  2. **选线卡「还没修好」→「暂未开放」（通过）**：`modes/xiyou/ui/tianqi_line_cards.gd:282`（`_make_card()` 新旧画法共用构造）已改为 `"暂未开放"`；`charset_hei.txt`／`charset_song.txt` 均覆盖该 4 字（缺 0 字），`xiyou_ui_skin_3b.gd:172`（`cards_unready_text`）通过。对既有 `04_验证/本地结果/ui_skin_3b/关闭对照/{base,branch}` 跑 `--compare` 得 21/23 `SAME`（交付单前文写作「22 张里 21 张」系总数笔误，实为 `tq_off` 10 页＋`xiyou` 13 页共 23 张），仅 `xiyou_XTianqiLineCards.png` 与 `tq_off_XTianqiLineCards.png` 各差 1119 像素；逐像素解码比对两图差异包围盒均为 `(741, 254, 813, 272)`（1280×720 下第 3 张未开放卡中央 `72×18` 像素标签区域），**确认 100% 只差「还没修好」→「暂未开放」四字**。检索确认 `XTianqiLineCards` 仅由 `map_scene.gd:399`／`tianqi.gd:681` 在天启篇选线调用，且在 `07_开发环境/发行空壳特例.json:32` 列为空壳，**只在天启篇出现，重制版玩家看不到**。
  3. **工坊手柄换页与 `选测对照.json`（通过）**：`modes/xiyou/ui/alien_workshop.gd:111-123` 在 `if skin and skin_tabs.size() > 1:` 下以互斥 `if/elif` 顺序接住 `ui_page_up`（-1）、`ui_page_down`（+1）与未绑动作时的 `KEY_Q`/`KEY_E`（防重复触发，且走 `XKeyMap.handled(self)` 消费，关闭皮肤时不走该分支）；`xiyou_ui_skin_3b.gd:306-311`（`ws_tab_back_pageup`）通过。`03_再刷重制_Godot/07_开发环境/选测对照.json:14` 的 `ui_skin` 组 `scenes` 已加入 `xiyou_ui_skin_3b.tscn`。
  4. **diff `5fd436890..7d9e77eb4` 回归检查（通过）**：除 `dff5eb3de` 合并 `main` 到 `c66438ebc`（仅 `tests/xiyou_ui_skin_offshot.gd` 有三方合并且已跑通）外，返修提交 `6be4844a9`、`7d9e77eb4` 仅触及上述 5 个游戏/测试/配置脚本、2 个测试与交付单，未带入新问题。
- **前台轻量化实测**：`语法检查.py`（915 个 `.gd` 0 问题）、`发行空壳.py check`（59 脚本 500 函数通过）、无头专项 `xiyou_ui_skin.tscn`（89/89）、`xiyou_ui_skin_3b.tscn`（39/39）、`xiyou_ui_skin_menu.tscn`（58/58）、`xiyou_ui_skin_offshot.tscn`（21/21，含对既有 `关闭对照` 运行 `--compare` 21/23 SAME＋2 张选线卡各 1119px）、`xiyou_ui_skin_1b.tscn`（85/85）、`xiyou_ui_skin_1c.tscn`（78/78）、`xiyou_input_handled.tscn`（10/10）、`xiyou_alien_workshop.tscn`（45/45）、`xiyou_alien_config.tscn`（95/95）、`xiyou_tianqi_look.tscn`（59/59）全部通过。
- **没核到的（留总装 `--affected --cloud`）**：未跑 `并行测试.py`、`工具回归.py`、`选测.py` 其余场景（含 `xiyou_tianqi_e2e`、楼层及事件对照四片）、未在当前机器重拍有窗截图（`xiyou_ui_skin_3b` 有窗 51/51 与 `皮肤关闭对照.py --base main` 23 张重拍）。

