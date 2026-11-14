# 交付：xa/stub-check-in-build

- 车道／工作者：发行空壳数值默认 0 检查共用化／小A（xa，xa-stub-check）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【小A·未经审查】发行空壳：出包与补丁共用「数值默认 0」检查（dev.待定）

- 玩家可见：无（只改构建与检查工具）
- `03_再刷重制_Godot/07_开发环境/发行空壳.py`：抽出 `check_errors(missing, how)`，让 `make_tree`（`发行出包.py` 整包与 `发布补丁.py` 补丁共用入口）在克隆落盘前与 `check` 子命令走同一套验证（含缺成员拒绝与返回 `int`/`float` 的数值类函数按类型给 0 拒绝），验证不过直接非零退出阻断出包；`build_all` 开头清空模块级 `NUMERIC` 集合，避免同进程多次调用残留。
- `03_再刷重制_Godot/07_开发环境/测试发行空壳.py`：新增 `test_numeric_default_zero_rejected_in_make_tree_for_build_and_patch`，构造返回 `1.0` 且无早退、无特例的天启篇倍率函数，验证无特例时 `make_tree`、整包入口（`发行出包.stub_tree`）与补丁入口（`发布补丁.export_patch`）均被阻断，补进特例后均通过。

## 覆盖边界（只报告不改，供总装写进规则）

1. **自动覆盖范围**：
   - 脚本空壳化（`发行空壳.py`）：仅扫描 `modes/` 目录下且顶层声明匹配 `^class_name (X(?:Tianqi\w*|RiftAlien))\b` 的 `.gd` 脚本（`XTianqiTitle` 白名单保留）。同时只在 `modes`、`core`、`scenes`、`addons` 四个目录下扫描西游外部引用。
   - 发行内容审计与导出排除（`发行内容审计.py` 的 `DENY` 与 `export_presets.cfg`）：自动拦截 `modes/xiyou/tianqi_data/*`、`content/tianqi/*`、`content/gojo/*`、`modes/xiyou/rift_alien.json`、`modes/xiyou/ui/tianqi/*` 下的新文件。
2. **当前黑名单／规则认不出、需手动登记的情形（以后新车道必查）**：
   - **类名不带 `XTianqi` 前缀（且不是 `XRiftAlien`）的天启篇脚本**，或**放在 `modes/` 以外目录（如 `core/`、`scenes/`）的天启篇脚本**：`发行空壳.targets()` 不会识别，真脚本会原样进包。新车道新增天启篇类应统一使用 `XTianqi*` 命名并放在 `modes/` 下；若确需其他类名或目录，必须手动扩展 `发行空壳.py` 的 `CLASS_RE` / 扫描目录。
   - **全新目录或顶层单文件形态的天启篇数据／美术／UI 资源**（不在 `modes/xiyou/tianqi_data/*`、`content/tianqi/*`、`content/gojo/*`、`modes/xiyou/ui/tianqi/*` 下）：`发行内容审计.DENY` 与导出预设黑名单认不出，会直接打进整包和补丁。新车道凡新建天启篇专属目录或独立数据文件，必须同步手动登记进 `发行内容审计.py` 的 `DENY` 以及 `export_presets.cfg` 三个发行预设（`Windows 发行`、`安卓 发行`、`macOS 发行`）的 `exclude_filter`。
   - **西游代码新增调用天启篇数值函数（返回 `int`/`float`）**：若真脚本前 8 行没有 `if ...: return <简单值>` 早退，必须同步在 `发行空壳特例.json` 登记关闭时的返回值（如倍率写 `"1.0"`），否则 `check`、整包出包与补丁导出均会拦截。

## 交接板

- 下一步：无新增
- 用户试玩说明：无（内部出包与补丁空壳校验加固）

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- `python3 03_再刷重制_Godot/07_开发环境/测试发行空壳.py`（3 项全过）
- `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`（49 个脚本，360 个函数通过）
- `python3 03_再刷重制_Godot/07_开发环境/测试发行出包.py`（14 项全过）
- `python3 03_再刷重制_Godot/07_开发环境/测试导出过滤.py`（通过）
- `python3 03_再刷重制_Godot/07_开发环境/工具回归.py`（18 项全过）
- `python3 03_再刷重制_Godot/07_开发环境/交付自检.py`（通过）

## 本分支提交

- e66ed6da8 发行空壳：出包与补丁共用数值默认 0 检查并补回归测试
