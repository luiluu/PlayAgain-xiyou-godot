# 交付：claude/bajie-fix-f1f3

- 车道／工作者：修复／八戒（Claude）
- 状态：可合并（待 Codex 核查；没有用独占文件例外）
- 基线：fbb205d7（claude/bajie-fix-startstate）
- 来源：沙僧积压核查第一期（`00_项目管理/核查范围/清积压_第一期_20261027.json`）的 F1、F3，以及交接板 O-097。F2（叠毒致死缺 collapse 记录，涉及 battle_logic）按总装安排先不做。

## 期一

### F1／P2：毒伤、种族、异化结算被画成治疗字

- **原因**：regen 记录的 `hp` 字段，四个生产者都按 hpDamage 口径记，正数是伤害、负数是回复。四个生产者是：
  - `battle_logic._regenerate` 记 `-shown`；
  - 叠毒 Regenerate 脚本记 `r.hpDamage`；
  - 种族、异化记 `before - after`。

  只有播放器 `battle_scene._play` 的 regen 分支又取了一次反，`_popup(-hp)`。所以 HP 再生、毒伤、种族、异化的弹字全部画反，这个错误在新生产者加进来之前就有。
- **修法**：统一契约为「regen 记录与 hpDamage 同号」，播放器原样传给 XDamagePopup（正数伤害、负数治疗）。只改 `battle_scene.gd` 一行，生产者都不动。
- **专项** `tests/xiyou_regen_popup.gd`，26/26。四个生产者都用真实入口产出记录，再交给 `battle_scene._play` 播放，断言实际弹字的 `kind` 和数值：
  - HP 再生为负：弹伤害字 `hp`。
  - HP 再生为正：弹治疗字 `hp_heal`。记录值是请求回复量 `-floor(mhp×hrg×rec)`，不是截到上限后的实际回升，与 MV gainHp 结果槽一致。
  - 叠毒 460：由角色 1 施加，走真实 `start_turn`／`end_turn`，弹 `hp`，数值为实扣。
  - 异化 `_lose_hp`：弹 `hp`。
  - 反向验证：退回取反写法，5 项 kind／文本失败。

### F3／P2：XEquipment.clone 漏复制 state_data

- **原因**：`XEquipment.clone` 逐字段复制角色，漏了 `state_data`（其中有 `_stateCounter`、`_stackingPoison` 等状态私有字段）。状态 1775 挂五层的角色，克隆后层数归 1，MP 从 221 变成 225（实测）。
- **修法**：在 `refresh_passive` 之前加 `b.state_data = a.state_data.duplicate(true)`，对应原版 JsonEx 深拷贝整个角色。`XFormulaContext.clone_battler` 的通用属性复制本来就含 state_data，没动。
- **专项** `tests/xiyou_equipment_clone_state.gd`，9/9：
  - 原样克隆、原样预览、换装预览三种情况，层数都是 5；八项能力值与原件一致（换装预览装回原装备后比较）。
  - 改克隆的层数不影响原件。
  - 反向验证：去掉这一行，6 项失败（层数为空，MP 225 对 221）。

## 期二：O-097 不成立，不改

交接板 O-097 说这 7 个技能把状态 ID 写在值里，`actor.gd battle_start_state_tags`（以及 power.gd 同类解析）会静默跳过：

| 技能 | 标签 |
| --- | --- |
| 7495 | `<StartPushState: 1331>` |
| 7496 | `<StartPushState: 1332>` |
| 7498 | `<StartPushState: 1333>` |
| 7510～7513 | `<StartPushState: 1337>`～`<StartPushState: 1340>` |

原版 v0.28 冻结源的探针（真实引擎，全内存新局）结果：
- 7 个技能的 meta 键都是 `StartPushState`，值是 ` 1331` 这类。dsPassiveSkill 的 processStateTags 把键解析成状态 `Number("")=0`、概率 1331，然后调 `addState(0)`，什么都不挂。
- 实测 7 例，状态 1331～1340 都没挂上，身上状态为空，也没有报错。
- 原版另外三处读这个标签的地方也挂不上：
  - `installCombatPowerRuntime` 第 191 行和 `installCostumePreferencesRuntime` 第 20 行，正则都要求 `StartPushState` 后紧跟数字；
  - `installImportedBalanceRuntime` 只是补丁文本，不解析。

所以冻结源本来就不挂这几个状态，重制跳过与原版一致。按总装「冻结源不挂的照冻结源」，actor.gd 和 power.gd 都不改，批准的 actor.gd 例外没有用上。探针和输出在 `03_再刷重制_Godot/04_验证/本地结果/20261027_八戒_O-097/`（不入 Git）。

如果这些技能本意是要挂状态，那是原版数据写错了，属于「原版可优化」，要用户决定。可以写进优化登记：改成 `<StartPushState1331: 100%>` 的写法，做成可回退。本批不自行改。

## 验证

16 场，并行 2，`--full`，全部单次通过。总用时 1744 秒，大部分时间在排共用槽。

- **新专项**：xiyou_regen_popup 26/26、xiyou_equipment_clone_state 9/9。两场都做过反向验证：退回修复后都会失败。
- **弹字与战斗界面**：xiyou_battle_ui 70、xiyou_popup_overlap 8、xiyou_battle_options 92。
- **regen 生产者**：xiyou_state_js 1733、xiyou_shield 565、xiyou_race_battle 436、xiyou_alien_battle 330、xiyou_imported_balance 273。
- **装备**：xiyou_equipment 1228、xiyou_equipment_admission 7。
- **xiyou_rules 难度 1 四段**：xiyou_rules 115637、xiyou_rules_d1b 115733、xiyou_rules_d1c 115746、xiyou_rules_d1d 115725。
- **没跑**：全量和其余 20 段规则。

## 变更记录草稿

## 2026-10-27 【Claude·八戒·未经Codex检验】修复 F1 regen 弹字符号与 F3 装备预览克隆漏复制状态私有字段；O-097 经原版确认不成立（dev.待定）

- F1：regen 记录统一与 hpDamage 同号，播放器不再取反。HP 再生、毒伤、种族、异化弹字恢复正确，新专项断言真实弹字种类。
- F3：装备预览克隆深拷贝 state_data，1775 五层预览能力值与原件一致。
- O-097：原版把 `<StartPushState: N>` 解析成状态 0，冻结源本来就不挂，重制一致，不改。
