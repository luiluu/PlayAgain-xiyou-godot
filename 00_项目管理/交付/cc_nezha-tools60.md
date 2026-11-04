# 交付：cc/nezha-tools60

- 车道／工作者：D 工具／哪吒（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·哪吒·未经审查】修审查 37 三条 P2＋一条 P3：云端基准只认 affected／full、手补代码的收尾提交不当基准、云端 plan 不再每次整轮（dev.待定）

只改 `07_开发环境`、`.gitignore`，不碰 Godot 工程。次序 P2-2 → P2-3 → P2-1 → P3。

- **P2-2 scenes 结果不算已验证**：`云端选测.py` 新增 `verifying_results()`，`cloud_passed_base` 与 `local_verified_base` 只取 `refs/ci/results/<提交>/{affected,full}`，`scenes`（只重跑几个场景）不再让未验提交当基准。
- **P2-3 手补代码的收尾提交不当基准**：`local_verified_base` 对带「验证: 选测」尾注的收尾提交，比较它与第一父（合并提交）的差异，只有版本号（开发编号.json、project.godot、build_info.json）、`00_项目管理/` 与 `00_设计/` 下 .md／.json、.uid 才认；带代码（如 67dce91f 手补 power.gd）则该提交不当基准，改取它的第一父（合并提交），手补的改动留在 基准→HEAD 差异里被再选测。`合并车道.py` 同时在收尾尾注写 `手补: 文件…`（`release_only_path` 与云端口径一致），后来人一眼能看到。
- **P2-1 云端 plan 不再每次整轮**：`cmd_plan` 改 `selector.select(ROOT, base, head=sha)`（只算已提交差异，`changed_files` 不再并入未跟踪文件），`.gitignore` 加 `.ci-timings/`。原来云端恢复的 `.ci-timings/timings.json` 是未跟踪文件，落到 `*` 规则，ci/main 自 11-02 起每次都是 full。
- **P3 全量 finish 的尾注**：`合并车道.py` 不加 `--affected` 的 `--finish` 现在写 `验证: 全量`（原来该分支永远走不到）；`local_verified_base` 认它（全量覆盖整棵树，含手补）。
- **回退**：`XIYOU_CI_BASE=cloud` 仍只认云端通过的提交（tools58 的开关）；.gitignore／head 两条无开关，直接 revert。
- **测试**：`测试云端准备.py` 加 `test_scenes_result_does_not_verify_a_commit`（审查的临时复现改成正式例）、`test_finish_commit_with_hand_patched_code_falls_back_to_merge_commit`、`test_plan_selection_ignores_untracked_files`，并把 tools58 的链例改成文档类收尾提交；`测试合并工具.py` 改全量尾注例、加 `手补:` 例与 `release_only_path` 对口径例。

## 修好后 main 的选测实际是什么样（本机用真仓库算，没有真推云端）

- 当前基准：`verified_base_info` 返回 11205986（合并 cc/wukong-tail3，云端通过的祖先）；HEAD 相对它选 0／386 个场景（只有工具文档改动）。
- **选测 vs 全量差距**：之前 ci/main 每次 full＝386 个场景、约 140～155 分钟额度；现在按差异选。以 rules4 那批窗口（基准 51fb315f^1 → 67dce91f）为例：选 **214／386** 个场景，非整轮。
- **rules4 那种 power_panel 漏选在新选法下能否选到：能**，且有两层保险：①基准不再把手补了 `power.gd` 的收尾提交当已验证，power.gd 的改动留在差异里，`refs` 找到引用 XPower 的测试，`xiyou_status_power_panel` 被选中；我另用「去掉 battle 组点名和 escapes」的旧表算同一窗口，它仍被选中（因为差异里有 power.gd）。②tools59 的 `escapes` 与 rules5 的点名再兜 state_effects.gd 本身的改动。
- **没做的**：任务里说"真推一次车道分支看 plan.json"。真推会在公开仓库触发完整云端选测（按上面数字至少几十分钟额度），我没有擅自推；用 `选测.py` 在真仓库上复算了 plan 里调用的同一函数（带 head、`.ci-timings` 忽略），结果如上。需要真推的话，总装一句话我就推 `ci/nezha-tools60` 并读 plan.json。

## 交接板

- 下一步：合并后第一次云端选测看 plan.json 的 mode 是 affected 而不是 full。
- 用户试玩说明：无（工具改动）
- 需要用户决定：无

## 进度账

- 无（工具类）

## 可优化（流程／工具／效率）

- 已做：见上。
- 说明：旧尾注"基准 --cloud"（11-02 的 8 条）仍解析不了会断链，不影响近期。

## 本分支提交

（见 git log）

## 验证

- 工具测试：`测试云端准备.py` 24 个全过；`测试合并工具.py` 251 个全过；`测试选测.py` 没改选测.py（上一条已跑 108 个）。没碰 Godot，不跑 Godot。
