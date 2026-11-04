# 交付：cc/bajie-rules8

- 车道／工作者：C 规则／八戒（cc，Sonnet／medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·八戒·未经审查】状态块翻译 rules8：全游戏可达的未翻译状态块清零（dev.待定）

背景：`未翻译块清单.py` 在 rules6 后报：切片可达 0、全游戏可达 34、不可达 48（共 82）。这些状态在切片外（后期楼层、别的角色、套装、防具备注）会碰到，重制里原先不生效。这期把 34 块全翻了，每块先用 mv_oracle 量原版再实现；清单现报全游戏可达 0、不可达 47（比原来 48 多算掉的一块是与其中某块原文完全相同的不可达块，一并翻了）。

**参照探针**（都在 `mv_oracle/state_effects_probe.cjs`，新增三个用例，不改老用例的产物）：
- `effect2.blocks`（4032 行、56 例实战）：伤害 react／confirm 14 块——38、50、97、250、381、720、908、1112、1257、1394、1407、1538、1661、1749；单块直调加真实 apply，再额外变 v206、本击是否暴击。
- `rest2.blocks`（regenerate 15 行、钩子 70 行）：224、566、577（regenerate）；49、102、1741、1742、1748、1315、1778、1769、1771、1772、1776、2018、2033。
- `poison.blocks`（40 行）：732 毒奶，来源者是装 3590 的克莱德（16）、不装、敌人三种，叠毒层数、v320、目标血量各变。

**转换器**（`xiyou_export.py`，都是整段 token 比对，不用宽松正则）：
- `MEASURED_EFFECT_BLOCKS`：直接认原文的 14 块（38、250、720、908、1112、1394、1407、1538、1661、102 action_start、1778、2018×3）。
- `MEASURED_EFFECT_SOURCES`：原文写法 IR 表达不了的，整块比对后换成等价写法——50／97（存结果→清→扣血弹字→清→还原）、381（末尾 `* 10` 是被丢弃的表达式）、1257（`let`、`++`）、224／566／577（照 rules6 的 260 写法）、102 initiate（`undefined` 用没赋过值的局部量表示）、1769／1772／1776（`_stateCounter[s] = _stateCounter[s] || x`）、1771（两个 reserveCommonEvent 里 2482 被 2479 覆盖）、2033、732。
- `NO_EFFECT_BLOCKS`：原版一跑就没效果的 5 块——1749 的 `user.criticalRate()` 不存在（TypeError）；1741／1742 的 `this.user()` 不存在（TypeError）；1748 的 `user.attackCount` 不存在（undefined > 1 为假）；1315 是空块。`UNREAD_FIELD_BLOCKS`：49 只写 `_lastUsedSkill`，冻结源 js 里没人读。
- `_compile_effect_tokens` 加两个来源者读法：`origin.elementRate(常数)`（381）、`origin.gearLevel(基础防具号)`（732，对应原文 equips().filter(baseItemId).getEquipItemObject().level()）；字段名加 `_reverenceMp`、`_stackingPoison`。
- `formula_program.py` 的 `PHASE_CALLS` 加 `saveResult`／`restoreResult`／`setCounterIfEmpty`。

**运行时**（`core/state_effects.gd`）：
- `save_result`／`restore_result`（50／97：原文 `JsonEx.makeDeepCopy(target._result)` 与还原）。
- `set_counter_if_empty`（计数没有或为 0 才写）。
- 字段写 undefined 等于删字段（`_reverenceMp`）。
- 来源者读：`o_elementRate_N`、`o_gearLevel_N`（后者复用公式系统已有的 `XEquipmentView.first_armor_level`）。
- **同块先写后读变量修正**：`set_variable` 之前只改游戏变量，块开头拿的变量快照不更新，块里 `setValue(1139, …)` 后马上 `value(1139)` 读到旧值（1769／1776 会错）；现在写时同步更新快照（原版读到新值）。老块没有先写后读的，行为不变。

**原版缺陷（照原版测量、没改）**：
- 1749「数据错误:暴击」：`user.criticalRate()` 原版没这个方法，打出伤害就 TypeError，整块没有效果。说明只写「每点暴击率提供 0.01 暴击伤害」，没写暴击率取 0.19 还是 19 点、加成作用在谁身上——**不编，请 Kyo 定**。
- 1741／1742「错误数据:速度」、1748「错误数据:普攻」：同样是 `this.user()`、`user.attackCount` 不存在，原版没效果。名字就叫「错误数据」，像是故意做的占位，按无效果处理。
- 381／908／1538（反伤）、1394 公式本身没改：尤其 381 的 `* 10` 外层被丢弃，只有 `gainHp` 参数里的 `*10` 算数。
- 1257「死之掌握2」：说明与代码对不对没核（技能 7195 的说明没读）。

**这期没改任何游戏数值，没有新优化，不占优化号。**

## 验证

- `xiyou_state_effects`（现 30111 项）：`effect2.row`／`apply`（4032 行 + 56 例实战）、`rest2.regen`／`hook`／`param`（15 + 70 行）、`poison.native`／`damage`／`dead`／`field`／`anim`（40 行，每行先用参照行的数据验证公式、再比运行时）。
- `xiyou_state_effects_tp`：inventory 82 → 47。
- `语法检查.py`、`探针登记检查.py` 通过。
- 同步（`同步正式西游.py --accept-additions`）退出码 0，新增三个用例已接受，老用例测量不变。
- 云端选测（31 场景，基准 48c480ba7d，提交 6e4b7096d7）：通过（<https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41846523932>）。第一次（c32a09c1c0）`xiyou_state_js` 的「参照里的报错只许来自未翻译状态」断言挂在 732（已翻译、敌人来源仍报 TypeError），测试里放行 732 后重跑通过。
- 没做反向验证（`反向验证.py`）：这期的断言是逐行对照原版测量，不是自写的期望值，改坏任何一块都会有大批行失败；要补的话我会挑 50／97 的存还原、1769 的计数默认、732 的法宝等级三处。

## 交接板

- 下一步：不可达 47 块无需翻（数据里没人能加上）；若 Kyo 要，可翻出来补完。1749 等 Kyo 定暴击率口径。
- 用户试玩说明：切片外的内容里原先不生效的状态现在生效——伤害反弹／吸蓝护盾／附加雷风伤害（雷鸣、狂风符文手套）、毒心毒奶（法宝等级加伤）、凤霞解放系的计数器、魔法吸血（花多少蓝回三倍血）、狠活状态加减属性等。
- 需要用户决定：1749「数据错误:暴击」的暴击率口径（原版没效果）。

## 进度账

- 状态块翻译：全游戏可达 34 → 0（不可达 47 不翻）。

## 待交叉核查

- 核心文件 `core/state_effects.gd`：`save_result`／`restore_result`、`set_counter_if_empty`、字段删除、`o_gearLevel_`／`o_elementRate_`、`set_variable` 同步快照。
- `xiyou_export.py`：新增的 MEASURED／NO_EFFECT／UNREAD 表项，核每条是否与 States.json 原文一一对上、等价改写有没有走样（尤其 102 initiate、1257、732）。
- 重点核：(1) 732 里 `origin.isActor()` 守卫等价于原文敌人来源 TypeError；(2) 50／97 的 `isAttack` 取 `se_attack`；(3) 同块先写后读变量的快照修正有没有影响别的块（老块探针全对得上）。
- 测试里 1407 的小数血量按 6 位小数比（参照取整到 6 位），不是漏洞。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 41af2d82 rules8 第一族：伤害 react／confirm 14 块
- （第二批、732 见 `git log cc/bajie-rules8`）
