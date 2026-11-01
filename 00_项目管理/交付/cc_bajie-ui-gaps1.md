# 交付：cc/bajie-ui-gaps1

- 车道／工作者：B 界面／规则（总装十一派给八戒）／八戒（cc，八戒）
- 状态：可合并
- 分支从 cc/bajie-raven-ui1 末端 0450abcc 切，已合 main 22238e0b（含 guyu4～raven-ui1）；合并冲突只有 battle_scene 日志分支一处（mastery_up 与 main 的 se 并排）。

## 变更记录草稿

## 2026-11-01 【cc·八戒·未经审查】技能熟练度期一（YEP_SkillMasteryLevels）：解析、战斗内涨熟练度、伤害、存档；饿狼画面遗留核清（dev.待定）

- **盘点**（交接板「白龙」一条的饿狼画面层）：进阶原因提示（`actor_advanced.gd` 饿狼分支，G.reason 蜂鸣＋右上角提示）、追击／反击战斗日志（`XGarou.trigger` 的 garou_trigger 标记，battle_scene 照 displayAction 加一行技能名、再弹伤害放动画）、星空外观（`XGarou` Garou_Cosmic／`appearance.gd`，悟空 drops1）、技能分类与指令窗（battlelog2）都已做；神之触媒 victory_texts 照派单等 Kyo，没动。
- **熟练度是真缺口**：原版开着 YEP_SkillMasteryLevels v1.00，参数 Level Formula `(1 + 2) + (1 + 1) + 1`（＝6 次升一级，注释说 120 是错的）、上限 100000、Damage Formula `value * (1.00 + (level * 0.1))`、升级动画 742；普攻（技能 1）也算技能，敌人也涨（每场新建从 0 起）。installDamageElementRuntime 在 raw＋flatSkill 之后乘 masteryDamage，masteryRate 也乘进元素固定增伤。重制原先 `XBattler.skillMasteryLevel` 恒 0、伤害链没有这一步——技能用多了原版伤害逐级 +10%，重制永远是 0 级。
- 新 `modes/xiyou/core/skill_mastery.gd`（XSkillMastery）：
  - 技能备注逐行照原版 if／else 顺序解析：`<Max Mastery Level: n>`、`<Mastery Effect: ±n … Per Level>`／`±n%`、`<No … Mastery Effect>`、`<Custom … Mastery Formula: …>`（贪婪匹配：一行写两个标签时类型对不上，整行不生效，照原版）；公式用 Godot Expression 算（value／cost／turns、level，`CodexCat.mastery(this.subject())` 换成小猫剑圣剑技等级）。
  - 涨熟练度：`XBattleLogic.execute` 付费处记下技能（paySkillCost 包装，只在付得起的那支里，菜单不经过这里），`act`／`_force_action` 行动结束的状态回合之后计一次使用（onAllActionsEnd 包装），够 masteryFormula(等级＋1) 升一级、已用归 0；先夹技能上限，变量 13 为 1 时再夹变量 8（0 当 100000）；有升级记一条 `mastery_up`，battle_scene 在行动者身上放动画 742。
  - 伤害：`XDamage._calculate` 加 mastered（只对技能；治疗、settled 不走）与 masteryRate。
  - 存档：角色行加 `masteryLevels`／`masteryUses`（空的不写，旧档读回 0 级）。
- 参照：新探针 `mv_oracle/skill_mastery_probe.cjs`（真实 BattleManager；全部 6804 个技能的上限／次数／伤害公式表、8 组涨熟练度、敌人、菜单、5 组伤害、存档往返），产物拷成 `tests/fixtures/skill_mastery_oracle.json`，不接入全量同步。
- 没做（期二、期三）：技能窗量条与「LV.%1」、installSkillLevelNoticeRuntime 升级提示、测试模式上限、战力 power zones 的 masteryRate 与 CombatPower 缓存键；渡鸦 10122～10139／10170 运行时改写的熟练度设定（上限 8／0、次数 8＋4×等级、每级 8%）与上限 `R.masteryCap`、饿狼追击／反击借主拳熟练度与进阶继承、异化 affix 23 取 min、宿傩／甚尔 `_actionMastery`／云裳派生伤害等模块包装；MP／TP／HP 费用与冷却的熟练度公式（正式西游插件参数都原样，只有渡鸦运行时改写，期三一并接）。

## 交接板

- 下一步：「白龙」一条删掉画面层里已做的进阶原因、追击／反击日志、技能分类、星空外观（只留神之触媒等 Kyo）；新开一条「技能熟练度期二（界面、升级提示、测试模式、战力）、期三（各角色模块包装、渡鸦熟练度、费用／冷却公式）」。
- 用户试玩说明：战斗里技能（含普攻）每用 6 次升一级熟练度（升级时角色身上放升级动画），每级伤害 +10%（部分技能备注另有公式）；技能窗还不显示熟练度等级（期二）。
- 需要用户决定：无（照原版，没有偏离，不用 O 号）。

## 进度账

- 战斗核心：技能熟练度（YEP_SkillMasteryLevels）期一移植。

## 待交叉核查

- 甲档：`battle_logic.gd`（execute 付费处记账、act／_force_action 的 `_mastery_end`）、`damage.gd`（mastered／masteryRate）、`battler.gd`（熟练度字段、skillMasteryLevel）、`xstate.gd`（存读档两项）、新 `skill_mastery.gd`。

## 验证

- 专项 `xiyou_skill_mastery` 216/216。反向 5 处都能抓到：去掉变量 13 上限 212/216、去掉 mastered 208/216、不记账 113/216、不读档 214/216、不认自定义公式 195/216。
- 选测（合 main 前，基准 0450abcc；选测.py 因 xstate.gd 改动退回 game 组 304 个，车道只跑战斗核心＋存档＋各角色战斗专项 126 个，清单是 rules 全 24 段、event_compare、determinism、combat、battle*、smart_ai*、各角色 *_battle、*save*、*_load 等）：124 过；`xiyou_determinism` early_inventory_rule 1 处在基准 0450abcc 原文件上同样失败（不是本期引入），`xiyou_guyu_ui` 缺 oracle/guyu_ui.json（前几期新探针的产物，主工作区还没同步）。
- 合 main 22238e0b、`--补齐` 后复跑 10 个：skill_mastery、determinism、guyu_ui、event_compare、combat、battle、garou_battle、rules、save_page、cat，全过（determinism、guyu_ui 都由 main 修好）。语法检查 470 个 0 问题。
- 新探针 skill_mastery_probe 不接入全量同步（同 garou_battle），产物手拷进 tests/fixtures，所以没跑 同步正式西游.py。

## 可优化（流程／工具／效率）

- `选测.py` 的 xstate_fields 只认 `s.x = …` 这类读档行；角色行里加存档键（`a[str(id)]["…"] = …`）和 `XFoo.from_save(x2, row…)` 一行就退回 game 组 273 个场景。可以把这两种写法也加进 onlyLines（派哪吒）。
- `选测.py main` 在车道分支基于未合并分支时，会把前几期的改动也算进来；交代里写「选测.py <本期起点>」更准。

## 本分支提交

- WIP: 技能熟练度期一：参照探针、XSkillMastery 解析／涨熟练度／伤害 mastered／存档
- WIP: 熟练度专项 xiyou_skill_mastery 216/216，反向 5 处
- 合并 main 22238e0b
- 本交付单
