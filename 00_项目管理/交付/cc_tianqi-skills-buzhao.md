# 交付：cc/tianqi-skills-buzhao

- 车道／工作者：天启篇全角色技能重构补招一期（1～30 号）／cc（技能重构）
- 状态：可合并

接在 cc/tianqi-skills-p2b 后面切出（含 p2、p2b），要在它们之后合。

## 变更记录草稿

## 2026-11-12 【cc·技能重构·未经审查】天启篇全角色技能重构补招一期：1～30 号补的招（dev.待定）

- 按设计稿第四节第 5、9 条补招，名字是拟的、Kyo 可以改：四小强 30 级爆发技（修「因果审判」魔攻 6.0、罗琳「圣盾冲锋」攻×3.0＋双防各×1.6、美娜「月下背刺」攻×3.0＋敏×3.0、里德「破军一击」攻 6.0，都冷却 3）、克莱德 10 级「圣疗术」（单体治疗 30% 生命）、玛莎 20 级「狂风术」（全体三段，每个敌人合计 1.5）；维利的百式观音在天启篇 30 级就学会（进阶照旧也给）。
- 新技能不插进 Skills 表：`skill_rework.json` 的 `new_skills` 给表外号段（10701 起），`XDB.rec` 遇到这些号时按底号复制一条再照常改写，遍历全表的原版对照不受影响。`learn` 按角色（不按职业，克莱德和玛莎同职业）加学习等级。
- `XActor.learnings()` 取代三处直接读职业技能表（新建、升级、改等级）；天启篇卡开着时加上补招。开卡之前已经过了等级的老存档，开战时补学（`XTianqiSkills.sync_learn`）。
- 和角色卡一样只在天启篇、`XTianqiSkills.CARDS` 打开时生效（默认关）。
- 专项 `xiyou_tianqi_skills` 扩到 104 项。
- 玩家可见：无。

## 交接板

- 下一步：技能重构第三期 31～60 号（角色卡＋专属物＋补招一起写，gear、new_skills、learn 表都能直接用）。
- 用户试玩说明：天启篇打开角色卡后，四小强 30 级、克莱德 10 级、玛莎 20 级各多一招。
- 需要用户决定：无（招名可改）。

## 优化登记

- 无新开关（在 `XTianqiSkills.CARDS` 下）。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 无。

## 待办

- 人物图鉴的技能列表（`actor_book.gd` 读职业技能表）还不显示补招。
- 号段 10701 起是表外号；五条悟（已在 main）开表时把 10634～10650 接在表尾，补招号段留了空隙不会撞，但两种写法不同，以后可统一。

## 验证

- 语法检查、天启篇数据校验通过；`xiyou_tianqi_skills` 104/104。
- 选测：`xiyou_tianqi*` 全部、`xiyou_actor_p0`、`xiyou_actor_advanced`、`xiyou_rift2_canglong`、`xiyou_skill_mastery`、`xiyou_determinism`、`xiyou_actor_book`、`xiyou_raven`、`xiyou_tusu_xuan`、`xiyou_actor_modules`、`xiyou_garou_progress`、`xiyou_skill_change_to`、`xiyou_state_js`、`xiyou_battle_common_events`，50 个场景全部通过。
- 没跑：`xiyou_rules*`（改了 actor.gd 学技能的读法、xdb.gd 表外号段；原版档结果不变），请总装按选测跑。

## 本分支提交

- （提交后补）
