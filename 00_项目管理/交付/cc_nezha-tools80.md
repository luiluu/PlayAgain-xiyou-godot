# 交付：cc/nezha-tools80

- 车道／工作者：工具／哪吒（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-06 【cc·哪吒·未经审查】云端 --scenes 写错就报错；xiyou_export 默认来源认 XIYOU_APP、再用本树冻结正式源（dev.待定）

- `07_开发环境/云端选测.py`：新增 `requested_scenes`，`plan --scenes` 用它挑场景。场景名不带 `.tscn`、在 `tests/` 里不存在、或一个都没给，直接报错停下（RuntimeError，`main` 照常转成非零退出），不写计划。原来写错的名字被静默略过，全错时计划是空的，云端「0 个场景全过」显示成功（11-06 换源车道两次手动重跑都这样白跑）。
- `03_转换工具/xiyou_export.py` `DEFAULT_APP`：先认环境变量 `XIYOU_APP`，没设就用本树的 `02_内容与素材/冻结正式源/app.nw`（车道工作树里是 `新建工作树.sh --补齐` 建的链接，主工作区里就是原件）；原来写死主工作区的 v0.28 路径。`同步正式西游.py`、`验证西游来源.py`、`事件指令统计.py`、`事件增量比对.py` 的 `--app` 默认值都从它来，一并跟上。
- 回退：`requested_scenes` 调用处改回原来的交集写法；`DEFAULT_APP` 改回原路径字符串。

## 交接板

- 下一步：无新增。
- 用户试玩说明：无（工具改动）。
- 需要用户决定：无。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 注意（不是本轮改的）：没跑过 `--补齐` 的工作树里本树冻结正式源链接不在，`DEFAULT_APP` 会指向一个不存在的路径；原来会悄悄读主工作区的。车道都先 `--补齐`，所以照常；转换器遇到来源不存在时本来就报错，不会读错源。
- 优化登记草稿：无

## 待交叉核查

- `03_再刷重制_Godot/07_开发环境/云端选测.py`：`requested_scenes`、`cmd_plan` 的 `--scenes` 分支。
- `03_再刷重制_Godot/03_转换工具/xiyou_export.py`：`DEFAULT_APP`。
- `03_再刷重制_Godot/07_开发环境/测试云端准备.py`：新类 `SceneListAndAppDefaultTests` 3 项。未改战斗核心文件。

## 验证

- 新增 3 项（`test_scenes_without_tscn_or_missing_fail_instead_of_empty_pass`：不带 .tscn／不存在／空白三种都报错、不写计划；`test_valid_scene_list_is_kept_in_order_given`；`test_export_default_app_prefers_env_then_this_tree`：拷到临时目录载入，设了 XIYOU_APP 用它、没设用临时树自己的冻结正式源）在改动前的代码上全部挂（2 失败 1 报错）。
- `测试云端准备.py` 32 项全过；`测试选测.py` 133 项全过；`工具回归.py` 全过（50 秒）；`测试增量同步.py` 69 项全过（同步脚本从 xiyou_export 取默认来源）。
- 没在云端真跑 `--scenes`；没跑真同步。

## 本分支提交

- 见 git log
