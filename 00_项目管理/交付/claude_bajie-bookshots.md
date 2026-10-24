# 交付：claude/bajie-bookshots

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_64）
- 状态：可合并

## 变更记录草稿

## 2026-10-24 【Claude·八戒_64·未经Codex检验】怪物图鉴与战斗内图鉴成对截图补证、修炼「修炼」位置、异化工坊焦点框、截图模式不读开发档设置（dev.待定）

- **补证**：上轮没补的怪物图鉴菜单与战斗内图鉴入口两批补上标准级成对截图，外加修炼底部窗。原版重放 `ui_reference/review_system_pages.js` 加 `enemy_book`（照 enemy_book_oracle 的 setup，走 Scene_EnemyBook 目录与掉落）、`training`、`battle_book`（地图 5、敌群 2、难度 3，角色指令窗按原入口打开；排在最后，因为进战斗后回不到下一页的新局）；来源身份多记 AB_EnemyBook、EliteEnemy、EnemyNameColorByDifficulty。Godot 侧 `xiyou_enemy_book`、`xiyou_battle_ui` 的截图点加窗口读数（`xiyou_enemy_book` 截图前清掉前面操作留下的「未解锁」提示条）。`review_system_pages_compare.py` 加图鉴三态矩形、说明卡位置与宽、修炼空格宽，**80/80**。结论写在 [核查补证_20261024_系统批成对截图](../核查补证_20261024_系统批成对截图.md)「八戒_64 续补」：图鉴两批一致（说明卡高是已登记 O-007），修炼查出差异已修。
- **修炼底部「修炼」**（八戒_60 留的剩余差异）：原版用 44 个空格推到中间，原版字体下实测宽 317.28；本工程字体空格窄，偏左约 8 像素。`XTrainingScene` 绘制时把行首空格按原版空格宽（`SPACE_W`）折成横坐标，行文与 fixture 不变。
- **异化工坊焦点框**：原版重画后不聚焦任何按钮，焦点框只在键盘操作后画（`:focus-visible`）。Godot 原来一打开就在第一个按钮画框，现改为 `grab_focus(true)`：焦点仍在首键、不画框，方向键移动后才画。预先聚焦算优化 **O-089**（`XAlienWorkshop.focus_first = false` 回退为不聚焦），已登记优化登记。
- **截图模式不读开发档设置**：18 个带 `--out=` 的专项里，只有 `xiyou_system_evidence` 自己隔离了设置，其余的会读本机 `user://modes/xiyou/options.json`（如 `codexPowerEnabled:false` 让截图少「装备战力」行）。改在 `XConfig.path()` 一处统一：命令行带 `--out=` 时（`XConfig.screenshot_mode()`）只用内存默认值，不读也不写 options.json。游戏本身不会带这个参数。
- 验证：见交付单「验证」。
- 提交：见「本分支提交」。
- 未完成／已知问题：无。图鉴 P2 击败数（规则，沙僧52）不在本任务。

## 交接板

- 下一步：无新增。待交叉核查加本分支提交（见下）。
- 用户试玩说明：修炼界面底部「修炼」二字位置与原版一致；异化工坊打开时不再在第一个按钮上画亮框（按方向键后才出现）。
- 需要用户决定：O-089（异化工坊打开时预先聚焦第一个按钮，画面与原版相同、只是不用先按 Tab），待用户决定。

## 进度账

- 无变化（补证与界面小修）。

## 验证

- headless 专项（`并行测试.py`，单次通过、无偶发）：xiyou_alien_config 95/95、xiyou_alien_workshop 44/44（加 O-089 回退断言后单跑 45/45）、xiyou_battle_options 92/92、xiyou_battle_ui 70/70、xiyou_crafting 49/49、xiyou_enemy_book 52/52、xiyou_options_basic 139/139、xiyou_options_misc 86/86、xiyou_panels 35/35、xiyou_pets 27/27、xiyou_power 137/137、xiyou_system_evidence 15/15、xiyou_training 188/188。
- 窗口模式取证（`--out`）：xiyou_system_evidence 16/16、xiyou_crafting 49/49、xiyou_pets 27/27、xiyou_alien_workshop 44/44、xiyou_alien_config 95/95、xiyou_enemy_book 52/52、xiyou_battle_ui 90/90、xiyou_training 188/188；原版重放 23 态无引擎错误、来源身份前后一致；核对 80/80。
- 没跑全量 `检查.sh`。
- **证据目录保留到合并后由总装处理**（不入 Git）：工作树 `03_再刷重制_Godot/04_验证/本地结果/bajie-bookshots/`（`formal/`、`godot/`、`compare.json`、`logs/`）。其他临时输出（中途的探针截图、裁图、旧日志）已删，参照服务已停。

## 本分支提交

- `13ee8057` 怪物图鉴与战斗内图鉴成对截图：原版重放两页、Godot 窗口读数、核对脚本
- `d325fdfe` 修炼底部「修炼」按原版实测空格宽定横坐标；原版重放加修炼页
- `5344b37f` 异化工坊焦点框照原版 :focus-visible
- `695553d1` 截图模式（--out=）统一只用内存默认设置
- `bc84e935` 截图模式判断改用循环；原版重放战斗页挪到最后
- `f7de89fd` O-089 可回退并登记
- `036941d9` 补证汇总追加、ui_reference README、移除已并入的旧交付单 `claude_bajie-evidence.md`
- 本交付单提交
