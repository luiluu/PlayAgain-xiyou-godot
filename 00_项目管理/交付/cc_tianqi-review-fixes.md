# 交付：cc/tianqi-review-fixes

- 车道／工作者：C 规则·机制／cc（Orca worker，Opus＋medium）
- 状态：可合并

依据：私密设计仓《天启篇_内容与设计全面评审_v0.1》（小A，基线 `2f11c424e`）第二节第 1、2、5、6、7、8、9 条。第 3、4 条按派单不做，只写现状；第三、四节的设计取舍不碰。

## 核实

| 条目 | 结论 | 证据 | 处理 |
| --- | --- | --- | --- |
| 1 破产一剑减防无效（P0） | 属实（协调初判的「skill 没有 magical 键」不成立：`_skill(..., true)` 带 `magical: true`） | `tianqi_horsemen.gd` `_famine_perform` 的破产一剑按法术取 `u.mat`，`_strike` 读 `t.mdf`；`actor_param` 的破产只在 `i == 3`（物防）。专项开关关着时 `review1_bankrupt_mark_useless_off`：挂不挂破产伤害一样 | 修：O-待定-1 `XTianqiHorsemen.BANKRUPT_MDF`，破产同时降法防。行动末尾清标记符合设计稿「先挂破产再重击」，不改 |
| 2 同回合脏缓存 | 部分属实 | `cached_param` 不看 `param_dirty` 是照 krz 原版的有意设计（`battler.gd` 注释「当场读取仍旧」），原版内容的行为不能动，所以不改 `battler.gd`。红宝石：`review2_red_stale_atk_off` 复现，加攻后同一行动的追加普攻读旧攻。战狂化形：误报，伤害结算末尾的 `refresh_resources` 已让缓存格变冷，`review2_berserk_atk_after_hit` 不加修也过 | 修：O-待定-2 `XTianqiHorsemen.FRESH_PARAM`，四骑士行动里加属性（宝石红／蓝／圣水、骑士队长、百亿仙剑全属性）后当场 `param_refresh()`，与 `alien_battle` 的现成做法一样，不碰 O-348 只读窗口与整批加减状态。战狂只钉一条回归测试 |
| 3 七印 drop_mult=1.0 | 属实（未做项） | `tianqi_qiyin.gd:497` 还是 `return 1.0` | 不做：等 Kyo 定掉率 |
| 4 默印技能号 0、天卷零代价 | 属实 | `tianqi_qiyin_effects.gd:29` `silence_skill_id: 0`；`seven_seal_scroll` 的代价只是说明，没有判定 | 不做：牵涉神器设计 |
| 5 法宝预览漏判 | 部分属实 | 预览漏了「商店买的不能喂」，属实；「同一件装备」不算漏：法宝本身 `is_magic` 已挡在「不能喂」。预览目前只有测试在调，物品页菜单用的 `eligible` 走的是真判断，玩家暂时看不到偏差 | 修：预览直接调 `reason()`，删掉另写的 `_preview_reason`（副本法宝的 `is_same` 恒假、等级和上限照读副本，口径一致） |
| 6 异化词条文案写死化形 | 属实 | `affix_view` 拷的是 `new_affixes` 静态文案（化形的数） | 修：O-待定-3 `XTianqiAlienGear.TIER_TEXT`，按装备真实级取 `effects` 的数出收益文案（工坊详情与重抽二选一卡片都传级）。`again.every` 第 2、3 档都是 3：只报告，见「需要用户决定」 |
| 7 装备详情缓存键缺说明 | 属实 | `gear_detail.gd` `set_item` 的键没有 `description` | 修：键里加 `description` |
| 8 mark_views／采样顺序 | 前半属实，后半误报 | 七印效果、词条再释放、技能追加释放三处 `end_action` 的命中没有 `views`（主路径 `_invoke` 有 `mark_views`）：`review8_recast_hits_have_views` 不修时 `[true,false]`。`tianqi_affix_battle.gd:524` 的 action 帧在 apply 前取快照，和主路径 `battle_logic.gd` 行动帧的取法一样（行动帧取出手前，命中帧另取） | 修：三个模块里每次 `apply` 之后当场 `mark_views`（见「核查返修」，原来在 `battle_logic.gd` 外层整批包的写法已撤）；采样顺序不改 |
| 9 零星 | 部分处理 | 两处陈旧注释属实：已改（`tianqi_horsemen.gd` 头注释、`tianqi_skills.gd` 头注释）。`xiyou_fabao_rework` 偶发属实：`XGear.create` 掷词缀会抬品质，`_bag` 改成固定模板品质。`rewards.json` 净印·清心 `[2,2,1]`、`boss_troops: []`、`gojo.gd` 进阶费用 `[10w,50w,10w,10w]`：属实，只报告。替身的钥匙串完整版 `crit_mult: 0.0`：是设计的代价（文案「暴击率 ×0」「魔塔是没有暴击的」），不是缺陷 | 见「需要用户决定」 |

## 验证

专项（本机，全部通过）：

| 场景 | 新断言 | 断言数 |
| --- | --- | --- |
| `xiyou_tianqi_horsemen_battle` | `review1_bankrupt_hits_mdf_on`、`review1_bankrupt_mark_useless_off`、`review1_bankrupt_cleared_on/off`、`review2_red_fresh_atk_on`、`review2_red_stale_atk_off`（6 条） | 106/106 |
| `xiyou_tianqi_war` | `review2_berserk_hit`、`review2_berserk_atk_after_hit`（2 条） | 99/99 |
| `xiyou_tianqi_drop` | `review5_preview_skips_bought`、`review5_preview_keeps_own`（2 条） | 76/76 |
| `xiyou_fabao_rework` | 测例固定品质（无新断言） | 86/86 |
| `xiyou_tianqi_alien_gear` | `review6_tier_dying`、`review6_tier_again`、`review6_tier_thrift_venom`、`review6_huaxing_same_*`（4 条）、`review6_o-off`（共 8 条） | 57/57 |
| `xiyou_tianqi_affix_battle` | `review8_recast_hits_have_views`（1 条） | 64/64 |
| `xiyou_gear_detail` | `review7_description_rerender`（1 条） | 56/56 |

反向验证（手动把被测文件换回修之前跑）：第 5 条 `review5_preview_skips_bought` 失败、第 8 条 `review8_recast_hits_have_views` 失败；第 1、2 条的「开关关」断言本身就是复现。

选测（返修前）：`选测.py main --list` 因改了 `battle_logic.gd` 选出 284 个场景（战斗核心全套）；返修后 `battle_logic.gd` 已和 main 一样，见「核查返修」。这次 `battle_logic.gd` 只给天启篇三处 `end_action` 的返回值包 `mark_views`，不在天启篇战斗里时这三处返回空数组，`mark_views` 什么也不做，所以没跑 `xiyou_rules*`、`xiyou_smart_ai*`、事件对照这几大类；跑了全部 31 个 `xiyou_tianqi_*`（773 秒，全部通过），以及 `xiyou_determinism`、`xiyou_param_cache`、`xiyou_rift_alien`、`xiyou_gojo`、`xiyou_gear_detail`、`xiyou_alien_workshop`、`xiyou_alien_config`、`xiyou_fabao_rework`、`xiyou_bulk_pills`。没改 `battler.gd`／原版缓存语义，所以没加跑 `--oracle`。另跑 `语法检查.py`、`工具回归.py`，都通过。

## 核查返修

gpt 甲档核查结论「修完再合」，一项 P2：

- 问题：`battle_logic.gd` 把三处 `end_action`（七印效果、词条再释放、技能追加释放）的返回值整批包 `mark_views`，所有命中都是整批打完后才取快照；多段打同一目标（攒段横扫 `bonus_hits`、技能追加后 then 再打同一目标）每段都显示最终血量，首段就直接到底，中间的 action 帧快照又可能把血条抬回去。原来的断言只查有没有 `views`，抓不到时点不对。
- 修法：撤掉 `battle_logic.gd` 外层的三处包装（这个文件现在和 main 一样）；改成在三个模块里每次 `logic.apply` 之后当场 `logic.mark_views([r])`：`tianqi_qiyin_effects.gd` `_derived`、`tianqi_affix_battle.gd` 再释放、`tianqi_skills.gd` 追加释放与 then。只动天启篇路径。
- 测试：`xiyou_tianqi_qiyin_effects` 新增 `_burst_views`：止戈攒段横扫整次行动（`lg.act`）打同一敌人 6 段，断言 `review8_burst_views_each_hit`（逐段快照 HP 严格递减）、`review8_burst_first_not_final`（首段快照 HP 大于最终 HP），共 2 条，50/50；`xiyou_tianqi_affix_battle` 64/64（`review8_recast_hits_have_views` 保留）。反向验证：换回返修前的四个文件，`review8_burst_views_each_hit` 失败，快照是 `[9731, 8386, 8386, 8386, 8386, 8386]`。
- 选测：`battle_logic.gd` 已和 main 一样，`选测.py` 选 43 个场景，云端选测全部通过（提交 470ccb476，1 片 7.4 分钟）
- 提交：470ccb476

## 变更记录草稿

## 2026-11-14 【cc·天启篇评审核实·未经审查】天启篇评审 v0.1 第二节核实与修复（dev.待定）

- 依据小A《天启篇_内容与设计全面评审_v0.1》第二节逐条核实（第 1、2、5～9 条），核实表见交付单。
- 饥荒骑士「仙法：破产一剑」：这一击是法术、打法防，破产标记原来只降物防，等于没有；改成同时降法防（O-待定-1，`XTianqiHorsemen.BANKRUPT_MDF`）。
- 死亡骑士宝石加攻后，同一行动的追加普攻读到加攻前的攻击（敌人能力值 krz 缓存）；四骑士行动里加属性后当场刷新缓存（O-待定-2，`XTianqiHorsemen.FRESH_PARAM`）。战狂化形「受伤加攻」核实为误报，钉了回归测试。
- 法宝喂养预览改走实喂的同一套判断（商店买的不能喂）；异化新词条收益文案按装备真实级出（O-待定-3）；装备详情缓存键加说明；七印效果、词条再释放、技能追加释放的命中逐段补画面快照（每次 apply 后当场取）；两处陈旧注释；`xiyou_fabao_rework` 测例固定品质消偶发。
- 玩家可见：饥荒骑士破产一剑伤害变高（照设计）；死亡骑士宝石后的追加普攻按新攻击；异化工坊新词条收益按装备级显示；融印、洗词条后装备详情马上换说明；天启篇追加释放等的血条跟着跳。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `core/tianqi_horsemen.gd` `XTianqiHorsemen.BANKRUPT_MDF`、`actor_param` | （天启篇新内容）破产标记只降物防，破产一剑打法防，标记不起作用 | 破产同时降法防 | 评审 v0.1 第 1 条；设计稿「先挂破产再重击」 | `BANKRUPT_MDF` 设 false | cc | 保留 |
| O-待定-2 | `core/tianqi_horsemen.gd` `XTianqiHorsemen.FRESH_PARAM`、`fresh_param` | （天启篇新内容）骑士加属性后等回合边界才刷新敌人能力值缓存 | 加属性后当场 `param_refresh()`：作用范围是该骑士的全部八格能力值缓存和特性列表（effect_lists），所以同一行动里其它属性、状态特性也读新值，不只是加的那一项 | 评审 v0.1 第 2 条：宝石后的追加普攻读旧攻 | `FRESH_PARAM` 设 false | cc | 保留 |
| O-待定-3 | `core/tianqi_alien_gear.gd` `XTianqiAlienGear.TIER_TEXT`、`tier_benefit`；`ui/alien_workshop.gd` | （天启篇新内容）新词条收益文案一律是化形档的数 | 按装备真实级取 effects 出文案 | 评审 v0.1 第 6 条 | `TIER_TEXT` 设 false | cc | 保留 |

## 交接板

- 下一步：第 3 条（七印掉落倍率）、第 4 条（默印技能号、天卷代价）等 Kyo 定后再派。
- 用户试玩说明：饥荒骑士第二阶段起的破产一剑会明显更疼（破产降防终于生效）；死亡骑士的宝石后追加普攻更疼。
- 需要用户决定：
  1. 破产一剑（第 1 条）：现在是法术（威力取法攻、打法防），破产标记本车道改成同时降物防和法防。另一种做法是把破产一剑改成物理（取攻击、打物防），破产照旧只降物防。两种伤害量级不同，请定。默认按前者（O-待定-1 开着）。
  2. 异化新词条「再动」`again.every` 是 `[5, 3, 3, 2]`：蚀骨和化形都是每 3 回合，升到化形这项没有提升。要不要改（如 `[5, 4, 3, 2]`），请定数。
  3. 天启篇奖励表 `rewards.json`：瘟疫印「净印·清心」`values: [2, 2, 1]`，T1 和 T2 同值，是不是有意？`boss_troops: []` 还空着（31～33 层旧守层者的异化核等终焉异化做好再接）。
  4. 五条悟进阶费用 `[10 万, 50 万, 10 万, 10 万]`：第 2 档 50 万后又回到 10 万，像是写错（`gojo.gd` 进阶表），请定。
  5. 第 3 条七印 `drop_mult` 仍是 1.0（掉落词条没接进七印掉落）；第 4 条默印 5 件套技能号 0、七印天卷没有实扣代价、非七印战斗都生效（含首领）。按派单不做，等定。

## 可优化（流程／工具／效率）

- 建议：`选测.py` 对 `battle_logic.gd` 一律选战斗核心全套（284 个）。像这次只在天启篇分支里加一层包装的改动，可以考虑按改动行所在的「天启篇挂钩」识别、只选天启篇专项（预计省一轮云端全套；归工具车道）。

## 本分支提交

- 280b54e61 破产一剑降法防、骑士加属性当场刷新缓存，战狂化形核实为误报并钉测试
- 02034680e 法宝喂养预览与实喂同一套判断、法宝测例固定品质
- 301a756ff 异化新词条收益按真实级出文案、天启篇行动末尾追加命中补画面快照
- 18af3dca6 装备详情缓存键加说明、两处陈旧注释
- 236b91773 交付单、优化号占位分号
- 470ccb476 核查返修：追加命中逐段取画面快照
