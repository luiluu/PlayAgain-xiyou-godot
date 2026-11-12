# 交付：cc/gojo-p2

- 车道／工作者：天启篇五条悟第二期／cc（五条悟线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-12 【cc·五条悟·未经审查】五条悟第二期：专属法宝「眼罩」、开放方式「最强之名」（dev.待定）

- 依据 Pro《五条悟_角色设计_v0.2》（Kyo 11-12 定稿）第一节专属法宝、第二节开放方式；Kyo 11-12「五条悟只进天启篇」。
- 专属法宝「眼罩」（护甲 8001，装备类型 13，`<req_actors: 180>`，按宿傩神武解的样子开表补进去）：虚式「茈」结算后返还苍印、赫印各 1。五条悟在天启篇入队时（`XState.add_actor` → `XGojo.on_join`）背包有就拿、没有就生成一件装上；原版档不触发。
- 开放方式「最强之名」：证道难度、36 层骑士战打赢（`XTianqiRewards.after_final`，再挑战也算），那场开战时出战的人里有宿傩 172 或甚尔 171（中途阵亡也算）→ 全局配置 `codexTianqiGojo` 记一次（跨存档），对话框提示「五条悟：『你们打得不错嘛。』最强之名已解锁」（台词待定，设计稿原样）。
- 解锁前天启篇里也当他停用（`XGojo.locked`）；解锁后技能表名单把 180 放进超强者（17 人），候选池、抽卡池照超强者上限出（寻常、艰险上限 0 抽不到）。开新局抽阵容时当前存档还不是天启篇，候选池改问 `XTianqi._disabled`（五条悟只看解锁）。原版档照旧不出现（`XGojo.hidden`）。
- 专项：`xiyou_gojo` 加解锁、候选池、眼罩；`xiyou_tianqi_skills` 固定没解锁（超强者 16 人）并加一条解锁后 17 人；两个专项都用 `XGojo.unlock_override` 不读本机配置。
- 玩家可见：无（天启篇只在 Kyo 本地）。

## 交接板

- 下一步：五条悟美术换正式图（头像、技能图标 16 个、眼罩图标；清单已给 Kyo 交 GPT），图到了接进 `content/gojo/`。
- 用户试玩说明：证道带宿傩或甚尔打赢一次 36 层骑士，之后天启篇九死以上的候选池会出现五条悟；入队自动戴眼罩，放完茈会剩下一苍一赫。
- 需要用户决定：无（「上场」按开战时出战的人算，中途阵亡也算，照设计稿默认）。

## 优化登记

无（沿用 `XGojo.ENABLED`）。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 语法检查通过；`xiyou_gojo`、`xiyou_tianqi_skills` 全过。
- 选测：`xiyou_tianqi*` 全部、`xiyou_hidden_actors`、`xiyou_actor_book`、`xiyou_actor_advanced`、`xiyou_skill_mastery`、`xiyou_reincarnation_entry`、`xiyou_rift2_canglong`、`xiyou_xuan_battle`、`xiyou_super_acquire`、`xiyou_super_deploy`、`xiyou_item_marks`、`xiyou_weak_challenge`、`xiyou_event_compare` a～d、`xiyou_determinism`，共 57 个：第一轮 `xiyou_rift2_canglong` off.Armors 挂（比原表时没补眼罩），专项里补上后单跑通过，其余全过。
- 返工（总装四十收口挂）：`03_转换工具/天启篇数据校验.py` 的技能表规则自检超强者人数 16 → 17（五条悟在名单里，没解锁时游戏里当他不开放）；校验与 `测试天启篇数据校验.py` 39 项通过。
- 没跑：`xiyou_rules*` 全段（原版档不走新逻辑，请总装合并时按选测跑）。

## 本分支提交

- （见 git log）
