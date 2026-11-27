# 交付：luiluu/t532

- 车道／工作者：T532 元素伤终态（T451 续）／cc（Opus 5.5＋medium，职级 P8；`ctx_aa3a96b034d5`）
- 状态：可合并

## 变更记录草稿

## 2026-11-27 【cc·T532·未经审查】天启篇固定词条元素伤终态：普通防具本体全身合计 ≤ +20%、晶石神文按孔拆单记、防具单件重排提案（dev.待定）

- 依据：预算稿 `重制设定/天启篇_全局数值预算_v0.16.md`（@093e51d1）第九节第 2 件、附表一 T451 行、附表四「元素伤（单系）」行；D290（Kyo 11-26 全按推荐）；协调 11-27 批文件清单与 Q1～Q3 口径。
- 过渡办法（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_gear.gd`）：新增 `XTianqiGear.armor_elem_capped`，在 `stat_list` 里 `elem_amp_view` 之后调用。gear_elem_amp.json 表里普通防具的**本体那份**（`_tq_ea_amp`，T451 的单件数），在副手～戒指 9 个栏位（etype 2～10）上按每一系（含物理 1）全身相加，超过 `armor_cap.pct`（20）时各件等比缩到合计 20；宝珠、强化（晶石／神文）、符文之语、随机词条增量不进合计、不缩；武器全额不进；法宝（13，系别法宝线）、坐骑（16）、神器（17，成长神器线）、专武（skill_rework）不进；**R1（小o 核 P1-1）**：七印生成件（带 `qiyin` 标记，借原版防具底板编号与栏位）和天启篇奖励实例（带 `tq_reward`）也不进、不缩，判定收在 `XTianqiGear.plain_armor`，终态开关同用这一判定。原实例不改写，只改视图。回退开关 `XTianqiGear.ARMOR_ELEM_CAP := true`。
- 晶石、神文按孔拆单记（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_ledger.gd`，协调批的只动 `upgrade_amplify`＋桶名表）：新增 `upgrade_holes`（镶嵌历史逐孔一行：孔号、材料号、来源 crystal／rune／other、元素、值）；`upgrade_amplify(eq, src)` 可按来源过滤；`passive_buckets` 多出 `enhanceSplit {元素: {crystal, rune, other}}` 汇总，**R1（小o 核 P1-2）**另出 `enhanceHoles` 逐孔明细（每孔一行：装备实例 `instanceId`、底板号、栏位、孔号、材料号、来源、元素、值）。`enhance` 桶合计与额度、九线、分池逻辑**一行未动**（明细只记不扣）。数值本来就等于附表四（晶石 1025～1034 每孔 +5%、神文 306～314 每孔 +1%，只能镶武器），没改数。
- 被动缓存（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/actor.gd` `_refresh_passive_now`，**R1 小o 核 P1-3**，独占外）：O-396 的缓存签名原来只比备注、标签、状态施加者；正常镶嵌（`XGearUpgrade.apply`）和防具封顶开关只改 `yep`／`upgrades`，缓存不失效，账本还是旧值。签名每件多加 `hash([yep, upgrades])`，西游档同样生效（只会多重算，不改结果）。
- 终态单件重排（提案，**默认关，待 Kyo 定**）：`gear_elem_amp.json` 升 version 2，540 件防具各加 `final {amp, subs}`，规则写在 `armor_final_rule`（一档 1、二档 1／2、三档 2、四档 2／3、五档 3，且不高于 T451 值；整数避 4）；卡面 `subs` 同步改好（502 行替换，`armor:4094` 手补一行）。开关 `XTianqiGear.ARMOR_FINAL := false`，开了只对 etype 2～10 生效，合计上限照旧兜底。
- 校验（`03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`）：version≥2 时查 `armor_cap`（避 4 整数 1～100）、`armor_final_rule`、每件防具必有 `final`、`final.amp` 元素键同 `amp`、值避 4 正整数且不高于 T451 值且在本档区间、`final.subs` 与 `subs` 逐对同旧串。
- 测试与工具：新专项 `tests/xiyou_tianqi_t532_elem_final`（11 项，R1 加七印混穿、正常镶嵌即时进账、已建缓存同进程切开关三项）；`tests/xiyou_tianqi_ledger_p3` 的 `t473_4535_affix_capped_all_pools` 改断言（4535＋4285 两件防具元素合计现在被封到 20，到不了旧九线元素顶 30，元素那一刀为 0，其余断言不变）；`发行空壳特例.json` 登记 `XTianqiGear.stat_list`（发行时原样返回 list）；量数包装 `tests/virtual_player/t532_elem_bench.gd`；虚拟玩家 `_act_choice` 把天启篇选线确认（确定／再想想）排到闭关意图前面（原来闭关意图下会选「再想想」兜圈子，见下「虚拟玩家」）。
- 玩家可见：天启篇里普通防具（头、身、手、腿、鞋、腰、项链、戒指、副手）给的元素／物理增伤，全身同一系加起来最多 +20%（原来九件能叠到一百多）；武器、宝珠、强化、符文之语、随机词条、法宝、神器那几份不受影响。装备说明卡上单件的数不变（合计上限只在算伤害时生效）。西游档不变。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·T532防具元素合计上限 | `modes/xiyou/core/tianqi_gear.gd` `XTianqiGear.ARMOR_ELEM_CAP`（`armor_elem_capped`、`stat_list`）＋`tianqi_data/gear_elem_amp.json` `armor_cap` | T451 后普通防具单件 5～20%，9 件全身每系能叠到 ~180% | 本体那份全身每系合计 ≤ +20%，超了等比缩；增量与武器不动 | 预算稿 v0.16 九.2 过渡办法，D290 | `XTianqiGear.ARMOR_ELEM_CAP = false` | cc（T532） | 保留 |
| O-待定·T532防具单件终态 | `modes/xiyou/core/tianqi_gear.gd` `XTianqiGear.ARMOR_FINAL`＋`gear_elem_amp.json` 各防具 `final` | （同上） | 防具单件重排到 1～3（满穿合计入额） | 九.2「之后重排防具单件数」；改 Kyo 事项 50 亲定的数 | 现默认关；开了要回退设 `false` | cc（T532） | 待 Kyo 定 |

## 交接板

- 下一步：换家核查（小o 6.2-sol high）；Kyo 定终态单件表（见「要 Kyo 定」）后开 `ARMOR_FINAL`；T450 重标时用的是封顶后的防具元素伤。
- 用户试玩说明：天启篇防具元素增伤全身合计封 +20%，穿满高档普通防具的输出会低一些（R1 复跑：B 档 33 层赢的两场回合数 7→13、20→19，其余不变）；西游档不变。
- 需要用户决定：防具单件终态表（下表，开关默认关）。

### 要 Kyo 定：防具单件终态（新旧对照）

满穿＝副手～戒指 9 个栏位都穿同档、同一系都带的最高情况。

| 档（等级） | 件数 | T451 现在单件 | 现在满穿合计（过渡封 20 前→后） | 提案单件 | 提案满穿合计（封 20 后） |
| --- | --- | --- | --- | --- | --- |
| 一（1～29） | 43 | 3～7% | 最多 63% → 20% | 1% | 9% |
| 二（30～49） | 116 | 5～10% | 最多 90% → 20% | 1%（原≤8）／2% | 18% |
| 三（50～69） | 193 | 5～13% | 最多 117% → 20% | 2% | 18% |
| 四（70～79） | 182 | 15～18% | 最多 162% → 20% | 2%（原≤16）／3% | 27% → 20% |
| 五（80+） | 6 | 19～20% | 最多 180% → 20% | 3% | 27% → 20% |

不定的话照现在：单件数不动（说明卡照 T451），只有算伤害时合计封 20。

## 进度账

- 天启篇数值体系（v0.16 九.2 固定词条元素伤）：过渡办法与拆单记完成；终态单件表已备好、待 Kyo 定后开关。

## 可优化（流程／工具／效率）

- 已做：虚拟玩家选线确认排到闭关意图前面（`tests/virtual_player/virtual_player.gd` `_act_choice`；回退＝把那段 `elif` 挪回 `_intent == "zhenqi"` 后面）。原来闭关意图还留着时，选线确认走 `_zhenqi_choice`→`_brand_choice`，回「再想想」，大厅选线对话无限兜圈（「同一句对话在原地重复了 80 次」）。本分支上种子 1 短帧 climb 2/2 次复现（第 6 层），改后同种子通到 17 层、跟 main 基线一样。
- 建议：`t532_elem_bench.gd`／`t533_pass_bench.gd` 这类开关对照包装可以并成 T438 脚手架一个通用参数 `--set=类.开关=值`，省得每张卡写一个包装（归工具车道）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqiGear.stat_list`（中间多一步 `armor_elem_capped`） | 3 处（`git grep -n "stat_list(" -- '*.gd' \| grep -v "func \|tests/"`：`core/actor.gd` 的 `stat_equips`、`_param_plus` 一带、开战状态那处） | 调用方 3 处逐处结论：都是拿装备视图算特性／能力值／开战状态；新一步只改表里普通防具的 `yep.elementAmplify`，不动 params、traits、note、开战状态；西游档 `elem_amp_on()` 假直接返回原列表（专项 `t532_west_unchanged` 逐个 `is_same`） |
| `XTianqiGear.elem_amp_view`（多写 `_tq_ea_amp`；ARMOR_FINAL 开时读 final） | 3 处（`git grep -n "elem_amp_view(" -- '*.gd' \| grep -v "func \|tests/"`：`stat_list`、`ui/help_card.gd` 两处） | 调用方 3 处逐处结论：说明卡两处只读 note／meta／yep，多一个私有键无影响；ARMOR_FINAL 默认关，关时行为与 T451 相同（`t451_*` 专项 25/25 照过） |
| `XTianqiLedger.upgrade_amplify`（加可选参数 `src`，内部改走 `upgrade_holes`） | 1 处（`git grep -n "upgrade_amplify(" -- '*.gd' \| grep -v "func \|tests/"`） | 调用方 1 处逐处结论：`passive_buckets` 不传 `src`＝全部，与原来同值（`t530_ledger_core` 59/59、`t532_crystal_rune_split_per_hole` 验 enhance 合计） |
| `XTianqiLedger.passive_buckets`（返回多 `enhanceSplit` 键） | 1 处（`core/actor.gd` 存进 `bySource`） | 调用方 1 处逐处结论：读 `bySource` 的地方都按名字取键，没有遍历全部键的；新键只给对账看 |
| `XActor._refresh_passive_now` 的缓存签名（每件多加 `hash([yep, upgrades])`） | 1 处函数体内（`git grep -n "_refresh_passive_now()" -- '*.gd'` 5 处调用都经过这一段） | 调用方 5 处逐处结论：只让 yep／upgrades 变了时不复用旧缓存，算出的表与不缓存时相同（READ_VERIFY 同口径）；没变时照旧命中；西游档多一次哈希，结果不变 |
| `XTianqiGear.plain_armor`（新） | 2 处（`armor_elem_capped`、`elem_amp_view` 的终态判定） | 只认副手～戒指栏且无七印／奖励标记 |
| 新开关 `XTianqiGear.ARMOR_ELEM_CAP`（默认开）、`XTianqiGear.ARMOR_FINAL`（默认关） | — | 专项 `t532_armor_cap_in_ledger_and_switch`、`t532_armor_final_switch` 各设回退值验 |

## 验收逐条

| # | 验收项 | 状态 | 证据 |
| --- | --- | --- | --- |
| 1 | 过渡：武器全额＋防具合计 +20% | ✓ | `armor_elem_capped`；R1 `t532_qiyin_not_capped`（实际 `XTianqiQiyinEquip.make` 两件七印＋一件普通防具：七印 19%／20% 原样，普通 15% 不缩；终态开时七印仍 19%，普通读 final 2%）、`t532_switch_live_cache`（已建缓存的同一角色正常 `refresh_passive`：开 20%→关 47%→开 20%，九线元素裁切 0→0.17→0）；专项 `t532_armor_cap_combined`（3 件四档防具火系合计 47%→20%、武器物理 30% 全额）、`_proportional_no_mutation`、`_keeps_extras`（宝珠 +12% 不缩：32%）、`_skips_artifact`、`_in_ledger_and_switch`（账本 equip 桶 20%，关开关回 47%） |
| 2 | 晶石、神文按孔拆单记 | ✓ | `upgrade_holes`＋`enhanceHoles`（R1）＋`enhanceSplit`；R1 `t532_holes_live_via_apply`（已建缓存的角色用正常 `XGearUpgrade.apply` 镶两颗火晶石、一颗雷神文，账本即时出 3 行：同实例孔 0、1 各 +5%、孔 2 神文 +1%，enhance 合计 0.10）；专项 `t532_crystal_rune_split_per_hole`（两颗晶石孔 0、1 各 +5%、神文孔 2 +1%，enhance 合计 0.10／0.01 不变） |
| 3 | 终态重排防具单件入额 | ✓（数待 Kyo 定，开关默认关） | `gear_elem_amp.json` 540 件 `final`＋`armor_final_rule`；专项 `t532_armor_final_switch`（4535 开 3%／关 20%，卡面「所有伤害+3%」，合计兜底） |
| 4 | 校验＋专项绿 | ✓ | `天启篇数据校验.py` 全部通过；专项见「测试」 |
| 5 | 只改天启篇，西游档零改动 | ✓ | `elem_amp_on()` 含 `on()`（XTianqi.active）守卫；专项 `t532_west_unchanged`（西游档 stat_list 逐个 `is_same` 原对象） |

## 测试

- R1 本机专项（`并行测试.py --full`，提交 f90fc13f5）：`xiyou_tianqi_t532_elem_final` 11/11、`xiyou_tianqi_ledger_p3` 44/44、`xiyou_t530_ledger_core` 59/59、`xiyou_t549_gear_skills` 1970/1970、`xiyou_tianqi_deck_phys_amp` 25/25、`xiyou_tianqi_ledger` 83/83、`xiyou_tianqi_orbs` 56/56、`xiyou_tianqi_nine_off` 19/19、`xiyou_tianqi_phase4` 178/178、`xiyou_tianqi_affix_battle` 89/89、`xiyou_tianqi_equip_roundtrip` 7/7、`xiyou_tianqi_qiyin_effects` 71/71、`xiyou_tianqi_skills` 248/248、`xiyou_tianqi_live_sample` 32/32。
- R0 本机专项：`xiyou_tianqi_t532_elem_final` 8/8、`xiyou_tianqi_ledger_p3` 44/44、`xiyou_t530_ledger_core` 59/59、`xiyou_t549_gear_skills` 1970/1970、`xiyou_tianqi_deck_phys_amp` 25/25、`xiyou_tianqi_ledger` 83/83、`xiyou_tianqi_orbs` 56/56、`xiyou_tianqi_nine_off` 19/19、`xiyou_tianqi_phase4` 178/178、`xiyou_tianqi_affix_battle` 89/89、`xiyou_tianqi_suit_template` 48/48、`xiyou_tianqi_t528` 19/19、`xiyou_tianqi_t524_leaks` 22/22、`xiyou_tianqi_skills` 248/248、`xiyou_tianqi_live_sample` 32/32、`xiyou_virtual_player`（explore）16/16。
- `天启篇数据校验.py`：全部通过；`发行空壳.py check`：0。
- R1 云端选测：待填
- R0 云端选测：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/46063163888 （提交 e65100b56，整轮 839 场景 16 片）。第 1 次：唯一失败 `xiyou_ui_detail_d3`（`list_inertia_off_stops`、`list_tap_keeps_pixel_pos`，列表惯性／触点像素，本卡没碰界面代码；本机同提交跑 93/93 过）；`gh run rerun --failed` 第 2 次全过，结论 success。我猜是云端时序偶发，没深查。

## 数值报告：逐种子分布

### R1 复跑（返修后，提交 f90fc13f5，口径同下、原始记录 `../交付截图/luiluu_t532/r2/`，表 `bench_r2.md`）

| 模板 | 层 | 种子 | 线 | 关（T451 原样）:结果/回合/倒地 | 开（防具合计 ≤20%）:结果/回合/倒地 |
|---|---|---|---|---|---|
| B | 31 | 1 | war | 超时/50/0 | 超时/50/0 |
| B | 31 | 2 | famine | 超时/50/0 | 超时/50/0 |
| B | 31 | 3 | death | 败/14/6 | 败/14/6 |
| B | 33 | 1 | war | 胜/7/0 | 胜/13/0 |
| B | 33 | 2 | famine | 胜/20/0 | 胜/19/0 |
| B | 33 | 3 | death | 败/5/7 | 败/5/7 |
| C | 31 | 1 | war | 胜/14/0 | 胜/14/0 |
| C | 31 | 2 | famine | 胜/17/0 | 胜/17/0 |
| C | 31 | 3 | death | 胜/16/0 | 胜/16/0 |
| C | 33 | 1 | war | 胜/7/1 | 胜/7/1 |
| C | 33 | 2 | famine | 胜/2/0 | 胜/2/0 |
| C | 33 | 3 | death | 胜/8/2 | 胜/8/2 |
| D | 31 | 1 | war | 胜/13/0 | 胜/13/0 |
| D | 31 | 2 | famine | 胜/17/0 | 胜/17/0 |
| D | 31 | 3 | death | 胜/17/5 | 胜/17/5 |
| D | 33 | 1 | war | 胜/3/0 | 胜/3/0 |
| D | 33 | 2 | famine | 胜/2/0 | 胜/2/0 |
| D | 33 | 3 | death | 胜/1/0 | 胜/1/0 |

| 模板 | 层 | 关:胜率 / 回合中位（剔除中止） | 开:胜率 / 回合中位 | 中止场 |
|---|---|---|---|---|
| B | 31 | 0/3 / 50 | 0/3 / 50 | 0 |
| B | 33 | 2/3 / 7 | 2/3 / 13 | 0 |
| C | 31 | 3/3 / 16 | 3/3 / 16 | 0 |
| C | 33 | 3/3 / 7 | 3/3 / 7 | 0 |
| D | 31 | 3/3 / 17 | 3/3 / 17 | 0 |
| D | 33 | 3/3 / 2 | 3/3 / 2 | 0 |

- 关的 18 场与 R0 逐场相同（结果、回合、倒地全等），开关关时行为没变。
- 胜负 18 对零翻转；只有 B 33 层两场赢的回合变了（7→13、20→19），中位 7→13，与小o 隔离对照「只封普通防具」的 13／19／5 逐场一致。其余 C、D 全部与关相同。
- `T532_GEAR` 行（只计普通防具本体）：基准队普通防具最大一系 17%～68%，超 20 的封到 20（`r2/*_on.log`）；R0 的 93%～127% 是把七印借号那份也算进去了。

### R0（首交，七印被误算，作废，留作对照）

**量数口径**（派单）：基准队 D271 五档基准队（T438 脚手架，cc 加薄包装 `t532_elem_bench.gd`，`--t532=on|off` 只切 `ARMOR_ELEM_CAP`，ARMOR_FINAL 关）；来源 D290；模板 B 九死／C 炼狱／D 证道 × 31、33 层 × 种子 1～3 × 每模板 1 支阵容（四线轮覆），成长神器 none，上限 50 回合；统计量：胜率＋回合中位数；剔除：事件中止场（三态判）。**36 场没有中止场，全部计入。**只量一轮，没改口径、没调数。原始记录 `../交付截图/luiluu_t532/r1/`，汇总脚本 `summ.py`，表 `bench.md`，跑法 `run.sh`。

| 模板 | 层 | 种子 | 线 | 关（T451 原样）:结果/回合/倒地 | 开（防具合计 ≤20%）:结果/回合/倒地 |
|---|---|---|---|---|---|
| B | 31 | 1 | war | 超时/50/0 | 超时/50/0 |
| B | 31 | 2 | famine | 超时/50/0 | 超时/50/0 |
| B | 31 | 3 | death | 败/14/6 | 败/14/6 |
| B | 33 | 1 | war | 胜/7/0 | 胜/25/0 |
| B | 33 | 2 | famine | 胜/20/0 | 胜/29/0 |
| B | 33 | 3 | death | 败/5/7 | 败/5/7 |
| C | 31 | 1 | war | 胜/14/0 | 胜/16/0 |
| C | 31 | 2 | famine | 胜/17/0 | 胜/22/0 |
| C | 31 | 3 | death | 胜/16/0 | 胜/16/0 |
| C | 33 | 1 | war | 胜/7/1 | 胜/7/1 |
| C | 33 | 2 | famine | 胜/2/0 | 胜/4/0 |
| C | 33 | 3 | death | 胜/8/2 | 胜/9/2 |
| D | 31 | 1 | war | 胜/13/0 | 胜/14/0 |
| D | 31 | 2 | famine | 胜/17/0 | 胜/20/0 |
| D | 31 | 3 | death | 胜/17/5 | 胜/16/5 |
| D | 33 | 1 | war | 胜/3/0 | 胜/3/0 |
| D | 33 | 2 | famine | 胜/2/0 | 胜/4/0 |
| D | 33 | 3 | death | 胜/1/0 | 胜/2/0 |

| 模板 | 层 | 关:胜率 / 回合中位 | 开:胜率 / 回合中位 | 中止场 |
|---|---|---|---|---|
| B | 31 | 0/3 / 50 | 0/3 / 50 | 0 |
| B | 33 | 2/3 / 7 | 2/3 / 25 | 0 |
| C | 31 | 3/3 / 16 | 3/3 / 16 | 0 |
| C | 33 | 3/3 / 7 | 3/3 / 7 | 0 |
| D | 31 | 3/3 / 17 | 3/3 / 16 | 0 |
| D | 33 | 3/3 / 2 | 3/3 / 3 | 0 |

- （R0）胜负 18 对全部没翻；回合变长主要在 B 33 层（两场赢的 7→25、20→29），其余 ±0～5 回合；D 31 种子 3 开了反而少 1 回合（我猜是行动顺序随机，没核）。
- 每场开打前打的 `T532_GEAR` 行：基准队出战的人防具本体最大一系合计 93%～127%，全部被封到 20%（`r1/*_on.log`）。影响没有这个差看起来大，我猜是原来旧九线合用元素顶（30%）已经切掉大半，没拆账核。
- 没设过线门槛（卡上只给统计量），只报数；是否要 T450 重标时把这一截算进去，归 T450。

## R1 返修（小o 核退回，报告 `xiyou-design-docs/协作交接/核查报告/T532_小o核.md`）

| 编号 | 改法 | 复判 |
| --- | --- | --- |
| P1-1 七印被误算进 20% | `XTianqiGear.plain_armor`：有 `qiyin` 标记或 `tq_reward` 标记的不进合计、不缩、终态不读 final | 专项 `t532_qiyin_not_capped`（真七印生成件混穿）；36 场复跑 B33 中位 13，同小o 隔离对照 |
| P1-2 账本丢孔位 | `passive_buckets` 出 `enhanceHoles` 逐孔行（实例、孔号、材料、值），`enhance`／`enhanceSplit` 合计照旧 | 专项 `t532_holes_live_via_apply` |
| P1-3 正常镶嵌／同进程切开关缓存不失效 | `actor.gd` 缓存签名每件加 `hash([yep, upgrades])` | 专项 `t532_holes_live_via_apply`、`t532_switch_live_cache`（都不手清 `_pm_base`，走正常 `apply`／`refresh_passive`） |

- **另发现（没改，要协调定）**：T451 的 `elem_amp_view` 对七印生成件也按底板号套表：七印件底板效果 T082 已清空（`yep` 删掉），视图又把表里的单件数加回去（专项里两件七印读出火 +19%、+20%，小o 报告里那份 +59% 记在 `tianqi` 桶）。这是 T451 起就有的，不是本卡引入；本卡按小o 口径只让它不进合计。要不要让 `elem_amp_view` 跳过七印／奖励件（七印件元素伤归零），影响七印输出，请协调定，不定照现在。

## 虚拟玩家（DoD）

- explore：16/16 过。
- 短帧 climb（种子 1，`--vp-ff --vp-frames=120000`）：改虚拟玩家前，本分支 2/2 次在第 6 层大厅选线对话兜圈子中止（`../交付截图/luiluu_t532/climb_summary_before_vpfix.md`），同种子 main 基线通到 17 层（`climb_summary_base.md`）。原因是虚拟玩家：选线确认（确定／再想想）在闭关意图下走 `_zhenqi_choice` 回「再想想」；本分支战斗结果变了、到第 5 层通关那一刻闭关意图还留着才撞上（用 `--vp-verbose` 跑时时序变了没撞上）。改后：爬到第 17 层（守层者输满 5 次，同 main 基线）、卡死 0（`stuck` 空）、脚本报错 0、硬违规 0；1 条存疑「生命高于上限 角色 162」（非硬，main 基线同样有，T533 也报过），我猜与本卡无关，没核（`climb_summary.md`）。退出码 1、专项 7/8 是停在 17 层的缘故，数值卡期 M5 前按 DoD 视为正常。

## 本分支提交

- 61cef2da3 T532 元素伤终态：防具本体合计 ≤20%（ARMOR_ELEM_CAP）、终态单件 final（ARMOR_FINAL 默认关）、晶石神文按孔拆单记＋校验＋专项
- aad3c632f T532 发行空壳登记 stat_list；量数包装 t532_elem_bench（--t532=on|off）与 run.sh
- e65100b56 T532 量数 36 场（防具合计上限开／关）＋虚拟玩家选线确认排到闭关前（闭关意图下选「再想想」兜圈子）＋climb 摘要
- f3bdb11f2 T532 交付单
- 1db5b6015 T532 补新增脚本的 .gd.uid
- f90fc13f5 T532 R1 返修（小o 核 P1-1～3）
