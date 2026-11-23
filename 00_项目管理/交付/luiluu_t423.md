# 交付：luiluu/t423

- 车道／工作者：T423 出包检查加一条：发行包存档签名必须生效／小A（Hydrogen＋high，P7）
- 状态：可合并

## 做了什么

按 D264、T422 排查建议及协调批复（选 B＋新开关口径），在发行入口冒烟和出包后检查两侧落齐「发行包存档封存生效＋导出 v2」断言，防误传 `--no-save-key` 或导出过滤变动导致静默导明文；全程不碰密钥内容，也不在日志、报错或交付文字里输出密钥内容与位置。

1. **游戏入口只读状态探针**：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/entry.gd`
   - 新增静态函数 `save_seal_report()` 与 `_report_entry_state()`，合并 `_title()` 与 `_tq_build_title()` 处原有的 `--report-entry` 打印。
   - 仅在命令行带 `--report-entry` 时只读打印两行状态（不写盘、不改流程、不触碰或输出密钥内容与位置）：
     - `SAVE_SEAL_ACTIVE=true|false`（校验 `XSaveSeal.active_now()` 为真且内存 `seal("{}")`／`unseal` 闭环通过）
     - `SAVE_EXPORT_FORMAT=kyo-remake-save-sealed-v2|kyo-remake-save-json-v1`
2. **发行入口冒烟运行时断言**：`03_再刷重制_Godot/07_开发环境/发行入口冒烟.py`
   - `run_entry()` 起发行包时补 `--audio-driver Dummy`，并调用 `check_save_seal_output()` 断言 `SAVE_SEAL_ACTIVE=true` 与 `SAVE_EXPORT_FORMAT=kyo-remake-save-sealed-v2`（缺失或不符即失败，给出指向 `--no-save-key`／导出过滤／`--allow-unsealed` 的人话提示）。
   - **新开关与口径**：
     - 校验现成发行包（`--zip`／`--win-dir`／`--apk`，含 `发行出包.py` 的四路冒烟）默认强制开启封存断言；
     - 独立自导出冒烟（不带现成包，如 `检查.sh --release-keys`）默认只打 `INFO` 不阻断，需强制时可加 `--require-save-seal`；
     - 新增 `--allow-unsealed`：显式允许本地测试用未封存包跳过封存断言，打印醒目大字警告「此包不能发给玩家」，且与 `--require-save-seal` 互斥（同传退出 2）。
3. **出包后包内兜底检查与 `--allow-unsealed` 门禁**：`03_再刷重制_Godot/07_开发环境/发行出包.py`
   - 新增 `verify_save_seal_artifacts()` 接在 `audit_unreleased()` 之后（即便传 `--no-smoke` 也会执行）：核对源工程 `XSaveSeal.ENABLED` 为真、`XSaveTransfer.FORMAT_SEALED` 为 `kyo-remake-save-sealed-v2`，并直接检查各平台已导出产物（macOS `.zip` 内 `.pck`、Windows `.pck`、安卓 `.apk`）均含格式合格的封存配置及带 `kyo-remake-save-sealed-v2` 的存档导出模块；不读外部原件，报错不输出密钥内容与位置。
   - **新开关与口径**：
     - 单传 `--no-save-key` 而未传 `--allow-unsealed` 时，入口与出包后检查均默认拦下并退出 1，给出人话提示；
     - 确需出本地测试用明文包时须同时加 `--no-save-key --allow-unsealed`：入口、出包后检查、结束汇总与 `冒烟.md` 均打印大字警告「此包不能发给玩家」，`smoke_all()` 同步透传 `--allow-unsealed`，且**保留旧发行目录不删**（防止本地测试包顶掉玩家可用旧包）。
4. **对应测试**：
   - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_entry_release.gd`：新增 `save_seal_report_active_v2`、`save_seal_report_unsealed_v1`（覆盖封存有效与发行模板缺配置两态）。
   - `03_再刷重制_Godot/07_开发环境/测试发行入口冒烟.py`：新增 `SaveSealSmokeTests` 6 项（v2 通过＋确认传 `--audio-driver Dummy`、v1／false 失败提示、缺失状态行失败、独立自导出默认放行、`--allow-unsealed` 打「此包不能发给玩家」警告、命令行参数与互斥）。
   - `03_再刷重制_Godot/07_开发环境/测试发行出包.py`：新增 `SaveSealPostCheckTests` 8 项（三平台产物通过、误传 `--no-save-key` 默认拦下、格式不合格不泄漏密钥字样、缺 v2 或总开关关闭拦下、`--allow-unsealed` 大字警告与透传、不删旧发行目录）。

## 验证结果

- **Godot 专项测试（本机无头 `--audio-driver Dummy`）**：
  - `res://tests/xiyou_entry_release.tscn`：18/18 通过
  - `res://tests/xiyou_save_seal.tscn`：127/127 通过
- **Python 工具测试（本机前台单跑）**：
  - `python3 03_再刷重制_Godot/07_开发环境/测试发行入口冒烟.py -v`：21/21 通过
  - `python3 03_再刷重制_Godot/07_开发环境/测试发行出包.py -v`：31/31 通过
  - `python3 03_再刷重制_Godot/07_开发环境/测试导出过滤.py`：通过（退出码 0）
  - `python3 03_再刷重制_Godot/07_开发环境/测试Windows实机冒烟.py`：通过（退出码 0）
  - `python3 03_再刷重制_Godot/07_开发环境/测试安卓实机冒烟.py`：18/18 通过
- **发行空壳检查**：
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：退出码 0（81 个脚本，782 个函数都有）
- **云端选测**（提交 `35bb9fbd0e`，分支 `ci/luiluu/t423`，基准 `fdb8a88c6b2f8451d2a716b57f9ca64fbcaffb1e`）：
  - 18 个场景、3 片，最长一片 4.0 分钟，全部通过：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45196072641

## 变更记录草稿

### 2026-11-23 【小A·未经审查】出包检查加一条：发行包存档封存生效与 v2 导出断言（dev.待定）

- **改动**：按 D264 与 T422 建议，在 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/entry.gd` 的 `--report-entry` 处新增只读状态输出 `SAVE_SEAL_ACTIVE=` 与 `SAVE_EXPORT_FORMAT=`；`03_再刷重制_Godot/07_开发环境/发行入口冒烟.py` 校验现成发行包时默认断言封存生效且导出 `kyo-remake-save-sealed-v2`；`03_再刷重制_Godot/07_开发环境/发行出包.py` 新增出包后包内兜底检查 `verify_save_seal_artifacts()`，误传 `--no-save-key` 默认拦下，确需本地测试明文包须显式加 `--allow-unsealed`（大字警告「此包不能发给玩家」且不删旧发行目录）。全程不触碰、不记录密钥内容与位置。
- **验证**：`xiyou_entry_release` 18/18、`xiyou_save_seal` 127/127、`测试发行入口冒烟.py` 21/21、`测试发行出包.py` 31/31、`发行空壳.py check` 0、云端选测 18 场景 3 片全过（run `45196072641`）。
- **玩家可见**：无（只改出包检查、冒烟探针与测试）。

## 交接板

- 下一步：
  - 后续正式出包按常运行 `发行出包.py`，会自动同时走包内兜底与四路冒烟运行时断言；若本地调试确需出明文包，须显式传 `--no-save-key --allow-unsealed`。
- 用户试玩说明：无（只改出包检查与冒烟探针）。
- 需要用户决定：无。

## 进度账

- 发行出包质量门禁：补齐发行包存档封存生效与 `kyo-remake-save-sealed-v2` 导出格式双重断言（出包后包内兜底＋入口冒烟运行时校验）及 `--allow-unsealed` 本地测试保护口径。

## 可优化（流程／工具／效率）

- 无。

## 动了的共用函数和开关

无（未改动 `core/`、`battle/`、`skin/` 下已有函数或玩法开关；`modes/xiyou/entry.gd` 仅在现有 `--report-entry` 冒烟分支追加两条只读 `print`）。

## 本分支提交

- `35bb9fbd0` T423 发行包存档封存生效与 v2 导出断言（入口冒烟探针＋出包后兜底检查＋--allow-unsealed）
- 本提交：补充 T423 交付单（`00_项目管理/交付/luiluu_t423.md`）
