# 交付：cc/wukong-dot1b

- 车道／工作者：A 内容／悟空（cc，Sonnet）；接 cc/wukong-dot1（WIP e2a37757、deeede13）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·悟空·未经审查】YEP_X_ExtDoT 持续伤害／再生移植（dev.待定）

背景：gaps6 查出约 41 个状态带 `<DoT Formula>`／`<Regen Formula>`／自定义公式块（中毒、损伤、祝福再生等），重制里回合结束 HP 不变。这期整个移植。

- **探针** `mv_oracle/dot_probe.cjs`（产物 `dot.json`，105 例）：量冻结正式源 `processDamageOverTimeStates` 的时机（先于 HP 再生率、先于状态回合递减）、45 个真实状态（41 个带公式；固定随机，波动 0／0.5／0.999）、40 条合成备注（波动、元素、标签写法、自定义块、负值）、叠加与致死顺序、结果槽恢复、存活与战斗外守卫、施加者（角色／敌人／无／缺失／导入角色／读档）、护盾下的持续伤害。已登记进 `同步正式西游.py` 的 PROBES 与 `oracle_additions.py`。
- **转换器** `xiyou_export.parse_ext_dot`：照原版 `processEDoTNotetags1` 逐行匹配（冒号后恰一个空格，所以 `<DoT Formula:300>` 认不出）；拼出的 JS 整段比对成 simple／assign／2038 特例，认不出的记 unresolved 并报出（现为 0）。状态记录多一个 `dot` 字段。插件参数 Regen 动画 46、DoT 动画 59、默认波动 20、默认元素 0 由探针逐项核对。
- **运行时** `core/ext_dot.gd`（XExtDot）＋ `battle_logic.gd` `turn_end_battler`：持有者活着时、HP 再生率之前，每个带 dot 的状态按 `states()` 顺序各算一次（名单开头定下，前一个状态把持有者打倒后面的照算）；`value = max(0, 式)`，波动 `随机(amp+1)+随机(amp+1)−amp`，元素倍率，Math.round；走资源上下文 gainHp（护盾、绑定、导入角色同一层）；弹字与动画放进 `regen` 日志。不做 maxSlipDamage，所以 DoT 可以把持有者扣到 0；被 DoT 打倒后不再做 HP 再生。
- 公式里 a／origin＝状态施加者，b／user／target＝持有者；没有施加者记录（开战被动等）时 a＝持有者；有记录但对象已不在，公式读 a 的状态本回合跳过。

**没做**：
- 2038「火遁初级燃烧」：自定义再生公式读 `user.damagedot`，这个字段由同一状态的 Custom Apply Effect 写（`user.damagedot = target.mat*50*(1+v1218)`），Apply Effect 这块还没翻译；运行时现在 `damagedot` 没写时什么都不做（记诊断），所以 2038 仍不掉血。施加者是角色时原版本来就什么都不做（读全局泄漏值，实测 0），这部分已与原版一致。后续翻 Apply Effect 即可接上（运行时已读 `state_data.damagedot`）。
- 原版 NaN 结果会把角色扣到 0，数据里没有这种公式，没做。

**没有新优化，不占优化号**（按原版测量实现，没有改数值）。

## 交接板

- 下一步：2038 的 Apply Effect（写 `damagedot`）翻译后 DoT 全部接通；审查线程核 dot1／dot1b。
- 用户试玩说明：带毒、灼伤、损伤等持续伤害状态现在每回合结束掉血（带「再生」的状态回血），弹字与动画与原版一致。
- 需要用户决定：无

## 进度账

- 无（状态备注类插件）

## 可优化（流程／工具／效率）

- 无

## 待交叉核查（改了核心文件）

- `modes/xiyou/battle/battle_logic.gd`：`turn_end_battler` 里 `XExtDot.tick` 加在 `_regenerate` 之前，并给 `_regenerate` 套了 `if b.is_alive()`（原 regenerateAll 自带存活判断）。

## 验证

- `python3 07_开发环境/测试ext_dot.py`（解析对照 dot.json＋夹具一致）：6 项 OK。
- 专项 `xiyou_dot`：2143／2143（46 个真实状态 × 持有者／施加者组合、合成备注 40 条、叠加与致死顺序、结果槽、守卫、护盾、导入角色、时机）。
- `同步正式西游.py --accept-additions` 退出码 0（dot_probe 新增用例已接受）。
- 选测（`选测.py main --list`，142 个场景，含 xiyou_determinism 与 xiyou_rules 抽样）走云端选测，结果见本文件末尾「云端结果」。

## 本分支提交

- e2a37757 WIP 探针 dot_probe.cjs
- deeede13 WIP 转换器、运行时、专项
- 本期：合并 main、交付单
