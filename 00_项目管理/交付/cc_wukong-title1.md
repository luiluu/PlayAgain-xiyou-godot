# 交付：cc/wukong-title1

- 车道／工作者：C 规则／悟空（cc）
- 基线：从 cc/wukong-pushstate2 末端 cd6f8e84 切出。
- 状态：可合并

## 原版对照表（Star_Designation，1380 行）

先说结论：**原版称号没有能力加成**。它只是玩家头顶的名牌（名字＋图标＋颜色）；插件后半截（约 980～1270 行）是联机插件 HWGOE 的其他玩家显示和寻路，单机不跑（`if(!window.HWGOE)` 下只改 Scene_Map 初始化）。所以派单里「加成进能力值」这一项原版没有，没做。

| 部分 | 原版 | 分期 |
| --- | --- | --- |
| 称号表 | 插件参数 `Designation 1～100`（struct：DesignationName／DesignationIcon／DesignationColor），冻结源 30 条；`DataManager.isDatabaseLoaded` 时读进 `$dataStarDesignationOpt`；kyo 专属成就（installKyoAchievementRuntime）另登记 31 号「kyo专属」、图标 240202、颜色 #f5f7fa | 一期（逻辑） |
| 解锁 | `ConfigManager.DesignationN`（全局配置，所有存档共用，makeData／applyData 往返）；事件脚本 `ConfigManager.DesignationN[N] = true;` 共 59 处（Map004 EV55、Map007／013／014／017／020 等、CE367／434）；31 号跟着成就 143 是否到手（syncDesignation：选择称号前、读档时） | 一期（逻辑＋存档） |
| 条件 | 条件分支脚本 `ConfigManager.DesignationN[5]`（Map002 EV2） | 一期（事件指令） |
| 当前称号 | `$gamePlayer.DesignationName／DesignationIcon／DesignationColor`（$gamePlayer 进存档） | 一期（存档） |
| 选择 | `Star.Designation.ChooseTitle()`（Map004 EV1「更换称号」）预约标题画面时接在 `$dataCommonEvents` 末尾的公共事件：提示「选择要显示的称号」，选项是全部称号（没解锁的 `\I[0]???`），取消类型 -2；取消清空（名字空、图标 0、白色），选到 ??? 不变，选到已解锁就设成它 | 一期（逻辑走现有选项窗） |
| 头顶名牌 | `Sprite_Character.updateOther`／`RefUserDesignation`：玩家头上 180×84 画布，名字（$gamePlayer.SaveActorName）、称号名（字号 16、称号颜色）、图标；installDisplayPreferencesRuntime 另画一份 180×58 的名牌（offsetY 48、透明时隐藏） | 二期（界面） |
| 联机 | HWGOE 其他玩家名牌与寻路 | 不做（单机） |

## 变更记录草稿

## 2026-10-31 【cc·悟空·未经审查】称号系统一期：解锁、选择、存档与事件接口（dev.待定）

- 新 `core/designation.gd`（`XDesignation`）：称号表（插件参数 30 条＋kyo 专属 31 号）、`unlocked`／`unlock`（31 号看成就 143）、选项文字、`apply_choice`（取消清空、??? 不变）、`choose`（提示＋选项窗，取消类型 -2）。
- `xconfig.gd`：配置加 `DesignationN`（默认 {}，applyData 照原版 `config.DesignationN || {}`），`designations()`／`save_designations()`。
- `xstate.gd`：加 `designation`（当前称号 {name, icon, color}，没选过为空），存档键 `designation`（to_dict 一处、from_dict 一处）。
- `mv_script.gd`：认 `Star.Designation.ChooseTitle()`（当场弹；原版预约公共事件、本事件结束后弹，那一支后面没有别的指令）、`$gamePlayer.DesignationN = … || []`（无用的空数组，跳过）、`ConfigManager.DesignationN[N] = true`；条件脚本 `ConfigManager.DesignationN[N]` 进白名单表达式（`designation(N)`）。
- 参照 `mv_oracle/designation_probe.cjs`（9 例，不接全量同步）→ `tests/fixtures/designation_oracle.json`；专项 `tests/xiyou_designation.gd` 24/24。

## 交接板

- 下一步：称号二期（界面）：地图上玩家头顶名牌（名字、称号、图标、颜色，offsetY 48，透明时隐藏；对照 installDisplayPreferencesRuntime 那份），选项窗里的图标显示（`\I[n]` 已在文字里）。
- 用户试玩说明：方桌大厅「更换称号」能选了，各处的称号奖励会记下（所有存档共用）；头顶还看不到称号（下一期）。

## 优化登记草稿

优化登记草稿：无。

## 进度账

- 养成·称号：0 → 逻辑与存档完成（界面未做）。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 参照：`designation_probe` 9 例无报错（正式冻结 v0.28）。
- 专项：`xiyou_designation` 24/24。反向：去掉解锁那行 23/24。
- 相关场景（本机）：`xiyou_script`、`xiyou_common_scripts`、`xiyou_save_events`、`xiyou_save_page`、`xiyou_autosave`、`xiyou_achievement`、`xiyou_change_clothes`、`xiyou_options_basic`、`xiyou_options_misc`、`xiyou_designation` 共 11 个场景全部通过。选测（改了 xstate／xconfig／mv_script）超过 40 个，交总装合并时跑。
- 改动的共用核心文件：`xstate.gd`（`designation` 字段、to_dict／from_dict 各一处）、`xconfig.gd`（DEFAULTS、applyData 一支、两个函数）。没改 actor.gd。

## 本分支提交

- 8797a3b0 参照探针
- 7dcd372d 称号一期逻辑与专项
