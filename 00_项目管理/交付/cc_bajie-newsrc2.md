# 交付：cc/bajie-newsrc2

- 车道／工作者：A 内容·楼层／八戒（cc，第十四批 CT）
- 状态：进行中（集成分支用，不合 main；做到一半按 40% 线交接，已完成部分可先由总装在集成分支树里 merge）
- 从 `cc/newsrc-switch`（43efc26a）切出；工作树 `.claude/worktrees/bajie-newsrc1`（沿用上一单的树，generated 是新源产物，`generated/oracle/event_states.json` 是新源 9665 个用例的结果）。

## 变更记录草稿

### 【cc·八戒·未经审查】换源追平续：新源空绿 19 例、showRoster 新写法、洪荒诅咒分档（跟到 v0.62.12）

- **新源新增空绿 19 例**（`事件空绿扫描.py --check` 现在过，96 例都写明了理由）：
  - 补预设 `#n2` 8 个真走到效果：ce9039、ce9030、m144e15p0、m45e10p0、ce9026（四个前置技能都要）、m45e10p1、ce1438（`random_seq` 0.12 抽到 25）、ce9023。一护（148）、麒麟（142）是超强者，默认难度 `$gameParty.addActor` 被 `CodexBossDifficulty` 拦下（「超强者仅限地狱及以上难度获取」），预设要带 `difficulty: 9`；`m213e2p0#w1_857` 同样补上。
  - 收基线并写进 `事件空绿走不到.json`：藏宝图 CE117、1381～1384（只调 `RunGetFun`，要站在宝藏坐标上，预设设不了站位）；CE9028、9029、9034（条件是敌人状态，只在战斗里）；m145e11p0、m43e23p1、m45e10p2（刷孔：失去再得到同一把武器，件数不变 delta 量不出，`#n2` 预设已让它走到）。上一单收进基线的 30 个商人第 2 页也补了理由。
- **`CodexBossDifficulty.showRoster` v0.44 写法**：大厅 EV41 六页改成裸调用 `CodexBossDifficulty.showRoster('strong'|'super');`（不再 `setWaitMode`），名单是 `CodexTier` 两档（`<KyoTier>` 原地重建，不另加小猫）。`MVScript` 认这种写法，名单取 `XState.tier_ids`；旧写法照旧。两条各在一个选项分支里、后面没有别的指令，当场显示与原版看到的一样。
- **`XState.tier_ids(tiers)`**：按角色备注第一个 `<KyoTier:…>` 取（同原版 `TAG.exec`），`tier_non_weak_ids` 改成调它。悟空的 XTier（`cc/wukong-newsrc5`）进来后两处都改成调 XTier。
- **洪荒诅咒分档**（v0.52 用户重排，只改分档与显示／倍率，不改诅咒效果）：`XHonghuang.TIER` 改成 static var，默认 `TIER_V052`，回退设回 `TIER_V028`。玩家可见（选项文字的档位与奖励倍率），O 号待总装分配。

## 进度（对照派单 CT）

- ① 19 个空绿：**做完**，`--check` 过。
- ② A 剩：
  - showRoster：**做完**（event_compare m4e41 六个基础页对上；带变体的四例只剩角色 1 被动 10455，是规则车道 actor_p0 同根）。
  - 洪荒诅咒：**做完**。分档跟上后在新源重跑 `honghuang_curse_probe.cjs`、`honghuang_reward_probe.cjs`，重出两份夹具（原来内容还是 v0.28 的，表里原归工具车道，本单改分档必须一起出，就顺手做了）；`xiyou_honghuang_curse` 两条写死的标签断言改成新分档。**honghuang_curse、honghuang_reward 两个场景现在全过**。
  - 未登记脚本（script_census）：天道注视、showRoster 已销；还剩剑心图鉴 `_kyoJianxinBookUnlocked`（CE2507、Map225 EV10、Map4 EV61）、`CodexGuide.injectChangelog`（Map4 EV71）、`CodexWhisper`（Map4 EV76，随大厅新事件）、`CodexLiuying.recruit`（CE9043，随流萤）、等级上限道具 `pluginCommand('maxlevel'…)` 三条、CE1370 追加行动（战斗里 `_actions.push`）、敌人 2027 按变量 1349 加属性那段。**没做**。
  - 挖宝运行时（common_scripts）、Map213 一护（floor_odds）、107／110 层商店、商店库存分组、大厅事件 74～76：**没做**，定性见 `cc_bajie-newsrc1.md` 的表。
  - event_compare 重出基线：**没做**（要等上面跟完）。
- 和悟空 XTier 对接：悟空还没交付，没对。

## 接续要点（给下一位）

- 工作树 `.claude/worktrees/bajie-newsrc1`（分支 `cc/bajie-newsrc2`）。generated 是新源产物；跑测试要 `--skip-generated-check`（本树 generated 跟主工作区不同是故意的）。补探针：`XIYOU_APP=/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/v0.62.12/app.nw python3 07_开发环境/补跑事件状态探针.py`（增量，几分钟）。
- event_compare 单跑几例：`./07_开发环境/godot --headless --path 01_Godot工程 res://tests/xiyou_event_compare.tscn -- --only=m4e41,ce1442`。
- 新源原版里 355 参数是字符串的两处（深渊商人、CE1439）原版无效果，重制照原版；商人页门控在 `MVEvent.merchant29_present()`。
- 下一步建议顺序：未登记脚本里的小项（剑心图鉴开关、injectChangelog、maxlevel 道具）→ 商店三项（107／110 层、库存分组）→ 挖宝运行时 → Map213 一护重写用例 → 大厅 74～76 → event_compare 重出基线。

## 交接板

- 下一步：见上「接续要点」。
- 用户试玩说明：无（集成分支）。
- 需要用户决定：无（商人一事总装已定）。

## 进度账

- 换源追平（A 领域）：空绿清零；28 个场景里 13 个已过（上一单），本单又对上大厅名单与洪荒诅咒选项。

## 可优化（流程／工具／效率）

- 建议：`event_state_probe` 的 `party` 预设遇到超强者会被拦下却不报错，只在空绿检查里才看出来；探针可以在加人失败时提示（工具车道）。

## 待交叉核查

- `mv_script.gd`（showRoster 新写法）、`xstate.gd`（`tier_ids`）、`honghuang.gd`（分档）、两份洪荒夹具、`xiyou_honghuang_curse.gd`、`event_presets.json`（11 个 `#n2`、`m213e2p0#w1_857`）、两份空绿登记。

## 验证

- `事件空绿扫描.py --check`：空绿 96 例均在基线内，理由 96 例齐。
- event_compare `--only=m4e41,ce1442`：13 例 8 对上，5 例只差角色 1 被动 10455。
- 本机新源复测：honghuang_curse 885/885、honghuang_reward 311/311、honghuang_curse_battle 344/344、opening_branches、script、dungeon 过；difficulty_actor（只差 10455）、floor_odds（只差 Map213）、weak_challenge（121/125，说明卡行）、script_census（剩上面列的未登记脚本）照旧挂，都在 189 表里。
- `语法检查.py` 0 问题。

## 本分支提交

- 见 `git log cc/newsrc-switch..cc/bajie-newsrc2`

### 【cc·八戒·未经审查】换源追平续二（本单后半，11-06 下午）：未登记脚本、v0.41 商店、挖宝、一护、大厅 74～77、对接 XTier

- **未登记脚本销 10 条**（script_census 只剩 `CodexLiuying.recruit()`，随流萤归扩角色）：
  - 剑心图鉴开关 `$gameSystem._kyoJianxinBookUnlocked`（存 `s.flags` 同名；147 在队或在角色仓库就开；脚本条件 `!!…` 进 `eval_expr` 的 `jianxin()`）。
  - 等级上限道具：CE1385 破限之志（不到 75 设 75，否则还道具 1069 并提示）；CE1685／9041 临时抬到 81、升一级、放回（`this._kyoMaxLevel` 记在本层解释器 meta）。
  - `CodexGuide.injectChangelog`：转换器新出 `db/PlayerChangelog.json`（`export_changelog`，照 `G.changelogEntries`：ContentVersion 合法时读到 releaseNumber，缺文件即停，空页跳过，新版在前）；解释器在本句后插入日志页，换新数组不改地图原列表。
  - 肉山 Map186 EV34：改 XDB 缓存里敌人 2027 能力值、状态 2781 第 12 条特性（原版改内存 `$dataEnemies`，不进存档、同次运行累加，照搬）。
  - `CodexWhisper`：`seen('键')` 条件与 `mark('键')`，记配置 `codexWhisperSeen`（XConfig，不跟存档）。
  - **CE1370 斩天拔剑术再释放：原版代码错误**。新源写成 `actor._actions.push(2827)`，OTB 下公共事件在行动结束后才跑、push 的行动没人取，2827 从不出手（`battle_common_event_probe.cjs` 加 `push_recast_with／without` 两例实测：with 造了 1 个 2827 行动、行动序列与 without 完全一样）。天魔星说明是「斩天拔剑术会额外释放一次」，旧版写法是 splice＋forceAction。`XBattleEventRunner.O_PUSH_RECAST`（默认 true）补成强制行动（施法者取预约行动者，会 2826 才算，否则变量 884），设 false 回原版。**O 号待总装分配**。
- **v0.41 商店规则**（`installBalanceShopV041Runtime`，重制原来没有）：`XShopStock.prepare_policy`／`shop_context`／`policy`。被动书指定价 ×1.3 向上取整；左右互搏术 1914 全局限购 8 本（`flags._codexLeftBought41`，卖回不还名额，旧档按各组已卖 5−剩余补）；当铺 Map204 全店不限购；大厅 EV54 有被动书时全店不限购、否则只被动书不限购。解释器 302 时记事件、map_scene 开店前算、关店清空。`shop_stock` 参照里两项对象身份（每次开店套新外观）按外观改判。
- **107／110 层商人**：新源 EV6 换成深渊商人 `<CodexMerchant29>`，原版同样走不到（`merchant29_present`），两个用例按新源判。
- **挖宝 v0.29**（`installTreasureBatchRuntime` 包 RunGetFun）：`XTreasureMap.run` 新增 `common_id`；新源去掉站位门槛与「挖宝成功」，按公共事件认藏宝图（21 种表），只算四类候选齐的宝点、扣用的那张图。旧源（manifest 无此运行时）照原生。批量使用界面（Scene_Item 包装）没做（B 界面）。
- **Map213 一护**：新源原作已做活（43 层 1570 → 45 层 1575 → 116 层 1576 → 敌群 2026 → 卍解-斩月-II 72）。`XDeadContent.ichigo_old_source()`：O-184 只在旧源（第 1 页条件角色 109）打补丁，新源不再给 CE2508 插 1309。**优化登记里 O-184 建议加注「新源原作已做活，补丁不生效」**（共用文件，交总装）。
- **大厅 74～77**：切片 keepEvents 加 74 祈求者天赋、75 时空漩涡（挡 (14,19)，碰到推回）、76 漩涡字幕过场（新档首次进大厅自动跑一次）、77 流萤立绘（空页，移动路线换图）。图早已在产物里。
- **对接悟空 XTier**：merge 集成分支 451012b6 后，`XState.tier_non_weak_ids／tier_ids` 改调 `XTier`；`xiyou_script` 旧写法超强者名单人数按 XTier 算。

### 进度（本单后半）

- 未登记脚本：做完（剩流萤）。商店三项：做完。挖宝运行时：做完。Map213：做完。大厅 74～76（含 77）：做完。nonWeakIds 对接：做完。
- **event_compare 重出基线：没做**（交接给下一位，见下）。

### 接续要点（后半）

- event_compare 基线：全量跑一遍（本机 >10 分钟，挤时推分支上云跑），看差异是否都是本单改动带来的（商店 ×1.3、挖宝不看站位、大厅 76 过场、1914 限购会改不少 trace），确认后按工具车道的方法重出基线。
- 大厅 76 过场：新档首次进大厅会跑一段带动画的自动过场。本机发现 opening_branches 测完退出时过场动画还挂着，Godot 报「2 resources still in use」，并行测试按失败算；我在 guide、opening_branches 里先把 rift1 记成看过。**其它进大厅的场景可能同样被挂**，全量跑时注意；根治是查过场里 212／205 等待的协程在退出时没收（或测试宿主统一把 rift1 记成看过，过场单独一例测）。过场本身还没有完整走一遍的用例（只测了条件与 mark）。
- 旧源兼容：v0.41 商店外观、挖宝 v0.29、PlayerChangelog 都按产物 manifest 有无对应运行时或文件切换；旧源产物没跑过本单的测试。
- 宝宝路线 v0.62（`installBabyAllActorsRuntime`，开关 2496 号角店全免费）重制没有，不在 A 车道本单范围，记一下。

### 验证（本单后半，本机新源产物）

- xiyou_script 40/40（含 roster 按 XTier）、battle_common_events 95/95、shop_stock 56/56、floor_reach107 59/59、floor_reach109 367/367、common_scripts 457/457（合 XTier 后）、floor_odds 173/173、floor_reach004 207/207、opening_branches 16/16、difficulty_inherit 6120/6120、lobby_shops／map／weak_challenge 照旧（weak_challenge 121/125 在 189 表）、guide 56/63（与集成分支原来一样）。
- script_census 只剩流萤 1 条（known_empty 照旧挂）。
- `事件空绿扫描.py --check`：96 例均在基线内、理由齐。

### 待交叉核查（后半）

- `mv_script.gd`（`_cut_misc`、`_data_patch`、`_inject_changelog`、eval_expr 的 jianxin／CodexWhisper）、`xconfig.gd`（codexWhisperSeen）、`battle_event_runner.gd`（`_push_recast_script`、O_PUSH_RECAST）、`battle_common_event_probe.cjs`＋夹具、`shop_stock.gd`（v0.41）、`shop.gd`、`map_scene.gd`、`mv_interpreter.gd`（302 记事件）、`treasure_map.gd`（v0.29）、`dead_content.gd`（ichigo_old_source）、`xstate.gd`（tier 对接）、`xiyou_export.py`（export_changelog）、`xiyou_slice.json`，以及各测试改动。
