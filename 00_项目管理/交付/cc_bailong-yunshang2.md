# 交付：cc/bailong-yunshang2

- 车道／工作者：E 角色专属／白龙_9（cc）
- 状态：可合并
- 分支从 cc/bailong-yunshang1 末端 86c69d8e 切出（总装九派单），**包含云裳第一期**：一期还没合的话，合本分支就一起合进去（一期交付单 cc_bailong-yunshang1.md 照样有效）。main 在切出后没动。

## 天衣分批（15 件，key＝本体−7920；谁穿谁吃效果）

| 批 | 天衣 | 为什么放这批 |
| --- | --- | --- |
| A（本期） | 8 六衡裁身、9 寸光留仙、11 同袍换日、13 万法同裳、14 七曜流霞 | 只靠觉醒和行动队列：9、11 就是储行／赠行行动来源（异化等着它）；13、14 是伤害钩子 split 的两种分段；8 只改能力值 |
| B | 0 山河作骨、1 百厄成锦、2 赊月偿星、3 不渡黄泉、4 逆命换锦、5 千军入袖、6 空袖藏星、7 九曲回针、10 孤灯照众、12 一身两世 | 0／2／12 要派生伤害的分担、赊账、复演；1／4／10 要状态复制 stateCopy；3 是幽灵；6 借技能；5 收袖要战斗指令窗切换（_yunSleeve）与溢出；7 针眼要天衣铺战前选技能 |

派生伤害（derived）、觉醒、行动来源三样基础 A 批都做好了，B 批的天衣直接接在上面。

## 变更记录草稿

## 2026-11-01 【cc·白龙_9·未经审查】云裳第二期 A 批：觉醒、收针、余辉、符针、御风、赠行／储行、天衣 8／9／11／13／14（dev.待定）

照原版 installNativeYunshangRuntime.js（行号是该文件的）：data／awake／setting 第 33～45、220 行，Y.wake 第 214～219 行，resetRound 与 startBattle／startTurn／endTurn／endBattle 包装第 226～246 行，
skills／meetsSkillConditions 第 248～256 行，stateAdded 不涉及（B 批），derived／burst 第 330～339 行，prepareAction／startAction 第 380～394 行，applyCommand 第 395～406 行，
apply 包装第 407～422 行，addActions／getNextSubject／freeGift／storeActions／release／cut 第 437～447 行，伤害钩子 split／build 第 749～773 行，扩 `XYunshang`：

1. **战斗数据**：每个穿天衣的出战成员一份（换一件天衣、换一场战斗就重建）；round＝开战 1、每回合 max(1, 回合数)。
2. **觉醒**（`wake`）：敕衣点神 10273 命中穿天衣的队友唤醒到下一回合末；天衣无缝 10281 开战全醒；神纹自鸣 10275 每回合开始随机唤醒一个没醒的；首次唤醒时六衡裁身按觉醒重裁；戴织神天梭的云裳在场时得「余辉」，下一次主动伤害结算 ×1.33。异化绝缘（外来）挡唤醒。
3. **收针** 10274：选一个觉醒者（重制没有战斗里的选择窗，`XYunshang.wake_target` 给就用，不给照自动战斗 aiGather：剩余回合最多、不是自己优先），伤害 ×剩余回合数，并消耗他的觉醒；没人觉醒不能用。
4. **符针**：钉影命中每个目标种 1／2（银针织阵）／3（千丝成阵）根，倍率 1／0.555／0.4（双针 ×0.555、非主目标照展幅档），记下种针时的魔攻与余辉；敌人行动前引爆身上全部（派生伤害：符针结算 10286，戴梭结算 ×1.99、必暴击），并让这次伤害 ×0.67（钉影虚弱，一次）；穿天衣且觉醒的人造成伤害后引爆目标一根。派生伤害不判命中、不吃双针／展幅、不种针，暴击照 itemCri 掷。
5. **御风** 10272：命中后全队敏捷 ×1.33 到下一回合末，本回合还没行动的队友按敏捷排到队列最前。
6. **行动来源**：队列加行动带标签（原有／赠行／储行），getNextSubject 取出时记下（`took`）。同袍换日 11 给赠行 10284（赠队友 1 次，每回合 3 次；受赠与储存的行动不能再赠），觉醒后 `free_gift` 每回合免费赠 2 次（同一人每回合最多 2 次，绝缘挡）；寸光留仙 9 给收存余光 10285（收起队列里自己剩下的原有行动，再多存 1 份，最多 3），`release` 每回合一次放回（觉醒时每份 2 次），觉醒时每回合开始多存 1 份。
7. **异化**：`alien_battle.gd` 的百相切换仿形条件、蚀术解封窗口照原版排除赠行／储行的行动（`XYunshang.source_original`）；绝缘挡唤醒、加行动、免费赠行。
8. **六衡裁身** 8（`cut`）：选一项，其余五项按本回合快照各 33% 裁入它、自身 ×0.67；觉醒改两项（不够自动补第一个没选的），其余不降；回合末清除。重制没有战斗指令窗，`XYunshang.cut` 给 API，自动战斗那套（魔攻≥物攻选魔攻＋敏捷）是 B 批 AI。
9. **万法同裳** 13：物攻／魔攻各取两者较高；伤害钩子 categoryMax（物理／元素加成取较高）；觉醒时伤害分物理、魔法两路各算一次再相加。
10. **七曜流霞** 14：没醒时伤害元素换成选定的一个，觉醒时换成元素组（天衣铺战前设置是养成期，先用原版默认：元素组 2、3、4，当前 2）。
11. **拆神** 10271 的驱散（一期漏了）：命中后去掉目标第一个普通增益，成功时队伍里（醒着的先）第一个有普通减益的去掉一个（减益表含异化加进来的 statePairs 诅咒与腐蚀）。
- 一期的能力值包装去掉了自己的取整夹值（哪吒 dev.246 的 `XActor.final_clamp` 就是原版这一层，总装八提醒别重复）。
- battle_logic.gd：开战、开回合、回合末、结束战斗、取下一位行动者、startAction（prepare，被符针打倒就整次取消）、apply 之后、伤害计算（分段）各一行；actor.gd：param 战斗内层、skills 天衣技能各一行。
- 参照：`yunshang_probe.cjs` 加 11 例 p2.*（battle2：真实 startBattle＋startTurn）；天衣有等级需求，穿不上原版不生效，各例按需求给等级。
- 专项 `xiyou_yunshang` 419 项（一期 225＋二期）：每步比回合、觉醒、战斗数据、标签、队列里 174 与 1 号的行动数增减、余辉，以及能力值、敏捷、符针数、能不能用；伤害按行动者分组比比值。

## 优化登记草稿

优化登记草稿：无（本期没有改原版行为的地方）。

## 验证

- 专项 xiyou_yunshang 419/419（直接跑与并行测试都过）。
- 反向验证（逐个改、各自单跑，已还原）：余辉、御风、赠行上限、裁身比例、万法两路、千丝倍率、收针回合、储行加份、觉醒期限、七曜元素、万法取高、放行翻倍、免费赠 2 次、钉影虚弱各自都有失败（1～26 项）；categoryMax 改掉不失败（本例没有带 SelfPhysRate／SelfElemRate 的角色，见待交叉核查）。钉影虚弱起初看不出（敌人伤害只有 3～5），参照与专项给符针例的敌人加物攻 5000、1 号生命 +1e6 后能看出。
- 没改切片、转换器、探针以外的参照（yunshang_probe 不接全量同步），不用重跑同步与内容覆盖检查。语法检查通过。
- 选测（本机 CHECK_JOBS=3，规则对照 `RULES_ONLY_ACTORS=174`，48 分钟）31 个全过：xiyou_yunshang、xiyou_help_card、xiyou_alien_battle、xiyou_alien_affix、xiyou_rules、xiyou_rules_d2～d6、xiyou_battle、xiyou_battle_gaps、xiyou_otb、xiyou_action_sequence、xiyou_custom_damage、xiyou_jingliu、xiyou_jingliu2、xiyou_sukuna_battle、xiyou_garou_battle、xiyou_raven_battle、xiyou_mira_battle、xiyou_yomi_battle、xiyou_toji、xiyou_race_battle、xiyou_cat、xiyou_smart_ai（四份）、xiyou_actor_p0、xiyou_actor_modules。
- ⚠ 偶发：xiyou_alien_battle 首轮 1 项失败（encounter.boss_150.plainName：首领名带不带「天外天·灼烂歼鬼」前缀，与云裳无关），单跑通过；这个场景累计偶发已 5 次（别的车道也踩），该修测试了，不在本车道范围，写进「可优化」。

## 交接板

- 下一步：云裳第二期 B 批——天衣 0／1／2／3／4／5／6／7／10／12、赊账、幽灵、借技能、自动战斗 AI（makeAutoBattleActions 与 evaluate 包装），以及战斗指令窗（收袖、放行、赠行、裁身、元素、收针选人）与天衣铺设置界面（界面车道）。
- 用户试玩说明：云裳的天衣现在能在战斗里「唤醒」了：敕衣点神唤醒穿天衣的队友，天衣无缝开战全醒，神纹自鸣每回合随机唤醒一个；收针按觉醒剩余回合打出大伤害。钉影会在敌人身上种符针，敌人出手前引爆；御风让全队变快。穿同袍换日能赠队友行动，穿寸光留仙能把行动存起来以后用；六衡裁身、万法同裳、七曜流霞也生效了。其余天衣下一批。战斗里的选择窗（选元素、选裁哪项等）还没有，先用默认值。
- 需要用户决定：无。

## 进度账

- 角色与专属机制：云裳完成度 0.3 → 0.5（觉醒、符针、行动来源与 5 件天衣；剩 B 批 10 件天衣、赊账、幽灵、借技能、AI 与界面），角色约 +0.5 个百分点（450×0.2÷8817×50≈0.51）。按行数估，不是测量值。

## 可优化（流程／工具／效率）

- 发现（工具）：单个专项直接跑 `07_开发环境/godot --headless --path 01_Godot工程 res://tests/<场景>.tscn` 只要 8 秒，并行测试在机器忙时排槽要 7 分钟；改错→重跑的循环用直接跑，交付前再走并行测试留记录。
- 发现（坑）：GDScript 的 `a().merged(b())` 先求参数 b() 再调 a()，测试里「先行动再读数」要分两步（本专项的 `_with`）；字典写 `o.mode = x` 会建 StringName 键，伤害计算的模块快照（value_copy）不认，要写 `o["mode"]`。
- 发现（测试）：xiyou_alien_battle 的 encounter.boss_150.plainName 累计偶发 5 次（flaky.jsonl），按规矩第二次偶发就该修测试（固定随机或等名字生成完），请总装派给合适的车道。
- 发现（坑）：伤害钩子写了没在 `actor_damage_hooks.gd` descriptor 的 writes 里声明的字段，整次伤害计算失败成 NaN（不报错，只在 diagnostic 里），新字段记得登记。

## 待交叉核查

- 原 Codex 核心文件：`battle/battle_logic.gd`——`setup`（异化 start 之前）`XYunshang.start_battle`；`start_turn`（异化之前）`XYunshang.start_turn`；`next_subject` 取出时 `XYunshang.took`；`execute` 在异化 start_action 之后 `XYunshang.prepare`，行动者因此倒下就返回；`_invoke` 普通路线 `return [r] + XYunshang.applied(...)`；`_calculate_damage` 改走 `XYunshang.calculate_split`；`end_turn` 末尾 `XYunshang.end_turn`；`end_battle` 宿傩之后 `XYunshang.end_battle`。
- `core/actor.gd`：`param_before_alien` 在 final_clamp 之内套 `XYunshang.battle_param`；`skills` 在异化之前 `XYunshang.skill_ids`。
- `core/actor_damage_hooks.gd`：descriptor writes 加 categoryMax。`core/alien_battle.gd`：`blocks_borrowed` 切换仿形、`start_action` 解封窗口加 `XYunshang.source_original`。
- 留意：防御（GUARD）行动在 act 里不走 execute，原版 prepareAction 对防御也跑（敌人防御时也会引爆符针），重制没接；黄泉／宿傩自己的 apply 路线不经 `XYunshang.applied`，他们穿天衣觉醒时打人不引爆符针。万法同裳 categoryMax 本例没有带 SelfPhysRate／SelfElemRate 的角色，参照看不出差别，只按读码接。分段结果不再按第一段的元素行摊固定减伤（原版各段的明细在 segments 里），敌人有固定减伤时可能有差。

## 本分支提交

- 95160db7 参照 p2.* 11 例
- WIP：接线与专项、categoryMax 声明、分段字符串键、符针例敌人物攻、交付单草稿
- 本提交：交付单可合并
