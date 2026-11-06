# 交付：cc/nezha-newsrc6

- 车道／工作者：工具／哪吒（cc）。从集成分支 cc/newsrc-switch 7c2a3a7e 切出，交回集成分支，不进 main。
- 状态：可合并
- 派单 DC 两件：① 15 个新状态翻成结构化效果；② 璇·余辉、绑定两份 gainHp 参照（只出参照与探针，Godot 不动）。

## 结论

### ① 15 个新状态：Effect 块 27 块全部翻好，没有翻不了的

被动条件（Custom Passive Condition）4 块不是 Effect 块、也不用翻：2771～2774 只由技能 10563～10566 直接附加，不是被动状态，原版不会去算这个条件。

| 状态 | 块 | 译成 |
|---|---|---|
| 2720 舍身剑·燃血 | Remove、Leave | effect_program（各扣一次满血；自然消失时 Remove 和 Leave 都跑，扣两次，参照 2 次弹字） |
| 2721 凝气成罡 | Confirm | effect_program（HP 伤害>0 时目标再掉 ceil(atk×45)） |
| 2723 用剑终伤+150% | Confirm | effect_program（改写：`user.firstWeaponType() === 2` 才给 var 2 加 150） |
| 2724 诛仙剑主 | Confirm | effect_program（var 2 +300） |
| 2747 全知全能 | React | effect_program（新局部量 `se_item_id`＝本招编号写 var 1566；给行动者加 2748；与 var 1565 相同则清零） |
| 2748 全知全能 -1 | Leave | effect_program（var 1565 ← var 1566） |
| 2750、2751 | React | effect_program（`value = 0`） |
| 2771～2773 超赛1～3 | Apply／Remove／Confirm | costume_image／**新** costume_form_remove／value_steps（已有） |
| 2774 超蓝 | Apply／Remove／Confirm | costume_image／costume_restore＋`addState: 1`／value_steps |
| 2775 自在极意功 | React | effect_program（预约 1721；var 1586≥10 清零） |
| 2776 自我极意功 | React | effect_program（预约 1722） |
| 2777 自我终伤 | Confirm | effect_program（var finalRate 那行没分号，靠换行补；登记进 ASI 原文哈希表，改成一行就不认） |

- 超赛换装（`xiyou_state_effects_tp` 的 `inventory.costume_0`／`untranslated_46` 两项）：现在两项都过（tp 544/544）。
  - 原版量到的规则：移除效果在状态去掉之后跑；2771～2773 移除时只有当前图还是自己那张（或空）才动，剩下的超赛形态里编号最大的接上，一个不剩才还原旧图；2774 移除直接还原并 `addState(1)`，**角色当场倒下**（原版设计如此，照搬）。10 种叠加／先后顺序逐步对上，敌人身上什么都不做。
  - Godot 新增 `XStateEffects._costume_form_remove`；`_costume_restore` 带 `addState` 时没记旧图退回角色本身的战斗图、还原后加状态。老的换装模板行为不变。
- 参照：`state_effects_probe.cjs` 新加两例 `effect3.blocks`（8 块 × 伤害类型 × 数值 × 3 组变量，2304 行＋实战 32 行，多记 6 个变量和预约的公共事件）和 `newsrc6.blocks`（2723 武器 5 行、2720／2748 移除与自然消失 8 行、换装 10 个序列＋敌人 2 行）。`effectMeasure` 加了可选 `opts`，老用例不传，行内容不变。新源 37 例无错。
- 测试：`测试状态效果翻译.py` 新加 `test_newsrc6_states`（在旧转换器上 15 个状态全挂，新转换器过）；`xiyou_state_effects` 加 effect3／newsrc6 对照。

### ② gainHp 遮蔽参照（新探针 `gainhp_shadow_probe.cjs`，夹具 `tests/fixtures/gainhp_shadow_oracle.json`，22 例）

krz_state_re 给 `Game_Actor.prototype` 定义了自己的 gainHp（还有 setHp、addState），后装在 `Game_Battler.prototype.gainHp` 上的包装对角色不生效、对敌人生效。

1. **璇·余辉（回光溢出转护盾）**：回光给队友（溢出）、给璇自己，**原版一次护盾都不发**，余辉 1～3 级都一样。同一个行动里直调 `Game_Battler.prototype.gainHp`（包装本该走的路）会发：1 级 1947、2 级 3407、3 级 4867（溢出 9735 × 20／35／50%）；对敌人 gainHp 也会发。旧源 v0.28 的 xuan_battle 夹具也是空的，新旧源一致。
2. **绑定（敌方行动期间不可选中者不掉血）**：非璇种类附身后，在敌人行动里对附身者 `gainHp(-50)` **照掉**（525→475），`setHp(10)` 照改，`addState(4)` 照加；直调 `Game_Battler.prototype.gainHp` 才挡住。宿主照常掉血。璇自己的种类另有 `Game_Actor` 包装，附身期间确实不掉血（xuan_bind 的 `owner.hp_loss`：附身期间 4698 不变，回身后 4598）。binding、xuan_bind 两个探针新源重跑，与夹具逐项相同。

这两条按「原版玩法 bug 照搬」应当照搬（余辉对角色无效、绑定对非璇种类挡不住脚本扣血）；要不要修、怎么做开关，交规则车道那一单。我没动 Godot。

## 验证（本机，`XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`，转换器 `--app` 同一份）

| 项 | 结果 | 说明 |
|---|---|---|
| state_effects 探针（新源） | 37 例无错 | 新参照拷进本树 generated/oracle（不入 Git） |
| xiyou_state_effects_tp | 544/544 | costume_0、untranslated_46 转绿 |
| xiyou_state_effects | 32630 过、169 挂 | 新增 effect3／newsrc6 全过；挂的 169 项剩下的失败是上一棒就有的 revive.apply（敌人热缓存不复活，归规则）、action.counter.sequence 1、rest.costume.undefined_note 1 |
| 测试状态效果翻译.py | OK | 顺手改了一条过期断言：2544／2545 早已由 hook.weapon 译成 effect_program，原来断言还是 js（在集成分支头上就挂） |
| 测试转换器写入.py、语法检查.py | 通过 | — |
| 工具回归.py | 6/7 | 插件备注覆盖挂：它读本树 `冻结正式源/app.nw` 链接（旧源），新源豁免键 codexaura 等在旧源里没有；与本单无关，集成分支头上同样 |
| 事件空绿扫描.py --check | 775 条 | 全是本树 event_states 参照拷自主工作区（旧源）、与集成分支预设对不上；本单没碰事件 |
| gainhp_shadow／binding／xuan_battle／xuan_bind 探针（新源） | 全部无错 | 后三个与现有夹具逐项相同 |

- Godot 侧的新检查我没在旧代码上单独跑一遍；它们第一项就查「这一阶段没有 op js」，旧代码必挂。
- effect3 实战行里 2721 满血那两行只比掉血方向（参照敌人生命加了 1e9，额外 atk×45 打不死；Godot 这边敌人是原值会被打死）。

## 改了哪些文件

- `03_转换工具/xiyou_export.py`：实测块表、改写表、ASI 哈希各加新块；换装第二套模板（COSTUME_APPLY2、COSTUME_FORM_REMOVE、COSTUME_REMOVE_DEATH）；`se_item_id`
- `01_Godot工程/modes/xiyou/core/state_effects.gd`：costume_form_remove、costume_restore 的 addState、se_item_id
- `03_转换工具/mv_oracle/state_effects_probe.cjs`（effect3.blocks、newsrc6.blocks；effectMeasure 的 opts）
- `03_转换工具/mv_oracle/gainhp_shadow_probe.cjs`（新）、`01_Godot工程/tests/fixtures/gainhp_shadow_oracle.json`（新）
- `01_Godot工程/tests/xiyou_state_effects.gd`、`01_Godot工程/tests/fixtures/state_effects_translation.json`（加 newsrc6 的 15 条备注）
- `07_开发环境/测试状态效果翻译.py`
- 产物：集成树要重跑 state_effects 探针（或同步）才拿得到 effect3／newsrc6 两例参照。

## 变更记录草稿

## 2026-11-06 【cc·哪吒·未经审查】v0.62.12 新增 15 个状态翻成结构化效果；余辉、绑定 gainHp 遮蔽参照（dev.待定）

转换器把 2720～2777 共 27 个 Effect 块译成 effect_program／换装操作，超赛多形态回落（costume_form_remove）与超蓝还原后倒下（costume_restore addState）进 Godot；state_effects 探针加 effect3.blocks、newsrc6.blocks 两例原版参照；新探针 gainhp_shadow 量出回光溢出给角色不发余辉护盾、非璇附身者在敌方行动中照掉脚本扣血（都是 krz Game_Actor.gainHp 遮住包装）。核查：待审查（改了 state_effects.gd、转换器）。

## 交接板

- 下一步：集成树重出 state_effects 参照；规则车道按 gainhp_shadow 夹具定余辉／绑定照搬还是开关修。
- 需要用户决定：无新增（余辉、绑定是原版 bug，默认照搬，修不修由规则单提）。

## 可优化（流程／工具／效率）

- `新建工作树.sh --补齐` 在集成分支上不认 XIYOU_APP：转换器按默认（旧源 v0.28）重跑，参照又拷主工作区的旧源，于是插件备注覆盖、事件空绿扫描在集成树里天然红。建议补齐时读 XIYOU_APP（或分支上的来源文件）传给 `xiyou_export.py --app`，并跳过拷主工作区参照（工具，小）。
- 本机 4 个共用 Godot 槽经常被占满，`--补齐` 的 godot --import 等了 19 分钟没轮到；车道单跑一两个场景时可以考虑让 --import 也走快车道锁（工具，小）。
