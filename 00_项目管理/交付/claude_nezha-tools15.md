# 交付单：claude/nezha-tools15（哪吒_10，工具车道）

- 状态：可合并
- 执行者：Claude（哪吒）；验证：工具回归＋专项，未跑全量，也未对真实云端实跑（云端部分用桩脚本）

## 变更记录草稿

## 2026-10-30 【Claude·哪吒】合并收尾与车道自测的 Godot 选测可改走云端（dev.待定）

- `检查.sh` 加 `--cloud`（须与 `--affected` 同用）：选中的 Godot 场景改调 `云端选测.py run`＋`wait <HEAD> --mode affected`，本机不跑 Godot；非 Godot 检查照旧。推送失败、超时、未通过都判失败并提示去掉 `--cloud` 改本机，不静默降级。环境变量 `XIYOU_CLOUD_SCRIPT`、`CHECK_CLOUD_NO_UPLOAD`、`CHECK_CLOUD_TIMEOUT`。
- `合并车道.py` 的 `--finish` 与 `--close-batch` 加 `--cloud`（须配 `--affected`）：给 `检查.sh` 转 `--cloud`；本批各条都没有切片／参照刷新（`refresh`）时设 `CHECK_CLOUD_NO_UPLOAD=1`，batch.json 条目多记 `refresh`。失败保留现场、不提交收尾、不清理、不推送。
- 文档：`合并提速工具.md`、`云端测试.md` 各加一段用法；规则文字未动。
- 自测：`测试选测.py` 53/53（新增 6：通过、传不传产物、未通过、超时、触发失败、需 `--affected`／无场景不碰云端，均用桩脚本），`测试合并工具.py` 209/209（新增 3）。

## 交接板

- 无需登记。

## 可优化

- 云端只测已提交的 HEAD，合并收尾的提交（交付单删除、编号替换）不在测试内；影响小。
- 未对真实 GitHub Actions 实跑；第一次用 `--cloud` 建议总装挑一条小合并试跑。
