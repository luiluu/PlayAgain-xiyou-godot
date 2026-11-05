# 交付：cc/rules-ui15

- 车道／工作者：B 界面／rules 线程（cc，ui15）
- 状态：进行中（上下文到线，写接续；本分支除本文件外没有新改动）

## 接续要点（下一个会话从这里开始）

分支 `cc/rules-ui15` 是从 `cc/rules-ui14`（15341fa5）切的，已 `--补齐`。ui14 合进 main 后先 `git merge main`。

### ① 技能说明卡完整版（派单 BD ①）

- 已查清：characterHelpView **已经移植**了，在 `modes/xiyou/ui/character_help.gd`（XCharacterHelp），管专属角色技能 10122～10299。剩下的缺口只在**小猫剑圣**这一族。
- 原版 `characterHelpTarget`（冻结源 `js/codex/runtime/installDisplayPreferencesRuntime.js:140`）：note 含 `<CodexCat:` 的也走 characterHelpView，先 `CodexCat.helpItem(item, actor)`（:367）。冻结 v0.28 里这样的有技能 14 个（10437～10450）、物品 2 个（2899、2900）、防具 1 个（7999）。
- 重制现在的做法：这 17 个不走 XCharacterHelp，在 `help_card.gd` 里走 genericHelpView 再近似修补（:467 currentHelpText 换 C.helpText、:491 目标排在伤害属性前、:519～520 伤害属性行去掉 `\C[n]`、字号取 14）。只对照过参照里的 10437、10438。
- 要做：
  1. 用 `ui_reference` 浏览器夹具（静音）量原版这 17 个的 characterHelpView 结果，看文字、分行、高度、图标。可以照 `tests/fixtures/*_oracle.json` 已有的写法，比如 character_help 一类的探针；先 `rg characterHelp 03_再刷重制_Godot/01_Godot工程/tests mv_oracle` 看已有的夹具和探针能不能扩。小猫有没有 178 号角色会改变结果（`XCat.help_actor`），两种情况都要量。
  2. 和重制比。差了就让 cat 物件改走 XCharacterHelp（前面加 `XCat.help_item`），删掉 help_card 里的近似分支，写一个新专项逐项对照夹具。
- 先跑 `xiyou_cat`、`xiyou_actor_book*`、`xiyou_battle_ui` 等用到 help_card 的专项打底，`选测.py main --list` 会列全。

### ② 光标音扫描（派单 BD ②，ui14 可优化）

- 在 `tests/xiyou_list_paging.gd` 的 `_scan()` 旁边加一个扫描：`modes/xiyou/ui/*.gd` 里名叫 `_move`／`move`／`_move_list`／`page`／`_page` 的函数，函数体里要有 `XSound.system(0)`，或者调到的 `select`／`_select`／`_cursor_se`／`_page_set` 里有。豁免写明原因。
- ui14 时扫过一遍（读码），各页结果：
  - 都有光标音：achievement、actor_advanced、actor_warehouse、change_clothes、choice_window、costumes、crafting、equip、inlay_book、party、pets、save、skill、star_warehouse、training、warehouse。
  - 经 select 间接响：actor_book、enemy_book、achievement。
  - 在输入处响：menu.gd。
  - ui14 补的：item_scene、shop。
  - status_page 的 `_scroll` 没响，要核原版 JAH 状态页上下滚动响不响。
  - `XBattleList`（战斗）在 `modes/xiyou/battle/`，也一起扫。

## 变更记录草稿

（待写）

## 交接板

- 下一步：照上面接续要点做 ui15 ①②；做完如有额度接地图事件，先问总装要哪一段（别和 dead eventsreg2、悟空 accept5 撞）。
- 用户试玩说明：本分支暂无改动。
- 需要用户决定：无。

## 进度账

- 部分：无新增（只做了范围核查）。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- （本文件）
