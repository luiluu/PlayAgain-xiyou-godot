# 交付：cc/update-cloud1

- 车道／工作者：自动更新（工具与平台）／cc（update-cloud1）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·update-cloud1·未经审查】自动更新第④批：云端真 Windows 与安卓模拟器上验补丁叠加载入

- 背景：前几批的补丁载入只在 Mac 上用发行模板验过。本批把它接进云端 `export-smoke` 的 `windows-run`（windows-latest，真发行 exe）和 `android-run`（x86_64 模拟器，真 apk）。本分支叠在 `cc/update-install1` 上，合并顺序：spike0 → check1 → release1 → install1 → cloud1。只动工具和流程文件，没改游戏代码。
- 做了什么：
  - `补丁叠加验证.py --make-only --base <底包.pck> --patch-out <目录>`：相对现成的底包做探针补丁（改已有脚本、加带 `class_name` 的新脚本、改数据、改一张贴图），写 `patch.pck`、`active.json`（未确认）、`expect.txt`。原来的做补丁那段抽成 `make_patch`，Mac 上六次运行照过。
  - `Windows实机冒烟.py`：发行目录里有 `_patch` 就多跑四次，每次新的临时 `%APPDATA%`：装上补丁（载入、探针行、进标题、跑起来后登记变已确认）、SHA 不对、文件截断、已连续两次没起来（启动前自动退回并留提示）。
  - `安卓实机冒烟.py`：apk 旁边有 `_patch` 就多跑一次：`adb root` 后把补丁放进应用私有目录 `files/updates`（改属主、`restorecon`），启动，看 logcat 里的载入行、探针行、进标题、进程活着、没有崩溃行，再读回登记确认变成已确认。拿不到 root（真机、Play 镜像）只记 INFO 跳过，真机不碰。
  - `.github/workflows/export-smoke.yml`：Windows、安卓各自导出发行包后做探针补丁，随发行包一起经 Actions 缓存交给后面的任务；探针补丁做不出来只打警告、不挡别的检查。
  - 离线测试：`测试Windows实机冒烟.py` 加 3 项（假 exe 照载入器规则处理登记；五种故意弄坏各自只让对应的检查挂）；`测试安卓实机冒烟.py` 加 1 项（判断函数）。
- 云端实测（`ci-export/update-cloud1`，run 43004891703，跑完已删掉试跑分支）：
  - **真 Windows：7 项补丁检查全过**（`win_patch_loaded`、`win_patch_replaces_script_class_data_image`、`win_patch_enters_title`、`win_patch_confirmed_after_boot`、`win_patch_bad_sha_not_loaded`、`win_patch_truncated_not_loaded`、`win_patch_auto_rollback`）。补丁放在 `%APPDATA%\KYO\再刷重制\updates`。
  - **安卓模拟器（API 34 x86_64）：6 项补丁检查全过**（载入、探针行、进标题、跑起来后已确认、进程活着、没有崩溃行）。补丁放在 `/data/data/<包名>/files/updates`，说明安卓上 `user://` 就是应用私有的 files 目录。
  - 这一轮整体标红，是因为另外 7 项与补丁无关的检查失败：两个平台各 3 项「标题按键开新游戏」停在标题（天启篇开局多了选存档位、难度、阵容，按键序列没跟上）和 `android_pause_hook_fires`。**同样的失败在当天 main 的那一轮（run 42986831172）里就有**；按键序列另有车道在修（`ci-export/cc/platform-release450` 的提交写着在改这个）。不是本分支带来的。
- 验证：`测试Windows实机冒烟.py` 12/12、`测试安卓实机冒烟.py` 全过；`工具回归.py` 全过；`补丁叠加验证.py` 六次运行全过。
- 没验的：真机（第⑤批，先不做）；安卓上只验了载入，没在模拟器里跑下载（下载代码与平台无关，Mac 上测过；安卓的网络权限 apk 里有没有没查，见「交接板」）。
- 待交叉核查：丙档工具；`安卓实机冒烟.py` 里 `adb root` 那段只在模拟器上跑，请看一眼「拿不到 root 就跳过」。

优化登记草稿：无

## 交接板

- 下一步：**查安卓发行包有没有 INTERNET 权限**（导出预设 `permissions/internet`）。没有的话安卓上「检查更新」和补丁下载都连不上网；原来重制版没有联网功能，很可能没开。开它要改 `export_presets.cfg`「安卓 发行」「安卓 验收」，归平台车道，随下一个整包生效。
- 下一步：标题界面接线（PR #29 合并时，见 check1、install1 交付单）；出含载入器的下一个整包后 `发布补丁.py --full-only --min-base <号> --stage` 建清单；第⑤批实机先不做（Kyo／协调 11-11）。
- 用户试玩说明：无（只有工具与云端流程）。
- 需要用户决定：无。

## 进度账

- Windows／安卓扩展账：自动更新 约 80% → 约 88%（真 Windows、安卓模拟器上载入已验；剩标题接线、安卓联网权限、第一次真发版、实机）。

## 可优化（流程／工具／效率）

- 已做：探针补丁做不出来时只警告不挡 `export-smoke` 其它检查（回退：把那一步的 `||` 去掉）。
- 建议：`export-smoke` 现在 main 上本来就红（按键序列、切后台钩子），新问题容易被盖住；等 platform-release450 的修复合并后再看一轮是否转绿（归平台车道）。

## 本分支提交

- （见 git log cc/update-install1..cc/update-cloud1）
