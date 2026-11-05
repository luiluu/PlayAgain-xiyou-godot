# cc/bailong-ui7 交付单

- 车道／工作者：E 角色专属／白龙（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·白龙·未经审查】新角色技能菜单补「功法」页（dev.待定）

接 tail7 的缺口。冻结源规则来源：`js/codex/runtime/installV010UsabilityRuntime.js`，`newActor(actor)` = `actorId` 在 167～177（含两端）；包装 `Window_SkillType.makeCommandList`：先滤掉已有的 `skill＋ext 6`，再在被动（ext 4）前插「功法」（`$dataSystem.skillTypes[6]`，enabled，没学功法也列），没有 4 时插在 `min(2, 长度)` 位；同时包 `addedSkillTypesForMenu` 补 6。注释写明「战斗分类保持原生」，所以**战斗指令窗不加**。包装在隐藏呼吸 3 之后，故 167／172 为 `[1,2,6,4,5]`，173／174 同。

- `actor_modules.gd` 新增 `menu_page_types(actor_id, types)` 与 `GONGFA_*` 常量；`skill_scene.types()` 两路（强制表／特性表）都过一遍。屠苏、璇原本特性里就有 6，被先滤再按规则放回，位置在 4 前，结果与规则一致。
- 战斗指令不动（`_command_entries` 本就跳过 3～6）。空页显示沿用现有技能页（不选中任何技能，列表为空），原版同为空页。
- 专项：`xiyou_battle_log` 的 `types.menu-sorted`、`types.hide3.*` 改 `[1,2,6,4,5]`；新增 `types.gongfa.fn`（边界 166／167／177／178、已有 6、空表、无 4）与 `types.gongfa.<id>`（队里有 167～177 的角色时 6 在 4 前）。

## 交接板

- 下一步：无。
- 用户试玩说明：渡鸦、宿傩、饿狼、云裳、屠苏、璇等 167～177 号角色技能页多一页「功法」（被动前），战斗指令不变。
- 需要用户决定：无

## 进度账

- 不加分（对齐原版）。

## 验证

- `语法检查.py` 0 问题。
- 本机 `CHECK_JOBS=2`：xiyou_battle_log 71/71、xiyou_skill_page 21/21、xiyou_tusu_ui 28/28、xiyou_skill_menu_events 10/10。
- `云端选测.py`：33 场景 3 片通过（提交 cedd511db7，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41953233373）。
- 没做原版实机再量：规则取自冻结源代码，tail7 已有 167～175 实机 `[1,2,6,4,5]` 对照。未跑 `工具回归.py`（只改 .gd）；未开窗口截图。
- `types.gongfa.<id>` 只对测试队伍里有的角色生效，其余靠 `.fn` 覆盖。

## 待交叉核查

- 没改 battle_logic／actor／battler 等核心文件。
- 请核 `menu_page_types` 的插入位与冻结源包装是否一致（尤其无 4 时的 `min(2,len)`）。

## 本分支提交

- 见 `git log cc/bailong-tail7..cc/bailong-ui7`

**可合并**
