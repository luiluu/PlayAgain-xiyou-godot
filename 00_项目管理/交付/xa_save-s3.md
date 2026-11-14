# 交付：xa/save-s3

- 车道／工作者：存档门面 S3／ag（默认模型，方案定为 Sonnet＋medium，丙档）
- 协调派单：task_6788e7bf2a74
- 分支：xa/save-s3（基于 main `61b2786ca`）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【ag·存档门面S3·未经审查】存档门面 S3：18 个天启篇旧专项改走真实存读与夹具开局（dev.待定）

- **内存往返改真实写盘读档（12 个专项）**：`xiyou_tianqi_alien_gear`、`xiyou_tianqi_famine`、`xiyou_tianqi_rewards`、`xiyou_tianqi_death`、`xiyou_tianqi_money`、`xiyou_tianqi_numbers`、`xiyou_tianqi_plague`、`xiyou_tianqi_war`、`xiyou_tianqi_summit`、`xiyou_tianqi_no_diff_passive`、`xiyou_tianqi_weak_clear`、`xiyou_tianqi_drop` 原先只跑 `to_dict()`／`from_dict()` 内存往返，现统一改用共用夹具 [tq_save_kit.gd](../../03_再刷重制_Godot/01_Godot工程/tests/lib/tq_save_kit.gd)（`kit.roundtrip()`、`kit.save()`／`kit.reload()`、`kit.legacy(["drop"])` 及统一 `dir_override` 隔离与 `kit.teardown()`），经真实 `XSave.save`／`XSave.load_slot` 写盘与读档验证。
- **手写 `flags["tianqi"]` 改夹具真开局（7 个专项）**：`xiyou_tianqi_drop`（两类均涉）、`xiyou_tianqi_gear`、`xiyou_tianqi_gear2`、`xiyou_tianqi_trim`、`xiyou_tianqi_sect_a`、`xiyou_tianqi_sect_bing`、`xiyou_tianqi_sect_geng` 改用 `Kit.new_game(...)` 走 `XTianqi.start_new_game` 开局造档（`xiyou_tianqi_gear` `_ui()` 顺应开局 5 名成员改取 `s.battle_members()[0]`；`xiyou_tianqi_sect_geng` 保留 `[8, 9, 10, 11]` 阵容设置；`xiyou_tianqi_sect_bing` 同步加 `Kit` 隔离临时存档目录）。
- **范围与保留**：仅修改 `03_再刷重制_Godot/01_Godot工程/tests/` 下上述 18 个测试脚本，未改生产代码。`xiyou_tianqi_save.gd`（专门直测 `from_dict` 入口及 `{}` 空表保护）与 `xiyou_tianqi_elements.gd`（主测试已跑 `XSave.save`／`load_slot`，末尾仅附测 JSON 浮点规范化）按定位保留不变。
- 玩家可见：无（仅测试改造）。

## 交接板

- 下一步：总装按丙档核查并合并 `xa/save-s3`，补跑超过 2 分钟的全量门禁检查（见下方「留给总装」）。
- 需要用户决定：无。
- 用户试玩说明：无。

## 进度账

- 对应方案《[cc_save-rng-facade](12cd35586^:00_项目管理/交付/cc_save-rng-facade.md)》3.1 分批表 **S3**（说明：方案成文于 `d45643f0b`，当前 `main` 新增 `sect_bing`、`no_diff_passive`、`weak_clear` 等，共排查出 12 个仅内存往返 + 7 个手写 `flags["tianqi"]`，去重后全部 18 个已改造完成）。

## 改造清单与断言数对照（18 个专项）

| 专项脚本（`tests/`） | 改造类别 | 具体改法 | 改前断言 | 改后断言 | 结果 |
| --- | --- | --- | --- | --- | --- |
| `xiyou_tianqi_alien_gear.gd` | 真实存读 | `to_dict/from_dict` → `Kit` + `kit.roundtrip()`（恢复 `XState.current`） | 57/57 | 57/57 | 通过 |
| `xiyou_tianqi_famine.gd` | 真实存读 | `to_dict/from_dict` → `Kit` + `kit.roundtrip()` | 99/99 | 99/99 | 通过 |
| `xiyou_tianqi_rewards.gd` | 真实存读 | `_items()`、`_summit()` 2 处 → `Kit` + `kit.roundtrip()` | 78/78 | 78/78 | 通过 |
| `xiyou_tianqi_death.gd` | 真实存读 | `to_dict/from_dict` → `Kit` + `kit.roundtrip()` | 95/95 | 95/95 | 通过 |
| `xiyou_tianqi_money.gd` | 真实存读 | `to_dict/from_dict` → `Kit` + `kit.roundtrip()`（恢复 `XState.current`） | 77/77 | 77/77 | 通过 |
| `xiyou_tianqi_numbers.gd` | 真实存读 | `to_dict/from_dict` → `Kit` + `kit.roundtrip()` | 67/67 | 67/67 | 通过 |
| `xiyou_tianqi_plague.gd` | 真实存读 | `to_dict/from_dict` → `Kit` + `kit.roundtrip()` | 100/100 | 100/100 | 通过 |
| `xiyou_tianqi_war.gd` | 真实存读 | `to_dict/from_dict` → `Kit` + `kit.roundtrip()` | 99/99 | 99/99 | 通过 |
| `xiyou_tianqi_summit.gd` | 真实存读 | 手写 `dir_override` + `to_dict/from_dict` → `Kit` + `kit.roundtrip()` | 79/79 | 79/79 | 通过 |
| `xiyou_tianqi_no_diff_passive.gd` | 真实存读 | `JSON+from_dict`（2 处 + `_reload`）与手写清目录 → `Kit` + `kit.roundtrip()` / `kit.save()+reload()` | 176/176 | 176/176 | 通过 |
| `xiyou_tianqi_weak_clear.gd` | 真实存读 | `JSON+from_dict` 与手写 `dir_override` → `Kit` + `kit.roundtrip()` | 46/46 | 46/46 | 通过 |
| `xiyou_tianqi_drop.gd` | 真实存读 + 夹具开局 | `_tianqi_state` → `Kit.new_game(diff)`；`_signature` 2 处 `duplicate+from_dict` → `kit.save()` + `kit.legacy(["drop"])` + `kit.reload()` | 85/85 | 85/85 | 通过 |
| `xiyou_tianqi_gear.gd` | 夹具开局 | `_tianqi_state` → `Kit.new_game("jiusi")`；`_ui()` 改测 `s.battle_members()[0]` | 36/36 | 36/36 | 通过 |
| `xiyou_tianqi_gear2.gd` | 夹具开局 | `_tianqi_state` → `Kit.new_game("jiusi")` | 47/47 | 47/47 | 通过 |
| `xiyou_tianqi_trim.gd` | 夹具开局 | `_tianqi_state` → `Kit.new_game(diff)` | 44/44 | 44/44 | 通过 |
| `xiyou_tianqi_sect_a.gd` | 夹具开局 | `_tianqi_state` → `Kit.new_game(diff)` | 41/41 | 41/41 | 通过 |
| `xiyou_tianqi_sect_bing.gd` | 夹具开局 | `_tianqi_state` → `Kit.new_game(diff)` + `Kit` 隔离临时存档目录 | 28/28 | 28/28 | 通过 |
| `xiyou_tianqi_sect_geng.gd` | 夹具开局 | `_tianqi_state` → `Kit.new_game("jiusi")`（保留 `lineup = [8, 9, 10, 11]`） | 81/81 | 81/81 | 通过 |

## 反向验证抽查（`07_开发环境/反向验证.py`）

抽查 3 个已改造专项（覆盖纯真实存读、纯夹具开局、两者兼有），临时破环源码 1 处确认测试能咬住并自动还原：

| 抽查专项 | 临时改动 | 结论 |
| --- | --- | --- |
| `xiyou_tianqi_rewards` | `tianqi_rewards.gd` 去掉 `got(s, key)` 判重（遗物每次都给） | 咬住了（失败数 有失败） |
| `xiyou_tianqi_gear2` | `gear_table.json` 坐骑神话敏捷 `33` 改成 `34` | 咬住了（失败数 有失败） |
| `xiyou_tianqi_drop` | `tianqi_drop.gd` `fill()` 去掉 `XOrbs.hash32` 改 `randi()`（旧档读档重掷） | 咬住了（失败数 有失败） |

## 验证

- 全部 18 个改后专项前台分批经 `并行测试.py ... --full` 跑过，**全部通过、0 失败**，每项断言总数与改前持平（见上表）：
  - 批 1：`xiyou_tianqi_alien_gear` 57/57、`xiyou_tianqi_death` 95/95、`xiyou_tianqi_famine` 99/99、`xiyou_tianqi_rewards` 78/78（14 秒）
  - 批 2：`xiyou_tianqi_money` 77/77、`xiyou_tianqi_numbers` 67/67、`xiyou_tianqi_plague` 100/100、`xiyou_tianqi_war` 99/99（14 秒）
  - 批 3：`xiyou_tianqi_no_diff_passive` 176/176、`xiyou_tianqi_summit` 79/79、`xiyou_tianqi_weak_clear` 46/46（17 秒）
  - 批 4：`xiyou_tianqi_drop` 85/85、`xiyou_tianqi_gear2` 47/47、`xiyou_tianqi_trim` 44/44（`gear` 修 `_ui()` 后补测过）
  - 批 5：`xiyou_tianqi_sect_a` 41/41、`xiyou_tianqi_sect_bing` 28/28、`xiyou_tianqi_sect_geng` 81/81（12 秒）
  - 复跑 `xiyou_tianqi_gear`：36/36（5 秒）
- `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`（终版后前台执行）：`872 个 .gd，0 个问题（17 秒）`，通过。
- `python3 03_再刷重制_Godot/07_开发环境/天启篇存档登记.py`：通过（`天启篇存档字段都已登记`）。
- 留给总装（单次超过 2 分钟，按派单不在本车道跑）：`03_再刷重制_Godot/07_开发环境/检查.sh`（全量检查约 10 分钟）、`03_再刷重制_Godot/07_开发环境/工具回归.py`（约 131 秒）。

## 可优化（流程／工具／效率）

- 现状：`tests/lib/tq_save_kit.gd` 的 `new_game()` 会自动塞入 5 名弱者开局队友并标记 `lineup`，导致原本只建空队再测单个默认角色的旧测试（如 `xiyou_tianqi_gear.gd` `_ui()`）需调整取队首成员。暂保持 `Kit.new_game` 不动，如后续还有大量单人测试接入可考虑加可选参数，不强求。

## 本分支提交

- `733b396a0` 测试(天启篇)：存档门面 S3 旧专项改走真实存读与夹具开局（仅改 `tests/` 下 18 个文件）
- 交付单提交见本分支 `HEAD`

## 待交叉核查

- 核查档位：丙档（只改 `tests/`，不改生产代码）。
- 抽核重点：18 个 `tests/xiyou_tianqi_*.gd` 中 `Kit` 初始化／`teardown`、`roundtrip()` 后必要处的 `XState.current` 恢复、`Kit.new_game` 替换手写 `flags["tianqi"]` 是否保持原有测试意图与断言不减。
