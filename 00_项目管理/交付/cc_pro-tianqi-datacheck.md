# 交付：cc/pro-tianqi-datacheck

- 车道／工作者：天启篇数据校验补七印祭坛／cc（Pro）
- 状态：可合并
- 合并顺序：排在七印装备化、七首之龙两条车道之后合；合前对最新表重跑一次 `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py` 和 `python3 03_再刷重制_Godot/03_转换工具/测试天启篇数据校验.py`（那两条车道会给七印的表加字段；不认识的键不报错，但改了已查字段的值、件数或键名会在这里报出来）。

## 变更记录草稿

## 2026-11-12 【cc·Pro·未经审查】天启篇数据校验补七印祭坛四张表（dev.待定）

- `03_转换工具/天启篇数据校验.py` 新增五项检查，登记进 CHECKS，文件头说明列表补一行：
  - `qiyin_gear`、`qiyin_drop`、`qiyin_dragon`、`qiyin_altar` 各一项：数字避开 4（各表自己的 `nice_number_exempt` 豁免，同 `check_gear_table` 那套 `nice_violations`）；印键只有 bai、hong、hei、hui、xun、zhen、mo；部位键只有 head、body、hands、waist、legs、feet；几率（键名 `chance` 或 `*_chance`，按难度分档的字典逐档查）在 0～1；权重（`weights`、`*_weights` 字典，`*_weight` 单值）非负且不全为 0。
  - `qiyin_gear` 另查：部位、套装件、神器栏的类型号都在 `core/tianqi_gear.gd` 的 `ORDER` 里（解析 gd 文本），套装件类型号同它的部位；七套各 6 件且部位不重复、毕业武器 13 把、神器 5 件，键不重复；武器和流派的类型都在 `weapon_types` 里。
  - `qiyin_refs` 跨表：drop／dragon／altar 引用的印和套装在 gear 的 `seals`、`sets` 里，部位在 `parts` 里，神器在 `artifacts` 里；drop 的 `weapon_classes` 武器类型名在 gear 的 `weapon_types` 里，且和 gear 对应流派的 `types` 一致（流派写 `any` 的默印不比）。
  - 只查表里现有的字段，缺字段不查、不认识的键不报错；表不在打印「跳过」算通过。
- 新建 `03_转换工具/测试天启篇数据校验.py`（unittest，39 例）：每条新规则一个反例夹具（临时目录放真表副本改坏一处，把脚本的 `DATA_DIR`、`TIANQI_GEAR_GD` 指过去），另有表缺失跳过、不认识的键不报错、豁免只认本表；正例对工程里的真表跑 `main([])` 全过。
- 玩家可见：无。

## 交接板

- 下一步：无。
- 用户试玩说明：无。
- 需要用户决定：无。

## 发现

- 无。四张真表在 main `e3df19b` 上全部通过，没有要改表的项。

## 验证

- `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`：全部通过（含新加的五项）。
- `python3 03_再刷重制_Godot/03_转换工具/测试天启篇数据校验.py`：39 例全过。
- 没改 .gd 和 tianqi_data 下的表，不涉及 Godot 测试。

## 优化登记

- 无。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 建议：`天启篇数据校验.py` 和新测试现在都不在 `检查.sh`／`工具回归.py` 里，表改坏了只有手跑才发现。可在 `检查.sh` 的 tools 段加一行跑 `测试天启篇数据校验.py`（不到 1 秒，只用标准库）；本车道不改共用脚本，交总装派。

## 本分支提交

- 265b18b 天启篇数据校验：补七印祭坛四张表和跨表引用检查，新建回归测试
- （本提交）补交付单

## 总装补（合并前）

- 按本单「可优化」建议，`检查.sh` tools 组加一行：跑 `03_转换工具/测试天启篇数据校验.py` 和 `天启篇数据校验.py`（写成 `$ROOT/03_再刷重制_Godot/03_转换工具/…` 让替身解析认得；`测试选测.py CheckerTests CheckerStubParseTests` 32/32）。
