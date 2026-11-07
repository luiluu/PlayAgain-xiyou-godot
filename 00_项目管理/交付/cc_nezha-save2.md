# 交付：cc/nezha-save2

- 车道／工作者：存档／哪吒（cc，项目线程「完成再刷西游Godot引擎重制」）
- 状态：可合并
- 基于：cc/nezha-save1 头（1c45a467），交付前已合 main（ec877cb6，dev.389）。

## 做了什么

### 报告第 10 项：读档校验 → `xiyou_save_corrupt` → 读档前深层类型校验

- 问题：`XSave.valid_data` 只查顶层和角色的部分字段，`XState.from_dict` 及其调用的各 `from_save`、读完就跑的包装（XPets.loaded 等）读得多得多。坏字段（如 orbState 是数组）让 from_dict 半途报脚本错：这时护盾账本等全局已清、新状态只建了一半，有的样例还会把坏档换成当前局。
- 复现：`tests/xiyou_save_corrupt`（新）。先真存一份档，再按 50 种损坏逐个改写成 `save_2.json`（真写盘），走 `XSave.load_slot(2)`／`summary(2)`；另一例写坏的切后台自动存档走 `load_auto`。断言读档返回失败、`XState.current` 与当前档位不变、金币不变、存档页显示「无法读取」，且日志无 SCRIPT ERROR（并行测试遇 SCRIPT ERROR 判挂）。旧代码上 50/53 挂（只剩完好档那 3 条过），新代码 53/53。
- 修法：新文件 `modes/xiyou/core/save_check.gd`（`XSaveCheck`），按 from_dict 的实际读法逐字段查：会被 int()／float() 的要是标量，bool() 的要是布尔或数字，逐项 map 的要是标量数组，`for k in x` 后取 `x[k]` 的要是字典且值为标量，有类型字典成员（dungeon、bossMastery、raceSupply、ecoFrac、hangUp、flags）要是字典；称号缺 icon／color、actorOps 缺 skill、宝珠状态、藏宝图 rom、载具、画面色调、仓库（装备项走 `_valid_gear`）、商店库存、渡鸦、饿狼、更衣、角色仓库、宠物（出战宠物的 push／skills）都在内。`XSave.valid_data` 角色每行末尾调 `XSaveCheck.actor_row`，结尾 `return XSaveCheck.top(d)`。
- 「先建完再替换」：GDScript 没有异常，from_dict 一旦开始就没法半途回退；所以做成校验当闸门：valid_data 不过就不进 from_dict（load_slot、load_auto、summary、auto_summary 都先过 valid_data），过了的档 from_dict 不会在类型上出错，也就只在建完后替换 `XState.current`、返回成功。没改 from_dict 的顺序，也没改档案格式。
- 只拒「会出错」的形状：缺省的可选字段、字符串数字照旧放行（int("12") 不报错），不收紧本来能读的旧档。改 from_dict 或各 from_save 的读法时要同步改 save_check.gd（文件头有注明）。
- 不是原版缺陷（MV 原版读档是另一套），所以没有回退开关、没有 O 号。

### 第二项：Map004 漩涡过场 rift1 残留 options.json → 本分支无法复现，未改代码

- 查实：rift1（CodexWhisper，配置键 codexWhisperSeen）和 `XConfig.whisper_mark` 只在新源分支上（悟空 `cc/wukong-newsrc10`／`-ec`，提交 4cba550b、4dcce00f、592934f9），main（ec877cb6）和本分支都没有这个过场，所以本分支上首跑、再跑没有差别可复现。
- 已处理的：`xiyou_actor_p0` 的 recruit_11 已由悟空在 2ff9d706 修了（开头删旧 options.json、`_loaded_path` 置空、`whisper_mark("rift1")`），floor_run、fortress029 在 0f753038 也处理了。
- 建议（新源合进 main 之后做，或交给新源车道顺手做）：
  1. 本分支上用 `XConfig.path_override = XSave.dir().path_join("options.json")` 的测试约 50 个，大多只在结尾删 options.json、开头不删；上一轮中途挂掉就会留下残档。改成开头也删、`XConfig._loaded_path = "<unloaded>"` 重读。最好在 tests 里加一个公用小函数（删残档、设 path_override、重读，新源上再按需 `whisper_mark("rift1")`），各测试一行调用，免得 50 个文件各写一遍。
  2. 新源上起跑在 Map004 的再逐个确认要不要标 rift1：验过场本身的（opening_branches、guide）不标；只验别的（lobby_shops 的 `case_e54p0_base_0-0`、招募）标上。`xiyou_lobby_shops` 现在只在第 118 行结尾删 options.json。
  3. 复现法：同一场景本机连跑两次（第二次不删 `user://test_xiyou_lobby_shops`），结果要和云端新目录一致。

### 总装追加：O-206、O-209 回退值补测试

- O-206 `XSaveTransfer.BACKUP_BEFORE_IMPORT = false`：`xiyou_platform` 新断言 `transfer_import_rollback_no_backup`，真写盘导入到有档的第 1 格，断言照样导入、目录里不多出 `.before_import` 备份（开着时同一流程多一个，已有 `transfer_import_backs_up`）。
- O-209 `XMVCanvas.CRISP_HIDPI_TEXT = false`：把画字时「要不要加同色描边」的判断抽成 `XMVCanvas.embolden_at(scale)`（画字照用它，行为不变）；`xiyou_key_map` 新断言 `crisp_hidpi_no_embolden`（默认：缩放 1 加、1.5／2 不加）和 `crisp_rollback_always_embolden`（关掉后 1 与 2 都加）。
- `回退开关覆盖.py`：缺口 新 2 → 新 0（覆盖 127 → 129）。

## 改动文件

- 新：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/save_check.gd`（＋.uid）
- 改：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/xsave.gd`（valid_data 两处调用）
- 新：`03_再刷重制_Godot/01_Godot工程/tests/xiyou_save_corrupt.gd`／`.tscn`（＋.uid）
- 改：`modes/xiyou/ui/mv_canvas.gd`（抽出 embolden_at）、`tests/xiyou_platform.gd`、`tests/xiyou_key_map.gd`（O-206／O-209 回退断言）

## 验证

- 云端整轮（合 main 前，提交 34deeed99d）：442 个场景全过，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42325277578
- 合 main（ec877cb6）后本机：语法检查通过；存档相关选测 xiyou_save_corrupt、xiyou_review_regressions、xiyou_save_page、xiyou_autosave、xiyou_star_warehouse、xiyou_save_events、xiyou_pause_save、xiyou_battleback_save（结果见下）；工具回归。
- 旧代码上复现：xiyou_save_corrupt 3/53（50 个坏档样例全挂，日志 49 处 SCRIPT ERROR）。

## 变更记录草稿

【cc·哪吒·未经审查】读档深层类型校验（审计第 10 项）：新增 XSaveCheck，按 from_dict 与各 from_save 实际读取逐字段查类型，坏一处整档不读，不再半途报错留下半个新局；新测试 xiyou_save_corrupt（50 种坏档、真写盘、存档页与自动存档两个入口）。rift1 残留 options.json 一项只在新源分支上存在，查明情况与建议写在交付单。

## 待交叉核查

- 甲档（存档）：save_check.gd 是否漏了 from_dict 实际读到、会出错的字段；是否误拒了合法旧档（尤其 vehicles、pets、phwarehouse）。

## 可优化

- 测试设置 options.json 的写法约 50 处各写一遍，建议收成一个公用函数（见第二项建议 1）。

## 本分支提交

- 1510d71a 起：读档深层类型校验＋xiyou_save_corrupt；合 main；交付单。

可合并
