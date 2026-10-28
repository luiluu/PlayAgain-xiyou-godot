# 交付：codex/review-backlog-20261028-9

- 车道／工作者：核查／重制_沙僧_86（Codex）。
- 状态：WIP，同树接续沙僧86→87；本期未最终交付，勿合并
- 正在做什么：固定dc8057c1，核Claude黄泉一期、商店自动关闭、缺失公共事件预约清槽、通天野外五图四批；不审原单中Claude对Codex历史产品的核查结论。
- 前两期已分别交付df5e4c88／c84bf27d，待总装实际登记；仍沿用原state-effects-2b，所有原件保留，不修实现或正式测试，不改共享登记。
- 本期本地证据review-backlog-20261028-9，原单与净diff已保存。后续只按实际审查范围交付，未完成前不可合并。

## 沙僧86→87同树接续（2026-10-28）

- 实际上下文输入275071／窗口475000＝57.9%，已超过40%线，立即接续；不能只总结停工。当前额度五小时22%、周28%，均未到95%／90%停手线；未使用额度重置。用户刚明确“额度reset，加油开工”，继续清可核积压，不每期结束停等。
- 必须显式workdir=/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/state-effects-2b；UI项目关联根目录不代表文件工作区。当前codex/review-backlog-20261028-9，固定代码dc8057c186702569d93f0213d702dd52e4442b71；不建／清树，不reset／cherry-pick，不接管main，不追新main，不改共享交接板／编号／记录，不建PR。
- 第七期df5e4c88已交付推github，远端同SHA：11批13个Claude提交限定通过；W1武器P2双端实测（原版无法行动时仍强制技能1／解放0次，Godot技能127／1次）、工具撤出T1/T2 P2、仓库Q1/Q2 P2、地图盘点D1 P2保留。正式11场18428/18428、原版86例重采sourceIdentity/cases全同generated；限定实际生产draft模拟55→44、unsafeRemoved=[]。仍未实际登记。
- 第八期c84bf27d已交付推github，远端同SHA：六批45个Claude提交限定通过（merge-speed、slice-affected、reach106/115/109、ce-fix2）；floor-narrow F1 P2保留，完整真实198图切片只改keepEvents32/4分别漏真实unknown160/floor30_seeker，full=false。15场1434/1434，独立自动存档落盘8/8；限定生产draft模拟单独55→49，与第七期联合55→38，无误销；三项P3文案／地图数订正保留。仍未实际登记。
- 第六期f17c2bba四批仍待总装登记，不重复核。第五期六批已登记；旧三期G1/G2、四期旧T1、五期TAB C2及六期跳跃存档S1等问题保持待修。八期分支保留七期交付单祖先：总装按实际合并顺序处理，已并后删除不可重复导入。
- 本期九正在核四批共21个Claude提交，scope.json全有Claude执行者／待Codex：yomi6、shop6、reservationFix4、field5。原单、净diff、四份收尾patch已保存。shop-review二原单包含Claude核Codex旧产品的结论，明确不复核这些，只审ade369a新修复与机械搬运／登记；不把原报告结论批准一遍。
- 已读：黄泉模块157行及挂点／公式分派diff、冻结Yomi runtime相关函数（39～78／128～158／492～516／729～741）、main安装顺序101早于127、dsPassiveSkill xparam别名链。O-098已登记待用户决定，CRIT_FIX可回退。商店7行自动关闭hook＋114行专项全文、map open_shop真实await/queue_free；缺失预约7行修复及对应4行新回归；五图专项262行业务段和原单。
- 数据证据field-data-check.json：94/92/93/105/90剔转换meta后原版所有字段完全相同；直接37敌群／37敌人／81技能无缺项（含原版未踩调试战斗，不代表全实战）。field-source-events.json保留全部相关命令与69入口原页。四个野外入口也有switch21转102旁路，当前切片已有102；当专项边界，勿报漏图。称号系统原单明确未移植，别当新回归。
- 本期唯一在途长任务related-specialties.log：14场专项（shop_auto_close/flow/shop_buy/shop_stock/review135/reach094/actor_p0/help_card/六难度rules_c），最后仍running，读.status.json后用等待任务.sh --timeout45等，别重启／取消。此前168/45/10工具套件、7期11场、8期15场和actor_modules56等没有实现变动，不重跑。
- 黄泉独立rank双端诊断均done/0，yomi-rank-comparison.json：45级无装备，手学10185/10186，rank0/1/2八项params、四条formula、debuff_count与penetration完全相同；crit原版0.05、Godot10.04，差9.99正好O-098。原件yomi-{native,godot}-first.json及diagnostic-sources均保留。
- **未收口候选，不能定P2或声称招募通过**：首轮raw recruit在Godot底层模块直接调用，缺native外层门，不是等价入口；已确认生产唯一调用mv_script.gd:276～284先_recruit_blocked，再调XYomiJingliu.recruit，不能把raw差异报产品缺陷。第二轮改走真实公共事件9004：native真实Game_Interpreter，Godot真实MVInterpreter＋正式EventHost；blocked两端都无入队／法宝。enabled(2494=true)时两端法宝装备都true，但native输出inParty=false、Godot=true。当前inParty用native $gameParty._actors.includes(169)，尚未查看实际_actors／类型、enforce清理或难度初始化，可能夹具／读数错误，需先查真实原版数组和实际角色列表。不要为了对上而改实现或放宽。
- 招募第二轮两任务均done/0，但逐项比较脚本assert失败，输出原件yomi-recruit-{native,godot}-first.json保留；尚无comparison通过文件。诊断源review9_yomi_recruit.cjs／.godot/review9_yomi_recruit.gd，同名tscn，源归档diagnostic-sources。新取证用新日志／新输出名，原件不覆盖，统一占槽＋长任务，Godot隔离HOME，原版host fs守卫不去掉。
- 下一步：先等related专项；优先解释enabled招募入口读数差异，再给本期四批最终边界。核四个收尾patch的机械登记与编号（尚未逐行看完），对问题按P级／出处／复现／建议交Claude；写本期报告及限定登记范围、用生产draft/pending模拟查unsafeRemoved，文档选测--affected dc8057c1 --oracle，提交推github核远端。九期未最终交付，千万别当可合并。
- 不向其他chat发消息，不派Claude活；由总装读交付单派修。只核Claude，不修实现／正式测试，不自核自己的提交／本期报告／完成度。继续到可核积压清完或额度线；上下文实际40%即保存同树下一序号，及时读本聊天token_count（最后用input_tokens，不把累计total当窗口）。
