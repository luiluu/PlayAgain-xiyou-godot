# 交付：codex/converter-write-changed

- 车道／工作者：框架工具／沙僧（Codex，重制_沙僧_17；接续重制_沙僧_14～16）
- 状态：可合并
- 完成交付：沙僧_17 接续 155702a 的干净现场，等待原最终全检至 done／0，没有重复启动或重跑已通过基准。交付前已重读主线 AGENTS.md 与交付 README；main bd3c52b 之后至 bf42625 只更新编号、归并与车道登记，按一轮验收规则不追合重验。
- 接手点：从 main 84aa727 独立开工。真实切片字节与 SIGKILL 恢复通过。证据与实测脚本保存在本工作树 `03_再刷重制_Godot/04_验证/本地结果/转换器写入/`（不入 Git）。
- 已完成长任务：旧版基准 `/tmp/converter-main-benchmark.log`（等待工具确认 done／0）、补齐 `/tmp/converter-write-changed-prepare.log`、真实字节／中断 `/tmp/converter-real-acceptance.log`、隔离候选导入测时 `/tmp/converter-candidate-benchmark.log`。旧版预热及无改动同步均测量不变，后者 32/32 CACHE_HIT。
- 最终全检：`/tmp/converter-post-main-check.log` 已由等待工具确认 done／0（runId `2c5cbd976d1e47e7885cb92d33d2715d`）；84 个 Godot 场景、工具回归与来源核验全部通过。本地证据另存为 `检查-oracle-post-main.log`、`check-summary-post-main.json`，首轮证据保持原样。
- 验收起点：8415be0 合 main f0b0b7a 后的首轮 `/tmp/converter-write-changed-check.log` 已由等待工具确认 done／0（84 个 Godot 场景、合并工具联跑 101 项含最新增量同步回归、公式 10 项、转换器写入 8 项全部通过，无偶发重跑）；证据目录保留 `检查-oracle.log` 与 `check-summary.json`。`/tmp/converter-branch-benchmark.log` 亦 done／0，严格首跑只清本工作树五个可再生子树与 slice／manifest，oracle、同步指纹及探针缓存保留。
- 最新主线补验：50408d2 新合入 `actor_passive_probe.cjs`、同步 PROBES 新入口，以及 dungeon／mv_script 的当前存档随机流修复。`/tmp/converter-post-main-prepare.log` 与 `/tmp/converter-post-main-sync.log` 已由等待工具确认 done／0；补齐刷新主线参照后，同步只执行 actor_passive_probe（200 用例无错误，26.840 秒），其余 32 个 CACHE_HIT；55.730 秒结束，测量不变（无需额外接受），来源核验通过。1,439 个正常产物逐字节不变，mtime／inode 与 .import 均保留。`/tmp/converter-post-main-unchanged.log` 亦 done／0：25.013 秒、33/33 CACHE_HIT、执行与分片均 0、测量不变、来源通过；正常产物字节／mtime／inode／.import 再次不变。

## 变更记录草稿

## 2026-10-20 【Codex·沙僧·未经Claude检验】转换器只写发生变化的文件

- 实现：JSON 先收集最终版本，避免技能／物品／装备表的中间版本触发写入；所有文件按字节比较，只对变化使用同目录临时文件＋os.replace，素材保留 copy2 原有元数据语义；成功后清理五个自有子树的旧文件、对应 .import 与空目录。oracle 与同步指纹保留，TOOL_VERSION 仍为 19。拒绝产物父目录符号链接，避免写入／清理落入正式源或 oracle。
- 验证：8 个写入回归通过；已有测试增量同步 39/39、测试合并工具 93/93 通过。真实切片：无改动 1439 个文件与旧版空目录全量逐字节一致，写入 0、删除 0，全部修改时间／inode 不变、.import 保留；移除最后一张地图后与旧版全量一致，删除地图与退出引用的素材及两者 .import（4 文件）；加回地图后再次一致。SIGKILL 停在 System.json 的 os.replace 之前，旧目标保持完整，重跑清除残留临时文件且与旧版全量一致。证据 `real-acceptance.json`、脚本 `实测字节与中断.py` 位于上述本地结果目录。
- 本工作树最终验收：1,439 个产物与旧版基准逐字节一致，oracle 字节不变；无改动转换写入 0、删除 0、未变 1,439。正式 `同步正式西游.py --accept-additions` 32/32 CACHE_HIT（执行 0、分片 0），测量不变、来源验证 0 问题；报告与摘要保存在上述证据目录的 `branch-sync-unchanged-report.json`、`branch-sync-unchanged-probes.log`、`branch-acceptance.json`。
- 耗时对比（秒，同一工作树、各一轮；两轮有并行负载差异，不能把全部差值归因于实现）：

| 操作 | main 旧版 | 本分支 |
| --- | ---: | ---: |
| 转换首跑 | 8.269 | 5.802 |
| 紧接首跑的导入 | 36.345 | 30.264 |
| 无改动转换 | 8.292 | 5.061 |
| 紧接无改动转换的导入 | 38.616 | 2.696 |
| 预热后无改动同步 | 52.175 | 27.374 |

- 旧版首次 32 探针预热 1968.129 秒，不计入无改动同步对比；两版无改动同步均测量不变且 32/32 CACHE_HIT。隔离候选初测记录仍保留（首跑／无改动转换 15.602／12.208、导入 78.904／7.339），正式对比使用上表。原始日志及 `main-timing.json`／`branch-timing.json` 都在证据目录。
- 首轮全量验证：`检查.sh --oracle` 全部通过，84 个 Godot 场景无偶发重跑，合并工具联跑 101/101（包含更新后的增量同步回归）、结构化公式 10/10、转换器写入 8/8，来源与六难度参照同源；日志 `/tmp/converter-write-changed-check.log`，本地副本及摘要在证据目录。该轮对应 f0b0b7a 基准。
- 新主线补验（沙僧_16）：补齐与 `同步正式西游.py --accept-additions` 均 done／0，新增探针已实跑通过、其余 32 项复用；55.730 秒、测量不变、正常产物字节及元数据不变，详见顶部补验状态与 `post-main-additions-acceptance.json`。
- 新主线无改动同步：25.013 秒、33/33 CACHE_HIT，测量不变，1,439 个正常产物字节、mtime／inode 与 .import 不变；`post-main-unchanged-report.json`／`post-main-unchanged-acceptance.json` 保存证据。
- 新主线最终全检：`检查.sh --oracle` done／0，84 个 Godot 场景全部通过；十六层副本 `xiyou_floor16_dungeon` 并行时失败、按现行工具单独重跑后 25/25 通过，记一次偶发。`xiyou_rules`／`xiyou_rules_b` 分别 351／341 秒，超过现行 600 秒上限的一半，建议唐僧另排拆分。合并工具联跑 101/101、结构化公式 10/10、转换器写入 8/8、共性工具 21/21、云端导入保护 3/3 均通过；MV／界面访问守卫与来源核验通过，当前西游来源、转换产物及六难度参照同源，无基线外内容覆盖问题。日志和摘要见顶部最终全检证据。
- 已知维护事项：上述慢场景与副本偶发交唐僧另排；本分支所有超时、断言和阈值（含 TASK_IDLE_TIMEOUT）保持，测试未跳过。转换器仍须由 Claude 独立核查，自测不替代交叉核查。

## 交接板

- 下一步：唐僧合并本分支并归并本交付单，保留待 Claude 独立核查；转换器交付完成后，沙僧依次用独立分支推进 336 能力值缓存、悟空_24／八戒_30 审查车道核查。main 已完成两条审查车道的合并收尾。最新车道表仍有悟空_25（角色 41～60）与八戒_31（双持装备槽），下一条代码车道空出名额前只做原版只读预检。
- 测试节奏事项：现行 `并行测试.py` 原上限为 600 秒、拆分提示阈值为 300 秒（早已在 bfab2d3／436e1d1 更新，本分支不改）。前次草稿误把 300 秒当上限，已按源文件更正；首轮观察超过 150 秒不足以认定过半。现有慢场景拆分维护由唐僧另排，最终全检若有超半／偶发会据日志另记，本分支只改约定四个文件。
- 用户试玩说明：本轮只改善转换与导入时间，游戏产物内容不变，TOOL_VERSION 保持 19。
- 需要用户决定：无。

## 进度账

- 工具维护，不建议变更游戏完成度。

## 本分支提交

- b1035ed 登记任务范围及验证计划。
- 906b5fb 首批 7 个写入回归；随后补第 8 个 oracle 目录符号链接保护回归。
- ba0df2a 保存真实切片字节与 SIGKILL 验收、候选及旧版基准现场。
- 60f80b4 沙僧_15 接续登记。
- 01465a9 安装增量实现、检查入口一行调用；8 例回归通过。
- 8415be0 合并 main f0b0b7a 的规则与工具更新。
- 62eecb6 记录旧版基准及本工作树验收起点。
- 3615d7d 记录本工作树严格首跑／无改动耗时、32 探针复用与字节验收。
- 50408d2 合并 main bd3c52b 新增角色被动探针及随机流修复，下一会话须补齐产物并补验。

- a583e6a 沙僧_16 接续新增探针补验。
- bbcc0c7 记录新主线补齐与新探针实跑通过。
- 11b19a7 保存 33 项全复用验收并启动本轮全检。
- a731fea 更正草稿的既有时限（600 秒／拆分 300 秒），没有改测试。
- 155702a 保存 33 项补验通过及最终全检现场。
- 8a1aec5 沙僧_17 接续等待原最终全检。

可合并。
