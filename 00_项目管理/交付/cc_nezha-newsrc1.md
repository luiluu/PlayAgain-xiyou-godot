# 交付：cc/nezha-newsrc1（换源追平：35 个场景夹具重出）

- 车道／工作者：工具／哪吒（cc）
- 状态：交回集成分支 `cc/newsrc-switch`（不合 main，不标可合并；由总装 merge 进集成分支）
- 依据：`cc_newsrc-switch.md` 表「一」第一行 35 个场景（只挂 `source`）。

## 做了什么

- 工作树从 `cc/newsrc-switch`（cc69f998）切；`generated/` 用集成分支工作树里已同步好的新源产物（manifest `releaseVersion` v0.62.12），没在本树重跑同步。
- 28 个探针用 `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw` 重跑（全部退出 0），产物照原样拷成 28 个 `tests/fixtures/*_oracle.json`（键与旧夹具完全相同，`sourceIdentity` 变成 v0.62.12）。没改游戏代码、没改测试。
- 云端选测（运行 42193657527，提交 c9bbbb5c，基准 cc69f998，29 个场景）：**21 个通过，8 个有真实数值变化**，另 6 个夹具库里没有能重出它们的探针（见下）。

## 一、重出后全过（21 个，原来只挂 source）

airship_state、airship_view、battle_common_events、battle_start_event、boss_lifecycle、boss_output、boss_output_context、boss_react、boss_sequence、boss_state_origin、casino_batch、designation、enemy_warehouse、hit_warehouse、honghuang_curse_battle、item_bag、start_state_walk、state_merge_context、state_operation、target_eval、xuan_bind

## 二、重出后数值有变（8 个，归车道）

| 场景 | 通过／总数 | 变了什么（新源实测 vs Godot） | 初判 | 建议车道 |
|---|---|---|---|---|
| power_books | 6057/6136 | 各书用例的技能表都多一个 10455：新源角色开局就会 10455，Godot 没有（如 `book.1654.before.skills` `[]` → `[10455]`） | 同一根因：新源职业／开局技能多了 10455，Godot 角色初始化或学习表没跟上 | C 规则 |
| power_books_boundary | 55082/55682 | 同上，600 处都是技能表多 10455 | 同上 | C 规则 |
| power_books_menu | 1053/1068 | 同上（`item.skills` 多 10455） | 同上 | C 规则 |
| book_capacity | 920/924 | 同上（`power.class-full` 四处技能表多 10455） | 同上 | C 规则 |
| passive_content | 12 处失败 | 被动书 1652、2237 的伤害约高 3.75%（如 6214.67 → 6447.72、10564.95 → 10961.13），full／low／repeat 三组都一样 | 新源这两本书的被动倍率或伤害链改了；Godot 照旧值 | C 规则 |
| xuan_auto | 4544/4556 | 璇的力壁护盾值变了（如 124057 → 124372、210792 → 210840），`dinggui_seq` 多一层护盾，mist 第 5～7 步命中队友的结果跟着变 | 新源护盾计算（可能与成长乘区 growth 同源，见 rules 那 65 片） | C 规则 |
| battle_gaps | 1041/1043 | 新源新增技能 10462 的百分比 MP 消耗用例 5 个（cost.base／bigMp／mcr／penalty／reduce），测试里写死的个数对不上：`percent_skills` 44、`counts` cost 222 | 夹具多了用例，测试的计数断言要跟着改；10462 本身 Godot 是否算对要看那 5 个用例（本轮这 5 个没挂） | C 规则 |
| pushstate | 90/91 | `rec.6706.enemy`：旧源对敌人上状态 1561（1 回合），新源不上了 | 新源 RecPushState 对 6706 的处理改了 | C 规则 |

## 三、库里没有能重出的探针（6 个，仍挂 source）

| 场景 | 夹具 | 情况 | 建议 |
|---|---|---|---|
| random_streams | `boss_rng_oracle.json` | 夹具是 Codex 手搭的原生量具测的（scope：Boss 变身／回复时状态时长的随机次数），仓库与历史里都没有产它的探针 | 工具车道补写探针，或请沙僧按原量具重测 |
| character_help_cost | `character_help_cost_oracle.json` | 同上（帮助卡实际 MP／TP 消耗） | 同上 |
| death_admission | `death_admission_oracle.json` | 同上（HP0 阵亡准入） | 同上 |
| recover_permanent | `recover_permanent_review.json` | 同上（clearStates／recoverAll 保留 Permanent686） | 同上 |
| book_capacity_ui | `book_capacity_ui_oracle.json` | 界面原版参照（pages＋sourceFingerprints），仓库里只有 Godot 截图脚本，没有原版取样工具 | 界面车道（B）按原版重取 |
| module_hooks | `module_equipment_view.json`；`generated/oracle/module_hooks.json` | 前者记的是 cat_probe 4ea173d 的 `stats.sword671` 行，要按那时的格式从 cat_probe 产物里摘；后者是同步产物，本地基线里另挂 `oracle.native_registry`（新源钩子注册表第 10／20 项不是 cat-sword／orb-sets 了） | 摘 view 归工具车道；注册表变化归 C 规则 |

## 可优化（流程／工具／效率）

- 建议（工具车道）：上面 5 个手搭量具的夹具没有探针，换源时没法重出。以后新夹具要求提交产它的探针（`检查.sh` 可以查：带 `sourceIdentity` 的夹具必须能在 `mv_oracle/*_probe.cjs` 里找到文件名）。
- 建议：35 个夹具哪个探针产的，现在只能靠文件名猜（`battle_common_event_probe` 写 `battle_common_events.json`、`book_capacity` 一个探针两份夹具等）。可以在探针头注释统一写「→ tests/fixtures/X」，或加一张对照表。
- 优化登记草稿：无

## 验证

- 本机：换源产物下先跑 35 个场景的基线（都只挂 source，module_hooks 另挂 `oracle.native_registry`，与云端 42178820127 一致）；本机重跑因测试槽被占，排队 30 分钟没动，停掉改云端。
- 云端：运行 42193657527，结果见上。
- 没改游戏代码、没跑同步、没动 main。

## 本分支提交

- 见 git log
