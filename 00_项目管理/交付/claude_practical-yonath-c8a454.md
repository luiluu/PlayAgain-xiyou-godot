# 交付：claude/practical-yonath-c8a454

- 车道／工作者：B 界面·演出／八戒（Claude，重制_八戒_21）
- 状态：**可合并**（已合 main，`检查.sh --oracle` 全部通过）

## 变更记录草稿

## 2026-10-19 【Claude·八戒·未经Codex检验】双持攻击动画补第二把武器；战斗 101 消息窗标准级对照（dev.待定）

- 双持（核查报告 `核查报告_20261018_Claude核查Codex.md` 第 4 条）：`battle_scene._attack_animation_ids` 照 `Game_Actor.attackAnimationId1／2`（weapons()[0]，空手 1；weapons()[1]，没有为 0 不放），`_attack_animations` 照冻结源给出两条：普通路径（MV `showActorAttackAnimation`）武器 1 不镜像＋武器 2 镜像，MIRROR 路径（`YEP_BattleEngineCore.js:5617` `showActorAtkAniMirror`）武器 1 镜像＋武器 2 不镜像；敌人只放 id1（与 a57d9f7 一致，未动）。序列 `ATTACK ANIMATION`、反击（displayCounter→showAttackAnimation）、无序列命中（`_show_hit`，等两段都播完）三处都改用它；两段各自从基础延迟起算（各调一次 showNormalAnimation）。`YEP_WeaponAnimation` 的 `<Weapon Animation>` 冻结数据未用到，不处理。
- 正式版参照：ui_reference 新增 `__atkAniRef.suite()`（双持 2005＋2、单武器 2005、空手、敌人，两只目标，普通与 MIRROR 两路，记每个新建 Sprite_Animation 的目标／动画／镜像／_delay），读数 `tests/fixtures/attack_animation_oracle.json`；`xiyou_sequence_visual` 新增 12 项逐条对照（53/53）。
- 战斗 101 消息窗（dev.091／十六层遗留）：冻结版战斗夹具里放同一条 `\n<海拉的幻影>很久没有打的这么尽兴了，哈哈哈。`（无头像、背景 0、位置 2）截图 `battle_msg_101_formal`，Godot `xiyou_battle_ui` 新增同一场面截图 `battle_49_message_101` 与几何断言（52/52）。消息窗 0,548,1280,172、名字框 0,484,298,64 两边一致；正文字形范围 (15,566)～(413,590) 与 (15,567)～(413,590)，名字字形 (85,502)～(212,526) 一致，名字颜色 (232,232,147) 对 (231,231,146)；右侧状态与行动顺序条两边都照常显示。未发现需修的差异。
- 已知、不修：MV `Scene_Battle.updateStatusWindow` 消息忙时关上角色／队伍指令窗，Godot 未做；战斗里的 101 只在敌群事件（回合中，没有指令窗）出现，碰不到。Godot 还没有双持槽（`equipSlots` 第 2 格在双持时变成武器、`convertInitEquips`），可装备 2005 的刘备（角色 13）未接、也没有第二把武器能装上，本次只补动画；双持槽属装备规则，留给接刘备／双持角色的批次。
- 执行者：Claude（八戒）；核查：待 Codex。

## 交接板

- 下一步：删掉「云端核查（PR #4）遗留：八戒——双持角色攻击动画补第二把武器」一句；架构审查后续 8 的「战斗消息窗标准级画面对照」划掉。新增小项（装备规则）：双持槽（trait 55 → equipSlots 第 2 格为武器），随刘备等双持角色接入时做。
- 用户试玩说明：双持角色普通攻击会同时放两把武器的动画（目前 Godot 版还装不上第二把，玩家暂时看不到）。
- 需要用户决定：无。预分配 O-058 未用（没有可优化项）。

## 进度账

- 战斗画面：不调，双持只补演出缺口、消息窗对照无差异。

## 本分支提交

- ea2461a 双持角色攻击动画补第二把武器，补正式版参照 attack_animation_oracle 与回归
- 39885a1 战斗消息窗标准级对照：101 消息窗与名字框对正式版截图，补 battle_49_message_101 与几何回归
