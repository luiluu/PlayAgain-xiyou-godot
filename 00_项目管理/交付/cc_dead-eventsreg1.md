# 交付：cc/dead-eventsreg1

- 车道／工作者：tests／探针／悟空（dead 线程，cc；派单第八批 AX）
- 状态：可合并（一期：表＋一批写法补齐）

## 变更记录草稿

## 2026-11-05 【cc·悟空·未经审查】地图事件零散写法回归一期：对照覆盖表（250 类写法），补 13 个有状态变体，没对照例的写法 34→20（dev.待定）

- **事件对照记覆盖**（`tests/xiyou_event_compare.gd`）：加参数 `--coverage=<文件>`，用测试里的 `CoverInterp`（继承 MVInterpreter，覆写 `_execute`／`_make_child`）记每个用例实际执行到的指令「位置:下标」（位置＝`mMeEpP` 或 `ceN`；用例变体记到基础页上）。不带这个参数时完全照旧（`MVInterpreter.new`）。
- **写法覆盖表**（`03_转换工具/事件写法覆盖.py`，只读）：切片里地图事件页与公共事件的每条指令按「写法」归类（111 按条件类型、脚本条件按脚本形状；122 按操作数；355／655 按整段脚本形状；356 按插件指令前两词；201／301 按指定方式；续行与分支结构行不算），对上覆盖文件，出 `04_验证/事件写法覆盖.md`。结果：**250 类，230 类有原版对照例（真执行到），20 类玩家走得到但没有**（补之前 34 类）。
- **补的变体**（`03_转换工具/event_presets.json` 追加 13 条，tag `r1`～`r7`，Sonnet 子任务起草、我复核）：ce1431#r1（111 脚本条件 `=== N || === N`）、m186e3p1#r1（toaster 拼变量）、ce714#r1～r7（`$gameParty.DCultyL1～L8`）、m4e50p0#r1（`for … $dataActors.length` 循环）、ce1313#r1（`actor.learnSkill`）、m4e36p0#r1（241 播放 BGM）、ce334#r1（326）。参照端 13 例都跑完、无报错；`xiyou_event_compare` 全量通过（新变体全部一致，没有游戏差异要记）。
- 没补上的 20 类与原因（详见表）：
  - 要选非默认选项才走得到（对照应答固定取默认项）：PHWarehouse remove（m4e8、m187e2）、m4e41p1 的 for 循环、toaster 带 color（m186e3p1:17）、354 回标题（m2e2p0:60）。
  - 要靠随机结果过门（对照随机数固定 0.5）：`CodexMapRemoval.notice`（m80e13 变量 136 恒得 2）、`actor1.addState`（ce1094 变量 708 恒得 3）。
  - 参照引擎替身不支持：261 播放影片（ce1516，参照端报错，已撤）、云存档 `HWGOE.save.cloudSaveGame`、`prompt()`、`SceneManager.push(…Warehouse)`、`CodexCasino.open`、`CodexReincarnationRandom.*`、`ConfigManager.DesignationN`——这些是开界面／宿主入口，各有界面专项（仓库、赌场、轮回、称号），不在事件对照里比。
  - 103 数值输入：紧跟 101 的 103 被对话组一起消费，覆盖表不单记下标（参照轨迹里有 prompt 记录，实际已比）。
  - 传承强化上限的 toaster（m195e23）：原版语法错误、整段不执行（events6 认作无操作），没有可比的输出。

## 优化登记草稿

- 无（只改 tests／探针）

## 交接板

- 下一步：二期可选：给对照替身加「选第 N 项」的预设字段（`answers`）就能把要选非默认选项的 5 类补上；随机门那 2 类可加「固定随机值」预设字段。都要同时改 `event_state_probe.cjs` 与 `xiyou_event_compare._apply_preset`，归 tests／探针车道。
- 用户试玩说明：无（玩家看不到）。
- 需要用户决定：无。

## 进度账

- 地图事件解释器「零散写法回归」：表已出，有对照写法 230／250；完成度由总装定。

## 可优化（流程／工具／效率）

- 覆盖表可以接进 `检查.sh`（全量时跑一次 `--coverage`、`事件写法覆盖.py --check` 卡「有对照的写法变少」），防止以后改预设或解释器把已覆盖的写法弄丢。本期没接，因为 `--coverage` 要多跑一轮 event_compare（约 4 分钟）；归工具车道定。
- 观察面：ce1313#r1、ce334#r1 两个变体执行到了目标指令，但空绿扫描报「仍无 delta 也无非文字 trace」：ce1313 的 `$gameParty._targetActorId` 在新局里是空，学技能落空；ce334 的 326（改 TP）不在快照里。快照加 TP、预设支持 `_targetActorId` 能让它们真比出东西；归探针车道。

## 验证

- `xiyou_event_compare` 全量（带 `--coverage`）10/10 通过；`事件空绿扫描.py --check`：空绿 98 例均在基线内（没动基线，accept5 在做）。
- 选测：`选测.py main --list` 给 77 个（03_转换工具 改动带出整组 xiyou_rules）；event_presets.json 只被 event_state_probe、事件对照、空绿扫描读，本机跑了 xiyou_event_compare、xiyou_script_census、xiyou_common_scripts、xiyou_dungeon、xiyou_autosave、xiyou_lobby_shops 六项，全部通过；xiyou_rules 系列没跑（不读预设）。`工具回归.py`、`语法检查.py` 通过。
- 改了参照预设：`补跑事件状态探针.py --force` 重量过 event_states.json（992 个变体）；总装合并时 `检查.sh` 会再补跑。

## 待交叉核查

- `CoverInterp` 记位置的口径：根游标记用例页，公共事件子游标记 `ce<common_id>`，非公共事件的子游标（common_id 0）不记。
- 13 条预设的条件是否真对准目标分支（表里「执行到」由覆盖文件核过）。

## 本分支提交

- a2c70824 WIP：事件对照 --coverage；事件写法覆盖.py 出表
- 本提交：13 条变体、表更新、交付单
