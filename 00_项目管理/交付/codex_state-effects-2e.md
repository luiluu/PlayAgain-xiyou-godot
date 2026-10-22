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
