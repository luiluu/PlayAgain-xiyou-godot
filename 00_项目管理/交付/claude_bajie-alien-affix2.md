# 交付：claude/bajie-alien-affix2

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_82）
- 状态：进行中
- 本期：异化词条效果期二·第①批「状态类」：疫囊、囚厄、绝缘、舍身。基线是期一分支 claude/bajie-alien-affix-354c33 的末提交 027b81c0。
- 2026-10-29 唐僧通知用户要留额度，期二先停在这里，以 WIP 提交保存。

## 现状（停在这里）

**做到哪**
1. 前置已完成：`alienation.json` 的 templates 补了 `statePairs`（19 对）和 `jailStates`（172 个），照 installAlienationRuntime 的 config 原样抄；`alien_config_probe.cjs` 一并导出这两张表（同步脚本里本来就登记了这个探针）；`xiyou_alien_config` 通过。
2. 四个词条在 Godot 侧已实现（`alien_battle.gd` 文末「期二①」一节），接点如下：
   - `battler.gd`：`add_state` 加绝缘拒收、舍身转给队友、囚厄转移；`_add_state` 记附加次数，疫囊重复附加时回合取较长；`remove_state` 拦截不可驱散的状态，自然移除后清掉囚厄接收标记；`clear_states` 保留受保护的状态；`add_shield` 加绝缘拒收、舍身转移。
   - `actor.gd`：`add_state` 遇到疫囊受保护状态时，绕过角色侧的拦截（原版 addProtected）。
   - `resource_context.gd`：`add_state` 遇到疫囊、囚厄的状态时不判抵抗；`gain` 加绝缘拒收外来恢复、舍身的生命恢复转给队友。
   - `battle_logic.gd`：`state_rate` 与效果 21 的抵抗判定接疫囊、囚厄；效果 33／34 与 `sequence_buff` 接增减益的拒收、转移、不可驱散（新参数 `alien_routed`）；`sequence_add_state` 的抵抗判定同样处理；`end_turn` 开头调 `XAlienBattle.spread_pest`（原版 Affixes 的 endTurn 包装在原 endTurn 之前）。
   - `alien_battle.gd`：腐蚀到期按自然移除走（`natural_removal`）；`lock_party`／`end` 维护「战斗中」标记，并清掉囚厄接收标记。
3. **O-106（优化，可回退）**：`installNativeTojiRuntime.js:150-154`（模块 9）先截下了 `Game_Actor.addDebuff`，installAlienationAdvanced 后包的 `Game_Battler.addDebuff` 对角色走不到，所以原版里囚厄「接收队友减益」、绝缘「免疫外来减益」对角色都失效（只有疫囊者经 `Game_Battler.prototype.addDebuff` 走得到）。参照探针实测证实：jail 例第 1 步，减益留在队友身上；insulation 例第 7 步，敌人的减益照样上身。`XAlienBattle.o106_actor_debuffs` 默认 true，按词条说明对所有角色生效；设成 false 就与原版一致。需要用户最后拍板。
4. 参照探针 `alien_affix_probe.cjs` 扩了四例：battle.pest／jail／insulation／sacrifice。用空白技能 13 原地填效果合成技能；步骤有 set、roundEnd（A.spreadPest）、expire（自然移除）。全探针 7 例都干净。
5. 专项 `xiyou_alien_affix` 扩了：期二用例逐步对照（对照时 O-106 关）；另加 `o106.*` 三项，检查 O-106 开时减益的接收与拒收。**最后一次运行 433/433 通过**。

**原版依据（文件:行）**
- 疫囊：installAlienationAffixes.js:64-79（protectedState、stateRate／isStateResist／isStateAddable、addProtected、removeState 三件套、removeStatesAuto、resetStateCounts、clearStates、debuffRate、addDebuff、removeBuff、spreadPest、endTurn）。
- 囚厄：installAlienationAdvanced.js:154-175（receiving、stateRate／isStateResist／isStateAddable、addState 里转移、removeState 三件套、clearStates、addDebuff、removeBuff、clearBuffs）。
- 绝缘：Adv:91-92（source／external）、97（gainHp）、111-112（gainMp）、114（addShield）、160（addState）、169-175（removeState、clearStates、addBuff、addDebuff、removeBuff、clearBuffs）、194（云裳）、195（revive）。
- 舍身：Adv:93（supportTarget）、98（gainHp）、114（addShield）、163（addState）、171（addBuff）。
- 附加次数：installAlienationRuntime.js:82-83（resetStateCounts 计数、A.tryState）。

**还没验证**
- 只跑过 `xiyou_alien_config` 和 `xiyou_alien_affix`（433/433）。**没跑选测**：这次改了 `battler.gd`、`actor.gd`、`resource_context.gd`、`battle_logic.gd`，每场战斗都会经过这些地方，至少要补跑期一那批（`xiyou_alien_`、`xiyou_module_hooks`、`xiyou_actor_p0`、`xiyou_formula*`、`xiyou_smart*`、`xiyou_rules` 难度 1 四段等）。另外要加跑状态、增减益、资源相关的专项：`xiyou_param_states`、`xiyou_battle*`、`xiyou_boss*`、`xiyou_state*`（具体名字以 tests 目录为准）。
- **`xiyou_alien_affix` 用时从期一的 3 秒涨到 50～65 秒，原因没查**。停手前正要复跑确认是不是机器负载。若不是负载，要怀疑新钩子在热路径上太慢：`has()` 每次都走 `XAlienation.for_actor` 扫装备，`_in_template` 线性查表，`battling()`、`forced_state` 在 `state_rate`、`add_state`、`remove_state` 上每次都调。优化方向：开战时把词条与模板表缓存成集合。
- **没跑同步**：`alien_affix_probe.cjs`、`alien_config_probe.cjs` 都改了，交付前要在工作树跑 `同步正式西游.py --accept-additions`。alien_config.json 的 templates 多了两个键，不算「只增用例」，同步可能报「有变化」，届时人工确认后接受。
- 没合 main（悟空期一改了 actor.gd，合并时要看 `add_state`／`learn_skill` 附近有没有冲突）。

**下一步**
1. 查清专项变慢的原因（必要时缓存词条与模板集合），然后跑上面列的选测。
2. 合 main，跑同步，补全交付单（变更记录草稿、待交叉核查点名、可合并）。
3. 没移植的尾巴（写进交付单「没做」）：
   - 舍身、绝缘对回合末再生的处理：`_regenerate` 直接写 `hp`，原版经 gainHp 包装（Adv:108-109）。
   - 绝缘对 setHp 的处理（Adv:107）。
   - 绝缘对云裳 wake／addActions／freeGift 的处理（Adv:194）。
   - 疫囊者在阵亡 clearStates 时保留状态的边角。
   - 囚厄、绝缘对 clearBuffs 的保留：重制阵亡时直接清零。

## 发现的原有差异（不归异化，交总装另派）

- 角色身上已有状态时挨减益，原版帧外读物攻不刷新（krz 参数缓存没包 addDebuff），重制会刷新。用不带词条的对照例实测：原版 424，重制 318（物防同理 400 对 300）。探针里的这个对照例已删，期二用例不读帧外物攻／物防。建议派给管参数缓存的车道，查 `sequence_buff` 的 `_refresh_battler` 与 krz dirty 的对应关系。

## 可优化（流程／工具／效率）

- 已做：探针合成技能要在原对象上改字段（`Object.assign($dataSkills[13], …)`）。整个替换会丢掉 YEP 技能熟练度挂的字段，行动结束时插件报错并 `SceneManager.terminate`，jsdom 的 `location` 随之失效，后面的用例全挂。这条写在探针注释里，以后的探针照做。
- O-106：见「现状」3。

## 本分支提交

- 期二前置：alienation.json 补 statePairs／jailStates，alien_config_probe 一并导出（WIP）
- （本提交）WIP：期二① 四个词条实现、探针与专项扩充，交付单现状
