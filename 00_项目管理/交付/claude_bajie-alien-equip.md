# 交付：claude/bajie-alien-equip

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_88）
- 状态：可合并
- 本期：异化词条④——**吞器 swallow、献器 offer** 的战斗侧与背包保护；**夺舍 possession 只出方案**（见文末「夺舍方案」，待沙僧审、总装再派）。

## 现状：已完成

- 吞器、献器：实现、探针 3 例、专项、同步、选测（37 场景全过）、反向验证都已完成，可合并（O-118 换号、hostScope 变动生成接受单）。
- 夺舍：方案已写完（文末「夺舍方案」），没写代码，等沙僧审、总装派。
- 还没验证的：
  - 仓库存放供体（未拦，见「没移植／差异」）。
  - 战斗中换装没有界面入口，只有函数级检查。
  - 全量 `检查.sh` 按规则没跑。

## 变更记录草稿

## 2026-10-30 【Claude·八戒·未经Codex检验】异化词条④：吞器、献器；夺舍方案（dev.待定）

1. **吞器、献器**（`alien_battle.gd` 文末「词条效果④」）：
   - 锁队（Adv:68-71，`setup_gear`，与各人的生命类处理同一轮、在其之前）：把要空出的装备栏原样记进本场 logic 的存储（`gear`，按角色，同一批装备实例），装备栏直接置空——吞器空出衣服栏（装备类型 4），献器空出全部装备栏；之后刷新（被动缓存、能力值，生命／法力截到新上限，同原版 A.refreshGear＋refresh）。原生读装备栏的部分（能力值、特性、套装、法宝、宝珠、被动缓存、武器类型条件）都自然看不到空出的装备。
   - 借用效果（Adv:31-35 A.effectGhost，81-85 traitObjects 包装，`gear_effects`）：吞器者借供体的登记效果（角色 meta `xalien_ghosts`），献器把自己每件装备的登记效果（异化装备本身不借）交给绑定队友（`xalien_received`）；作为额外特性对象接在 `XActor.trait_objects` 末尾，护盾效果、自身物理／元素倍率备注同样读得到。
   - 结束（Adv:196，`restore_gear`）：`end_battle` 开头（同原版 endBattle 包装在原 endBattle 之前，胜／逃／败都走）原样放回装备栏、去掉借用效果、刷新；重新锁队前也先放回。空栏里若被放进别的装备（原版没有这种途径，直接覆盖），退回背包不丢件。
   - 换装（Adv:87，`XAlienation.can_change`）：吞器占用的供体不能穿；战斗中吞器、献器者与献器的队友不能换装。
   - 背包（Adv:88-90）：供体不能在商店单件出售（`XItemMarks.can_sell`）、挂机卖出跳过（`sellable_gear`），`XItemMarks.sell` 不让供体失去（loseItem 包装）；一键出售见 O-118。
   - 锁队检查（Adv:62）：吞器供体失效（加了锁定、被装备、被别的吞器占用等，A.ready 不过）、献器绑定队友不在场／已倒下／已被前面的人绑定时，异化装备卸下放回背包并提示——沿用已有的 `eject_invalid`，本期补参照例。
2. 接点：`actor.gd` `trait_objects` 末尾 `gear_effects`；`battle_logic.gd` `end_battle` 开头 `restore_gear`；`alienation.gd` `can_change`（供体、战斗中换装）与 `o_reserved_onekey`；`item_marks.gd` `can_sell`、`sellable_gear`（加可选参数 `onekey`，缺省假，原调用不变）、`sell`、`onekey_sell`。
3. 参照探针 `mv_oracle/alien_affix_probe.cjs` 加 3 例（共 31 例）：`battle.swallow`（本体 1044，供体背包里的指虎 6，衣服栏穿皮甲 3；敌人打、自己普攻、逃跑结束）、`battle.swallow.invalid`（供体加【锁定】，锁队卸下放回背包）、`battle.offer`（绑定角色 8；敌人打两人、队友普攻、全灭结束）；这几例另记双方装备栏（本体编号）、八项能力值、命中／回避／暴击与背包里异化装备、供体件数；新步骤 `end`（endBattle）。独立装备的 baseItemId 可能指向另一件独立装备，探针一路追到数据库本体。
4. 专项 `xiyou_alien_affix`：逐步对照三例；另 `gear.<swallow|offer>.<0|1|2>.*`（胜、逃、败结束后装备栏是同一批实例、背包不多不少、无重复实例、meta 清掉、存读档往返装备栏与背包实例号和异化配置不变），`gear.*` 守卫（战斗中供体不能穿、吞器者不能换装、结束后能换；供体不能商店卖、挂机卖出与一键出售跳过；O-118 关时一键出售照原版给钱不扣件）。

## 原版依据

- `js/codex/runtime/installAlienationAdvanced.js`（Adv）：10、17（词条说明）、28-31（A.reserved、bound、canOperate）、31-35（effectGhost）、43-44（ready：献器要有可借效果、吞器供体条件）、62（锁队检查卸下）、65（绑定队友）、68-71（空栏与借用）、77（refreshGear＋refresh）、81-85（traitObjects）、87（changeEquip／forceChangeEquip）、88（loseItem）、89（hangUp.doSell）、90（Window_ShopSell.isEnabled）、196（endBattle 还原）。

## 优化（O-118，已加登记表行）

- O-118：一键出售跳过吞器占用的供体（`XAlienation.o_reserved_onekey`）。原版一键出售（sellUnifiedQuality→doSell）没挡供体，照样给钱，loseItem 包装又不让它失去——每次都白拿一份卖价。回退：`o_reserved_onekey = false`（照原版给钱不扣件）。登记表行写的是 `O-118`，合并时请换号。

## 没移植／差异（写明）

- 仓库存放（`XWarehouse.deposit`）不挡供体：原版仓库插件经 loseItem，被挡后是否照样放进仓库没核对；重制照常移走，吞器在下次开战锁队时因供体不在背包而失效、卸回背包（不丢件、不复制）。如要照原版挡，归后续。
- 原版 refreshGear 另清 `CP.MagicWeaponManager.BATTLE_CACHE` 等缓存：重制法宝特性每次从装备栏现算，没有这层缓存。
- 战斗中换装：重制没有战斗中换装的入口（事件 319 未移植），守卫只在 `XEquipment.change` 一处生效。

## 验证

- 合过 main（654be040，碰的是飞艇、交接板与优化登记，没碰切片、转换器、探针与本车道文件；优化登记 O-115 状态列冲突取 main 的「保留」，O-116 行保留）后，工作树跑 `同步正式西游.py --accept-additions` 通过（测量不变、无 issues，留了产物指纹）。**hostScope 文字有变**：`alien_affix.json` 末尾加了「、第④批装备类（吞器、献器）」，请总装生成接受单。
- 选测（`并行测试.py`，并行 2，37 个场景全部首轮通过，2596 秒，日志 `04_验证/本地结果/并行测试/20261030_005319_cd70a87l`）：`xiyou_alien_affix` 1456/1456（原 1325，加三例逐步对照与 gear.* 检查）、`xiyou_alien_battle` 330/330、`xiyou_alien_config` 95/95、`xiyou_alien_workshop` 45/45、`xiyou_item_marks` 108/108、`xiyou_equipment` 1228/1228、`xiyou_equipment_admission`、`xiyou_equipment_clone_state`、`xiyou_formula_equipment` 1804/1804、`xiyou_hangup`／`_auto`／`_options`；另因 `trait_objects`、`end_battle` 是热路径跑了 `xiyou_rules` 难度 1 四段、`xiyou_smart_ai` 四段、`xiyou_battle*`、`xiyou_shield`、`xiyou_actor_p0`、`xiyou_magic_weapon*`、`xiyou_orbs`、`xiyou_shop_*`、`xiyou_costume_battle`。
- 反向验证：①临时让 `gear_effects` 返回空、不清 meta：`xiyou_alien_affix` 13 项失败（swallow 的 a、offer 的 b 读数，gear.*.no_meta）；②临时不放回装备栏：13 项失败（swallow／offer 结束后读数与 locked、gear.*.equips_1）。都已还原。
- 偶发：无。
- 没覆盖：仓库存放供体（见「没移植／差异」）；战斗中换装没有界面入口，守卫只用函数级检查。

## 改了的原沙僧核心文件（待交叉核查点名）

- `battle_logic.gd`：`end_battle` 开头加 `restore_gear`。
- `actor.gd`：`trait_objects` 末尾加 `gear_effects`（热路径：没有吞器、献器时两次 has_meta 就返回）。
- 另：`alienation.gd`、`alien_battle.gd`、`item_marks.gd`（不在本车道独占表里，改动是出售守卫三处，请总装留意有没有别的车道同时在改）；探针 `alien_affix_probe.cjs`；测试 `tests/xiyou_alien_affix.gd`；`00_设计/优化登记.md` 加 O-118 一行。

## 交接板

- 下一步：④夺舍按本单「夺舍方案」等沙僧审、总装派；④吞器、献器已交。
- 用户试玩说明：工坊配置好的吞器（借背包一把武器的登记效果，整场没有衣服栏）、献器（自己整场没有装备，登记效果给绑定队友）在战斗里生效，战斗结束（胜、逃、败）装备原样回来；被吞器占用的武器不能卖、不能穿。
- 需要用户决定：O-118（一键出售跳过吞器供体）去留，默认保留，可回退。

## 可优化（流程／工具／效率）

- 建议：`长任务.py start … -- 并行测试.py … --quiet` 在共用槽满、排队很久时，`--quiet` 不打「等槽」心跳，日志一直空，看门狗按空闲把它判成 stuck 停掉（本次排队 47 分钟后被停、白等）。可让 `并行测试.py --quiet` 照样打等槽心跳（或长任务对并行测试默认放宽空闲上限），并在车道须知里提醒长任务里别加 `--quiet`。预计收益：省一次重排队；归工具车道（哪吒）。

## 夺舍方案（只出方案，未写代码）

### 原版行为（installAlienationAdvanced）

- 说明（Adv:11）：取得绑定队友的登记主动技能与普通被动特性，使用自身属性与费用；队友整场退出战斗，不提供装备、资源与行动；自己倒下时两人退场。
- 配置与就绪：A.bindingOptions（Adv:39，生命类：双方都要 A.lifeCompatible——不穿云裳第 3 件、没有免死／复活类备注；对方身上没有生命／绑定类异化）；A.ready（Adv:41-42，队友在队、可绑定，且队友已学会至少一个 templates.possessionSkills 里的技能）。工坊侧重制已有（`alienation.gd` ready／binding_options）。
- 锁队（Adv:62、65、72）：队友不在场、已倒下或已被前面的人绑定→卸下放回背包（已有 `eject_invalid`）；`p._alienPossessedBy = a`；possessionTraits＝队友 nativeSkills 里 A.safePassive 的技能的 traits／note／meta 副本。
- A.safePassive（Adv:36）：stypeId 4、没有效果、备注不含 Custom／Codex／Actor／Unique／Passive State／$game／SkillKill／SkillFr／Summon／死亡／复活／变身，且备注里 passive／StartPush／TurnPush 标签全部属于白名单（PBST2-7、XPBST0-9、ELUP、WPNM、HarmRi、CrHarmRi、HarmRe、IRUP、GRUP、SPBST2）。
- 战斗中（inBattle）：
  - `Game_Party.battleMembers`（Adv:80）去掉被夺舍的队友——不上场、不行动、不被选为目标、不算全灭、经验按后备成员（同 isBattleMember）。
  - `Game_Actor.skills`（Adv:86）：加队友已学会的 possessionSkills（A.borrowedSkills，Adv:37）与队友的 safePassive 技能（按 id 去重）；费用、公式读夺舍者自己的。
  - `traitObjects`（Adv:85）接 possessionTraits。
  - A.syncRelations（Adv:105，每次 gainHp、endAction 等之后）：夺舍者倒下而队友没倒下→队友 `_hp = 0` 并附加阵亡（经 _alienDeathSync，不触发生命池等）。
- 结束（Adv:196）：清 `_alienPossessedBy`；队友身上的阵亡**不还原**（战后照阵亡）。

### 重制要动的文件

1. `alien_battle.gd`：新段「词条效果④：夺舍」——锁队记 `possessed`（队友→夺舍者）与 possessionTraits；`borrowed_skills`、`safe_passive`；`gear_effects` 同处接 possessionTraits（或另起 `possession_traits`）；`sync_relations` 加死亡同步；`end` 清记号。
2. `battle_logic.gd`：`setup` 里 `actors = s.battle_members()` 在 `XAlienBattle.start` 之前定；要在锁队之后把被夺舍的队友从 `actors` 拿掉（或锁队前先算），且要早于 `battle_scene` 按 `logic.actors` 建立精灵、状态窗、OTB 行动条。`gain_exp` 的 `actors.has(a)` 自然给后备倍率。
3. `actor.gd`：`skills()` 已有 `XAlienBattle.skill_ids` 接点（百相、无面），夺舍加在同一处；`trait_objects` 接点本期已加。
4. `battle_scene.gd`：只要 `logic.actors` 在建立界面前已过滤，界面不用改；要核对 `XState.current.battle_members()` 在战斗中的 16 处直接调用（如 `battle_scene.gd:566` 失败时复活出战成员、`hang_up_auto.gd:52／290` 挂机、`enemy.gd:101` 强敌计数、`xstate.gd:563／579` 队伍特性、`zhenqi.gd:779`），逐个定是否要排除被夺舍的队友（原版 battleMembers 是全局过滤，战斗中所有调用都看不到他）。
5. 探针 `alien_affix_probe.cjs`：`battle.possession`（队友角色 8 学会一个 possessionSkills 与一个 safePassive 被动）：锁队后的技能表、能用的技能、特性读数（被动的命中／暴击等）、`battleMembers` 的人数、敌人能选的目标；夺舍者被打倒后队友的生命与阵亡；结束后队友仍阵亡。另 `possession.invalid`（队友已倒下→卸下）。
6. 专项 `xiyou_alien_affix` 逐步对照；`xiyou_battle_ui` 加一项：被夺舍的队友不出现在状态窗与行动条。

### 风险

- **跨战斗持续**：夺舍者倒下时队友被写成阵亡，战后照阵亡（原版就是这样）——不碰存档结构，但会让玩家战后看到一个没上场的队友阵亡，要在交接板写清；是否要改（例如战后只把队友回到 1 血或不同步阵亡）属于 O 号候选，等用户定。
- **出战名单**：重制战斗中直接调用 `XState.battle_members()` 的地方不经 `logic.actors`，漏改会让被夺舍的队友被挂机药水、强敌计数、队伍特性等算进去；这是本项最大的工作量与漏网风险。
- **角色数据**：只读队友的技能与被动，不改队友的技能表、装备、等级；不涉及存档字段（全在本场 logic 存储与 meta 里，战后清掉）。
- **界面**：战斗开始时出战人数比菜单里少一人，精灵站位、OTB 行动条要按过滤后的名单排；百相仿形窗等借技能界面已能显示额外技能。
- **挂机**：自动战斗的技能选择要能看到借来的技能（`XHangUpAuto` 读 `skills()`，应自然生效，要专项确认）。

### 分步

1. 探针参照例（只写 `.sandbox/`）＋同步。
2. 锁队与出战名单过滤（`logic.actors`），专项对照 battleMembers 与目标。
3. 技能与特性（skills、traitObjects、safePassive），专项对照技能表与读数。
4. 死亡同步与结束清理，专项对照倒下后两人状态。
5. 审查 16 处 `battle_members()` 直接调用并逐个处理，界面专项一项。

### 要不要新 O 号

- 实现本身照原版，不需要；**候选**（等沙僧审后由总装决定要不要登记、问用户）：①夺舍者倒下时被夺舍的队友战后仍阵亡（原版如此）；②夺舍者在战斗中被复活时队友不复活（原版 syncRelations 只同步倒下）。

## 本分支提交

- 见 git log（claude/bajie-alien-equip）。
