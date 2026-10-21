# 交付：claude/bajie-44

- 车道／工作者：C 规则＋工具／八戒（Claude，八戒_41 做到 WIP，额度中断；八戒_43 接手验收）
- 状态：可合并

## 变更记录草稿

## 2026-10-22 【Claude·八戒·未经Codex检验】导入再生乘 REC、待核查销账范围、同步探针走共用并发槽（dev.待定）

- 做了什么（交接板下一步 0b、0c，沙僧_39 晚间批 P2 两条＋唐僧_12 负载问题）：
  - **导入 DOT／再生乘 REC**：`battle_logic.gd` `_regenerate` 的 full 与「去掉导入负 HRG 后的 other」都按原版先乘目标 REC 再 floor，之后才把导入部分 ×0.01（`installImportedBalanceRuntime.js:496／506`）。other 不用「hrg 减导入部分」算：照原版把导入角色附加状态的负 hrg 特性换成 0、按特性对象原顺序重新求和（相减有浮点误差，floor 后差 1）。`imported_balance_probe` 加 REC≠1 与混合来源再生新例，Godot 按 setup.states 重放。
  - **待核查.py 销账范围**：只认核查条目的标题与「核查覆盖／范围／核查」等销账范围行里的 dev 编号，验证、证据行提到的编号不再误销同号批；加沙僧复现回归（`测试记录工具.py`）。
  - **同步探针占共用槽**：`同步正式西游.py` 每个 node 探针先在 `并行测试.py` 的跨工作树共用槽（`CHECK_GLOBAL_JOBS`，默认核数一半、最多 6）占位再跑，几条车道同时同步加测试合计不超上限；`SYNC_JOBS` 只管本次同步最多排几个探针。`并行测试.py` 抽出 `global_limit()` 两边共用。回归 `test_sync_probes_share_global_slots`：两个假同步（6 个线程跑 node 假探针）加一轮假测试，上限 1 时从不重叠。
  - **接手时修的两处**（八戒_43）：① `run_node` 懒加载 `并行测试.py` 时几个探针线程同时首次调用，会拿到还没执行完的模块（报 `no attribute 'global_slot'`），改为加锁、执行完才公开；② 增量同步用例把 `subprocess.run` 换成假探针，`state_dir` 里的 git 也拿到假输出（"same\nsame"、空串），在当前目录建出 `same\nsame/xiyou_test_state`、`xiyou_test_state` 垃圾目录：`state_dir` 只信绝对路径（否则退回临时目录），这些用例另指定临时状态目录。垃圾目录已删。
- 验证：合 main 后在工作树跑 `同步正式西游.py --accept-additions`（41 个探针全复用、测量不变，留指纹）；专项 `xiyou_imported_balance` 273/273、`xiyou_shield` 565/565、`xiyou_state_effects` 42/42；`测试合并工具.py`（含增量同步）120/120、`测试记录工具.py`、`测试角色同步提速.py` 通过，在空目录里跑完不留文件。未跑全量（按车道规则由总装合并后统一跑）。

## 交接板

- 下一步：删掉 0b、0c 两条（0c 的双持说明已关闭）。
- 用户试玩说明：导入角色（141、142 等）附加的持续伤害遇到目标再生效果倍率（REC）不为 1 时，掉血数与原版一致。
- 需要用户决定：无

## 进度账

- 无（共性规则修正与工具，不另计）

## 本分支提交

- 318a0b8 导入 DOT／再生乘 REC，imported_balance_probe 加 REC≠1 新例与 Godot 重放
- 292fb24 待核查.py 只认核查条目的销账范围行
- fe0373f 再生 DOT 按特性对象原顺序重求和、同步探针占跨工作树共用槽与回归（八戒_41 现场）
- 13e7777 共用槽模块加锁加载、state_dir 只信绝对路径、用例指定临时状态目录（修 cwd 垃圾目录）
