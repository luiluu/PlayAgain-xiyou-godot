# 交付：luiluu/t547-abyss-gear-random

- 车道／工作者：T547 西游档深渊装备随机词条／cc（Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-26 【cc·T547·未经审查】西游档深渊商人装备也掷随机词条（dev.待定）

- 依据 Kyo 11-26 15:35「西游档的深渊武器不随机词条，我们改一下深渊的装备也会随机词条」。开工基准 `dd15d65bb`；先查重 T410（至臻装备补候选，走掉落入口，没碰商人）。
- 查因：两条「深渊装备」来路结论不同，问协调后定做 A。
  - A 深渊／不朽商人买的装备：`core/abyss_merchant.gd` `generate` 照原版 v0.30 `M.generate`，把底装备自带的词条表整个删掉、换成「买的那条特效 100%」一行，所以商人货除了买的那条永远没有别的随机词条（同一件防具普通掉落有多行随机词条，商人版一行没有）。这是原版写法，不是标记或表漏了。
  - B 深渊首领掉的武器（被封印者等掉的 65／28 深渊段武器）：跟其它同品质武器规则完全一样，没被排除——西游档武器底子普遍只有 1 行、3% 出一条 Mod 特效（防具才是多行十几%）。体感「不出词条」是武器本身概率低。本卡不改（要改是改概率，协调已另问 Kyo）。
- 改法（O-待定-1，`XAbyssMerchant.KEEP_BASE_AFFIXES`，默认开）：西游档商人买的装备保留底装备自带的词条行与词条表，照普通掉落掷（同一张表、同样的概率与行数）；买的那条特效先合进去、照旧必出、排在 affixIds 第一位，`_codexExtraAffix29` 照旧只记买的那条。随机数照旧用本轮种子。`XGear.roll_item` 加可选参数 `forced_affixes`（掷随机行前先合入、不耗随机数），其它调用处不传、行为不变。
- 返修（核查 P1-1）：买的特效（Mod／神话／混沌神话）先合入后，底装备低品质随机行合并时会覆写 `meta.quality`／`ici`，高档货掉档丢星。`XGear.roll_item` 在 `forced_affixes` 非空时记合入词条里的最高 quality／ici，合完若被拉低就恢复成最高档（买 Mod 而随机出神话时保住神话，不被 Mod 拉低）；普通掉落不传 forced，照原版后合覆写，不套保护。P3-1：forced 的 kind 写入 affixIds 时统一 `str()`。
- 天启篇：天启篇商人走 `XTianqiMerchant`（不经 `generate`）；`generate` 里另判 `XTianqi.active` 走原支，天启篇档不受影响。
- 旧存档：Kyo 定已有存档里的旧深渊装备不动，只管以后新买的，不做读档补词条。
- 玩家可见：西游档在深渊／不朽商人买到的装备，除了指定的那条特效外，还会像普通掉落一样有机会带上随机词条；买的档位品质与星级不会因此变低。
- 验证（返修后）：本机专项 xiyou_merchant29 140/140、xiyou_affix_absorb 45/45、xiyou_tianqi_affix_roll 30/30、xiyou_heartsteel 676/676；关掉品质保护时 6 条新断言失败（确认测得出降档）。返修前：本机专项 xiyou_merchant29 112/112（新增 9 项）、xiyou_affix_absorb 45/45、xiyou_treasure_map 35/35、xiyou_tianqi_affix_roll 30/30、xiyou_tianqi_random 75/75、xiyou_heartsteel 676/676、xiyou_affix_rate 371/371；云端选测 186 个场景通过。

## 交接板

- 下一步：无（B 首领武器词条概率要不要调，协调已另问 Kyo，要调另开卡给数）。
- 用户试玩说明：西游档在深渊商人抽一件装备，看除了指定特效外有没有带别的随机词条（低品质底子概率低，多抽几次）。
- 需要用户决定：无（旧装备处理 Kyo 已定不动）。

## 进度账

- 西游档现有规则调整，不涉进度。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/abyss_merchant.gd` `XAbyssMerchant.KEEP_BASE_AFFIXES` | 商人装备删掉底装备词条表，只留买的那条特效 | 西游档商人装备保留底装备随机词条行照普通掉落掷，买的那条照旧必出 | Kyo 11-26 要深渊装备也随机词条（T547） | `XAbyssMerchant.KEEP_BASE_AFFIXES = false` | cc（T547） | 保留 |

## 可优化（流程／工具／效率）

- 无。

## 动了的共用函数和开关

| 函数／开关 | 调用处粗数 | 逐处结论 |
| --- | --- | --- |
| `XGear.roll_item` | 7 行（`git grep -nE '[^[:alnum:]_]roll_item[[:space:]]*\(' -- '*.gd'`，含定义与注释） | 只加末尾可选参数 `forced_affixes := []`，空时循环不进、品质保护（`top`）也不启用，行为不变。传它的只有 `XAbyssMerchant.generate`（开关开、非天启篇）；`XGear.create`、`create_prestige_drop`、云裳订单、心钢测试都不传。 |
| `XAbyssMerchant.generate` | 2 处（`draw` 1 处生产调用、`tests/xiyou_merchant29.gd` 1 处） | 开关关或天启篇档：照旧换掉词条表，与原版对照 26 例一致（测试在关开关下跑原版段）。开关开：保留底装备词条表，买的那条用 forced 合入。扣点、次数、来源键、登记入包照旧。 |
| `XAffixAbsorb.extra_affixes`（读 `_codexExtraAffix29`） | 未改 | 商人货能被吸取的仍只有买的那条；底装备掷出的随机词条不可从商人货上吸取（原版对商人货就只认这条，保持）。 |

## 验证

- 本机：见变更记录草稿。xiyou_merchant29 新增 `keep.*`：同一份随机数下，商人装备除买的那条外的词条与同底装备普通生成（`XGear.create`）逐件相同（防具、武器各 400 次）；买的那条排第一、额外特效键只记它；回退支 400 次额外词条 0 条；天启篇档 50 次额外词条 0 条。本机统计：13 层深渊商人池首件防具底子 400 抽带出 23 条随机词条、首件武器底子 11 条（低品质底子行概率低；高品质底子照各自的行）。
- 返修 P2-1：`keep.*` 改为三档（mod／mythic／chaos）× 防具／武器各 400 次，武器 `rolls_some` 改成真判断 `extra > 0`；新增 `grade_kept`（成品 quality＝买的与掷出的最高品质、不低于回退支、星级不少于回退支）、`lower_exercised`（神话／混沌档确有低品质随机行，保护被走到）、`mod_rolls_higher_kept`（买 Mod 掷出神话再掷低品质，保住神话的 quality／ici）、`plain_unprotected`（不传 forced 的普通掉落照原版被后合行覆写）。本机统计：防具每档 400 抽 23 条随机词条，武器 11 条；神话／混沌档全部随机行都低于所买品质，全部保住。
- 云端选测（返修）：通过，提交 16a5f8047 选测 185 个场景、6 片（基准 cc1cea0dc），https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45872554790 （`gh run watch` 退出码 0）
- 云端选测（返修前）：通过，提交 c27ddff12 选测 186 个场景、6 片（基准 dd15d65bb），https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45841902903 （`gh run watch` 退出码 0）
- 回退开关覆盖：`KEEP_BASE_AFFIXES` 不在缺口里。
- 发行空壳.py check：通过（86 个脚本）。
- 截图：无（不改界面；商人页「装备本体和具体特效随机」文字仍准确，不改字）。

## 玩家更新说明（小A 已审，用建议版）

- 在深渊商人、不朽商人处买到的装备，除了所选档位的特效外，现在也会像普通掉落的装备一样，有机会额外带上随机词条。此前已经买到的装备保持原样。（小A 文字审建议版）

## 本分支提交

- 16a5f8047 T547 返修：商人买的特效品质不被低品质随机行降档＋专项三档品质断言
- c27ddff12 T547 西游档深渊商人装备保留底装备随机词条（KEEP_BASE_AFFIXES）＋专项
