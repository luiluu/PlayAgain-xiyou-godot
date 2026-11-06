# 交付：cc/nezha-newsrc2（换源追平：6 个重出不了的夹具补量具）

- 车道／工作者：工具／哪吒（cc）
- 状态：交回集成分支 `cc/newsrc-switch`（不合 main，不标可合并；由总装 merge 进集成分支）
- 依据：`cc_nezha-newsrc1.md`「三」。从 `cc/newsrc-switch` 020aab89 切，中途合了 31d0628a。

## 做了什么

每个都先在旧源（v0.28）上跑，确认与现夹具一致，再用 `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw` 重出。没改游戏代码、没改测试。

| 场景 | 夹具 | 新补的工具 | 旧源上验 | 新源重出后 |
|---|---|---|---|---|
| recover_permanent | `recover_permanent_review.json` | `mv_oracle/recover_permanent_probe.cjs` | 与现夹具整份相同 | 数值无变化 |
| death_admission | `death_admission_oracle.json` | `mv_oracle/death_admission_probe.cjs`（夹具用例的错误键是 `issues`，不走 host.finish，照原格式自己写） | 整份相同 | 数值无变化 |
| character_help_cost | `character_help_cost_oracle.json` | `mv_oracle/character_help_cost_probe.cjs`（`CodexDisplay.characterHelpView` 的「消耗」行＋`skillMpCost`／`skillTpCost`＋被动缓存 consumeReduce） | 整份相同 | 数值无变化 |
| random_streams | `boss_rng_oracle.json` | `mv_oracle/boss_rng_probe.cjs`（照 boss_lifecycle transform.0.2：敌群 1 第 1 个敌人第 2 回合变身 6 号，包一层 Math.random 计数） | 整份相同 | 数值无变化 |
| module_hooks | `module_equipment_view.json` | `mv_oracle/module_equipment_view_probe.cjs`：先跑 `cat_probe.cjs`，再从 `.sandbox/cat.json` 的 `stats.sword671` 摘出同格式 | 除 `provenance`（提交号、cat.json 的 SHA）外相同 | 数值无变化 |
| book_capacity_ui | `book_capacity_ui_oracle.json` | 原版取样工具其实在：`ui_reference/review_book_capacity.cjs`（隔离 Chrome 两页），改成认 `XIYOU_APP`；新加 `ui_reference/book_capacity_ui_fixture.cjs` 把两页拼上来源身份和 33 个文件指纹 | 除计时抖动外相同（Toast 淡出中途的 opacity、trace 的帧号 135／136、time），测试不比这几项 | 数值无变化（同样只差 opacity） |

用法写在各脚本头注释里；都只写 `.sandbox/`（或给定的输出目录），再拷成夹具，不接入全量同步。

## 云端

- 6 个里 5 个全过：book_capacity_ui、character_help_cost、death_admission、random_streams、recover_permanent。module_hooks 只剩 `oracle.native_registry`（`view.same_source` 已过）：这一项读的是同步产物 `generated/oracle/module_hooks.json`，新源的钩子注册表第 10／20 项不再是 cat-sword／orb-sets，是真实变化，归 C 规则（newsrc1 已列）。

## 可优化（流程／工具／效率）

- 建议（工具车道）：`检查.sh` 加一项，带 `sourceIdentity` 的夹具要能对上一个产它的探针（文件名或探针头注释里的「拷成 tests/fixtures/X」），免得下次换源又有手搭的重出不了（newsrc1 已提）。
- 优化登记草稿：无

## 验证

- 旧源：6 个工具的产物与现夹具比对，结果见上表。
- 新源：6 个夹具重出，与旧夹具比只差来源身份（UI 那份另有 opacity 抖动）。
- 云端：运行 42196620540（提交 f96bbef2，基准 31d0628a，74 个场景；本分支动了 mv_oracle，选测连带选上 rules 65 片）。失败 4 个：module_hooks（只挂 `oracle.native_registry`，见上）；另 3 个 event_compare、rules10、status_power_panel 不是本分支的，集成分支的 189 个失败表里本来就有。

## 本分支提交

- 见 git log
