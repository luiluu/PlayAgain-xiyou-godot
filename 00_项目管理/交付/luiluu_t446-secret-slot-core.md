# 交付：luiluu/t446-secret-slot-core

- 车道／工作者：T446（子卡 T013-1b）／小A（ag，Gemini 4 Neon + high，职级 P8）
- 状态：可合并（已按 cc Opus 初审与 cc Sonnet 文字审完成返修）

## 变更记录草稿

## 2026-11-24 【ag·小A·未经审查】T446 T013-1b 秘籍格核心系统：6/4/3 格占格拦截、花钱封印、老存档迁移与功法页 UI（dev.待定）

- 新增秘籍格核心模块与规则表（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_secrets.gd`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/secret_books.json`）：
  - 总开关 `XTianqiSecrets.ENABLED := true`（设 `false` 完整回退到旧临时截断），仅在天启篇存档（`XTianqi.active`）生效，西游档零变化；单本加伤口径登记遵循 D274（`+5%～+15%`）。
  - 格数上限读 `balance_table.json` `tiers.<档位>.secret_cap`（弱者 6 格、强者 4 格、超强者 3 格）。
  - 占格判定：功法（`stype=6`）、通用被动书（物品 `code 43` 与公共事件 `code 44` 且 `stype=4`）、元素转换书（老 5068～5075＋新 11201～11205）、以及按 T441 避撞契约提前预留认号的深渊六式被动（6192～6203、6206～6211）与止戈（6185）/天怒（6204）；明确豁免号卷（`XTianqiTrumpet` / `<CodexPower>`）、抽奖被动（`stype=5`）、主动书（`stype 1/2/3` 等）、角色自带/职业/进阶被动（含超越极限 1240/1241/1242/1244）、27 本 Boss 血脉（D274④：`2807..2813`、`3224..3236`、`4701..4707`）、58 张外观变身卡（6801～6858）、种族技能、万灵增元丹被动与转换药剂（1058）。
  - 元素转换书：首次学习占 1 格；当角色生效格中已有另一门元素转换书时，再学新转换书原地替换、不要求先空出新格。
  - 学书拦截与单书多技能／固定角色预检：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/item_scene.gd` 在 `_effective`、`_use` 与 `_use_direct`（覆盖无对象直用道具）接入 `XTianqiSecrets.item_effective`／`item_learn_reason`，覆盖 `code 43` 与 `code 44` CE 书；单书同时教多个占格技能（如物品 77《心法:叠岚云烟》正练同教 4901＋4920、物品 1998《幸运女神的眷顾》同教 498＋4817）按单分支实际所需格数预检，不够即整本拒收、不消耗道具；固定角色公共事件（如 CE 1088 固定教 30 号角色）预检查对事件写死的角色而非当前选中角色。
  - 非道具学技能拦下反馈（P3-2）：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/actor.gd` 在 `learn_skill` 拦下满格学书、`_skill_records` 滤掉已封秘籍；`mv_event_core.gd`（318 指令）、`mv_interpreter.gd`（355 指令抑制紧随其后的伪成功 `$.toaster`，如 CE 1626 满格不再照弹「融合成功」）、`mv_script.gd`（变量角色与脚本 `learnSkill`）以及 `forget_skill_scene.gd`（`toggle` 满格弹提示且不翻转 `r.kept`）均在被拦时弹原因提示。
  - 花场钱封印与启封：花 5 场钱（`XTianqiMoney.price(s, 5)`，表驱动于 `secret_books.json` `rules.seal_field_units`；**注：5 场钱为本单自定初值，请协调转 Kyo 知会并与数值线共校**）可封印一本已学秘籍，不退书、腾出 1 格、被动立即失效；有空位时可从已封列表启封。
- 存档节、旧档迁移与总账协同（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_save.gd`、`tianqi_ledger.gd`、`battle/battle_logic.gd`）：
  - 在 `XTianqiSave` 注册 `flags.tianqi.secrets`（v1，懒建）并挂接 `after_load` 的 `XTianqiSecrets.migrate_after_load(s)`：旧天启篇档读入时若某角色生效占格秘籍超出上限，不没收 `skill_ids`，超出部分自动移入 `sealed` 已封列表；仅在首次迁移时（由 `migrated` 标记防重复）授予该角色一次免费封印补偿期（`free_pick = true`），二次超格读档仍截入已封但不再重复赠送。
  - 免费封印期自然结束条件（P2-1）：（1）玩家点击「结束免费期」按钮；（2）在技能页完成封印／启封后切换角色或关闭技能页自动结束（`XSkillScene._finish_touched_free_picks`）；（3）进入下一场战斗时全员自动结束（`XBattleLogic.setup` 调 `XTianqiSecrets.on_battle_start`），杜绝跨场囤着永久免单。
  - 总账协同（P1-1）：`XTianqiSecrets.on()` 开启时，`XTianqiLedger.bucket_of` 改用 `XTianqiSecrets.occupies_slot` 判定 `"secret"` 桶（抽奖被动、Boss 血脉、变身卡不再混入秘籍桶挤掉生效功法），`live_confirm_add` 跳过已封且非占格项不入 `raw_books`，`secret_kept` 不再按旧期三桶截断而是保留全部 `occupies_slot` 且未封印的书（含仅持书本状态 `#7135` 场景）；`ENABLED = false` 时完整回退旧临时截断。
- 新旧两套皮肤功法／被动页 UI 与文字审定稿（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/skill_scene.gd`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/skin/skin_skill_page.gd`）：
  - 功法（`stype=6`）与被动（`stype=4`）页展示 `秘籍格 X / Y`（格数全部统一「`X / Y`」空格写法；含已封数与「旧档补偿：免费封印中」提示），列表合并列出已封秘籍，新旧两套皮肤徽标统一为「`占格`／`已封`」（旧皮肤 `[占格]`／`[已封]`）；新皮肤 16:9 选中行不再在行尾塞长操作提示挤坏技能名，改由底栏显示 `确定 免费封印／封印／启封` 与右侧详情牌按钮（`免费封印`／`启封秘籍`／`结束免费期`）。
  - 全部天启篇玩家可见文字集中放在 `XTianqiSecrets` 中，由混合脚本调用，发行空壳替换后西游包零外泄。
- 校验、空壳与专项测试：
  - `03_再刷重制_Godot/03_转换工具/天启篇数据校验.py` 补 `secret_books.json` 规则校验；`03_再刷重制_Godot/07_开发环境/发行空壳.py` 的 `TIANQI_WORDS` 追加「秘籍格／启封秘籍」守卫；专项 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_secrets.gd`＋`.tscn` 覆盖全量验收与 P1-1／P2-1／P2-2／P3-2／文字审断言。
- 玩家可见：天启篇正式启用 6／4／3 秘籍格上限（弱者 6 格、强者 4 格、超强者 3 格），功法、通用被动书与元素转换书计入秘籍格（Boss 血脉、号卷、抽奖被动与主动书不占格），元素转换书支持原地替换；满格或余格不足学书将被拦截且不消耗书本，可在技能页的功法／被动栏花精魂封印已有秘籍腾出格位或启封已封秘籍；旧存档超格秘籍不没收，自动收入已封列表并在首次迁移时附带一次免费封印补偿期（点「结束免费期」、改完离开技能页或进下一场战斗自动结束）。

## 返修对照与留存 P3 登记

- **代码 P1-1（已修）**：`tianqi_ledger.gd` 开启新秘籍格时 `bucket_of` 改用 `XTianqiSecrets.occupies_slot`、`live_confirm_add` 非占格不进 `raw_books`、`secret_kept` 按 `occupies_slot && !is_sealed` 保留不再用旧期三截断；专项补超强者 3 功法（7166/7167/7168）＋3 抽奖被动（6305～6307）＋2 血脉（2807/3236）全算伤害断言。
- **代码 P2-1（已修）**：`free_pick` 新增自然结束条件（点「结束免费期」、改完切角色／关技能页自动结束、进入下一场战斗全员自动结束）；存档行补 `migrated` 标记，读档超格只在首次迁移给一次免费期，后续不再重复送。
- **代码 P2-2（已修）**：`tianqi_secrets.gd` 重写 CE 分支扫描器（按 102/402 与 111/411 单路径计算同分支同时新增格数，并识别固定角色 CE）与 `code 43` 多技能预检，`item_scene._use_direct` 接入拦截；专项实测物品 77（固定 30 号角色需 2 格）与物品 1998（code 43 双技能需 2 格），1 格时整本拒收不吃书。
- **代码 P3-2（已修）**：`mv_event_core.gd`（318）、`mv_interpreter.gd`（抑制紧随其后的伪成功 `$.toaster`）、`mv_script.gd`、`forget_skill_scene.gd`（不翻 `r.kept` 且弹提示）全部补齐；专项实测 CE 1626（88 号角色 7515 满格时不弹「融合成功」）与 `forget_skill_scene.toggle`。
- **文字审（cc Sonnet 全部已修）**：P2-1 改「旧档补偿：免费封印中」＋按钮「结束免费期」＋弹窗补自动／手动结束说明；P2-2 新旧徽标统一「占格／已封」（`[占格]`／`[已封]`）；P3 格数统一「`%d / %d`」、`:505` 补「生效中的」、统一「旧存档」、已封重学加「，启封后生效」、新皮肤 16:9 行尾操作提示挪到底栏不再挤坏技能名。
- **其余 P3 留存登记**：
  - P3-1（`tianqi_secrets.gd` 迁移排序）：老档首次迁移目前按技能号升序保留、号大移入已封，因有免费封印补偿期兜底未改为按旧 `secret_kept` 贡献排序，后续有需要可按贡献重排。
  - P3-3（**需转 Kyo 知会**）：`secret_books.json` `rules.seal_field_units = 5`（封印价「5 场钱」）为设计稿仅写「封要花一点钱」时由本单暂定的初值，请协调转 Kyo 知会并交数值线共校。
  - P3-4（归 1c / T443）：`secret_books.json` `rules.per_book_damage_pct_range = [5, 15]` 仅作规则登记，当前单本上限仍读 `damage_ledger.json` `phase4.secret_slot = 0.08`，D274 单本加伤落地归 T443（1c）。

## 玩家可见文字清单（已按 cc Sonnet 文字审修订）

全部玩家可见中文文案均集中于 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_secrets.gd`：

- 满格／已学提示：`已学会此秘籍（已封印），请在技能页启封，启封后生效`、`已经学会这本秘籍`、`%s最多装备 %d 本秘籍（当前 %d / %d），请先在技能页封印已有秘籍`、`%s最多装备 %d 本秘籍（当前 %d / %d，本书需 %d 格），请先在技能页封印已有秘籍`
- 格数与列表标签：`秘籍格 %d / %d`、`（已封 %d）`、` · 旧档补偿：免费封印中`、`已封`、`占格`、`[已封]`、`[占格]`；底栏按键提示：`启封`、`免费封印`、`封印`
- 详情牌按钮与标签：`已封印 · 不生效`、`占秘籍格（%d / %d）`、`启封秘籍`、`免费封印`、`封印（%s 精魂）`、`结束免费期`
- 确认弹窗与操作反馈：`封印「%s」？`、`启封「%s」？`、`旧存档超格补偿期间本次封印不收费。封印后被动立即失效，腾出 1 个秘籍格（书本不退还，可在已封列表重新启封）。点「结束免费期」、改完离开技能页或进入下一场战斗后免费期自动结束，之后封印要花精魂。`、`封印后被动立即失效，腾出 1 个秘籍格，书本不退还。需花费 %s 精魂（当前 %s）。`、`启封后将占用 1 个秘籍格（当前 %d / %d），被动立即生效。`、`启封后将与当前生效的「%s」互换（不额外占格），被动立即生效。`、`当前秘籍格已满（%d / %d），请先封印一本生效中的秘籍。`、`秘籍格已满（%d / %d），请先封印一本生效中的秘籍`、`确认封印`、`确认启封`、`取消`、`精魂不足（封印需要 %s 精魂）`、`已免费封印「%s」，腾出 1 个秘籍格`、`已封印「%s」（消耗 %s 精魂），腾出 1 个秘籍格`、`已启封「%s」，被动已生效`、`已结束旧存档免费封印期，后续封印将收取精魂`

## 验收截图（已重拍入仓，16:9 800×450 与 20:9 1000×450）

- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/new_skin_secrets_list_16x9.png`（新皮肤功法页：秘籍格 3 / 3、已封 2、旧档补偿：免费封印中、选中行「玄天功·入门 占格」无省略号、底栏「确定 免费封印」、详情牌「结束免费期」，16:9）
- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/new_skin_secrets_list_20x9.png`（新皮肤功法页，20:9）
- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/new_skin_secrets_confirm_16x9.png`（新皮肤 `XSkinConfirm` 封印确认弹窗：旧存档说明与自动结束说明、按钮「结束免费期」，16:9）
- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/new_skin_secrets_confirm_20x9.png`（新皮肤封印确认弹窗，20:9）
- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/old_skin_secrets_list_16x9.png`（旧皮肤功法页：右上金字秘籍格 3 / 3、列表徽标统一 `[占格]`/`[已封]`，16:9）
- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/old_skin_secrets_list_20x9.png`（旧皮肤功法页，20:9）
- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/old_skin_secrets_confirm_16x9.png`（旧皮肤花精魂封印确认弹窗，16:9）
- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/old_skin_secrets_confirm_20x9.png`（旧皮肤封印确认弹窗，20:9）

## 交接板

- 下一步：T446（T013-1b）返修完成，待 cc Opus 复核 P1/P2 后合入；后续 T013-1c（T443 功法 50 本重标＋EV054 重整）与 T013-1d（T444 通用书第一批）可直接接在 `XTianqiSecrets` 与 `secret_books.json` 上推进。
- 用户试玩说明：天启篇启用弱 6 / 强 4 / 超 3 秘籍格；满格或余格不足学书会提示拦下且不消耗书；技能页功法／被动栏可花精魂封印已有秘籍或启封已封秘籍；旧存档超格不没收、自动入已封并在首次迁移赠一次免费封印补偿期（点「结束免费期」、改完离开技能页或进下一场战斗自动结束）。
- 需要用户决定（知会项）：封印价 `secret_books.json` `rules.seal_field_units = 5`（5 场钱）为设计稿未写具体数时本单暂定的初值，请协调转 Kyo 知会并与数值线共校（可随时改表，无需改代码）。

## 进度账

- 部件 9／10（原版养成线重做·第一期子卡 T013-1b）：秘籍格核心系统初版及初审返修（P1-1／P2-1／P2-2／P3-2 与文字审全部项）已落地并全绿通过。

## 可优化（流程／工具／效率）

- 已做：所有天启篇秘籍格玩家可见文案全部收口到纯天启篇脚本 `XTianqiSecrets`，混合脚本零硬编码并在 `发行空壳.py` 增补「秘籍格／启封秘籍」防外泄守卫（回退只需删 `TIANQI_WORDS` 末尾两词），避免西游发行包漏字与空壳特例膨胀。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XActor.learn_skill` | 62 处（`git grep -nE '[^[:alnum:]_]learn_skill[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/**/*.gd'`） | 调用方 62 处逐处结论：仅在 `XTianqiSecrets.on()` 为真且技能属于占格秘籍且满格/已学时返回（非占格的战技、魔法、角色自带/进阶、血脉、号卷、抽奖被动、种族全放行；元素转换书已有生效转换书时原地替换放行）；西游档与 `ENABLED=false` 时 `blocks_learn` 恒返 `false`，62 处行为零变化。 |
| `XActor._skill_records` | 3 处（`git grep -nE '[^[:alnum:]_]_skill_records[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/**/*.gd'`） | 调用方 3 处逐处结论（定义处 + `native_skills` + `_skills_now`）：仅跳过 `XTianqiSecrets.is_sealed(self, id)` 为真的已封秘籍，不删 `skill_ids`；未封印技能、西游档及 `ENABLED=false` 下结果完全不变。 |
| `XTianqiSave.after_load` | 1 处（`git grep -nE 'XTianqiSave\.after_load[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/**/*.gd'`） | 调用方 1 处逐处结论（`XState.from_dict`）：末尾新增幂等调用 `XTianqiSecrets.migrate_after_load(s)`，仅对天启篇超格旧档将超出部分移入 `sealed` 并在首次迁移记 `migrated = true`、`free_pick = true`，新档懒建不写分区，西游档直接返回。 |
| `XTianqiLedger.bucket_of` | 5 处（`git grep -nE '[^[:alnum:]_]bucket_of[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/**/*.gd'`） | 调用方 5 处逐处结论（定义处 + `passive_buckets` 2 处 + `nine_off_source` + `param_cap`）：`XTianqiSecrets.on()` 为真时技能桶改按 `XTianqiSecrets.occupies_slot` 判 `"secret"`，避免抽奖被动／血脉／变身卡挤入秘籍桶；`nine_off_skill` 仍走 `is_secret_skill` 不受影响；关开关或西游档完全回退。 |
| `XTianqiLedger.passive_buckets` | 2 处（`git grep -nE '[^[:alnum:]_]passive_buckets[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/**/*.gd'`） | 调用方 2 处逐处结论（定义处 + `XActor._refresh_passive_now`）：新增 `is_sealed` 守卫跳过已封秘籍；未封或关开关时不变。 |
| `XTianqiLedger.secret_kept` | 2 处（`git grep -nE '[^[:alnum:]_]secret_kept[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/**/*.gd'`） | 调用方 2 处逐处结论（定义处 + `apply_nine_cap`）：`XTianqiSecrets.on()` 为真时保留全部 `occupies_slot` 且未封印的书（不再做旧期三截断）；关开关时完整回退旧临时截断，`xiyou_tianqi_ledger_p3` 40/40 与 `xiyou_tianqi_live_sample` 32/32 通过。 |
| `XTianqiLedger.live_confirm_add` | 2 处（`git grep -nE '[^[:alnum:]_]live_confirm_add[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/**/*.gd'`） | 调用方 2 处逐处结论（定义处 + `XDamage._calculate`）：`XTianqiSecrets.on()` 为真且 `cap == "secret"` 时跳过已封书、非占格技能归 `"none"` 不入 `raw_books`；关开关或西游档完全不变。 |
| `XBattleLogic.setup` | 3 处（`git grep -nE '\.setup[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/xiyou/battle/'`） | 调用方逐处结论：紧接 `XTianqiBrand.sweep(s)` 追加 `XTianqiSecrets.on_battle_start(s)`，仅在天启篇档且已有 `secrets` 分区时清掉 `free_pick`；西游档与无分区新档直接返回零开销。 |
| `XForgetSkillScene.toggle` | 2 处（`git grep -nE '[^[:alnum:]_]toggle[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/forget_skill_scene.gd'`） | 调用方 2 处逐处结论（定义处 + `ok()`）：重新学习被 `XTianqiSecrets.learn_reason` 拦下时播蜂鸣＋弹提示并提前返回不翻 `r.kept`；西游档及非占格技能零变化。 |
| `MVEventCore._execute`（318）与 `MVInterpreter._host_command`（355）／`MVScript.run` | 3 处（`mv_event_core.gd:454`、`mv_interpreter.gd:420`、`mv_script.gd:235,1168`） | 仅在天启篇且 `XTianqiSecrets.learn_reason` 非空时播蜂鸣＋弹提示，并抑制紧随 318 之后的伪成功 `$.toaster`（如 CE 1626「融合成功」）；西游档及未拦截路径完全不变。 |

## 验证与云端选测

- 云端选测（返修最终代码提交 `ad8a809e90`，基准 `7394f04624`）：**522 / 522 场景全部通过**（16 片，最长一片 15.3 分钟）
  - 运行页：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45321441669
- 本机专项与回归（全部加 `--audio-driver Dummy`）：
  - `tests/xiyou_tianqi_secrets.tscn`：headless 86/86 通过；窗口实拍 102/102 通过（含 8 张 16:9 800×450 与 20:9 1000×450 截图与尺寸校验）
  - `tests/xiyou_tianqi_live_sample.tscn`：32/32 通过
  - `tests/xiyou_tianqi_ledger_p3.tscn`：40/40 通过
  - `tests/xiyou_tianqi_nine_off.tscn`：19/19 通过
  - `tests/xiyou_tianqi_save.tscn`：82/82 通过
  - `tests/xiyou_ui_skin_card_e.tscn`：44/44 通过
  - `tests/xiyou_ui_page_details.tscn`：46/46 通过
  - `tests/xiyou_skill_page.tscn`：27/27 通过
  - `tests/xiyou_item_use.tscn`：13/13 通过
- 工具检查：
  - `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：1202 个 `.gd`，0 问题
  - `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`：全部通过
  - `python3 03_再刷重制_Godot/07_开发环境/天启篇存档登记.py`：通过
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：通过（82 脚本 804 函数全齐）
  - `python3 03_再刷重制_Godot/07_开发环境/交付自检.py`：退出码 0，结论「可以交付」

## 本分支提交

- `e000551df` T446 T013-1b 秘籍格核心系统：6/4/3 格占格拦截、花钱封印、老存档迁移与功法页 UI
- `77de110de` Merge branch 'main' into luiluu/t446-secret-slot-core
- `7394f0462` T446 交付单入仓（含云端选测 45311591082 全绿 490/490 与两套皮肤 8 张截图）
- `22c2436c0` T446 补测试脚本 xiyou_tianqi_secrets.gd.uid
- `040e0c2e8` T446 返修：修总账协同 P1-1、免费期终点与首次迁移 P2-1、单书多技能与固定角色预检 P2-2、非道具拦学提示 P3-2 及文字审全部项
- `ad8a809e9` T446 返修补：secret_kept 改按 occupies_slot 且非已封保留（修 xiyou_tianqi_live_sample 仅持状态 #7135 场景）
- （本交付单更新提交见最新提交）
