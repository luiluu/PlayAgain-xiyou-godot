# 交付：luiluu/t544-skill-page-lag

- 车道／工作者：T544 安卓技能页卡顿排查（cc，Opus＋medium，P8；只查不改）
- 状态：可合并

## 结论（一句话）

技能页每画一行技能都要算这一行的消耗（MP／TP／HP），算一次消耗要读 4 次左右的能力值（最大 MP、MP 消耗率、最大 TP……），而**每读一次能力值都要把角色的全部技能记录从头重建一遍**（`param_base` → `passive_values` → `skills()`）。所以一行的开销随角色学会的技能总数线性增长，一屏 28 行就是「28 × 4 × 技能数」。被动页最明显，是因为被动最多、一屏总是画满 28 行。战斗里的技能列表早就包了只读窗口（O-348），主菜单技能页没有包。

## 1. 量数（玩家版和 main 都量了）

- 玩家现版本：`channel.json` latest.code＝893（0.04.04）→ 提交 `1667d3cda`（合并 luiluu/t444，dev.893 收尾）。在 scratchpad 用 `git clone --shared` 检出量数（generated／.godot 从本工作树 APFS 克隆，转换产物没按旧提交重跑，写明）。
- main：本分支起点 `dd15d65bb`（dev.937）。
- 环境：Mac（Apple Silicon）无头 Godot，`--audio-driver Dummy`。角色 1，80 级，按固定顺序学 N 个被动（stypeId 4），其余技能是开局自带的。「移动一格」＝`_move` 往下一格（含翻页滚动）＋下一帧（列表窗口重画）。空帧基线约 5 ms。
- **安卓实机没核**：这次没导安卓包实测。手机上跑 GDScript 一般比这台 Mac 慢几倍（我猜 3～5 倍，没量过），所以下表在手机上要再乘几倍。

### 西游档（旧界面，玩家现在用的就是它）

| 学会被动数 | 被动页条目 | 移动一格 main | 其中列表重画 | 移动一格 玩家版 dev.893 | 包只读窗口后列表重画 | 包只读窗口后移动一格 |
| --- | --- | --- | --- | --- | --- | --- |
| 20 | 24 | 129 ms | 117 ms | 125 ms | 45 ms（首测，含冷缓存） | 53 ms |
| 60 | 62 | 231 ms | 211 ms | — | 46 ms | 59 ms |
| 120 | 122 | 351 ms | 319 ms | 330 ms | 20 ms | 40 ms |
| 240 | 240 | 648 ms | 591 ms | — | 22 ms | 58 ms |
| 400 | 396 | 约 1020～1040 ms | 约 925～950 ms | 970 ms | 25 ms | 83 ms |

- 打开技能页本身不慢（`_ready` 约 20～25 ms，首帧 38～193 ms），因为一打开停在「战技」，条目少；**切到「被动」那一下**和**在被动页里每按一下方向键／每翻一屏**才卡：main 上 20 个被动 127 ms、120 个 322 ms、400 个 937 ms。
- 玩家版与 main 的数字在误差内一致 → **不是近期改动引入的回退**（见 5）。

### 天启篇档（新界面皮肤，只在天启篇开线且设置选新界面时）

新皮肤 `XSkinSkillPage.sync()` 每次刷新（每按一下）都把**本类全部条目**重建一遍行数据（不只一屏），所以是「条目数 × 技能总数」的平方增长：

| 学会被动数 | 移动一格（refresh） | 包只读窗口后 sync |
| --- | --- | --- |
| 20 | 87 ms | 3.9 ms |
| 60 | 416 ms | 7.7 ms |
| 120 | 1397 ms | 13.5 ms |

（240、400 档没跑：一次 sync 要好几秒，量数太慢；按上面趋势 400 档会到十几秒一下。）

原始数据：[04_验证/T544_技能页卡顿/](../../03_再刷重制_Godot/04_验证/T544_技能页卡顿/)（每行一个 JSON：`HEAD_旧界面.log`、`玩家版dev893_旧界面.log`、`HEAD_天启篇皮肤.log`、`HEAD_param拆分.log`）。

## 2. 卡在哪（证据）

逐环节拆分（`04_验证/T544_技能页卡顿/t544_skill_lag_probe.gd` 的 split_*、同目录 `t544_skill_lag_micro.gd`）：

| 单次耗时 | 20 被动 | 400 被动 |
| --- | --- | --- |
| `a.skills()` 重建技能表 | 0.59 ms | 7.96 ms |
| `XBattler.param` 里的 `param_base` | 1.19 ms | 15.7 ms |
| 读一次 `a.mmp` | 0.76 ms | 8.9 ms |
| 读一次 `a.mcr`（MP 消耗率） | 0.62 ms | 7.8 ms |
| 读一次 `a.max_tp()` | 0.60 ms | 7.7 ms |
| `logic.skill_cost` 一条技能 | 2.7 ms | 32 ms |
| `_costs` 全部条目一遍 | 65 ms（24 条） | 12.8 s（396 条） |
| 包只读窗口后 `_costs` 全部条目 | 2.2 ms | 19～30 ms |

- 调用链：`skill_scene.gd` `_paint_list`（每个可见行）→ `_costs` → `XBattleLogic.skill_cost` → `_skill_cost` 读 `a.mmp`、`a.mcr`、`a.max_tp()`，下限那一遍再读一次 → `XActor.param` → `XBattler.param` → `XActor.param_base` → `_param_base_core` 里 `passive_values("passivePBST…")`、`passive_values("passivePBSTEX…")` → `_passive_values_now` 遍历 `skills()` → `_skills_now` 每条技能过心钢／云裳／异化／谷雨／屠苏包装，再每条 `XDB.rec` ＋三层 `skill_view`（真气、天启篇装备、弱者词条）。
- `XActor.param` 自己开的只读窗口只管这一次读取，读完就丢；下一次读 `mcr` 又重建一遍。
- 战斗选技能（`battle_scene.gd:2153`）、装备页（`equip_scene.gd:202`、`:396`）都已在整段外面包了 `XActor.read_begin()／read_end()`（O-348）；`skill_scene.gd` 和 `skin/skin_skill_page.gd` 里一处都没有。
- 排除的嫌疑：说明文字解析（`custom_cost_row` 全部条目 0.3～4 ms）、熟练度等级（≤1.3 ms）、秘籍行信息（≤0.3 ms）、说明卡 `skill_view`（0.002 ms）、图标、类型列表（0.05 ms）都不是大头；光标闪烁不重画整块（O-319 已拆层）。T531 `param_whiteboard` 只在天启篇生效（协调已更正），西游档不走。

## 3. 修法和预计收益（只查没改，修法另开卡）

1. **（推荐，小改）技能页整段包只读窗口**：`XSkillScene._refresh`、三个窗口 painter（`_paint_list`、`_paint_status`、`_paint_types`）、`XSkinSkillPage.sync` 外面各包 `XActor.read_begin()／read_end()`，做成回退开关（O 号，默认开）。
   - 预计收益（Mac 实测，包在探针外层量的）：西游档被动页移动一格 129→53 ms（20 被动）、351→40 ms（120）、约 1030→83 ms（400），列表重画降到 20～45 ms 且基本不再随技能数增长；天启篇皮肤 sync 87→3.9 ms（20）、1397→13.5 ms（120），约 20～100 倍。
   - 安全性：带 `XIYOU_READ_VERIFY=1`（命中就重算比对、不一致当场崩）把旧界面和新皮肤各跑了 20／120 两档，全部跑完、没有不一致。窗口里没有写入（只读页面），使用技能、确认等写操作不在 painter／sync 里。
   - 配置建议：Sonnet＋medium（照 O-348 现成写法套，机械），交付前加跑 `xiyou_skill_page`、`xiyou_skill_mastery`、`xiyou_tusu_ui`、`xiyou_tianqi_secrets`、`xiyou_ui_skin_1b` 等技能页相关场景；我核。
2. **（可选，接 1 之后）新皮肤只在内容变化时重建行**：`sync` 现在每按一下都重建全部行再比 key；光标移动时可只 `list.select`。包了窗口后已是十几毫秒，收益不大，排在后面。
3. **（长线，另议）`skills()` 跨调用缓存**：按写入代数（`_write_gen`）记住技能表，地图、战斗、所有页面都受益；但牵涉面大，要甲档核查，建议先做 1 再看还卡不卡。

## 4. 西游档和天启篇是否都有

都有。西游档旧界面：卡在一屏 28 行 × 每行重建多次技能表；天启篇新皮肤：每按一下重建全部条目，更严重（120 被动 1.4 s）。同一根因，同一修法（1）两边都治。

## 5. 查重（是否近期回退）

- 玩家版 dev.893 与 main dev.937 实测一致（上表），两版之间热路径（`_skill_records`、`param_base`、`passive_values`）只有天启篇专用分支的改动。
- 结构本身从 10-12 起就是这样（`passive_values` 遍历 `skills()` 始于 `67b3624d9`），之后每加一层技能包装（如 11-18 `bba3f291c` 弱者词条 skill_view、11-24 `e000551df` 秘籍封印 `is_sealed`）每条技能的重建成本略涨，但没有哪一次是突变。玩家说「一直挺卡」与此相符：技能越多越卡，是老问题随存档成长变明显，不是新回退。

## 变更记录草稿

## 2026-11-26 【cc·T544·未经审查】安卓技能页卡顿排查（只查不改）（dev.待定）

- 量数：技能页按被动数分档，西游档旧界面被动页移动一格 129 ms（20 被动）→ 约 1030 ms（400 被动），玩家版 dev.893 与 main 一致；天启篇新皮肤 120 被动时 1.4 s。
- 根因：每行算消耗读 4 次能力值，每次读能力值都重建整张技能表（`param_base` → `passive_values` → `skills()`）；技能页没有包只读窗口（战斗技能列表 O-348 已包）。
- 修法另开卡：技能页 `_refresh`／painter／皮肤 `sync` 包 `XActor.read_begin／read_end`（READ_VERIFY 比对无差异），预计降到 40～85 ms／十几 ms。
- 量数探针 `t544_skill_lag_probe.gd`、`t544_skill_lag_micro.gd` 与原始数据都放在 `04_验证/T544_技能页卡顿/`（不在工程 tests/ 里，跑时复制进去）。

## 交接板

- 下一步：新开修卡「技能页包只读窗口」（见交付单 3-1；Sonnet＋medium，cc 核）
- 用户试玩说明：无（只查不改）
- 需要用户决定：无

## 进度账

- 无（排查卡）

## 可优化（流程／工具／效率）

- 建议：菜单页逐行读能力值的地方都该在整段外包只读窗口；可加一条静态扫描（painter／sync 里调 `skill_cost`／`mmp`／`param(` 却不在窗口里的）。预计能提前发现同类卡顿，归工具车道。

## 动了的共用函数和开关

无（工程目录零改动；探针脚本放在 04_验证/，不在工程里）。

## 截图

无（无头量数，没截图）。

## 云端选测

- 没跑云端：本分支没改工程文件（`选测.py dd15d65bb` 结论「Godot 场景 0 个；非 Godot 检查：无」），没有可选的场景。探针最初放在 tests/ 时选测判成整轮（823 场景、约 212 分钟额度），已挪出工程避免空跑。

## 本分支提交

- 见 `git log main..luiluu/t544-skill-page-lag`
