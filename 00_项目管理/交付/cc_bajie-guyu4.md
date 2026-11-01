# 交付：cc/bajie-guyu4

- 车道／工作者：B 界面（总装十派给八戒）／八戒（cc，八戒）
- 状态：可合并
- 分支从 cc/bajie-guyu3 末端 46047272 切（guyu3 被旧工作树占着，那边只有交接稿与 relic3 的提交），工作树 `.claude/worktrees/ecstatic-archimedes-4ef973`。
  guyu3 的交接稿 `cc_bajie-guyu3.md` 已并进本单并删掉；合并本分支即带上 guyu3 的提交。

## 变更记录草稿

## 2026-11-01 【cc·八戒·未经审查】谷雨 175 战斗界面：赠春／还春选择窗、侧栏储备状态字、立绘动作、万象长春盏说明条目（dev.待定）

- 照原版 `installNativeGuyuRuntime.js` 474～680 与 `installThreeGrowthRelicRuntime.js` 76～111 移植；新参照 `mv_oracle/guyu_ui_probe.cjs`（9 例，已登记进同步 PROBES，产物 `oracle/guyu_ui.json`）量原版的状态字、护盾合计、转移预览与说明（含不合法原因）、选择窗命令表与宽高光标、动作、法宝条目。
- **转移窗口**（新 `battle/guyu_transfer_window.gd`，`XGuyuTransferWindow`）：技能里选「借一枝春色」先开窗（宽 320、画面正中，每种比例「赠春（n%）」「还春（n%）」，没有能转的目标时灰掉；5～9 级只有 50%，10 级起 25／50／75%），技能窗留着不可操作、说明卡收起；取消回技能列表；选定把方向与比例写进这次行动（`XGuyu.transfer_mode／transfer_ratio`，行动结束 `end_action` 与开战 `reset` 设回给出 50%，自动战斗等没写的行动照原版按给出 50%），再选队友。选队友时说明卡写原版的转移说明（方向、比例、去向、储备量、受接收上限限制、待绽；不合法时写原因）；选自己或不合法的队友蜂鸣、留在选目标（onActorOk 包装）。之前固定给出 50% 的限制去掉。
- **储备条**（侧栏 `side_status.gd`）：谷雨在队的战斗中名字行右侧写状态字「储N」＋归根N／待绽／花期N／生长（10 号、#b7ead0，名字宽收到 76）；生命条上的护盾数值与蓝段按其他来源护盾＋花荫账本合计（重制的账本不并进 `b.shield`，所以相加）。演出中读日志里记下的值（`view_of` 加 guyu_shield／guyu_text）。
- **立绘与动作**（`battler_sprite.gd`、`battle_scene.gd`）：五个主动技换谷雨自己的动作（治疗 spell、花期 chant、转移 item、花荫 guard、终结 skill；归根中、绽放不换）；谷雨本人素材（battlerName Guyu、没有换装卡）不在移动时「走」改「待机」并定在第 0 帧（v0.28 待机稳定修复）；归根时脚下 48 帧金边瓷片与枯叶反馈（`XGuyu.visuals` → 行动末／回合末的 `guyu_visual` 记录 → 精灵画，不进存档、不用战斗随机数）。
- **万象长春盏说明卡**（`three_growth.gd`、`help_card.gd`）：同步时改写法宝备注——去掉原有 APs 行、每级成长与品质标签，写回品质 9、新的每级成长，倒序写 relicLines（专属：谷雨、等级需求、未进化时的进化说明、特效倍率成对、进化后的复活特效、法宝每级四行）；签名相同只改一次。说明卡显示时也同步（实例照原版定下进化；数据库原件复制一份按所属人物等级现算，不写回数据库）。
- 重制与原版的已知差别：原版同步也改数据库原件（$dataArmors），人物降回 60 级以下后原件仍是进化后的；重制只改实例，原件说明按人物现在的等级。原版「再生」的抽芽开花画面只排过 root、画不到，没移植。
- 改了原沙僧独占的核心文件：`battle_logic.gd`（act 与 end_turn 各加一行取谷雨画面记录；`view_of` 加两个画面字段），请重点核。
- 验证：见交付单「验证」。

## 发现的原版问题（已做成可回退开关）

- **O-待定（选择窗只露 2 行）**：原版在 createAllWindows 建窗，那时 BattleManager.actor() 为空、命令只有 2 行，窗高定在 100；10 级起打开时换成 6 行也不变高，三种比例只露 2 行、要上下滚（参照 `window` 例量到：打开后 6 项、页行数 2、光标 2、顶行 1）。重制默认窗高按命令行数；`XGuyuTransferWindow.FIT_ROWS = false` 照原版 2 行。
- **O-待定（转移说明卡位置漂移）**：原版每次换目标（Window_BattleActor.select 包装）都 setText，HelpExtend 的 setItem 在上一张卡的位置上再修正一次（x<900 右移 52、y 上下挪），卡片随换目标一路漂移，同 O-107 的毒鸡汤卡。重制默认贴在该队员左侧；`XBattleScene.TRANSFER_HELP_NEAR = false` 照原版漂移。原版选目标窗打开时 select 与 guyuUpdateTransferHelp 各调几次没逐帧量，回退支按「打开一次、每换一次目标一次、确定不合法一次」，没和原版截图核对。

优化登记表行（请总装编号并入 `03_再刷重制_Godot/00_设计/优化登记.md`）：

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | XGuyuTransferWindow（谷雨赠春／还春选择窗） | 建窗时命令只有 2 行，窗高定在 2 行；10 级起 6 个选项只露 2 行，要滚动 | 窗高按命令行数，6 行全露出来 | 原版窗高是建窗时机的副作用，不是设计；只露 2 行看不出还有别的比例 | `XGuyuTransferWindow.FIT_ROWS = false` | cc（八戒） | 待用户确认 |
| O-待定 | XBattleScene._transfer_help（谷雨转移选目标的说明卡） | 每次换目标都在上一张卡的位置上再修正一次，卡片一路漂移 | 贴在所选队员左侧，放不下放右侧 | 同 O-107：卡片漂走、还会盖住队员 | `XBattleScene.TRANSFER_HELP_NEAR = false` | cc（八戒） | 待用户确认 |

## 交接板

- 下一步：谷雨界面这一期做完。还没做的：CodexSV 新角色立绘归一（Codex_MiraRavenMultiFrame 的 normProfiles／inferProfile：ID 167 起的角色按可见边界缩到高 72、宽不超 129，脚底对齐；谷雨 profile 是 160×160、边界 [23,45,137,145]）——重制目前所有角色都按旧式 0.75 缩放，米拉、饿狼、云裳、谷雨、屠苏、璇都偏大，是跨角色的界面活，建议另派一条。
- 用户试玩说明：谷雨 5 级起在战斗里用「借一枝春色」会先弹出赠春／还春选择（10 级起可选 25%／50%／75%），选队友时说明卡写转移多少储备；右侧状态栏谷雨在队时每人名字旁写储备和花期／归根；谷雨施法有自己的动作，待机不再踏步；法宝说明卡写专属、进化与特效。
- 需要用户决定：上面两条 O-待定（选择窗窗高、转移说明卡位置），默认是优化后的样子。

## 进度账

- 谷雨 175：界面（转移窗口、储备条、立绘动作、法宝说明）由未做 → 做完；剩跨角色的 CodexSV 立绘归一。

## 验证

- 新参照 `guyu_ui_probe.cjs` 9 例无错；工作树 `同步正式西游.py --accept-additions`：测量不变（新增 guyu_ui.json 已接受，只重跑 3 个探针、其余 74 个复用），自动同步备份 `04_验证/本地结果/自动同步/20261101_084243_592451_v0.28-v0.28`。
- 新专项 `xiyou_guyu_ui` 790/790（窗口模式加截图 794/794，四张截图看过：选择窗 6 行与 2 行、侧栏状态字、说明卡贴队员左侧）。反向验证 4 处都抓到：选定不写方向比例（scene.target_mode 等 3 项）、花期剩余回合差 1（lv35 状态字 7 步）、FIT_ROWS 不起作用（window.original 2 项）、归根不发画面记录（script.sub.root_visuals）。
- 选测 27 个（合并 main 后、补齐与同步之后，并行 2）：xiyou_guyu、xiyou_guyu_battle、xiyou_guyu_ui、xiyou_three_growth、xiyou_help_card、xiyou_character_help_cost、xiyou_actor_book、xiyou_book_capacity_ui、xiyou_battle_ui、xiyou_costume_battle、xiyou_sequence_visual、xiyou_appearance、xiyou_battle_events、xiyou_shield、xiyou_otb、xiyou_poison_collapse、xiyou_race_battle、xiyou_panels、xiyou_battle、xiyou_action_sequence、xiyou_yunshang、xiyou_event_compare（必跑）、xiyou_rules.tscn、xiyou_rules_d1b、xiyou_rules_d1c、xiyou_rules_d1d 共 26 个通过；**xiyou_determinism 371/372**：`early_inventory_rule`（敌人倒下没掉装备，gear 0）。不是本分支引入的：白龙 `cc/bailong-yunshang9`（含同一个 main 909f5638、不含本分支改动）的工作树 08:39 与 09:13 两次跑都是同一条失败；主工作区 07:00 那次 372/372，所以是 07:00 之后合进 main 的批次（yunshang8／relic3／wukong-drops1 收尾一带）带来的，请总装查。
- `语法检查.py` 0 个问题。

## 可优化（流程／工具／效率）

- 建议：CodexSV 立绘归一做成通用（按 profile 或从首帧推断可见边界），一次解决 167 起全部新角色的大小，归界面车道。
- 无别的。

## 本分支提交

- 3917793d 谷雨界面参照 guyu_ui_probe，登记进同步
- fc5da81a 谷雨界面：选择窗、说明卡与选目标校验、侧栏状态字与护盾合计、待机定帧、动作、归根反馈、法宝说明条目；专项与反向
- 0b35a090 合并 main（云裳三期、relic3）
- 交付单草稿、同步、截图（本单）
