# 交付：claude/project-thread-z0d29k

- 车道／工作者：天启篇·词条实装数据层（第④步前半）／cc（Pro，云端容器）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·Pro·未经审查】天启篇词条总表：数据表、只读加载器、校验（dev.待定）

- 按天启篇词条重构设计稿 v0.3（定稿）做第④步的前半：只做数据和校验，**不接进任何游戏流程**（不改掷装备、伤害结算、深渊商人、存档）。全部是新文件。
- `modes/xiyou/tianqi_data/affix_table.json`：四阶分界（1～29／30～59／60～69／70 以上）、成色（极 3%，上品按品质 10／20／30%）、七档品质的槽数与能出的层、层门槛与每件上限（特效 2、传说 1）、五档难度×三层几率（难度键同 `XTianqi.DIFFICULTIES`）、12 栏位与五个栏位组、项链光环 15%、通用法宝 50% 带光环并按养成三分之一／三分之二分阶；51 条词条（基础 12、特效 18、传说 12 含稀有的连击与再动、光环 9），每条有键、名字、层、标签、一排数值、单位、权重、叠法、结算位置和附加规则。表里只存一排数值，三种成色由加载器现算。
- `modes/xiyou/core/tianqi_affix_table.gd`（`XTianqiAffixTable`）：只读查表 `value(词条, 阶, 成色)`（不能出返回 null）、`tier_of_level`、`artifact_tier`、`slot_group`、`slot_has_aura`、`candidates(层, 栏位组)`、`layer_odds`、`slot_count`、`quality_layers`、`perfect_chance`、`fine_chance`。不掷随机数、不碰存档、不引用 XDB。
- 新专项 `xiyou_tianqi_affix_table`（47 项，不需要转换产物）和同内容的 Python 校验 `03_转换工具/天启篇词条表校验.py`（228 项，只用标准库）。
- 玩家可见：无（数据层，还没接线）。

## 和 PR #26（五档难度与档位数值表）的合并

两条线同时开工，那边已建了 `03_转换工具/天启篇数据校验.py`（`CHECKS` 表，`balance_table.json` 也放在 `modes/xiyou/tianqi_data/`）。为了不撞文件，本分支的校验放在**另一个文件** `03_转换工具/天启篇词条表校验.py`，提供 `run(path=None) -> bool`。两个都合并后，总装可以二选一：

1. 什么都不动：两个脚本各跑各的（都是只读、都只用标准库）。
2. 并成一个入口：在 `天启篇数据校验.py` 的 `CHECKS` 里加一行（中文文件名要用 importlib 载）：

```python
import importlib.util as _u
_s = _u.spec_from_file_location('affix_check', HERE / '天启篇词条表校验.py'); _affix = _u.module_from_spec(_s); _s.loader.exec_module(_affix)
CHECKS.append(('affix_table', lambda args: _affix.run()))
```

`modes/xiyou/tianqi_data/` 目录两边共用，各放各的 JSON，不冲突。

## 交接板

- 下一步：词条接线（第④步后半），等 12 栏位那条线合并后由 Max 派：`core/gear.gd` 天启篇规则下按本表掷词条（装备只存 `{词条键, 阶, 成色}`）、结算接 `damage.gd` 各池、连击走特性 34、再动走特性 61 并补「同名只生效一条」「多出来的行动不再触发」、深渊商人改货架。
- 用户试玩说明：无（还没接进游戏）。
- 需要用户决定：无（两处已由 Kyo 11-11 01:21 定，见下）。

## Kyo 已定（2026-11-11 01:21）

1. **底线检查只对基础层严格成立**：特效、光环的二阶极等于四阶普通，传说三阶极高于四阶普通。Kyo：「我觉得没问题，毕竟极很稀有」，不改；校验对这三层只打一行「注意」。
2. **词条数值不要小数**（Kyo：「我不想要有小数，你优化一下」）。本表和设计稿 v0.3 不一样的 9 处，一律改成 1、2、3、5、6（、8）这样的整数，不出现 4：

| 词条 | 设计稿 v0.3 | 本表 | 四阶普通／上品／极 |
| --- | --- | --- | --- |
| 闪避、敏捷 | 0.5、1、1.5、2、3、5 | 1、2、3、5、6、8 | 5／6／8 |
| 生命回复、魔法回复 | 0.3、0.5、0.8、1、1.5、2 | 1、2、3、5、6、8 | 5／6／8 |
| 吸血、再释放 | 1、1.5、2、2.5、3 | 1、2、3、5、6 | 3／5／6 |
| 光环·恢复 | 0.5、0.8、1、1.5、2 | 1、2、3、5、6 | 3／5／6 |
| 光环·全能 | 0.5、1、1.5、2、3 | 1、2、3、5、6 | 3／5／6 |
| 光环·暴怒的爆伤 | 暴击率 ×2（会出 4） | 单独一排 2、3、6、10、12 | 6／10／12（和设计稿四阶一样） |

   这几条的四阶数值比设计稿高了约一倍半到三倍（回复类最明显：每回合 5～8%），要等数值测算工具跑过再看要不要压；设计稿的新版本（v0.4）由写设计稿的一方补。成色几率、难度表、权重这类几率仍写成小数，它们不显示给玩家。
3. 栏位、品质先用英文／拼音键（weapon…mount；putong…shenhua），接线时和 12 栏位线、`XQuality` 对上，改键只改 JSON。

## 接线时要对的键（给接线那一步）

- 栏位键 → 12 栏位线的装备类型编号：表里 `slots[].key`，改键只改 JSON。
- 品质键 → `XQuality`（UnifiedQuality）的品质名：表里 `qualities[].key`／`name`。
- 结算位置 `pool` 的键（stat、xparam、regen、skill_damage、element_damage、final_damage、crit_multiplier、damage_taken、target_vulnerability、target_debuff、lifesteal、state_rate、heal_received、heal_dealt、heal_overflow、battle_start、target_rate、skill_cost、recast、drop_rate、exp_gold、on_kill、attack_times、extra_action）→ `damage.gd` 等处的实际池。
- 法宝种类：只有 `general`（通用法宝）出光环；专属、独特法宝的种类键等法宝线定。

## 进度账

- 无（天启篇改版，不计重制完成度）

## 可优化（流程／工具／效率）

- 建议：`07_开发环境/godot` 只认 Mac 的 `当前Godot.app`，云端跑 `语法检查.py` 要临时建 `当前Godot.app/Contents/MacOS/Godot` 链到 Linux 版（本轮这样跑的，跑完删了）；可让它在有 `$GODOT` 时直接用（哪吒，工具）。

## 验证

- `python3 03_再刷重制_Godot/03_转换工具/天启篇词条表校验.py`：228/228 通过（另打 3 条「注意」，即「Kyo 已定」第 1 条）。
- 专项 `xiyou_tianqi_affix_table`：云端容器（Godot 4.7.2 Linux，无转换产物）单跑 47/47。
- `语法检查.py`：682 个 .gd 0 个问题（云端，临时链接 Godot，见「可优化」）。
- 工具回归：「选测替身与 检查.sh 解析」1 项挂，在没有本分支改动的干净 main 上同样挂（云端环境差异），其余全过。
- 反向验证（逐项改 JSON → 两边各跑一次 → 用原字节还原）：

| 改坏的地方 | Python | Godot |
| --- | --- | --- |
| 物攻一排改成不递增 1,2,3,5,5,8 | 挂 2 项 | 挂 2 项 |
| 极几率 0.03→0.04（写进 4） | 挂 2 项 | 挂 2 项 |
| 九死特效 0.25→0.26（合计≠1） | 挂 1 项 | 挂 1 项 |
| 寻常传说 0→0.01、基础 0.89 | 挂 1 项 | 挂 1 项 |
| 戒指改进防具组 | 挂 1 项 | 挂 1 项 |
| 删掉一条光环 | 挂 2 项 | 挂 2 项 |
| 特效层改成一阶起 | 挂 4 项 | 挂 4 项 |
| 终伤第五个数 15→16 | 挂 1 项 | 挂 1 项 |
| 闪避一排写进小数 5.5 | 挂 1 项 | 挂 1 项 |
| 物攻标签改成守 | 挂 1 项 | 挂 1 项 |

- 要 Max 那边做的：把 `xiyou_tianqi_affix_table` 登记进 `选测对照.json`（建议跟 `modes/xiyou/tianqi_data/affix_table.json`、`core/tianqi_affix_table.gd`、`core/tianqi.gd` 走）；要不要把 Python 校验加进 `检查.sh` 由总装定。没碰切片、转换器、探针，合并不用重同步。

## 待交叉核查

- 乙档：`modes/xiyou/tianqi_data/affix_table.json` 与设计稿 v0.3 第 3～7 节逐条对照；`core/tianqi_affix_table.gd`、`tests/xiyou_tianqi_affix_table.gd`、`03_转换工具/天启篇词条表校验.py`。

## 本分支提交

- 8d9c053e 天启篇词条总表：数据表、只读加载器、Godot 专项与 Python 校验、交付单
- （本提交）词条数值全改整数，暴怒爆伤单独一排（Kyo 11-11 01:21）

- 车道路径：无（云端容器做的；本分支只加新文件，没改切片、转换器、探针）
