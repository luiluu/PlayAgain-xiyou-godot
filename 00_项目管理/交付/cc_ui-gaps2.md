# 交付：cc/ui-gaps2

- 车道／工作者：B 界面／界面二期 FD2（cc）
- 状态：可合并

## 盘点（上一期交接线索逐条对 v0.62.12 原版核实）

| 项 | 结论 | 依据 |
| --- | --- | --- |
| v0.56 修行面板两页简化（installNativeGuidanceRuntime G.panelRows／G.detailRows） | 已做，不用动 | `ui/status_page.gd` `PAGE_NAMES_V062` 第 4 页「修行」、第 5 页「修行·详细」，`core/guide.gd` 第 137 行起（XGuide.PANEL_V062）；「战力构成」五乘区按 O-044／O-050 不移植 |
| v0.62.06／08 进阶界面尺寸 | 已做，不用动 | `ui/actor_advanced.gd` 第 154 行起 `ADV_V108`（Codex_MiraRavenMultiFrame v1.08，流萤 128px 格按图鉴尺寸缩小） |
| v0.62.06／08 改版向导加流萤三页 | 已做（走转换），不用动 | 是 Map004 EV71「改版向导」的事件文字；原版与 `generated/maps/Map004.json` EV71 里「流萤」都出现 7 次、文字一致 |
| 至臻闪光补漏（直接 append 新实例的路径） | **原版这些路径本来就不闪，重制一致，不用补** | 见下 |

### 至臻闪光：逐条对原版

原版 installTreasureBatchRuntime 只包了两处：`gainIndependentItem`（且要 `isNewItemValid(item)`，即传进来的是数据库底子、由它新建实例）和非独立装备的 `gainItem`。重制对应 `XState.gain_gear`，已接。重制里其余直接 `s.gear.append` 新实例的路径，原版都不经这两个函数：

- 深渊商人 `core/abyss_merchant.gd:242`：原版 installAbyssMerchantRuntime 第 60～70 行 `D.makeItem(blue)` 后 `$gameParty.registerNewItem(created,created)`，不经 gainItem → 原版买到至臻装备不闪。
- 云裳 `yunshang_orders.gd` grant_spec：原版 grantSpec 直接 `$dataArmors.push`＋`$gameParty._armors[n.id]=1`。
- 魔冠 `demon_crown.gd` _grant：原版 grantSpec 同上（7940 也不是至臻）。
- 异化奖励 `alien_battle.gd` grant：原版 A.grant 走 `registerNewItem(底子, 实例)`。
- 猫的练习剑 `cat.gd`（武器 2）：不是至臻。
- 其余 append（卸装回包、仓库取出、角色离队退装备、异化失效放回等）都是已有实例回背包，原版 gainItem(实例) 也不触发（`isNewItemValid` 为假）。

所以上一期交接里「深渊商人等直接 append 实例的路径没接」那句可以删：照原版就是不闪。没有改代码。

## 变更记录草稿

## 2026-11-07 【cc·界面·未经审查】界面二期线索核实：修行两页、流萤界面已做，至臻闪光其余路径原版本就不闪（dev.待定）

- 上一期交接三条线索逐条对 v0.62.12 原版核过，都不用改代码：修行面板两页（`ui/status_page.gd` PAGE_NAMES_V062）、流萤进阶大图（`ui/actor_advanced.gd` ADV_V108）、改版向导流萤页（Map004 EV71，走转换）都已在 main。
- 至臻闪光：原版只包 gainIndependentItem（传数据库底子新建实例时）和非独立装备的 gainItem；深渊商人（makeItem 后 registerNewItem）、云裳与魔冠 grantSpec、异化 A.grant 都不经这两个函数，原版这些路径本来不闪，重制一致。交接板「深渊商人等直接 append 实例的路径没接」那条删掉。

## 交接板

- 下一步：删掉交接板里「至臻闪光……深渊商人等直接 append 实例的路径没接（量小，需要时补）」这条（核过，原版这些路径不闪，重制一致）；修行两页、流萤进阶大图、改版向导流萤页都已在 main，界面缺口线索本期清空，下一批界面缺口要重新盘点（ui5 千万级血量拖尾仍等 Kyo）。
- 用户试玩说明：无（本期没有代码改动）
- 需要用户决定：无

## 进度账

- 界面页面：不变（本期只核实）

## 可优化（流程／工具／效率）

- 建议：交接里写「没接／没做」前先对原版查一下那条路径是不是真的经过被包的函数（本期三条线索都已做或原版本来如此，派单前 rg＋看原版十分钟就能省一条车道）。归总装派单习惯，无需车道。

## 验证

- 只改了交付单，没有代码改动，不跑选测。

## 本分支提交

- 本交付单
