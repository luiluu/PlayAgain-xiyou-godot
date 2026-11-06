# 交付：cc/bajie-newsrc1

- 车道／工作者：A 内容·楼层／八戒（cc，第十四批 CP）
- 状态：进行中（集成分支用，不合 main；由总装在 `cc/newsrc-switch` 的工作树里 merge）
- 从 `cc/newsrc-switch`（cc69f998）切出；工作树 generated 用集成分支的新源产物（v0.62.12），转换器在本树对新源重跑过。

## 变更记录草稿

### 【cc·八戒·未经审查】换源追平：新源 355 字符串参数、CodexTier 名单、天道注视、深渊商人页（跟到 v0.62.12）

- **新源 355 的 `parameters` 是字符串**（表「一」第二行 9 个场景的 `mv_event_core.gd` String 赋给 Array）：只有两种，都是 355——深渊商人 32 个事件页的 `CodexAbyssMerchant.openCurrent(this);`、公共事件 1439 的 `if(window.CodexAbyssMerchant)CodexAbyssMerchant.complete(this);`。原版 `command355` 读 `parameters[0]`，对字符串只拿到第一个字符：新源参照引擎实测，前者 eval `C` 抛 ReferenceError 被 YEP_CoreEngine 的 try 吞掉，后者 eval `i`（插件漏出来的全局变量）只取值，**两条在原版都不生效**，`complete`／`openCurrent` 都没被调到。
  - 选在**转换器规整**（`xiyou_export.py` `mv_string_parameters`）：把字符串拆成逐字符数组，任意下标读到的都与原版对字符串取下标相同，行为不变；原字符串留在指令的 `mvStringParameters`，manifest 另记 `mvStringParameters`（31 处：切片里 30 个事件页＋CE1439）。不在解释器容错的理由：Godot 侧按数组读 `parameters` 的地方不止 `_execute`（地图／战斗解释器的 355、`xstate` 扫公共事件名单、`actor_book`、`casino_batch`、`bulk_pills` 等），只修一处别处照样崩，新写的读者也会再踩；规整成原版实际读到的值，一处修完。
  - `MVScript.run`：整段只有一个裸标识符时当无操作（原版 eval 它没有效果），这样 `C`／`i` 不进「认不出的脚本」。
  - 开关：`XIYOU_MV_STRING_PARAMS=keep`（转换器不拆，回到原样）、`MVScript.BARE_IDENTIFIER_NOOP = false`。O 号待总装分配。
  - **原版本身的问题（报 Kyo，不改原版）**：v0.62.12 里深渊／不朽商人因此永远不会出现（唯一调 `complete` 的就是 CE1439 这条）。
- **CodexTier.nonWeakIds()**（v0.44 起公共事件 1345、1443～1445 的名单改读角色备注 `<KyoTier:超强者|强者>`）：`XState.tier_non_weak_ids()` 按备注取（有名字、编号升序）；`MVScript.run` 把调用换成字面数组后照旧走「名单循环」写法，`XState.difficulty_native_ids` 认 `var 名单 = CodexTier.nonWeakIds()`（弱者判定 `XWeakChallenge.is_weak` 读它）。
- **一线生机与天道注视**（公共事件 1330，v0.34 起 `CodexHeavenGaze.apply(true|false)`）：有名字的角色逐个建出，弱者在 `apply(true)` 时学 6212；非弱者先 repair（会 6212 的忘掉、学 6213）再学 6213。
- **深渊商人事件页**（v0.30 起 `<CodexMerchant29>`）：第 2 页只在 `hasMerchant()` 时成立、不看页面条件。重制没跟商人运行时，`MVEvent.merchant29_present()` 恒为否（原版 v0.62.12 也走不到，见上）；开关 `MVEvent.MERCHANT29_PAGE_GATE = false` 回到只看条件。`xiyou_dungeon` 的 `page_of` 同步；`xiyou_floor_abyss037` 的商人用例改成新源行为（77／78 不开、商人页不出）。

## 场景追平情况（表「一」第二行 9 个＋表「三」A 领域 19 个）

已过（本树本机）：floor_abyss174、floor_abyss211、floor_reach011、floor_unknown160、floor_unknown210、floor_unknown223、unlock_chain、unlock_chain_b、unlock_chain_c、opening_branches、script；复测中：dungeon、floor_abyss037、floor_odds（见「验证」）。

还挂的，逐个定性：

| 场景 | 现象 | 定性 | 归谁 |
|---|---|---|---|
| difficulty_actor | 名单已跟上，只剩角色 1 少被动 10455 | 新源角色多被动（与 actor_p0 同根） | C 规则 |
| honghuang_reward | 名单已跟上，只剩 `source` | 夹具来源 | 工具（哪吒） |
| honghuang_curse | `source`＋提示多一行「神话、混沌神话词条概率也随之提高…」 | 新数据已有这一行，旧夹具没有：重出夹具即过 | 工具（哪吒） |
| review135 | 状态 1726「不朽2」确认效果 | 新源公式改成 `value*(1+v965*0.1)`，状态 JS 翻译 | C 规则 |
| interp_review | flush.225：316 升级文字参照为空 | 新源参照里升级文字没进 `$gameMessage`，原因未查明（AXY_Toast 与插件参数两版相同） | A，下一单 |
| common_scripts | 挖宝多一条「挖宝成功」、away 用例走了坐标提示 | v0.3x 起 `installTreasureBatchRuntime` 改挖宝路径，要跟这个运行时 | A，下一单 |
| floor_odds | Map213 EV2 一护修炼 | 新源整页重做（`<ClaudeShuangEvent>`，变量 1575／1576／1578、敌群 2026、角色 148），用例按 v0.28 写死，要按新源重写；天道注视部分已跟 | A，下一单 |
| floor_reach004 | 大厅保留事件少 74、75、76 | 新源新增祈求者天赋、时空漩涡、漩涡字幕（`CodexWhisper`）三个事件，是新内容；进切片要连运行时一起跟 | A＋扩内容 |
| script_census | 新源未登记脚本 | 总账：`CodexBossDifficulty.showRoster` 带行尾注释、剑心图鉴、`CodexGuide.injectChangelog`、`CodexWhisper`、`CodexLiuying.recruit`、等级上限道具、CE1370 追加行动等；天道注视已跟。跟一个销一个 | A，逐项 |
| event_compare | 退步 100 多例＋地图 234～239 读不到 | 新源几乎每个改过的事件都在里面；234～239 是新地图不在切片。要等上面各项跟完、事件状态探针新源补量后重出基线 | A，最后做 |
| floor_abyss037 | 深渊商人 | 已改成新源行为，复测中 | — |
| floor_reach107 | 107 层商店对话 | 新源商店对话改了，未细看 | A，下一单 |
| floor_reach109 | 110 层商店 1410～1415 取不到 | 新源 110 层商店改了，未细看 | A，下一单 |
| map132_shop、shop_buy | 号角店多 245／274／359／456／494、少 3063 | 新源停用号角表变长（`installImportedBalanceRuntime.disabledHornIds` 加了 245、274、359、456、494）＋流萤号角 3063 进不朽号角店；停用表在 `imported_balance.gd`（规则车道正在动），`item_marks.gd` 另有一份同名常量，建议改成引用前者；3063 要等流萤跟进 | C 规则＋扩角色 |
| shop_stock | 分组口径（sameObject、ungrouped） | 新源商店库存分组改了，未细看 | A，下一单 |
| difficulty_actor 之外的 CodexTier 用处 | `XItemMarks.super_strong_ids`、`mv_script._STRONG_IDS` 仍是写死名单 | 新源统一读 `<KyoTier>`，建议都改读 `XState.tier_non_weak_ids` 一类；未动 | C 规则 |

## 交接板

- 下一步：A 领域剩下的按上表：挖宝运行时、Map213 一护、107／110 层商店、商店库存分组、新增大厅事件、未登记脚本逐项；最后 event_compare 重出基线。
- 用户试玩说明：无（集成分支）。
- 需要用户决定：原版 v0.62.12 深渊／不朽商人因 CE1439 的 355 参数写成字符串而永远不出现——这是原版的问题，重制照原版（不出现）；要不要在西游 MOD 里修，Kyo 定。

## 进度账

- 换源追平（A 领域）：28 个里已过 11 个、复测 3 个，其余定性见上表。

## 可优化（流程／工具／效率）

- 建议：`item_marks.gd` 的 `DISABLED_HORNS` 与 `imported_balance.gd` 重复，改成引用一份（规则车道顺手）。
- 建议：机器上三条车道同时跑时，本车道的事件状态探针四段占满共用 4 槽，测试等了二十多分钟；探针段数可按空槽数自适应（工具车道）。

## 待交叉核查

- `xiyou_export.py`（转换器规整）、`mv_script.gd`、`xstate.gd`（`tier_non_weak_ids`、`difficulty_native_ids`）、`mv_event.gd`（商人页）、两个测试改动。

## 验证

- 待写

## 本分支提交

- 见 `git log cc/newsrc-switch..cc/bajie-newsrc1`
