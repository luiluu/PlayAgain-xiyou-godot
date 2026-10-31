# 交付：cc/bajie-toji1

- 车道／工作者：C 规则／八戒（Claude，八戒_92 开分支后交接）
- 状态：进行中
- 分支从 cc/bajie-blackflash 末端 3d530eb8 切（总装六交代），工作树 `.claude/worktrees/compassionate-gagarin-ec734e`。

## 交接（八戒_92 → 下一位八戒）

八戒_92 本会话已交宿傩第二期、黑闪期，上下文到 41%，按规矩不开大活，只切了分支、写了这一节。接手者从这里开工：

- 任务（总装六原话要点）：甚尔 171 移植期一。参照冻结 v0.28 `js/codex/runtime/installNativeTojiRuntime.js`（33 KB，prettier 后约 1080 行）。第一步把原版机制清单与重制现状对成表写进下面「机制对照」，按收益排期。
- 期一（先交、可合并）：招募／开机同步／能力值与基础伤害公式，加上和 XBlackFlash 的接线（`core/black_flash.gd` 已登记 171 配置：触发 10216～10219、觉醒技 10226、状态 2635；觉醒时 10216 额外一击 `_tojiHitCount`＋1 留给甚尔模块做；甚尔要学到 10225 才启用，原版由黑闪 unlock 在 setup／levelUp 学）。照 `garou.gd` 第一期写法，新文件 `core/toji.gd`，文件头写已移植／未移植；接入点参照 `sukuna.gd` 第一期（`actor_modules.gd`、`formula_execution.gd` 模块公式、`actor_damage_hooks.gd`、`mv_script.gd` 招募）。`actor.gd` 已有甚尔普攻形态（TOJI_MAIN／TOJI_SHAPES）。
- 期二起：战斗内专属机制，做不完写下期清单；画面侧只出逻辑记录，写进「下期」交画面车道。
- 参照探针对原版（mv_oracle 只写 `.sandbox/`），专项含反向验证；O 号用占位进「## 优化登记草稿」表，没有就写「优化登记草稿：无」。改了 battle_logic／actor／battler／damage／xstate 要点名。
- 不碰：`garou.gd`（白龙_7 在做饿狼第二期）、`raven.gd`、`mira.gd`。
- 验证：专项＋选测本机跑（GitHub Actions 11-01 前用不了），本机同时测试最多 2 条车道，跑前看占槽（主工作区 `检查.sh` 在跑时会排很久）。
- 停手：要等别的未移植系统才能做的，跳过写进交付单。
- 经验（八戒_92）：探针写法见 `mv_oracle/sukuna_battle_probe.cjs`——新局里 `$gameParty.addActor` 对非初始角色无效，直接写 `_actors`／`_battleMembers`；超强角色出战要开开关 2494；`BattleManager.endTurn` 前把 `_enteredEndPhase` 置 false。新 class_name 文件要先 `godot --headless --path 01_Godot工程 --import` 才认得。Parse Error 时 `并行测试.py` 会空等 600 秒，先直接跑单个场景。55 级专属角色伤害恒为原版 0.96079 倍是已知的五乘区差（Kyo 10-27 定不移植），专项按比值比。
- 回报发总装六（local_d96f72ab-eeec-4265-9505-798906c3eb37），只在可合并、卡住、要新车道时发。

## 机制对照

（待写）

## 变更记录草稿

（待写）

## 本分支提交

（待写）
