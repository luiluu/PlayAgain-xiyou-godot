# 交付：cc/tianqi-affix-0a

- 车道／工作者：[T015] 弱者专属词条批 0A 规则地基，cc（Opus＋medium，P8；甲档，交小A Hydrogen 核）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·未经审查】天启篇弱者专属词条批 0A：规则地基 XTianqiWeakAffix（不含任何具体词条）（dev.待定）

- 依据私密仓 `重制设定/天启篇_弱者专属词条设计_v0.3.md`（第二节第 1、2、4 那一句、5、6 条）＋ `v0.3.1.md`（第二节四条）；Kyo D65～D72（D72：先做批 0A，具体词条等基础数值定了再做）。
- 新增 `modes/xiyou/core/tianqi_weak_affix.gd`（`XTianqiWeakAffix`）＋ `modes/xiyou/tianqi_data/weak_affix_table.json`：
  - **装备与作用域**：装备实例上 `tianqi_exclusive: {key}`，只认武器、副手两格，两格同一条只算一条；生效要本人（表里 `actor`）、在场（助力位没上场不算）、活着、这条开着（`enabled`，默认全关）。每人的库存／格数／标签放本场 unit，换装、离场、倒下、战斗结束清零（每根开头对一次签名）。`text_state` 给说明文字变灰用（not_owner／off／unknown）。
  - **根与五类事件**：`act`、`_forced_run` 各开一根（进出配对；上一根没收尾时下一回合开头报警清掉）。根内阶段：主动根 → 执行完后原生追加（`XTianqiAffixBattle.end_action` 那段记原生再释放）；`_invoke` 里的原生反击、反射记 COUNTER；本模块代出的专属派生记 DERIVED（派生里再触发的反击仍算派生，不连锁）。只有主动根里出手者用根那一招的直接有效命中进 `hits`；四骑士主动技经 `horseman_strike` 同样记，回合末死期、灼烧、疫病不记。次数：每根一次、每自然回合 N 次（只在回合开始／结束清，多动、强制行动、追加不清）。
  - **最终受击者**：execute 选完目标后接专属引导，排在四骑士嘲讽、瘟疫挑衅、混子之盾三层之后（三层改过就不动）；强制行动、混乱不引导；技能要在表里「可引导」名单（默认空，D68）且单体对敌。成功后原生掩护对引导者跳过，反射、反击按引导者判。每一段前复查（execute 逐段循环和行动序列 ACTION EFFECT 两处）：引导者倒下或挂暂不倒下而 0 血 → 回原目标、摘标签；原目标也不合法 → 跳过；不重掷、不改找别人；多个引导者取出战栏靠前的。
  - **首领**：`boss_turns`（控制向下取半、取到 0 不挂；普通减益向上取半至少 1；幅度不砍）。
  - **看得见**：`badges`（角标文字）、`say`（日志一行）出口，图标和文案交小A。
  - **掉落**：`drop_candidates`／`roll_drop` 接口（池空不掷、不动任何随机；有池时走这件装备自己的流 `XTianqiRandom.item_roll`，读档不变）；**没接进掉落**，见「我不同意的地方」。
  - 具体词条以 `register(键, 处理对象)` 挂进来（`root_end`／`turn_begin`／`turn_end`／`badge`）。
- 接线（各一行或两行，全部只在天启篇档、模块开着时动）：`battle/battle_logic.gd`（setup、end_battle、start_turn、end_turn、act、_forced_run、execute 两条多段路、targets_for 记三层改没改、`_invoke` 反射／反击、`substitute_for`、`apply` 末尾、`horseman_strike` 末尾）、`battle/action_sequence.gd`（`_action_effect` 逐段复查）、`core/tianqi_horsemen.gd`（`hp_damage`：专属派生、原生反击／反射打混子不记「这次行动打过混子」）。
- 顺手对齐（v0.3.1 第二节第 3 条要求「单独登记」）：原生反击、反射打瘟疫骑士混子，以前也会记到反击者「这次行动打过混子」上，等他下次行动时 +1 不服；现在不记（开关 `COUNTER_NO_HUNZI_MARK`，单独一个 O 号）。
- 表里一条具体词条都没有、可引导名单为空，所以开着时战斗结果和没有本模块一样（专项里固定种子三方对照：没装／装着不触发的测试条目／模块关，四回合逐条日志和全员读数一致）。唯一会变的是上一条混子标记。
- 验证：新专项 `xiyou_tianqi_weak_affix` 94/94（v0.3 第二节第 6 条 11 条断言＋v0.3.1 四条，各有触发／不触发两面）；反向验证 8 处改坏全部咬住（清单 `04_验证/反向验证清单/cc_tianqi-affix-0a.json`）；选测 70 场景全过（`xiyou_tianqi*` 62 个＋`xiyou_action_sequence`、`attack_query`、`boss_sequence`、`counter_guard`、`determinism`、`raven_reflect`、`battle_common_events`、`smart_ai`）；第二批 27 场景全过（`event_compare*`、`xiyou_rules`／`rules10`／`rules_d3`／`d3b`、`smart_ai_*`、骑士战、瘟疫）；`--oracle` 的参照引擎启动检查与同源检查通过；语法检查、发行空壳 check 通过。
- 提交：见「本分支提交」
- 未完成：具体 8 条词条（批 1、批 2）；掉落接线；状态跳续转、额外费用、骑士签表（批 0B）。

## 验证

- 专项：`xiyou_tianqi_weak_affix` 94/94（无头，`--audio-driver Dummy`）。
- 选测第一批 70 场景全部通过（447 秒，日志 `04_验证/本地结果/并行测试/20261116_010809__jh1093r`）。
- 选测第二批 27 场景全部通过（1219 秒，日志 `04_验证/本地结果/并行测试/20261116_011621_eapbw6vt`）：`xiyou_tianqi_weak_affix`、`xiyou_event_compare*`（4）、`xiyou_rules`、`xiyou_rules10`、`xiyou_rules_d3`、`xiyou_rules_d3b`、`xiyou_smart_ai_*`（16）、`xiyou_tianqi_horsemen_battle`、`xiyou_tianqi_plague`。
- `--oracle`：`mv_oracle/boot_check.cjs` 正常（db true、modulesFailed []、errors []），`验证西游来源.py` issues []。
- 没跑：全量 `检查.sh`（车道不跑，选测.py 判整轮是因为改了 battle_logic，按须知交总装合并后跑）；`xiyou_rules` 其余难度段（西游档下本模块整个不开，`on()` 要天启篇档）。

## 我不同意的地方／边界

1. **掉落只给接口、没接进掉落**。v0.3 第二节第 5 条末句把掉落列在批 0A，但 D65 说「先出能掉的兵器交集表」，v0.2 第 2 节掉落还连着「占传说层那一格、三阶以上不朽及以上、深渊商人可指定、重铸保护」——这些都要有真条目和交集表才能定、才能测。现在表里零条，接上也恒为空池、不改任何结果，等于写一段测不到的死代码。建议开第一条（批 1 玛莎或克洛什）时连同交集表、商人、重铸一起接，挂在 `XTianqiAffixRoll.apply` 的传说层。
2. **「原生追加」只按阶段分**：行动执行完之后的都算原生追加（再释放单独记），行动执行中各模块自己的附带段（镜流扩散、云裳、甚尔反弹等）算在主动根里。只认「根的出手者用根那一招」的命中，所以这些不同技能号的附带段不会被当成直接命中。8 条样板里要监听原生追加的三条（艾坤截球来、魔雷老人改五雷、克洛什改追加目标）都要在 `XTianqiSkills.end_action` 的追加里截——那是 T016 正在改的地方，我没碰，开批 2 时要和 T016 的结果对接。
3. **「回原目标也算进收尾倒下结算」是防御性的**：两条多段路里暂不倒下只挂在本行动的目标（引导者）身上，回去打的原目标没挂，被打到 0 血当场就倒，现有路径碰不到这一行；反向验证清单里没列它，说明写在清单里。
4. 引导只做单体对敌（scope 1）。设计稿说第一批只给普通攻击和单体伤害技打标记，随机 N 体（scope 3～6）要不要也能引导，等签表时再定。

## 待交叉核查

- **交小A甲档（Hydrogen）**：`core/tianqi_weak_affix.gd` 全文；`battle/battle_logic.gd` 的接线（重点：`act` 里 `root_begin` 放在 `is_over／is_dead` 早退之后、`root_end` 放在 `_sync_orders` 之前；`execute` 非序列路的逐段 `segment_target` 在死亡判断之前、`continue` 不 `break`；`targets_for` 的 `guide_layers_changed` 是成员变量，xuan_battle 另调一次 targets_for 会改写它，但 execute 读的是自己那次调用紧接着的值）；`battle/action_sequence.gd` `_action_effect`；`core/tianqi_horsemen.gd` `hp_damage`。改到的原 Codex 独占核心文件：`battle_logic.gd`。
- 原版档（西游档）路径：`on()` 要 `XTianqi.active`，各钩子第一句都是关着时原样返回（发行空壳照搬这个返回值）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·弱者专属词条 | `modes/xiyou/core/tianqi_weak_affix.gd` `XTianqiWeakAffix.ENABLED`；`tianqi_data/weak_affix_table.json`；`battle/battle_logic.gd`、`battle/action_sequence.gd`、`core/tianqi_horsemen.gd` 各处一两行；`tests/xiyou_tianqi_weak_affix.gd` | 没有弱者专属词条 | 天启篇弱者专属词条批 0A 地基：专属装备认本人、五类事件与根、专属引导与掩护／多段失效、每根／每回合次数、首领减半、角标出口、掉落接口；具体词条按条开关、默认全关 | Kyo D65～D72（D72 先做批 0A）；设计稿 v0.3＋v0.3.1 | `XTianqiWeakAffix.ENABLED = false`（不引导、不记事件、不派生，专属只显示灰字） | cc | 保留 |
| O-待定·混子标记对齐 | `modes/xiyou/core/tianqi_weak_affix.gd` `XTianqiWeakAffix.COUNTER_NO_HUNZI_MARK`、`not_own_action`；`core/tianqi_horsemen.gd` `hp_damage` | 原生反击、反射打到瘟疫骑士混子，也记到反击者「这次行动打过混子」，他下次行动时 +1 不服 | 反击、反射不是他的行动，不记（盾照扣） | 设计稿 v0.3.1 第二节第 3 条「原生的也顺手对齐、单独登记」 | `XTianqiWeakAffix.COUNTER_NO_HUNZI_MARK = false`（原生反击照旧记；专属派生仍不记） | cc | 保留 |

## 交接板

- 下一步：①批 1（玛莎、克洛什，Sonnet＋medium）先出字段能力表，同时查欠账 1（技能追加只结算一段）；②开第一条词条时接掉落（见「我不同意的地方」1）；③批 2 要监听原生追加的三条等 T016 合并后对接（见 2）。
- 用户试玩说明：无（地基，玩家看不到变化；瘟疫骑士战里原生反击打到混子不再给反击者加不服）。
- 需要用户决定：无。

## 进度账

- 无（天启篇新机制地基，不进重制进度账）

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 9b62058a4 XTianqiWeakAffix 与战斗接线（WIP）
- 后续提交：专项、反向验证清单、交付单（见 `git log main..cc/tianqi-affix-0a`）
