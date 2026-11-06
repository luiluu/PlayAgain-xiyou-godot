# 交付：cc/wukong-newsrc6

- 车道／工作者：CS ④ 真气本命兵／神兵试炼指定道法（v0.43／v0.45）（cc，悟空）
- 状态：**完成，可交总装合集成分支**
- 基线：从 `cc/wukong-newsrc5` d1b41749 切出；工作树沿用 `.claude/worktrees/wukong-newsrc4`（分支已换），跑测试设 `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`。

## 变更记录草稿

## 2026-11-06 【cc·悟空·未经审查】换源集成：真气 v0.45 神兵试炼与指定道法（dev.待定）

- 照 v0.62.12 `installNativeZhenqiRuntime.js` 改 `modes/xiyou/core/zhenqi.gd`：
  - `weapon_masters`：每类武器只取第一位神兵之仙，敌群须只有它一个且不隐藏，按武器类型排序；新源多了 2005～2009 五位（钝器、斧、太刀……），共 12 位。新 `weapon_types`（有名字、有 `daofa:benming:N` 技能、有该类武器；原版另排 `hiddenGear`，v0.62.12 恒 false）。
  - 神兵试炼菜单每页 4 位，翻页／返回／离开，标签改「［试炼完成］／［已领悟］」，说明三行照新源。`_start_weapon` 按神兵本身（不是序号）开战，先核对仍有效、没有待开的试炼（原版另判 `inBattle`，重制闭关菜单只在地图上跑，不判）。
  - 神兵试炼结算：只记试炼完成（有人活着），**不再给真气**；不顺带降服灵根；`zq_weapon_trial` 敌人经验、金钱为 0（`enemy.gd`），`battle_logic.rewards()` 末尾照原版 makeRewards 包装：幻化之战清空物品（含米拉深渊额外掉落），神兵试炼经验金钱清零。
  - `spec_state`：只有 `weaponTrials` 的旧档补上 `w`；`_learned` 照 learned45（true 或正数）。
  - 灵根解锁再认只给灵根的新备注 `<CodexZhenqiLinggen:…>`，与 `<Element Absorb>` 合并，同元素只提示一次。
  - 指定道法：`_roll_daofa` 掷出的道法存 `pendingDaofaRoll`（随存档，`from_save` 读回），返回、读档都不重掷；本命兵／灵根走 `_pick_specialization`（可指定项每页 4 个、翻页、「随机（X）」、「稍后再选」），`_finish_daofa` 核对后学技能、记 `spec`、清掉 roll；选属性奖励也清 roll（原版 `done`）。
- 第 5 条首领血条（瓶颈之战、神兵试炼、可指定本命兵 Boss）属界面车道（`battle/boss_hp_bar.gd`），没做。
- 测试：`xiyou_zhenqi_break` 的 `flow_weapon_menu` 选项数 9→7（新源每页 4 位＋下一页＋返回＋离开）；新增 `daofa_roll_kept`、`daofa_roll_cleared`（掷出结果读档不重掷、选定后清掉）、`weapon_no_exp_gold`（神兵试炼经验金钱为 0、物品清空）。

## 交接板

- 下一步：首领血条第 5 条归界面车道；`xiyou_zhenqi` 6 条 `page.*`（真气状态页改版，新源改成挑战评估＋建议）在本分支改前改后都挂，归界面车道（CV 范围里有 zhenqi）。
- 用户试玩说明：无（集成分支）。
- 需要用户决定：无。原版玩法照搬，没有用开关的地方。

## 进度账

- 无变化。

## 结果

| 场景 | 前 | 后 |
|---|---|---|
| zhenqi_break | 76/83 | 85/85（含新增 2 条） |
| zhenqi_daofa | 55/68 | 69/69（含新增 1 条） |
| zhenqi | 175/181 | 175/181（同前，界面车道） |

## 验证

- 本机新源：上表；另跑碰 `XZhenqi`／`rewards()` 的 23 个场景，改前改后失败集合逐条相同（battle_gaps 1041/1043、book_capacity_ui、dungeon、guide、power、random_streams 本来就挂），其余全过。
- 语法检查 592 个 .gd 0 问题。
- `事件空绿扫描.py --check` 不过：4739 条「event_states.json 没量／预设已删（产物过期）」，与 newsrc5 交付时同数，本树事件状态产物落后，本分支没碰预设和事件。请总装在集成分支同步后看。
- 没跑云端选测（本机已跑全部相关场景）。
- 新增 3 条断言在旧代码上会挂（旧代码没有 `pendingDaofaRoll`、`zq_weapon_trial`），没单独留挂的记录。

## 可回退

- 无开关。回退＝还原本分支对 `zhenqi.gd`、`enemy.gd`、`battle_logic.gd` 的改动。

## 待交叉核查

- `zhenqi.gd`（神兵列表、菜单、结算、指定道法、存档）、`enemy.gd`（`zq_weapon_trial`）、`battle_logic.gd`（`rewards()` 末尾清零）、两个测试文件。

## 本分支提交

- `git log cc/wukong-newsrc5..cc/wukong-newsrc6`
