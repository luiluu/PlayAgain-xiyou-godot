# 交付：cc/bailong-chars2

- 车道／工作者：E 角色专属／白龙（cc，FF2，接 cc/bailong-chars1 第二期）
- 分支起点：cc/bailong-chars1 末端 0630f569（一期还没合进 main），已合 main 26c4fe69。**合并时先合 chars1 再合本分支**（本分支含 chars1 全部提交）。
- 状态：云端选测进行中（见「验证」），结果出来后改成「可合并」

## 本期两项

| 运行时 | 处理 |
| --- | --- |
| installDualExclusiveRuntime（v0.62.10，68 行） | **本期做**：双持时专武只能装一把（白晶晶 76 例外） |
| installVegettoFormRuntime（26 行） | **本期做**：哪吒 newsrc6 的 `costume_form_remove` 只管 2771～2773 移除那一下；原版是 battlerName 最外层包装，图被还原成本体（如超蓝 2774 移除时还原旧图、旧档）而身上还有形态时按最高形态补图，重制原先没有，这期补上 |

## 待交叉核查（审查甲档：装备与存档相关）

- `core/equipment.gd`：新 `is_exclusive`／`dual_blocked`／`release_dual_exclusive`、`DUAL_EXCLUSIVE_EXEMPT`、开关 `FIX_DUAL_EXCLUSIVE_BEST`；`change` 开头挡（另一武器栏已有专武时不换）；`optimize` 候选跳过专武（开关）。
- `core/actor.gd` `release_unequippable` 末尾一行：`removed.append_array(XEquipment.release_dual_exclusive(self))`——武器栏里的专武只留排在前面的一把，其余跟别的卸下件一样由调用处放回背包（换装、`release_to_party`）；预览克隆与 `init_equips` 只卸不入包（与原有卸下件处理一致；原版 initEquips 时会进背包，入队装备表里没有两把专武的角色，不影响）。
- `ui/equip_scene.gd`：候选里被挡的专武画暗（`XUI.DIM.a`），确定时蜂鸣不换（Window_EquipItem.isEnabled）。
- `core/costumes.gd`：`battler_name` 末尾套 `vegetto_form`（换装卡生效且有图／图名已不是数据库原图的保留，否则按 2774＞2773＞2772＞2771 取 clbjt／cjbjt3／cjbjt2／bjtc1，再退回原图）。

读档：原版没有读档时整理，旧档两把专武是在下一次 refresh（releaseUnequippableItems）时卸下；重制同样落在 `release_to_party` 的各调用处（加减状态、参数变化、资源刷新），没有另加读档钩子。

## 优化登记草稿

已直接写进 `03_再刷重制_Godot/00_设计/优化登记.md`（真火那行下面）：**O-待定·双持专武最强装备**——原版「最强装备」第二栏想跳过专武，但跳过挂在 Game_BattlerBase.canEquip 上，Game_Actor.canEquip 是饿狼等运行时包装出的自有函数（探针里 `hasOwnProperty` 为真），走不到；第二栏挑中专武后被 changeEquip 挡下而空着。重制默认修好（挑下一件最好的），`XEquipment.FIX_DUAL_EXCLUSIVE_BEST = false` 回原版。需要 Kyo 确认，写进交接板「需要用户决定」。

## 变更记录草稿

## 2026-11-07 【cc·白龙·未经审查】双持专武只能装一把、贝吉特形态图兜底（跟到 v0.62.12）（dev.待定）

- **双持专武**（`core/equipment.gd`，跟 `installDualExclusiveRuntime` v0.62.10）：专武＝带 `<req_actors>` 的武器；另一个武器栏已有专武时换装不换、装备页变灰、最强装备跳过；旧档同时装着两把的，下一次刷新只留排在前面的一把，另一把退回背包。白晶晶（毒吻＋穿肠）例外。原版最强装备第二栏会空着，重制默认补上下一件最好的（O-待定·双持专武最强装备，可回退）。
- **贝吉特形态图**（`core/costumes.gd`，跟 `installVegettoFormRuntime`）：图被还原成本体或留空、身上还有超赛／超蓝时，按最高形态补战斗图。
- 参照：`mv_oracle/dual_exclusive_probe.cjs`（刘备、紫霞 2 段 19 步），夹具 `tests/fixtures/dual_exclusive_oracle.json`；专项 `xiyou_dual_exclusive`（126 项）、`xiyou_vegetto_form`（17 项）。
- 玩家可见：刘备、紫霞等双持角色不能再同时拿两把专武；贝吉特形态切换时战斗图不会掉回本体。

## 交接板

- 下一步：白龙两期都交了，角色专属类运行时盘点剩「◆唯一」说明（界面车道）。
- 用户试玩说明：同上「玩家可见」。
- 需要用户决定：O-待定·双持专武最强装备（默认修好，回原版是第二栏留空）。

## 进度账

- 角色：待总装按本期两项核定。

## 验证

- 合 main 26c4fe69：冲突只在 `优化登记.md`（main 的 O-231 与 chars1 的真火行都留），之后 `新建工作树.sh --补齐` 重跑。
- `语法检查.py` 0 问题；`工具回归.py` 全过（含探针登记检查：新探针有同名夹具、关了五乘区）。
- 本机专项 13 个全过：`xiyou_dual_exclusive`、`xiyou_vegetto_form`、`xiyou_dual_wield`、`xiyou_equipment`、`xiyou_equipment_admission`、`xiyou_equipment_clone_state`、`xiyou_costumes`、`xiyou_state_effects`、`xiyou_actor_looks`、`xiyou_liuying2`、`xiyou_cat`、`xiyou_mira_battle`、`xiyou_wtype`。
- 云端选测：`云端选测.py run`，提交 9a364943，基准 92c94104a8，345 个场景（含 chars1 改动面、xiyou_determinism、xiyou_rules 全段）。结果：待填。
- 原版探针：`dual_exclusive_probe.cjs`，跑法 `NODE_PATH=<主工作区>/03_再刷重制_Godot/03_转换工具/mv_oracle/node_modules node <探针>`；产物拷进 `tests/fixtures/`，不进同步 PROBES。探针里刘备／紫霞直接写 `_level=80`（新游戏有等级上限，只为过 `<req_level>`）。
- 测试里参照比的是原版（`FIX_DUAL_EXCLUSIVE_BEST = false`），修好的一头另比两例（刘备 2007＋2、紫霞 1696＋2）。
