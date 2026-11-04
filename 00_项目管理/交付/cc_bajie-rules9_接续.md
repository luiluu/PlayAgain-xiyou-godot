# 交付：cc/bajie-rules9（接续：任务二 插件备注真缺）

- 车道／工作者：C 规则／八戒（cc，Sonnet）；上下文到线，停手交接，下一位接着做
- 状态：进行中

## 已量的结论（用 mv_oracle 的 host.cjs 在冻结正式源上实测；脚本留在本机 `03_再刷重制_Godot/04_验证/本地结果/20261104_八戒rules9/`：`floor1.cjs`、`multi1.cjs`、`multi2.cjs`，不入库，运行前先 `node` 它们要 `require` 绝对路径的 `shared/host.cjs`，现在就是写死的本工作树路径）

### 1. Max State Floor（6 个状态：1323～1327、2521 隐月 1～5）—— 原版里根本叠不上层，不需要实现
- 这 6 个状态都带 `<State Can Added Floor>`＋`<Max State Floor: 0>`（0＝不限层）；只有 `PushsubState1323…1327／2521: 100%`（技能 7489／7503～7506／10119 剑饮空月，说明写「每层 +2%…暴击，可无限叠加」）会加它们，没有别的来源（数据、公共事件、脚本里没有 `Add State x Floor` 标签，也没人调 `addStateMoreFloor／stateFloor`）。
- 加状态走 `dsPassiveSkill.js` 第 2048 行：`!subject.isStateAffected(stateId)` 才 `addState`，**已带着就不再加**；CP_StateFloor 的层数只在 `addState` 里涨，而 `isStateAddable` 对已带着的状态为假。实测（floor1.cjs）：连命中 4 次，`stateFloor(1323)` 恒为 1；直接再 `addState` 两次也还是 1；只有手工调 `addStateMoreFloor(1323, 3)` 才到 4 层（游戏里没人调）。`removeState`／`removeStateCompletely`／战斗结束都是一层直接清掉，与普通状态一样。
- 所以「Max State Floor: 0」在这个游戏里无可观察效果，重制不需要多层机制。说明里的「可无限叠加」是原版文案与代码不符（原版缺陷，重制照原版，可登记给 Kyo）。
- 待做的小事：`battle_logic.gd` 的 `_push_rows`（约 2255 行 `not u.is_state_affected(...)`）加一行注释写明这个结论（让 `插件备注覆盖.py` 把它归入已读），再在 `xiyou_pushstate` 里加一条断言：连命中多次，角色身上 1323 只有一份、`state_ids` 里不重复。可选：验证重制侧隐月 +2% 暴击是否生效（原版 `a.cri` 在加状态后读到的还是 0.19，没刷新缓存，探针里没查清，重制侧没核）。

### 2. Multi-Element Rule（16 个技能）—— 原版里这个标签没有效果，不需要实现；但要核重制多属性伤害与原版是否一致
- 实测（multi2.cjs）：把技能 7006（Add）、9956（Multiply）、10007（Highest）的 `elementMultiRule` 分别改成 0～4 五种，`Game_Action.makeDamageValue` 结果完全不变（7006＝1734、9956＝867、10007＝1612，条件见下）。原因：冻结源的 `Codex/runtime/installDamageElementRuntime.js` 接管了元素伤害计算（`getItemElements` 被覆盖成 `actionElements`，第 272 行；技能说明里写「均分伤害」），YEP_ElementCore 的 `calcElementRate` 规则分支不再起作用。所以标签 `<Multi-Element Rule: …>` 在原版没有任何作用，重制不实现也对。
- **没做完的核对**：重制的 `damage.gd`（约 247～300 行）对多属性取「各属性候选里伤害最大的一条」（`best`），而原版 `installDamageElementRuntime`（第 131、159 行附近）看起来是对各属性的加成取平均（`elementalBonus` 之和除以 `es.length`）或另一种合并，两者是否一致没比。实测数字（multi1.cjs，公式固定 1000、无浮动不暴击，角色 1 默认装备下，敌人 `elementRate` 被改成 2→2.0、3→0.5、5→1.0、9→1.5、1→1.0，其余 1）：7006(2,3,5)＝1734、7057(1,9)＝1674、7319(1～10)＝1734、9956(3,5)＝867、9959(2,5)＝1734、9962(2,3)＝1734、10007(2,3,4,5,6,7,8,9,11,12)＝1612、10070(1～9)＝1734、7471(2,9)＝1734、7472(2)＝1734；单属性对照（技能 1 改属性）：1→1674、2→1856、3→464、5→928、9→1392。注意：单属性 2 是 1856，而 7006 含属性 2 却是 1734，说明原版不是取最大的一个；重制要对着这批数在 Godot 里算一遍（同样的公式 1000、同样的敌方元素抗性表）。**下一步**：写 `mv_oracle/multi_element_probe.cjs`（正式探针，登记 PROBES，产物拷成 tests/fixtures），再在 Godot 里用 `XDamage` 同条件算 16 个技能，逐个比；不一致就按原版改 `damage.gd` 的合并方式（读 `installDamageElementRuntime.js` 第 120～200 行弄清楚合并公式，别猜）。这一步改的是战斗伤害核心，改前跑 `选测.py main --list` 看影响面，交付用 `云端选测.py`。
- 这是任务二里真正可能改玩家数值的一项（16 个技能：7006、7007、7057、7063、7319、7327、7471～7473、9956、9959、9962、9963、10007、10008、10070），改了要登记优化或原版缺陷，写明依据。

### 3. Element Reflect（1 件防具）—— 还没量
- 防具 4998「圣光の屌丝」`<Element Reflect 8: +100%>`（说明：反弹神圣伤害）。YEP_ElementCore 里是 `Game_Battler.elementReflectRate` 加到「元素反射率」，对属性 8 的魔法反弹（`<Bypass Element Reflect>` 的技能不反弹）；要先判断冻结源里 codex 运行时是否也接管了反射（跟上面一样，先改标签值看结果变不变），再决定重制要不要做。重制工程里搜 `Element Reflect` 没有读取。

## 变更记录草稿

（任务二做完再写；上面 1、2 的「原版无效果」结论写进去，别忘了说明是实测。）

## 交接板

- 下一步：见上面三条；先做 1 的小注释＋断言（几分钟），再做 2 的对照（大头），最后量 3。
- 用户试玩说明：待定。
- 需要用户决定：隐月「可无限叠加」与代码不符（原版缺陷，照原版保持）——Kyo 是否要改成真的可叠加。

## 进度账

- 无变化。

## 可优化（流程／工具／效率）

- 无新增（任务一那张已写补齐旧 oracle 的建议）。

## 本分支提交

- 00f3a0c0 rules9 任务一
