# 交付：cc/nezha-tools30（哪吒_13，慢测试拆分与测试等待加固）

- 车道／工作者：D 工具／哪吒（cc，哪吒_13）
- 状态：可合并
- 分支起点：b413c4b6（tools29 末端）；交付前合了 main（42e3ff69，bulkpills1b、tools29 已在里面）。

## 变更记录草稿

## 2026-11-01 【cc·哪吒·未经审查】慢测试拆分、测试等待改「墙钟＋帧数」、alien_battle 偶发根因、伤害钩子漏登记当场报错、并行测试快车道（tools30，dev.待定）

- **起因**：第四批收尾时本机跑 276 个场景（CHECK_JOBS=3，另有三条车道在测，负载约 27），挂了 4 个和改动无关的：`xiyou_smart_ai_d`、`xiyou_troop_events_b` 跑满 600 秒被杀，`xiyou_map186`、`_legions`、`_legions_b` 是 90 秒墙钟到点、军团战没打完。这 5 个在本分支单独复跑（负载 10～20）全部通过：smart_ai_d 358 秒，legions 172／171 秒，troop_events_b 138 秒，map186 96 秒。所以是负载问题，不是回归。
- **smart_ai 拆分**：原来 4 份按用例序号逐条轮流，可是用例按「敌群×场面×角色 1/8/9/10」排，结果每份正好是一个角色，角色 9、10 候选多，那两份最慢（满负载 388 秒和 600 秒以上）。现在选择用例按「同敌群同场面的 4 个角色」整组轮流，伤害行照旧逐条轮流，分 16 份（`xiyou_smart_ai`、`_b`～`_p`）。分 8 份时实测每份 114～123 CPU 秒，负载 10～15 下 127～166 秒，满负载会再翻倍，所以分到 16 份，每份约 60 CPU 秒。断言合计 83233 不变（原来 4 份 22133＋22038＋19531＋19531，8 份时实测合计也是 83233）。
- **troop_events 拆分**：2 份改 4 份（`_c`、`_d` 新加，`_half` 不变）。每份 54～58 CPU 秒、60～80 秒；断言合计 13024 不变（原来 6574＋6450）。
- **测试等待** `tests/wait_budget.gd`（WaitBudget）：墙钟过了上限，而且帧数（`Engine.get_process_frames`）也过了「上限按 60 帧/秒折算」的帧数，两条都满足才算超时。慢机器帧少会多等，快机器照旧按墙钟到点。给了进度签名时，签名一变就从头计。`xiyou_map186`、`xiyou_map186_legions` 用签名：打完的场数、当前是哪一场战斗、第几回合、敌人还剩几个、还没用掉的自动回答。事件还在推进就续等；签名一直不变、两条都过了才判失败，场景 600 秒上限兜底。回退：`WaitBudget.USE_FRAMES = false` 回到只看墙钟。新专项 `xiyou_wait_budget` 8 项。
- **同类墙钟超时一并改**：`rg TIMEOUT_MS` 找到除 map186 两个以外的 53 个测试文件，共 110 处「`var t0 := Time.get_ticks_msec()` 加 `while … Time.get_ticks_msec() - t0 < TIMEOUT_MS:`」的等待（多数是 `_wait_map` 和 `_run_event`），机械换成 `WaitBudget.new(TIMEOUT_MS)` 和 `t0.waiting()`，循环体不动，上限值不动。语法检查通过（`t0` 要是还在别处当整数用，类型不对会报出来；结果没报）。没改的：`xiyou_floor_run.gd` 本来就按帧数等（`_within`，加快时钟时改按墙钟）；`xiyou_floor_run` 和 `xiyou_status_power_panel` 里只打印耗时的 `get_ticks_msec` 不算等待。这 53 个文件没加进度签名，只多了帧数这一条；签名要按各自事件写，建议以后哪个再因负载超时就照 map186 加。

- **alien_battle 偶发**（累计 5 次，都是 `encounter.boss_150.plainName`，名字多了前缀，例如「天外天·灼烂歼鬼小李飞刀」）：根因是随机流，不是时钟也不是负载。奖励本体由 `XGear.create` 掷前后缀和属性浮动，用的是新局的装备随机流，种子每局都不一样。参照那边序列用完以后 Math.random 一律是 0.5。测试里 `_encounter` 开头设 `XGear.force_roll = 0.5`，结束时恢复 -1。验证：故意设成 0.001 时，boss_150 和 origin_ok 两例的 plainName 都失败，说明确实是这里；改好后连跑 6 次都是 330/330。
- **伤害钩子漏登记字段**：钩子写了 descriptor `writes` 里没有的字段时，注册表返回 `undeclared_write:<字段>`，`damage.gd` 只 `push_warning`，这次伤害的值就成了 NaN，测试看不出来。现在 `XModuleRegistry.dispatch` 遇到这种情况会 `push_error`，写明「伤害钩子 <模块>（<点位>）写了 descriptor writes 里没登记的字段 <字段>」。并行测试见到 `ERROR:` 行就判失败，所以哪个场景触发了，当场就挂。回退：`XModuleRegistry.REPORT_UNDECLARED = false`。`xiyou_module_hooks` 里故意写错字段的那一例先关掉再恢复，并加了一条断言，确认诊断里点了模块名和字段名。打开时手动跑过一次，确实打出那行 ERROR。10-31 那轮 276 个场景的日志里没有一处「damage module unavailable」，所以现有测试不会因为这一条变红。
- **并行测试快车道**（白龙：单个专项直接跑 8 秒，排槽却要 7 分钟）：这一次只跑不超过 2 个场景、而且每个上次实测都不超过 60 秒时，先试 `slots/express.lock`。这把锁全机只有一把，非阻塞；拿到就不排共用槽直接跑，最多比共用上限多一个进程。拿不到，或者没有实测记录，就照常排队。回退：`XIYOU_SLOT_EXPRESS=0`。实测 alien_battle＋module_hooks 两个，负载约 15 时 36 秒跑完（打出「快车道」提示）。

## 验证

- 复跑：上面 5 个失败场景单独跑全部通过（见起因）。
- 拆分：smart_ai 8 份＋troop_events 4 份＋_half 共 13 个场景全过，合计断言与拆分前一致。改成 16 份后：16 份合计 83233/83233；负载 10～15 下每份 57～64 CPU 秒、63～119 秒。
- 改过等待的 60 个场景（`wait_budget.gd` 的选测结果，含 map186 五个、`xiyou_wait_budget`）＋smart_ai 16 份，共 76 个，并行 3：全部通过（2891 秒）。map186_b 256 秒最慢（120 CPU 秒，原本就这样，不在这次拆分范围）。
- 合 main 以后：`xiyou_yunshang`、`xiyou_toji`、`xiyou_toji_battle`（新合进来、带伤害钩子的）、`xiyou_module_hooks`、`xiyou_alien_battle`、`xiyou_wait_budget`、`xiyou_bulk_pills` 7 个全过，没有 ERROR 行。
- 合并工具自测 `测试合并工具.py` 230/230（新加快车道一例：共用槽占满时短单场景直接跑；超过 60 秒的、关掉开关的、快车道被占的照常排队），`测试提交守卫.py` 通过，`测试选测.py` 62/62，回退开关覆盖没有新缺口，语法检查通过。

## 交接板

- 下一步：无新增。
- 用户试玩说明：无（只改测试）
- 需要用户决定：无

## 进度账

- 无（测试）

## 可优化（流程／工具／效率）

- 建议：smart_ai 每条伤害行、每个选择用例都重新开一局、重新布置战斗（`setup`，约 43 毫秒一次，两万多次，合计约 950 CPU 秒），这才是它慢的根本原因。伤害行只做预估（`safe_damage`、命中、闪避），同一敌群可以共用一次布置；选择用例同一敌群同场面的 4 个角色也可以共用。估计能省一半以上的时间，份数也能减回去。可是这样会动到测试的隔离方式，要先确认预估确实不改状态，所以这次没做，留给工具车道。
- 建议：`云端测试耗时.json` 里没有新拆出来的场景，云端分片会先按默认值估，跑过一次以后就有实测值。

## 本分支提交

- WIP：smart_ai 16 份、troop_events 4 份、WaitBudget 与 53 个测试文件
- WIP：alien_battle 偶发、伤害钩子守卫、快车道
- 合并 main；交付单可合并
