# 交付：luiluu/cc-t117-brand-core

- 车道／工作者：T117（T073-b）烙印本体：力量、存档、一条线暗装（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-17 【cc·T117·未经审查】天启篇烙印本体 XTianqiBrand：力量、存档、一条线暗装（开关关着）（dev.待定）

- 依据：私密设计仓《天启篇_烙印 v0.5》第十三节 T073-b（第三、五、九、十、十一节），Carbon v0.4 复核 P2-2／P2-3／P2-4。数据表 `tianqi_data/brand.json`（T116，dev.680）。
- 新脚本 `modes/xiyou/core/tianqi_brand.gd`（`XTianqiBrand`，开关 `ENABLED` 默认关，T073-e 翻）：
  - 存档：角色 `XActor.zhenqi` 的 `brand`（万分点整数）／`brand_carved`／`brand_realm`；首胜表放 `flags.tianqi.brand.firsts`（`XTianqiSave` 新分区 `brand`，稿里叫 `brand_firsts`）。`XZhenqi.from_save` 只在读进来的数据里本来就有这三个键时原样留，不新建。
  - 力量：`mult` ＝ 1 ＋ 0.5 ×（烙印÷100）^形状，只读烙印值；接在 `XTianqiBase.k_actor_mult`（K 那一项的口子，T081 留的）。`k_for` 改成「K（期四关着为 1）× 烙印乘数（烙印关着为 1）」，两个开关各管各的，两个都关着恒 1；`scale_direct` 直接扣血也跟着乘。敌人、西游档恒 1。
  - 一条线：节点、`at_node`、`can_stand`（甲二门禁 P2-2：没刻印且已在铸骨不放第 3 场心魔）、`stand`、`carve`、`cap_now`（第五节第 6 条公式）、唯一写入口 `gain`（万分点四舍五入、封顶截断、到节点飘「烙印已到瓶颈」）。
  - 认这一场：`facts_of`→`classify`（第五节第 4 条六步次序；骑士、影子先于守层者认，七首之龙、七印【里】首领、鸿钧各自的键；主席 745／752、研究员 893 按编号排除；名字前缀白名单；不调 `is_boss_enemy`）；`tier_of` 只有 `XDungeon.inside` 时才读副本档位变量；生熟 `is_ripe` 开战时定、整场不变。常规事件战的键 `ev:地图:事件:敌群` 由 `mv_interpreter` 301 开战前记 `pending_event`。
  - 结算 `settle`（`BattleLogic.grant` 里接在真气后面）：首通（出战 ×1 含倒下、助力位 ×0.5、后备 0）、再打（差距 10%，下限 0.25×难度系数，助力位 ×0.5）、烙实入口（灼痕满过几次 × 0.75、一场最多 2 次；T073-d2 之前 `fills` 为空＝按 0 条）。P2-4：层线按这一场的层算，「已通关 36 层」等结算完写首胜表才置位，36 层首通完正好 95%。
  - 面板：`panel`（亮段、刻度线、暗段、封住段、「+」、P2-3 高亮）、`bar_text`（文字条）。闭关菜单在开关开着的天启篇档里换成烙印页：一根文字条＋「烙印 N%+」＋天启注视一行（期四开着时），「刻印」（二次确认）、「挑战心魔」（只在能打时出现）。
- 接线（只加烙印接线，不改别人逻辑）：`battle_logic.gd` setup 末尾 `battle_setup`、grant 里 `settle`；`zhenqi.gd` from_save 保留键、开关开着时 on_victory 不再涨真气、闭关页分流；`tianqi_base.gd` `k_actor_mult`／`k_for`；`tianqi_save.gd` 登记 `brand` 分区；`mv_interpreter.gd` 301 记事件；`tests/xiyou_virtual_player.gd` 加 `--vp-brand`（开着跑）；`07_开发环境/发行空壳特例.json` 补两行。
- 专项 `tests/xiyou_tianqi_brand`（77 条）：关着逐字节同原来、西游档／天启篇档读存来回不变、第十一节第 1 步（0→100% 1.50 倍、七个节点逐个对，经 `XDamage.calculate` 对木桩）、稿内专项 1～7、P2-2／P2-3／P2-4、真开一场 6 层守层者 setup→grant 端到端。
- 玩家可见：无（开关关着）。

## 验收逐条对照

| # | 验收 | 对应 |
|---|---|---|
| 1 | 开关关着逐字节同原来；西游档读出来再存回去逐字节不变；`--oracle` | `default_off`、`off.mult`、`off.dealt`、`off.no_meta`、`off.settle`、`off.menu_qi`、`off.xiyou_roundtrip`、`off.xiyou_no_keys`、`off.tianqi_roundtrip`、`off.keys_kept`、`off.no_section`；`检查.sh --oracle --affected main --cloud`（见「验证」） |
| 2 | 开着，第十一节第 1 步过线 | `power.ends_1.50`（误差 ≤0.5 个点）、`power.nodes`（七个节点）、`power.k_slot`、`power.enemy_1`、`power.xiyou_1` |
| 3-1 | 到节点再打 10 场不变，打赢心魔后接着涨 | `t1.stall_10`、`t1.no_gain_toast`、`t1.stand`、`t1.grows_after`、`t1.no_double_stand` |
| 3-2 | 没通关 36 层、已在层线上再打 100 场不变 | `t2.line20`、`t2.stay_100` |
| 3-3 | 33 层不让 34 层熟；6 层哥布林、35 层影子不让 36 层骑士熟；早期副本首领不让七印【里】熟 | `t3.keys_33_34`、`t3.summit_raw`、`t3.horseman_key`、`t3.horseman_raw`、`t3.qiyin_raw`、`t3.ev_ripe`、`t3.ev_other_raw`、`t3.survival_none`、`t3.dragon` |
| 3-4 | 主席、研究员、【前所未见】、【精英】、心魔、五条悟试炼打赢后不变、不进首胜表 | `t4.kind_*`（9 种）、`t4.no_gain`、`t4.no_firsts`、`t4.special_raw`、`t4.boss_prefix` |
| 3-5 | 低档打赢的换高档还是生的；大厅、七印读到 1 | `t5.higher_raw`、`t5.same_ripe`、`t5.outside_1`、`t5.inside_tier`、`t5.records_max`、`t5.keeps_max` |
| 3-6 | 最低难度助力位再打正好 +13 万分点 | `t6.plus13`（9500→9513）、`t6.fighter_plus25` |
| 3-7 | 不刻印、铸骨、40%：没入口、不写「+」、40% 往后封住、木桩 1.20 倍、刻了印入口出现 | `t7.dmg_1.20`、`t7.gate_closed`、`t7.no_plus`、`t7.bar_sealed`、`t7.no_entry`、`t7.trial_refused`、`t7.cap40`、`t7.carve_confirm`、`t7.carved`、`t7.entry_after_carve`、`t7.plus_after_carve`、`t7.trial_battle` |
| 4 | P2-2 甲二门禁；P2-3 撞节点高亮＋「烙印已到瓶颈」；P2-4 36 层首通结算次序（正好 95%） | P2-2 同上 t7；`p23.highlight`（5～30 层六个节点）；`p24.segment_ends`（每 5 层末正好在节点）、`p24.exact_95`（36 层那一场带 2 次灼痕满也正好 9500）、`p24.cleared36_after`、`p24.helper_half` |
| 5 | 数值卡 DoD | 烙印开着（`--vp-brand`）：explore 种子 1 `TEST_RESULT 14/14`；climb `--vp-frames=40000` 种子 1 `6/6`；卡死 0（stuck []、stalemates 0）、脚本报错 0、violations []（负血负钱 0）、存档读写正常（VP 自带检查过）。短帧 climb 只到第 1 层、全灭 1 次（等级 1 的开局队），没打赢首领，**烙印结算在 VP 里没被走到**，端到端由专项 `e2e.*` 覆盖 |
| 6 | `检查.sh --affected` 过、交付自检 0 | 见「验证」 |

## 甲核 R1 返修（小A 报告 `协作交接/附图/T117/小A甲核报告_R1.md`）

- P1 已修：七印里副本前两场精英（灰印 297、默印 220 借【首领】名敌群）原来被名字前缀认成首领。`facts_of` 加 `qiyin_elite`（有里副本规则、不是首领那场、不是书卷揭的），`classify` 命中就判「不是首领战」。补 `qiyin_real.*`：经 `XTianqiQiyinRule.prepare`→`BattleLogic.setup`→`facts_of` 真实路径验 297、220 为 none、灰印首领那场为 `qiyin:hui`；反向验证过（去掉这条判断两条都挂）。
- P2-1 已修：`gain` 写入前 `_ensure_keys`（专项 `gain_ensure_keys`：zhenqi 为空的角色写完 qi 等键都在）。
- P2-2 已修：开着烙印时闭关列表页头换成烙印文案（`TEXT_RETREAT`，专项 `retreat_head_brand`）。
- 文字审第四节 1～5 照改（页头、心魔门槛两句、瓶颈两句、刻印确认两句、按钮「刻印」→「进行刻印」）；第 6 条「立入」还是「立锚」翻开关前请 Kyo 定，本单不改。
- P3-2 已修：`from_save` 只认数字类型的烙印键；`XSaveCheck.actor_row` 校这三个可选键；`XState._become_current` 清 `pending_event`。
- P3-1 没改，交设计：死亡线第 2 节节末精英 `spread`（敌群 294，借 333【首领】罗奇）现在按名字前缀算首领战；饥荒线的 `spread`（430）注释写的是节末「首领」。稿里没写四线节末这一场算不算首领战，请协调／Kyo 定一句，改法是在 `classify` 里按线表的 `spread` 敌群号排除或认（一行）。
- 不在本单、交翻开关前的界面卡：主菜单「真气」项（`ui/menu.gd` 第 29 行、`ui/skin/ui_skin.gd` 第 224 行「真气／闭关突破」）、人物状态页（`ui/status_page.gd`）、战力条（`ui/power_strip.gd`）里的「真气」字样，开着烙印时都要换。

## 玩家可见文字（合前请小A 文字审）

开关关着玩家看不到；翻开关（T073-e）前要定稿。全在 `tianqi_brand.gd` 顶部常量和 `zhenqi.gd` 的 `_brand_page`／`_brand_carve`／`_brand_trial`：

- `%s 的烙印已到瓶颈`（到节点飘字、烙印页一行；P2-3）
- `%s 的烙印已到瓶颈，本场未再增长。`（停在节点上的人打赢首领战）
- 闭关列表页头（R1 改）：「烙印」「烙印随首领战加深，到每境节点后，打赢心魔即可立入下一境。」「未刻印只能停在铸骨（40%），刻印后可继续推进。」
- `烙印 %s`（结算飘字，如「烙印 狗逍遥 +3%，…」）
- 刻印确认：「一旦刻印，烙印只涨不降，没有回头路。」「刻印后，每首通一位守层者都会加深烙印；不刻印则只在首领战挨打时记下烙印，上限 40%。」按钮「刻印」「再想想」；烙印页入口「进行刻印」；完成「%s 刻下了烙印。」
- 心魔：「烙印还没到本境上限，暂不能挑战心魔。」「未刻印到此为止，先进行「刻印」才能继续挑战心魔。」「%s 不在出战队伍中。」「请先把%s编入出战队伍再打心魔。」「心魔幻化为第%d层守层者之力。」「%s必须坚持到战斗结束，才能立入下一境。」「%s 立入%s！」「%s 未能立入%s。」「（打心魔的角色需活到战斗结束）」
- 闭关列表「［可打心魔］」、烙印页「（未刻印）」、选项「挑战心魔」
- 「刻印」「烙印」同屏（稿第十二节提醒）：烙印页同时有选项「刻印」和条旁「烙印 N%」，请专门看一眼

## 我不同意的地方／没做的

1. **面板只做了文字条，没画图形条**。稿要「一根条、刻度线、+、暗段」；`panel()` 给出全部数据（亮段、节点、暗段止点、封住起点、+、高亮），闭关页现在用 `bar_text` 画一根 20 格文字条（■亮 ▒暗 ×封住 □空，节点 |，高亮 ‖）。真正的图形条和角色状态页放哪一行属于界面皮肤（XUiSkin），建议翻开关前派一张界面小单，读 `panel()` 画。
2. **使徒的键用 `guardian:<层>`**，没用稿里的 `apostle:<线>:<第几位>`。查下来使徒是 10／20／30 层守层者被战争线改出来的（`XTianqiWarAlien`），首通奖本来就该是那一层守层者的；单独起键反而让同一层能拿两次首通。稿写「上下文字段开卡时核」，我按这个结论定了，有异议请协调说。
3. **心魔战沿用旧瓶颈之战的幻化**（`trial_ref(s, 1)`，按修行进度层的守层者 ×1），只把门禁换成 `can_stand`、打赢调 `stand`。心魔战自己的强度和规则稿说不在本稿范围；旧 14 境的境界奖励、道法在烙印开着时不再从这里发（新七境的境底、境支、道法是养成线第三期的事）。
4. **烙印开着时闭关页不再显示真气**、胜利不再涨真气（稿第十节「原来的真气在天启篇不再涨」）。旧 `qi`、`realm`、`firsts` 原样留着不删。
5. **「烙印已到瓶颈」对甲二封住的人不飘**：不刻印、铸骨 40% 的人到了节点也不提示，理由同面板不写「+」（他打不了心魔，提示是假的）。
6. **层线取「主塔进度（变量 20）」和首胜表的大者**：首胜表里有守层者／鸿钧／影子／骑士键就算通过到那一层；影子＝35、骑士＝36（任一线）。
7. 首胜表放在 `flags.tianqi.brand.firsts` 而不是根上的 `brand_firsts` 散键：车道须知「新存档字段放 flags.tianqi.<分区>」要求的写法，意思一样。

## 交接板

- 下一步：T073-c 常驻六条、T073-d1 发作、T073-d2 灼痕与烙实（`settle` 已读 `fight(logic).fills`：actor_id → 这一场满过几次）、T073-e 翻 `XTianqiBrand.ENABLED`；翻之前派一张界面小单画烙印条（见上第 1 条），文字过小A。
- 用户试玩说明：无（开关关着）。
- 需要用户决定：无。

## 进度账

- 天启篇烙印：T073-b 本体暗装完成（开关关着）。

## 可优化（流程／工具／效率）

- 已做：虚拟玩家加 `--vp-brand`，开着烙印跑 explore／climb（不加就照旧；回退＝删那两行）。
- 建议：VP 的短帧 climb 在种子 1 下 4 万帧只到第 1 层、开局队全灭，测不到任何首领战结算；数值卡 DoD 想覆盖结算，可以给 VP 一个「开局直接给中期存档」的入口（归虚拟玩家车道）。

## 验证

- `python3 07_开发环境/语法检查.py`：994 个 .gd，0 个问题。
- 专项 `xiyou_tianqi_brand`：77/77（R1 返修后 82/82），日志零 SCRIPT ERROR。
- 虚拟玩家（`--vp-brand`）：explore 14/14；climb 4 万帧 6/6，stuck 0、stalemates 0、violations 0、脚本报错 0。
- `检查.sh --oracle --affected main --cloud`：第一轮云端 421 个场景全过、只挂「发行空壳缺成员」（XTianqiBrand.realm／last_realm），补进 `07_开发环境/发行空壳特例.json`（发行值 0／6）后第二轮（提交 c58b99f18 快照）退出码 0：云端选测通过、MV 参照引擎启动检查通过、「选测全部通过」。
- R1 返修后（提交 f13cb990f）本机选测：`xiyou_tianqi_brand`（82/82）、`xiyou_zhenqi*`、`xiyou_save_corrupt`、`xiyou_save_cold_load`、`xiyou_tianqi_save`、`xiyou_tianqi_phase4`、`xiyou_tianqi_no_x6`、`xiyou_tianqi_ledger`、`xiyou_determinism`、`xiyou_tianqi_qiyin*` 共 20 个场景全过；`语法检查.py` 995 个 0 问题；`发行空壳.py check` 67／606 全有；`工具回归.py` 全过。R1 只改 tianqi_brand／zhenqi／save_check／xstate 与专项，没碰 battle_logic，`--affected` 云端全选测沿用 c58b99f18 那轮。
- 交付自检：见回报（标可合并、提交之后跑）。
- 附带：`k_for` 保留开头早返（两个开关都关着直接 1.0），发行空壳照规则 2 照搬 1.0，不会落到 float 默认 0.0。

## 本分支提交

- 见 `git log main..luiluu/cc-t117-brand-core`
