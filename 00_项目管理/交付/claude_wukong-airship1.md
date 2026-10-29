# 交付：claude/wukong-airship1

- 车道／工作者：A 内容·地图／悟空_68（Claude）
- 状态：可合并
- 基线：从 `claude/wukong-airship` 末端 b4ed0d34 切出（上期只交方案，唐僧先合 airship 再合本分支，文件不重叠）。
- 编号：没用优化号（本期照原版，不是优化）。

## 变更记录草稿

## 2026-10-29 【Claude·悟空·未经Codex检验】飞艇状态与存档（天之上飞艇方案甲一）（dev.待定）

- 起因：上期盘点（交付单 `claude_wukong-airship`）天之上 Map069、神魔战场 Map186 靠飞艇在岛间移动，用户 10-29 晚定了照原版做飞艇 3 期（方案甲），本期做第一期，玩家看不到变化。
- `xstate.gd`：新字段 `vehicles`（照 `Game_Map._vehicles`，下标 0 小船、1 大船、2 飞艇：图号、坐标、朝向、行走图、BGM、高度、驾驶中）与 `vehicle_type`（照 `Game_Player._vehicleType`，walk／boat／ship／airship），随档（存档键 `vehicles`／`vehicleType`）。开局与旧档没有这两个键时按 System 起始位置（`Game_Vehicle.initialize`：飞艇 Map186 (50,49)、朝向 4、Vehicle 第 3 格、BGM 用 System 的）；半截的字典缺的键按缺省补，`vehicleType` 不认识的按走路。没升存档版本、没改旧字段。新函数 `vehicle(0/1/2 或名字)`、`default_vehicle(i)`、常量 `VEHICLE_TYPES`。
- `mv_event_core.gd`：
  - 指令 202（设置载具位置，`Game_Vehicle.setLocation`）：直接指定与变量指定都写进 `vehicles`，只改图号与坐标、朝向不动；原先在 `mv_interpreter.gd` 里「只记不动」的分支删掉，改到核心（战斗里原版也一样执行）。
  - 指令 323（改载具图像）记下行走图与序号；指令 140（改载具 BGM）记下 BGM（全工程目前 0 处，照原版补上）。
  - 条件分支第 13 类（载具）：`$gamePlayer.vehicle() === $gameMap.vehicle(p1)`，走路时恒假，在飞艇上只有 2 为真。重制还不能上飞艇（甲二），所以现在实际仍恒假，行为不变。
- 不做（甲二、甲三）：上下飞艇、飞行移动、降落、飞艇画面、BGM 播放。
- 新专项 `xiyou_airship_state`（28 项）：开局／旧档缺字段／半截字段的缺省；真实地图场景里跑楼层回大厅 Map003 EV4 → 69 (30,25)、CE240 恰兰吉尔 → 69 (65,56)、CE1002 神魔战场 → 186 (50,49)、CE10 回到大厅 → 69 (30,25)；在飞艇上时 CE240 被条件 13 拦住、不换图不挪飞艇；202 变量指定、323、140、不认识的载具编号；`XSave` 真存档读档往返一致（存档目录用测试专用的 `user://test_airship_state`，跑完删掉）。
- 原版参照：没加 `mv_oracle` 探针。202／323／140 在原版只是把参数原样赋给载具字段（`rpg_οbjects.js` `command202`／`setLocation`、`command323`、`command140`），期望值直接取冻结数据里的事件参数与 System.json，没有要算的数值；探针要先在参照引擎里开地图跑公共事件，成本大于收益。

## 交接板

- 下一步：
  - 「天之上岛间移动」：用户 10-29 定甲（照原版飞艇 3 期，不做 O-114 岛间传送）。甲一（飞艇状态与存档）已做；下一期甲二（上下飞艇、飞行、降落）。飞行中禁用地图传送菜单与挂机做成可回退优化，到甲二／甲三实现时登记新 O 号。
  - O-114 预分配的号不用了，可以收回。
- 用户试玩说明：无变化（只开始在存档里记飞艇位置）。
- 需要用户决定：无（甲／乙已定甲；上期交付单里「需要用户决定」那两条合并时可以划掉）。

## 进度账

- 无变化（玩家可见功能没变）。

## 待交叉核查

- 本分支提交（见下）。重点：`xstate.gd` 存读档新增键与旧档缺省（原沙僧核心文件，请重点核）；`mv_event_core.gd` 202 从地图解释器移到核心后，战斗里遇到 202 也会改飞艇位置（原版同样如此，全工程 202 都在地图事件或公共事件里）。

## 可优化（流程／工具／效率）

- 建议：`选测.py` 只要动了 `xstate.gd` 就选出 218 个场景（几乎全量，因为人人都引用 XState）。可以给 `xstate.gd` 加 `onlyLines` 式的细分（只加字段与存读档键的改动只选存档类专项＋事件对照），预计车道每次改存档字段省 20 分钟以上；归工具车道。本期按规则自己挑了一组（见「验证」）。

## 验证

- 没改切片、转换器、探针，没跑同步；没跑全量（车道规则）。
- 专项 `xiyou_airship_state`：28／28 通过（合 main 前后各一次）。
- 选测：`选测.py b4ed0d34` 因为改了 `xstate.gd` 选出 218 个场景（近乎全量），按车道规则改挑与存读档、事件解释器、202 涉及地图相关的一组：`xiyou_airship_state`、`xiyou_event_compare`、`xiyou_save_events`、`xiyou_save_page`、`xiyou_autosave`、`xiyou_battleback_save`、`xiyou_interp_review`、`xiyou_map186*`（5 段）、`xiyou_floor_reach069`／`106`／`115`、`xiyou_transfer`、`xiyou_flow`、`xiyou_map`、`xiyou_floor_run*`（3 段）、`xiyou_review_fix`、`xiyou_screen_fx`、`xiyou_hangup*`（3 个）、`xiyou_heir116`、`xiyou_difficulty_inherit_load`、`xiyou_global_vars`、`xiyou_system_evidence`、`xiyou_opening_branches`、`xiyou_start_state_walk`、`xiyou_loose_fixes`、`xiyou_common_scripts`：**35 个场景全部通过**，没有偶发（日志 `04_验证/本地结果/并行测试/20261029_200703_r9sx66cx`）。总装合并时如按影响面另选，建议至少加跑全部存档类与事件对照。
- 必跑项（非 Godot）：MV 文件守卫、界面参照服务守卫、导出过滤，都通过。
- 合 main（334e64c3）无冲突；main 新提交只动了战斗／异化文件和 `alien_affix_probe.cjs`，与本车道无关，没重跑 `--补齐`。

## 本分支提交

- f39912ba 飞艇状态与存档（甲一）：载具字段随档、202／323／140、条件 13；新专项 xiyou_airship_state
- （合并提交）合 main 334e64c3
- （本提交）交付单
