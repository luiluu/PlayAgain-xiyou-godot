# 交付：cc/bajie-newsrc1

- 车道／工作者：A 内容·楼层／八戒（cc，第十四批 CP）
- 状态：交付集成分支（不标可合并 main；集成分支用，不合 main；由总装在 `cc/newsrc-switch` 的工作树里 merge）
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

已过（本树本机，新源）：floor_abyss174、floor_abyss211、floor_reach011、floor_unknown160、floor_unknown210、floor_unknown223、unlock_chain、unlock_chain_b、unlock_chain_c、opening_branches、script、dungeon、floor_abyss037，共 13 个；floor_odds 只剩 Map213 一护（天道注视部分已过）；weak_challenge 120→121/125（剩说明卡行，B／C）。

还挂的，逐个定性：

| 场景 | 现象 | 定性 | 归谁 |
|---|---|---|---|
| difficulty_actor | 名单已跟上，只剩角色 1 少被动 10455 | 新源角色多被动（与 actor_p0 同根） | C 规则 |
| honghuang_reward | 名单已跟上，只剩 `source` | 夹具来源 | 工具（哪吒） |
| honghuang_curse | 提示多一行「神话、混沌神话词条概率也随之提高…」 | 新数据已有这一行；夹具 `honghuang_curse_oracle.json` 内容还是 v0.28 的（只有两行，最后一次提交仍是 honghuang1），合了集成分支后 `source` 不再报但内容没重出。在新源上重跑 `honghuang_curse_probe.cjs` 重出即过 | 工具（哪吒） |
| review135 | 状态 1726「不朽2」确认效果 | 新源公式改成 `value*(1+v965*0.1)`，状态 JS 翻译 | C 规则 |
| interp_review | flush.225：316 升级文字参照为空 | 新源参照里升级文字没进 `$gameMessage`，原因未查明（AXY_Toast 与插件参数两版相同） | A，下一单 |
| common_scripts | 挖宝多一条「挖宝成功」、away 用例走了坐标提示 | v0.3x 起 `installTreasureBatchRuntime` 改挖宝路径，要跟这个运行时 | A，下一单 |
| floor_odds | Map213 EV2 一护修炼 | 新源整页重做（`<ClaudeShuangEvent>`，变量 1575／1576／1578、敌群 2026、角色 148），用例按 v0.28 写死，要按新源重写；天道注视部分已跟 | A，下一单 |
| floor_reach004 | 大厅保留事件少 74、75、76 | 新源新增祈求者天赋、时空漩涡、漩涡字幕（`CodexWhisper`）三个事件，是新内容；进切片要连运行时一起跟 | A＋扩内容 |
| script_census | 新源未登记脚本 | 总账：`CodexBossDifficulty.showRoster`（v0.44 改成两条裸调用、不带 setWaitMode，强者／超强者两份名单 `$gameMessage.add` 进同一个消息；名单改读 `<KyoTier>`、不再另加小猫；重制要能「无等待追加到待显示文字且带头像」才跟得准）、剑心图鉴、`CodexGuide.injectChangelog`、`CodexWhisper`、`CodexLiuying.recruit`、等级上限道具、CE1370 追加行动等；天道注视已跟。跟一个销一个 | A，逐项 |
| event_compare | 退步 100 多例＋地图 234～239 读不到 | 新源几乎每个改过的事件都在里面；234～239 是新地图不在切片。要等上面各项跟完、事件状态探针新源补量后重出基线 | A，最后做 |
| floor_reach107 | 107 层商店对话 | 新源商店对话改了，未细看 | A，下一单 |
| floor_reach109 | 110 层商店 1410～1415 取不到 | 新源 110 层商店改了，未细看 | A，下一单 |
| map132_shop、shop_buy | 号角店多 245／274／359／456／494、少 3063 | 新源停用号角表变长（`installImportedBalanceRuntime.disabledHornIds` 加了 245、274、359、456、494）＋流萤号角 3063 进不朽号角店；停用表在 `imported_balance.gd`（规则车道正在动），`item_marks.gd` 另有一份同名常量，建议改成引用前者；3063 要等流萤跟进 | C 规则＋扩角色 |
| shop_stock | 分组口径（sameObject、ungrouped） | 新源商店库存分组改了，未细看 | A，下一单 |
| difficulty_actor 之外的 CodexTier 用处 | `XItemMarks.super_strong_ids`、`mv_script._STRONG_IDS` 仍是写死名单 | 新源统一读 `<KyoTier>`，建议都改读 `XState.tier_non_weak_ids` 一类；未动 | C 规则 |

## 事件状态探针（新源）

- 在本树用新源（`XIYOU_APP` 指 v0.62.12）跑了 `补跑事件状态探针.py`：增量补量到 **9657 个用例全部是新源结果**（四段并行，机器满载时 39 分钟）。结果在本树 `generated/oracle/event_states.json`（gitignore，不入库；集成分支合并后要在集成分支树里再补跑一次，或从本树拷）。
- 派单说先只跑 28 个场景用到的：这 28 个里只有 `xiyou_event_compare` 读 event_states，而它读全量，所以直接全量补了。
- Map213 EV2 三个预设变体（`m213e2p1#a3`、`m213e2p2#a3`、`m213e2p0#w1_857`）跟新源换了变量／武器／角色（1309→1575、1311→1570、807→72、109→148、1318→1576）；另把 main 上总装删 3 个零效果 w1 变体的提交（a967b7ea）摘进来，免得合 main 前空绿检查一直挂。

## 空绿扫描（`事件空绿扫描.py --check`）

- 「一条效果指令都没走到」的报错已清零。
- 30 个深渊／不朽商人第 2 页收进基线（新源原版本身无效果，见上）。
- **还挂 19 个新增空绿**（新源内容改动造成，要补预设）：ce117、ce1381～1384、ce1438、ce9023、ce9026、ce9028～9030、ce9034、ce9039、m144e15p0、m145e11p0、m43e23p1、m45e10p0～p2。下一单补。

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

- 合入集成分支 31d0628a 后，本树本机新源跑 72 个场景（`xiyou_floor*`、`xiyou_unlock_chain*`、`xiyou_script*`、census1、dungeon、seal_doors、event_compare 与上表各场景、difficulty_inherit 三个）：53 过、19 挂，挂的 19 个全在云端 189 失败表里，没有新挂的（日志 `04_验证/本地结果/并行测试/20261106_103302_fg1i5hlj/`）。
- 改 `xstate.gd` 让选测扩到 400 个场景，本机三条车道抢槽，没跑全；`xstate` 只加了一个函数和一条只在新写法下生效的分支。
- `语法检查.py` 0 问题；`工具回归.py` 全过；`事件空绿扫描.py --check` 见上（还挂 19 个新增空绿）。
- 新源参照引擎实测 355 字符串参数（临时脚本在会话草稿区，不入库）：CE1439 那条不调 `complete`、商人那条 `C is not defined` 被 YEP 吞掉；数组写法才调到 `openCurrent`。

## 本分支提交

- 见 `git log cc/newsrc-switch..cc/bajie-newsrc1`
