# 转换工具

【Claude·未经Codex检验】｜2026-10-12

只读取正式西游应用（v0.04）与固定来源，输出写入独立目录；不能覆盖原版、旧 MOD 或真实存档。每次转换记录输入 SHA、工具版本、输出清单、无法处理项与实际验证结果。

## mv_oracle：MV 参照引擎

无画面加载正式西游 `app.nw` 的完整 MV 引擎、165 个启用插件与全部 Codex 运行模块（Node + jsdom），作为 Godot 重写的「标准答案」：同一输入分别交给 MV 与 Godot 计算，逐项比对伤害、状态、掉落等结果。

- `hboot.cjs`：复制自 Louis 工程 `strength-recheck-20261010-210743/sim/hboot.cjs`（源 SHA256 `de6f861e…cbaf5b0`），新增文件系统守卫——写入只限 `.sandbox/`，屏蔽 Application Support、作者钥匙与真实存档路径。插件在加载数据库时会写自身缓存（如 `RpgJiban*.rpgsave`），一律落在沙盒内，不是玩家存档。
- `boot_check.cjs`：启动检查。2026-10-12 实测 3 秒加载 242 个脚本、数据库就绪、165 插件、模块失败 0、版本 v0.04。
- 依赖：`npm install`（jsdom 24.1.3、lz-string 1.5.0；`node_modules/` 与 `.sandbox/` 不入 Git）。

注意：正式版脚本文件名含形近的非拉丁字符（如 `rpg_managеrs.js` 中的西里尔字母 е），匹配文件名时不能手打。
