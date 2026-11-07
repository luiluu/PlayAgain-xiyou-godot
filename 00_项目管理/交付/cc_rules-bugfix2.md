# 交付：cc/rules-bugfix2

- 车道／工作者：规则（cc，项目线程「完成再刷西游Godot引擎重制」），总装派单：Codex 审查报告第 8、9 项；追加天衣订单词缀、gear 重掷序号登记
- 状态：可合并（验证见文末）
- 基于：cc/rules-bugfix1 头 47e6270c（bugfix1 当时没进 main），交付前已 merge main（ec877cb6，含 bugfix1）。
- 改了战斗核心：`battle/battle_logic.gd`（受伤解除一处调用＋新函数）、`core/battler.gd`（is_guard、is_restricted、on_restrict、change_state_if_removed、add_new_state 一段、_add_state 一行）；`core/yunshang_orders.gd` submit 一段。

## 逐条

### 报告第 8 项（battle_logic.gd:2550 HP 正伤害不处理 removeByDamage）

- 复现测试：`tests/xiyou_state_remove.gd` 的 `damage.*`（59 例 × states／removed／draws），对照新夹具 `tests/fixtures/state_remove_oracle.json`（`mv_oracle/state_remove_probe.cjs`，冻结 v0.28 真实 executeHpDamage）。旧代码上 `damage.*.under` 全挂（状态不去掉、不掷随机数）。
- 结论：原版照常生效（15 个状态：愤怒、睡眠、眩晕、冰冻、缚龙索、离魂术等；参照里阈值下解除、阈值上保留、伤害 0／回复不掷、两个状态按 states() 顺序各掷一次），是重制漏了，**不是原版 bug，不挂开关**。
- 修法：`_execute_hp_damage` 里 `value > 0` 时先 `_remove_states_by_damage(t)` 再充 TP（同 onDamage 顺序）；用规则随机流 `_float("remove_by_damage")`，`floor(×100) < chanceByDamage` 就走 `_state_remove`（现有解除流程：结果槽 removedStates、remove 效果、刷新）。之后照 StateChangeIfRemove `checkToRemoveStates` 对之前身上的每个状态 `change_state_if_removed(id, "受伤解除")`：备注有 `<SC受伤解除:N>` 就换成 N、原状态不再记入本次解除（deleteRemovedStates）。数据里目前没有这个标签，专项 `sc.damage_changes` 临时写一条验证通路。

### 报告第 9 项（battler.gd:431 第一次受限不执行 removeByRestriction）

- 复现测试：`tests/xiyou_state_remove.gd` 的 `fixed.*`（开关开：防御 2／170／235、凌波舞 525、鸣贝 569／580 遇到睡眠 10、混乱 8、愤怒 7 被去掉、不再防御；防御后被晕、醒了也不再防御；已受限再加不触发；普通状态不触发）。旧代码上全挂。
- **原版实测：onRestrict 从不触发**。参照 `restrict.*` 46 例全是「没去掉、仍防御」：krz_state_re 把 Game_Actor／Game_Enemy.states() 缓存起来，addNewState 先算 restricted 时把脏标记用掉，push 之后的 isRestricted 读旧缓存，所以「从未受限变受限」永远判不出来。按 Kyo 11-07「原版 bug 一律修」：
  - **O-待定-3** `XBattler.FIX_RESTRICT_REMOVE`（默认 true）：add_new_state 前后比 is_restricted（restriction > 0），第一次受限时 on_restrict：防御指令（重制的 guarding，代替原版防御状态 2）失效、去掉 removeByRestriction 的状态（走 remove_state，记入结果槽）。关着时 `restrict.*` 逐例比参照（专项里先关再比）。
  - 「行动限制解除」的 SC 换状态在 addState 里面，被 _Fix_StackOverflow 的全局锁挡住，跟原版锁一致（数据里也没有这种标签）。
- OTB 行动队列核对：onRestrict 的 clearActions 在 OTB 下没有可见效果——OTB 在 getNextSubject 时才 makeActions（Olivia_BattleSysOTB:620），重制也是轮到时当场决定，没有预存的行动；行动队列的移除只看 canMove（addState 包装 otbClearActionOrdersOfUnableBattlers），重制已有，不受这次影响。
- 同一条规则顺带补上（原版生效、重制漏了，不挂开关）：
  - isStateRestrict：已受限时 removeByRestriction 的状态加不上（参照 `restrict.*.8+2`、`8+525`：不加、不掷回合数）。放在 `_add_state` 开头。
  - is_guard 认状态的防御旗标（特性 62 / 1）：170、235、569、580 原版 isGuard 为真（参照 before.guard），重制之前只认防御指令。

### 追加：天衣订单词缀（cc_rules-bugfix1 照搬清单第 4 条）

- 作者本意：Y.submit 把模板（`model()`，最高需求等级的布衣，当前 4282）的 `<Prefixes>` 补进天衣备注再 processYanflyTags、makeItem，旁边注释写「Retain native base stats/affix distributions」，之后 `normalizeRobe` 注释「Ordinary affix quality never replaces a robe's fixed super-artifact tier」——作者明确预期天衣会掷到模板的前缀、并专门防词缀改品质。补的不生效是因为 DreamX 的词缀表只在读库时解析。判为笔误式缺陷，按备注本意实现。
- **O-待定-4** `XYunshangOrders.FIX_TEMPLATE_PREFIXES`（默认 true）：开工掷天衣时，天衣自己的词缀行后面接上模板的前缀行（只取前缀，同原版只补 `<Prefixes>`）；掷完品质、图标档改回天衣自己的（normalizeRobe）。名字照旧改回天衣名。
- 测试：`xiyou_yunshang_shop` 的 p8 参照两例先关开关逐项比原版；新 `prefix_fix.*`：同一随机数 0.1，关着不掷、开着掷出的词缀都出自模板前缀表、全是前缀、品质图标档与名字不变。旧代码上 `prefix_fix.on_rolled` 挂（开关不存在时为解析错误，另核：开关改 false 时挂）。

### 追加：gear 重掷序号

只登记、不修（见下方草稿最后一行）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-3 | 受限解除（`modes/xiyou/core/battler.gd` `add_new_state`／`on_restrict`） | krz_state_re 的 states() 缓存让 addNewState 判不出「从未受限变受限」，onRestrict 从不触发：防御、凌波舞、鸣贝在被晕、混乱后照留，防御后被晕醒来仍减伤 | 第一次受限时去掉 removeByRestriction 的状态，防御失效 | 原版缺陷（Kyo 2026-11-07「原版的 bug 要修」） | `XBattler.FIX_RESTRICT_REMOVE = false`（参照 state_remove_probe 在关时逐例比） | cc（规则 bugfix2） | 默认修 |
| O-待定-4 | 天衣订单开工（`modes/xiyou/core/yunshang_orders.gd` `submit`） | 往备注补模板的 `<Prefixes>`，但词缀表读库时已解析，天衣从不掷词缀 | 照作者注释本意掷模板的前缀，品质、图标档保持天衣自己的 | 原版缺陷（补了却没生效） | `XYunshangOrders.FIX_TEMPLATE_PREFIXES = false`（参照 yunshang p8 在关时逐项比） | cc（规则 bugfix2） | 默认修 |

另请总装在优化登记表末尾（不编号、不发 O 号）补一行：「gear 重掷序号：已知原版缺陷，无可见影响，不修」（`core/gear.gd` 同几率词缀排序用的序号重掷后不归零；当前数据没有同几率的词缀）。

## 变更记录草稿

## 2026-11-07 【cc·规则·未经审查】挨打解除睡眠等状态、第一次受限解除防御、天衣掷模板前缀（dev.待定）

- **受伤解除**（审查第 8 项，`battle/battle_logic.gd`）：正 HP 伤害后，睡眠、眩晕、愤怒等 15 个状态按几率解除，用规则随机流；带 SC受伤解除 标签的照换状态。原版生效、重制之前漏了。
- **受限解除**（审查第 9 项，O-待定-3，`core/battler.gd`）：原版因 krz 缓存从不触发；现在第一次被晕、混乱时防御、凌波舞、鸣贝解除。另补：受限时这些状态加不上；防御类状态的防御旗标算进防御。
- **天衣订单词缀**（O-待定-4，`core/yunshang_orders.gd`）：按原版注释本意掷模板的前缀，品质不变。
- 新参照探针 state_remove_probe（夹具 tests/fixtures/state_remove_oracle.json）、新专项 xiyou_state_remove。

## 交接板

- 下一步：无新增。
- 用户试玩说明：睡眠、眩晕等挨打会按几率醒；防御后被晕或混乱，防御就没了；新做的天衣可能带模板的前缀词缀。
- 需要用户决定：无。

## 待交叉核查

- cc/rules-bugfix2：受伤解除、O-待定-3 受限解除、is_guard 状态旗标、isStateRestrict（甲档：战斗核心 battle_logic／battler）；O-待定-4 天衣前缀（乙档）

## 进度账

- 无

## 可优化（流程／工具／效率）

- `新建工作树.sh --补齐` 的 godot --import 在共用槽排队了 15 分钟以上（别的车道在跑全量）。车道开工补齐时导入能不能低优先、或复用主工作区的 .godot 导入缓存不重导，值得看一下。

## 验证

- 参照：新探针 `state_remove_probe.cjs` 106 例（冻结 v0.28），存成夹具 `tests/fixtures/state_remove_oracle.json`（不进同步，探针登记按同名夹具认）；探针里关了 CodexZones。
- 语法检查：602 个 .gd，0 个问题。
- 专项（本地）：xiyou_state_remove 387/387、xiyou_yunshang_shop 428/428。
- 旧代码上会挂（逐条把修复行改成 pass 后跑）：去掉受伤解除调用 → `damage.*`、`sc.damage_changes` 挂；去掉 on_restrict → `fixed.*` 挂；去掉 isStateRestrict → `restrict.*.8+2`／`8+525` 挂；去掉模板前缀 → `prefix_fix.on_rolled` 挂。
- `事件空绿扫描.py --check` 通过（空绿 55 例，均在基线内）。
- 云端选测通过：merge main 后 db9a3dce，344 个场景、13 片（https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42325215002）。
- 临时产物已清（.sandbox 的 state_remove.json、scratchpad 备份）。工作树是 app 自建的，没有另建 clone。

## 本分支提交

- 4d8a47db WIP：代码、探针、专项
- e0954e72 专项通过、旧代码上挂已核
- db9a3dce 合并 main
- 交付单 cc_rules-bugfix2（本提交）
