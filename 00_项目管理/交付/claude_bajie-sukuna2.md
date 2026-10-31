# 交付：claude/bajie-sukuna2

- 车道／工作者：C 规则／八戒（Claude，八戒_91 开分支后交接）
- 状态：进行中
- 分支从 claude/bajie-shaseng-p2 末端 a05a72b7 切（唐僧交代），带着 warehouse、alien-leftover、shaseng-p2 三条的提交。

## 交接（八戒_91 → 下一位八戒）

八戒_91 本会话已连交三期，上下文过 40%，按规矩不开大活，只切了分支、写了这一节。接手者从这里开工：

- 任务（唐僧原话要点）：宿傩第二期，把 `modes/xiyou/core/sukuna.gd` 文件头第 20～22 行列的「未移植」战斗内机制按冻结 v0.28 `js/codex/runtime/installNativeSukunaRuntime.js`（W.CodexSukuna，约 20 KB）补上，先做影响伤害的：施放帧 `_sukunaCast`／`_sukunaPart`（`damage` 第 93 行注释说没有）、神灶准备层（第 102 行恒 0）、领域展开、魔虚罗适应层（恒 0）、伤口（受治疗减半）；黑闪要和甚尔共用就抽成共用模块（CodexBlackFlash）。
- 第一步：把原版机制清单与重制现状对成一张表写进本交付单（下面「机制对照」节），一期做不完就分期，写下期清单。
- 参照探针对原版（mv_oracle 只写 `.sandbox/`），专项含反向验证；O-待定 写进「## 优化登记草稿」表，不直接改优化登记；改了原沙僧核心文件（battle_logic／actor／battler／damage／xstate）要在交付单点名。
- 撞车提醒：白龙在 `battle_logic.gd` 加渡鸦钩子，悟空在改 skill_cost／上限／伤害链；改 battle_logic 前先 `rg` 对一下。
- 选测超过 40 个场景走云端（`云端选测.py run`＋`wait`）；本机同时最多 2 条车道跑测试。
- 回报发给唐僧总装 五（local_f30544cb-6325-4e44-a095-a54d8f831b39），只在可合并、卡住、要新车道时发。

## 机制对照

（待写）

## 变更记录草稿

（待写）

## 本分支提交

（待写）
