# 交付：claude/project-thread-d4k4ag

- 车道／工作者：天启篇·第二批／cc（项目线程「开始制作天启篇内容」，云端容器；第一批已在 dev.444 合并，本分支从合并后的 main 重开）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·天启篇·未经审查】天启篇第二批：上场 4 人＋助力位、每通关 5 层大厅抽角色、删号角与事件招募（dev.待定）

- Kyo 2026-11-10「开始吧」：按数值重构方案（Kyo 11-08 定）做第二批，只对天启篇存档（`XTianqi.active`）生效，原版档不变。
- **上场 4 人＋1 个助力位**：出战栏仍是 5 格，`XState.battle_members()` 在天启篇只取前 4 格（战斗、敌人强度、先发等都跟着它），新 `XState.helper()` 是第 5 格。助力位不上场、战斗胜利拿满经验（`XBattleLogic.grant`；西游 System 的「后备成员获得经验」本来就开着，替补也拿满，这条只在它关掉时才有区别），光环、技能共享照整栏 5 格算（`XSkillShare` 本来就按整栏），队伍能力（特性 64）也算助力位的装备。整队页第 5 格标「助力」。
- 超强者同一场上限只算上场 4 格（`XItemMarks.enforce_party`），助力位放超强者不算；`can_deploy` 多一个参数「放进哪一格」，先模拟换完再数。
- **战斗中换人**：角色指令多一条「换人」，和助力位互换，用掉这次行动；换上来的人接手被换下者在本回合／下回合剩下的行动顺序，出战栏两格互换，角色图和右侧状态行原地换掉。助力位倒下、超强者换上来超过上限时不出这条；专属模块角色（167～177、179，开战时另建本场数据）换不了。
- **通关抽角色**：已通关层数＝变量 20 − 1，每通关 5 层一次、最多 6 次，按 Kyo 11-08 确认的五档表（第几次 × 难度 → 档位、几选一、自选）。回到方桌大厅、没有别的事件时由小小鱼主持；X 选一的候选掷一次就记进存档（`flags.tianqi.offer`），不能重抽；可选「稍后再选」留到下次回大厅；自选先选档位再从本局还没有的角色里挑。
- **删招募**（`XTianqi.NO_RECRUIT`）：号角拿不到、商店不上架（只卖号角的店就是空的）；事件入队（指令 129）和各角色专属招募不再让新角色入队，提示「天启篇的伙伴只从方桌大厅的通关招募来。」开局阵容和通关抽角色照常入队。原大厅 EV15／EV19「抽卡」两个 NPC 在原版里页面条件到不了（变量 20 ≥ 100），本批没动。
- 开关：`XTianqi.NO_RECRUIT`、`XTianqi.SWAP_IN_BATTLE`（都默认 true）。
- 新专项 `xiyou_tianqi_party`（33 项）：上场与助力位、超强者上限只算上场、原版档 5 人；事件入队与号角拦截及开关回退；五档抽卡表、不到 5 层不能抽、候选不能重抽、6 次封顶、大厅对话（稍后再选、选第几个）；真实战斗里只上 4 人、换人指令与开关、战斗中换人（逻辑、角色图、状态行、出战栏）、换完打赢；按一份固定奖励发经验时助力位和上场者一样多。`xiyou_tianqi_opening` 的 `can_deploy_cap` 改按格判断。
- 玩家可见：天启篇战斗只上 4 人，第 5 格是助力位（拿满经验、光环照常，战斗中可「换人」）；每通关 5 层回大厅可抽一名新伙伴；号角和招募事件不再出现。

## 交接板

- 下一步：天启篇第三批：12 个装备栏＋第 13 栏「神器」（装备栏线程已开）；之后词条（v0.3 定稿）、档位数值。
- 用户试玩说明：天启篇新开一局，整队页第 5 格是「助力」；战斗里角色指令有「换人」。抽角色要通关 5 层后回大厅（测试时可在调试里把变量 20 改成 6 再回大厅）。
- 需要用户决定：无（默认按草稿做）。可以以后再定的两处：通关层数取「变量 20 − 1」；换人用掉这次行动。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·天启篇招募 | `modes/xiyou/core/tianqi.gd` `XTianqi.NO_RECRUIT`；`XState._add_actor`、`XItemMarks.can_acquire_item`、指令 302 | 号角、号角商店、招募事件让角色入队 | 天启篇存档只从开局阵容和大厅通关抽角色得到新角色 | Kyo 2026-11-08 数值重构方案「招募改成通关抽角色」 | `XTianqi.NO_RECRUIT = false` 照原版招募（也不再抽角色） | cc（天启篇） | 默认开 |
| O-待定·天启篇换人 | `modes/xiyou/core/tianqi.gd` `XTianqi.SWAP_IN_BATTLE`；`XBattleLogic.tianqi_swap`、`XBattleScene._tianqi_swap` | 没有助力位 | 战斗指令「换人」和助力位互换 | Kyo 2026-11-08「助力位战斗中可切换」 | `XTianqi.SWAP_IN_BATTLE = false` 不出这条指令 | cc（天启篇） | 默认开 |

## 进度账

- 无（天启篇改版，不计重制完成度）

## 可优化（流程／工具／效率）

- 建议（沿用第一批）：云端容器没有 zsh，`工具回归.py` 里调 `检查.sh`／`新建工作树.sh` 的三项在云端线程必挂；可让这三项缺 zsh 时跳过并打提示（哪吒，工具）。

## 验证

- `语法检查.py`：681 个 .gd 0 个问题。
- 专项 `xiyou_tianqi_party` 33/33；`xiyou_tianqi_opening` 41/41；相关场景 `xiyou_party`、`xiyou_super_acquire`、`xiyou_super_deploy`、`xiyou_shop_buy`、`xiyou_lobby_shops`、`xiyou_battle` 本地全过。
- 选测：GitHub 云端选测（workflow_dispatch，本分支 6a32209f8，基准 origin/main，14 片）：13 片全过，片 11 只挂了本专项的 `helper_full_exp`（自动战斗打敌群 2 的掉落经验在云端是 0，本机不是）；改成按固定奖励直接发经验后本机 33/33，
- 云端单跑（a1007db9c）：`xiyou_tianqi_party` 33/33、`xiyou_tianqi_opening` 41/41：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42930697904 。全量选测在 6a32209f8：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42926889569 （之后只改了专项本身和交付单）。

## 待交叉核查

- 甲档：`battle/battle_logic.gd`（`can_tianqi_swap`／`tianqi_swap`、经验）、`battle/battle_scene.gd`（换人指令与 `_tianqi_swap`）、`core/xstate.gd`（`battle_members`／`helper`／`_add_actor`）、`core/item_marks.gd`（`can_deploy`／`enforce_party`／`can_acquire_item`）。
- 乙档：`core/tianqi.gd`（抽角色）、`map/map_scene.gd`（大厅抽角色钩子）、`map/mv_interpreter.gd`（号角不上架）、`ui/party_scene.gd`、两个专项。

## 本分支提交

- 6a32209f8 天启篇第二批：上场 4 人＋助力位（战斗中换人）、每通关 5 层大厅抽角色、删号角与事件招募
- d6154a0b2 交付单草稿
- a1007db9c 专项经验检查改按固定奖励直接发
- （本提交）交付单：可合并

- 车道路径：无（云端容器做的；本分支没改切片、转换器、探针，合并不用重同步）
