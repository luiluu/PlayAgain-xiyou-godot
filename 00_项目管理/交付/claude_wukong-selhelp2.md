# 交付：claude/wukong-selhelp2

- 车道／工作者：C 规则·机制（战斗选目标、参数缓存调查）／悟空_64（Claude）
- 状态：可合并

从 main fd9a1ad2 切出。期一：选目标时的指令窗对原版；期二：减益后参数缓存差异，只做了只读调查和提案，没改核心文件。

## 期一：选目标时的指令窗

### 原版依据（冻结 v0.28，ui_reference 实测）

上期「遗留」写的是「原版选目标时指令窗仍显示」，这句**不对**：当时只看了 `visible`。这次逐帧读了不透明度，原版其实是把指令窗淡出了：

- `Olivia_SideBattleUI.js:428–437`：选敌窗或选我方窗处于激活状态时，每帧调用指令窗、技能窗、物品窗的 `updateFadeOut`。
- `:595–598` `updateFadeOut`：`opacity`、`contentsOpacity` 每帧减 16。指令窗不 hide，只是停用（`active` 为假）。
- 实测（四人战斗夹具，美娜行动）：
  - 「攻击」或技能确定后，指令窗逐帧读数是 239、223、…、15、0，第 16 帧到 0；`visible` 一直是 true，`active` 为假。
  - 技能窗在 onSelectAction 时 hide（不淡出）。
  - 说明卡（Sprite_ItemHelp）不可见，所以不存在叠放次序问题。
- 取消回来：`updatePosition`→`updateFadeIn`，下一帧不透明度就是 255（攻击路径时指令窗重新激活；技能路径回到技能窗，指令窗显示但不激活，光标不闪、alpha 1）。
- 截图 `selhelp2_attack`、`selhelp2_skill_list`、`selhelp2_skill_target` 只存在本机 scratchpad，没入 Git，已删除。

### 重制落点

- `battle_scene.gd` `_pick_target`：
  - 选目标时不再 `cmd_win.visible = false`，改成停用指令窗（`active = false`）。
  - 用 Tween 在 `CMD_FADE_FRAMES`（16）/60 秒内把 `modulate.a` 从 1 淡到 0。
  - 选完或取消时停掉 Tween，`modulate.a` 立刻恢复成 1，`active` 还原成进来时的值。攻击路径还原为激活；技能、物品路径本来就是停用，保持停用。
- 新常量 `CMD_FADE_FRAMES := 16.0`，注释写了来源。
- 原版这样做不挡目标，也不挡说明卡（说明卡在选目标时本来就不显示），所以**不做优化，没用 O-108**。

### 验证

- `xiyou_battle_ui` 新增 9 项断言：
  - 攻击路径：淡出中（可见、停用、alpha 小于 1）；0.35 秒后 alpha 为 0；取消后激活且 alpha 为 1。
  - 选目标确认段的三种范围：技能窗已关、指令窗淡出中；取消后 alpha 为 1 且停用。
- 选测（`并行测试.py … xiyou_battle_ui xiyou_battle xiyou_race_battle xiyou_help_card xiyou_item_list xiyou_hangup`）：14 个场景全过，没有偶发，62 秒。
  - `xiyou_battle_ui` 108/108（无头，原 99＋新 9）
  - `xiyou_race_battle` 653/653
  - `xiyou_help_card` 992/992
  - `xiyou_item_list` 38/38
  - `xiyou_battle` 8/8、`xiyou_battle_events` 108/108、`xiyou_battle_options` 92/92、`xiyou_battle_start_event` 50/50、`xiyou_battle_common_events` 22/22、`xiyou_battle_common_event_child` 13/13、`xiyou_battleback_save` 5/5
  - `xiyou_hangup*` 三个场景（226／57／25）也过了。加它们是因为 `xiyou_hangup_options` 读 `cmd_win.visible`。
- `xiyou_battle_ui` 窗口模式 `--out` 单跑：135/135（原 126＋9），24 张截图。`battle_42_target` 里看不到指令窗，和原版 `selhelp2_attack` 一致。

## 期二：参数缓存差异调查（只读）

### 新探针

`03_转换工具/mv_oracle/param_cache_probe.cjs`：冻结原版、全内存新局，只写 `.sandbox/param_cache.json`，20 例。
- **没挂进同步**：只是调查用，还没有 Godot 专项读它。
- 单跑：`cd 03_再刷重制_Godot/03_转换工具/mv_oracle && node param_cache_probe.cjs`（约 25 秒）。
- 每个读数同时记三样：缓存值 `a.param(i)`、绕过缓存的现算值（`krz.restate.Game_Actor_param`）、伤害公式读数（临时把技能 1 的公式换成 `a.atk`／`b.def`，走 `evalDamageFormula`）。角色还记 `CodexCombatPower.actor().total`。

### 原版机制（`krz_state_re.js`）

- 战斗中 `Game_Actor`、`Game_Enemy` 的 `param`、`xparam`、`sparam` 都按格缓存（`:477–540`），条件是 `inBattle`。`paramRate` 也缓存（`:543–570`），而且**不看 inBattle**。角色另有 `debuffRate`、`attackElements`、`attackStates`、`attackSpeed`、`stateResistSet`、`states()` 等缓存。
- 缓存只在 `refresh()` 里、并且 `need_refresh` 为真时才清（角色 `:180–247`，敌人 `:250–316`）。
- 把 `need_refresh` 置位的：`onTurnStart`、`onTurnEnd`（前后各一次）、`changeEquip`、`gainHp`／`gainMp`／`gainTp`（值不为 0）、`regenerateAll`、`onBattleStart`／`onBattleEnd`、`addState`、`removeState`、`addBuff`、`removeBuff`（`:35–154`）。
- **没包的**：`addDebuff`、`eraseBuff`、`eraseState`、`Game_Action.apply`／`prepare`（后两个是注释掉的）。
- 被包的方法大多在**原方法内部的 refresh 之后**才置位，所以当场读还是旧值，要等**下一次** refresh 才清。

### 实测结论（三个问题）

**① 实战伤害、命中、战力预演读的是不是旧值**

- 伤害：是。缓存已经读过、再挨纯减益（不带伤害的减益效果）时，`a.atk`／`b.def` 公式读数和帧外读数一样是旧值。例：角色 1，物攻 47、物防 20；减益后现算是 35、15，缓存仍是 47、20。敌人侧同理：攻 12、防 13，现算 9、9。
- 带伤害的减益技能**不会**读到旧值：`apply` 先 `executeDamage`，`gainHp` 置位 need_refresh，接着效果 32 → `addDebuff` 内部的 refresh 就把缓存清了。实测 `apply_debuff.damage`：减益后马上是 35、15。`apply_debuff.pure`：仍是 47、20。
- 冷格不会读到旧值：上次清缓存之后还没读过的格，减益后第一次读就是新值（`debuff_cold`：35、15）。八戒例里「已有状态」不是条件：`debuff_warm.none` 和 `debuff_warm.plain` 结果一样。关键是减益前这格读过没有。
- 战力预演：不受影响。`CodexCombatPower.actor().total` 在所有情况下都是 465，现算的减益也不进战力，它本来就不算 buff。
- 命中：减益只动 0～7 号参数，不碰 `xparam`。另测了加带 22 号特性的状态（状态 556）：命中、回避当场不变，下一次 refresh 才变。原因是 states 缓存同样「当场旧、下次 refresh 才新」，这一层重制已经用 `effect_dirty`／`effect_snapshot` 建模（`battler.gd`）。角色侧这一层有没有逐项对齐，本期**没有核**。

**② 什么时候失效**

| 减益后读到旧值，接着做 | 结果 |
| --- | --- |
| 只调 `refresh()` | 仍旧（need_refresh 为假） |
| `gainHp(-1)` | 仍旧：need 变真，但扣血内部的 refresh 在置位之前，要等下一次 refresh |
| `gainHp(0)` | 仍旧，也不置位 |
| `onTurnEnd` | **刷新**（regenerateAll 先置位再扣、回血触发 refresh） |
| `onTurnStart` | 仍旧（只置位）；之后再 `refresh()` 就刷新 |
| 加一个新状态、`addBuff`（别的参数）、`removeState` | 仍旧，只置位，下次 refresh 才新 |
| `removeBuff` 同一参数 | 读到去掉 buff 前缓存的值（这例恰好等于去掉后的值） |
| `eraseBuff`＋refresh | 同上，不置位 |
| 再挨一次同参数减益 | 仍旧（现算已是两层：24） |

实战里一般在回合末（onTurnEnd）、或者下一次「先置位、后 refresh」的事件之后刷新，例如下一次挨带伤害的技能。

**③ 涉及哪些参数和入口**

- 入口：`addDebuff`（效果 32、YEP 行动序列的 debuff）、`eraseBuff`、`eraseState`，它们不置位。其余被包的入口当场仍旧，下一次 refresh 才新。
- 参数：`param` 0～7（角色和敌人都有）；`xparam`、`sparam` 和 states 缓存同理。`paramRate` 在战斗外也缓存。战斗外实测：加状态 752（物攻倍率）后物攻仍是 35，refresh 后才是 30。

### 重制现状

- 敌人：`enemy.gd:220` `cached_param` 加上 `battler.gd` 的 `param_dirty`／`param_refresh`，已经复刻；`battle_logic.gd:1721` 注明 krz 没包 addDebuff。敌人侧和原版一致。
- 角色：`battler.gd:30` 写着「目前只有敌人启用，角色仍每次重算」，`battle_logic.gd:155` 只对敌人调 `param_cache_begin`。**这就是八戒那例的差异**：角色挨纯减益后，重制当场生效，原版要等下一次 refresh。

### 修法提案（请唐僧定）

**甲、照原版复刻角色缓存**
- `battle_logic.gd`：开战、结束时对 `actors` 也调 `param_cache_begin`／`param_cache_end`。
- `actor.gd` `param`：仿 `enemy.gd:220`，把「krz 包住的原生层」走 `cached_param`。注意原版在 krz 之后加载、包在缓存外面的有 Star_Warehouse、Codex_PercentPills 和多个 `codex/runtime`（Hubris、Mira、Race、AlienationAffixes、Heartsteel、Tusu、DamageElement、Toji、Guyu、Sukuna 等）。分层要逐个对，工作量中等，是八戒的文件。
- 加 `xiyou_param_cache` 专项读 `param_cache.json`，探针挂进同步。
- 可能受影响的夹具：用到角色中途读参数的 `xiyou_rules*`、`xiyou_race_battle`、`xiyou_alien_affix`、`xiyou_power*`、伤害对照（`--oracle`）。

**乙、不复刻，登记优化（我倾向乙，但要用户拍板）**
- 原版这是性能缓存的副作用，玩家能看到的效果是：纯减益技能对已经读过参数的目标，要到回合末才真正生效。重制角色侧已经是即时生效，保持不动，把这条差异登记成优化（要总装分配编号，这期没用 O-108）。
- 要不要顺手把敌人侧也改成即时生效（`battle_logic.gd:1721` 对减益也标 dirty，一行，加回退开关），是另一个决定：
  - 改了，敌我两边一致，但离原版更远；
  - 不改，敌人仍按原版。
- 动敌人侧的话要重跑上面那些夹具。

## 优化

没有新增优化，没用 O-108。期二乙方案需要另外的编号，由总装决定。

## 变更记录草稿

## 2026-10-29 【Claude·悟空·未经Codex检验】选目标时指令窗照原版淡出；减益后参数缓存只读调查（dev.待定）

- 选目标时指令窗不再立刻隐藏：照 Olivia_SideBattleUI 的 updateFadeOut 停用后 16 帧淡到 0，取消立刻恢复（原版实测逐帧 −16）。更正上期「原版选目标时指令窗仍显示」：当时只看了 visible，原版其实是淡出。
- 新参照探针 `param_cache_probe`（不挂同步，单跑）：krz 能力值缓存对减益的时序。挨纯减益且缓存已读过时，伤害公式和帧外读数都是旧值；带伤害的减益、冷格、回合末都是新值；战力预演不受影响。重制敌人侧已复刻，角色侧没缓存，提案甲（复刻）和乙（登记优化）待定。
- 验收：`xiyou_battle_ui` 加 9 项（指令窗淡出、停用、取消恢复）。

## 交接板

- 删掉「原有差异（八戒 dev.206 发现…）」那条，改成：已查明（见变更记录 dev.待定），差异只在角色侧、只在纯减益且缓存已读过时出现；修法甲／乙待定。
- 需要用户决定：减益后参数缓存，照原版复刻（角色也延迟到下次 refresh 才生效），还是作为优化保持即时生效，以及敌人侧要不要跟着改成即时（见本交付单「修法提案」）。

## 遗留

- 角色侧 `xparam`／`sparam`／states 缓存是否和原版逐项一致，本期没核（只测了原版一例状态 556）。
- 探针没挂同步、没有 Godot 专项读它；定了方案甲再一起挂。

## 待交叉核查

- 改了：`battle_scene.gd`（`_pick_target`、`CMD_FADE_FRAMES`）、`tests/xiyou_battle_ui.gd`（攻击路径与 `_select_confirm` 的指令窗断言）。
- 新文件：`mv_oracle/param_cache_probe.cjs`，只写 `.sandbox`。
- 没碰 `battler.gd`、`actor.gd`、`battle_logic.gd`。
- 请沙僧核期二结论：krz 被包方法「内部 refresh 在置位之前」这一点，以及 `apply_debuff.damage` 用 executeDamage＋applyItemEffect 模拟 apply 顺序是否成立（整条 apply 在单角色宿主里缺战斗现场，云裳运行时会报错）。

## 可优化（流程／工具／效率）

- `shared/host.cjs` 的新局里 `$gameTroop` 是空的，敌人当行动者时 `Game_Action.subject()` 取不到人，要手动 `$gameTroop._enemies=[e]`。可以在 host 里加个 `battleHost()` 帮手，顺便搭起 `inBattle`、`onBattleStart` 和云裳等运行时要的战斗现场，让探针能跑整条 `apply`。C 车道小活。

## 清理

参照服务（serve.py:8766）已停，浏览器窗格已关。scratchpad 里的原版截图、Godot 截图和测试日志已删。`.sandbox/param_cache.json` 在 .gitignore 里，留着备查。

## 本分支提交

- 198ba94f WIP: 选目标时指令窗照原版 Olivia updateFadeOut 停用并 16 帧淡出，取消立即恢复；battle_ui 加断言
- （本提交）参数缓存探针、交付单可合并
