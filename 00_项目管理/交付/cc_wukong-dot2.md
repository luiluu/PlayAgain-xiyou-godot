# 交付：cc/wukong-dot2

- 车道／工作者：A 内容／悟空（cc，Sonnet）；接在 cc/wukong-dot1b（头 7ba62464）之后，**依赖 dot1b 先合并**（本分支含它的全部提交）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·悟空·未经审查】dot2：2038 燃烧 Apply Effect 翻译、屏障实测不可达、四类备注细查（dev.待定）

**① 2038「火遁初级燃烧」的 Custom Apply Effect 译成 effect_program**（dot1b 遗留的「damagedot 没人写」）：
- 参照探针 `state_effects_probe.cjs` 新增 `damagedot.apply`（11 行直调＋3 行真实 addState）、`dot_probe.cjs` 新增 `apply2038`（持有者 角色学没学 7520／敌人 × 施加者 a1／e0／e1／无 × v1218 起点 0／3，整条链：加状态→回合末再生）。
- 原版事实：`customEffectEval` 里 `var user = this; var target = this`，所以 `user.damagedot = target.mat*50*(1+v1218)` 用的是**持有者自己**的 MAT（块里注释写的「造成状态的人的魔法攻击」与代码不符，照代码）；v1218 先 +1（持有者学过 7520 再 +3）后读；**敌人持有者没有 hasSkill，整块 TypeError 中断**（damagedot 不写、变量不动）。回合末再生公式只在「施加者不是角色」时读 damagedot、按火属性倍率、波动 0 当**回复**算。
- 转换器 `xiyou_export.py`：`MEASURED_EFFECT_BLOCKS` 加 2038 apply 整段；字段表加 `damagedot`（运行时存 `state_data._damagedot`）。`core/ext_dot.gd` 读 `_damagedot`。
- 实际影响很窄：火遁 7826~7829 是玩家技能，状态加在敌人身上，敌人持有者块报错不写（与原版一致）；施加者是角色时再生本来什么都不做。只有「敌人把 2038 加给角色」才有回血；v1218 对敌人持有者也不再被无条件改动（原版就这样）。不需要用户决定。
- 顺手修 main 上已坏的 `测试未翻译块清单.py`（rules8 翻掉 1771 后两条断言过期：1771 apply→改认 887 establish；「全游戏可达」现在应为 0）。未翻译块 47→46（`xiyou_state_effects_tp` inventory 改 46）。

**② 屏障（YEP_AbsorptionBarrier）：实测不可达，不实现。**
- 新探针 `barrier_probe.cjs`（`barrier.json`，已登记 PROBES／oracle_additions）：全部数据表（技能、物品、角色、职业、敌人、武器、防具、状态）里解析出屏障字段的只有技能 **10032 月之庇佑**（`<Custom User Barrier> value = user.hp`）；它是**被动**（occasion 3＝永不可用、scope 0、无 effects），职业 154 的 50 级技能。学会后菜单里、战斗里 `canUse` 都为假、`usableSkills` 里没有，战斗开始、再生、回合结束屏障点数始终 0（探针连跑三回合）。屏障的增加只发生在「技能／物品被使用」的结算里（或角色／装备／状态上的 Barrier Points／Regen 备注，全库 0 个），所以没有任何入口。Custom_Shield_Mechanic 的「受伤减半、回合末掉 25%」也只在有屏障点数时起作用＝死代码。
- 守卫专项 `xiyou_barrier`（24 项）：原版参照成立；重制数据里带 barrier 备注的只有 Skills#10032；重制的 `can_use` 对 10032 也为假。以后数据里出现第二个屏障标签就会挂，到时再回来做屏障。
- 月之庇佑 10032 的说明文字「不想再失去什么了」是纯文案，没有数值效果可丢。

**③ 只读细查（无代码改动）：`YEP_X_AnimatedSVEnemies` 四标签、dsPassiveSkill `passive*`**——结论与真缺列表见下节「细查结论」。

## 细查结论（③）

原版取值用 `Game_Enemy` 真实对象量过（2000 个敌人：186 个有 `<Sideview Battler>`，1814 个没有；四个标签每个出现在 195 个敌人的备注里＝186 个 SV 敌人＋9 个非 SV 敌人）。重制的对应实现：`battle/battler_sprite.gd`（呼吸、影子）、`battle/battle_scene.gd _make_enemy_sprite`、`battle/action_sequence.gd attack_motion`。

| 标签／能力 | 原版量到的效果 | 重制现状 | 对玩家有没有影响 |
| --- | --- | --- | --- |
| `BREATHING SPEED: 11`（195 个） | 对 9 个非 SV 的有效：呼吸周期 2π×11 帧≈1.15 秒（默认 20 帧≈2.09 秒），横向幅度 0.001、纵向 0.02；对 186 个 SV 敌人无意义——**SV 敌人根本不呼吸**（`Enable Breathing=1` 只给非 SV 敌人，SV 要写 `<Breathing>`，全库 0 个） | `_make_enemy_sprite` 给**所有**敌人 `breathing = true`，固定周期 2.4 秒、只有纵向 0.02 | 有，纯画面、小：186 个 SV 敌人多了呼吸；1814 个非 SV 敌人呼吸偏慢（2.4 对 2.09 秒），9 个差得多（2.4 对 1.15 秒） |
| `SIDEVIEW NO COLLAPSE`（195 个） | 与插件默认 `Collapse=false` 相同：SV 敌人 `updateCollapse` 直接返回，**倒下不淡出变红**，留在原处（MOG_CollapseEffects 在后面包了一层，敌人没有它的 collapse 数据时仍落回这里）。非 SV 敌人不受影响（`isSideviewCollapse` 对非 SV 返回真） | `XBattlerSprite.collapse()` 对所有敌人都淡出变红 0.5 秒 | 有，纯画面，**只按源码推断，没有拍原版画面**；186 个 SV 敌人 |
| `SIDEVIEW SHOW SHADOW`（195 个） | SV 敌人在脚下画 `Shadow2` 影子（缩放 auto＝图宽/9/64）；非 SV 敌人没有 | 影子只给角色建（`b is XActor`），SV 敌人没有 | 有，纯画面；186 个 SV 敌人少了脚下影子 |
| `SIDEVIEW WEAPON: id, 动作, 动画` | 攻击动画号：186 个 SV 敌人全是 1，等于 `EnemyAtkAni` 默认 1，**没有区别**；攻击动作：145 个 thrust、35 swing、6 missile；44 个 SV 敌人带武器图（`weaponImageId>0`），挥舞／射击时画出武器；9 个非 SV 的标签无效（`hasSVBattler` 假） | `attack_motion` 对敌人一律 thrust、不画武器图（`start_weapon` 只给角色） | 有，纯画面：41 个 SV 敌人攻击动作与原版不同，44 个少武器图；伤害、动画号不变 |
| dsPassiveSkill `passiveGUARD`（技能 10089 苍龙*破晓，苍龙核心技能） | `Game_Actor.isGuard` 恒为真：**该角色一直处于防御**，受伤按 `÷(2×grd)`（YEP_DamageCore `applyGuard`），战斗里一直摆防御姿势 | 没读；`guarding` 只在使用防御指令时置位（`battle_logic.gd:1006`），`damage.gd:260` 读它 | **有，战斗数值**：苍龙少一半以上减伤 |
| dsPassiveSkill `passivePREE`／`passiveASUP`（各 6 个技能：1053、1084、1897、1110、1113、2782…） | 遇敌先制率＋、被偷袭率－（`Game_Party.ratePreemptive／rateSurprise`），只有开战判定「先制／偷袭」时才起作用 | 重制整套**先制／偷袭都没做**（`rg preempt|surprise` 无结果；变更记录 10-12~16 已记「未完成：先发制人/被偷袭」），所以连带没有 | 有，但前提是先把「先制／偷袭」本身做出来；先量原版（OTB 下表现、`XdRs_HangUp` 会强制 `_surprise = true`、`zidongzhandou` 会强制 `_preemptive = true`，要一起读） |
| dsPassiveSkill `passiveXPBSTEX`（技能 968：`EX2:20,HPUP,40`；3886：`EX9:50,MPUP,100`；插件说明里的 EX7 只是文档示例） | 条件满足时追加能力值（EX2 暴击率 +20；EX9 TP 回复率 +50）；条件：HP／MP 在某值以上 | 重制只读 `passivePBSTEX`（`actor.gd:605`），**没读 `passiveXPBSTEX`** | 有，小：2 个装备技能（妖精匕首、溢满）的条件加成不生效 |
| dsPassiveSkill `SvPngFd`（防具 2937、4279、5198、5200~5203，状态 1120 人鱼化身） | 穿戴／带状态的角色战斗立绘放大 N 倍（`Sprite_Actor.updateFrame`；Codex_MiraRavenMultiFrame 的多帧角色也读它）；敌人备注里的 SvPngFd（850、938）没人读 | 没读（`rg SvPngFd` 无结果） | 有，纯画面但显眼：巨人／泰坦等「变大」装备不变大 |
| dsPassiveSkill `atkk` | 攻击次数 +N | 已读（`attack_times_add`、`cat.gd`）；覆盖报告标「拿不准」是误报 | 无 |

**真缺列表（按建议先后）**：
1. `passiveGUARD`（技能 10089）：改 `damage.gd` 的防御判定认被动，战斗数值，小。——建议下一期悟空。
2. `passiveXPBSTEX`（968、3886）：照 `passivePBSTEX` 的读法补读，小。
3. 先制／偷袭整套（连带 PREE／ASUP 12 个技能）：先量原版再做，中到大；写不写进下一期请总装定。
4. `SvPngFd` 角色立绘放大（7 件防具＋1 个状态）：界面车道，小到中；多帧角色（Mira 渡鸦）另有一套比例，要一起看。
5. SV 敌人画面三件（脚下影子、不呼吸／呼吸周期按速度、倒下不淡出）和 44 个敌人的武器图＋攻击动作：界面车道，纯画面；倒下不淡出要先拍一次原版确认再做。

## 交接板

- 下一步：悟空下一期做真缺 1、2（passiveGUARD、passiveXPBSTEX）；先制／偷袭、SvPngFd、SV 敌人画面细节由总装挑车道。
- 用户试玩说明：本期没有玩家可见变化（2038 实际影响很窄，屏障、四标签只做了结论）。
- 需要用户决定：先制／偷袭要不要做（原版随机遇敌有概率先制／被偷袭，OTB 下开战谁先动会变）；其余是画面细节，按总装排。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 待交叉核查（改了核心文件）

- 本期没改战斗核心文件。改了：`core/state_effects.gd`（没动，转换器与运行时字段通路沿用），`core/ext_dot.gd`（读 `_damagedot`）。

## 验证

- `python3 07_开发环境/测试未翻译块清单.py`：7 项 OK；`语法检查.py`、`探针登记检查.py` 通过。
- 专项 `xiyou_dot`（新增 `apply2038` 一族）、`xiyou_state_effects`（新增 `damagedot.*`）、`xiyou_state_effects_tp`（inventory 46）、`xiyou_barrier`（新，24 项）通过。
- 同步（`同步正式西游.py --accept-additions`）退出码与云端选测结果见本文件末尾「云端结果」。

## 本分支提交

- c4753d2e dot2 ①：2038 Apply Effect 译成 effect_program、探针 damagedot.apply／apply2038
- 3db71fc7 dot2 ②：屏障实测不可达、探针 barrier_probe、专项 xiyou_barrier
- 本期：交付单（③ 细查）

## 云端结果

- 同步 `--accept-additions` 退出码 0（dot_probe、state_effects_probe、barrier_probe 新增用例已接受）。
- 云端选测（23 个场景、3 片，基准 7ba62464，提交 dde2a3b6e3）：通过，<https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41862185511>。基准取 dot1b 头，所以 dot1b 须先合并。
