# 交付：cc/wukong-custom1b（接自 98dabaed）

- 车道／工作者：C 规则／悟空（cc）
- 状态：**未完成，不可合并**。Kyo 11-04 说停手收工，停在写专项之前。下面的代码**一次都没跑过**，只跑了语法检查（结果见本分支提交说明）。

## 接续要点

已提交（WIP）：

- 探针 `03_转换工具/mv_oracle/target_eval_probe.cjs`，已跑，35 个用例无错，产物拷到 `tests/fixtures/target_eval_oracle.json`（不进同步，名字符合探针登记检查）。
- `battle_logic.gd`：`target_eval`、`_eval_targets`、`_v8_shuffle` 接在 `_targets_for` 开头；`skill_item_costs`、`can_pay_items`、`pay_items`、`item_cost_rows` 接在 `can_use`、`pay_skill_cost`。
- `skill_scene.gd`（菜单付费、费用显示）、`battle_scene.gd`（战斗列表费用显示）。
- `battle_event_runner.gd`：`_freeze_followup_script`（CE1321）。

还没做：

1. 写专项 `tests/xiyou_target_eval.gd`＋`.tscn`，对照夹具：用 `XRandomStream.scripted`，带子条目 `{"kind":"float","value":v}`，夹具顶层 `tapes`；比目标和 `rule.draws`（对应 `calls`）。人数 1～8 时直接给 `l.actors` 赋值（没确认 `setup` 有没有人数上限）。回春术要 4 个敌人，`XEnemy.new().setup(...)` 塞进 `l.enemies`。
2. 消耗物品断言：`cost.parsed`、`cost.pay.*`，再加菜单用 2610 扣物品、智能 AI 不选付不起的技能。
3. 冻结追击断言：放 6171 且会 6175 → `pending_force` 是 6172；不会 6175、敌人放都不追。原版语义只读了代码，这条没有探针数据。
4. 普查清单：见下，把 E 类改成断言全认得。
5. 先跑 `选测.py main --list`，选测＋专项，`--oracle` 按需；`git merge main`（改了探针，可能要 `--补齐`）；写完本单「验证」改「可合并」。

## 探针量到的

- Custom Target Eval 是**三种**写法，不是之前说的两种：36 个「活着多于 2 个取两个」，**9 个「多于 3 个取两个」**（龙息、狂怒冲撞、熔岩陨弹一族，3 个目标时全打），回春术 1172 另写。全库共 46。
- 随机数：每比较一次取一次，n＝3 时 2～3 次，n＝4 时 4～5 次，随比较结果变。原版运行的 nwjs 154 和探针的 node 都是 V8 TimSort，短数组同一算法（nwjs 版本从正式 Mac 游戏的 Framework 目录看到；算法相同是按版本推断，没在 nwjs 里实测）。`_v8_shuffle` 照此写，**还没对过夹具**。
- 回春术 1172 没人受伤：目标是三个 undefined，走完整行动不报错、扣 200 MP、无效果。全库敌人的行动表里没有它，没查事件强制的用法。
- 消耗物品只有 `<Item n Cost: m>` 一种，20 个技能；费率、替换备注数据里没有（`cost.other_notes`）。敌人不看不扣。切片内角色能学的：2610、3760、3761、5765、5766。

## 新发现，要总装看（没动）

**混乱类状态重制疑似没实现**：原版 restriction 1～3 的状态 13 个（7、8、9、124、1045、1113、1567、1830、2046、2504、2505、2506、2580），行动者带着时走 `makeConfusionTargets`（探针 `gt2.confused`：state 8 时 `confused` 真、level 2、不走 eval，每次取 2 个随机数）。重制 `modes/xiyou` 里 rg 不到混乱目标逻辑，`battle_logic` 只看 restriction ≥4。只凭 rg，没跑对局验证。多个技能能上这些状态（如 102、470、780、981）。若属实比 Target Eval 影响面大，建议单开一期。本期 eval 接在 `_targets_for`，以后混乱加在它前面即可。

## 普查 E 类 21 种（已核）

交接板和清单对不上的原因：清单 E 类是「地图解释器认不出」，不是真缺。跑 `xiyou_script_census`（改动前）：`CENSUS_BATTLE_KNOWN 20`，20 种战斗解释器认得。

- 唯一没认的是冻结追击 CE1321，**真缺**：技能书物品 1951、1952 学得到 6171、6175。本分支补了，没跑过。
- 打算：清单键留着（地图解释器仍认不出，删了 `no_new_unknown` 会挂），`xiyou_script_census.gd` 加一条断言「E 类全部战斗认得」（`battle_known` 等于 21）。**这步没做**，清单和普查测试都没改。
- 以上 callers 是按冻结数据追的，没逐条进对局。

## 待交叉核查

改了 `battle_logic.gd`（核心文件）；交付时重点核。

## 变更记录草稿

（完成后写）

## 本分支提交

- WIP：见 `git log main..cc/wukong-custom1`
