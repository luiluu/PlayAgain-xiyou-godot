# 交付：codex/state-effects-2e

- 车道／工作者：翻译／核查 · Codex（沙僧，重制_沙僧_43）。
- 状态：进行中（纯TP整块先取原版参照，尚未翻译或验收）。
- 沿用state-effects-2b工作树，从b34efa5切本分支；2b／2c／2d固定可独立合并，不重复已过验证。
- 开工只读main交接板及两树status／log，main仍09ebfb0；唐僧未提交登记未触碰。额度五小时88%、周56%。到90%只收尾手头步骤，不开新步骤或自动接力。
- 本批收窄为5个仅user.gainTp常量整块：607／609 battle200，857 battle50，1334 apply25，1336 apply75。先原版比较资源、上限、结果槽、刷新、随机与实际apply重加路径，再决定能否完整翻译。
- 独占仍限状态翻译、state_effects.gd、battler.gd、battle_logic.gd状态挂点、自己的探针／专项；不改actor.gd、XState或角色测试。
- 当前生命周期run／run_one不传入行动资源上下文。不能为了降低js数只改TP数值而丢掉结果槽；须完整处理嵌套apply上下文，并先证实外层结果槽语义。若本步骤到收尾线，只提交原版证据及明确前置，不登记可合并。
- 原版测量将由长任务.py启动，日志state-effects-2e/native.log；尚未启动最终同步。车道不跑全量，由唐僧合并后统一检查。全部提交待Claude交叉核查。

## 测量检查点

- 首轮native退出1：新case误放在必须最后执行的action.counter之后；既有反击夹具会令location失效，后续新局ReferenceError。已将新case移到counter之前；不修改生产或原版环境。保留native.log，修后日志native-v2.log。
- 测量执行期间额度到90%，按规则只收尾本测量，不进入翻译／同步／自动接力。2e仍进行中，不能合并为玩法完成。

## 原版测量已完成，额度到线停在检查点

- native-v2于2026-10-22 05:06（Europe/Paris）退出0，22例errors=[]。tp.native_blocks有140条直接执行边界行、4条真实addState两次重加行；与generated保留的2d最终21例独立逐项比较全部相同，仅新增本case，sourceIdentity相同。摘要在本地state-effects-2e/native-verified.json，完整参照仍在mv_oracle/.sandbox/state_effects.json。
- 直接行覆盖角色1与敌人、5块、初始TP -1/0/1/150/199/200/250、存活／死亡两组。测试两者maxTp均200，未声称已测角色自定义上限。TP增量按最终上限截断，即使已经饱和，tpDamage仍记负的请求增量（-200/-50/-25/-75）；HP/MP结果原有字段保留，gain结束dirty=true，140行draws均0。
- 实际1334／1336连续addState两次：TP从1到26／76，apply只生效一次；4行各抽2次时长随机，最终turns=1，addedStates仅含该状态。刷新边界记录在log；本期没有把重加当第二次gain。
- 首轮失败是明确的探针排列问题，已保留native.log并修正；不是偶发重跑，未修改原版或生产算法。native-v2是修正后的首次运行。
- 本分支尚未改变Godot生产、转换器或自己的Godot专项；5块仍为js，第二期未翻译仍444。本分支仅原版参照检查点，**不标可合并**；没有最终同步，不把本期探针指纹冒充2d最终指纹。generated/oracle仍保留2d的21例，未将22例复制进去。
- 后续实现前置：XStateEffects的battle与apply入口目前没有资源上下文；battle_logic.gd技能附加状态分支里的add_state也没有将_action_resources传给apply回调。必须设计显式生命周期资源上下文与嵌套保存／恢复（可考虑battler.add_state可选context、battle_logic状态挂点显式传入），让apply里的gain写回外层同一结果槽和日志；不能只用临时XResourceContext丢掉结果。独立battle资源槽的消费也须明确，预览不触碰真实对象／缓存／RNG／结果槽。此处仅列前置，未设计完或实现，不能据此宣称支持。
- 后续可按这些原版行补Godot逐项对照；角色自定义TP上限、刷新导致状态变化与嵌套guard仍需补参照，不能把当前140条当完整族验收。8个纯addState候选仍未开工。
- 额度到五小时90%后只完成本次测量收尾，不再开新步骤、不自动创建接力聊天。下次恢复沿用本树codex/state-effects-2e；不要重复已完成的原版测量，新增覆盖时另加case并保留旧22例。
- 可交唐僧的仍为2b ad7c867、2c 4760a54、2d b34efa5，按序合并后统一全量检查，全部Codex实现待Claude交叉核查。2e是后续WIP，不并入该完成批。
- 本轮车道按规则不跑全量检查；主工作区共用登记未改。无同步／测试活动任务，无heartbeat，不重建监视。

## 2026-10-22 后续接续指向

- 用户插队的架构13已交codex/module-hooks（a8fcb0d），可合并；之后已回状态第三／四期，在codex/state-effects-3-design（1ff5c0c）交具体接口设计，运行时需actor／XState／事件宿主范围交接，不强推第五期。2e继续保留为纯TP原版测量WIP，未实现、不可合并为玩法完成；不要在此枝重复测量或擅自扩做。
- 本目录恢复2e以保留其未入Git的native22例及日志。第三／四期设计移到独立state-effects-3-design工作树；总装清理2b／2c／2d时不要删除本目录或2e分支。
- main的AGENTS.md已在7608538记录用户把5小时收尾线改为95%；上面的90%是当时测量收尾历史，后续开工读取当前main规则与实际额度。

## 恢复期二（2026-10-22，沙僧_46）

- 用户明确要求在总装合并期间继续；开工已只读交接板、两树状态与日志，当前额度5小时28%／周4%。本树cb59b460干净，没有活动任务。
- 已确认b0cbf868是main祖先，main fd975959已合整批状态修复（dev.135内容），期二前置满足；本树已无冲突git merge main。唐僧main未提交收尾只读，不接总装。
- 既有原版22例未重测，已在本地结果state-effects-2e/native22-preserved.json保存完整副本；SHA256 24100228be3102a9dcca56fa0bb5ed9b08bbbd9b5819742308772c478876b0a0。原.sandbox/state_effects.json与native-v2日志仍保留，不删除。
- 下一步长任务refill-resume.log补齐本树产物与导入；随后设计显式生命周期资源上下文及嵌套保存／恢复，先读现有run／run_one、add_state与_action_resources路径。仍只做5个纯TP整块，不做8个addState候选，不提前改actor／XState或开第三期。
