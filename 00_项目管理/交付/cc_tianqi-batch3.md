# 交付：cc/tianqi-batch3

- 车道／工作者：天启篇·第三批／cc（项目线程「完成再刷西游Godot引擎重制」，本机工作树 unruffled-mendel-f95b6d）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·天启篇·未经审查】天启篇第三批：五档难度与档位数值接进战斗、候选池与上限只认数值表、删一线生机与天道注视、选线骨架（dev.待定）
- 协调派单（第三批）：把五档难度和档位数值接进游戏，选线做成大厅单独事件（内容等四线），盘点余项能做的先做。只对天启篇存档（`XTianqi.active`）生效，原版档不变。
- **数值基准**：五档在数值上都按「艰险」跑，艰险借原版普通难度（Vitsuno 难度 3）。开局（`XTianqi.opening_commands`）五档一律走原版普通分支（`XTianqi.UNIFIED_LEGACY`、`legacy_of`）：普通难度被动、难度适应、普通的开局物品。原版各难度自带的倍率（敌人血量 ×75～×750、结算伤害 ×3／×1.5、难度适应 ×5 只有前三档有）差得太远，不再叠在新表上；难度差别只来自数值表。
- **敌人**（新 `core/tianqi_combat.gd` `XTianqiCombat.enemy_rates`，`XEnemy.setup` 调它）：基准倍率上 mhp 乘本档敌人血量、atk／mat 乘敌人攻击，其余能力照基准。敌人图鉴、真气、地图遇敌都走 `XEnemy.setup`，一起跟着变。
- **我方**（`XTianqiCombat.damage_mult`，`XDamage._calculate` 在独立乘区之后乘一次）：角色打出的伤害乘档位出伤（读攻击者档位）× 本档我方伤害 × 上场弱者协力出伤 × 助力位光环（助力位有人才给）；打到角色身上的乘档位承伤（读目标）× 协力承伤。协力只数出战栏前 4 格的弱者，助力位不算；直接读出战栏，不在伤害结算里整理队伍。治疗、吸收、敌人打敌人不乘。
- **单一来源**：`XTianqi.DIFFICULTIES` 去掉 `super_cap`／`min_weak`，`XTianqi.difficulty()` 从 `balance_table.json` 并进超强者上限、至少弱者、候选池；`XTianqi.pool` 按表里的 `pool` 取档位。`天启篇数据校验.py` 认 tianqi.gd 不再写这两项（写了才对照）。
- **删一线生机与天道注视**（`XTianqi.NO_HEAVEN_GAZE`，Kyo 11-08 数值重构）：天启篇存档里公共事件 1330（`CodexHeavenGaze.apply`）整段不做，不学 6212／6213。
- **选线骨架**（Kyo 11-11「选线做成单独的大厅内事件」）：存档字段 `flags.tianqi.line`、`XTianqi.LINES`（战争·莉co、死亡·勇者、瘟疫·混子、饥荒·小镇做题家；一句话说明是占位）、`line_of`／`line_ready`／`choose_line`、大厅里小小鱼主持的选线对话（排在通关抽角色后面，「再想想」留到下次）。`XTianqi.LINE_EVENT_OPEN` 默认 false，玩家看不到；选定后能不能换是 `LINE_CHANGEABLE`（默认不能，旧稿口径）。在哪儿出现、怎么呈现、没选线时怎么玩，等四线设计稿和 Kyo 定。
- 没动：天道诅咒（公共事件 1319，全员伤害 ×80%）和变量 8／9／12／13／14 是原版所有新档都有的基准，不是教派专属，照原版留着；`quality_offset`（装备品质偏移，表里标 draft）还没接，等装备掉落那批。
- 新专项 `xiyou_tianqi_numbers`（55 项）：五档敌人倍率与开关回退、同一只敌人炼狱对九死的血量和攻击比、防御不变、原版档照原版；各档位出伤／承伤倍率、协力只数上场弱者、助力位空着没光环、敌人打敌人恒 1、开关关掉和原版档恒 1；真实 `XDamage.calculate` 开／关的比值等于倍率（出伤、承伤各一）；五档开局都是 `Difficulty SetID 3`、开关关掉回到各借各的；上限与候选池同表；天启篇不学 6212／6213、开关回退、原版档照学；选线默认不出、打开后「再想想」、选定、不能再换、不认的线、存读档保留、原版档不收。`xiyou_tianqi_opening` 九死开局改按普通分支断言，`xiyou_tianqi_balance` 改用 `XTianqi.difficulty()` 对照。
- 玩家可见：天启篇存档的五档难度现在真的不一样了：敌人血量和攻击按档位表变（寻常最低、炼狱最高），开局不再按原版难度给不同的开局物品和难度被动；强者、超强者打得更狠、更耐打，上场弱者越多全队越强一点，助力位有人时全队伤害 +5%。一线生机和天道注视不再出现。

## 交接板

- 下一步：天启篇装备品质偏移（`quality_offset`）随装备掉落那批接；选线事件等四线设计稿与 Kyo 定后打开 `LINE_EVENT_OPEN` 并补内容；1 号角色写死的 39 处事件（盘点 1110 最后一节）还没逐条分类。
- 用户试玩说明：天启篇新开一局，各档敌人强度不同（同一层炼狱的怪血量是艰险的 2 倍）；整队页把强者、超强者换上场能看出伤害差。
- 需要用户决定：无（按数值重构草稿与 11-11 定的表做；数字都是表里的占位，实战校准另做）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·天启篇数值接线 | `modes/xiyou/core/tianqi_combat.gd` `XTianqiCombat.ENABLED`；`core/tianqi.gd` `XTianqi.UNIFIED_LEGACY`；`core/damage.gd`、`core/enemy.gd` | 难度各自按原版倍率与难度被动，没有档位出伤承伤 | 天启篇五档按艰险（原版普通）为基准、敌人按数值表乘血量攻击，伤害按档位、协力、助力位光环乘一次 | Kyo 11-08 数值重构方案、11-11 定的档位与协力数值 | `XTianqiCombat.ENABLED = false` 且 `XTianqi.UNIFIED_LEGACY = false` 回到第二批（五档借各自原版难度、伤害不读档位表） | cc（天启篇） | 保留 |
| O-待定·天启篇删一线生机 | `modes/xiyou/core/tianqi.gd` `XTianqi.NO_HEAVEN_GAZE`；`map/mv_script.gd` 公共事件 1330 | 弱者学一线生机 6212、非弱者学天道注视 6213 | 天启篇存档不学 | Kyo 11-08 数值重构「删掉一线生机和天道注视」 | `XTianqi.NO_HEAVEN_GAZE = false` | cc（天启篇） | 保留 |
| O-待定·天启篇选线 | `modes/xiyou/core/tianqi.gd` `XTianqi.LINE_EVENT_OPEN`／`LINE_CHANGEABLE`；`map/map_scene.gd` | 原版没有选线 | 方桌大厅单独的选线事件（骨架，默认关） | Kyo 11-11「选线做成单独的大厅内事件」 | 默认就是关的；`LINE_EVENT_OPEN = false` | cc（天启篇） | 保留 |

## 进度账

- 无（天启篇改版，不计重制完成度）

## 可优化（流程／工具／效率）

- 无

## 需要总装做什么

- main 上 `xiyou_input_handled` 现在就挂（`update_page.gd` 直接调 `set_input_as_handled`），请派自动更新车道改成项目统一的写法，和本分支无关。

## 验证

- `语法检查.py`：699 个 .gd 0 个问题。
- `工具回归.py` 全过。
- 本机专项：`xiyou_tianqi_numbers` 55/55、`xiyou_tianqi_opening` 41/41、`xiyou_tianqi_title_flow`、`xiyou_tianqi_balance`、`xiyou_tianqi_party` 全过（`xiyou_tianqi_party` 首跑 `helper_full_exp` 一次偶发、重跑通过，累计第 1 次，见下）。
- 反向验证（`反向验证.py`，4 项全咬住）：去掉伤害结算里的天启篇乘区、敌人倍率退回原版、一线生机拦截去掉、开局不统一到普通。
- `天启篇数据校验.py`：规则自检通过（另带 `--params` 对照见下）。
- 云端整轮选测（`云端选测.py run`，1c7b9d1c3，510 个场景、16 片）：509 过，只挂 `xiyou_input_handled` 的 `no_direct_set_input_as_handled`，指的是 `modes/xiyou/ui/update_page.gd`（自动更新车道 dev.454～456 合进来的，本分支没碰）直接调 `set_input_as_handled`；本机单跑同样挂，是 main 现有的问题，不是本分支引起的：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/43006662325
- 偶发：`xiyou_tianqi_party` 的 `helper_full_exp` 本机首跑一次（上场者 0 经验、助力位与替补有），重跑通过，云端整轮也过；累计第 1 次，再出就修测试。

## 待交叉核查

- 甲档：`core/damage.gd`（`_calculate` 多一个乘区）、`core/enemy.gd`（`setup` 的能力倍率）。
- 乙档：`core/tianqi_combat.gd`（新）、`core/tianqi.gd`（`difficulty`／`legacy_of`／`pool`／选线）、`map/mv_script.gd`（1330 拦截）、`map/map_scene.gd`（选线钩子）、`tianqi_data/balance_table.json`（只改说明）、`core/tianqi_balance.gd`（只改注释）、三个专项。
- 丙档：`03_转换工具/天启篇数据校验.py`。

## 本分支提交

- 86e936088 五档难度与档位数值接进战斗、候选池与上限改读数值表、删一线生机与天道注视开关、选线骨架
- 0ede2fa74 专项 xiyou_tianqi_numbers
- d2aee19c4 开局专项改断言
- 1c7b9d1c3 交付单（进行中）
- （本提交）交付单：可合并
