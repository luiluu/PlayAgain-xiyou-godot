# 交付：luiluu/t246

- 车道／工作者：T246 期四 abs_rescale 剩 5 类定口径接线＋药品 pct 整数＋T245 P3（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-19 【cc·T246·未经审查】天启篇期四：绝对值清单剩下五类定口径，公式型持续伤害的写死底数改按持有者生命上限；药品、持续伤害百分比取整（dev.待定）

- `abs_rescale.json` 里 T243 盘点剩下的 5 类 47 行（公式型 state_dot 14、state_shield 7、note_shieldeffect 3、note_regen_formula 10、note_dbhplsteal 13）全部从文字说明改成结构化，`unscanned` 清空。口径：
  - **公式型持续伤害 14 行**：公式最前面写死底数的 3 行（43 猛击之伤「1025 + a.atk×7 − b.def×2」、643 奇怪的治疗「1025 + a.mat×2」、644 奇怪的复活「1025 + a.mat×5」）跟常数持续伤害（T081）同一口径：底数 1025 换成「持有者生命上限 × 15%」（1025 ÷ 弱者 81 级生命 6910 × 100 取整），公式其余部分照旧。另 11 行没有写死底数（a.mat×N 回复 7 行、b.mhp×3%、a.mhp＋…、b.hp×幸运差、2038 取技能伤害写进的 damagedot），本来就随属性／生命涨，`mode: raw` 照原式。
  - **护盾 10 行**（state_shield 7、note_shieldeffect 3）：`<ShieldEffect:N>` 原版是「获得的护盾量 ×(1＋N/100)」的倍率（`XBattler.shield_effect_bonus`），不是绝对量，`mode: raw`。表里原来的「卡标准 20%」是盘点时的猜测，跟标签实际含义不符。
  - **吸血 13 行**（note_dbhplsteal）：`<DBHPLSteal: N%>` 是「吸血量 × N/100」的倍率（`XLifeSteal`），本来就是百分比，`mode: raw`。
  - **回复公式 10 行**（note_regen_formula）：跟 state_dot 是同一个 `<Regen Formula>` 标签重复列出（常数的 57／160／168 已由 state_dot 那行按生命上限换算，a.mat×N 随属性涨），`mode: raw`，reason 里写了对应的 state_dot 行。
- 接线：`core/ext_dot.gd` `_one` 公式算完后调 `XTianqiBase.dot_value`（常数行照旧整条换算；带 `base` 的行只换底数）。按程序 `sha256` 认公式，天启篇改写过、对不上的照原式并警告一次。开关 `XTianqiBase.ABS_DOT_FORMULA`（默认开，false＝公式型照原式；常数持续伤害不受它管）。只在期四总开关开着、天启篇存档时生效，西游档原样。
- `abs_value` 认 `mode: raw`（照原数）和带 `base` 的行（不整条换）；T246 起 raw 行也是字典，不挡会被当成 pct 0 清零。
- 附则 E：药品 `item_fixed_heal` 47 行、常数持续伤害 27 行的 pct 四舍五入成整数（7.2→7、4.3→4…，不足 1 记 1），`over100` 也取整。
- 生成：`03_转换工具/天启篇期四填表生成.py --写其余换算`（只换这几类，别的行不动；`build_abs` 整表生成也改成同一口径）。数据校验 `天启篇数据校验.py` 同步：这几类 new 必须结构化、pct 整数 1～100、公式型要有 base 和 64 位 sha256、护盾／吸血／重复回复公式只能 raw、`unscanned` 可以空。
- 顺手（T245 复核 P3）：`core/guardian_rework.gd` `rescale_params` 命中七印重标的敌人才读 `XTianqiQiyin.data()`；数据校验 `guardian_params.json` 的行写 `mhp` 报错（代码只换 1～7 项，血量走 HP_BASE）；七首之龙专项补魔防 `param(5)` 断言。
- 专项：`tests/xiyou_tianqi_phase4` 158/158（新增 643 开／关／ABS_DOT_FORMULA 关、95 raw、55 raw 不清零；药品、33 号持续伤害改认整数 pct），`tests/xiyou_tianqi_guardian_params` 41/41，`tests/xiyou_dot` 2259/2259，`tests/xiyou_tianqi_abs_skill` 38/38；`测试天启篇数据校验.py` 73 条（新增 6 条反例）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/tianqi_base.gd` `XTianqiBase.ABS_DOT_FORMULA`（`abs_rescale.json` state_dot 带 base 的行；接在 `core/ext_dot.gd` `_one`） | （天启篇期四）状态持续伤害公式里写死的底数 1025 照原版绝对值 | 换成持有者生命上限的整数百分比 15%，公式其余部分不动 | 跟常数持续伤害（T081）同一口径，原版量级的绝对值跟期四本体对不上 | `XTianqiBase.ABS_DOT_FORMULA = false` | cc（T246） | 保留 |

## 交接板

- 下一步：abs_rescale.json 五类口径已定，清单里没有还是文字说明的行了；groups 里 `enemy_skill_fixed_base`（敌人技能伤害底数）、`abs_threshold_in_notes`（属性门槛）两组仍是待办清单，没接，不在本单范围。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 影响（转 Kyo 知会）

- 药品、常数持续伤害取整：每行变化不超过对象上限的 0.5%（如治疗药水(小) 7.2%→7%、中毒 4.3%→4%、魔力药水(中) 14.8%→15%）。
- 643 奇怪的治疗、644 奇怪的复活（技能 3640 奇怪治疗术、3924 奇怪的复活术挂给我方的整人状态，每回合扣血）：底数从固定 1025 改成持有者生命上限 15%。期四我方生命上限约 3.7 万时一回合多扣约 4500；对弱者 81 级本体（6910）几乎不变。43 猛击之伤同理。
- 护盾、吸血、回复公式这几类没有改动玩法，只是表里写清楚为什么不换。

## 发现

1. 验收逐条：
   1. 5 类口径：见变更记录草稿。真正带绝对值的只有 3 行公式型持续伤害；其余 44 行原版本来就是倍率／随属性涨／重复行。口径跟 T081、T243 一致，没有大幅改玩法的，没 ask。
   2. 接线＋开关：`ABS_DOT_FORMULA` 可回退，`on()` 把关（期四＋天启篇存档）。专项 `dot643_switch_off` 覆盖回退。
   3. item_fixed_heal pct 整数：47 行全部整数（常数 state_dot 27 行一起取整，附则 E）。
   4. 数据校验同步、`天启篇数据校验：全部通过`；故意改坏（pct 7.2、sha256 乱写、护盾写 pct、文字 new、guardian 写 mhp）都能报出来（进了回归）。西游档：`dot_value`、`abs_value` 第一句要 `on()`，专项 `e2e_off.*` 照原数；云端选测 38 个场景全过（提交 9dc366dcf）。
   5. T245 P3 三条：见变更记录草稿。
2. 55 治愈之歌在期四开着时被天启篇技能重构改写（状态没有 dot），专项改成直接问 `dot_value` 验 raw 不清零。
3. `发行空壳.py check`：76 个脚本、700 个函数都有（`dot_value` 照规则 2 生成）。

## 本分支提交

- 9dc366dcf 接线、表、数据校验、T245 P3、专项（云端选测 38 场景过）
- （本提交）交付单
