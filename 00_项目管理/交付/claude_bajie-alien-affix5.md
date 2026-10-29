# 交付：claude/bajie-alien-affix5

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_84）
- 状态：进行中（期一：投影接点＋祸祝）
- 本期：异化第③批「行动道具投影」。期一：投影接点＋祸祝 blessing；期二：恶愿 wish、逆祷 prayer。从 claude/bajie-alien-affix4（d728ec70）切出，合过一次 main（fa746789）。

## 原版依据（冻结 v0.28 `js/codex/runtime/`）

- Aff＝installAlienationAffixes.js，Adv＝installAlienationAdvanced.js。
- 投影：Aff:41-47。`Game_Action.prototype.item` 整个换成 `A.project`：角色行动、词条是祸祝且技能在 templates.blessing（只有 7100 幻日虹）时，返回 `A.clone(技能)` 改过的视图，按行动缓存（`action._alienView`）；`DataManager.isSkill` 认 `_alienOriginal`。
- 祸祝（Aff:44）：scope 原为 8 改 2，其余改 1（敌方单体）；效果 31（增益）改 32（减益），其余效果的 dataId 换成 `statePairs[dataId]`；名字「祸祝·原名」。7100 是自身加速（附加 2421 幻日虹），投影后给敌人附加 2668 祸祝·幻日虹（速度 ×0.75，10 回合）。
- Aff:5（云裳 transferDebuffs 加上 statePairs 的诅咒与腐蚀）：`alienation.json` 的 transferDebuffs 是装好之后导出的，已经含 2653～2671、2652，`xiyou_alien_config` 核对过，不用另做。

## 重制落点

- `alien_battle.gd`（XAlienBattle）新节「行动道具投影」：`project(u, skill)` 与 `_project_blessing`。角色、非物品、未投影过、词条与模板对上才投影；投影是技能字典的深拷贝，保留原 id，另记 `_alienOriginal`、`_alienMode`、`_alienOriginalScope`。没有配对的 dataId（原版 NaN，什么也不附加）记 -1。
- `battle_logic.gd` `execute`：`weapon_unleash` 之后、付费之前 `skill = XAlienBattle.project(u, skill)`。之后费用、目标、命中、伤害、效果、`action` 记录的名字都读投影（原版 item() 在这些地方都被换掉）。
- **没接（待唐僧批）**：`battle_scene.gd` `_pick_target` 开头加一行 `skill = XAlienBattle.project(a, skill)`，选目标界面按投影后的 scope（祸祝选敌人）。不加时界面按原 scope（自身）走，不弹选敌；逻辑里 scope 1 拿不到选中的敌人，改随机一名敌人（`targets_for`）。
- 自动战斗／智能 AI 选技仍按原技能评估（见「没做」）。

## 优化登记（O-109）

| 编号 | 原版 | 重制 | 回退 |
| --- | --- | --- | --- |
| O-109 | 投影用 `A.clone`（JSON 克隆）复制技能，丢了 YEP_SkillMasteryLevels 挂在技能对象上的 `masteryMpCost`／`masteryTpCost` 函数。用祸祝技能时 `skillMpCost`／`skillTpCost` 调不到函数而报错，`SkillMasteryLevelsError` 先 `alert` 再 `SceneManager.terminate()`：**正式游戏里一用祸祝技能就弹错退出**（探针里每次使用触发 2 次，MP、TP 各一次）。逆祷（克隆技能 8）、恶愿（克隆原技能）走的是同一个克隆，期二要再确认 | 不崩，费用照原技能算。熟练度费用公式插件默认是 `cost`（不随熟练度变），7100 没有自定义，所以数值与「报错被吞」时一样 | 无开关：回退就是退出游戏，没有可复现的结算差别。登记行写明这一点，用户可以否 |

## 验证

- 专项 `xiyou_alien_affix` **867/867**（原 825，多 42 项）：新加 battle.blessing（穿异化本体 1020 世界树之枝；7100 打敌人 0、敌人 1，再普攻一次看不投影）、battle.blessing.none（无词条，7100 给自己加速），每步比双方状态与生命法力，另比投影后的名字、scope、效果（`view`，不比 `terminated`）。跑专项时临时把探针输出拷进 `generated/oracle`，跑完已拷回。
- 选测：（跑着，见下次更新）
- 同步：（待跑）

## 变更记录草稿

## 2026-10-29 【Claude·八戒·未经Codex检验】异化第③批期一：行动道具投影接点＋祸祝（dev.待定）

- **内容**：异化词条「祸祝」在战斗里生效：带祸祝的角色用幻日虹（7100），改为对一名敌人施放，加速状态换成对应的诅咒（祸祝·幻日虹，速度 ×0.75），技能名显示「祸祝·日之呼吸·肆之形 幻日虹」。接点是 `XAlienBattle.project`（原版换掉 Game_Action.item），在 `execute` 里武器解放之后换一次。
- **优化 O-109**：原版这里会让游戏弹错退出（投影丢了技能熟练度的费用函数），重制不崩，费用照原技能。
- **参照**：`alien_affix_probe.cjs` 加 battle.blessing／blessing.none 两例，能在开战前学技能（`learn`，要先学会模板技能才穿得上），记录行动开始时 item() 的名字、scope、效果与 terminate 次数（把 `SceneManager.terminate`、`alert` 换成计数）。

## 交接板建议

- 下一步：本分支期二（恶愿、逆祷）。
- 用户试玩说明：异化装备的「祸祝」现在战斗里生效。原版用祸祝技能会弹错退出，重制不会（O-109，请拍板）。
- 需要用户决定：O-109（祸祝投影原版崩溃，重制不崩），按默认继续。

## 没做

- 选目标界面的投影（`battle_scene.gd`，等唐僧批，见「重制落点」）。
- 自动战斗、智能 AI、挂机的选技与评估按原技能（原版 evaluate 读的是投影）。祸祝只影响 7100 一个技能，落到逻辑里照样投影；只是 AI 估值不同。

## 可优化

- 探针：参照引擎被 terminate 之后后面的用例全挂、报的是 `location` 未定义，看不出原因。可以在 `shared/host.cjs` 的 start 里默认把 `SceneManager.terminate` 换成「记一笔并抛错」，探针直接报出是哪一步触发的（这次花了几轮才查到）。归维护探针工具的车道。

## 本分支提交

- 7df2e3db WIP: 异化第③批期一：行动道具投影接点（execute 里武器解放之后）＋祸祝，探针两例，专项 867/867
- 2ce366ed Merge branch 'main' into claude/bajie-alien-affix5
