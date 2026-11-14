# 交付：cc/tianqi-check-mode

- 车道／工作者：工具（丙档）／cc（检查模式），Orca 工作树 `~/orca/workspaces/再刷项目资料库/tianqi-check-mode`
- 状态：进行中

## 环境

- 开工时 Orca Setup 已补齐：`01_Godot工程/modes/xiyou/generated/` 有，约 1.5 GB（派单写的 `01_Godot工程/generated` 路径不存在，产物实际在 `modes/xiyou/generated`）；`01_Godot工程/.godot/` 有，约 462 MB；`当前Godot.app`、`冻结正式源/app.nw` 链接都在（指向主工作区，主工作区 `app.nw → v0.62.12/app.nw`）。没有再跑 `新建工作树.sh --补齐`。

## 变更记录草稿

## 2026-11-14 【cc·检查模式·未经审查】工具：天启篇检查模式（合并不自动同步、检查不默认 --oracle），车道前缀与核查者认 gpt／小A（dev.待定）

- **自动触发盘点**（先 rg 再改）：仓库里没有调用 `同步正式西游.py` 的 launchd、cron 或 GitHub 工作流（`.github/workflows` 三个都不调用；本机 `~/Library/LaunchAgents` 也没有相关项，crontab 空）。`检查.sh` 本身不调用同步。真正自动触发的只有两处：`合并车道.py` 在车道改了切片、`xiyou_export.py`、`mv_oracle/*.cjs` 或带测量接受单（refresh）时，合并后自动跑 `同步正式西游.py --accept-additions`；以及收尾检查一律带 `--oracle`。另有两处提示：`检查.sh` 的「选测选中了同源检查，但没加 --oracle」，`交付自检.py` 要求这类车道交同步指纹和接受单（算问题、挡可合并）。
- **天启篇默认模式**（Kyo 11-14 停更，正式源永久定在 `冻结正式源/v0.62.12`）：
  1. `合并车道.py`：新增 `check_cmd()`，收尾检查（单条 `--finish` 与 `--close-batch`）默认不带 `--oracle`，只有本批有 refresh 车道时才带（产物会变，要核同源）；新增 `merge_sync_mode()`，refresh 车道合并后**停在同步前**，报错提示总装二选一：`XIYOU_MERGE_SYNC=1` 重跑同一命令（照旧同步），或 `XIYOU_MERGE_SYNC=skip`（不动产物接着合）；放弃仍是 `--abort`。
  2. `检查.sh`：去掉「同源检查没加 --oracle」提示（只在 `XIYOU_LEGACY_SYNC=1` 时打印）；文件头写明天启篇默认模式。`--oracle` 仍非默认，原版对照探针与专项照旧在选测里，没删测试。
  3. `交付自检.py`：refresh 车道的同步指纹、指纹过期、接受单检查降为提示，另加一句「合并会停在同步前、由总装定」；分道说明改成「天启篇默认合并停在同步前，等总装定 XIYOU_MERGE_SYNC=1／skip」。
  4. `同步正式西游.py` 没改，照旧可以手动跑。`07_开发环境/README.md` 加了一段说明。
- **回退**：`XIYOU_LEGACY_SYNC=1` 整个回到重制期旧路径（合并自动同步、收尾检查一律 `--oracle`、同源漏 `--oracle` 时提醒、自检把同步指纹算问题）；只想让合并检查带 `--oracle`，设 `XIYOU_MERGE_ORACLE=1`。
- **顺手修**：`回退开关覆盖.py` 的「最后改它的车道」只认 `合并 cc|claude|codex/`，加上 `gpt`、`xa`、`luiluu`（Orca 工作树分支，如 `luiluu/Antigravity`）。同类问题还有 `待核查.py`：分支名 `BRANCH`、合并标题 `MERGE` 的正则同样只认旧前缀，`xa/`、`gpt/` 车道的提交、合并、收尾分不进同一批，核查条目里写的 `xa/<任务>` 也销不了账；`REVIEW` 只认【Claude｜cc｜Codex】，gpt、小A 写的核查条目不算数。一起改了：前缀统一用 `LANE_PREFIX`，【gpt】【小A】的核查算跨模型「审查」，可以销「核查: 待审查」。
- **清理影响盘点**（小A 11-14 清了 `冻结正式源/v0.28`、`04_验证/本地结果/`、`.git/tangseng*`、`mv_oracle/.sandbox` 内容）：没有工具会因此直接失败。`v0.28` 只在注释、测试替身和版本表里出现，不读路径；`本地结果/` 下的输出目录、锁文件、同步基线都是用到时 `mkdir`；`.git/tangseng` 只在一处 docstring 提到。两个守卫（`mv_oracle/guard_check.cjs` 16/16、`ui_reference/guard_check.py` 12/12）在本树跑过，通过。有一处后果（不算故障）见下面「交接板」节。
- **验证**：`测试合并工具.py` 新增 4 例（check_cmd 开关、merge_sync_mode 开关、切片车道默认停下后 skip 接着合、旧路径恢复 `--oracle`），既有同步用例在 setUp 里点名 `XIYOU_MERGE_SYNC=1`，6 处「收尾检查参数」断言改成新默认（不带 `--oracle`）；改动后跑过的 15 例全过。`测试交付自检.py` 30/30（新增 1 例；两例旧规矩用例点名 `XIYOU_LEGACY_SYNC=1`）。`测试选测.py CheckerTests` 中同源提示用例改成两种模式各测一遍，通过。`测试回退开关覆盖.py` 14/14、`测试记录工具.py` 17/17（各新增 1 例；正则退回旧版时新例确实失败）。`工具回归.py` 全部通过。选测 `检查.sh --affected 915666793 --cloud`：待写。
- 执行者：cc（检查模式）；核查：丙档只看结论与自检输出。

## 交接板

- 下一步：无（本车道只改工具）。
- 需要总装／Kyo 处理（仓库外或要改规则，本车道没动）：
  1. 主工作区 `mv_oracle/.sandbox/` 已被清空（11-14 清理），探针增量缓存 `incremental-cache.json`、运行依赖记录 `probe_deps/` 和种子存档都没了：以后手动跑 `同步正式西游.py` 会整份重量全部探针（以前算过要几小时、占满槽）；`事件增量比对.py` 不加 `--trust-current` 会退出 3。天启篇不常同步，暂时不用补；真要同步时排在夜里。
  2. 规则文档（`车道须知.md`「交付」节、`多会话并行.md`）里「慢车道交付前在本树跑同步、合并时 main 跑同步」的写法和新默认不一致，请总装或小A 照本单改成「合并停在同步前、总装定 XIYOU_MERGE_SYNC」。
  3. `待合.py` 看板里那句「慢车道另起一批（队尾或夜里，合并要同步）」没改（有测试按原文断言），总装觉得要改再派。
- 用户试玩说明：无，玩家看不到变化。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 已做：合并检查只在必要时带 `--oracle`，省掉每次合并的参照引擎启动（回退 `XIYOU_LEGACY_SYNC=1` 或 `XIYOU_MERGE_ORACLE=1`）。
- 建议：天启篇车道基本不再动切片、转换器、探针，`选测对照.json` 里同步相关的工具测试（`测试增量同步.py`、`测试角色同步提速.py`、`测试事件探针分段.py`）可以考虑移出必跑项，只在改到同步脚本时选测；可以省几十秒到几分钟，归工具车道。没删测试。

## 本分支提交

- b05a6733c 检查模式：天启篇默认合并不自动同步、检查不默认 --oracle，XIYOU_LEGACY_SYNC=1 回旧路径
- 34552dc4f 回退开关覆盖、待核查：认 gpt/、xa/、luiluu/ 车道合并，gpt、小A 核查条目销待审查
- 开发环境 README：天启篇检查模式与回退开关
