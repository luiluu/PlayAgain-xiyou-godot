# 交付：cc/tianqi-ending

- 车道／工作者：天启篇·结局收尾（异化图鉴本线页、可轮回结算与读档标记、选线卡已通关）／cc（项目线程「完成再刷西游 Godot 引擎重制」）
- 状态：可合并

## 依赖与合并顺序

- 从 main（dev.494）切出，不依赖待合的分支。和 cc/tianqi-pet-hide、cc/tianqi-alien-affix、cc/tianqi-alien-finale 不碰同一处（本单改 `alien_workshop.gd` 的天启篇那一段之后、`tianqi_alien_gear.gd` 的 `grant` 开头一行；alien-affix 改的是 `tianqi_alien_gear.gd` 详情和文件头，位置不同）。

## 变更记录草稿

## 2026-11-12 【cc·天启篇·未经审查】天启篇结局收尾：异化图鉴本线页、可轮回、选线卡已通关（dev.待定）

- 按设计仓库《天启篇_四线剧情与关卡设计稿 v0.4》第 4 节结局、第 6 节（异化图鉴本线页、可轮回、跨存档乙：图鉴、成就、外观跨档，不带数值）。只认天启篇存档。
- 新模块 `core/tianqi_alien_codex.gd`（XTianqiAlienCodex，开关 `ENABLED`）：赢下的战斗里倒下的本线异化怪点亮「线:种类:级」，存在全局配置新键 `codexTianqiAliens`（`XConfig.tianqi_aliens`／`tianqi_alien_mark`，跨存档）；由 `XTianqiAlienGear.grant` 开头调 `record`。异化工坊页（天启篇存档、选了线）底下多「本线异化图鉴（点亮数／总数）」一节：本线每种一行，四级各一格，打倒过的写级名，没打过的「？？」。
- 结局：36 层第一次打赢骑士，台词（原有的 CC 彩蛋「已完成，已验证。（未经姐姐复核）」）和奖励之后再说一句「战争线·终　本档获得了「可轮回」。」；再挑战不再说。读档界面「天启之路」那行线名后面标「可轮回」（`XSaveScene.can_reincarnate`）。
- 选线竖卡：跨存档通关过的线（骑士徽记）卡上方点亮「★ 已通关」。
- 新专项 `tests/xiyou_tianqi_ending`（17 项）。
- 玩家可见：开发版天启篇里异化工坊能看本线异化图鉴；通关 36 层后读档界面有「可轮回」；再开新档选线时通关过的线卡上有「★ 已通关」。发行版看不到（天启篇关着）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_alien_codex.gd` `XTianqiAlienCodex.ENABLED`；`core/xconfig.gd`（新键 `codexTianqiAliens`）、`core/tianqi_alien_gear.gd`（`grant` 一行）、`ui/alien_workshop.gd`（图鉴一节）、`core/tianqi_line.gd`（可轮回一句）、`ui/save_scene.gd`（可轮回标记）、`ui/tianqi_line_cards.gd`（已通关） | 原版没有天启篇 | 天启篇异化图鉴本线页（跨存档）、结局可轮回结算与读档标记、选线卡已通关 | 四线设计稿 v0.4 第 6 节（Kyo 11-11 定跨存档乙） | `XTianqiAlienCodex.ENABLED = false`：不记也不显示图鉴；可轮回一句和两处标记随天启篇开关 | cc | 已接受（Kyo 11-11 优化直接接受） |

## 交接板

- 下一步：「可轮回」现在只是标记（设计稿：二周目什么都不继承），轮回从哪里开局（标题新游戏？大厅小小鱼？）、开局时有没有提示，设计稿没写，先只做标记和显示；结局演出现在是对话加一句结算，没有专门的画面（等美术）。
- 用户试玩说明：开发版天启篇档打赢几只异化怪后开主菜单「异化工坊」，底下看「本线异化图鉴」；36 层打赢骑士后读档界面线名后面有「可轮回」；开新档到选线，通关过的那条线卡上有「★ 已通关」。
- 需要用户决定：「可轮回」的入口（先只做标记，按现在继续）。

## 进度账

- 天启篇（扩展账）：结局收尾 0 → 异化图鉴本线页、可轮回结算与读档标记、选线卡已通关已接；轮回入口、结局画面未做。不写主表。

## 可优化（流程／工具／效率）

- 无。

## 验证

- `xiyou_tianqi_ending`：17/17。
- 相关专项（Mac，本工作树，`并行测试.py`，17 个场景，108 秒，全部通过）：`xiyou_tianqi_ending`、`xiyou_tianqi_alien_gear`、`xiyou_alien_workshop`、`xiyou_options_basic`、`xiyou_options_misc`、`xiyou_save_page`、`xiyou_save_events`、`xiyou_save_corrupt`、`xiyou_tianqi_look`、`xiyou_tianqi_war`、`xiyou_tianqi_famine`、`xiyou_tianqi_plague`、`xiyou_tianqi_death`、`xiyou_tianqi_summit`、`xiyou_tianqi_rewards`、`xiyou_tianqi_title_flow`、`xiyou_determinism`。
- 没跑的：`xconfig.gd` 让选测判出较多场景；本单只加一个配置键和两个读写函数（照 `codexTianqiBadges` 的写法），其余请总装合并时按选测跑。
- 反向验证（`反向验证.py`，单跑本专项）：不记图鉴、活的也记、开关不管、页面不显示、不说可轮回、每次都说、读档不标、卡不标，8 处全部咬住。
- `语法检查.py`：通过。
- `交付自检.py`：提交后跑，见回报。

## 本分支提交

- 天启篇结局收尾与专项
- 交付单
