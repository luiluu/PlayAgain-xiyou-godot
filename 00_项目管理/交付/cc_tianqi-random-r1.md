# 交付：cc/tianqi-random-r1

- 车道／工作者：C 规则·随机门面 R1／cc 车道（Opus＋medium，协调派单 task_b0d311af9178；方案见 `git show 12cd35586^:00_项目管理/交付/cc_save-rng-facade.md` 第 2、3 节）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【cc·随机门面R1·未经审查】天启篇随机门面 XTianqiRandom 骨架：seed-fix 存档派生入口原样搬家＋随机守卫.py（dev.待定）

- 新建 `modes/xiyou/core/tianqi_random.gd`（`XTianqiRandom`）：seed-fix 的 `save_stream`／`save_roll`／`seeds_on`／`has_seed_id`／`on_register`／`before_renumber`／`all_gear`／`assign_all`／`seed_id`／`item_roll`（连私有 `_derive_seed_id`、`_who`）**原样搬过去，派生字符串一字不改**；头注释写「身份规则」五条（＋「掷完要给玩家看的掷完就存结果」）。新增 `after_load(s)`＝老件补随机身份。
- `XTianqi` 里这 10 个函数改成同名转发（注明保留一个发行版本后删）；开关仍是 `XTianqi.SEED_FROM_SAVE`（O-449，搬家不换号——抽角色候选也认它，留在原处，R2 再看要不要挪）。
- 生产代码调用处改调门面：`xstate.gd` `register_gear`、`tianqi_reforge.gd`（2 处）、`tianqi_alien_gear.gd`（2 处）、`star_warehouse.gd`、`tianqi_affix_roll.gd`、`tianqi.gd` 开局补号；`mv_event_core.gd`、`map/mv_script.gd`、`ui/shop.gd`、`item_marks.gd` 只改注释里的类名。S2 正在改的 `warehouse.gd`、`yunshang_orders.gd`、`demon_crown.gd`、`tianqi_save.gd` 第 50 行注释没碰（与 xa/save-s2、xa/save-s3 试合并都无冲突）。
- 读档补号：`xstate.gd` `from_dict` 末尾删掉 `XTianqi.assign_all(s)` 一行，改由 `XTianqiSave.after_load` 末尾调 `XTianqiRandom.after_load`（`after_load` 拆成 `_migrate`＋补号两步；补号不受 `XTianqiSave.ENABLED` 影响，只认 `SEED_FROM_SAVE`，与搬家前一致）。次序上补号从 `XWeakChallenge.after_load` 之后挪到之前——后者只学／忘 10357，不碰装备，结果相同。
- 新工具 `07_开发环境/随机守卫.py`（方案 2.6）：范围＝`发行空壳.targets()` 认的天启篇脚本全集（60 个，含两个门面）＋`fabao_feed.gd`、`lottery_rework.gd`；报前面不带「.」的全局 `randf/randi/randf_range/randi_range/randfn/randomize/seed(`、任何 `.randomize()`／`XRandomStream.fresh_seed(`／`.pick_random(`／`.shuffle(`、`RandomNumberGenerator.new()` 后 3 行内没 `.seed =`；行尾注「# 表现」或「# 随机守卫：理由」放行。现存 5 处补注记：`tianqi.gd` 抽角色开关关时 `rng.randomize()`、`tianqi_qiyin.gd` `next_seed` 开关关时 `fresh_seed()`、`lottery_rework.gd` 开关关时 `fresh_seed()`、`tianqi_elements.gd:633`／`:1062` 两处调用方没给流时的兜底（方案 2.1 第 6 行「待查能不能走到」，留 R2）。挂进 `检查.sh`（文档与登记段，不占测试槽）、`检查.sh` tools 组与 `工具回归.py`（`测试随机守卫.py` 5 条）；`测试选测.py` 只改文档改动时的预期名单（多一项随机守卫）。
- 新专项 `tests/xiyou_tianqi_random`（48 条）＋夹具 `tests/fixtures/tianqi_random_premove.json`：夹具在**搬家前**的代码上生成（`tianqi.gd`／`xstate.gd` 等与 main 61b2786ca 逐字相同时跑 `XIYOU_TQ_RANDOM_WRITE=1`），内容是一份去掉随机身份的天启篇老档原文（背包 5 件含一对同 instanceId 复制品、身上 7 件、仓库 2 件，只留一件旧号）和当时读档补出的 15 个号、各入口掷出的序列。专项把存档原文写进存档位真读档，门面和 `XTianqi` 转发各比一遍（补号顺序与号、`save_stream`／`save_roll`／`item_roll` 序列、装备计数、来源键号与 `src_n`、星辰仓库补号、`seed_id` 懒补）；另测 `reload_same`（存→读→再取相同，含三种子）、关存档门面开关也照补、`from_dict` 直接走得到、关 `SEED_FROM_SAVE` 不补号回到全局随机、西游档不补。反向验证：把 `"tq_seed_src|%s|%d"` 改一个字符 → 2 条挂；把 `"tianqi_item|"` 改一个字符 → 6 条挂。
- `tq_save_kit.gd` 的 `each_seed`、`reload_same` S1 已加好，本批直接用，没改。
- 提交：见本分支提交
- 未完成／已知问题：方案 2.3 里的 `by_count`／`by_key`／`by_item`／`by_source`／`gear_stream`、旧写法包装（R2）与战斗键（R3）都不在本批。

## 返修（ag 甲档核查 R1：2 条 P2，2026-11-14）

- ag 甲档核查结论：原样搬家逐行一致、读档补号时机等价、老档夹具逐件比对、5 处补注理由成立；只有 `随机守卫.py` 两条 P2。
- P2-1 放行只认真正的行尾注释、`.seed =` 按分支：新 `_scan` 逐行拆出「代码／字符串之外的行尾注释」，`ALLOW` 只在注释部分匹配（字符串里写「# 表现」不再放行）；`RandomNumberGenerator.new()` 后第一句碰到这个发生器的语句必须定种子（`.seed =`，或注了放行的 `randomize()`），是 `if` 链就要有 `else`、每个分支都定种子，是 `for`／`while` 看循环体；同层不碰发生器的句子跳过（抽奖流先取存档字段那种）。
- P2-2 误报：`.new()` 后紧跟 `rng.randomize()  # 表现` 不再报；三引号字符串跨行跟踪，里面的 `randf()` 等不查。
- `测试随机守卫.py` 加 4 组用例（字符串里的假注释、单分支／缺 else／晚定种子、注了表现的 randomize、三引号多行），修前 4 条挂、修后 9/9 过；原 `test_unseeded_rng` 里「只有 if 分支定种子」那条预期正是 P2-1 要抓的，挪进分支用例改为应报。
- 验证：`随机守卫.py` 60 个脚本通过（现有 7 处 `.new()` 都按新规则过）；`测试随机守卫.py` 9/9；`工具回归.py` 全过。只改两个工具脚本，没碰游戏代码，Godot 测试沿用上轮。

## 交接板

- 下一步：甲档核查 `cc/tianqi-random-r1`（存档身份派生）；之后派 R2（ag，旧写法收进门面＋`tianqi_elements.gd` 两处兜底查能不能走到）；R3 等 Kyo 定方案第 4 节。
- 用户试玩说明：无（只搬家，老档随机身份与序列逐件相同）。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- `XTianqi` 的 10 个转发保留一个发行版本后删；删前跑 `rg 'XTianqi\.(save_stream|save_roll|seeds_on|has_seed_id|on_register|before_renumber|all_gear|assign_all|seed_id|item_roll)'`（现在只剩 `tests/xiyou_tianqi_seed_fix.gd` 和 S2 那三处复制路径的注释），顺手把 `xiyou_tianqi_seed_fix` 里的调用换成门面（S3 不碰它，可随 R2）。
- `随机守卫.py` 的范围现在借 `发行空壳.targets()`；清单制落地后直接读那份清单。

## 验证

- 本机专项（`并行测试.py`，12 个全过）：`xiyou_tianqi_random` 48/48、`xiyou_tianqi_seed_fix` 77/77、`xiyou_lottery_seed` 12/12、`xiyou_tianqi_affix_seed` 22/22、`xiyou_tianqi_drop` 85/85、`xiyou_tianqi_save` 51/51、`xiyou_tianqi_reforge` 16/16、`xiyou_tianqi_alien_gear` 57/57、`xiyou_star_warehouse` 99/99、`xiyou_tianqi_opening` 44/44、`xiyou_weak_challenge` 125/125、`xiyou_determinism` 372/372。
- 云端选测（`选测.py main` 因改了 `xstate.gd` 选中 507 个场景）：ea3fdfbd9d，507 个场景、9 片全部通过（GitHub Actions run 43624579816）。交付单之后的提交只动交付单。
- `语法检查.py`：874 个 `.gd`，0 问题。
- `工具回归.py`：全过（`测试选测.py CheckerTests CheckerStubParseTests` 32/32、`测试随机守卫.py` 5/5）。
- `随机守卫.py`：60 个天启篇脚本通过；`天启篇存档登记.py` 通过。
- 与在核查的 `xa/save-s2`、`xa/save-s3` 试合并（`git merge-tree`）都无冲突。

## 待交叉核查

- 甲档（存档身份派生，派单定）：
  - `modes/xiyou/core/tianqi_random.gd` 与 main 上 `tianqi.gd` 原 66～200 行逐字对比：只多了 `XTianqi.` 前缀（`SEED_FROM_SAVE`、`active`）、两处 `randf()` 行尾注、注释里「from_dict 末尾」改「XTianqiSave.after_load 末尾」、新增 `after_load`。
  - `tianqi.gd` 转发签名与默认参数（`on_register` 的 `source := ""`）。
  - `xstate.gd` 删 `assign_all` 那一行、`tianqi_save.gd` `after_load` 拆分（补号挪到 `ENABLED` 判断之外）。
  - 夹具是不是真在搬家前生成：`git show 24f615967`（门面先复制进来、`tianqi.gd` 未动）后 `git show <夹具重生成那次>` 时的 `modes/` 与 main 相同（生成时 `git diff --stat main -- modes` 只有新文件 `tianqi_random.gd`）。

## 本分支提交

- 24f615967 WIP：新建 XTianqiRandom（seed-fix 入口原样复制）＋搬家前存档夹具
- （其余见 `git log main..cc/tianqi-random-r1`）
