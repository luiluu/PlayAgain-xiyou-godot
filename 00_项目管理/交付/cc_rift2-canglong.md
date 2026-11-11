# 交付：cc/rift2-canglong

- 车道／工作者：A 内容·大厅＋C 规则·角色／项目线程「漩涡二阶段＋苍龙破晓实装」（cc，本机 Mac）
- 状态：可合并
- 分道：快车道（不碰切片、转换器、参照探针；Map004 在 XDB.map 读入时就地改）

依据：分支 `claude/project-thread-rapszm` 的方案交付单（第三节、三之二、第四节；Kyo 的 8 个小问题按草案默认），`cc/pro-canglong-numbers` 的数值表 v0.3（五招都乘真龙之力），Kyo 11-11 定的习得等级与「整体对标 0.8 倍狂刀」。

## 做了什么

**时空漩涡二阶段**（`modes/xiyou/core/rift.gd`，`XRift.STAGE2`）
- Map004 EV75 图换 `!Codex_Rift_Stage2`（1344×576，约两格宽，新素材在 `content/rift/`，`XDB.img_path` 转换产物里找不到 `!Codex_Rift_*` 时再到这里找），转速加倍（路线每步 6 帧→3 帧），调查文字换成「转得比上次快了。贴近了，能听见很远的声音。」，震屏弹回照旧。
- 新事件 201／202：(13,19)、(15,19) 无图挡路，调查同漩涡。203「时空漩涡_字幕2」：并行页每 30 帧看一次条件（rift1 播过、rift2 没播、且不是刚播 rift1 的同一次进大厅），满足就转自动执行页播：变暗 →「??????：你在这里，刷了很久了吧。」→ 闪光震屏 → 苍龙破晓（TZX04）甩出两格到 (14,21) 站起 →「此处……尚有人族的气息。」→ 淡出往南 → 小字「兑换大厅里，好像又多了点什么。」。先记 `rift2` 再播，全存档只播一次（配置 `codexWhisperSeen`）。204 是过场用的人物，平时无图。
- 「同一次进大厅」：`map_scene.load_map` 换图时 `XRift.on_map_setup` 记进图次数，`XConfig.whisper_mark('rift1')` 时记下当次；条件里的虚拟键 `rift1@thisvisit` 由 `XConfig.whisper_seen` 转问 XRift，不写盘。
- 切片 keepEvents 不列 201～204，`map_scene` 的过滤加了 `XRift.keep_event` 放行（不改切片，所以是快车道）。
- 给大厅异化线程的接口：`XRift.stage()`（开关开着恒为 2）、`XRift.canglong_drop_cell()`＝(14,21)，已经通过协调转告。

**苍龙破晓重做**（`modes/xiyou/core/canglong.gd`，`XCanglong.REWORK`）
- 职业 144 习得：被动 苍龙\*破晓 2、雷道之威 33、觉醒\*苍龙 50 不变；玉玺禁章 10、血浪 20、飞霄 30、诛灭 50（原 2 级）、逐道 60。
- 五招公式改走公式模块 `"canglong"`（`XFormulaExecution` 新一支，同流萤、米拉的写法）：玉玺／血浪 (物攻＋魔攻)×(1＋熟练)×5000、飞霄 (物攻＋魔攻＋幸运)×(1＋熟练)×3200、诛灭 八项属性和×85000、逐道 (物攻＋魔攻＋幸运)×TP×1000，全部再乘真龙之力 1＋等级²×2%（不封顶）。`formula` 文本同步改（智能 AI 的 `formula_safe` 认得），段数仍由动作序列定。
- 玉玺禁章去掉 9 类武器限制；逐道加冷却 3（`<Cooldown: 3>`，说明行同步）。
- 文字：五招「伤害」说明行换新公式；苍龙\*破晓的「真龙之力:\v[1497]」（v1497 是传承强化·极）换成真龙之力说明；【上邪】「专属:云无迹」→「专属:苍龙破晓」。

**解放 146**（`XImportedBalance.RELEASE_CANGLONG`）
- 146 不再算停用、隐藏；号角 274 不再算停用号角，回到兑换大厅号角商店（Map132 EV16 本来就有这一行）。招募照旧走 CE2506（入队、送【上邪】），超强者门槛照旧（地狱以下不能招）。
- 名单常量不动（参照测试照原版比），改了直接读常量的四处：破阵名单「（停用）」（`mv_script.gd`）、宝宝名单（`baby_all_actors.gd`）、商店过滤与能否购买（`item_marks.gd` 两处，改问 `horn_id_disabled`）。图鉴、仓库、出战、天启篇抽人走 `is_disabled_actor`／`is_hidden_actor`，跟着放开（天启篇发行版 RELEASE_OPEN 关着，开发版里 146 会进天启的候选）。

## 数值复核（原版引擎，Kyo 要的 dmg5）

在本机原版无画面引擎（`Game_GitHub/playagain_xiyou/sim/dmg5.cjs`，冻结 v0.62.12 只读，补丁只打内存）跑，脚本存成 [原版复核.cjs](../../03_再刷重制_Godot/00_设计/苍龙破晓数值/原版复核.cjs)。条件同草案：70 级、熟练 32、法宝 888、全暴击、保留强者压制、每回合回满 TP、智能挂机出招。

| 项 | 实测 | 数值表 v0.3 推算 |
| --- | --- | --- |
| 苍龙 70 级五回合 | **851.84 万亿** | 853.01 |
| 狂刀 70 级五回合（20 次平均，同种子） | 1066.63 万亿 | 1066.63 |
| 比值 | **0.799 倍** | 0.800 |
| 出招 | 逐道、诛灭、飞霄、逐道、诛灭 | 同 |
| 单次：玉玺／血浪／飞霄／诛灭／逐道 | 48.50／64.67／101.57／182.76／192.38 万亿 | 48.57／77.09／101.37／183.10／192.71 |
| 81 级（游戏上限）苍龙／狂刀 | 1152.53／1073.80 万亿＝**1.073 倍** | 约 1.07 |

- 习得越晚单次越高，五招顺序成立；血浪比推算低 16%（数值表那格是按公式推的，没实测），不影响顺序和总量。
- 草案「99 级约 1.59 倍」用不上：原版等级上限 81（dmg5 也按 81 设），81 级实测 1.07 倍，和 Pro 的粗估一致。
- 重制这边：专项按同一组属性比 `XDamage.eval_formula` 与手算公式逐招相等；重制里整场木桩没有跑（重制没有 dmg5 那套木桩工具）。

## 验证

- 新专项 `xiyou_rift2_canglong`：83 项全过（三个开关各开、关一组；关掉后 Map004、Skills、Classes、Armors 与转换产物逐项相同）。
- `xiyou_hidden_actors` 26／26（按原版比的一段先关解放开关，末尾开着加查图鉴少 6 名、仓库列出 146）。
- 选测（本机，`并行测试.py`，并行 2）：第一轮 70 个场景（`选测.py` 结论整轮，按影响面手挑：改动文件引用到的专项、事件对照四段、智能 AI 全部、`xiyou_determinism` 等）挂 19 个，原因两类：① rift1 看过的档进大厅会播 rift2 过场，占住大厅的测试（flow、hud、transfer、walk_speed、guide、map_dispatch、pause_save、screen_fx、floor_run）——`TestEnv.isolate` 和 9 个直接 `whisper_mark("rift1")` 的专项一并记 rift2；② 按原版比的参照测试碰到苍龙数据、Map004 或号角 274（event_compare 四段、actor_book、baby_all_actors、imported_balance、item_use、map132_shop、shop_buy）——在 `_ready` 调 `XCanglong.original_data()` 三个开关全关，同样处理了 xiyou_rules、actor_p0、help_card、action_sequence、formula_program、json_cache、map。
- 第二轮 29 个场景（上面挂的 19 个＋原版参照几组＋本专项）全部通过；`RULES_ONLY_ACTORS=146` 跑 `xiyou_rules*` 65 段全部通过；`工具回归.py` 全过；`语法检查.py` 通过。
- 合进 main（含 cc/lobby-corruption）后：`xiyou_lobby_corruption` 一项「rift2 播过前不见鳞」因 TestEnv 默认记 rift2 而挂，改成该专项开头去掉 rift2、关 `XRift.STAGE2`（它的阶段由 `STAGE_OVERRIDE` 指定），之后与 rift2_canglong、hidden_actors、guide、hangup_options、map_dispatch 一起重跑全过。
- 没跑：全量；`xiyou_rules*` 只跑了 146（别的角色的数据没动）。

## 待交叉核查（改到的共用核心文件）

- `core/xdb.gd`（Skills／Classes／Armors／Map 读入时打补丁、`img_path` 加 `content/rift/` 兜底）、`core/formula_execution.gd`（模块 canglong 一支）、`map/map_scene.gd`（进图计数、keepEvents 放行 201～204）、`core/xconfig.gd`（虚拟键 `rift1@thisvisit`、mark 通知）、`core/imported_balance.gd`、`core/item_marks.gd`（两处号角判断）、`map/mv_script.gd`（破阵名单「停用」）、`core/baby_all_actors.gd`。
- 别的车道的测试：`tests/xiyou_lobby_corruption.gd` 开头三行（见上）。

## 变更记录草稿

## 2026-11-11 【cc·未经审查】时空漩涡二阶段、解放并重做苍龙破晓（dev.待定）

- Kyo 11-11 定整包带漩涡二阶段、解放苍龙破晓并按 0.8 倍狂刀重做（方案见分支 claude/project-thread-rapszm 交付单，数值见 cc/pro-canglong-numbers）。
- 新 `XRift`（rift.gd）：Map004 读入时把漩涡换成两格宽的二阶段图、转得更快、换调查文字，加两格挡路和 rift2 过场（甩出苍龙破晓，落点 (14,21)），新事件 201～204；`XDB.img_path` 找不到 `!Codex_Rift_*` 时读 `content/rift/`；`map_scene` 记进图次数并放行 201～204。开关 `XRift.STAGE2`。
- 新 `XCanglong`（canglong.gd）：职业 144 习得改成 10／20／30／50／60 五招，五招公式走模块 canglong 并乘真龙之力 1＋等级²×2%，玉玺去武器限制，逐道加冷却 3，三处说明文字更正。开关 `XCanglong.REWORK`。
- `XImportedBalance.RELEASE_CANGLONG`：146 不停用不隐藏，号角 274 回兑换大厅号角商店，超强者门槛照旧。
- 玩家可见：兑换大厅的时空漩涡变大了，会甩出新伙伴苍龙破晓，号角商店能买到他的号角；他的五个招式随等级学会，伤害随等级成长。
- 验证：新专项 xiyou_rift2_canglong 83 项；原版引擎 dmg5 木桩 70 级 851.84 万亿＝0.799 倍狂刀，81 级 1.073 倍；选测见交付单。
- 未完成／已知问题：重制里没有整场木桩对照（只比了公式值）；rift2 过场、两格漩涡的画面没在真机上看。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·漩涡二阶段 | `modes/xiyou/core/rift.gd` `XRift.STAGE2`（`patch_map`，Map004；`map_scene.gd` 两行、`xconfig.gd` 两行、`xdb.gd` `img_path`） | v0.62.12 大厅时空漩涡只有一阶段（EV75～77、rift1 甩出流萤） | 漩涡二阶段：两格宽新图、转速加倍、新调查文字、左右挡路，rift2 过场甩出苍龙破晓（新事件 201～204） | Kyo 11-11 定整包出漩涡二阶段（时空裂缝方案 v0.7） | `XRift.STAGE2 = false` 后 `XRift.clear_cache()` | cc | 保留 |
| O-待定·解放苍龙 | `modes/xiyou/core/imported_balance.gd` `XImportedBalance.RELEASE_CANGLONG`（`released_actor`、`horn_id_disabled`） | 146 苍龙破晓 v0.30 起停用并隐藏，号角 274 不卖不能用 | 解放 146：不停用不隐藏，号角 274 回兑换大厅号角商店，超强者门槛照旧 | Kyo 11-11 定解放苍龙破晓，由漩涡二阶段引出 | `XImportedBalance.RELEASE_CANGLONG = false` | cc | 保留 |
| O-待定·苍龙重做 | `modes/xiyou/core/canglong.gd` `XCanglong.REWORK`（`patch_skills`／`patch_classes`／`patch_armors`、公式模块 canglong） | 苍龙只学到一个主动招，诛灭乘别人的除魔值恒为 0；10093～10096 学不到；说明里真龙之力指错变量、【上邪】写成云无迹 | 五招按 10／20／30／50／60 级习得，公式重定并乘真龙之力 1＋等级²×2%（不封顶），逐道加冷却 3，玉玺去武器限制，文字更正；70 级木桩 0.8 倍狂刀 | Kyo 11-11 定强度 0.8 倍狂刀、习得等级与真龙之力 | `XCanglong.REWORK = false` 后 `XCanglong.clear_cache()` | cc | 保留 |

## 交接板

- 下一步：真机看一眼 rift2 过场与两格漩涡（落点、遮挡、淡出）；三～五阶漩涡图已在原目录，以后的阶段照 XRift 加。
- 用户试玩说明：已招过流萤的档，下次进兑换大厅会播二阶段过场，之后号角商店有苍龙破晓的号角（地狱及以上或开挑战才能招）。新档第一次进大厅照旧先播流萤那段，下一次进大厅再播苍龙。
- 需要用户决定：无（草案里的 8 个小问题按默认：雷道之威、逐道吃 TP、生存被动不动；台词、站姿、二阶段文字照草案）。

## 进度账

- 冻结后扩展账：大厅时空漩涡二阶段、苍龙破晓解放与重做（新增内容，不进主表）。

## 可优化（流程／工具／效率）

- 已做：`原版复核.cjs` 把「把重制的数值打到原版引擎内存里跑 dmg5 木桩」做成一条命令，单角色约 9 秒，以后定角色倍率可照抄（删文件即回退）。
- 建议：重制里也做一个木桩专项（同 dmg5 条件），让「重制与原版逐值相同」能直接对，不用只比公式；归 C 规则车道。

## 本分支提交

- a4362df8d 漩涡二阶段、苍龙重做与解放初版
- 86f895e98 专项 xiyou_rift2_canglong
- 9185bc03b 隐藏角色专项改法；原版复核脚本
- bd9d3d814 原版参照测试关三个开关（`XCanglong.original_data`）
- e3400b4cd 测试记 rift2 看过
- （合并 main）、（本提交）大厅异化专项去 rift2、交付单可合并
