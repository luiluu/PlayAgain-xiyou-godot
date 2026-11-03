# 交付：cc/bajie-growth2e

- 车道／工作者：C 规则·机制／八戒（cc，Opus）
- 状态：可合并（选测见「验证」；尾项见「接续」）

（成长装备期二b 收尾：growth2c（魔冠，到交接线）＋ growth2e（审查 29 P3-1／P3-2 补参照、选测）并成这一份；growth2c 分支 95040687 以前的提交都在本分支。心钢／狂妄等尾项在「接续」。）

## 变更记录草稿

## 2026-11-03 【cc·八戒·未经审查】成长装备期二b：魔冠「"头顶"」、审查 29 P3-1／P3-2（dev.待定）

派单：总装十五 growth2c／growth2e（成长装备期二b），魔冠＋审查第 29 期两条 P3，尾项写接续。

### 一、来源核对

- 魔冠 7940 只从 installNativeDemonCrownRuntime 里来：Map162（切片里有）敌群 539～542、不朽的未知战斗（来源 57／59，没记来源按变量 107＝2／3），开战掷一次，胜利且 <3%。条件判定直接用已有的 `XYunshangOrders.immortal_clear`。
- 原版 main.js 第 151 行装载，比心钢（111）、狂妄晚，是外层：startBattle 在原来之前、endBattle 在原来之后（在利维坦锻造锤、狂妄掉落之后）。

### 二、原版参照 `demon_crown_probe`（18 例，不进同步，拷成 `tests/fixtures/demon_crown_oracle.json`）

- 公式 D.next／D.display；得到（数据库那件→账本发实例：名字、说明、图标、成长行、八项 code21）；胜利成长 6 场（含失败、逃跑）；战斗中死亡（同一人第二次不重记）、复活后再死、战斗外死亡；中途换装备、不在出战；掉落 9 例（边界 0.03／0.0299、来源、敌群、地图、失败、逃跑、变量 107）；读档防回滚（成长、遭遇序号重打不重掷、换敌群不算）；卖出记移除、穿上卸下不记、按底子扣不记且读档不重发；旧档没 uid 的收编（成长保留）。
- 参照的坑：`changeLevel` 在参照里受难度上限卡住，探针直接设 `_level`；`revive` 不去死亡状态，用 `removeState(1)`＋`clearResult`（否则同一行动结果里不能再加死亡）；战斗中去死亡状态要场景的 OTB 窗口，探针给了桩。

### 三、移植（`core/demon_crown.gd` XDemonCrown，新文件）

- 账本照 `XYunshangOrders` 的写法：存档目录旁 `crown_progress_v1.json`（整份写、先写临时文件再改名），存档 flags 记 `_codexCrownProfile`／`_codexCrownEncounterSeq`／`_codexCrownWorldDeathSeq`；改账本都走 transaction（复制→改→写盘→replay）。
- 重制与原版不同处：①新局不平白写盘（原版 setupNewGame 就建档案；重制等到第一次得到魔冠、碰上掉落战斗或读到带魔冠的档才建）；②原版独立物品被按底子扣掉后仍留在 $dataArmors，重放找得到就不重发，重制用 flags `_codexCrownKnown`（本档建过的 uid）顶替；③开战掷点原版 Math.random，重制取战斗规则流 `demon_crown.roll`（只在掉落战斗、且这一遭遇序号第一次开战时掷）；④编号 Crypto 16 字节。
- 接线：`battle_logic.start_battle` 最前（甚尔之前）`XDemonCrown.begin`；`end_battle` 末尾（狂妄 clear_reward 之后）`XDemonCrown.finish`；`battler.add_state` 新加死亡状态后 `on_death`；`XEquipment.change` 末尾 `equip_changed`；`xstate.gain_gear` 得到 7940 改走 `grant`，`lose_gear(record)` 带 uid 记 removed；`xsave.save` 写前 `before_save`，`load_slot` 云裳之后 `after_load`。
- 账本不可用（坏了、版本不对、本档编号找不到）：提示「"头顶"成长记录暂不可用…」一次，魔冠倍率退回 1，本局之后不再写。

### 四、审查第 29 期 P3-1／P3-2

- P3-1：`battle_logic.gd` `act()` 与 `_forced_run` 的 endAction 前半段改成 屠苏 → 谷雨（end_action、take_visuals）→ 狂妄 → 心钢（原版装载 心钢 111、狂妄 112 在 谷雨 133、屠苏 137 里层）。
- P3-2：`XGuyu.apply` 加可选参数 `inner`（里层回调），心钢 `blocks_apply` 挪进回调：谷雨先置行动执行标记，心钢拦下时返回空结果、跳过奈叶与心钢记账。
- 原版参照：`heartsteel_probe` 加两例（41 例无错）。`order.tusu`：屠苏 60 级化武剑给穿狂妄的 1 号，1 号打过 e0、e0 留 1 血，斩锋后屠苏剑气纵横打死 e0，原版在这次 endAction 就出扬名（击杀按修复口径）。`order.guyu`：谷雨 35 级开花期，穿心之钢的 1 号被事件强制放没蓄满的巨人吞噬，心钢拦下、谷雨仍绽放（付储备、打种子）。
- 专项 `xiyou_heartsteel` 回放这两例；反向验证（把 act 换回旧次序、把拦截挪回谷雨外）两项都报错。

## 待交叉核查

- 新文件：`core/demon_crown.gd`、`tests/xiyou_demon_crown.gd`（＋tscn、fixture）、`mv_oracle/demon_crown_probe.cjs`。
- 原沙僧核心文件：`battle_logic.gd`（魔冠两行；P3-1 两处 endAction 次序；P3-2 apply 里心钢拦截进谷雨回调）、`guyu.gd` `apply` 加 `inner` 参数；魔冠两行（start_battle 最前 begin、end_battle 末尾 finish）、`battler.gd` `add_state`（记 was_dead，新死调 on_death）、`xstate.gd`（gain_gear 7940 分支、lose_gear 魔冠分支）。
- 另改：`core/equipment.gd`（change 末尾一行）、`core/xsave.gd`（save、load_slot 各一行）、`mv_oracle/heartsteel_probe.cjs`（order.tusu、order.guyu）、`tests/xiyou_heartsteel.gd`（`_battle` 可换队伍、两例回放）、`tests/fixtures/heartsteel_oracle.json`。
- 请重点核：begin 放在 start_battle 最前是否与其它开战包装的规则流抽数次序冲突（只在掉落战斗首次开战抽一次）；`_codexCrownKnown` 顶替 $dataArmors 的做法。

## 交接板

- 下一步：成长装备期二b 魔冠与审查 29 两条 P3 已交（审查 29 P3-1、P3-2 可销账，待审查）；期二b 尾项见本单「接续」。
- 用户试玩说明：魔冠「"头顶"」在 Map162 的不朽未知战斗胜利有 3% 掉落；穿着打赢一场八项全属性多约 1%（越高涨得越慢，上限 1000%），穿着的人倒下就丢一半。成长记在存档目录旁的独立文件，读旧档不会回滚。
- 需要用户决定：无。

## 进度账

- 养成·成长装备：约 60% → 约 75%，依据：魔冠已移植并对上参照；剩心钢／狂妄动态说明、智能 AI、战力等尾项。

## 可优化（流程／工具／效率）

- 已做：无。
- 建议：`长任务.py start` 后面的命令如果是空的场景名单，`并行测试.py` 会跑全部场景；本车道在 zsh 里用 `$T` 传名单没拆开词，误启动了全量（车道不该跑全量）。建议 `并行测试.py` 不带场景名时要求显式 `--all`，或者 `长任务.py` 加一个 `stop <日志>` 子命令（车道会话 kill 进程会被权限拦下），归哪吒。

## 验证

- 原版探针 `node demon_crown_probe.cjs`：18 例无错；`node heartsteel_probe.cjs`：41 例无错（新加 order.tusu、order.guyu）。两份都不进同步，拷成夹具。
- 专项 `xiyou_demon_crown` 101／101、`xiyou_heartsteel` 423／423（合 main 后）。
- 反向验证（`反向验证.py`）：`act()` 换回旧次序（心钢、狂妄在屠苏前）→ `xiyou_heartsteel` 报错；心钢拦截挪回谷雨 apply 外 → 报错。`_forced_run` 的次序没有单独的参照例（同 act 改法）。
- 选测：合 main（dev.286 之后，c4473c42）后 `选测.py main --list` 列出的 300 个场景全名照跑（含 xiyou_rules 抽样 12 段、xiyou_smart_ai 抽样 4 段、xiyou_determinism、xiyou_event_compare）：299 过；`xiyou_demon_crown` 挂在「没有 `TEST_RESULT=` 行、_ready 里弹掉落提示报引擎 ERROR」（测试 101/101 本身是过的，growth2c 只直接跑过、没走过并行测试）。改成延后一帧跑、打 `TEST_RESULT=` 行后，与 `xiyou_heartsteel` 一起重跑通过。
- `python3 07_开发环境/语法检查.py`：通过。
- 偶发：无。
- growth2d（作废）交付单里查出的探针 4 处（50 级、OTB 桩、revive、收编例）本单探针都已处理；按底子扣用 `_codexCrownKnown` 复现原版不补发，口径与总装定的一致，不算优化、不开回退开关。

## 本分支提交

- ca624dfc／c8a89bb0 参照探针与夹具；e21bad56 运行时与专项（growth2c）
- 95040687 P3-1／P3-2 改码；66be5b81 两例参照与专项回放；b847f7f6 合 main；之后：交付单、demon_crown 专项接入并行测试

## 接续

1. 魔冠余项：图标 Codex_DemonCrown 图没转换；RJO.HE 详情里的数字取整（getDescParams 包装）；战力 CodexCombatPower 里的魔冠；CodexZones.invalidate。
2. 期二b 尾项：心钢／狂妄动态说明（`H/U.helpRows`、`describe`、`helpView`，接 help_card；`xiyou_heartsteel` 的 PENDING_FIELDS 里 desc 还没比）、选原件时 Shift 看原件词条、智能 AI 选巨人吞噬（`Codex_SmartBattleAI.js` 引用 7900，先查 plugins.js 确认启用）、战力、甚尔抑制行动不减蓄力、解锁与锻造锤的提示（toaster）。
3. 可选：给 `_forced_run` 的新次序补一例（强制行动里屠苏剑气＋狂妄），现在只靠与 act 同改法。
