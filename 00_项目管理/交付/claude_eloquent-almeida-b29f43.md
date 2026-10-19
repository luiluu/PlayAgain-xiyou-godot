# 交付：claude/eloquent-almeida-b29f43

- 车道／工作者：C 机制（无战斗）／八戒（Claude，重制_八戒_24，Opus，medium）
- 状态：可合并

## 变更记录草稿

## 2026-10-19 【Claude·八戒·未经Codex检验】跨存档变量（dev.待定）

- **正式版机制**（冻结 v0.28 `Drill_VariablesAcrossArchive.js` v1.3＋`Drill_CoreOfGlobalSave.js`；同名的 `Drill_GlobalVariable` 是关着的旧副本）：参数列出变量 900／899／1000／1476 与开关 2281，文件路径 1＝游戏根目录 `save/drill_global.rpgsave`（键 `GVa`）。
  - 写：挂在 `Game_Variables/Game_Switches.setValue` 之后，改的是这几格就记进全局存储并排队写盘（帧刷新每 10 帧写一次）。变量存的是 setValue 收到的**原值**（取整前；`_data` 里是取整后的）；设成 0／false 也存，之后照样盖。不经 setValue、直接写 `_data` 的不会存。
  - 读：`Game_Map.initialize`（新开局 createGameObjects）与 `DataManager.extractSaveContents`（读档）之后，全局存储里有值的格盖掉本局的值；没存过的格不动（读档时保留档里的值）。全局存储整局只在启动时读一次文件，之后一直在内存里。
  - 内容里用到的：三十层 Map146 玉皇大帝「向守层员索要礼物」（变量 878＝1 且变量 14＝1）`setValue(900,1)` 后调 1322；奇异石碑（开关 2302、变量 878）`setValue(899,1)` 后调 1328；Map158 EV1 `setValue(1476,1)`，大厅 Map004 EV54／56／65／68 与 Map132 EV9 读 1476；开局 Map002 EV2 第 3／4 页调 1322、1328（变量 900／899＝1 时全员学 6176／6205）。1000 与开关 2281 只在已关闭的 NGP_Final_Complete 里用，启用内容里没人写。
- **Godot**：新增 `core/xglobal_vars.gd`（`XGlobalVars`），文件 `<存档目录>/global.json`（跟 `XSave.dir()`，即 `user://modes/xiyou/global.json`；测试的 `XSave.dir_override` 临时目录也跟着走），不读写 MV 文件与玩家存档。`XState.set_variable/set_switch` 改到插件列出的格时存原值并立即写盘（先写临时文件再替换）；`XState.new_game`、`new_game_blank`、`from_dict` 末尾 `XGlobalVars.apply` 盖值（直接写字典，不触发写盘）。按路径只读一次文件，相当于正式版的启动时读一次；文件损坏按空处理，下次改值整份重写（正式版 JSON.parse 会在启动时报错停机，属防错，不登记优化）。
- **参照**：新增 `mv_oracle/global_vars_probe.cjs`（已登记进 `同步正式西游.py` 的 PROBES，产物 `generated/oracle/global_vars.json`）：同一进程里改值（含 2.7 原值、不跨存档的 901／2280）、新开局、读「插件生效前」的旧档、新开局后跑 1322／1328、899 设 1 再开局、设回 0、122 加法指令，共 8 步，记变量／开关、全局存储内存值与待写文件内容。无画面引擎不跑帧刷新，所以不写盘；重启读回由 Godot 测试自证。
- **测试**：新增 `xiyou_global_vars`（17 项）：8 步逐项对照参照，另测重启后从文件读回、`XSave` 存读档后仍取全局值、不跨存档的变量不带、损坏文件按空并重写、换存档目录即另一份。
- **未接（交悟空）**：事件脚本 `$gameVariables.setValue(900, 1);`／`setValue(899, 1);`／`setValue(1476, 1);` 现在 `mv_script` 还不认（会进 skipped），所以游戏里目前没有地方会写这几格；开局 1322／1328 已会按全局值学被动。悟空接玉皇大帝礼物／奇异石碑时在 `mv_script` 加 `$gameVariables.setValue(N, 数字)` 的翻译，**必须走 `XState.set_variable`**，不能直接写 `variables` 字典，否则不会存进全局。
- 框架维护约定加一条「跨存档变量」。预分配 O-063 未使用。

## 交接板

- 下一步：删掉「下一步」第 2 条里的「跨存档变量 899／900（要改存档，单独一批）」；悟空接三十层礼物／石碑时补 `mv_script` 的 `$gameVariables.setValue(N, 数字)`（走 `set_variable`），并在楼层流程测试里确认新开局学到 6176／6205。
- 用户试玩说明：暂无玩家可见变化（写入这几格的事件脚本还没翻译）；接通后，在三十层拿到「胜天半子」「代天巡狩」，之后新开局全员自动学会，读旧档也生效。
- 需要用户决定：无。

## 进度账

- 存档／系统：机制补齐一项，不改完成度（玩家可见部分随悟空接事件后再算）。

## 本分支提交

- 9ce980e WIP: 跨存档变量 XGlobalVars、参照探针与回归测试
- 54a38ff 合并 main
- 12c5e11 WIP: 交付单草稿、框架约定一条、测试缺参照时报清楚
- （本提交）跨存档变量交付：同步留指纹、检查全过

## 验证

- worktree 跑 `同步正式西游.py --accept-additions`：只新增 `global_vars.json`，其余测量不变，0 问题（备份 `03_再刷重制_Godot/04_验证/本地结果/自动同步/20261019_163007_v0.28-v0.28/`）。
- `检查.sh` 全部通过（`xiyou_global_vars` 17/17）；只改存档侧、不碰战斗，未加 `--oracle`。

可合并。
