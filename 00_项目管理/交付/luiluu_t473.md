# 交付：luiluu/t473

- 车道／工作者：小A（Neon＋high，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-24 【小A·未经审查】T473：修天启篇两处本体漏口——原版装 tianqi_affixes／alien.tq 不逃逸九线封顶＋秘籍格改读天启档位（dev.待定）

- **起因**：T471 小A 核 R1 查出天启篇本体两处漏口：
  1. **P1-1**：`modes/xiyou/core/tianqi_ledger.gd:647` 在 `XTianqiLedger.bucket_of` 中将带 `tianqi_affixes` 或 `XTianqiAlienGear.is_tq` 的装备一律归入 `"tianqi"` 桶，而 `NINE_BUCKETS` 不含 `"tianqi"`。由于天启篇掉落／商店／事件生成的原版装备（如 `4535 苍琉幻生灭`、`4285 双鱼念气瓶`、`4075 三环剑`、`4115 苍苍白骨`）均挂 `tianqi_affixes`（或可在工坊刻天启异化核 `alien.tq`），其原版 `note`／`meta`／`yep.elementAmplify`／`traits` 全部从 `"equip"` 洗白进 `"tianqi"` 桶，逃逸九线封顶（技能/元素/终伤/爆伤）、`NINE_OFF` 多动停用及 `param_cap`；而天启词条自身本就走 `XTianqiAffixBattle`、天启异化走 `XAlienBattle`／`XTianqiAlienAffix`，不经过 `bucket_of`。
  2. **P1-3**：`modes/xiyou/core/tianqi_secrets.gd:402,559,626,637` 与 `modes/xiyou/core/tianqi_ledger.gd:1073` 读西游原版 `XTier.tier_of`，未按天启篇运行时名单档位 `XTianqiSkills.tier_of` 取数，导致与西游有档位差的 32 名角色格数错乱（例如三笠 95、绿司机 2、维利 22 错得 4/6/6 格而非 3/4/4 格）。
- **改动**：
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_ledger.gd`：
    - `bucket_of`（第 645～659 行）：仅纯天启篇底子装备（七印 `qiyin`、净印／遗物 `tq_reward`）归 `"tianqi"` 桶；挂了 `tianqi_affixes` 或天启异化 `alien.tq` 的原版装／符文之语／成长装继续按本体归 `"hubris"`／`"runeword"`／`"equip"`，其原版被动与特性受九线封顶、`NINE_OFF` 与 `param_cap` 管束，天启词条与异化词条自身独立通道不受影响。
    - `secret_slots(a, s = null)`（第 1076～1084 行）：受 `XTianqi.active(s) and XTianqiSkills.tiers_on(s)` 守卫，天启篇档改读 `XTianqiSkills.tier_of(a, true)`（返回空时安全回退 `XTier.tier_of(a)`），西游档零改动照 `XTier.tier_of(a)`。
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_secrets.gd`：
    - 新增 `tier_of(a, s = null)`，受 `XTianqi.active(s) and XTianqiSkills.tiers_on(s)` 守卫，天启篇档按 `XTianqiSkills.tier_of(a, true)` 取运行时角色档位（空串回退 `XTier.tier_of(a)`），西游档零改动照 `XTier.tier_of(a)`。
    - `limit(a, s = null)` 及内部 `learn_reason`、`item_learn_reason`、`unseal`、`migrate_after_load`、`ui_slot_text`、`ui_card_actions`、`ui_confirm_spec` 统一传 `s` 改调 `tier_of(a, s)`／`limit(a, s)`；特别保障 `XState.from_dict` → `XTianqiSave.after_load(s)` → `migrate_after_load(s)` 在 `XState.current` 尚未切换（如从标题页或西游档读入天启老档）时也能按天启档位正确触发 T446 既有超量封印逻辑，已装多出的书自动移入已封且保留在 `skill_ids` 中不丢书。
  - 专项对齐与新增断言：
    - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_ledger_p3.gd`：更新 `secret_slots_by_tier` 对齐 `XTianqiSkills.tier_of`，新增 `_t473_fixes`（4 条断言：4535/4285/4075/4115 贴 `tianqi_affixes` 与 `alien.tq` 分桶、4535+4285 实测四池全部进 `"equip"` 触发 `nineCap` 且 `final_damage` 天启词条增量照常生效、`NINE_OFF` 不逃逸、`secret_slots` 天启 3/4/4/6 与西游 4/6/6/6 对照，44/44 通过）。
    - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_secrets.gd`：`_find_actor_by_tier` 对齐 `XTianqiSkills.ids`／`tier_of`，新增 `_test_t473_runtime_tier_and_migration`（3 条断言：三笠/绿司机/维利/艾坤 3/4/4/6 格及文案「超强者最多装备 3 本秘籍」、老档三笠 4 本/绿司机 6 本/维利 6 本在 `XState.current = null` 读档迁移自动超量封印至 3/4/4 不丢书且二次读档幂等、西游档零改动 4/6/6 不拦不写 `flags.tianqi`，89/89 通过）。
    - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_gongfa_shop.gd`：`_find_actor_by_tier` 对齐 `XTianqiSkills.ids`／`tier_of`，并将易筋经妙法／九阳生命增量断言从隐含 `base_mhp_rate == 1.0` 的 `mhp/base_mhp` 改为角色无关的 `(param_base(0) - base_mhp_base) / param_base_direct(0)`（42/42 通过）。
- **玩家可见**：修复天启篇两处底层逻辑漏口：带天启词条或天启异化的原版装备被动现正确受九线封顶管束；角色秘籍格上限现与天启篇角色档位一致（三笠 3 格、绿司机 4 格、维利 4 格等），老存档已装超出新上限的秘籍读档后自动移入已封印列表、不丢书且首次迁移享有免费自选。

## 交接板

- 下一步：
  - 合并本单后，可重跑 T471（D281 炼狱档复量）并同步调整 `t445_book_probe.gd` 的 95/2/22 秘籍本数至 3/4/4。
- 用户试玩说明：
  - 天启篇中带天启词条或天启异化的原版装备，其原版被动不再绕过九线封顶；角色秘籍格上限统一按天启篇档位计算（超强者 3、强者 4、弱者 6），老档超格秘籍自动转入已封印不丢书。西游档无任何变化。
- 需要用户决定：无（注：`4535 苍琉幻生灭` 等原版 80 级神话装自带的 `PushState0329`／`PushsubState0335` 属于原版装本体状态内容，本单按验收范围未擅自删改，由后续是否删改原版装内容单独决定）。

## 进度账

- 天启篇核心修复：修复伤害加成总账分桶逃逸漏口与秘籍格档位错读漏口（不涉及主表里程碑百分比变更）。

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqiLedger.bucket_of` | 28 处含定义（`git grep -nE '[^[:alnum:]_]bucket_of[[:space:]]*\(' -- '*.gd'`） | 核心调用 4 处（`tianqi_ledger.gd:752,788` `passive_buckets`、`:992` `nine_off_source`、`:1285` `param_cap`）：均只针对对象自身原版 `note`/`meta`/`yep`/`traits` 判桶，去掉 `tianqi_affixes` 与 `is_tq` 逃逸后四处一并修复，天启词条（`XTianqiAffixBattle`）与天启异化（`XAlienBattle`/`XTianqiAlienAffix`）走独立通道不受影响；`k_calibrate.gd:867` 为调试打印；其余 22 处测试调用（`xiyou_tianqi_ledger`、`xiyou_tianqi_ledger_p3`、`xiyou_tianqi_nine_off`、`xiyou_tianqi_secrets`）均已验证全过。 |
| `XTianqiLedger.secret_slots` | 8 处含定义（`git grep -nE '[^[:alnum:]_]secret_slots[[:space:]]*\(' -- '*.gd'`） | `tianqi_ledger.gd:1142` `secret_kept`（回退旧截断路径，与 `XTianqiSecrets.limit` 同口径）；测试 6 处（`xiyou_tianqi_ledger_p3.gd:165,542-546`、`xiyou_tianqi_live_sample.gd:234`）：均按天启篇档位或西游档回退 `XTier` 校验通过；新增可选参数 `s: XState = null` 完全向后兼容单参调用。 |
| `XTianqiSecrets.limit` | 20 处调用（`git grep -nE '[^[:alnum:]_]limit[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_secrets.gd' '03_再刷重制_Godot/01_Godot工程/tests/' \| grep -v 'static func limit' \| grep -E 'tianqi_secrets\|XTianqiSecrets\.limit'`） | `tianqi_secrets.gd` 内部 11 处调用（`learn_reason`、`item_learn_reason`、`unseal`、`migrate_after_load`、`ui_slot_text`、`ui_card_actions`、`ui_confirm_spec`）均补传 `s`，保证读档迁移时即使 `XState.current` 未切换也按天启档位正确封超格；测试 8 处（`xiyou_tianqi_secrets.gd`、`xiyou_tianqi_gongfa_shop.gd`）均已验证全过；探针 `t445_book_probe.gd:59` 会在后续 T471 重跑中自动拿到正确上限 3/4/4；新增可选参数 `s: XState = null` 向后兼容单参调用。 |

## 验收逐条核对

1. **原版装上的 `tianqi_affixes` 也进九线封顶，不再逃逸，专项断言覆盖 4535 等样例**：通过。`XTianqiLedger.bucket_of` 移除 `tianqi_affixes`（及同源 `XTianqiAlienGear.is_tq`）逃逸分支；`xiyou_tianqi_ledger_p3.gd` 新增 `t473_bucket_original_gear_with_tq_affix`、`t473_4535_affix_capped_all_pools`、`t473_nine_off_not_escaped_by_affix`，覆盖 `4535 苍琉幻生灭`、`4285 双鱼念气瓶`、`4075 三环剑`、`4115 苍苍白骨` 及符文之语／成长装／七印／奖励装，实测四池全部进 `"equip"` 触发 `nineCap` 且天启词条自身增量照常生效。
2. **秘籍格格数按天启篇运行时角色档位取，三笠/绿司机/维利为 3/4/4，专项断言**：通过。`XTianqiSecrets.tier_of`／`limit` 与 `XTianqiLedger.secret_slots` 在天启篇下改读 `XTianqiSkills.tier_of(a, true)`；`xiyou_tianqi_secrets.gd` 的 `t473_secrets_limit_mikasa_green_willy` 与 `xiyou_tianqi_ledger_p3.gd` 的 `t473_ledger_secret_slots_tq_tier` 均断言 95/2/22/3 为 3/4/4/6 格及满格文案「超强者最多装备 3 本秘籍」。
3. **西游档零改动（`XTianqi.active` 守卫），老存档已装多出的书走 T446 既有超量封印逻辑不丢书**：通过。`XTianqiSecrets.tier_of` 与 `XTianqiLedger.secret_slots` 均以 `XTianqi.active(s)` 守卫，西游档下 95/2/22 仍照 `XTier` 返回 4/6/6 且不拦学书不写 `flags.tianqi`；`t473_legacy_overflow_95_2_22_no_loss` 实测模拟旧上限 4/6/6 本在 `XState.current = null` 读档经 `XTianqiSave.after_load` 迁移，三笠/绿司机/维利生效格自动收敛至 3/4/4、已封 1/2/2、`skill_ids` 全保不丢书、首次授予免费自选且二次读档幂等。
4. **云端选测全绿，交付自检 0**：通过（见下节测试记录）。

## 测试

- 本机专项（前台单跑，`--audio-driver Dummy`）：
  - `xiyou_tianqi_ledger.tscn`：83/83 通过
  - `xiyou_tianqi_ledger_p3.tscn`：44/44 通过（含 T473 新增 4 条断言）
  - `xiyou_tianqi_secrets.tscn`：89/89 通过（含 T473 新增 3 条断言）
  - `xiyou_tianqi_gongfa_shop.tscn`：42/42 通过
  - `xiyou_tianqi_nine_off.tscn`：19/19 通过
  - `xiyou_tianqi_general_books_b2.tscn`：46/46 通过
  - `xiyou_tianqi_live_sample.tscn`：32/32 通过
- 语法检查：`python3 03_再刷重制_Godot/07_开发环境/语法检查.py` 通过（1212 个 `.gd`，0 问题）
- 发行空壳：`python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check` 退出码 0（82 个脚本，812 个函数都有）
- 工具回归：`python3 03_再刷重制_Godot/07_开发环境/工具回归.py` 24/24 全部通过
- 云端选测：通过。提交 `6269c33770`（`ci/luiluu/t473`），基准 `4a321e5b71fabcb07709378f6476a7cde818b6d9`，22 个场景、5 片，最长一片 3.1 分钟，`gh run watch 45491593025 --exit-status` 等完结论 `success`。运行页：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45491593025
- 截图：本单未生成截图（纯底层分桶与档位计算修复，无新页面或排版改动）。

## 本分支提交

- `6269c3377` T473：修天启篇两处本体漏口——原版装 tianqi_affixes／alien.tq 不逃逸九线封顶＋秘籍格改读天启档位
- 本交付单提交
