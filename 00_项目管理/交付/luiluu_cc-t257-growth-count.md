# 交付：luiluu/cc-t257-growth-count

- 车道／工作者：T257 无限成长②三人计数接线（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-19 【cc·T257·未经审查】天启篇无限成长三人计数接线：渡鸦灵魂、奈叶适应、流萤胜场；T256 核查三条（dev.待定）

- 依据私密设计仓 `重制设定/天启篇_无限成长_v0.4.md`（2524a5d）3.1～3.3、第八节卡②「四处必看的坑」；Kyo D216「216全推荐」：Q3 甲、Q5 甲、Q6 乙。都只在天启篇且 `XTianqiGrowth.ENABLED`（O-620）开着时走，关掉回 T220 现状；西游档不走。没加存档字段。
- 渡鸦（`core/raven.gd`）：层数魔攻照旧只由 `XTianqiGrowth.param_flat` 平加（只判学会 10136、不判镰刀），没写进 `param_plus`。新 `growth_gain`：没学 10136 灵魂存到 15 万就停；学了 10136，20 万以内哪儿打都算，超出的部分过 `floor_ok`（Q6 乙），不过只记到 20 万。新 `growth_clamp`：`sync` 开头（学 10136 之前）把超过 15 万的灵魂压回。
- 奈叶（`core/nanoha.gd`）：基础段 2000 次以内照原版每次 +10 生命、+30 魔法；过 2000 次不再调 `add_param`（层数生命魔法由平加给），超出的次数过 `floor_ok`；跨 2000 那一下拆开（1999.5 次亲手打倒一个：前半次 +5／+15 补满基础段，后半次过 `floor_ok` 才记）；改完次数调 `param_mark_dirty()`。不碰 `actor_modules.gd`、`actor.gd`。凤霞地雷注释留在 `growth_add` 上方。
- 流萤（`core/liuying.gd`）：Q5 甲——胜场改成出战打赢就记（不看主手 4004），去掉「余烬满 ×1.2」；300 胜以内照旧每胜 +10 余烬、封顶 3000，超出的胜场过 `floor_ok`；有效余烬＝min(3000, 存档余烬)＋500×层数，在 `param_plus` 现算、不写存档；层数伤害 ×(100＋层数)/100 乘在 `tq_ops` 的 `_action` 判断之前（普通攻击也吃，物品不进 `tq_ops`）。
- `core/tianqi_growth.gd`（T256 核查）：P2-1 `unrace` 在内层减益下按 before÷param_before_alien 缩平加再退种族（只缩不放），不再过退；P2-2 改成 `XRaceBattle.param(a, i, before − f) + f`，人族渡鸦 1～30 层逐层正好 层×N；P3-1 `facts` 的 `finale` 照 `XTianqiBrand.classify` 排除四骑士开场生存战（mode＝survival）。
- `发行空壳特例.json`：`XTianqiGrowth.floor_ok`（放行）、`actor_row`（空值安全）、`ember_bonus`／`dmg_pct_of`（发行值 0）——西游代码只在 `on()` 为真时用到，空壳 `on()` 恒 false。
- 专项：新 `tests/xiyou_tianqi_growth_count` 39/39；`xiyou_tianqi_growth` 改一处次序（学会 10136 之后再灌魂，否则升级 sync 会照新规则压回 15 万）52/52。
- 玩家可见：天启篇流萤不用戴飞萤逐火也记胜场，满余烬不再 +20% 伤害；渡鸦没学至尊鸦皇时灵魂停在 15 万；渡鸦、奈叶、流萤过了基础段以后，回低层刷不再涨成长计数。状态行和卡面字是卡④（待小A 审），本卡没写玩家可见文字。

## 交接板

- 下一步：T258 探针标定（growth.json 的 N、Y）、T259 卡④文字（状态行、10136／5683／10624 卡面、4004 说明栏）；见下面「发现」第 2、3 条。
- 需要用户决定：无（第 3 条是否也去掉 4004「每 1 万生命终伤 +1%」待协调判断是否问 Kyo）

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：`XTianqiSave.after_load` 加一行 `XRaven.growth_clamp`（见发现 2），总装合并时顺手或派给管 tianqi_save.gd 的车道，约 1 行。

## 发现

1. 验收逐条：①四处坑都照做（渡鸦不进 param_plus、不判镰刀、没学 10136 停 15 万；奈叶不碰 actor_modules／actor；流萤三处；奈叶拆半次＋param_mark_dirty，渡鸦 on_enemy_death、流萤 _growth_win 跨层同样调）；②Q5 甲；③三人超出基础段都过 floor_ok；④T256 P2-1／P2-2／P3-1；⑤开关关掉回现状（专项比过：渡鸦不封顶、奈叶原版逐次公式、流萤要 4004 且 ×1.2、余烬回 min(3000)）；⑥专项覆盖；⑦虚拟玩家见「验证」。
2. **渡鸦「读档压回」的落点**：读档入口（`xstate.gd`／`tianqi_save.gd`）不在本卡独占文件里，压回放在 `sync` 开头——10136 只在 sync 里学，所以「学会那一刻兑现预攒灵魂」照样堵死；差别只是旧档读进来到下一次升级之前，灵魂页显示的数可能高于 15 万（不影响任何属性）。要严格读档就压，见「可优化」。
3. **4004 还有一处在天启篇生效**：`liuying.gd` `damage_ops`（`_action` 分支里）戴 4004 时「每 1 万最大生命终伤 +1%」没有天启篇判断。Q5 甲只点名去掉 ×1.2，本卡没动它；4004 在天启篇当纪念品的话可能也该去掉，卡④改 4004 说明栏时一起定。
4. 已知遗留（T256 发现 2）：饥荒遗物在种族之内、平加之外，仍放大层数那截；P2-1 的缩放只缩不放，没顺手处理。
5. 公共规矩读的是 v1.6。

## 验证

- `xiyou_tianqi_growth_count` 39/39（单跑，`--headless --audio-driver Dummy`）。
- 并行选测 27 个场景全部通过：xiyou_tianqi_growth、xiyou_tianqi_growth_count、xiyou_liuying、xiyou_liuying2、xiyou_liuying3、xiyou_liuying_help、xiyou_nanoha、xiyou_raven_soul、xiyou_raven_battle、xiyou_raven_artifact、xiyou_three_growth、xiyou_race_battle、xiyou_tianqi_skills、xiyou_tianqi_save、xiyou_param_cache、xiyou_tianqi_affix_battle、xiyou_tianqi_balance、xiyou_tianqi_ledger、xiyou_tianqi_ledger_p3、xiyou_tianqi_phase4、xiyou_tianqi_phase4_modules、xiyou_tianqi_rewards、xiyou_tianqi_brand、xiyou_actor_modules、xiyou_param_states、xiyou_alien_battle、xiyou_determinism。
- 虚拟玩家（种子 7）：explore 14/14 退出码 0；短帧 climb（`--vp-frames=60000`）9/9 退出码 0：卡死 0（stuck 空、stalemates 0）、脚本报错 0、硬性违规 0（climb 违规空；explore 4 条「生命高于上限」hard=false，开局战斗里的，跟本卡无关）；climb 中途全灭回标题、读档后接着打赢，存读档正常。只爬到第 1 层、阵容里没有这三人，成长本身靠专项。
- `语法检查.py` 0 问题；`发行空壳.py check` 通过；`天启篇数据校验.py` 全部通过（表格式没改）。

## 本分支提交

- e9192c7e6 三人计数接线、T256 核查三条、专项
- （本交付单与发行空壳特例一同提交）
