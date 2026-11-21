# 交付：luiluu/t305

- 车道／工作者：T305 皮肤关闭对照基线取 merge-base／cc（Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-21 【cc·T305·未经审查】皮肤关闭对照.py 默认基线改取 merge-base，版本号区域不计入差异（dev.待定）

- 不带 `--base` 时，基线＝HEAD 与 `github/main` 的 merge-base（没有该远程退回本地 `main`），github/main 往前走、本分支还没跟上时不再整批 DIFF；要比最新 main 显式 `--base github/main`。
- 比对加 `--mask-version=宽,高`（`tests/xiyou_ui_skin_offshot.gd` 的 `--compare`）：右下角版本号区域（工具默认 160×28）不计入差异，SAME 行注明「忽略版本号区域」；`皮肤关闭对照.py --no-mask-version` 整图比。
- 回归：本分支无参数跑，88/88 SAME，退出 0。没造「版本号不同」的真实场景（本分支与基线版本号相同），掩码只验了语法与全图相同路径。

## 交接板

- 下一步：无
- 用户试玩说明：无（开发工具）
- 需要用户决定：无

## 进度账

- 无（工具小改）

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 git log（T305）
