# 交付：codex/passive-content-merge-main

- 车道／工作者：集成／沙僧（Codex，重制_沙僧_75）
- 状态：进行中（冲突文本已初步合并，尚未同步或引擎验证，不可按可合并收取）
- 交付范围截至5761f01f；新分支从该点建立。PREE已独立保存至c5953948，未带入本分支。
- 本次合并本地main：9b140f365f93c2cfa4b19d85b6ddd72576830c16；不以远端覆盖本地。两父合并保留提交链。
- 用户明确要求先评判并执行Claude交代，原文留[只读交代证据](../核查范围/连续分支合main_Claude交代_20261026.txt)。方向合理，集成优先，PREE暂停；不自行销核或登记完成度。

## 冲突处理初稿（逐项待专项验证）

1. battle_logic.gd：保留资源域版_start_battle_effects（同样整队初始化TP后再Battle分发）；保留main的种族／异化开战及1320预约。减耗先dsPassive再外层XRaceBattle.cost（冻结安装先后）。Boss回合霸体同步＋main传入随机／变量上下文并存。HP接口保留main第五项item参数，异化outgoing外包Boss settled资源域，再导入平衡／护盾／实际损血记录；冻结main.js Boss在122、异化在128～131行，后装者在外。
2. actor.gd：权能书准入与XActorModules.can_learn同时保留；ConsumeReduce缓存扫描后再XActorModules.passive_cache。主线已有XTraining／XParamPlus及种族→小猫→角色模块挂点不回退；后续核查自动合并部分及专项。
3. battler.gd：死亡钩子只保留一处XEnemyBook.note_death，另保留XRaceBattle.on_death；状态时长继续用生命周期duration_key，并在其后同步异化腐蚀。
4. enemy.gd：缓存外先Boss属性倍率取整，再后安装的异化最大生命倍率；不预乘基础值。
5. enemy_book.gd：采用原分支更早bind_battle的真实实例弱引用边界，保留死亡→复活→再死亡逐次计数和既有结算补漏防重记；不叠加main第二个同名note_death。资源死亡统一经battler加阵亡，所以无第二份手工死亡计数。需要图鉴专项确认main的即时计数语义仍保留。
6. resource_context.gd：保留原分支add_state_with_context统一资源死亡路径，不复制main旧版手工清状态／计数路径；种族死亡清反攻由同一battler入口调用，不重复。
7. state_effects.gd：支持op集合取并集；永久加算、资源写入、预览边界与main叠毒／加状态／gain_steps／计数器等helper并存。poison_stack也服从execute守卫，emit并入合成inputs。新helper与既有资源域的交互仍须审视和专项，未凭文本无冲突声称语义已验证。
8. xiyou_export.py：保留永久属性整块翻译＋main叠毒／gain／计数器整块翻译，各函数保留各自return None，Python语法已过。
9. xstate.gd：本地main前进后新增的第九处冲突。读档先XPets.loaded(s)，随后保留main参数缓存标脏／刷新，两个职责都保留；待读档与宠物／角色模块专项。

## 一并交付的14张原交付单

- [codex_actor-bonus-states.md](codex_actor-bonus-states.md)
- [codex_actor-bonus.md](codex_actor-bonus.md)
- [codex_four-loose-fixes.md](codex_four-loose-fixes.md)
- [codex_passive-content-book-capacity.md](codex_passive-content-book-capacity.md)
- [codex_passive-content-boss-context.md](codex_passive-content-boss-context.md)
- [codex_passive-content-boss-output.md](codex_passive-content-boss-output.md)
- [codex_passive-content-boss-react.md](codex_passive-content-boss-react.md)
- [codex_passive-content-boss-sequence.md](codex_passive-content-boss-sequence.md)
- [codex_passive-content-boss-state-origin.md](codex_passive-content-boss-state-origin.md)
- [codex_passive-content-boss.md](codex_passive-content-boss.md)
- [codex_passive-content-power-books.md](codex_passive-content-power-books.md)
- [codex_passive-content.md](codex_passive-content.md)
- [codex_rng-compare-review.md](codex_rng-compare-review.md)
- [codex_state-effects-2g.md](codex_state-effects-2g.md)

- 树中另有codex_stage-review-50.md与codex_stage-review-50-phase2.md两张既有阶段审查单，未删除、未改结论；它们随既有祖先链存在，不把阶段审查算作上述14张中的新实现。总装收取时核对是否已登记并决定归档方式。

## 变更记录草稿

## 2026-10-26 【Codex·沙僧·未经Claude检验】连续交付与main集成（dev.待定）

- 截至5761f01f的14张交付单与本地main 9b140f36集成，实际九文件冲突采用两侧语义并存的初稿；验证尚待执行，不称完成。
- PREE不在本期；原版证据、全部.sandbox、失败／未完成样本、generated和整树保留。不改主工作区或共用登记。

## 验证与下一步

- 已做：九文件无冲突标记，git diff --check，xiyou_export.py编译检查。
- 未做：同步、测量差异接受审阅、Godot导入、检查.sh --affected main --oracle、14期与main冲突影响专项。禁止把初步合并当验证通过，禁止在验前标可合并。
- 先检查全局是否有同步进程；没有才用长任务.py start执行同步正式西游.py（python3 -u、XIYOU_TEST_HEARTBEAT=30），等待任务.sh每次--timeout45。不要--full，不绕共用四槽；源与切片变化按同步报告逐项检查，有既有测量变化必须接受单，不无条件接受。
- 固定main基准9b140f36后跑选测；已覆盖的原交付专项只列覆盖，不重复无意义运行，缺的补一次。仍含旧8项early_inventory_rule确定性失败时要区分继承／新增，不迁就测试或声称整轮全绿。
- 检查通过后由本分支推送github并向Kyo交付，交叉核查保留；总装才合入main和登记。然后回PREE，合入本集成分支再继续。

## 交接板

- 下一步：先完成本集成验证与交付，再恢复PREE；本单目前非可合并。
- 用户试玩说明：待集成验证通过后按原14张交付单汇总；本期不新增玩法。
- 需要总装决定：若审视新状态helper与资源域时必须大改main接口，先留具体冲突与参照，不在本期顺手重构；目前尚未作出需要大改的结论。

## 可优化

- 已做：以选测实际覆盖表去重原14期专项，保持覆盖不减少；回退方式为逐场重复运行。尚未运行所以不宣称节省实测时长。
- 共用槽等待改进仍留工具车道；本分支不修改并发上限或抢占他人任务。
