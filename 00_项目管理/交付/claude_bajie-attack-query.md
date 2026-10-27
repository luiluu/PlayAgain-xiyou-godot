# 交付：claude/bajie-attack-query

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_77）
- 状态：可合并
- 基线：按派单从 928ab678（star-warehouse 交付点）开，带着 ce-fix2、petsynth、star-warehouse 三个分支的提交。
- 来源：沙僧 review-pending 的 P2-1（核查报告_20261024_全部待审.md）。原版演员 154 装武器 77 时，实际攻击是 5769，逆骨未就绪；Godot 把攻击固定为 1，误判就绪。
- 本期只做期一（派单：探针、统一查询、逆骨就绪、指令窗攻击、普攻追加次数）；期二只列清单，见下。

## 变更记录草稿

## 2026-10-27 【Claude·八戒·未经Codex检验】普攻技能统一查询 attack_skill_id／is_attack（期一，沙僧 P2-1）（dev.待定）

1. **原版参照 `attack_query_probe.cjs`**（进 PROBES，产物 `attack_query.json`，29 例）：新局摆好角色或敌人（卸下全部装备、forceChangeEquip、学技能、加状态、refresh，战斗中），记 attackSkillId、canAttack、指令窗「攻击」那一项（Window_ActorCommand.addAttackCommand 全链）、拿替换后的技能与技能 1 各问 isAttack 与 numRepeats、异化祈祷／逆骨的就绪。用例覆盖：武器 77／83（5769）、79（6289）、12（12）、不能装的 78 被 refresh 卸下；防具 4541（7313）且先于技能；状态 66／120／125（125 同时普攻次数 +1），状态盖过装备，两个状态按排序取第一个；技能 2071（2067）及装备先于技能、两个技能按学会排序；甚尔 171 按形态（无形态 10216，2631→10217，2633 时装武器 77 仍是 10219）；宿傩 172 恒 10238（状态与武器都盖不过）；敌人无替换、状态 120／125、只加次数的 41。
   - 冻结数据里 `<Replace Attack>` 全是数字写法（武器 154、状态 12、防具 2、技能 25；职业、角色、敌人、物品没有），所以技能名写法不认。
2. **统一查询（改了原沙僧核心文件 `battler.gd`、`actor.gd`、`enemy.gd`）**：`XBattler.attack_skill_id()` 按原版 YEP_WeaponUnleash 找第一个 `<Replace Attack: x>`（逐行，取第一串数字；备注结果按文本缓存），角色顺序 状态 → 装备（槽序）→ 技能 → 职业 → 角色，敌人 状态 → 敌人，都没有是技能 1；甚尔、宿傩照两个运行时在 XActor 里包一层。`is_attack(item)`（物品恒否，比技能号）、`attack_skill()`、`XActor.attack_command_text()`（技能的 `<Command Text>`／`<Attack Text>`，没有就技能名；甚尔直接用技能名）。
   - 原版把找到的号缓存到下次 refresh，只在「忘记技能而没 refresh」时与即时查不同，正式流程碰不到，这里每次即时查。
3. **接上三处**：
   - 异化 `XAlienation.ready` 的祈祷／逆骨读 `a.attack_skill_id()`（原 `alienation.gd` 写死 1，P2-1 本身：154＋武器 77 现在逆骨、祈祷都未就绪，与原版同）；
   - 战斗指令窗「攻击」（`battle_scene.gd` `_command_entries` 与选目标）：技能、名字、可用都按替换后的技能（原来固定技能 1 与术语「攻击」）；
   - 普攻追加次数（`battle_logic.gd` execute 的普通与行动序列两处）改问 `u.is_attack(skill)`，抽成 `XBattleLogic.attack_repeats`（原来比技能 1：替换了攻击的角色普攻不加次数，而用技能 1 时反倒加）。
4. 专项 `xiyou_attack_query`（223 项）：逐例比上面各值；numRepeats 含 dsPassiveSkill 等改写，只比 MV 本体（次数＋isAttack 时的 attackTimesAdd）。

## 待交叉核查（点名原沙僧核心文件）

- `battler.gd`：新增 attack_skill_id／replace_attack_objects／is_attack／attack_skill／replace_attack_of。
- `actor.gd`：replace_attack_objects 覆盖（状态→装备→技能→职业→角色）、甚尔／宿傩的 attack_skill_id、attack_command_text。
- `enemy.gd`：replace_attack_objects 覆盖（状态→敌人）。
- `battle_logic.gd`：execute 两处普攻追加次数改 is_attack，新增 attack_repeats。
- 另改：`alienation.gd`（ready）、`battle_scene.gd`（指令窗攻击）、`同步正式西游.py`（PROBES 加一行）。

## 期二清单（只列，不做；每处先对照原版那处读的是 attackSkillId／isAttack 还是写死技能 1）

- `battle_logic.gd`：458 敌人没有可用行动时的退回、505 角色自动行动最后的退回、569 decide 的普通攻击、1158 execute 不能用时退回（原版 Game_Action.setAttack 读 attackSkillId）、1222 反击（invokeCounterAttack → setAttack，读反击者的 attackSkillId）。
- `battle_scene.gd` 1134：performAction 的武器动作（原版 `action.isAttack()`）。
- `smart_ai.gd` 160（预估次数）、374；`hang_up_auto.gd` 57、180；`power.gd` 538、552、671（installCombatPowerRuntime）。
- `race_battle.gd` 186、266、455；`cat.gd` 402；`sequence_player.gd` 560。
- 指令窗「防御」：原版同样按 guardSkillId 的 commandGuardText 改名（Replace Guard），重制仍用术语与技能 2。
- 合契（installNativeBindingChargeRuntime）被绑定者的「攻击」改名：重制没有该模块，随模块移植时补。
- 另见：KMS_SkillLevel、Olivia_AntiPlayerStress、Olivia_BattleSysOTB、种族／Guidance／Tusu／Yunshang 运行时也读 attackSkillId，期二逐个对照。

## 交接板

- 下一步：attack-query 期二（上面清单），派 C 车道；建议先做 battle_logic 的退回与反击（同文件、影响战斗结果），再做战力、智能 AI、挂机。
- 用户试玩说明：装着「替换攻击」武器／状态／防具／技能的角色，战斗指令里的「攻击」显示并使用替换后的技能（如夏娜装 8 秒肘击武器时是「8秒肘击24下」）；普攻追加次数跟着替换后的技能走；甚尔按形态、宿傩为咒力体术。异化祈祷／逆骨的就绪判断按实际攻击技能。
- 需要用户决定：无

## 进度账

- 战斗规则：普攻替换（YEP_WeaponUnleash Replace Attack）从无到期一接通（查询＋指令窗＋次数＋异化就绪），下游各处待期二。

## 可优化（流程／工具／效率）

- 建议：探针发现重制 `XBattleLogic.can_use` 不看导入平衡禁用角色（143／144／145／157／160，原版 canMove 为假，canUse 全否）；行动时有 `XImportedBalance.blocks` 挡住，但指令窗可用、智能 AI 选招等仍按可用算。归 C 车道小修或并入期二（预计改一行加专项一例）。

## 验证

- 合 main：已是最新（无新提交）。
- 专项＋必跑（`并行测试.py`，33 场景全过，2580 秒）：`xiyou_attack_query`（223/223）、`xiyou_alien_battle`（330）、`xiyou_alien_config`（95）、`xiyou_alien_workshop`（45）、`xiyou_battle_ui`（70）、`xiyou_options_basic`（139）、`xiyou_action_sequence`（115）、`xiyou_battle.tscn`（8）、`xiyou_event_compare`（5，改了战斗界面的必跑）；改了普攻次数判定，`xiyou_rules` 全部 24 段：`xiyou_rules.tscn xiyou_rules_d1b xiyou_rules_d1c xiyou_rules_d1d xiyou_rules_d2 xiyou_rules_d2b xiyou_rules_d2c xiyou_rules_d2d xiyou_rules_d3 xiyou_rules_d3b xiyou_rules_d3c xiyou_rules_d3d xiyou_rules_d4 xiyou_rules_d4b xiyou_rules_d4c xiyou_rules_d4d xiyou_rules_d5 xiyou_rules_d5b xiyou_rules_d5c xiyou_rules_d5d xiyou_rules_d6 xiyou_rules_d6b xiyou_rules_d6c xiyou_rules_d6d`，全过，无偶发。
- RED：旧实现没有 attack_skill_id；同一参照下先把查询接上、测试摆法还不对时是 178/223，其中 154＋武器 77 的逆骨／祈祷就绪、指令窗名字都是旧实现的错法。
- 同步 `同步正式西游.py --accept-additions`：只跑新探针（executed 1、reused 58），测量不变，产物指纹已留。

## 本分支提交

- fe570828 WIP：原版探针 attack_query_probe
- 65bbc383 期一：统一查询、三处接上、专项 xiyou_attack_query、探针进 PROBES
- （本提交）交付单：验证与期二清单
