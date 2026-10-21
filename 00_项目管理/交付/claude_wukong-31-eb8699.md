# 交付：claude/wukong-31-eb8699

- 车道／工作者：A 内容·楼层／悟空（Claude，重制_悟空_31）
- 状态：可合并
- 完成范围：期一（107 钟离、131 椎名立希）、期二（Map148 错误数据 NPC，状态效果部分按停手条件登记）、期三（830 第 20 回合）全做；108 奈叶本批不做。

## 变更记录草稿

## 2026-10-21 【Claude·悟空·未经Codex检验】107 钟离、131 椎名立希加回切片；错误数据 NPC；830 第 20 回合补验（dev.待定）

- **期一**：`xiyou_slice.json` 的 `actors` 加回 107、131，`xiyou_actor_p0` 的 `RECRUIT_6` 加 CE1665 → 107、CE1664 → 131，去掉「护盾运行时未做」的剔出说明。两人技能用的 `addShield`／`a.shield` 在 dev.115 已翻译，**没有再暴露共性缺口，没改共性代码**。角色专项 `xiyou_actor_p0` 2728、`xiyou_wtype` 13502、`xiyou_shield` 565、`xiyou_rules` 十二段全过。
- **期二**：Map148 事件 20 放进切片（`keepEvents` 148 加 20），`xiyou_floor_run` 的 `UNOPENED_EVENTS` 去掉 148→20。新增 `xiyou_error_data`：事件三段对话后背包 1421～1426 各一件、独立开关 A 开、第 2 页空白、再碰不重复给；物品使用（战斗效果栏 43）后学到 8221～8226（都带 `<Hide in Battle>`）；进战斗开战标签给角色附加状态 1741／1742／1743／1747／1748／1749，共 25 项通过。物品、技能、状态本来就在整库导出里，切片无需另加。
  - **状态效果没做（停手条件）**：状态 1741～1743 靠 `<Custom Turn Start／Turn End／Leave Effect>`（按速度掷骰、`user.addState(1744/1745/1740/1743)`，其中 1743 的离场脚本还会自己再加 1743）；1747／1748／1749 靠 `<Custom Confirm Effect>`（改伤害值、按平 A 次数 `target.gainHp`、按暴击率加暴击伤害）。Godot 没有这套 Custom Effect 脚本机制（只有 `guide.gd` 里一处提到标签），1744～1746（再次行动特性）因为只能被 1741～1743 触发也就不可达。当前状态：**状态能附加、图标显示，但没有任何效果**；原版 1747 的脚本还少一个右花括号，原版里是否能跑也要先在参照引擎里确认。要做的话是一个独立的「Custom Effect 脚本」机制，应先出提案。
- **期三**：`troop_event_probe.cjs` 加 `turnPreset`（开战前把回合计数设成 N，跑到第 N+1 回合；队伍一级、从头打到 20 回合早已倒下，所以用预置），新增 830 第 20 回合一例：第 4 页 101 对话＋强制 8203，每人受 `b.mhp*2`（970／900／1050／960）、HP 清零。`xiyou_troop_events` 新增 `_turn_preset_case` 对照对话、强制行动、第一击伤害与 HP（7699 项过）。`oracle_additions.py` 把带 `turnPreset` 的例单独成组，否则新增例被判「同键追加」不能自动接受。
  - **观察到的差异（未处理，已记）**：8203 的备注是「action effect: actors」写了两遍，效果栏另有 60% 附加阵亡。Godot 里角色 HP 被打到 0 但没倒下时（掷骰没中），第二遍会再扣一次，同一个角色可能记 2～3 个 hit；参照掷骰固定 0.5 必中，只一遍。HP 空了但还没死的这个窗口，原版 MV 里同一个掷骰没中的话应该也一样（`Game_Battler.refresh` 在 hp=0 时才补死亡），所以我认为不是缺陷，但没有在参照引擎里用别的随机值验证；测试因此只比第一击伤害与 HP 清零，不比 hit 条数。
- **沙僧 P2（加回前先修）**：行动序列负 HP 绕过护盾。`XBattleLogic.sequence_gain` 的负 HP 现走 `absorb_shield`（先吸收、击穿后减半），弹字角色记原值、敌人记减免后，与 `XResourceContext.gain` 一致；返回弹字值，`XActionSequence._modify` 用它记 `_gains`。`xiyou_action_sequence` 新增 `_shield_checks`：复用 `shield.json` 的 `gain.actors.500_-1000`（原版生命 10000→9750、盾 0），真实序列「HP -1000」对角色与敌人都扣 250、盾清零。
- 验证：同步 `--accept-additions` 合并 main 后最后一轮「测量不变」；之前各轮接受的新增只有 107／131 的行与 troop_events 一例；内容覆盖检查 new 0／resolved 0；`检查.sh --oracle` 结果见「检查」。

## 交接板

- 下一步：「待补角色」去掉 107／131（只剩 108 奈叶）；「错误数据」NPC 划掉，改记「状态 1741～1749 的 Custom Effect 脚本机制未做」。
- 用户试玩说明：三十一层德颜天左侧多一位「错误数据」NPC（5,32），首次对话给六件「错误数据」物品，使用后学到隐藏技能，进战斗附加状态但**暂无实际效果**。钟离、131 椎名立希可作为战斗角色使用（battleReady）。
- 需要用户决定：状态 1741～1749 的 Custom Effect 脚本要不要做（要做先出提案：回合开始／结束／离场与确认伤害的钩子）；默认继续不做，NPC 带着无效果状态暂时上线。

## 进度账

- 无变化（角色 battleReady，progressionReady=false）。

## 检查

- 全量 `检查.sh --oracle`（合并 main 的 635734a 之后，按旧规则跑过）：除 `测试转换器写入.py` 的 toolVersion 19≠20（两文件我没动、与 main 相同，需沙僧／总装改期望值）外全部通过。此后只补跑相关专项并通过：`xiyou_action_sequence` 115、`xiyou_shield` 565、`xiyou_battle*`、`xiyou_combat`、`xiyou_sequence_visual`、`xiyou_smart_ai*`、`xiyou_troop_events` 7699。
- 之后 main 又进了「车道不跑全量检查」的规则提交，已再合并一次 main（只动文档）。

## 本分支提交

- 见 `git log main..HEAD`
