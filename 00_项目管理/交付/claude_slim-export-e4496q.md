# 交付：claude/slim-export-e4496q

- 车道／工作者：导出配置（不占内容／界面车道）／Claude（云端讨论串「导出瘦身」）
- 状态：可合并

## 变更记录草稿

## 2026-10-18 【Claude·未经Codex检验】导出瘦身：排除测试与参照数据

- 原因：dev.079 Mac 试导出的 .pck 里带着约 77 MB `generated/oracle` 参照数据（导出设置是 `all_resources`＋`*.json`，排除项为空），另有 `tests/` 全部测试、夹具与基线 JSON、`generated/manifest.json`、`sync_stamp.json`。游戏运行时只读 `generated/` 的 `db/`、`maps/`、`slice.json`、素材与字体（`xdb.gd` 的 `load_json` 全部调用已核对），不读 `oracle/`、`manifest.json`。
- `export_presets.cfg` 加排除项：`generated/oracle/*`、`manifest.json`、`sync_stamp.json`、`builds/*`、`tests/fixtures/*`、`tests/*.json` 与各测试前缀；保留 `tests/xiyou_mac_export.*`（`--verify-export` 在包内跳到这个场景）。Godot 过滤只认 `*`、`?`，所以测试按前缀逐条排除。
- 新增 `07_开发环境/测试导出过滤.py` 并接进 `检查.sh`：tests/ 下除导出验收场景外每个文件都要被排除，参照数据必须被排除，游戏数据不能被排除。
- 验证：云端没有转换产物，用工程副本＋假产物（含 2 MB 假 oracle）以 Godot 4.7.2 `--export-pack "macOS 验收"` 实际导出比较：改前包里有 oracle、manifest、sync_stamp、builds 与 348 个 tests 条目；改后 tests 只剩 xiyou_mac_export，db／maps／slice 仍在。守卫脚本加一个假测试文件时报错、删掉后通过。未在 Mac 上用真实产物重新出包，预计 .pck 从 315 MB 降到约 238 MB，待 Mac 出包时实测并跑一次 `--verify-export`。
- 提交：见下

## 交接板

- 下一步：Mac 上下次出包时记新 .pck 大小，并跑 `--verify-export` 确认导出验收仍 16/16。
- 用户试玩说明：无玩法变化，安装包变小。

## 进度账

- 无变化

## 本分支提交

- 见 PR
