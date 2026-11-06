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
