# 交付：cc/pro-tianqi-datacheck3

- 车道／工作者：工具／Pro（cc，云端）
- 状态：可合并

## 合并顺序

- 排在金钱落地 `cc/tianqi-money` 之后合（它改 `balance_table.json`、加 `money_table.json`），合前对最新表重跑一次 `测试天启篇数据校验.py` 和 `天启篇数据校验.py`；`money_table.json` 合进 main 后可再补一个检查。
- 本分支只改两个工具脚本，不碰 `tianqi_data/` 下的表和任何 `.gd`。

## 变更记录草稿

## 2026-11-14 【cc·Pro·未经审查】天启篇数据校验补第三批六张表（dev.待定）

- `03_转换工具/天启篇数据校验.py` 新增六项检查，登记进 CHECKS，文件头说明列表补一行。都只查代码真读的字段（读表的模块写在各函数说明里），缺字段不查、不认识的键不报错，表不在打印「跳过」算通过；数字避开 4 照 `check_gear_table` 那套 `nice_violations`，豁免认各表自己的 `nice_number_exempt`；跨表要的参照表不在就跳过那一项。
  - `reforge`（XTianqiReforge）：`costs` 非空、非负整数、随阶不降、档数不超过 `affix_table.json` 的阶数；`allow_perfect`／`allow_rare` 是布尔。
  - `alien_gear`（XTianqiAlienGear、XTianqiAlienAffix）：各级 `rate` 在 0～1、`energy` 正整数、`refund` 非负且不超过 `energy`、级名非空；`level_order` 不重复且和 `levels` 一一对上，几率、分解能量随级不降；`late_only.min_level` 在 `levels` 里；工坊 `costs` 非负整数；`effects` 的词条在 `new_affixes` 里、数值非负、分级数组个数同 `level_order`，百分比字段（节俭 cost／heal、带毒 chance、再动 taken）在 0～100，再动 `every`、临终 `per_battle` 至少 1。跨表：`late_only.keys` 和 `new_affixes` 都在 `rewards.json` 的 `finale.lines` 里。
  - `abyss_shelves`（XTianqiMerchant）：两档货架 `cost`／`rare_cost` 非负整数、稀有价不低于原价；`layer` 在 `affix_table.json` 的 `layers` 里，`min_tier` 是正整数且在 `tiers` 里，`min_quality` 在 `core/tianqi_affix_roll.gd` 的 `QUALITY_KEYS` 里（解析 gd 文本）。
  - `qiyin_equip`（XTianqiQiyinEquip）：`quality_legacy`、`armor.atype`、`any_class` 类型对；各部位、各武器底子 `base_id` 正整数、`params` 是 8 个非负数；`artifact.base_id` 正整数；部位键只有六个；`names` 都是字符串。跨表：`qiyin_gear.json` 的六个部位、十二种武器类型都有底子，反过来底子的部位、类型都在 `qiyin_gear` 里（`_make_set`／`_make_weapon` 找不到底子就做不出装备）。
  - `qiyin_show`（XTianqiQiyinShow）：`seals` 七印齐全、键只有七个，`color`／`accent`／`true_glow` 是 `#RRGGBB`，`glyph` 非空；各段 `se` 是字符串、秒数（hold、flash、fade_out、step）非负、`dim` 在 0～1、震屏 power／speed／frames 是正整数；`art` 是 `res://` 路径。跨表：`qiyin_gear` 的印都有演出。
  - `qiyin_dragon_run`（XTianqiQiyinDragonRun）：`fight.troop`／`shell_enemy` 正整数、`extra_actions` 非负整数、`rate` 是 8 个正数、`tone` 是四个数（红绿蓝 -255～255、灰 0～255）、`name`／`battler` 非空、`open_reveal`／`segment_lock` 是布尔；`scenes` 每项是 [说话人, 台词] 的列表；`logs` 是非空字符串。
- `03_转换工具/测试天启篇数据校验.py` 39 例 → 48 例：新加 `Batch3Fixture`（临时目录放六张表和 affix_table、rewards、qiyin_gear 的真表副本，把 `DATA_DIR` 指过去），每条新规则一个反例（73 个子用例，含改参照表触发的跨表反例 3 个），另有表缺失跳过、参照表缺失时跨表项跳过、不认识的键不报错、JSON 读坏算失败、豁免认本表（4 个）且不借别的表；正例里 `main([])` 对真表全过并逐张确认六张表「规则自检：通过」，另验 `QUALITY_KEYS` 能从 gd 解析出七档。
- 玩家可见：无。

## 交接板

- 下一步：`drop_table.json`（dev.559 掉落重构）进 main 后补一个检查（见「待补」）；`money_table.json` 合进 main 后同样可补。
- 用户试玩说明：无（只改工具）。
- 需要用户决定：无。

## 发现

- 对 main 2f87155（dev.558）上的真表跑一遍，六张新表全过，没有不过的项，表一张没改。
- 记一笔口径（不算问题）：`alien_gear.json` 的再动 `every` 是 [5, 3, 3, 2]，随级变小是设计（级越高越常多动），所以 `effects` 分级数组只查个数和范围、不查单调；`levels` 的几率和分解能量才查随级不降。

## 待补

- `drop_table.json`：开工时（2026-11-14）main 最新是 dev.558，`tianqi_data/` 里还没有这张表，dev.559 掉落重构只在 `ci/cc/drop-rework` 上。照派单先做其余六张；它合进 main 后补 `check_drop_table`，要查落档边界「小于 16／50／110／1000」避开 4、概率 0～1、权重非负且不全为 0、档位／品质键在已知集合里、等级段首尾不倒挂。

## 验证

- `python3 03_再刷重制_Godot/03_转换工具/测试天启篇数据校验.py`：Ran 48 tests，OK。
- `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`：天启篇数据校验：全部通过，退出码 0（不给 `--params`，balance／horsemen 的 A 组照旧跳过）。
- 没跑 Godot 测试：本分支不改 `.gd` 和数据表，`检查.sh` 里相关的只有「天启篇数据表校验」这一项，就是上面两条命令。

## 进度账

- 无变化（工具）。

## 可优化（流程／工具／效率）

- 建议：`天启篇数据校验.py` 已到约 1500 行、二十多项检查，下次再加表时可按表拆成 `天启篇数据校验/` 包（每张表一个模块，CHECKS 汇总），测试也按表拆；归工具车道，不急。

## 本分支提交

- 见 `git log origin/main..cc/pro-tianqi-datacheck3`：一个提交，补六张表检查、测试和本交付单。
