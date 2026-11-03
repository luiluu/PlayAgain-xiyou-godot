# 交付：cc/bajie-growth2c

- 车道／工作者：C 规则·机制／八戒（cc，Opus）
- 状态：未完成（到交接线，WIP；魔冠已对上参照，P3-1／P3-2 已改未验证，见「接续」）

（成长装备期二b 分期：本单＝魔冠；心钢／狂妄尾项与审查 29 的 P3-1、P3-2 在「接续」。）

## 变更记录草稿

## 2026-11-03 【cc·八戒·未经审查】成长装备期二b：魔冠「"头顶"」（dev.待定）

派单：总装十五 growth2c（成长装备期二b），先交魔冠这块能独立验证的部分，尾项写接续。

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

## 待交叉核查

- 新文件：`core/demon_crown.gd`、`tests/xiyou_demon_crown.gd`（＋tscn、fixture）、`mv_oracle/demon_crown_probe.cjs`。
- 原沙僧核心文件：`battle_logic.gd`（魔冠两行；P3-1 两处 endAction 次序；P3-2 apply 里心钢拦截进谷雨回调）、`guyu.gd` `apply` 加 `inner` 参数；魔冠两行（start_battle 最前 begin、end_battle 末尾 finish）、`battler.gd` `add_state`（记 was_dead，新死调 on_death）、`xstate.gd`（gain_gear 7940 分支、lose_gear 魔冠分支）。
- 另改：`core/equipment.gd`（change 末尾一行）、`core/xsave.gd`（save、load_slot 各一行）。
- 请重点核：begin 放在 start_battle 最前是否与其它开战包装的规则流抽数次序冲突（只在掉落战斗首次开战抽一次）；`_codexCrownKnown` 顶替 $dataArmors 的做法。

## 交接板

- 下一步：成长装备期二b 魔冠已交；尾项与审查 29 的 P3-1、P3-2 见本单「接续」。
- 用户试玩说明：魔冠「"头顶"」在 Map162 的不朽未知战斗胜利有 3% 掉落；穿着打赢一场八项全属性多约 1%（越高涨得越慢，上限 1000%），穿着的人倒下就丢一半。成长记在存档目录旁的独立文件，读旧档不会回滚。
- 需要用户决定：无。

## 进度账

- 养成·成长装备：约 60% → 约 75%，依据：魔冠已移植并对上参照；剩心钢／狂妄动态说明、智能 AI、战力等尾项。

## 可优化（流程／工具／效率）

- 已做：无。
- 建议：`长任务.py start` 后面的命令如果是空的场景名单，`并行测试.py` 会跑全部场景；本车道在 zsh 里用 `$T` 传名单没拆开词，误启动了全量（车道不该跑全量）。建议 `并行测试.py` 不带场景名时要求显式 `--all`，或者 `长任务.py` 加一个 `stop <日志>` 子命令（车道会话 kill 进程会被权限拦下），归哪吒。

## 验证

- 原版探针 `node demon_crown_probe.cjs`：18 例无错。
- 专项 `xiyou_demon_crown`：101／101（比较时不比品质，因为词缀是各自掷的）。
- `python3 07_开发环境/语法检查.py`：499 个 .gd 无问题。
- 全量（误启动，见「可优化」）：没跑完，作废。P3 改后只跑了语法检查（499 个 .gd 无问题），专项未跑。
- growth2d（作废）交付单里查出的探针 4 处（50 级、OTB 桩、revive、收编例）本单探针都已处理；按底子扣用 `_codexCrownKnown` 复现原版不补发，口径与总装定的一致，不算优化、不开回退开关。

## 本分支提交

- ca624dfc／c8a89bb0 参照探针与夹具
- e21bad56 运行时与专项

## 接续

0. **先停掉误启动的全量**（长任务 PID 64002、进程组 64003，日志 `03_再刷重制_Godot/04_验证/本地结果/growth2c_选测.log`；P3 改在它跑的中途，结果不能用），再合 main（总装推送后）、`新建工作树.sh --补齐`，跑选测：`选测.py main --list` 里的战斗核心类＋ xiyou_demon_crown、xiyou_heartsteel、xiyou_hubris、xiyou_guyu_battle、xiyou_tusu_battle、xiyou_nanoha、xiyou_growth_forge、xiyou_yunshang_shop、xiyou_determinism、xiyou_save_page、xiyou_warehouse、xiyou_shop_buy、xiyou_equipment。**zsh 里名单别放进一个变量里传**（不拆词＝空名单＝全量）。
1. **审查 29 的 P3-1（代码已改，0a 提交）**：`battle_logic.gd` `act()` 与 `_forced_run` 里 endAction 前半段次序应为 屠苏 → 谷雨 → 狂妄 → 心钢（屠苏 137、谷雨 133 装得晚，在外层，先跑）；现在心钢、狂妄排在前面。
   改法：`act()`、`_forced_run` 里次序改成 屠苏 → 谷雨（end_action、take_visuals）→ 狂妄 → 心钢。**还缺原版参照例**（heartsteel_probe 补「谷雨代命＋狂妄」或「屠苏剑气＋狂妄」）。
2. **P3-2（代码已改）**：`XGuyu.apply` 加可选参数 `inner`（里层回调），battle_logic 把心钢拦截放进回调：谷雨先置 executed，拦下时返回空结果、跳过奈叶与心钢记账。**还缺参照例**（强制行动放没蓄满的巨人吞噬→谷雨花期绽放仍触发）。原说明：心钢 `blocks_apply` 被拦下时谷雨没打「行动已执行」标记；原版的拦截在谷雨里面（谷雨先置 executed）。可以给 `XGuyu.apply` 加里层回调，或者把拦截挪到 `_apply_core` 开头。两条都要补原版参照例（审查没写），详见 `git show cc/review-29:00_项目管理/交付/cc_review-29.md` 的 P3-1、P3-2 两节。
3. 魔冠余项：图标 Codex_DemonCrown 图没转换；RJO.HE 详情里的数字取整（getDescParams 包装）；战力 CodexCombatPower 里的魔冠；CodexZones.invalidate。
4. 期二b 尾项照旧：心钢／狂妄动态说明（`H/U.helpRows`、`describe`、`helpView`，接 help_card）、选原件时 Shift 看原件词条、智能 AI 选巨人吞噬（`Codex_SmartBattleAI.js` 引用 7900，先查 plugins.js 确认启用）、战力、甚尔抑制行动不减蓄力、解锁与锻造锤的提示（toaster）。
