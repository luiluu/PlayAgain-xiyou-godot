# 交付：luiluu/t446-secret-slot-core

- 车道／工作者：T446（子卡 T013-1b）／小A（ag，Gemini 4 Neon + high，职级 P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-24 【ag·小A·未经审查】T446 T013-1b 秘籍格核心系统：6/4/3 格占格拦截、花钱封印、老存档迁移与功法页 UI（dev.待定）

- 新增秘籍格核心模块与规则表（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_secrets.gd`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/secret_books.json`）：
  - 总开关 `XTianqiSecrets.ENABLED := true`（设 `false` 完整回退到旧临时截断），仅在天启篇存档（`XTianqi.active`）生效，西游档零变化；单本加伤口径登记遵循 D274（`+5%～+15%`）。
  - 格数上限读 `balance_table.json` `tiers.<档位>.secret_cap`（弱者 6 格、强者 4 格、超强者 3 格）。
  - 占格判定：功法（`stype=6`）、通用被动书（物品 `code 43` 与公共事件 `code 44` 且 `stype=4`）、元素转换书（老 5068～5075＋新 11201～11205）、以及按 T441 避撞契约提前预留认号的深渊六式被动（6192～6203、6206～6211）与止戈（6185）/天怒（6204）；明确豁免号卷（`XTianqiTrumpet` / `<CodexPower>`）、抽奖被动（`stype=5`）、主动书（`stype 1/2/3` 等）、角色自带/职业/进阶被动（含超越极限 1240/1241/1242/1244）、27 本 Boss 血脉（D274④：`2807..2813`、`3224..3236`、`4701..4707`）、58 张外观变身卡（6801～6858）、种族技能、万灵增元丹被动与转换药剂（1058）。
  - 元素转换书：首次学习占 1 格；当角色生效格中已有另一门元素转换书时，再学新转换书原地替换、不要求先空出新格。
  - 学书拦截与花钱封印：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/item_scene.gd` 在 `_effective` 与 `_use` 中接入 `XTianqiSecrets.item_effective`／`item_learn_reason`（覆盖 `code 43` 与 `code 44` CE 书），满格时拦下且不消耗物品并弹清晰提示；`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/actor.gd` 仅增 2 处挂点（`learn_skill` 调 `blocks_learn`、`_skill_records` 滤掉已封秘籍）。花 5 场钱（`XTianqiMoney.price(s, 5)`，表驱动于 `secret_books.json` `rules.seal_field_units`）可封印一本已学秘籍，不退书、腾出 1 格、被动立即失效；有空位时可从已封列表启封。
- 存档节与老档迁移（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_save.gd`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_ledger.gd`）：
  - 在 `XTianqiSave` 注册 `flags.tianqi.secrets`（v1，懒建）并挂接 `after_load` 的 `XTianqiSecrets.migrate_after_load(s)`：老天启篇档读入时若某角色生效占格秘籍超出上限，不没收 `skill_ids`，超出部分自动移入 `sealed` 已封列表并授予该角色一次免费自选生效格（`free_pick = true`，调配期间封印 0 精魂，完成自选后恢复收费），二次读档幂等；西游档读写往返零新增字段。
  - `XTianqiLedger`（`passive_buckets`、`secret_kept`、`live_confirm_add`）在 `XTianqiSecrets.is_sealed` 为真时跳过已封秘籍，确保已封书不入被动缓存、不入 `bySource`、不参与确认阶段归池。
- 新旧两套皮肤功法／被动页 UI（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/skill_scene.gd`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/skin/skin_skill_page.gd`）：
  - 功法（`stype=6`）与被动（`stype=4`）页展示 `秘籍格 X / Y`（含已封数与老档免费自选标记），列表合并列出已封秘籍（新皮肤标「占格／已封」，旧皮肤标「[秘籍]／[已封]」），提供封印／启封／完成自选确认弹窗（新皮肤走 `XSkinConfirm`，旧皮肤走居中 MV 确认窗 `secret_win`）。
  - 全部天启篇玩家可见文字集中放在 `XTianqiSecrets` 中，由混合脚本调用，发行空壳替换后西游包零外泄。
- 校验、空壳与专项测试：
  - `03_再刷重制_Godot/03_转换工具/天启篇数据校验.py` 补 `secret_books.json` 规则校验；`03_再刷重制_Godot/07_开发环境/发行空壳.py` 的 `TIANQI_WORDS` 追加「秘籍格／启封秘籍」守卫；新增专项 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_secrets.gd`＋`.tscn`。
- 玩家可见：天启篇正式启用 6／4／3 秘籍格上限（弱者 6 格、强者 4 格、超强者 3 格），功法、通用被动书与元素转换书计入秘籍格（Boss 血脉、号卷、抽奖被动与主动书不占格），元素转换书支持原地替换；满格学书将被拦截且不消耗书本，可在技能页的功法／被动栏花精魂封印已有秘籍腾出格位或启封已封秘籍；老存档超格秘籍不没收，自动收入已封列表并附带一次免费自选生效格。

## 玩家可见文字清单（待审，D276 归 cc Sonnet 文字审）

全部玩家可见中文文案均集中于 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_secrets.gd`：

- 满格／已学提示：`已学会此秘籍（已封印），请在技能页启封`、`已经学会这本秘籍`、`%s最多装备 %d 本秘籍（当前 %d/%d），请先在技能页封印已有秘籍`
- 格数与列表标签：`秘籍格 %d / %d`、`（已封 %d）`、` · 免费自选`、`已封`、`占格`、`[已封]`、`[秘籍]`、`按确定免费启封`、`按确定启封`、`按确定免费封印`、`按确定封印`
- 详情牌按钮与标签：`已封印 · 不生效`、`占秘籍格（%d/%d）`、`启封秘籍`、`免费封印`、`封印（%s 精魂）`、`完成自选`
- 确认弹窗与操作反馈：`封印「%s」？`、`启封「%s」？`、`老存档免费自选期间本次封印不收费。封印后被动立即失效，腾出 1 个秘籍格（书本不退还，可在已封列表重新启封）。`、`封印后被动立即失效，腾出 1 个秘籍格，书本不退还。需花费 %s 精魂（当前 %s）。`、`启封后将占用 1 个秘籍格（当前 %d / %d），被动立即生效。`、`启封后将与当前生效的「%s」互换（不额外占格），被动立即生效。`、`当前秘籍格已满（%d / %d），请先封印一本生效中的秘籍。`、`确认封印`、`确认启封`、`取消`、`精魂不足（封印需要 %s 精魂）`、`已免费封印「%s」，腾出 1 个秘籍格`、`已封印「%s」（消耗 %s 精魂），腾出 1 个秘籍格`、`已启封「%s」，被动已生效`、`已完成老存档免费自选，后续封印将收取精魂`

## 验收截图（已入仓，16:9 800×450 与 20:9 1000×450）

- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/new_skin_secrets_list_16x9.png`（新皮肤功法页：秘籍格 3/3、已封 2、免费自选、详情牌按钮，16:9）
- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/new_skin_secrets_list_20x9.png`（新皮肤功法页，20:9）
- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/new_skin_secrets_confirm_16x9.png`（新皮肤 `XSkinConfirm` 封印确认弹窗，16:9）
- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/new_skin_secrets_confirm_20x9.png`（新皮肤封印确认弹窗，20:9）
- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/old_skin_secrets_list_16x9.png`（旧皮肤功法页：右上金字秘籍格 3/3、列表 `[秘籍]`/`[已封]`，16:9）
- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/old_skin_secrets_list_20x9.png`（旧皮肤功法页，20:9）
- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/old_skin_secrets_confirm_16x9.png`（旧皮肤花精魂封印确认弹窗，16:9）
- `00_项目管理/归档/交付截图/luiluu_t446-secret-slot-core/old_skin_secrets_confirm_20x9.png`（旧皮肤封印确认弹窗，20:9）

## 交接板

- 下一步：T013-1b（T446）已可合并（合入顺位由总装按 T424 整包后安排）；玩家可见文字集中于 `tianqi_secrets.gd` 待审；后续 T013-1c（T443 功法 50 本重标＋EV054 重整）与 T013-1d（T444 通用书第一批）可直接接在 `XTianqiSecrets` 与 `secret_books.json` 上推进。
- 用户试玩说明：天启篇启用弱 6 / 强 4 / 超 3 秘籍格；满格学书会提示拦下且不消耗书；技能页功法／被动栏可花精魂封印已有秘籍或启封已封秘籍；老档超格不没收、自动入已封并赠一次免费自选。
- 需要用户决定：无（存档节与血脉豁免均已按 D274 拍板）。

## 进度账

- 部件 9／10（原版养成线重做·第一期子卡 T013-1b）：秘籍格核心系统（6/4/3 格占格拦截、花钱封印与启封、老档迁移与 `flags.tianqi.secrets` 存档节、两套皮肤功法/被动页 UI）已落地并全绿通过。

## 可优化（流程／工具／效率）

- 已做：所有天启篇秘籍格玩家可见文案全部收口到纯天启篇脚本 `XTianqiSecrets`，混合脚本零硬编码并在 `发行空壳.py` 增补「秘籍格／启封秘籍」防外泄守卫（回退只需删 `TIANQI_WORDS` 末尾两词），避免西游发行包漏字与空壳特例膨胀。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XActor.learn_skill` | 62 处（`git grep -nE '[^[:alnum:]_]learn_skill[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/**/*.gd'`） | 调用方 62 处逐处结论：仅在 `XTianqiSecrets.on()` 为真且技能属于占格秘籍且满格/已学时返回（非占格的战技、魔法、角色自带/进阶、血脉、号卷、抽奖被动、种族全放行；元素转换书已有生效转换书时原地替换放行）；西游档与 `ENABLED=false` 时 `blocks_learn` 恒返 `false`，62 处行为零变化。 |
| `XActor._skill_records` | 3 处（`git grep -nE '[^[:alnum:]_]_skill_records[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/**/*.gd'`） | 调用方 3 处逐处结论（定义处 + `native_skills` + `_skills_now`）：仅跳过 `XTianqiSecrets.is_sealed(self, id)` 为真的已封秘籍，不删 `skill_ids`；未封印技能、西游档及 `ENABLED=false` 下结果完全不变。 |
| `XTianqiSave.after_load` | 1 处（`git grep -nE 'XTianqiSave\.after_load[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/**/*.gd'`） | 调用方 1 处逐处结论（`XState.from_dict`）：末尾新增幂等调用 `XTianqiSecrets.migrate_after_load(s)`，仅对天启篇超格老档将超出部分移入 `sealed` 并记 `free_pick = true`，新档懒建不写分区，西游档直接返回。 |
| `XTianqiLedger.passive_buckets` | 2 处（`git grep -nE '[^[:alnum:]_]passive_buckets[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/**/*.gd'`） | 调用方 2 处逐处结论（定义处 + `XActor._refresh_passive_now`）：新增 `is_sealed` 守卫跳过已封秘籍；未封或关开关时不变。 |
| `XTianqiLedger.secret_kept` | 2 处（`git grep -nE '[^[:alnum:]_]secret_kept[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/**/*.gd'`） | 调用方 2 处逐处结论（定义处 + `apply_nine_cap`）：循环内跳过 `is_sealed` 秘籍；关开关时完整回退旧临时截断，`xiyou_tianqi_ledger_p3` 40/40 通过。 |
| `XTianqiLedger.live_confirm_add` | 2 处（`git grep -nE '[^[:alnum:]_]live_confirm_add[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/**/*.gd'`） | 调用方 2 处逐处结论（定义处 + `XDamage._calculate`）：仅当 `cap == "secret"` 且对应书号已封时跳过；不影响装备/角色桶及未封书。 |

## 验证与云端选测

- 云端选测（提交 `77de110deb`，基准 `0de2e578d5`）：**490 / 490 场景全部通过**（16 片，最长一片 17.5 分钟）
  - 运行页：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45311591082
- 本机专项与回归（全部加 `--audio-driver Dummy`）：
  - `tests/xiyou_tianqi_secrets.tscn`：headless 67/67 通过；窗口实拍 84/84 通过（含 8 张 16:9 800×450 与 20:9 1000×450 截图与尺寸校验）
  - `tests/xiyou_tianqi_ledger_p3.tscn`：40/40 通过
  - `tests/xiyou_tianqi_save.tscn`：82/82 通过
  - `tests/xiyou_tianqi_nine_off.tscn`：19/19 通过
  - `tests/xiyou_ui_skin_card_e.tscn`：44/44 通过
  - `tests/xiyou_skill_page.tscn`：27/27 通过
  - `tests/xiyou_item_use.tscn`：13/13 通过
- 工具检查：
  - `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：1197 个 `.gd`，0 问题
  - `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`：全部通过（含新增 `secret_books.json` 规则自检）
  - `python3 03_再刷重制_Godot/07_开发环境/天启篇存档登记.py`：通过
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：通过（82 脚本 799 函数全齐）
  - `python3 03_再刷重制_Godot/07_开发环境/工具回归.py`：23 项全通过

## 本分支提交

- `e000551df` T446 T013-1b 秘籍格核心系统：6/4/3 格占格拦截、花钱封印、老存档迁移与功法页 UI
- `77de110de` Merge branch 'main' into luiluu/t446-secret-slot-core
- （交付单入仓提交见本分支最新提交）
