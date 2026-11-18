# 交付：luiluu/t191

- 车道／工作者：T191 D200 原版技能卡小数系数全表取整＋D199 艾琳 10727 改 5＋D205 避 4 取消（cc，Opus＋medium，P8）
- 状态：可合并

依据：Kyo 11-18 08:4x「198 A 199 5 200 A …」（D200 选 A、D199 改 5）；Kyo 11-18 08:5x D205「以后数值不用避开 4」；D137②、附则 E；项目经理cc 回复口径（msg_ca36418143a9 的回复：按 A，≥1 就近取整 .5 进位、可取 4，<1 写整数百分比，条件倍率／条件加成不动，做成 tune.D200＋开关）。

## 验收（卡上 5 条＋追加 1 条）

1. ✓ 原卡剩下的小数系数全部取整：`skill_rework.json` 新覆盖层 `tune.D200`（721 条：604 条改系数＋卡面，117 条系数本来是整数、只把卡面 6.0 这类改成 6）；逐条改前改后见附录 `交付/T191_附录/系数取整改前改后.md`（一节 ≥1 变化超 ±20% 的 31 招，二节百分比项超 ±20% 的 20 招，三节全部 604 招，四节卡面逐行）。
2. ✓ 艾琳 10727：`tune.D189` 里 4→5，卡面「物理攻击×5」。
3. ✓ `天启篇数据校验.py` 新加 `coef_integer_rules`：覆盖层全开（D189＋D200）后每行伤害的系数、属性权重只能是整数或小于 1 的整数百分比；无条件 always 不得留着；卡面伤害行不带小数（10337 星影、10437～10439 剑心是代码常数，豁免）。关掉覆盖层时原卡有 500 多处小数，测试里断言拦得住。
4. －本卡没复量 K（统一放 T192）。附录一、二节是给 T192 的参考。
5. ✓ 卡面跟着改（721 条），**有玩家可见文字，待小A 审**（附录四节逐行；手写的 20 来条在 `天启篇系数取整.py` 的 MANUAL／MANUAL_LINES）。
6. ✓（追加）D205 避 4 取消，见下「D205 避 4 取消」。

## 取整办法

- 每个属性项的有效系数 e＝coef×权重×无条件 always 倍率（不带 need_skill 的 always，如「第六期复核段数 ×0.9」「黑龙形态 ×1.2」）。这类无条件倍率并进系数、从 conds 里去掉。
- 攻击类（物攻、魔攻、双防、敏捷、幸运、取高）：e≥1 就近取整，.5 进位，可以是 4（3.6→4、1.5→2、2.5→3、1.2→1）；e<1 写整数百分比（0.45→45%）。离整数不到 0.015 的按整数算（三分之一写成 0.33 带出来的 0.99→1）；权重 0.33／0.67 按准的三分之一、三分之二算。
- 生命上限、魔法上限：整数百分比、.5 进位、最少 1%（同 T175 生命上限×1% 写法）。
- 写法：单项（或取高）时 coef 放取整后的数、权重 1（生命魔法权重 0.01、coef 是百分数）；多项时 coef 1、各权重写取整后的数。`yomi_jingliu.gd`、`liuying.gd` 读 coef 当每段系数，它们那几招都是单项，写法照旧对得上。
- **卡面和代码常数对不上的一处（没改，不在本单文件）**：`liuying.gd` 天启篇天火轰击 10622 按代码常数「合计 3.6（星河 +0.5）÷段数」出伤，不读卡上系数；卡上 3.6→4 后，卡面写 ×4、实际仍按 3.6。引爆 9.0、完全燃烧 6.0÷9.0 也是代码常数（本来就是整数或和卡对得上）。建议 T192 或战斗车道把 3.6 改成读卡上系数。
- 不动：带 need_skill 的 always（学会某招后 ×1/3 这类拿段数换的）、各种条件加成（+20% 等）、追加几率、半伤 scale 0.5、治疗比例。
- 已在 `tune.D189` 里的技能按覆盖后的值算，已是整数的不进 D200。
- 生成脚本：`03_转换工具/天启篇系数取整.py`（`--write` 写覆盖层，可重跑、每次整段重写 tune.D200；`--report` 出附录；`--left` 列换不干净的卡面）。

## 结果（取整后变化）

- ≥1 取整变化超 ±20% 的 31 招：大多是 1.5→2（+33%，二十多招，如 171 游云／释魂刀、169 霆影横渡、170 断月剑、154、162、164）；往下的有 7030（1.44→1，−31%）、7007（1.35→1，−26%）、2358（1.33→1，−25%）、4816（1.3→1，−23%）、10192（1.29→1，−22%）。
- 按属性项数：1.8→2 有 101 项（+11%），3.6→4 有 79 项（+11%），1.2→1 有 70 项（−17%），1.5→2 有 26 项（+33%），2.5→3 有 17 项（+20%），7.2→7 有 17 项（−3%），1.25→1 有 15 项（−20%）。
- 百分比项：生命上限 0.28%～0.78% 这类最少取 1%，个别项 +92%～+256%（4374／4380 王八拳、3896 真*爷拳、1114 流沙乱舞等），但这几项本来就是小头（生命上限 1% 按标准线折攻击约 ×0.25），整招影响小；附录二节有全表。
- 回验：`base_line.json` 的 5670 钟离 地心·岩脊 取整后回验偏差 +10.9%（生命上限 2.5%→3%），在 `backtest_notes` 补了一条理由；校验里「覆盖前后有一边用得上就不算多余理由」（原来覆盖前不超就报多余）。

## D205 避 4 取消

- `天启篇数据校验.py`：`nice_violations`、`_fours`、`NICE_EXEMPT_ALLOWED`、`SKILL_EXEMPT_EXTRA`、`TUNE_NICE_EXEMPT` 删掉；各表（balance、horsemen、war_line 等四线、summit、seg_alien、gear_table、rewards、七印四张、重铸等六张、elements_table、skill_rework、期四 base_line／gear_base／damage_ledger.phase4 等）的避 4 检查全删；词条文字「填好的文字不含数字 4」「文字表本身不含数字 4」两条也删（同一条规矩的文字版）。文件头说明同步改掉。
- `测试天启篇数据校验.py`：五条「带 4 报错」用例合成一条 `test_four_allowed_d205`（带 4 照常通过）；第三批反例表里六条避 4 反例挪进「带 4 照常通过」那组；`test_exempt_not_borrowed` 改 `test_no_four_check_d205`；T175 的 `TuneInteger`（含 10727 豁免）换成 `CoefInteger` 七条。
- `天启篇单段上限拆段.py`：只有文件头一句「系数避开 4」，没有避 4 逻辑；改成「当时系数避开 4，D205 起不再要求」（脚本是 T081 一次性的，里面的 3.6、8.1 照旧）。
- `mv_oracle/hit_warehouse_probe.cjs`：查过没有避 4 逻辑（里面的 4 是 xparam 下标「魔法闪避 4」），没改。
- **各数据表里的 `nice_number_exempt` 字段没删**：现在没代码读它，是死字段；它分散在二十来张表里，其中 `damage_ledger.json` 归 T187 不能碰，`gear_base.json` 的 `level_override` 那条也在这里。只删一部分会更乱，建议另开一张清理卡一起删（或等 T187 合完后顺手）。

## 测试

- `天启篇数据校验.py` 全部通过（退出码 0）；`测试天启篇数据校验.py` 60 个过。
- `语法检查.py`：1032 个 .gd 0 问题；`工具回归.py` 全过（124 秒）。
- Godot 场景（`并行测试.py`，--headless 静音），共 61 个全过：
  - T175 那 25 个（t164_gem_shots、xiyou_tianqi_gear_params、xiyou_tianqi_gem_power、xiyou_tianqi_drop、xiyou_tianqi_nine_off、xiyou_tianqi_gear2、xiyou_tianqi_qiyin_gear、xiyou_tianqi_ring_style、xiyou_tianqi_qiyin_equip、xiyou_tianqi_skills 238/238、xiyou_tianqi_rewards、xiyou_tianqi_gear、xiyou_tianqi_phase4 94/94、xiyou_tianqi_phase4_modules、xiyou_json_cache、xiyou_text_batch23、xiyou_tianqi_balance、xiyou_tianqi_ledger、xiyou_tianqi_affix_text、xiyou_fabao_rework、xiyou_magic_level、xiyou_magic_weapon、xiyou_magic_weapon_level、xiyou_determinism、xiyou_tianqi_ledger_p3）；
  - 读技能卡的另 36 个（text_batch23_shots、xiyou_all_scope_repeat、xiyou_boss_strong_tianqi、xiyou_gojo 84/84、xiyou_gojo_trials、xiyou_hall_intro、xiyou_tianqi_again_use／brand／e2e／elements／no_diff_passive／no_x6／numbers／opening／party／real_swap／save／sect_b／sect_ren／skill_debt／swap_view／trim／trumpet／weak_clear／zhengdao_party、xiyou_cat_help、xiyou_cat_trial、xiyou_liuying／liuying2／liuying3／liuying_help、xiyou_xuan_auto／battle／bind／chart、xiyou_yomi_battle）。
  - 改了期望值的：`xiyou_tianqi_skills`（101 3.6→4、102 2.5→3、3632 ×4、破魂对万剑合计 1.5 倍→16 比 12、露丝取高 ×4）、`xiyou_tianqi_phase4`（cap.within ×4、寒锋权重 3.6→4、10727 ×5，新加 `tune_d200.switch`：开着 101＝4、160＝45% 且无条件倍率并掉，关掉 reload 回 3.6／0.5）、`xiyou_gojo`（赫 red 卡上 3.6→4）。
- 没跑：K 复量（T192）；全量 `检查.sh`（车道不跑）；实机看卡面。

- 附录放在 `交付/T191_附录/系数取整改前改后.md`（.md，交付自检提示它像另一份交付单；合并时 `--also` 带上或挪进归档）。
- 取整后 4748 破魂 2 段 ×8 对 万剑归一 3 段 ×4，合计比从 1.5 倍变成 1.33 倍（T081 拆段时定的 1.5 倍）；五条悟紫 1.8 是 `gojo.gd` 代码常数，不在卡上，没动。

## 要 Kyo 定

- 无（口径项目经理cc 已回）。

## 异议

- 无。附带一条提醒：取整让一批 1.5 的招 +33%、一批 1.2 的招 −17%，档内相对强弱会小幅变；T192 复量时可以看附录一节，偏得多的再按「换别的整数项」细调。

## 变更记录草稿

## 2026-11-18 【cc·T191·未经审查】原版技能卡小数系数全表取整（D200 A）、艾琳 10727 改 5（D199）、避 4 检查取消（D205）（dev.待定）

- 依据：Kyo 11-18 08:4x D200 A、D199 5；08:5x D205；附则 E。
- `skill_rework.json` 新覆盖层 `tune.D200`（`XTianqiBase.TUNE_D200`，叠在 D189 之后，`XTianqiSkills.data()` 按 D189→D200 顺序合并）：721 条技能系数取整（≥1 就近取整 .5 进位，<1 和生命魔法写整数百分比，无条件 always 并进系数），卡面跟着换；生成脚本 `03_转换工具/天启篇系数取整.py`。
- `tune.D189` 10727 系数 4→5。
- `天启篇数据校验.py`：加「系数不得有小数」（覆盖层全开后的系数、权重、无条件倍率、卡面伤害行）；去掉全部避 4 检查与豁免；回验多余理由按覆盖前后都用不上才报；`base_line.json` 补 5670 回验理由。
- 玩家可见：天启篇几乎全部伤害技能的卡面数字变整数或整数百分比；伤害随取整小幅变（多数 ±17% 以内，31 招超 ±20%）。期四总开关默认关，现在不影响玩家。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/tianqi_data/skill_rework.json` 的 `tune.D200`；`XTianqiBase.TUNE_D200` | （天启篇卡）原卡系数带小数（3.6、0.72、权重 0.5 等） | 全表取整：≥1 就近取整、<1 和生命魔法写整数百分比，无条件倍率并进系数，卡面跟着换 | Kyo D200 A、附则 E「系数不要小数」 | `XTianqiBase.TUNE_D200 = false` 后 `XTianqiSkills.reload()` | cc | 保留 |

## 交接板

- 下一步：T192 复量 K（附录一、二节是取整后变化大的招）；小A 文字审卡面（附录四节）。
- 需要用户决定：无。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：取整脚本可重跑，以后原卡再改（比如设计稿回填）直接重跑 `--write` 就能重算 D200。
- 建议：数据表里死掉的 `nice_number_exempt` 字段另开一张清理卡统一删（见上）。

## 本分支提交

- c8a0a6c82 WIP：D200 覆盖层、10727→5、校验系数整数、D205 去避 4
- 5251af9da／附录挪目录：交付单＋附录
- 3841aee60：期四、技能专项期望值、tune_d200.switch
- （xiyou_gojo 期望值、交付单测试结果：本单最后一个提交）
