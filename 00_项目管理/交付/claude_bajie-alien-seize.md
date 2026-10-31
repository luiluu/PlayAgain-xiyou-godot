# 交付：claude/bajie-alien-seize

- 车道／工作者：C 规则／八戒_90（Claude，Opus／medium）
- 状态：可合并
- 夺舍方案已审（审查第 1 期 A1～A6），按审查意见改了第 2 步再做。

## 变更记录草稿

## 2026-10-30 【Claude·八戒_90·未经审查】O-121 回退支照原版；异化夺舍（dev.待定）

1. **O-121 回退支照原版**（审查第 2 期 D1）：`XSmartAI.o_projection = false` 原来回到的是重制以前的「全程读原技能」，不是原版。改成照原版 `Codex_SmartBattleAI` 混读：目标方向、范围（对敌／对友／全体／随机／段数）读投影（`directed`，原版 `action.item()`），回复、护盾、增益、伤害估值读原技能（`valued`，原版 `candidate.item`）；全 0 分退回「普攻打 HP 最低的敌人」时，攻击投影成友方单体的（逆祷），目标照原版 `setTarget(敌人序号)`＋`smoothTarget` 落到同序号的队友。开关开着时行为不变；非异化角色两支都不变。
   - 断言（`xiyou_smart_ai` 第 0 份 `alien.off.*`，按原版源码的结果写）：逆祷攻击候选目标是队友、0 分，退回普攻目标是同序号队友；祸祝 7100 目标是敌人、0 分。
   - 反向验证：方向也改回读原技能（旧回退支），`alien.off.*` 三项失败。
   - 优化登记 O-121 的「如何恢复原版」一栏同步改写。
2. **异化夺舍**（期二，Adv:11、36-37、72、80、85-86、105、196）：
   - 锁队（`setup_possession`，接在 `lock_party` 末尾）：用**未过滤**的名单锁队，队友自己的异化装备照样冻结（审查 A2：队友穿饕餮，法力 → 0）；队友记 `xalien_possessed_by`，夺舍者记 `xalien_possession`（队友安全被动的备注，接在 `trait_objects` 的 `gear_effects` 后；MV 技能没有特性字段），刷新夺舍者被动缓存；之后把队友从本场 `logic.actors` 拿掉（不上场、不行动、不被选为目标、不算全灭，经验按后备倍率）。
   - 出战名单（审查 A3）：照原版 `battleMembers` 包装在 `XState.battle_members()` 里全局过滤（战斗中且有夺舍记号），不逐个审调用处。羁绊开战刷新（`map_scene` 的 `XPartySkills.battle_start`）在开战前、看到的是未过滤名单，同原版（Star_JiBan 的 startBattle 包装在异化锁队之内、onBattleStart 设 inBattle 之前）。
   - 开战先后（审查 A1）：`battle_logic.setup` 里原版在 `BattleManager.setup`（锁队之前）的读取——敌人等级、强敌计数、成员身份、逃跑率——仍含队友；原版属于原 startBattle（锁队之后）的——开战移除状态、初始 TP 与开战状态效果、预热——以及外层的种族 startBattle 包装（原版 race 包装在异化之外，先调原函数再建数据）不含队友。用 `possession_partners`（不改状态，同 `eject_invalid` 的判定）预判；`XAlienBattle.start` 之前名单换回全员给锁队用。
   - 技能表（Adv:37、86）：`skill_ids` 接点加队友已学会的 possessionSkills 与队友的安全被动（`safe_passive`：被动、无效果、备注没有黑名单词、至少一个标签且全在白名单；被动不要求已学会，审查 A4）。
   - 倒下同步（Adv:105，`sync_possession` 放在 `sync_relations` 开头、不受状态类／生命池早退影响）：夺舍者倒下而队友没有阵亡状态→队友生命 0、加阵亡。行动外扣血（事件 311、腐蚀）经 `after_outside_hp` 也同步；即死（直接附加阵亡）到行动结束 `finish` 才同步（审查 A6）。
   - 结束（Adv:196，`unpossess`，在 `end` 开头）：清记号、队友按原名单位置放回 `logic.actors`，之后的还原（饕餮法力、吞器衣服栏等）照原版按全队做；队友身上的阵亡不还原。重新锁队（测试夹具）前也先放回。
   - 参照：`alien_affix_probe` 加 `allyLevel`、`allyAffix`（队友自己穿异化武器）与夺舍读数（出战名单、敌人等级、借来的 9 火焰／被动 16 剑道天赋在不在技能表、9 能不能用），三例 `battle.possession`（角色 1 35 级、队友 8 90 级：名单 [1]、敌人等级 90、借技能能用、普攻、夺舍者被事件打死队友跟着阵亡）、`.glutton`（队友穿饕餮：法力 0）、`.invalid`（队友已倒下：卸下）。原版读数与审查实测一致。
   - Godot 侧另断言（原版源码）：结束后队友仍阵亡、记号清掉、回到名单；即死到行动结束才同步。
   - 反向验证：去掉 `battle_members` 过滤 → possession 两例名单读数失败；去掉 `sync_possession` → 队友倒下失败；去掉借技能 → 技能表读数与普攻 9 的伤害失败。都已还原。

## 交接板

- 下一步：期三星级仓库（审查第 1 期 B1～B3 与沙僧 Q1～Q3 一并处理）。
- 用户试玩说明：穿夺舍的角色开战后能用绑定队友学会的登记技能和被动，队友不上场；夺舍者倒下时队友一起倒下，战后队友仍是阵亡。
- 需要用户决定：O-121 去留（回退支现在照原版）；夺舍战后队友仍阵亡、夺舍者复活队友不复活，照原版，方案里的两个 O 号候选仍待用户定（本期没做）。

## 进度账

- 异化：最后一条词条夺舍完成。

## 可优化（流程／工具／效率）

- 建议：`xiyou_book_capacity_ui` 在云端选测里稳定失败（提示框尺寸差 10 像素，main 也一样），Mac 上通过——云端字体度量不同；云端会把每个分支都标红，宜给这个测试换成相对度量或在云端跳过尺寸项（归工具车道）。

## 待交叉核查

- 原沙僧核心文件：`battle_logic.gd`（`setup` 里 `everyone`／`leaving` 的先后与逃跑率）、`xstate.gd`（`battle_members` 过滤，全局热路径：一次 has_meta）。
- `alien_battle.gd`：夺舍段（`possessed`、`safe_passive`、`possession_skill_ids`、`possession_partners`、`setup_possession`、`sync_possession`、`unpossess`）、`lock_party` 接 `unpossess`／`setup_possession`、`sync_relations` 开头、`after_outside_hp`、`gear_effects`、`skill_ids`、`end`。
- `smart_ai.gd`：`directed`／`valued`、`score_candidate` 的 dir、`recovery_utility`／`benefit` 的 dir、退回普攻目标。
- 探针 `alien_affix_probe.cjs`（allyLevel、allyAffix、夺舍读数、三例）。

## 验证

- 合 main（70a281fa，带来切片、两个探针与 battle_logic／xstate 的改动，无冲突；前一次合 main 优化登记 O-120／O-121 行冲突，取 main 的 O-120、本分支的 O-121）后，`新建工作树.sh --补齐` 与 `同步正式西游.py --accept-additions` 都通过（「新增用例，已接受（不登记）」，alien_affix 54 例），留了产物指纹。
- 本地专项：`xiyou_alien_affix` 1999/1999（新 3 例逐步对照＋夺舍 5 项结束／即死断言）；`xiyou_smart_ai` 第 0 份的 `alien_projection` 6 项（开 3／关 3）。
- 选测（253 个场景，超过 40 个按新规走云端 `云端选测.py run`，13 片，运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41151419334）：252 个通过；`xiyou_book_capacity_ui` 失败（提示框尺寸 toast.*.boxRect／textHeight 差 10 像素），**main 自己的云端选测（41150258069）同一场景同样失败**，像是云端字体度量与 Mac 不同，不是本分支；本机单跑通过（85/85）。
- 反向验证：见变更记录草稿各项（O-121 关开关 3 项；夺舍过滤、倒下同步、借技能三处）。都已还原。
- 没跑全量与非 Godot 检查。

## 没做／差异

- 夺舍的 `xiyou_battle_ui` 检查（被夺舍的队友不出现在状态窗与行动条）没加：界面按 `logic.actors` 建，锁队在建界面之前已拿掉队友。
- 审查 A5「同一标签经 trait_objects 备注与被动缓存读两遍」：照原版接了两路（possessionTraits 备注＋技能表里的被动），没另核哪些读者会读两遍。

## 本分支提交

- 见 git log（claude/bajie-alien-seize）。
