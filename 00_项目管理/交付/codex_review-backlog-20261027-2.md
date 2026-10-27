# 交付：codex/review-backlog-20261027-2

- 车道／工作者：核查／沙僧（Codex，沙僧83·第二期）
- 状态：进行中
- 用户最新职责（2026-10-27）：沙僧只审查待审项，发现的问题交Claude实现／修测试；不再自行改实现、测试或接力执行。此前未验候选fa2ccd8a已从当前文件树撤出，原提交与候选副本保留给Claude，不自核放行。
- 用户最新停手线（2026-10-27）：周额度剩10%／已用90%时收尾当前步骤、保存推送后停手；优先于旧周98%规则。五小时95%与上下文40%接力规则继续有效。不消耗额度重置、不以新会话绕额度。
- 正在做什么：第二期8批已读差异／原单／变更条目，17场专项结果与问题已取证，正等待完成正式草稿与销账模拟；尚未最终交付。固定基准7cf62df818bbf3c8c40f41cfb9ce928131a538b4。
- 开工统计：待核查85批，计入上限47批；本地结果review-backlog-20261027-2/pending-start.json保留原始清单。不沿用第一期实时值。
- 范围：角色仓库、镶嵌图鉴、装备道具仓库、更衣、角色进阶、技能共享／羁绊／领袖、超强者限制、review-pending的唐僧合并登记。末项只核Claude的合并及收尾，不核其中Codex实现。
- 原第一期与14期证据、generated完整克隆、.sandbox及未跟踪原件保留；不改主工作区或共享交接板／编号，不建PR。

## 逐批核查

8批差异、原单与变更条目已核对。17场专项首轮中pet_synth两条遮挡断言失败、单跑通过，累计第二次偶发；不能据重跑放行。窗口开合在physics更新，遮挡在process更新，此前拟做低渲染帧率复现，因用户改定只审不修，已取消自己的未启动队列；未动主工作区测试。原输出与重跑各自保留。

## 可优化

本期只登记可优化项；玩法问题由总装决定与派回原车道。

执行者: Codex（沙僧）
核查: 待Claude

## 本期自测修正（不算交叉核查通过）

- pet_synth首轮失败24/26，syn_occludes_status／feed_occludes_status；单跑26/26，累计第二次偶发。原10个physics tick等待来自Codex历史提交4266e01e（本期不重核该实现）。
- 职责改定前曾提交候选fa2ccd8a，仅改测试等待：等窗口openness到255／0，再让process遮挡刷新；原26项断言、参照、容差不变，不调用产品内部刷新函数掩盖问题。该修正待Claude独立核查。
- 低渲染帧率（6fps）原版等待复现场景仍在共用槽排队，源码与首轮证据已保留；没动主工作区在途测试、并发或工具。尚未用修正后的自测结果声称通过。

## 已交回Claude的新增问题

- 宠物合成专项首轮24/26，syn_occludes_status／feed_occludes_status失败，自动单跑26/26，累计第二次偶发。首轮与重跑在本期本地结果specialties/xiyou_pet_synth.log及.rerun1.log。
- 根因线索：窗口openness在physics更新，XPetScene遮挡在process更新；10个physics tick不保证派生遮挡读数已更新。候选fa2ccd8a只把等待改为openness到终点再让process执行，断言／容差／参照不动；**尚未验证，不算修复通过**。
- 用户改定只审不修后，该候选已从当前审查分支文件树撤出；保留完整fa2ccd8a提交和本地候选副本。请Claude接手修稳并跑独立验证，完成后作为新待审提交再交Codex。
- 低渲染帧率诊断因共用槽排队未开跑；按新分工仅取消自己的未启动队列，没动主工作区在途测试。它没有RED／GREEN结果，不能当验证证据。
- 第一期F1～F6仍以f1c29246交付单为准；main已出现相关修复批，不要求重做。F4 +1按用户给Claude的新决定由其登记O-105；本期不自行核销相关修复。

## 沙僧83→84：同树上下文接力（2026-10-27）

- 实查last_input=419345、窗口475000，88.3%，已越40%线，立即保存接力；不是额度停手。末查五小时34%、周83%。**周剩10%／已用90%是用户最新停手线，替代旧98%；不能以新会话绕额度。**
- 所有文件命令必须显式workdir=/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/state-effects-2b。只用已有树，不建／清树，不reset／cherry-pick，不接管main，不改共用登记，不建PR。
- 当前分支codex/review-backlog-20261027-2，基准7cf62df8，tracked保存后干净；尚未交付第二期。原第一期已交f1c29246，14期已交c322f670，勿重做或自核。
- **用户最新职责是只审不修（错字也交Claude），不再做设计或额度接力。** 战斗／actor／battler／damage／xstate等开放Claude修改，改动重点核；阶段75%／95%仍归沙僧。此规则优先于旧AGENTS，唐僧已在Claude会话中承诺改共享规则，车道不改。
- 第二期现场完整机器摘要在本地结果/review-backlog-20261027-2/phase2-review-checkpoint.json。范围8批：8548e2f6（角色仓库）、7aba3d21（镶嵌图鉴）、bf0aa772（装备道具仓库）、c5e98618（更衣）、beab53ec（进阶）、3621731c（共享／羁绊／领袖）、8d03a8eb（超强者限制／换装设置）、8f8c525f＋2fba4b52（**只核Claude合并／登记，不核其中Codex实现**）。逐批diff／原交付单在编号子目录，变更条目在10-16至10-26分卷3101、3379、3415、3441、3454、3484、3501附近。
- 17场相关专项最新合计1004项，pet_synth例外首轮24/26、自动单跑26/26且累计第二次偶发，其余首轮绿。不能写“17场首轮全绿”或“已修稳”。其余主要数actor_warehouse26、inlay19、warehouse32、change_clothes32、actor_advanced33、party_skills214、advance_reads8、super_deploy43、costumes27、party58、pets29、event_compare5、flow48、determinism372、script21、item_use11。未确认新增玩法bug，原单明确尾项继续保留，优化O091/093/094/095均有登记。原图形几何用现有冻结源读数，不冒称新截全套图。
- pet_synth失败点syn_occludes_status／feed_occludes_status：窗口openness在physics更新，遮挡status_cover在process更新；固定10tick不保证遮挡已更新。出处是Codex历史4266e01e，本期不能自核其实现。职责改定前的候选fa2ccd8a（14行等待辅助＋改3处等待）**尚未验证**，已在3549df58从当前文件树撤出，完整Git和pet_synth-candidate-fa2ccd8a.gd保留给Claude；不得重新应用或自行修。6fps诊断从未开跑、排槽时取消自己PID36303，无RED/GREEN证据，文件已移入本地结果，不在正式tests。无本车道在途测试。
- 新问题已按用户显式授权，**实际通过Claude桌面发给“重制_唐僧·常驻总装”**（local_102f2c6b-6a6f-45de-a0c6-8d8732d0c04c，消息68，UI确认发送成功），请其派Claude修后再回核；claude-handoff.json记证。无需重复发送。用户第一期F4已定保持+1、O105，由Claude登记；main已有F1～F6相关修复批，不重复派、不自行销其修复。
- 已核Claude8f8合并树等于git merge-tree自动结果，43个原Codex核查标题全部原样登记到2fba，P2保留在交接板，三处dev164一致；只核操作完整性，不重新批准Codex原结论。两份验证JSON在本地结果。
- --补齐仅刷新main缓存＋转换器／import，通过，无全量同步；第一期generated另存review-backlog-20261027-1/generated，14期generated仍delivery82/generated，全部.sandbox／未跟踪／失败证据和整树保留。同源issues空（2096输入／382运行时／2098输出）；覆盖hard0/new0（5869页）。
- 下一步：84先读本段与checkpoint JSON提纲，基于已取得证据写本期正式逐批结论与“需要总装决定”，仅用明确Claude提交范围做销账模拟（不要把任何Codex实现／fa2自己的修正销掉），跑本分支文档选测，提交推送后告诉Kyo“第2期已交付”。已绿专项不无意义重复。再继续第三期（从当时main开-3），以周90%与上下文40%保存接力；不修任何代码。
