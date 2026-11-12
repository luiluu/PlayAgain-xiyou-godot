# 交付：cc/gojo-fix

- 车道／工作者：天启篇五条悟第一期返工／cc（五条悟线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-12 【cc·五条悟·未经审查】五条悟第一期返工：原版档的超强者名单不再算他，参照专项排除新加记录（dev.待定）

- 总装四十 dev.509～515 整轮挂 8 个场景，都是五条悟第一期（cc/gojo）开表补进 180 号角色、技能、职业、状态之后带出来的。
- 真问题（玩家可见）：原版档里 `XTier` 把 180 算进超强者，地图 4 事件 41「破阵·投影」列的超强者名单从 45 人变成 46 人（事件对照 b～d 共 6 条回归）。改成 `XTier.tier_of`／`ids` 在原版档（`XGojo.hidden`）不算他，`XItemMarks.super_strong_ids` 的缓存里也不留他；天启篇照旧读 `XTianqiSkills` 名单。
- 参照专项只排除新加记录，断言本身没放松：`xiyou_hidden_actors` 图鉴槽数、`xiyou_reincarnation_entry` 会 8105 的人数、`xiyou_rift2_canglong` 比原表时同样补上五条悟的技能和职业、`xiyou_xuan_battle` 可净化状态表、`xiyou_event_compare` 全角色循环的观察名单。
- 玩家可见：无（修的是还没合到玩家版的问题）。

## 交接板

- 下一步：五条悟第二期（眼罩法宝、最强之名解锁、正式头像；美术需求清单已给 Kyo）。
- 用户试玩说明：无。
- 需要用户决定：无。

## 优化登记

无（沿用 cc/gojo 的开关 `XGojo.ENABLED`）。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 建议：新加原创角色会碰所有「全角色、全表」类的原版参照专项。可以在选测对照里把 `xdb.gd` 开表补丁的改动映射到这批参照专项（hidden_actors、reincarnation_entry、rift2_canglong、xuan_battle、event_compare 四段、actor_book、actor_advanced、skill_mastery），免得车道漏跑；归工具车道。cc/gojo 第一期就是漏了这几个。

## 验证

- 语法检查通过。
- 单跑：`xiyou_hidden_actors`、`xiyou_reincarnation_entry`、`xiyou_rift2_canglong`、`xiyou_xuan_battle`、`xiyou_event_compare`、`xiyou_event_compare_b`～`_d`（总装报的 8 个），加 `xiyou_gojo`、`xiyou_tianqi_skills`、`xiyou_super_acquire`、`xiyou_super_deploy`、`xiyou_item_marks`、`xiyou_weak_challenge`（改了 XTier、超强者缓存）。

## 本分支提交

- （见 git log）
