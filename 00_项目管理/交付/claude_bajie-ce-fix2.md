# 交付：claude/bajie-ce-fix2

- 车道／工作者：C 规则·解释器／八戒（Claude，八戒_77）
- 状态：可合并（待 Codex 核查；没有改原沙僧核心文件）
- 基线：从 6ece5c08（ce-fix1 的合并提交）开的分支，开工 `--补齐`。之后 main 去掉了这次合并、改合 save-events（1b980186）；交付前合了 main，**所以本分支连同 ce-fix1 的提交一起带进来**（ce-fix1 交付单 `claude_bajie-ce-fix1.md` 也在本分支里）。
- 来源：总装 2026-10-27 派单「效果型公共事件期三」：ce-fix1 之后事件对照登记剩 18 项（专属角色号角 CE9002～9018、CE765、823、824，另有 m4e73p0、m189e1p0 两项老的）。

## 变更记录草稿

## 2026-10-27 【Claude·八戒·未经Codex检验】期三：专属角色号角的超强者门槛、镜流入队、备注超强者并入名单；事件对照登记只剩 m4e73p0（dev.待定）

接 ce-fix1：事件对照登记从 18 项减到 1 项（m4e73p0，O-044／O-050 有意不移植）。悟空期十二（dev.191）登记的 113 个公共事件不一致到此全部消掉。

- **号角的超强者门槛**（installBossDifficultyRuntime 的 `D.recruitments`）：原版给渡鸦、米拉、黄泉、镜流、甚尔、宿傩、饿狼、云裳、谷雨、屠苏、璇 11 个模块的 `recruit()` 包了一层——角色是超强者、又没开挑战开关也不是混沌难度时，提示「超强者仅限地狱及以上难度获取。」并返回 false，模块本身不跑。重制在 `MVScript._recruit_blocked` 照做：
  - 不带 try 的写法（9002～9005、9010）挡下就只提示。
  - try 写法（9006、9007、9009、9012、9013、9016）挡下后照原文 `gainItem` 还号角；号角本身也受同一门槛，`gain_item` 不给，和原版一样号角不回来。
  - 谷雨／屠苏／璇的脚本写的是 `X.ids().horn`，取同一张表里的号角号（2943、2945、2946）。
  - 模块没移植的甚尔、云裳、谷雨、屠苏、璇：只有挡下这一支能照做；放行时（地狱以上）照旧算没认出。
- **镜流入队**（9005 `CodexJingliu.recruit()`）：原来没接，接到 `XYomiJingliu.recruit(…, JINGLIU)`，和黄泉同一模块；镜流不是超强者，难度 3 也入队。
- **备注 `<CodexSuperStrong>` 的角色并入超强者名单**（installNativeBindingChargeRuntime `B.syncSuperStrong`）：原版在开战（BattleManager.setup）和读档时把 174 云裳、176 屠苏、177 璇并进 `D.superStrongIds`，之后获取、出战、招募、Boss 每名出战超强者 +20% 都按它算。重制原来只用固定名单，这三人不算。新增 `XItemMarks.super_strong_ids()`／`is_super_strong()`，获取／出战（`can_acquire_actor`、`enforce_party`）、Boss 加成计数（`XEnemy.deployed_strong_count`）、宏荒强弱分类（`XPowerBooks.actor_class`）、破阵·投影名单都改用它。重制总是算进去；原版只有「新局后还没打过仗也没读过档」那一段不算。
- **9011 天衣铺、9018 小猫试炼**：只移植了条件不够时的提示（云裳不在队或不到 20 级；小猫不在队、不到 35 级或没持剑）。条件够时的天衣铺页面和试炼战斗没移植，照旧算没认出。
- **CE765 一键开启**：游戏逻辑本来就对，是事件对照替身计时偏了 2 帧。原版每帧先 `frameCount++` 再跑解释器，第一条指令在第 1 帧；替身原来在 `_process` 里逐帧累加 1/60，等待指令在 `process_frame` 信号上恢复时这一帧还没计入，而且 120 帧累加成 1.999… 取整少 1 秒。改成在 `process_frame` 信号里先计帧、每例从第 1 帧起、按整数帧数换算。
- **CE823／824 裴钱练武／练气、m189e1p0**：是已登记的 O-085（精魂下限 0；原版扣钱可扣成负数）。两边每例都从新局 0 精魂起，原版净扣成负数的，重制夹在 0。事件对照按 O-085 把原版的负数差量去掉再比，三项一起消掉。先扣成负数再加回来的写法会照旧报不一致，到时再看。
- **原版探针 `common_script_probe.cjs`** 补 27 例（455 例）：号角难度 3 挡下 11 例，模块已移植的再测开挑战开关入队、已在队各 6 例，天衣铺和小猫试炼的前置各 2 例。探针新增预置 `actors`（入队＋等级）和 `sync`（调原版 `CodexBinding.syncSuperStrong`）。

## 交接板

- 下一步：事件对照登记只剩 m4e73p0（O-044／O-050 有意不移植）。号角放行一支里还没移植的模块：甚尔 171、云裳 174（含天衣铺）、谷雨 175、屠苏 176（含器谱 9014）、璇 177（含璇星谱 9015）；小猫试炼战斗（9018 条件够时）。
- 用户试玩说明：地狱以下难度用专属角色号角会提示「超强者仅限地狱及以上难度获取」，不入队；镜流号角能入队；云裳、屠苏、璇现在也算超强者（地狱以下不能出战、不能获取）。
- 需要用户决定：无。

## 进度账

- 无变化（没有新地图）。

## 验证

- `xiyou_event_compare`：5753 例一致 5752，不一致只剩 m4e73p0（`--update-baseline` 删 17 项，无退步）；参照报错 m221e3p0、ce1344 两例照旧，不计。
- `xiyou_common_scripts` 457/457（参照 455 例，新增 27 例）。反向验证：让 `_recruit_blocked` 恒返回 false，10 个 `horn.*.d3` 全部失败（9005 镜流不是超强者，本来就放行）。
- `xiyou_super_acquire` 31/31（新增 4 项：备注超强者在名单里、获取挡下、Boss 加成计数、出战被清下）。
- 选测 31 场，并行 2，`--full`，480 秒，全部单次通过：xiyou_actor_modules 56、autosave 10、boss_lifecycle 5080、boss_output 3823、boss_output_context 16621、boss_react 9074、boss_sequence 8315、boss_state_origin 15723、cat 994、common_scripts 457、event_compare 5、floor31_bosses 67、imported_balance 273、item_marks 108、party 58、party_skills 214、power 137、power_books 6136、power_books_boundary 55682、power_books_menu 1068、reward_branches 4、xiyou_rules 难度 1 四段 115637／115733／115746／115725、script 21、shop_buy 10781、status_power 36、status_power_panel 11、super_acquire 31、super_deploy 43。
- `内容覆盖检查.py --check`：新增 0、消掉 0（hard 2 都在基线）。
- 原版探针 `common_script_probe.cjs` 单跑约 1 分钟，errors 为空。
- 同步 `同步正式西游.py --accept-additions`（工作树，不登记）：退出码 0，「测量不变」，18 分钟，留了产物指纹。同步后复跑 `xiyou_event_compare` 5/5（5752/5753）、`xiyou_common_scripts` 457/457。
  - 第一次同步失败：slice_probe 六个难度的增量合并（`oracle_shard_merge.cjs`，每份约 170MB）同时退出 1，当时主工作区在跑全量。单独重放同一份合并成功，第二次同步六段都通过，判为偶发（日志 `同步_第1次.log`）。
- 合 main（1b980186，save-events）后：xstate.gd 存档键一处冲突（`mapEvents` 与 ce-fix1 的 `allowAutosave` 两边都留）。复跑 xiyou_autosave 10、save_events 25、save_page 40、battleback_save 5、flow 48、pet_capture 48、common_scripts 457、event_compare 5、super_acquire 31，全过。合进来的 save-events 改了探针（save_events_probe、pet_capture_probe），但两者的夹具都在 tests/fixtures 里，所以没有重新同步。
- 没跑全量。日志在 `04_验证/本地结果/20261027_八戒_cefix2/`，不入 Git。

## 待交叉核查

- 本分支提交（执行者: Claude（八戒），核查: 待Codex）。
- 没有改原沙僧核心文件（battle_logic／actor／battler／damage／xstate 都没动）。改了 `core/enemy.gd` 的 Boss 加成计数一行（超强者名单改走 `XItemMarks.is_super_strong`），请重点核：174／176／177 出战时 Boss 会多 +20%／人，原版开战时已经并入名单。
- 原版探针 `common_script_probe.cjs` 加了 `actors`、`sync` 两种预置，请核是否照原版流程。

## 遗留

- 号角放行时没移植的模块（见交接板下一步），以及 9014 屠苏器谱、9015 璇星谱（原版在角色不在队时什么也不做，重制目前也一样没反应，但没对照条件够时的页面）。
- 9011／9018 的原版还判 `$gameParty.inBattle()`，重制的脚本翻译只在地图上跑，没判。

## 可优化（流程／工具／效率）

- 事件对照替身的计时现在和参照引擎逐帧对齐（第 1 帧起、整数帧数换算）；之后再有「差一个等待」的不一致，先看计时，不是解释器。
- 补齐的导入等共用槽约 34 分钟（主工作区在跑全量）。
- 同步的 slice_probe 增量合并：六个难度并行各读写约 170MB 的 JSON，机器满载时会一起失败，而且同步日志里只有「探针失败」，看不到合并的报错输出。建议给工具车道：合并失败时把 `oracle_shard_merge.cjs` 的输出写进日志，六段合并改为串行或限 2 个并发。

## 本分支提交

- 见 `git log main..HEAD`
