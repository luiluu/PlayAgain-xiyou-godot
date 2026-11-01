# 交付：cc/bajie-mastery3

- 车道／工作者：C 规则／机制（总装十二派给八戒）／八戒（cc，八戒）
- 状态：可合并
- 分支从 cc/bajie-mastery2 末端 c0245dc7 切（链式：ui-gaps1 → mastery2 → 本期，总装只合链尾）。

## 变更记录草稿

## 2026-11-01 【cc·八戒·未经审查】技能熟练度期三：各角色模块的熟练度包装、渡鸦运行时设定、费用与冷却公式（dev.待定）

- **OTB 即时施放**：原版没开 YEP_InstantCast，Olivia_BattleSysOTB 的 `_otbInstantCast` 恒假，每次 endOTBAction 都调 onAllActionsEnd（强制行动、dsPassiveSkill 击杀续放也一样，续放的两笔付费在同一次 onAllActionsEnd 里计）。重制在 act／_force_action 末尾计次，一致，不用改。installTestModeRuntime 里那句「instant casts can finish without onAllActionsEnd」只对测试模式的上限训练，重制没有测试模式。
- **包装后的等级**（新 `XSkillMastery.effective`，`XBattler.skillMasteryLevel` 改走它；原始等级仍是 `XSkillMastery.level`）：照 main.js 的安装先后，渡鸦 → 宿傩 → 饿狼 → 异化。
  - 渡鸦（167）10122～10126：夹 R.masteryCap（变量 8 取整，≤0 当 8，最多 999）。
  - 宿傩（172）10229～10238：读来源技能的等级（10233→10232，10234～10236、10238→10229，10237→10231），夹变量 8（0 时取来源技能上限）。
  - 原版凡是读等级的地方都读包装后的（满级判断、onAllActionsEnd 比较升级与动画、升级通告前后、菜单技能窗量条与 LV）；所需次数、已用次数读原始的。所以宿傩的派生技能自己练升级不放动画、不报通告（参照 sukuna.gain37、notice）。
  - 小猫剑圣 CodexCat.mastery 原版直接读 `_skillMasteryLevels`，改成读原始等级。
- **渡鸦运行时设定**（finishRavenDatabaseCompatibility）：10122～10139 所需次数 8＋4×级、伤害每级 +8%、MP 每级 −3%、TP 每级 −2%（向下取整、不低于 0），HP、冷却不变；上限 10122～10126 跟变量 8，10127～10139 是 0（没有 CodexRavenDamage）。期一 table 原来跳过的渡鸦行现在也比。
- **费用、冷却公式**（YEP skillMpCost／TpCost／HpCost、applyCooldownMods 包装）：新 `XSkillMastery.cost`／`cooldown`。费用为正时 ⌊公式⌋、不低于 1，在 YEP_SkillCore 之上、dsPassiveSkill 减耗之内（`_skill_cost` 一行、`skill_hp_cost` 一行）；冷却为正时 ⌊公式⌋、不低于 1（`XBattler.pay_cooldown` 一行）。正式西游只有渡鸦的公式不是原样，其余技能数值不变。
- **饿狼**：
  - 进阶继承（G.advance）：新学的技能取被替换技能的等级、次数（setSkillMasteryLevel 再 setSkillMasteryUses，次数够就当场升一级），继承期间不报通告（`_garouAdvancing`）。参照 garou.advance 六阶逐个对上。
  - 追击／反击借主拳熟练度：**原版代码错误**，修了，开关 O-待定 `XSkillMastery.o_garou_borrow`（见优化登记草稿）。
- **异化无面／百相取 min**：**原版代码错误**，修了，开关 O-待定 `XSkillMastery.o_alien_object`。
- **甚尔**：武器库掷中时 `_actionMastery` 推 10211，随 onAllActionsEnd 计一次（原来「重制恒 0，不记」）；随机武器伤害读武器库等级（传技能对象）。
- **云裳**：派生伤害的熟练度替换（nativeDamage 里的 `_yunMasteryLevel`）：符针用种针时 10270 的等级（种下时记进针里），赊账用触发技能的等级；只替这个派生技能自己。
- **米拉**：原版只经 skillMasteryLevel 读，期一起就跟着生效，没有另外的包装。
- 参照：新探针 `mv_oracle/skill_mastery3_probe.cjs`（12 例，真实 BattleManager），产物拷成 `tests/fixtures/skill_mastery3_oracle.json`，不接入全量同步（同 skill_mastery_probe）；专项并进 `xiyou_skill_mastery`。

## 优化登记草稿

| 编号 | 位置 | 原版 | 改后 | 理由 | 回退 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 饿狼追击／反击借主拳熟练度（`core/skill_mastery.gd` _native，installNativeGarouRuntime:199） | 包装装在 Game_BattlerBase.skillMasteryLevel 上，可渡鸦先在 Game_Actor 上装了自有的包装（Sukuna、异化也在 Game_Actor 上），角色调用走不到 BattlerBase 那层：G.trigger 设了 `_garouMasterySource` 也读自己的，追击／反击技能没人练，伤害恒按 0 级（参照 garou.borrow：角色 0、BattlerBase 那层 3） | 追击／反击照设计读当前形态主拳的等级（伤害每级 +10%） | 代码装错了层，设计意图（G.trigger 专门设、清 `_garouMasterySource`）没生效 | `XSkillMastery.o_garou_borrow = false` | cc（八戒） | 待用户确认 |
| O-待定 | 异化无面／百相取 min（`core/skill_mastery.gd` effective，installAlienationAffixes:23） | 包装拿参数直接和技能编号比；伤害（installDamageElementRuntime 传 f.item）、费用、技能窗传的是技能对象，对不上，取不到 min：借来的技能按自己的等级算伤害；只有传编号的地方（满级判断、升级比较、通告）取到 min（参照 alien.faceless：编号 10、对象 50） | 传对象也取 min(自己、本人等级、来源等级、来源的熟练度)；百相 min(自己、本人等级) | 同一处包装两种调用结果不一样，显然是漏了对象 | `XSkillMastery.o_alien_object = false` | cc（八戒） | 待用户确认 |

## 交接板

- 下一步：熟练度系统移植完了（期一～三）。剩下依赖未移植系统的：测试模式上限（installTestModeRuntime）、战力区 CodexZones 的 masteryRate。
- 用户试玩说明：渡鸦五个主动技每 12／16／20…次升一级（上限跟难度的技能等级上限），每级伤害 +8%、MP 少 3%；宿傩派生斩跟着本体技能的等级；饿狼进阶后新拳法带着旧拳法的熟练度；甚尔用武器库会练武器库被动。
- 需要用户决定：上面两条 O-待定（默认都修好；关掉照原版）。

## 进度账

- 战斗核心：技能熟练度（YEP_SkillMasteryLevels）期三：角色模块包装、渡鸦设定、费用／冷却。

## 待交叉核查

- 甲档：`skill_mastery.gd`（effective／_native、渡鸦设定、cost／cooldown、all_actions_end 与通告改读包装后的等级）、`battler.gd`（skillMasteryLevel 改走 effective、新 skillMasteryLevelOf、pay_cooldown 一行）、`battle_logic.gd`（`_skill_cost`、`skill_hp_cost` 各一行钩子）、`damage.gd`（_ParamProxy 转发 skillMasteryLevelOf）。
- 乙档：`garou.gd`（INHERIT 继承、mastery_source、advancing）、`toji.gd`（武器库计次）、`yunshang.gd`（符针、赊账的 mastery）、`cat.gd`（读原始等级）、`skill_notice.gd`（饿狼进阶期间不报）、`skill_scene.gd`（量条、LV 读包装后的）、`alien_battle.gd`（只改注释）。
- 新探针 `skill_mastery3_probe.cjs`。

## 验证

- 专项 `xiyou_skill_mastery` 305/305（期一、二 244 条，期三 61 条：参照 12 例逐值、两个开关的修好／回退两支、甚尔、云裳）。
- 反向 13 处（`07_开发环境/反向验证.py`）：去掉渡鸦夹上限、宿傩不读来源、渡鸦上限不跟变量 8、费用不过熟练度、升级比较前后读原始、饿狼不继承、继承时报通告、甚尔不计武器库、异化无面不取 min、通告读原始、云裳派生不换等级 都抓到；「满级判断读原始等级」抓不到（参照里没有原始等级没满、包装后满了的例子，和原版读法一致，只是没测到）。
- 甚尔武器库、云裳派生熟练度没有参照例（参照宿主 Math.random 恒 0.5，武器库 <0.5 不触发），照原版源码写、重制里自测。
- 选测 21 个全过（670 秒）：xiyou_skill_mastery、otb、determinism、event_compare、rules、rules_d3、raven_battle、garou_battle、garou_progress、alien_battle、alien_affix、sukuna_battle、toji_battle、mira_battle、yunshang、cat、skill_page、combat、battle、power、status_power。`选测.py c0245dc7` 因 battler.gd 改动列出 164 个（game 组），车道只跑战斗核心与碰到的角色专项，其余交总装按影响面选测。
- 语法检查 471 个 0 问题。没合 main（链在 mastery2 上，mastery2 还没合）。

## 可优化（流程／工具／效率）

- 无新增。

## 本分支提交

- WIP: 参照 skill_mastery3、包装后等级、渡鸦设定、费用冷却公式、饿狼继承、甚尔武器库计次、云裳派生熟练度
- WIP: 专项（期三 11 例＋甚尔、云裳）
- WIP: 宿傩 10237 计次与通告例
- 本交付单
