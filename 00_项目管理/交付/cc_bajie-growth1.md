# 交付：cc/bajie-growth1

- 车道／工作者：C 规则·机制／八戒（cc，Opus medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-03 【cc·八戒·未经审查】成长装备期一：心之钢／杰作利维坦、狂妄／杰作无我（dev.待定）

派单：交接板「下一步」第 3 条（悟空 gaps4 盘点表第 5 行、分簇第 3 簇），两期里的期一。

### 一、来源核对（走得到）

- 原版两件都只从**不朽线的未知存在**掉：Map152、来源地图 38（没记来源时按变量 107＝1）、敌群 454／455 胜利，各 10%、每场一次（心钢在 `installNativeLeviathanForge` 的 endBattle 包装里掷，狂妄在自己的包装里随后掷）。
- 切片里 Map038、Map152、敌群 454／455 都在（`xiyou_floor_abyss037` 走的就是无尽虚空→未知存在），装备 7900～7903、技能 10227／10228 已转换；未知存在来源地图 `XState.unknown_origin` 早已接上。没有别的来源（商店、合成、事件都没有）。

### 二、原版参照 `heartsteel_probe`（39 例，不进同步，拷成 `tests/fixtures/heartsteel_oracle.json`）

- 公式（阶数、每阶所需层数）；穿上后的最大生命／物攻／双防（阶数倍率、旧版累计生命平加、扬名倍率）、技能列表、meetsSkillConditions（战斗外、蓄力 2／1／0、没记蓄力、错配）、常态最大生命；掉落 10 组条件；敌人权重；巨人吞噬减防。
- 真实 BattleManager 打 3 号敌群：心钢蓄力→巨人吞噬（伤害、待结算、冷却 3、同一行动不重复结算）→回合末回血→第二次施放→胜利存层数；逃跑不存。狂妄：原版口径、修复口径（见四）、首领分段，扬名倍率、剩余回合递减到清除、死亡清除、胜利存盛名；物防穿透前后同一招的伤害。
- 新装备入包会随机掷词条（心钢／狂妄带 `<Prefixes>`），探针记下实例的属性与特性，重制专项照它设实例。

### 三、移植（`core/heartsteel.gd` XHeartsteel、`core/hubris.gd` XHubris，新文件）

- 层数／盛名照原版字段名存在装备实例上（`_codexHeartsteelStacks`、`_codexHeartsteelHp`、`_codexHubrisFame`），随存档；旧档实例没有这些字段按 0（原版缺省同）。
- 心钢：最大生命 ×(利维坦 1.1＋)0.1×阶（param 包装，取整夹上限）、旧版累计生命（paramPlus）、技能表换成对应的巨人吞噬、技能条件（战斗中、蓄力满、对应的一件）、蓄力按行动计（强制行动不减）、巨人吞噬公式 `CodexHeartsteel.damage`（运行时按公式文本认，不改转换器）、命中按敌人权重记本场待结算、胜利才存、回合末回复 3%／5%、掉落。
- 狂妄：物防穿透两层（公式里目标物防 ×(1−18%／27%)、伤害钩子物防率 ×0.82／0.73）、贡献（2 次行动内）、击杀与协助、首领分段、扬名（倍率按已存＋待结算算、持续 3／4 个完整回合、刷新不叠加、死亡／卸装／战斗结束清除）、胜利存盛名、掉落。
- 接线：`battle_logic.gd`（startBattle、meets、startAction、endAction 含强制行动、endTurn、apply、executeHpDamage、endBattle 与掉落）、`actor.gd`（skills、paramPlus、param）、`enemy.gd`（param 公式帧）、`formula_execution.gd`（巨人吞噬公式、狂妄公式帧）、`actor_damage_hooks.gd`（hubris 钩子）。

### 四、原版缺陷：狂妄击杀永远记不上（O-待定，可回退）

原版 YEP 把倒下状态延后到行动结束才挂，狂妄的 executeHpDamage 包装里 `isDead()` 还是假，`_codexHubrisKilledByParty` 设不上：**普通击杀与协助一次扬名都不给**，只有首领每掉一成生命那条路能触发（参照 `hubris.battle.*` 量到）。重制默认按「生命被本方打到 0」算击杀（参照 `hubris.fix.*`：探针里只把这一个判断改成生命到 0，其余全走原版代码量出来的）；`XHubris.KILL_FIX = false` 回到原版。

### 五、专项 `xiyou_heartsteel`（新）

逐例对参照：公式、穿上后能力值、技能与条件、掉落、权重、减防、全部战斗步骤（命中值、蓄力、待结算、层数、回血、扬名倍率与剩余回合、行动数），另加存档往返（穿着的、背包里的）与旧档缺字段按 0。

## 待交叉核查

- 新文件：`core/heartsteel.gd`、`core/hubris.gd`、`tests/xiyou_heartsteel.gd`、`mv_oracle/heartsteel_probe.cjs`。
- 原沙僧核心文件改动：`battle_logic.gd`（10 处钩子，见三）、`actor.gd`（param／paramPlus／skills 三处）、`enemy.gd`（param 末尾公式帧）。请重点核：
  - param 包装次序：心钢（第 15 个）、狂妄（第 17 个）放在 `XActorModules.param` 外、`XCat.param` 内；原版宿傩（第 18 个）在它们外层，只管 172，差别只在取整。
  - 狂妄公式帧用 `XHubris.formula_param` 包在角色与敌人 param 最外层，只认执行路径的目标本体（AI 估伤用克隆，不打折）。
  - 敌人倒下判定在重制里用 `hp<=0`（重制没有延后倒下），结算点在 endAction／endTurn／endBattle。
- 掉落用战斗规则流 `next_float`（原版 Math.random）。

## 交接板

- 下一步，改写第 3 条：成长装备期一（心钢＋狂妄）已交；期二＝利维坦锻造（`installNativeLeviathanForge` 213 行：配方 457、锻造锤 2867 掉落 Map176、解锁）＋杰作无我锻造（狂妄文件里的 forge 段：配方 458、200 人道意志碎片 2530＋5 锻造锤）＋魔冠 `installNativeDemonCrownRuntime`；另有尾项：两件的动态说明（`help_card.gd` 写着未做）、智能 AI 选巨人吞噬（`Codex_SmartBattleAI.js` 引用 7900）、战力（`installCombatPowerRuntime.js`）、甚尔抑制行动不减蓄力。
- 用户试玩说明：不朽线未知存在（无尽虚空进去的那张）打赢有 10% 各掉心之钢、狂妄；心钢穿上多一招巨人吞噬（开战行动两次后可用），命中积累心钢层数、胜利保存，最大生命随阶数涨，回合末回血；狂妄物理攻击无视部分物防，参与击杀或打首领掉血得扬名（物攻提高几回合），胜利积累盛名。物品说明里的层数／进度文字还是静态的（期二做）。
- 需要用户决定：狂妄击杀判定（O-待定）——原版普通击杀与协助永远不给扬名（只有打首领掉血给），重制默认修成「打到 0 血就算」；要原版口径就设 `XHubris.KILL_FIX = false`。

## 优化登记草稿

| O-待定 | 狂妄／杰作无我击杀判定（`core/hubris.gd` `after_hp`） | 原版倒下状态延后挂，executeHpDamage 包装里 isDead() 恒假，击杀与协助永远不给扬名，只有首领分段触发 | 生命被本方打到 0 就记本方击杀，击杀与 2 次行动内的协助按权重给扬名与盛名 | `XHubris.KILL_FIX = false` |

## 进度账

- 养成·成长装备（dev.239 养成表）：0% → 约 40%，依据：四件里心钢、狂妄两件的成长、技能、战斗规则与掉落已移植并对上参照；两件锻造、魔冠、动态说明在期二。

## 可优化（流程／工具／效率）

- 建议：选测对 `battle_logic.gd`／`actor.gd`／`enemy.gd` 一律选 235 个场景（等于全量），车道只加一个新钩子也是这样；可以给「只新增一行 `XFoo.hook(...)` 调用、新模块独立」的改动一个窄口径（新模块专项＋战斗核心抽样），预计每条车道省 20～30 分钟。归哪吒。
- 已做：本车道没改工具。

## 验证

- 原版探针 `node heartsteel_probe.cjs`：39 例无错。
- 专项 `xiyou_heartsteel`：391／391（含存档往返与旧档缺字段）。
- `python3 07_开发环境/语法检查.py`：491 个 .gd 无问题。
- 选测 `选测.py main --list` 列 235 个（改了 battle_logic／actor／enemy＝战斗核心全选，近全量）；按派单不跑全量，`并行测试.py --jobs 2` 跑了 50 个：xiyou_heartsteel、xiyou_determinism、xiyou_event_compare、xiyou_battle、xiyou_combat、xiyou_actor_modules、xiyou_tusu、xiyou_tusu_battle、xiyou_yunshang、xiyou_yunshang_wraps、xiyou_alien_battle、xiyou_alien_affix、xiyou_formula_effects、xiyou_formula_equipment、xiyou_formula_program、xiyou_formula_rest、xiyou_custom_damage、xiyou_boss_output_context、xiyou_equipment、xiyou_param_cache、xiyou_param_max、xiyou_param_states、xiyou_smart_ai（_f／_k／_p）、xiyou_module_hooks、xiyou_battle_gaps、xiyou_power、xiyou_raven_battle、xiyou_garou_battle、xiyou_toji_battle、xiyou_sukuna_battle、xiyou_guyu_battle、xiyou_mira_battle、xiyou_yomi_battle、xiyou_cat、xiyou_actor1_damage、xiyou_otb、xiyou_skill_mastery、xiyou_floor_abyss037、xiyou_rules（抽 d1f／d2c／d3f／d4h／d5／d6c）、xiyou_race_battle、xiyou_party_skills——全部通过（894 秒），无偶发。没跑的约 185 个（楼层流程、界面、其余 rules 段等）留给总装合并后选测／每日全量。
- 回退开关：`XHubris.KILL_FIX = false` 由专项 `hubris.battle.*`（原版口径）覆盖；O 号由总装分配后登记，`回退开关覆盖.py` 才会计入。
- 交付前合了 main（225e1633，只有交接板／登记／开发编号），没碰本车道文件，不重跑。

## 本分支提交

- 3739b9d5 心钢／狂妄原版参照探针 heartsteel_probe
- 37395338 运行时 XHeartsteel、XHubris 与各处接线
- 31d9ea41 专项 xiyou_heartsteel
- f8f75098 专项加存档往返；交付单草稿
- d37a8b5c 合并 main
- （本提交）交付单可合并
