# 交付：claude/funny-dijkstra-c205fe

- 车道／工作者：B 装备／八戒（Claude，重制_八戒_31）
- 状态：可合并

## 变更记录草稿

## 2026-10-20 【Claude·八戒·未经Codex检验】双持装备槽（dev.待定）

- 规则（照冻结源）：`XActor.equip_slots` 照 YEP_EquipCore `equipSlots`，特性 55 的最大值为 1（MV `slotType／isDualWield`，职业、角色、装备、状态都算）时第 2 格（副手）改成武器；新增 `slot_type()`、`is_dual_wield()`。刘备（13）的双持来自专属剑「鸾凤和鸣剑」2005 自带的特性 55，曼德斯（26）来自职业。
- 初始装备：新增 `XActor.init_equips(ids)`，照 YEP_ItemCore `initIndependentEquips`：`convertInitEquips` 第 1 项与双持时的第 2 项查武器表、其余查防具表（≤0 跳过）；槽位类型在开头取一次，`grabInitEquips` 武器槽取表里第一把武器、其余取同装备类型第一件，能装备才装，最后不合的直接丢弃（如初始表给刘备 [2005, 盾]：装上 2005 后副手位变武器，盾被丢掉，与原版一致）。`setup` 改用它，并照 MV 先学技能再装初始装备。
- 换装：`release_unequippable` 每轮重取槽位类型（卸下带双持的武器后第 2 格变回副手，原副手位武器退回背包）；装备页候选、`change`、`optimize` 共用新的 `XEquipment.fits`（装备类型等于该槽当前类型且能装备）；最强装备的起始分照 MV `bestEquipItem` 改为 -1000（能力值和为负的也能选上）。装备页槽位名随之显示「武器」，`dev.093` 的双持攻击动画（weapons()[1]）现在能真正放出。
- 参照：新探针 `mv_oracle/dual_wield_probe.cjs` → `dual_wield.json`（已加进 `同步正式西游.py` 与 `oracle_additions.py`）：刘备、曼德斯 20 级两条换装流程共 17 步（装盾→装 2005 变双持、盾退回→副手位装第二把武器→换武器→换下 2005、第二把武器退回→再装→卸下→清空→最强装备），每步记槽位类型与名字、装备、背包、前 3 格的装备页候选、能力值、特殊能力值、weapons() 与 attackAnimationId1／2；另 7 组初始装备表与两人入队时的装备。Godot 侧 `tests/xiyou_dual_wield` 逐步比对，并在装备页（XEquipScene）实际操作一遍：301/301。
- 原版里的坑（界面上走不到，不照做、不另登记优化）：MV `changeEquip` 先与背包交换、再查槽位类型，类型不符时物品被吞掉；装上不能装备的件会立即卸回背包。装备页候选里都选不到，Godot 的 `XEquipment.change` 直接拒绝。
- 已知问题与未做：
  - **YEP `<Custom Parameters>` 未实现**（与双持无关，本次顺带查出）：冻结数据有 224 件装备带这个标签（如新手水果刀 1595 `atk = user.level * 2`，大量 `stat = user.level * N`，个别读变量），YEP `customParamPlus` 把它加进能力值，Godot 没有，这些装备的能力值偏低。探针为此改用没有这个标签的武器；建议另派装备规则车道接（需要公式求值，可走沙僧的公式中间表示）。
  - 双持角色 92、95、97、150、155、158、159、160 等不在切片里，规则通用，接入时不必再改槽位代码。
  - 没有新增优化项，O-072 未使用。
- 顺带修测试 `xiyou_floor16_dungeon`（悟空的文件，只改一处）：首领宝箱在没有邀请函 179 时变量 106 随机取 1～3，为 1 出「深渊之门」，测试默认选「进入此门」去了 Map051，`returned_floor16`／`dungeon_reset` 两项失败；撤掉本分支的规则改动照样失败，是 dev.105 副本随机改走世界流后固定变成这一支。改为出现时选「离开这是非之地」（同样传回十六层并重置）。
- 验证：`同步正式西游.py --accept-additions`（因改了同步脚本与 oracle_additions 全量重跑，测量不变，新增 dual_wield.json，留指纹）；`xiyou_dual_wield` 301/301；`检查.sh --oracle`（worktree，并行 2）全部通过，其中 actor_p0 829、equipment 1228、wtype 4360、panels 34、power 128、item_list 38、floor16_dungeon 25/25、rules a／b 各 222518。

## 交接板

- 下一步：第 4 条之后加一条「装备规则：YEP `<Custom Parameters>`（224 件装备的等级成长能力值）未实现，八戒_31 查出，需公式求值，交装备车道」；删掉 dev.093／变更记录里「Godot 还没有双持槽」的遗留说法（已做）。
- 下一步（补）：`xiyou_floor16_dungeon` 已改为不受深渊之门随机影响，悟空接十六层时知悉。
- 用户试玩说明：刘备装上鸾凤和鸣剑后，装备页第 2 格从「副手」变成「武器」，原来的副手退回背包，可以再装第二把武器（攻击时两把武器的动画都放）；换下鸾凤和鸣剑，第二把武器自动退回背包。曼德斯一开始第 2 格就是武器。
- 需要用户决定：无

## 进度账

- 装备：完成度不改（双持只补一条规则，按用户 2026-10-20 只粗估）

## 本分支提交

- 0c7841c 双持装备槽参照探针 dual_wield_probe（WIP）
- cc6b2bc 双持装备槽规则、初始装备、换装、装备页与测试
- b61f06d 测试：十六层副本宝箱遇深渊之门时选离开
