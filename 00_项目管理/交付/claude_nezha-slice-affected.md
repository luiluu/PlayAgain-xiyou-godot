# 交付：claude/nezha-slice-affected

- 车道／工作者：D 检查与合并工具／哪吒（Claude，哪吒_2）
- 状态：可合并（本分支已合 `claude/nezha-merge-speed`，须在它之后合，或一起合）

## 变更记录草稿

## 2026-10-26 【Claude·哪吒·未经Codex检验】选测：切片按顶层键细分、车道基准取分叉点（dev.待定）

起因（用户 2026-10-26 定）：`03_转换工具/*` 整组归 converter，内容车道只往 `xiyou_slice.json` 加地图也要跑 `xiyou_rules` 全部段＋事件对照；悟空_60 通天之上期一只加 5 张图，选测跑 26 个场景、约 50 分钟。

- **切片按顶层键细分**（`选测对照.json` 的 `sliceSections`）：`选测.py` 读基准与新版两份 `xiyou_slice.json`，比较哪些顶层键的值变了（不按 diff 行猜），每个键按下表归组，各组并集；另加引用了该键名（如 `"keepEvents"`）的测试。键不在表里、任一版 JSON 解析失败、顶层不是对象、文件新增或删除：退回 rules 里的整组 converter。只改格式（键值都没变）：不选场景。
- **车道基准取分叉点**（`选测对照.json` 的 `mergeBase`）：基准不是 HEAD 的祖先时（车道跑 `--affected main` 而 main 已前进），改用 `merge-base(基准, HEAD)`，只算本分支的改动；报告里写「基准 main（分叉点 xxxx）」。基准是 HEAD 祖先时（总装批末用批首 base）两者相同，行为不变。`--head` 回放时取 `merge-base(基准, head)`。
- `07_开发环境/README.md` 写明单跑一个场景的命令（`python3 并行测试.py ./godot ../01_Godot工程 --full <场景名>`，隔离 HOME；裸跑 godot 读本机 `options.json` 会误报）。
- 合并 `claude/nezha-merge-speed`：它的 toolRefs、`--head` 读 head 的测试、指纹沿用、静态失败即停全部保留；冲突只在 `选测.py` 文件头说明，两段都留。

验证：`测试选测.py` 38 项全过（新增 9 项）；`检查.sh --affected main` 选测全部通过；悟空切片实测见「验证」。

### 键→场景组

| 顶层键 | 组 | 跑什么 | 依据 |
| --- | --- | --- | --- |
| `maps`、`keepEvents` | slice_map | 事件对照＋`xiyou_floor*`／`xiyou_map*`／`xiyou_flow`＋引用该键的测试（如 `xiyou_floor_run`、`xiyou_lobby_shops` 读 `keepEvents`）；守卫、工具回归、内容覆盖 | `xiyou_export.py collect_slice` 用 `maps` 导出地图本体与素材、`keepEvents` 由地图场景读；`内容覆盖检查.py` 读地图 |
| `troops`、`actors`、`maxLevel`、`extraSkills`、`extraCommonEvents` | converter（照旧） | `xiyou_rules*` 全部段＋事件对照＋引用测试；守卫、工具、内容、同源 | 决定切片敌群／角色／技能，`slice_probe` 据此出 `generated/oracle/slice_d<N>.json`，`xiyou_rules` 逐行对照；`extraCommonEvents` 经物品技能效果调公共事件，还会带出敌群 |
| `extraAnimations`、`weaponScan` | converter（照旧） | 同上 | 只带动画素材，但动画属战斗表现，拿不准按战斗算 |
| `extraImages`、`systemImages`、`fonts`、`extraAudio` | slice_asset | 事件对照＋`ui_smoke`＋`xiyou_panels`＋`xiyou_*_ui`＋`xiyou_mac_export`＋引用该键的测试；守卫、工具回归 | 只往素材名单加文件（`collect_slice` 末尾与字体复制），不影响数据库 |
| `说明`、`keepEvents说明` | docs | 不选场景 | 纯说明文字 |
| 其它（新键） | 退回 converter | 整组 | 宁多跑不漏跑 |

**本期不放松的一路**：新加地图会通过遭遇表与事件（301）带进新敌群，同步后 `slice_probe`／oracle 参照和 `xiyou_rules` 对照行跟着变；这些产物在 gitignore 的 `generated/` 里，改动若落到 `04_验证/测量接受/*` 仍归 converter 整组，同步／测量接受单的规则不变。也就是：只加地图的车道若同步后需要更新测量接受单，那次照旧跑规则全套。

### 回退

- 切片细分：`03_再刷重制_Godot/07_开发环境/选测对照.json` 里 `"sliceSections"` 的 `"enabled"` 改成 `false`，即完全回到整组 converter（回归 `test_switch_off_restores_whole_converter` 覆盖）。
- 分叉点基准：同文件 `"mergeBase"` 改成 `false`，即按基准本身比（回归 `test_lane_ignores_main_progress_unless_switched_off` 覆盖）。

## 交接板

- 下一步：无新增
- 用户试玩说明：无（只改开发工具）
- 需要用户决定：无

## 进度账

- 无（工具）

## 可优化（流程／工具／效率）

- 已做：切片按键细分（回退见上）；车道基准取分叉点（回退见上）。
- 建议：`slice_map` 的楼层专项现在按通配符全跑（约 40 个场景、串行约 28 分钟），可进一步收窄到引用了改动地图编号的测试（如 Map069 → `reach069`）；需先确认楼层测试引用地图编号的写法是否统一，收益约再省 20 分钟／次，归哪吒。

## 本分支提交

- b89b5981 WIP: 选测按切片顶层键细分（未合 nezha-merge-speed）
- d7c8fc74 合并 claude/nezha-merge-speed
- 3d949a41 选测：切片按顶层键细分的回归、分叉点基准回归；README 写单跑场景命令
- （本提交）交付单

## 验证

- `测试选测.py` 38 项全过：新增只加地图、只加敌群、两者都加、只改图像、坏 JSON／未知键／文件删除退回整组、只改格式、开关关闭回整组、`--head` 回放、车道基准取分叉点（含 `mergeBase=false`）。
- `检查.sh --affected main`：13 个改动文件全归 tools／docs，Godot 场景 0 个、非 Godot 检查 guards＋tools，16 项全过，「选测全部通过」。
- **悟空切片实测**：`选测.py 56b6b32f^ --head 56b6b32f`（悟空_59 Map069 现场：切片加 5 张图＋reach069 测试）与 `选测.py ca5b8676^1 --head ca5b8676^2`（通天之上期一整条分支，自动取分叉点 da0eee8c）结论相同：切片归 slice_map（变的键 `keepEvents`、`maps`），不选 `xiyou_rules*`；共 42 个场景＝事件对照＋楼层／地图专项＋`xiyou_flow`＋`xiyou_floor_reach069`（测试本身）。按 `.git/xiyou_test_state/timings.json` 上次耗时串行合计约 1658 秒，原来的 `xiyou_rules*`＋事件对照约 7276 秒。场景数比改前回放的 26 多，但都是短场景，总耗时约降到四分之一。
