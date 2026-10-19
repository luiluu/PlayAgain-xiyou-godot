# 交付：claude/quirky-pasteur-5de601

- 车道／工作者：A 内容／解释器／悟空（Claude，重制_悟空_16）。派单写的工作树是 `wukong-interp-core`，本会话被限制在 app 自建的 `quirky-pasteur-5de601`，分支相应改名，内容同一任务。
- 状态：可合并

## 变更记录草稿

## 2026-10-19 【Claude·悟空·未经Codex检验】地图与战斗共用游标式事件解释器核心；战斗内 101 对话、334～336（架构审查第 8 项，dev.待定）

- 新 `core/mv_event_core.gd`（`MVEventCore`）：Game_Interpreter 的指令语义只写这一份（文字／选项／数值、条件分支、循环与跳出、标签、公共事件子游标、开关／变量／独立开关、金钱物品装备、队员、等级、技能、状态、全回复、插件指令等）。`advance()` 从游标一直执行到需要外部处理为止，返回 `done`／`message`／`command`（及子类请求）；`resume(应答)` 续上。公共事件同 MV `_childInterpreter` 建子游标，请求带发出它的那一层。环境相关的部分是虚函数（`_execute_env`、`_condition_env`、`_game_data`、`_party_members`、`_change_actor_state`、`_plugin_env`、`_data_changed`、`_treasure_popup`、`_make_child`）。
- `map/mv_interpreter.gd`：`MVInterpreter extends MVEventCore`，`run()` 在外面包一层 await：文字交 `host.show_message`，宿主指令（场所移动、画面、声音、战斗、商店、脚本 355 等 `HOST_CODES`）由发出请求的那一层 `_host_command` 执行。对外接口（`run`、`host`、`map_id`、`event_id`、`_depth`、`list`、`pending_lines`、`receipt`、`last_gain`、`skipped`、静态 `random_*`／`max_steps`／`fixed_random`）不变。
- 新 `battle/battle_event_runner.gd`（`XBattleEventRunner extends MVEventCore`）：战斗环境只接 333～336、339、敌人条件（111 类型 5）、敌人游戏数据（122 类型 4）、出战成员、战斗背景卷动插件（只记 `event_view` 记录）。删掉 `XBattleLogic._run_troop_list`／`_troop_condition`／`_troop_set_variables`／`_skip_branch`。战斗里因此也认得了原来不认的条件／变量写法（角色条件 111 类型 4 等）。
- `XBattleLogic` 敌群事件驱动（`troop_events`／`resume_event`／`is_event_waiting`／`event_waiting`／`run_events`）：101 时停在游标处，记录最后一条为 `{type: "message", msg, token}`；等待中再检查返回空（不重新选页、不推进），页的 span≤1 flag 在选页时就提交；`resume_event(token, 应答)` 续上本页与本次检查剩下的页；token 不对（重复确认、上一场）无效；`setup`／`end_battle` 清游标。`run_turn` 等无界面宿主走 `run_events`，消息由 `message_responder` 应答（未设置时确认）。339 强制行动仍当场结算，运行器回 `forced_action` 后继续。
- 稳定成员 slot：敌群全部成员（含隐藏）在 setup 时建出，`XEnemy.hidden`；隐藏成员 `is_alive`／`is_dead` 都为 false（isAppeared），不算胜负、不给经验掉落（deadMembers）、加不上状态（`sequence_add_state` 改查 `is_alive`，对非隐藏者等价）。`make_unique_names` 照 Game_Troop.makeUniqueNames（出现时分配字母、同名 ≥2 才显示，按原名计）。
- 334 完全回复（索引 −1 含隐藏成员，TP／buff 保留，隐藏不变）；照冻结源参数缓存，回满用清状态之前的上限（状态 77 时 HP 停在 80000000000）。335 只去隐藏标记并 makeUniqueNames，资源状态不变，死亡者出现仍死亡；行动顺序不当场改，824 出现者首次行动在 T3（与参照一致，未改 OTB）。336 原地换 `enemy_id`，HP/MP 绝对值保留截到新上限，TP／状态／buff 保留，不重抽神话／等级；原名变了清字母。敌人变化都写 `enemy_change` 记录（slot、前后读数、views）。
- 战斗画面：`_play_troop_events` 按记录播放，遇消息用 `XMessageBox.run` 显示，确认后 `resume_event` 再播后面的记录（自动／挂机按消息窗已有设置翻页）；隐藏成员不画本体与血条，出现时显示，变身时重建该成员的战斗图。
- 测试：新 `tests/xiyou_battle_events` 96 项全过，逐项消费 `oracle/battle_events.json` 8 例：165 的 T1～T4 变量 112、每回合敌人读数、T4 一次 101（文字、头像、背景、位置）、消息未关时身份仍 174／页 flag 已置／再检查不重入、确认后 334→336、T4 起出新形态的招、T5 不重复、最终读数；334 两例（死亡复活、隐藏成员与状态 77 缓存）；336 两例（读数）及变身后选招属新形态；824 变量 1178＝5／6 的成员数、333 只加在可见成员、字母、敌方首次行动回合（e1～e5 为 T3）、受伤／死亡的隐藏成员出现后读数不变；另有旧 token、重复确认、结束清游标、隐藏不算胜负与经验。
- 工具：`内容覆盖检查.py`、`事件指令统计.py` 改读 `mv_event_core.gd`＋`mv_interpreter.gd` 两份（按 match 分支认指令，语义移进核心后只读地图文件会把 101 等报成未翻译）；`测试内容覆盖.py` 随之改 mock。随机数与步数静态量（`random_*`、`max_steps`、`fixed_random`）移进核心，仍可用 `MVInterpreter.xxx` 访问。
- Godot 4.7 坑：协程跨 await 留着指向游标自己的类型化局部变量时，宿主场景先释放会让游标留在内存里，退出报「resources still in use」（xiyou_options_basic、xiyou_hangup_options 撞到）；请求字典因此不带游标，改用 `waiting_frame()` 取应答层，`MVInterpreter._step` 跨 await 不留局部引用。
- 验证：`检查.sh --oracle` 全部通过（Godot 测试 73 个场景，含新 xiyou_battle_events；内容覆盖无新问题）；专项 xiyou_troop_events 4320、xiyou_event_compare 5、xiyou_dungeon 5662、xiyou_flow 48、xiyou_script 17、xiyou_battle 8、xiyou_combat 34、xiyou_zhenqi 系列全过。事件对照 baseline 未变（不退步）。
- 提交：见下「本分支提交」
- 未完成／已知问题：
  - 十六层副本未解锁：要扩切片（Map033 副本入口 1、Map044 亚特兰蒂斯秘境、敌群 165／796 等），留下一批。
  - 消息窗在战斗里的位置、名字框转义（`\n<海拉的幻影>`）只接了已有 `XMessageBox`，未做冻结版与 Godot 截图的标准级画面对照。
  - CodexBossDifficulty 霸体 2651（偶数回合）重制版没有，测试比状态时去掉 2651；336 的形态同步因此也没有。
  - 敌人出招是 Godot 随机评分，参照固定 Math.random＝0.5 选到 4023；测试只比「出的是新形态 175 的招」。
  - 隐藏成员现在在 setup 时建出：含隐藏成员的敌群开战时多几次随机数（神话判定、等级、开战 TP），之后的随机序列与原来不同（与 MV 建全体成员一致）。这是 `XBattleLogic.setup` 的敌人建立处，不在沙僧公式／随机数改动的伤害主链上，合并时留意与 `codex/formula-rng-implementation` 的随机上下文改动是否碰到同一段。
  - 预分配 O-055 未使用（334 缓存、335 延迟都照冻结源，没有做可回退优化）。

## 框架补充（请唐僧并入框架维护约定「战斗内 101 对话与敌人变化」，标为已实现的部分）

- 接口与目标一致处：`XBattleEventRunner.advance()` 返回 `message`（对应目标的 message_requested）、`forced_action`（forced_action_requested）、`done`；`continue` 不单独返回，运行器内部循环直到需要外部处理。已提交日志由 `take_logs()` 取走。
- 补充：消息的 token 与续上放在 `XBattleLogic`（`troop_events`／`resume_event(token, 应答)`／`is_event_waiting`／`event_waiting`／`run_events`），不是运行器自己；游标状态是 `_runner`（页游标，含公共事件子游标、分支、first_subject）＋ `_check`（本次检查的 first、turn_end、瞬间页、guard）＋ `_waiting`。
- 补充：339 强制行动没有改成交给画面再续上，仍由规则当场结算后继续（与原 `_run_troop_list` 相同）；运行器回 `forced_action` 只表示有新记录。若之后要让画面先演完强制行动再执行后面的指令，可在驱动里把 forced_action 也当作停点。
- 偏离目标：`XEnemy.transform_to(enemy_id, context)` 没有做成 XEnemy 方法，变身写在 `XBattleLogic.enemy_transform`（要改字母表与 makeUniqueNames，那是 Troop 层的状态）；「已有待行动才重选」因本工程敌人轮到时才 decide，自然按新形态选招，不另生成待行动。
- 「地图事件与开局」一节的 `MVInterpreter` 说明可补一句：指令语义在 `MVEventCore`，`MVInterpreter` 只包 await 与宿主指令。

## 交接板

- 下一步：十六层副本解锁（扩切片：Map033 副本入口 1、Map044 亚特兰蒂斯秘境全图、敌群 165 与守护者 796 等，并加楼层流程测试）；战斗内消息窗的标准级画面对照（冻结版与 Godot 截图、窗口矩形、名字框）。
- 用户试玩说明：战斗里敌群事件的对话会弹出消息窗，确认后才继续；敌人可以中途出现、变身（现有切片里能遇到的有 456～458 守层者生命 ≤20% 时的对话等）。
- 需要用户决定：无。

## 进度账

- 不改完成度（十六层仍未解锁）；战斗内事件规则侧完成，画面待标准级对照。

## 本分支提交

- a994b1d WIP: 共用游标式事件解释器核心 MVEventCore，地图 MVInterpreter 改为外包 await
- 8eb4d0e WIP: 战斗事件运行器 XBattleEventRunner（共用核心），101 挂起与续上、334/335/336、隐藏成员 slot；删 _run_troop_list
- 3aeac8f WIP: tests/xiyou_battle_events 逐项对照 battle_event_probe 8 例（96 项通过）
- ce673e1 合并 main
- 3827ad9 WIP: 交付单（进行中）
- fb0196d WIP: 静态量移入核心；请求不带游标引用；内容覆盖与指令统计改读核心文件
