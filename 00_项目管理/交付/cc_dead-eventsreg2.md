# 交付：cc/dead-eventsreg2

- 车道／工作者：tests／探针／悟空（dead 线程，cc；派单第九批 BB）
- 状态：可合并
- 切点：cc/dead-eventsreg1（14115b15，当时还没进 main）。**本分支含 eventsreg1 全部提交，只合本分支即可**（两份交付单都要并）。

## 变更记录草稿

## 2026-11-05 【cc·悟空·未经审查】事件对照预设能选指定选项、用指定随机数；补 13 个变体，没对照例的写法 20→10（dev.待定）

- **预设 `answers`**（`mv_oracle/event_state_probe.cjs` 与 `tests/xiyou_event_compare.gd` 的 EventHost 两边同）：依次应答这一例里的「显示选项」（选第几项，从 0 数，越界夹到最后一项）和「数值输入」（填的数）；用完回到原来的默认应答。物品选择（104）没接：剩下的写法里用不到，参照与重制的物品选择应答也不对称，留二期。
- **预设 `random_seq`**（键名照 accept5 解锁链用例的 `random_seq`，总装 15:04 提醒复用）：这一例变量操作 122 的随机数按这串循环取，参照覆盖 `RANDOM_SEQUENCES`，Godot 交给现成的 `MVInterpreter.random_sequence`（与 accept5 用的同一个静态变量），不另起一套。只管 122，跟原有 RANDOM_SEQUENCES 口径一样。accept5 的 `battleResult`、`playerDirection` 在 cc/wukong-accept5 上，本分支没有，合并时无冲突的话两套键并存。
- **O-120（B2）对照时关掉**：`removed_gate_fix`（深渊之门已移除那支改走「离开」）只对表里事件（80:13）的用例关，同 seal_check_fix 的做法；m80e13p2#s1 用随机序列走到了 `CodexMapRemoval.notice`，原版停在提示后，重制按 O-120 改走离开，这是登记过的优化，不是新差异。
- **补的变体**（`event_presets.json` 追加 13 条，tag `s1`／`s2`，Sonnet 子任务起草、我复核并重跑）：m4e8p0#s1、m187e2p0#s1（PHWarehouse remove）、m4e41p1#s1（for…$dataActors 循环）、m186e3p1#s1（toaster 带 color）、m2e2p0#s1（354 回标题）、m80e13p2#s1（CodexMapRemoval.notice，random_seq）、ce1094#s1（actor1.addState，random_seq）、m4e46p0#s1（103 数值输入非 0）、m4e8p0#s2（推 Star_Scene_ActorWarehouse）、m41e1p0#s1（推 Scene_StarWarehouse）、m2e2p2#s1（ConfigManager.DesignationN）、m1e1p0#s1（开局四次应答）、ce249#s1（云存档 cloudSaveGame）。参照端 1005 个变体全部跑完、无报错；`xiyou_event_compare` 全量 10/10 通过，新变体全部一致。
- **覆盖表重出**（`04_验证/事件写法覆盖.md`）：250 类写法，有原版对照 240 类，没有且走得到 **10 类**（上期 20）。剩下的：
  - 赌场 `CodexCasino.open`（m4e60 三页）：试过 m4e60p0#s1／p2#s1，原版券不足时出「肝帝积分抽奖券不足。」，重制对照里没有——查实是**测试替身的缘故**：`XCasinoBatch.open` 先判宿主是不是 XMapScene，替身不是就直接返回，走不到券数判断；真游戏宿主是 XMapScene，提示照出（`casino_batch.gd` 第 57 行）。不算游戏差异，两条变体已撤；赌场由 `xiyou_casino_batch` 专项管。按总装 15:04 的分工，脚本／插件调用这几类交悟空 BG。
  - 轮回 `CodexReincarnationRandom.*`（m221e3p0）：原版点「轮回归来！」进 Scene_ReincarnationDraft，事件不结束（6000 帧 unfinished），对照比不了；交悟空 BG。
  - 261 播放影片（ce1516）：参照引擎播视频报错（替身没有视频元素），比不了。
  - 103、`prompt()`：变体里已经走到并比了（m4e46p0#s1 填 20250826 走了不同分支、m1e1p0#s1 整例一致），但 103 紧跟 101 被对话组一起消费、`prompt` 那段在消息组里执行，覆盖表不单记这两个下标，表上仍显示没有。
  - 传承强化上限 toaster（m195e23）：原版语法错误、整段不执行，无可比输出。
- 空绿扫描：97 例（上期 98），减少的一例是本期变体顺带补上的；**基线没动**（accept5 在做），`--check` 通过。

## 优化登记草稿

- 无（只改 tests／探针）

## 交接板

- 下一步：剩下 10 类里赌场、轮回交悟空 BG（已按总装分工）；103／prompt 只是覆盖表口径，可在 `事件写法覆盖.py` 里把「消息组里消费的 103」算进上一条 101 的执行（小改，归 tests 车道）。
- 用户试玩说明：无（玩家看不到）。
- 需要用户决定：无。

## 进度账

- 地图事件「零散写法回归」：有原版对照 240／250；完成度由总装定。

## 可优化（流程／工具／效率）

- `补跑事件状态探针.py --force` 现在 1005 个变体要 4～6 分钟，改一条预设也整份重量。可以加 `--only <base#tag,…>` 只量新加的再并进 event_states.json；归探针车道，预计一小时。
- 赌场这类「宿主不是 XMapScene 就直接返回」的写法，事件对照替身永远比不到；可以给替身加一个 `is_map_scene_stub` 之类的约定，或在 casino_batch 里把宿主判断放到券数判断之后（后者动游戏代码，要总装定）。

## 验证

- `xiyou_event_compare` 全量（带 `--coverage`）10/10；`事件空绿扫描.py --check` 通过（97 例都在基线内）。
- 选测：改的是 tests 与探针（与 eventsreg1 同口径，`选测.py` 会带出整组 xiyou_rules，它们不读预设）；本机跑了 xiyou_script_census、xiyou_common_scripts、xiyou_dungeon、xiyou_casino_batch、xiyou_floor_reach075（O-120 专项）五项，全部通过（机器满载，4373 秒）；`工具回归.py`、`语法检查.py` 通过。
- 改了参照探针与预设：`补跑事件状态探针.py --force` 已重量（1005 例，无 unfinished、无 errors）。

## 待交叉核查

- `answers` 两边口径：选项越界夹到最后一项（参照 Math.min／重制 clampi）；数值输入两边都直接写变量。
- `removed_gate_fix` 按用例关：只看 `kind == map` 且「地图:事件」在表里。

## 本分支提交

- eventsreg1：a2c70824、14115b15（见 cc_dead-eventsreg1.md）
- 3f8998a1 WIP：预设 answers 与随机序列
- 本提交：键名改 random_seq、O-120 对照时关、13 条变体、覆盖表、交付单
