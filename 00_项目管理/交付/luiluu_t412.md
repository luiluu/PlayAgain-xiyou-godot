# 交付：luiluu/t412

- 车道／工作者：漩涡三阶段 rift3（cc，Opus＋medium，P8）→ 交小A 续做
- 状态：进行中（WIP：cc 5h 额度到 91%，项目经理cc 叫停，交小A 续做）

## 做到哪（cc 11-23）

已做、已提交（本地专项 `xiyou_rift3_xufeng` 53/53、`xiyou_rift2_canglong` 改后未重跑整份，见下）：

1. **rift3 过场**（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/rift.gd`）：Map004 新事件 205「时空漩涡_字幕3」、206「时空漩涡_徐凤年3」、207「时空漩涡_异化怪3」，接着 rift2 的 201～204 往后排。
   条件 `RIFT3_CONDITION`：rift2 看过、rift3 没看过、且不是刚播完 rift2 的同一次进大厅（新虚拟键 `rift2@thisvisit`，不跟 CHAIN_AFTER_RIFT1 走）。先 `CodexWhisper.mark('rift3')` 再播，全存档只播一次。开关 `XRift.STAGE3`（默认开，关了不加 205～207、stage() 不到 3）。
2. **Kyo 11-23 过场设定**（项目经理cc 转：隐世强者察觉天地变化，追杀异化怪物从天而降，斩掉后决定跟随，留点四阶段彩蛋）已落在 `rift.gd` 的 `_rift3_event()`：
   变暗 →「??????」一句 → 漩涡闪光 → 异化怪物（原版行走图 Monster 第 6 格，大厅异化层按备注 `<codex_rift_alien_mob>` 染幽紫，`lobby_corruption.gd` `_update_tint`）从漩涡正上方摔到 (14,22) → 白光，徐凤年（7mobu7 第 2 格＝角色 152）追下来落到 (14,21) → 原版斩击动画 23＋重震＋白闪，怪物淡掉 → 徐凤年三句 → 淡出往南 → 小字。不新画。
   台词全在 `XRift.RIFT3_LINES`（草稿，**待小A 文字审**）：whisper「……又有东西，从那头漏过来了。」sense「山里坐了这些年，天地的气一乱，还是坐不住了。」hint（暗示四阶化形）「这东西还只是染了颜色。再往后……怕是连模样都要换了。」follow「你身上有漩涡那头的味道。这一程，我跟你走。」after「兑换大厅里，好像又来了一个人。」
3. **whisper 键 rift3、XRift.stage()==3**：rift3 看过且 STAGE2、STAGE3 开着时 stage() 返回 3（给 T411 `xufeng_gate_met()` 读 `XConfig.whisper_seen("rift3")` 或 `XRift.stage() >= 3`）。`xconfig.gd` 的虚拟键判断改成 `XRift.is_visit_key`。
4. **三阶怪物异化不开**：`rift_alien.gd` 新开关 `XRiftAlien.STAGE3_ALIEN := false`，XRift 给 3 时怪物端按 2 算（西游档怪物与二阶逐值相同）；STAGE_OVERRIDE 不受影响。
5. **测试**：新专项 `tests/xiyou_rift3_xufeng.gd/.tscn`（数据＋真开大厅把过场放完、落地、怪物染色淡掉、再进不重播、stage／开关）。`xiyou_rift2_canglong` 的 keep 断言 205→208。20 个先记 rift2 防过场占大厅的测试（含 `xiyou_test_env.gd`、`xiyou_fest_lobby.gd`、`07_开发环境/造测试档/load_check.gd`）同步记 rift3。
6. 截图：`00_项目管理/交付截图/luiluu_t412/rift3_fall.png`（怪物落地、徐凤年下落时白光）、`rift3_strike.png`（斩击瞬间）。

## 还剩（小A 续做）

- 台词文字审（`XRift.RIFT3_LINES`，5 句）。
- 本地选测：跑 `python3 03_再刷重制_Godot/07_开发环境/选测.py main --list` 列出的场景（至少 `xiyou_rift3_xufeng xiyou_rift2_canglong xiyou_rift_alien xiyou_lobby_corruption xiyou_fest_lobby xiyou_tianqi_hall xiyou_flow xiyou_map_dispatch`），`xiyou_rift2_canglong` 改断言后已跑通过一次（85/85 前一轮只差 keep 一条，改后未单独复跑）。
- `python3 03_再刷重制_Godot/07_开发环境/工具回归.py`、回退开关覆盖检查（新开关 `XRift.STAGE3`、`XRiftAlien.STAGE3_ALIEN` 若要进豁免清单或覆盖测试）、`发行空壳.py check`（rift.gd 是否在发行空壳名单里没查）。
- 写下面三节草稿、状态改「可合并」、提交后跑 `交付自检.py` 到 0、云端选测 `gh run watch` 前台等完写 run 链接。

## 变更记录草稿

待写

## 交接板

- 下一步：T411 把 `xufeng_gate_met()` 接 `XConfig.whisper_seen("rift3")`
- 用户试玩说明：看过苍龙过场后下一次进大厅，播徐凤年从天而降斩异化怪的过场
- 需要用户决定：三阶怪物异化（蚀骨）开不开（`XRiftAlien.STAGE3_ALIEN`，默认关）

## 可优化（流程／工具／效率）

- 建议：rift2 的三页结构可改用新的 `_whisper_pages()`（本单没动 rift2，免得改坏）

## 动了的共用函数和开关

| 函数／开关 | 调用方 | 结论 |
| --- | --- | --- |
| `XRift.stage()` | rift_alien.gd、lobby_corruption.gd | 可返回 3；rift_alien 默认夹到 2；lobby_corruption 只判 ≥2 和存档 maxStage 记录（会记成 3，无别处读） |
| `XRift.this_visit_seen`／`on_mark` | xconfig.gd | 键→进图次数字典，rift1 行为不变（rift2 专项 visit.* 断言覆盖） |
| `XLobbyCorruption._update_tint` | 每帧 | 多染备注为 `<codex_rift_alien_mob>` 的事件 |

## 本分支提交

- 见 `git log main..luiluu/t412`
