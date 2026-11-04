# 交付：cc/nezha-fix3

- 车道／工作者：C 规则·工具／哪吒（cc，nezha-fix3）
- 状态：进行中

## 变更记录草稿

## 2026-11-04 【cc·哪吒·未经审查】审查 40 的 P3 清理（dev.待定）

逐条处理[审查第 40 期](../核查报告_20261104_审查第40期.md)的 P3（不含只记不修的项）：

- **P3-1** `tests/xiyou_dot.gd`：`errors_skip` 去掉 `or true`，改成真断言（原版报错用例有效 tick 数＜状态数，失败时打印明细）；`states` 改成与原版 `after.states` 排序后逐项比，不再是恒真的 `stringify != ""`。专项 2248 → 2259 项（含 P3-3／4 新断言）全过。
- **P3-2** 转换器 `xiyou_export.py`：新增 `ASI_BLOCK_HASHES` 与 `asi_ok`。靠换行补分号才合法的 7 块（224、260、381、566、577、732、1006，用 node 逐块确认单行化会报语法错误）再比一层「保留换行的原文规范形」哈希，换行形状变了就退回 js；空白、缩进、`\r\n`、注释变化不影响。`state_effects` 转换结果对 2718 个状态逐个与现有 `States.json` 比，零差异。`测试状态js翻译.py` 去掉 732 的跳过条件，加 `AsiBlockTests`（夹具 `tests/fixtures/state_js_asi.json`），21 → 25 项。
- **P3-3** 施加者弱引用：量过，**无差异**。战斗里 `enemies` 只在 setup 时 clear 后 append，战斗中不删不换；角色对象由 XState 长期持有，所以弱引用始终解析回原版「按下标／号现查」的同一对象。加断言 `lifecycle.origin_ref*`（e0、e1、a1、a8，回合结算前后）。
- **P3-4** `_damagedot`：原版挂在 battler 上、状态移除后不清，重制 `state_data._damagedot` 同样不清，**一致**，不改；加断言 `lifecycle.damagedot_survives_remove`、`origin_cleared_on_remove`。
- **P3-5** `_state_change_if_remove`：核过冻结源 StateChangeIfRemove.js 与 YEP 的 `removeStatesAuto`／`updateStateTurnTiming` 包装（只切换自定义离开效果开关）。数据里只有 1328 带 SC 标签（只有「自动解除」），1328 只靠回合结束倒数消失，没有别的状态效果碰 1328，所以窄实现够用。`xiyou_state_change_remove` 加 3 条普查断言，数据变了会报。
- **P3-8** 血条显隐：新探针 `mv_oracle/hp_gauge_probe.cjs`（真实原版逐个 `new Game_Enemy` 读 `hpGaugeVisible()`，2000 个敌人，隐藏成员也量），夹具 `tests/fixtures/hp_gauge_oracle.json`（不进同步）；`xiyou_hp_gauge_visible` 改成逐敌人比原版（普通＋隐藏成员），画面例去掉 `or e.hp <= 0` 的恒真口子。
- **P3-9** `XBattler.is_guard()` 补 `canMove()`（`guarding and can_move()`），新增 `XBattler.can_move()`，`battle_logic.can_move` 改为转调；`xiyou_passive` 加 2 条（防御后被挂不能行动状态：不再减伤、防御系数 1.0；passiveGUARD 那支不看 canMove，原有对原版的比较仍过）。
- **P3-11** `tusu_xuan.gd` 头注释「未移植」一行改成指向 binding／tusu／xuan_battle／xuan_chart／xuan_tusu_art。

## 交接板

- 下一步：无新增。
- 用户试玩说明：唯一玩家可见的行为变化是 P3-9：角色点了防御之后若被挂上「不能行动」类状态，不再享受防御减伤（与原版一致）。
- 需要用户决定：无。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 已做：转换器的 ASI 哈希表（回退：删 `ASI_BLOCK_HASHES` 与 `effect_state_effect` 里的 `asi_ok` 一行）。
- 建议：以后新增靠换行补分号的 MEASURED 块时，同步登记到 `ASI_BLOCK_HASHES`（做法见 `xiyou_export.py` 该表上方注释；`AsiBlockTests` 的夹具也要补）。

## 待交叉核查（核心文件）

- `modes/xiyou/core/battler.gd`（`is_guard` 补 `can_move`、新增 `can_move`）、`modes/xiyou/battle/battle_logic.gd`（`can_move` 转调，行为不变）。

## 验证

- 本地：`xiyou_dot`（2259/2259）、`xiyou_passive`（257/257）、`xiyou_state_change_remove`（10/10）、`xiyou_hp_gauge_visible`（18/18）、`测试状态js翻译.py`（25 项）、`语法检查.py`、`探针登记检查.py`。
- 云端选测（159 场景，含 `xiyou_determinism` 等战斗核心类）：见下方结果行。

## 本分支提交

- 见 `git log main..cc/nezha-fix3`
