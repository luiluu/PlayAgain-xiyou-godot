# 交付：claude/bajie-pickproj

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_84）
- 状态：可合并
- 本期：异化行动道具投影的选目标界面（affix5「没做」的那一行）。从 main（cdb32d78）切出，开工时合过 main。

## 原版依据

- 选目标时原版读的是 `Game_Action.item()`，而 Aff:41-47 把它整个换成了投影。所以 scope、needsSelection／forceSelection、妖族的猎物判定（种族 needsSelection 包装）、OTB 行动顺序预览（读 inputtingAction 的 item）都按投影后的技能。
- 逆祷 needsSelection 包装（Aff:48）：原 scope 3～6 不选目标（改随机友方），返回 false。它不经过 forceSelection。
- 说明卡：选目标时 `_help()` 不带条目，卡片隐藏（YEP 的帮助窗没有 setBattler，范围文字原版也不出现）。卡片只在技能窗里显示，读技能窗的条目，也就是原技能、不带「祸祝·」前缀。原版 Window_BattleSkill.item() 同样是原技能，所以名字显示不受投影影响。

## 重制落点

- `battle_scene.gd` `_pick_target` 开头：`skill = XAlienBattle.project(a, skill)`。之后 scope 判断、forceSelection（`confirm`）、`needs_prey_selection`／`set_manual_prey`、`_target_skill`（行动顺序预览）都用这个投影后的技能。逆祷原 scope 3～6 直接返回行动者，不进选目标。
- 返回的目标交给 `logic.act`。`execute` 里会再投影一次（同一套规则，结果相同），所以指令记录里存的还是原技能。

## 验证

- `xiyou_battle_ui` **112/112**（原 108）。新加 `_alien_pick` 一段：临时把锁队词条写进异化存储，直接调 `_pick_target`：
  - 祸祝 7100（原本作用于自身）改成选敌人，默认最右；
  - 逆祷普攻改成选友方；
  - 逆祷炸裂火球（原 scope 5）不选目标。
  - 做完撤掉锁队词条。不投影的话，7100 会进友方模式，这一段就过不了。
- 选测（10 个场景全过，没有偶发）：`xiyou_alien_affix` 966/966、`xiyou_race_battle` 653/653、`xiyou_battle`、`xiyou_battle_common_event_child`、`xiyou_battle_common_events`、`xiyou_battle_events`、`xiyou_battle_options`、`xiyou_battle_start_event`、`xiyou_battle_ui` 112/112、`xiyou_battleback_save`。
- 已清理：本车道的并行测试日志目录已删。
- 没改探针、切片、转换器，不需要同步。

## 待交叉核查

- **`battle_scene.gd` `_pick_target`（唐僧 10-29 准）**：开头投影＋逆祷 3～6 早退，共 5 行（含注释）。请核：投影要放在 `needs_prey_selection` 之前，妖族与异化同时存在时都读投影后的技能。
- 另改：`tests/xiyou_battle_ui.gd`（新函数 `_alien_pick`，在 `_select_confirm` 之后调用）。

## 变更记录草稿

## 2026-10-29 【Claude·八戒·未经Codex检验】异化投影的选目标界面（dev.待定）

- **内容**：战斗里选目标时按异化投影后的技能：带祸祝的角色放幻日虹改成选敌人；带逆祷的角色用攻击改成选队友，原来打随机几名敌人的技能不用选。说明卡不变，仍显示原技能。
- **验证**：`xiyou_battle_ui` 加 `_alien_pick` 一段（4 项）。

## 交接板建议

- 下一步：无（唐僧不再派新活，等用户定）。
- 用户试玩说明：祸祝、逆祷的技能在选目标时就按词条效果选敌方或友方了。
- 需要用户决定：无

## 没做

- 自动战斗、智能 AI 的选技与估值（affix5 已列）。

## 可优化

- 无。

## 本分支提交

- （本提交）
