# 交付：cc/bailong-yunshang7

- 车道／工作者：E 角色专属／白龙_11（cc）
- 状态：可合并
- 分支从 cc/bailong-yunshang6 末端 b8c86fbc 切出（总装十派单），**包含 yunshang6**（与 yunshang4），yunshang6 的交付单照它自己的合。还没合 main（yunshang6 进 main 后总装通知再合）。
- 范围：云裳界面一期——战斗指令窗里云裳的几项；另加总装十追派的一小项：参照关五乘区、专项伤害改回比绝对值。天衣铺留下一期，盘点见文末。

## 变更记录草稿

## 2026-11-01 【cc·白龙_11·未经审查】云裳界面一期：战斗指令窗（dev.待定）

照原版 installNativeYunshangRuntime.js 第 508～538 行：

1. **指令窗**（Window_ActorCommand.makeCommandList 包装，在逃跑之后、种族血契之前）：同袍换日觉醒时「神纹赠行（免费）」（本回合赠过、衣魂中灰显）、寸光留仙「释放余光」（没存、本回合放过、衣魂中灰显）、六衡裁身（本回合裁过灰显）、千军入袖「收袖：开启／关闭」、七曜流霞「选择七曜元素」（本回合选过灰显）。`XYunshang.command_entries`。
2. **选择窗** `XYunChoicesWindow`（原版 Window_YunChoices）：普通 Window_Command，宽 760、画面正中，可见 3～12 行（行高 36），可带说明行（天衣铺用）。
3. **处理器**：收袖切换、放行后重画指令窗；赠行选人（出战里除自己外活着的，受赠满 2 次的灰显）→免费赠 2 次；裁身选一项（觉醒选两项，第二次去掉选过的）→Y.cut；七曜选元素写进设置、本回合不能再选。任何一步取消回指令窗。
4. **选技能之后**（onSkillOk／onEnemyOk 包装）：收针先选觉醒中的人（记进 `wake_target`）；没醒的换锦先选自己的状态（首行「不选自身状态」），选敌人后再选它的状态（首行「不选敌方状态」，取消回选敌），记进 `exchange_pick`。取消都回技能列表。
5. **选人**（onActorOk 包装）：敕衣点神选没穿天衣的、赠行选自己——蜂鸣，留在选人。
6. **云裳的技能栏**：原版只包 addedSkillTypes＝[2,1,5,4]，指令窗照这个次序、不列被动——魔法、战技、其他；`XActorModules` 的 BATTLE／MENU_SKILL_TYPES 加 174。
7. 自动战斗照旧走默认（收袖开、收针选剩余回合最多的、换锦各取第一个）。
- 参照：`yunshang_probe.cjs` 加 p6.cmd*（调原版 makeCommandList 收各天衣指令的名字、能不能选，用前用后各一次）；开头关五乘区 `CodexZones.ENABLED=false`（重制不移植，O-050；悟空查明 1 号伤害高 0.9% 就是它）。专项 `xiyou_yunshang` 的伤害从比值改回比绝对值（容差 1），全部对上；新专项 `xiyou_yunshang_ui` 用真战斗画面按键走一遍每个指令。

## 优化登记草稿

无。

## 验证

- 新专项 xiyou_yunshang_ui 33/33：指令名与能不能选照参照，选择窗位置大小，取消路径，收袖／放行／赠行／裁身（一项、两项）／七曜，敕衣点神选错人蜂鸣，换锦选两边状态后实际互换，收针用掉的是选的那位。反向验证 9 处全抓到（收袖名字、收针不记人、换锦不记敌方状态、不挡错目标、觉醒只选一项、技能栏、不赠、放行灰显条件、元素不写）。
- xiyou_yunshang 1575/1575（伤害比绝对值）；反向验证：展幅倍率 0.66→0.665，96 项失败。
- 语法检查通过。没改切片与转换器；yunshang_probe 不在同步的 PROBES 里（一期起就不接全量同步），`同步正式西游.py --accept-additions` 跑了也不会跑它，所以没跑；要不要登记进同步请总装定。
- 选测（CHECK_JOBS=3、RULES_ONLY_ACTORS=174，33 个场景写全名）：xiyou_yunshang、xiyou_yunshang_ui、xiyou_battle_ui、xiyou_battle、xiyou_battle_log、xiyou_battle_events、xiyou_battle_options、xiyou_smart_ai、xiyou_smart_ai_b、xiyou_smart_ai_c、xiyou_smart_ai_d、xiyou_help_card、xiyou_actor_modules、xiyou_actor_p0、xiyou_alien_battle、xiyou_alien_affix、xiyou_race_battle、xiyou_panels、xiyou_options_basic、xiyou_poison_collapse、xiyou_mv_animation、xiyou_sequence_visual、xiyou_review_fix、xiyou_regen_popup、xiyou_popup_overlap、xiyou_costume_battle、xiyou_otb、xiyou_rules、xiyou_rules_d2～d6。32 个过；xiyou_yunshang 只挂在 covers_all（加了 p6 没算进去），改好后和关五乘区的新参照一起单跑过（1575/1575），xiyou_yunshang_ui 也在新参照下单跑过。没有偶发。

## 交接板

- 下一步：云裳界面二期——天衣铺（见下面盘点）。
- 用户试玩说明：云裳和穿天衣的队友在战斗里多了指令：收袖开关、释放余光、免费赠行、六衡裁身、选七曜元素；收针会先问收谁的觉醒，换锦会先问换哪个状态。
- 需要用户决定：无新增（借来的技能看不看武器那条在 yunshang6）。

## 进度账

- 角色与专属机制：云裳完成度 0.85 → 0.9（战斗指令窗；剩天衣铺），按工作量估。

## 可优化（流程／工具／效率）

- 发现（工具，已做）：原版指令窗可以不建窗口直接量——`Object.create(Window_ActorCommand.prototype)` 设 `_list`、`_actor` 后调 `makeCommandList()`，收 `_list` 的名字、符号、能不能选（yunshang_probe p6.cmd*）。别的角色专属指令（血契、渡鸦等）要对照时可以照抄。
- 建议（总装定）：yunshang_probe 要不要登记进 `同步正式西游.py` 的 PROBES 与 `oracle_additions.py`，让它跟着正式源同步刷新。

## 待交叉核查

- `battle/battle_scene.gd`：`_command_entries` 加云裳的指令；`_command_for` 加 yunSleeve／yunRelease／yunGift／yunCut／yunElement 处理；`_pick_action_list` 加收针、换锦的选择；`_pick_target` 加错目标蜂鸣；新 `_yun_command`、`_yun_pick`、`yun_win`。新文件 `battle/yun_choices_window.gd`。`core/actor_modules.gd` 两张技能栏表加 174。
- 留意：选择窗的说明行（info）只有天衣铺用，战斗里没测到；收针选人列的是出战里觉醒中的（原版不看死活，照抄）；收袖开关还是不进存档。

## 天衣铺盘点（下一期）

原版 Scene_Yunshang（第 519～533、554～590 行）与订单账本（第 102～200 行）：

1. **入口** Y.openCrafting：战斗外、云裳在队且 20 级以上（否则提示「云裳达到20级后，可在战斗外使用天衣铺」），由天衣铺技能 10287 打开。
2. **首页**（说明 4 行＋5 项）：说明「天衣铺　云裳 N级　进阶x/2　不朽天丝 n」、当前订单或「当前没有制作订单」、「制作池按等级与进阶开放（35级起可制作）」、「属性与词条开工时确定，领取或读档不重抽」；选项 制作天衣（不朽天丝×15，35 级起、没有订单时）、领取已完成的天衣（进度满 10）、角色进阶（没到 2 次且够等级，进 Scene_ActorAdvanced）、配置天衣神纹、返回。出错时有兜底首页（「制作记录暂不可用，请恢复配套记录后重试」）。
3. **订单账本**：独立文件 `yunshang_orders_v1.json`（重制同步已登记为 EVENT_LEDGERS），profile／replay／transaction／journal；Y.pool 按等级与进阶开放的天衣、Y.submit 开工时定属性与词条、Y.progress 每场战斗每回合 token 记 1 格（满 10）、Y.claim 发天衣（带 _yunUid）。进阶次数原版取账本，重制现在用存档里的 XAdvance.rank（一期已定）。
4. **配置天衣神纹**：先选穿天衣的人（「名字｜天衣名」），再按天衣：空袖藏星选 3 个借用技能（出战成员会的可借技能，首个常驻，说明「选择借用技能 n/3（首个为常驻）」）、九曲回针选针眼（有冷却、不是不能用、名字不含唤醒／复活／制作／进阶、编号小于山河击）、七曜流霞选 3 个元素（2 起、不含 10，首个为当前元素）；别的天衣提示「这件天衣无需战前配置」。设置按天衣（_yunUid）存在角色上，重制现在是 `XYunshang.settings[角色]`、不进存档，二期要改成按天衣存进存档。
5. 另有图标（Yunshang_Icons、iconInfo、HD 图）、织神天梭升级经验（relicNextLevelExp、relicDisplayParams）、Y.equipmentCap、Y.advanceRequirements（等级、人道意志碎片、背包天衣数）这些，二期一并看。

## 本分支提交

- 151eda44 指令窗与选择窗，参照 p6.cmd*（WIP）
- 4113ed7e 界面专项 33/33（WIP）
- 本提交：参照关五乘区、伤害比绝对值、交付单可合并
