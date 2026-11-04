# 交付：cc/bajie-rules6

- 车道／工作者：C 规则／八戒（cc，唐僧总装十九派）
- 状态：进行中（等云端选测）

## 变更记录草稿

## 2026-11-04 【cc·八戒·未经审查】切片可达未翻译状态块清零：换装模板、必爆、公共事件预约、再生、改属性（dev.待定）

- **原版行为**（`state_effects_probe` 新用例 `rest.blocks` 实测）：
  - 换装：只有角色换图，先把旧图记到 `_prevBattlerName`（已有不盖，同时两个时记的是最初的图）；移除时换回并清掉。敌人 apply 什么都不做，remove 因为没有 `setBattlerImage` 直接 TypeError。没记过旧图就移除时，原版把图设成 undefined。
  - 必爆 541、755：目标身上有状态、技能能暴击时，select 打开 `_forceCritical`，deselect 恢复；`modifyCritical` 强制暴击，暴击随机数照抽。两个状态同时挂时第二个把 true 记成旧值，强制暴击在这场之后还留着。
  - 预约：`$gameTemp.reserveCommonEvent` 单槽，后盖前。1318 的 `!v == 1` 实际是 v 为 0 才预约。2568 变量>9998 时给目标加死亡。
  - 再生 260、1006：来源不是持有者且活着才生效；来源回血数字弹在来源身上，目标掉血由外层 `regenerateStateEffects` 弹。结果槽记最后一次 `gainHp`，不截血量。
  - 1423 欠债：金币扣 `变量980*100`（原版可扣成负数）；1840：`_tp` 直接设，不进结果槽；2003：敌人和角色都改 `_paramPlus`。
- **转换器**（`xiyou_export.py`、`formula_program.py`）：`MEASURED_EFFECT_SOURCES` 再加 15 块换写（541／755 同文），2003 两块进白名单；换装按模板（只有图名可变）译成 `costume_image`、`costume_restore`，142 块全走模板。切片补 `sv_actors/ftzs`、`sv_actors/2_Brown` 两张图（状态 66、226 写死的，原来不在切片里）。生成数据 `op: js` 247 → 82，切片可达 0。
- **运行时**：
  - `state_effects.gd`：`costume_image`、`costume_restore`（换装卡状态 58 张归 `XCostumes`，这里跳过）；`effect_program` 加预约、金币、设 TP、`addParam`、必爆开关、`origin` 作接收者；再生阶段块前清结果、块后发目标弹字；没有命中记录的阶段，弹字与动画走 `ctx.emit`。
  - `battle_logic.gd`：`turn_start`、`turn_end` 传 emit，**rules5 小爱莉被动的弹字原来丢了，现在有了**；回合开始的弹字存 `turn_start_logs`，`run_turn`、`battle_scene`、`battle_replay` 取走；`_drive_events` 开头取状态预约；暴击判定或上 `force_critical`。
  - `enemy.gd`：敌人有 `add_param`（`added_params`，只活在这场）。`battle_scene.gd`：regen 记录弹 MP。
- **报数**：`xiyou_state_effects_tp` 改 `inventory.costume_0`、`inventory.untranslated_82`。
- 测试：`xiyou_state_effects` 加 `_rest_blocks`；`测试状态js翻译.py` 加 `RestBlockTranslationTests`；`测试未翻译块清单.py` 换还没翻的例子。

## 交接板

- 下一步：切片可达未翻译块清零。全部 js 块剩 82：全游戏可达 34、不可达 48，等切片扩到那些内容时再翻，按 `未翻译块清单.py --detail` 看。
- 用户试玩说明：佛陀真身、牛头人附体、狗、怒目金刚、变身萧萧现在会换战斗图；被必爆状态标记的目标必吃暴击；太极、乾坤大挪移、向我看齐等受击时触发公共事件；附骨之疽每回合吸血；欠债胜利时扣金币。
- 需要用户决定（都默认照现状）：
  1. 欠债 1423：原版金币可扣成负数，重制有 `GOLD_FLOOR_ZERO` 的既有优化，到 0 为止。
  2. 同谐、秩序等的笔误见 rules5；这轮新增：鼬被动 1318 的 `!v == 1` 写法看着是笔误，实测效果等于变量为 0 才预约，照原版。

## 进度账

- 战斗规则：未翻译状态块 247 → 82，其中换装 142 → 0，真未翻 105 → 82；**切片可达 31 → 0**。

## 可优化（流程／工具／效率）

- `未翻译块清单.py` 的切片可达明细现在是空的，要看下一步得看全游戏可达。总装扩切片时可以先跑它，看新内容带进来几块。

## 验证

（待补：云端选测）

- 专项（本机）：`xiyou_state_effects` 25028、`xiyou_state_effects_tp` 538、`xiyou_state_js` 1733、`xiyou_status_power_panel` 11、`xiyou_battle_log` 57、`xiyou_battle_ui` 155、`xiyou_battle_events` 108、`xiyou_formula_effects` 908、`xiyou_honghuang_curse_battle` 344、`xiyou_determinism` 372、`xiyou_costumes` 27、`xiyou_costume_battle` 4、`xiyou_boss_state_origin` 15723，全过。
- 工具：`测试状态js翻译.py`、`测试未翻译块清单.py`、`测试公式程序.py` 过；`语法检查.py` 0 问题。
- 同步：合 main、补齐后把主工作区的 `state_effects.json` 盖回做干净基线，`同步正式西游.py --accept-additions` 退出码 0，只新增 `hook.blocks`（rules5 还没进 main）、`rest.blocks`。
- 选测对照：`选测.py main --list` 已含 `xiyou_status_power_panel`、`xiyou_costumes`、`xiyou_costume_battle`；`state_effects.gd`、`enemy.gd`、`actor.gd` 都在 battle 组，`battle_replay.gd` 没有专门规则、按引用选。
- 没测：换图的实际画面（只断言图在切片里、`battlerName` 对），回合开始弹字只测到 emit 和取走，`battle_scene` 的 `await _play` 没有专门断言。
- 与原版不同：没记过旧图就移除换装时，原版图变 undefined 显示不出来，这边保留现状；必爆粘住的强制暴击每场开战清掉，原版跟存档走。

## 本分支提交

（待补）

## 待交叉核查（核心文件）

- `state_effects.gd`、`battle_logic.gd`（暴击判定、`_drive_events`、turn_start／turn_end 的 emit）、`battle_scene.gd`、`enemy.gd`（`param_plus` 影响所有敌人能力值读取）、`battle_replay.gd`。
