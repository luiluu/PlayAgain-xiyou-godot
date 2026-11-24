# 交付：luiluu/t451

- 车道／工作者：T451 DECK 物理增幅恢复后逐把重调武器与普通防具全系增幅／小A（Gemini 4 Neon＋high，职级 P8；`ctx_efce68dead0f` 实现＋`ctx_792d62d29fde` 原地合 main 收口）
- 状态：可合并

## 变更记录草稿

## 2026-11-24 【小A·T451·未经审查】天启篇通用武器与普通防具全系增幅分档重调、专武与状态残留 yep 清理及 passiveELUP 扩展读取（Kyo 事项 50，dev.待定）

- 依据：Kyo 2026-11-24 事项 48／50（D280 补）与 T449 换家核查（P2-1、P3-1 及 60 件专武／防具残留 `elementAmplify` 线索）。
- 清理专武／状态残留原版增幅回设计稿（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_skills.gd`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/skill_rework.json`）：
  - 新增 `XTianqiSkills.parse_yep`／`_merge_yep` 与回退开关 `XTianqiSkills.YEP_RECOMPUTE := true`（西游档不生效），`gear_view` 与同源 `rec_state` 在改写 `note` 后重算 `yep` 并通过差值合并完整保留宝珠／强化等实例增量；清除了 60 件已写 `note_remove: Element Amplify` 专武／防具（含五河琴里 `weapon:87` +1200%、贝吉特 `weapon:91` +300%、桐人／亚斯娜／诛仙等天外天系列）与 36 个改写状态（如 `state:2719` +500%、`state:2768` +200%→+10%、`state:710` +100%→+10%）的原版残留增幅。
  - 在 `skill_rework.json` 补齐 3 件漏写 `note_remove: ["Element Amplify \\d+"]` 的装备（`armor:4519 戒指朱`、`armor:4520/4521 命运骰子`），并补录启用角色 `85 爱莉` 的专武 `weapon:2222 真我之钥·无暇回归`（去原版全 15 系 +1000%）。
- 通用武器与保留栏位普通防具全系增幅按等级分档重调（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/gear_elem_amp.json`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_gear.gd`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/help_card.gd`）：
  - 新增 `gear_elem_amp.json` 与视图 `XTianqiGear.elem_amp_view`（回退开关 `XTianqiGear.GEAR_ELEM_RESCALE := true`，西游档恒不生效），在 `stat_list` 与说明卡 `XHelpCard._content`／`detail_rows` 接入；重算 `yep.elementAmplify` 时按相对原表差值保留宝珠／强化增量，并同步重写备注 `<Element Amplify>` 与 `<pos=APs>` 卡面文案。
  - 范围全覆盖（不含双引号附魔模板与无名模板，非改写实体装备 0 遗漏）：326 把通用武器（含 179 把物理武器及非物理武器，五档上限 10／15／25／35／50%，取值 5%～50% 整数避 4）与 540 件保留栏位普通防具（含 205 件物理防具及非物理防具，五档上限 7／10／13／18／20%，常规 5%～20% 整数避 4，仅原版即 3% 的 `armor:327` 与原版 4% 避 4 降为 3% 的 `armor:501` 为 3%）。
  - `03_再刷重制_Godot/03_转换工具/天启篇数据校验.py` 新增 `gear_elem_amp` 规则校验（校验版本、档位上限、全避 4 正整数、`subs` 格式及与 `skill_rework.gear`／`gear_table.element_fabaos` 零重叠）。
- 修通 `passiveELUP` 扩展读取（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/actor.gd`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_skills.gd`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_ledger.gd`）：
  - 新增回退开关 `XTianqiSkills.PASSIVE_ELUP_EXT := true`，建立白名单 `passive_elup_sources()`，仅读取 `skill_rework.json` 中 `note_add` 显式写入 `passiveELUP` 的 6 件装备（`armor:4995/4519`、`weapon:2023/1698～1700`）与 2 个状态（`state:173/2733`），接入 `XActor._carry_fp`、`_passive_values_now` 与 `XTianqiLedger.passive_buckets`（装备入 `tianqi` 桶、状态入 `state` 桶），不激活原版未改写装备／状态（如 `armor:124`、`state:1149`）的废标签。
- 验证与归档：扩展 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_deck_phys_amp.gd` 至 25 项（覆盖 T449 核 P3-1 两条路径、残留 yep 清理、6 装备＋2 状态 `passiveELUP`、分档重调与卡面同步、宝珠增量保留、三开关回退与西游档不变）；阶段一全清单归档于 [T451_武器物理增幅全清单.md](../归档/交付截图/luiluu_t451/T451_武器物理增幅全清单.md)，单人木桩复测归档于 [T451_修后单人木桩复测.json](../归档/交付截图/luiluu_t451/T451_修后单人木桩复测.json)。五档标尺复测经协调批复移交 T450 合后重跑。
- 玩家可见：天启篇里专武与改写状态不再残留原版超高元素／物理增幅，全部回到天启篇设计稿；326 把通用武器的物理及各系元素增幅按等级分档调整为 5%～50%，540 件保留栏位普通防具调整为 3%～20%（常规 5%～20%），说明卡上的特效百分比同步更新；斧头の屌丝、戒指朱、星穹麒麟弩、心澜三阶及状态「法天象地」「三教极元（人）」的增伤词条正式生效。西游档完全不变。卡面同步替换文本待 cc Sonnet 审（D276）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·T451专武状态yep重算 | `modes/xiyou/core/tianqi_skills.gd` `XTianqiSkills.YEP_RECOMPUTE`（`parse_yep`、`_merge_yep`、`gear_view`、`rec_state`）＋`tianqi_data/skill_rework.json`（`armor:4519/4520/4521`、`weapon:2222`） | `gear_view` 与 `rec_state` 只改写 `note`/`meta`/`traits` 不重算 `yep`，60 件已删 `Element Amplify` 的专武／防具与 36 个改写状态残留原版 +30%～+1200% 增幅 | 天启篇改写视图按改写后 `note` 重算 `yep`，通过相对原表差值保留宝珠／强化增量，并补齐 3 件漏删与 `weapon:2222` 录入；西游档不变 | Kyo 11-24 事项 50① 与 T449 核查线索：残留原版增幅清掉回设计稿 | `XTianqiSkills.YEP_RECOMPUTE = false`＋`XTianqiSkills.reload_table()` | 小A（T451） | 保留 |
| O-待定·T451装备passiveELUP扩展 | `modes/xiyou/core/tianqi_skills.gd` `XTianqiSkills.PASSIVE_ELUP_EXT`（`passive_elup_sources`、`is_passive_elup_state`、`is_passive_elup_obj`、`passive_elup_extra`）＋`core/actor.gd`＋`core/tianqi_ledger.gd` | `XActor._passive_values_now` 只扫 `skills()`，导致 `skill_rework.json` 中 6 装备＋2 状态的 `note_add passiveELUP` 不生效 | 天启篇白名单读取上述 6 装备＋2 状态的 `passiveELUP` 并接入缓存指纹与账本分桶（装备入 `tianqi` 桶、状态入 `state` 桶），不激活原版废标签；西游档不变 | T449 换家核查 P2-1 | `XTianqiSkills.PASSIVE_ELUP_EXT = false` | 小A（T451） | 保留 |
| O-待定·T451通用装备全系增幅重调 | `modes/xiyou/core/tianqi_gear.gd` `XTianqiGear.GEAR_ELEM_RESCALE`（`elem_amp_view`、`stat_list`）＋`tianqi_data/gear_elem_amp.json`＋`ui/help_card.gd` | 天启篇掉落掷词条后整件装备进 `tianqi` 桶绕过九线封顶，通用武器物理／元素增幅高达 +100%～+1300%、普通防具高达 +100%～+1000% | 天启篇将 326 把通用武器按五档压至 5%～50%、540 件保留栏位普通防具按档压至 3%～20%（常规 5%～20%），物理与非物理元素一并重调、全整数避 4，保留宝珠增量并同步说明卡显示；西游档不变 | Kyo 11-24 事项 50②③④（D280 补） | `XTianqiGear.GEAR_ELEM_RESCALE = false`＋`XTianqiGear.clear_effective_cache()` | 小A（T451） | 保留 |

## 交接板

- 下一步：转换家核查（cc Opus＋medium 核甲档代码，cc Sonnet＋medium 审卡面替换文字，D276）；合入 `main` 后由 T450 用 `t438_d271_benchmark` 重跑五档标尺并回校 20～36 层血量。
- 用户试玩说明：天启篇中五河琴里、贝吉特、桐人等专武角色与通用武器／普通防具的元素与物理增幅回到天启篇设计区间，装备说明卡上的百分比与实际生效数值一致；西游档不受影响。
- 需要用户决定：无（Kyo 2026-11-24 事项 50 已全部拍板）。

## 进度账

- 天启篇数值体系（T451 武器与防具全系增幅重调）：进行中 → 完成（代码、数据表、校验、专项 25/25、单人木桩复测、云端选测 492/492 全过；五档标尺复测经协调批复移交 T450 合后重跑）。

## 验收项逐条证据（卡上 8 条）

| # | 验收项 | 状态 | 证据与落点 |
| --- | --- | --- | --- |
| 1 | 先出清单：每把武器修前修后木桩倍数、所属角色，按涨幅排序 | ✓ | 提交 `35bd002af` 入仓 `00_项目管理/归档/交付截图/luiluu_t451/T451_武器物理增幅全清单.md`（226 把物理武器按天启掉落态降序＋60 件残留专武／防具＋12 名专武角色实测＋6 装备 2 状态清单） |
| 2 | 定重调口径并给协调／Kyo 过 | ✓ | 阶段一清单呈报后，Kyo 2026-11-24 事项 50 拍板四条口径 |
| 3 | 按口径逐把改，系数整数避 4，卡面说明同步 | ✓ | `modes/xiyou/tianqi_data/gear_elem_amp.json`（326 把通用武器 5～50%＋540 件保留栏位防具 3～20%，全整数避 4，实体装备 0 遗漏，823 条 `subs` 100% 命中且无残留旧 `%`）、`tianqi_gear.gd`、`help_card.gd`、`天启篇数据校验.py` 通过，专项 `t451_gear_elem_rescale_values`／`t451_help_card_text_synced` 通过 |
| 4 | 五档标尺复测 | － | 经协调 2026-11-24 批复选项 A：单进程跑 A/B/C/D×3 种子约 30～40 分钟超出附则 A 限制，本单按已有单人木桩复测＋云端选测收口，五档标尺复测移交 T450 合后重跑 |
| 5 | T449 核 P2-1：6 装备＋2 状态 `passiveELUP` 修通读取 | ✓ | `actor.gd`（`_carry_fp`＋`_passive_values_now`）、`tianqi_skills.gd`（`PASSIVE_ELUP_EXT` 白名单）、`tianqi_ledger.gd`（分桶），专项 `t451_p2_1_passive_elup_ext` 与木桩 5 项复测全过，且未激活原版废标签 |
| 6 | T449 核线索：`gear_view` 重算 `yep` 清 60 件残留 | ✓ | `tianqi_skills.gd`（`YEP_RECOMPUTE`、`parse_yep`、`_merge_yep`，同步修复同源 `rec_state` 36 状态）＋`skill_rework.json`（补 `armor:4519/4520/4521`、`weapon:2222`），专项 4 条（残留清零、宝珠增量保留、`rec_state` 重算、回退开关）全过 |
| 7 | T449 核 P3-1：补专项「属性转换＋原物理招」「目标挂物理抗/免」 | ✓ | `tests/xiyou_tianqi_deck_phys_amp.gd` 新增 `p3_conv_plus_orig_phys` 与 `p3_target_phys_immune_ignored_on_deck`，全场景 25/25 通过 |
| 8 | Kyo 11-24 事项 50（①清残留 ②194 武器分档 5～50% ③234 防具压至 5～20% ④非物理元素一起压） | ✓ | ①见验收 6；②326 把通用武器全覆盖（含全部 179 把非附魔模板物理武器＋非物理武器，分五档 5～50%）；③540 件保留栏位普通防具全覆盖（含全部 205 件非附魔模板物理防具＋非物理防具，分五档 ≤20%）；④火／冰／雷／圣／暗／治疗等全系元素增幅同套分档一并压低 |

## 单人木桩复测数据摘要

原始数据：`00_项目管理/归档/交付截图/luiluu_t451/T451_修后单人木桩复测.json`（炼狱档 31 层守层者木桩，固定底数物理／副属性招，对照 T449 前 `pre_t449`、T449 后 `post_t449`、本单修后 `post_t451`）。

### 1. 13 名自带专武角色（物理招 / 副属性招）

| 角色 | 物理招（前 → T449 → T451） | 副属性招（前 → T449 → T451） | 结论 |
| --- | --- | --- | --- |
| 159 五河琴里 | 20657 → 268535 → **20657** | 火：268535 → 268535 → **20657** | 清专武残留物／火 +1200%，双系归位 |
| 164 贝吉特 | 15419 → 66303 → **20045** | 无：15419 → 15419 → **15419** | 清专武 +300%，仅留自身物理被动 +30%（×1.30） |
| 155 病娇 | 61883 → 15471 → **15471** | 无：61883 → 61883 → **15471** | 清专武无属性 +300%，双系归位 |
| 150 桐人 | 15367 → 169039 → **15367** | 无：15367 → 15367 → **15367** | 清专武物理 +1000%，归位 |
| 151 亚斯娜 | 18220 → 200425 → **18220** | 无：18220 → 18220 → **18220** | 清专武物理 +1000%，归位 |
| 162 诛仙 | 27201 → 299215 → **27201** | 无：27201 → 27201 → **27201** | 清专武物理 +1000%，归位 |
| 163 拳一 | 27074 → 54148 → **27074** | 无：27074 → 27074 → **27074** | 清专武物理 +100%，归位 |
| 148 黑崎一护 | 10997 → 14296 → **10997** | 暗：16496 → 16496 → **16496** | 清专武残留，归位 |
| 85 爱莉 | 15261 → 167867 → **15261** | 冰：251800 → 251800 → **22891** | 补录 `weapon:2222`，清全 15 系 +1000% |
| 153 惠惠 | 16136 → 18556 → **18556** | 火：179911 → 179911 → **18556** | 留自身被动 +15%，清专武火 +1000% |
| 154 夏娜 | 16136 → 16136 → **16136** | 火：177491 → 177491 → **16136** | 清专武火 +1000%，归位 |
| 156 嫦娥 | 10830 → 10830 → **10830** | 圣：79813 → 79813 → **7256** | 清专武圣 +1000%，归位 |
| 158 炮姐 | 16136 → 16136 → **16136** | 雷：179911 → 179911 → **18556** | 清专武雷 +1000%，留自身雷被动 +15% |

### 2. 代表通用武器与普通防具（18 件，含非物理样例）

| 装备 | 元素 | T449 前 → T449 后 → T451 修后 | 修后相对修前倍数（对应分档新值） |
| --- | --- | --- | --- |
| `weapon:2011` 天道制裁·混沌至高 | 物理 | 323062 → 4522873 → **484593** | ×1.50（+1300% → +50%，5 档） |
| `weapon:2025` 天顶剑·极 | 物理 | 161572 → 969434 → **219738** | ×1.36（+500% → +36%，5 档） |
| `weapon:2010` 紫炎莲华 | 物理 | 70848 → 495935 → **95645** | ×1.35（+600% → +35%，4 档） |
| `weapon:1909` “至臻”收割者 | 物理 | 18503 → 101764 → **23128** | ×1.25（+450% → +25%，3 档） |
| `weapon:1908` “至臻”秩序之怒 | 物理 | 18503 → 87887 → **23128** | ×1.25（+375% → +25%，3 档） |
| `weapon:1826` 大鹏风起 | 物理 | 34561 → 138246 → **44930** | ×1.30（+300% → +30%，4 档） |
| `weapon:1661` 碧血干戚 | 物理 | 34335 → 123605 → **44635** | ×1.30（+260% → +30%，4 档） |
| `weapon:1408` 秩序之怒 | 物理 | 17973 → 62907 → **21928** | ×1.22（+250% → +22%，3 档） |
| `weapon:1652` 不冠剑 | 物理 | 26006 → 49411 → **31207** | ×1.20（+90% → +20%，4 档） |
| `weapon:1837` 雷鸣无影 | 雷电 | 175609 → 175609 → **57073** | 非物理同压（原超高雷增幅压至分档） |
| `weapon:2003` 腾云斡旋势 | 雷电 | 17712 → 17712 → **17712** | 对照组无雷增幅，不变 |
| `armor:4541` 花与鸟之矢 | 物理 | 15271 → 167985 → **18326** | ×1.20（+1000% → +20%，5 档） |
| `armor:4535` 苍琉幻生灭 | 物理 | 30972 → 108403 → **37167** | ×1.20（+250% → +20%，5 档） |
| `armor:4536` 神魔战纹 | 物理 | 51518 → 180312 → **60791** | ×1.18（+250% → +18%，4 档） |
| `armor:4282` 如来的袈裟 | 物理 | 12535 → 32592 → **14666** | ×1.17（+160% → +17%，4 档） |
| `armor:4313` 尘影盾 | 物理 | 20799 → 54077 → **24334** | ×1.17（+160% → +17%，4 档） |
| `armor:4115` 苍苍白骨 | 物理 | 21710 → 41249 → **25184** | ×1.16（+90% → +16%，4 档） |
| `armor:4075` 三环剑 | 物理 | 20040 → 36072 → **23246** | ×1.16（+80% → +16%，4 档） |

### 3. P2-1 `passiveELUP` 装备与状态实测（5 项）

| 来源 | 元素 | T449 前 → T449 后 → T451 修后 | 结论 |
| --- | --- | --- | --- |
| `armor:4995` 斧头の屌丝 | 物理 | 8683 → 8683 → **10420** | ×1.20（`<passiveELUP01:20%>` 生效） |
| `armor:4519` 戒指朱 | 火焰 | 11288 → 11288 → **9552** | 清原版残留 +50% 并生效 `<passiveELUP02:10%>` |
| `weapon:2023` 星穹麒麟弩 | 物理 | 17721 → 17721 → **21265** | ×1.20（`<passiveELUP01:20%>` 生效） |
| `state:173` 法天象地 | 物理 | 7661 → 7661 → **8427** | ×1.10（`<passiveELUP01:10%>` 生效） |
| `state:2733` 三教极元（人） | 火焰 | 7661 → 7661 → **8427** | ×1.10（`<passiveELUP02:10%>` 生效） |

## 玩家可见文字改动清单（待 cc Sonnet 审，D276）

1. `03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/gear_elem_amp.json`（`subs` 字段，经 `XTianqiGear.elem_amp_view`＋`XHelpCard` 展示）：
   - 仅对装备原版 `<pos=APs>` 特效说明行做**百分比数字替换**，不改写剧情／叙事措辞；共覆盖 **316 把通用武器（322 条替换）**＋**496 件保留栏位普通防具（501 条替换）**，合计 **812 件装备、823 处数值文案**（其余 10 把武器／44 件防具原版 `<pos=APs>` 本身不含增幅百分比，只由说明卡头部的元素增伤汇总行自动按新 `yep` 显示）。
   - 代表性前后对照：
     - `weapon:1826 大鹏风起`：`特效:物伤+300%` → `特效:物伤+30%`
     - `armor:4535 苍琉幻生灭`：`特效:所有伤害+250%，…` → `特效:所有伤害+20%，…`
     - `weapon:88 天外天·护摩之杖`：`特效:血梅香(物理伤害+1000%,火焰伤害+1500%)` → `特效:血梅香(物理伤害+7%,火焰伤害+10%)`
     - `weapon:397 元素法杖`：`特效:元素祝福(所有元素伤害+10%)` → `特效:元素祝福(所有元素伤害+5%)`
     - `armor:501 主教之冠`：`特效:愈合祝福(治疗效果+4%)` → `特效:愈合祝福(治疗效果+3%)`；`特效:神光祝福(神圣伤害+12%)` → `特效:神光祝福(神圣伤害+6%)`
2. `03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/skill_rework.json`：
   - 新增 `weapon:2222 真我之钥·无暇回归`（`"desc": []`，隐藏原版超高元素特效行）；`armor:4519/4520/4521` 仅补 `note_remove: ["Element Amplify \\d+"]`，原有 `desc` 文字未变。
3. `03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/help_card.gd`：
   - 不新增文案，仅在 `_content` 与 `detail_rows` 接入 `XTianqiGear.elem_amp_view(obj)`。

## 验证与云端选测

- 本地专项：`xiyou_tianqi_deck_phys_amp.tscn`（`--headless --audio-driver Dummy`）→ `TEST_RESULT={"passed":25,"total":25}`
- 本地校验与回归：
  - `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py` → 退出码 0（含 `secret_books`、`general_books`、`gear_elem_amp` 全部通过）
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check` → 退出码 0（82 个脚本，812 个函数都有）
  - `python3 03_再刷重制_Godot/07_开发环境/语法检查.py` → 退出码 0（1200 个 `.gd`，0 个问题）
  - `python3 03_再刷重制_Godot/07_开发环境/工具回归.py` → 退出码 0（24/24 项全部通过）
  - `python3 03_再刷重制_Godot/07_开发环境/交付自检.py` → 退出码 0
- 云端选测：
  - 合并前（提交 `50c7376ea`）：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45356836130 （16 片全部通过）
  - 合并 `github/main`（`1667d3cda`）并解冲突后（提交 `0ae336e07`）：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45456941904 （492 个场景、16 片全部通过，`gh run watch` 前台等完）

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqiGear.reload_table` | 2 处（均为测试，`git grep -nE 'XTianqiGear\.reload_table\s*\(' -- '*.gd'`） | 调用方 2 处逐处结论：仅追加清 `_elem_amp_table`／`_elem_amp_views` 两张新缓存字典，既有清缓存语义不变，测试调用不受影响。 |
| `XTianqiGear.clear_effective_cache` | 32 处（均为测试，`git grep -nE 'XTianqiGear\.clear_effective_cache\s*\(' -- '*.gd'`） | 调用方 32 处逐处结论：仅追加清 `_elem_amp_table`／`_elem_amp_views`，确保切换开关或状态后不命中旧视图缓存，既有调用不受影响。 |
| `XTianqiGear.stat_list` | 3 处非测试＋1 处测试（`git grep -nE 'XTianqiGear\.stat_list\s*\(' -- '*.gd'`：`actor.gd:390/1252/1704`） | 调用方 4 处逐处结论：天启篇下在 `gear_view` 与 `element_fabao_view` 之后接 `elem_amp_view(e)`；`elem_amp_on()` 守卫西游档与开关关闭时原样返回，且 `gear_elem_amp.json` 与 `skill_rework.gear`／`element_fabaos` 零重叠，3 处角色属性／特性／开战状态聚合均按设计读取新增幅，不会改坏西游档或专武。 |
| `XTianqiGear.sync_element_fabaos` | 1 处非测试（`git grep -nE 'sync_element_fabaos\s*\(' -- '*.gd'`：`tianqi_save.gd:187`） | 调用方 1 处逐处结论：函数体未改（仅在其下方新增 F 节静态成员与函数），无影响。 |
| `XTianqiSkills.reload_table` | 6 处注释＋69 处测试（`git grep -nE 'XTianqiSkills\.reload_table\s*\(' -- '*.gd'`） | 调用方 75 处逐处结论：仅追加清 `_passive_elup` 缓存，与 `_again` 行为对称，不影响既有重载逻辑。 |
| `XTianqiSkills.again_sources` | 1 处非测试（`git grep -nE 'again_sources\s*\(' -- '*.gd'`：`tianqi_skills.gd:490`） | 调用方 1 处逐处结论：函数体未改（仅在其下方新增 `passive_elup_sources` 等辅助函数），无影响。 |
| `XTianqiSkills.gear_view` | 2 处非测试＋19 处测试（`git grep -nE 'XTianqiSkills\.gear_view\s*\(' -- '*.gd'`：`tianqi_gear.gd:325`、`ui/help_card.gd:139`） | 调用方 21 处逐处结论：`YEP_RECOMPUTE` 开且在天启篇存档时按改写后 `note` 重算 `yep` 并差值保留宝珠增量；2 处非测试调用（装备属性视图、说明卡）与测试均期望专武删掉的原版 `Element Amplify` 不再残留，西游档与关开关时原样返回。 |
| `XTianqiSkills.rec_state` | 2 处非测试（`git grep -nE 'XTianqiSkills\.rec_state\s*\(' -- '*.gd'`：`xdb.gd:215`，及类内 `tianqi_skills.gd:435`） | 调用方 2 处逐处结论：天启篇状态表改写后同步重算 `yep`，清掉 36 个改写状态残留的原版 `Element Amplify`；对未改写 `Element Amplify` 的状态 `yep` 无变化，西游档不进该分支。 |
| `XActor._carry_fp` | 1 处非测试（`git grep -nE '_carry_fp\s*\(' -- '*.gd'`：`actor.gd:866`） | 调用方 1 处逐处结论：仅将白名单内的 `passiveELUP` 改写状态（`state:173/2733`）纳入 `hard` 指纹，确保挂／卸该两状态时被动缓存必定失效重算；其它状态指纹完全不变。 |
| `XActor._passive_values_now` | 2 处非测试（`git grep -nE '_passive_values_now\s*\(' -- '*.gd'`：`actor.gd:1048/1057`） | 调用方 2 处逐处结论：仅当 `tag.begins_with("passiveELUP")` 时追加 `XTianqiSkills.passive_elup_extra(self, tag)`，白名单限定 6 装备＋2 状态，西游档与非 `passiveELUP` 标签零开销零变更。 |
| `XTianqiLedger.passive_buckets` | 1 处非测试（`git grep -nE 'passive_buckets\s*\(' -- '*.gd'`：`actor.gd:1587`） | 调用方 1 处逐处结论：仅在既有 `passiveELUP` 技能分支后补 `is_passive_elup_obj(o)` 分支，将上述 6 装备归 `tianqi` 桶、2 状态归 `state` 桶，避免误挤占九线 `equip` 桶，其余对象与西游档无变化。 |
| `XHelpCard._content`／`detail_rows` | 2 处＋3 处非测试 UI 调用（`help_card.gd:111/124`、`gear_detail.gd:120`、`skin_gear_detail.gd:79`、`skin_item_page.gd:292`） | 调用方 5 处逐处结论：在说明卡读取链路追加 `XTianqiGear.elem_amp_view(obj)`，幂等且西游档原样返回，保证新旧皮肤与装备详情页卡面同步显示分档后增幅。 |
| `XTianqiSkills.YEP_RECOMPUTE`／`PASSIVE_ELUP_EXT`、`XTianqiGear.GEAR_ELEM_RESCALE`（新增回退开关） | 各自类内＋`tests/xiyou_tianqi_deck_phys_amp.gd` | 均为默认 `true` 的 `static var` 回退开关，置 `false` 即可单项回退，专项已覆盖开／关两侧。 |

## 本分支提交

- `35bd002af` WIP: T451 阶段一实测清单入仓（226 把物理武器、60 件残留专武/防具、6 装备 2 状态 passiveELUP），等 Kyo 拍板口径
- `50c7376ea` T451 按 Kyo 事项 50 重调通用武器与普通防具全系增幅、修通 gear_view/rec_state 重算 yep 与 passiveELUP 扩展读取＋补专项
- `0ae336e07` T451 合并 github/main（1667d3cda）并解决 天启篇数据校验.py CHECKS 冲突
- 本提交：补齐标准交付单 `00_项目管理/交付/luiluu_t451.md`
