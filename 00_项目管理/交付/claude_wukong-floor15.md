# 交付：claude/wukong-floor15

- 车道／工作者：A 内容·楼层／悟空（Claude，重制_悟空_4，接 重制_悟空_3）
- 状态：可合并（地图循环、十五层 Map032、v0.27 开局轮回入口；十六层未做：周额度 90% 时停止开新层）

## 变更记录草稿

### 2026-10-15 【Claude·悟空·未经Codex检验】地图循环（scrollType）：十四层守层者原版走得到（dev.待定）

- **更正 dev.047 的「守层者走不到」**：十四层 Map030 是横向循环地图（scrollType 2，正式版 231 张图里只有它一张），MV 的 `Game_Map.roundXWithDirection` 让玩家从 x=0 往左一步到 x=59。dev.047 用的是不带循环的 `isMapPassable` BFS，才得出 616／276 两块不连通。正式引擎改用 `$gamePlayer.canPass`＋`roundX/YWithDirection` 复测：从入口 (18,30) 能到 888 格，含守层者 (44,23) 的下、左、右三格；`locate(0,16)` 后 `moveStraight(4)` 到 (59,16)。原版没坏，是 Godot 缺「地图循环」，所以**不做「挪守层者／开路」的优化**，改为照原版实现循环（O-034 未用，收回；轮回入口用 O-035）。
- 实现（照 MV）：`MVTilemap` 按 scrollType 设 `loop_x/loop_y`，`round_cell`（roundX/Y）、`is_valid`、`delta`（deltaX/Y，取较短一边）、`tile()` 环绕；绘制在循环方向两侧多画一屏（28／16 格，Tilemap horizontalWrap）。`MVCharacter.can_pass` 先绕回再判，`step_by` 走一格（格子绕回、real 平移一整张图，同 moveStraight 的 `_realX = xWithDirection(_x, 反方向)`）；跟随者 chase 用 `delta`（deltaXFrom）；玩家点按格、前方格（调查／接触事件）绕回，点按寻路 `_toward` 用 `delta`；循环地图上每帧把各角色画在离玩家最近的那一份（adjustX）；镜头在循环方向不限边。挂机回原点照 moveTowardPosition 的 deltaXFrom（`XHangUp.next_dirs` 加可选 `back_to`），范围仍照 distanceX 直接相减。
- 参照：`map_probe.cjs` 对循环地图另记 `loop`［横, 纵］与越过边缘那一步（`wrapLeft`／`wrapUp`，每行／列一位）；`xiyou_map` 比这两项（37/37）。`xiyou_floor_run` 去掉 `UNREACHABLE_BOSS`，寻路认循环；十四层完整模式真正走到守层者，并检查路上越过了边缘（`WRAP_BOSS`）。
- 验证：`xiyou_map` 37/37；`xiyou_floor_run_d`（13～14 层）167/167；`xiyou_hangup`／`_auto`／`_options`、`xiyou_hud`、`xiyou_transfer` 全过；临时场景截图看 x=2 与 x=57 处两侧绕回的图块与守层者显示正常（截图未入库）。
- 未完成／已知问题：跳跃（MV jump 也不绕回）与事件「接近玩家」类移动路线（Godot 尚未支持）在循环地图上未专门处理。

### 2026-10-15 【Claude·悟空·未经Codex检验】v0.27 开局轮回入口（CodexReincarnationRandom）翻译，O-035（dev.待定）

- 唐僧派（main 合并 v0.27 后 `xiyou_opening_branches` 分支 B 4 项失败）：Map221 引路人「轮回归来！」改为 `CodexReincarnationRandom.open(this)`＋条件 `entryAccepted()`／`entryHard()`＋`finishEntry()`。`MVScript` 翻译：open 时本局已开轮回（开关 2307／2303）则提示「本局轮回已经开启，阵容规则不能中途更换。」；否则先选「轮回普通／轮回困难／返回」，再选「常规阵容／返回」（返回回到难度），结果记在 `MVScript.reincarnation_entry`，两个条件读它（`eval_expr` 白名单加 entry_accepted／entry_hard）。
- **O-035**：「随机角色」模式（9 选 5、重抽、招募限制、弱者协力 10453）暂不开放，阵容规则不列该项；选择界面用两层选项代替 Scene_ReincarnationDraft。登记优化登记 O-035。
- 验证：`xiyou_opening_branches` 16/16（B 改应答为 轮回普通→常规阵容；新增 C：先「返回」不开启，再 轮回困难→常规阵容，开关 2282、全体学 8105）。
- 未完成：随机角色模式；Scene_ReincarnationDraft 的帮助窗＋命令窗外观。

### 2026-10-15 【Claude·悟空·未经Codex检验】扩十五层 Map032 黑暗废墟（dev.待定）

- 切片加 Map032（变量 20＝15 → (31,14)）、敌群 119～123（遇敌）与 138（守层者金池长老）；`maxLevel` 40 → 43；keepEvents "32" 放 1、2、3、5、6、7：守层者（敌群 138，敌群事件与 111／118 完全相同；可交见面礼（50 个物品 182 或 270 肝帝积分）免掉开场领域；没交见面礼时胜后另得物品 2019、变量 863＝1，之后可「向守层者索要礼物」进商店 1998；等级上限开放至 43；胜后卖货 851）、武器/防具商贩、神秘药贩、辛德瑞、宝箱（6）、送礼的同伴（7，公共事件 1324）。未放：副本入口（4，Difficulty 插件）、只在开关 2303／2307 时出现的传承训练官（8）、开关 2285 的雷劫（9、10）；守层者在开关 2302／2303／2305／2307 时换成求道者／马神投影（敌群 750／800／788）各页未接。
- 没有新指令、没有改共用数值链。参照 `troop_event_probe` 加 138；`xiyou_troop_events` 610 → 656。
- 插件指令 `ShopInventory apply …`（守层者「索要礼物」商店、神秘药贩的限购库存）Godot 不认，照解释器规则跳过：这两处商店暂不限购（事件对照未报不一致，因为对照不进商店）。待商店限购系统时补。
- **正式源在本轮同步期间更新到 v0.27**（data/Map004、Map221、Skills，js/codex/modules.json、main.js、installNativeYunshangRuntime、installReincarnationRandomRuntime）。第一次同步在 event_probe 末尾报「测量期间来源改变」中止；重跑后 worktree 里只比较不登记：「有变化」= v0.27 改动（events 第 141 例文字、sequences 新技能 10453）＋切片扩大（events 379→413 等）。**v0.27 的登记与跟进由总装在 main 上做**（备份 `04_验证/本地结果/自动同步/20261015_163511_v0.26-v0.27`）。
- 验证：`godot --import`；`xiyou_event_compare` 358/376 → 392/410（新增 34 例全部一致，已知 18 例不变，baseline 不用改；3 例参照报错 m221e3p0、m4e8p1、ce1344 与之前相同）；`xiyou_troop_events` 656/656；`xiyou_rules` 39218/39218；`xiyou_smart_ai` 14039/14039；`xiyou_map` 39/39；`xiyou_floor_run_d`（完整走 13～15 层）186/186，单跑 199.5 秒（十四层绕边缘路远，遇敌 7 场）。
- 未完成／已知问题：`xiyou_floor_run` 第 4 段已到 199.5 秒；按 ceil 均分，parts 改 5 仍是 13～15 层一段，不解决问题。下一层（十六层）时需改拆法（如余数分给前段、或按层指定段），再加场景。

## 交接板

- 下一步：
  - 「扩楼层」条改为：已到十五层主图（加 Map032），事件对照 392/410（剩 16 例要相应系统，另 2 例是 O-027）；十六层＝变量 20＝16 的落点（看大厅传送门）；`xiyou_floor_run` 第 4 段已 199.5 秒，加十六层前先改拆法（ceil 均分下 parts 加一不解决）。十五层守层者开关 2302／2303／2305／2307 各页（敌群 750／800／788）未接；`ShopInventory` 限购插件未做（十五层两处商店暂不限购）。
  - 删掉顶部「main 已知失败 xiyou_opening_branches 分支 B」。
  - 待交叉核查加本分支（核查重点：地图循环 `MVTilemap.round_cell/delta/loop_shift` 与 `MVCharacter.step_by`、跟随者、挂机回原点；keepEvents "32" 放 1、2、3、5、6、7；`MVScript._reincarnation_open`）。
- 用户试玩说明：十四层神谕森林现在左右相连（往左走出地图边缘会从右边出来），守层者可以走到；新增十五层黑暗废墟；开局「轮回归来！」改为先选轮回普通／困难、再选阵容规则（目前只有常规阵容）。
- 需要用户决定：O-035（v0.27 轮回入口的「随机角色」模式暂不开放）加进「需要用户决定」的 O 项列表；dev.047 记的「十四层守层者走不到」是误判，可从已知问题删除
- 顶部「main 已知失败 xiyou_opening_branches 分支 B」本分支合并后消除

## 进度账

- 楼层：8% → 8%（地图 18/231 → 19/231，加 Map032；地图循环属已有楼层的补全），悟空初值，待沙僧复核。

## 本分支提交

- 0f29f0a 开工交付单
- 1149646 地图循环（scrollType），十四层守层者真正走过去
- 5653df3 十五层切片（WIP）
- b6e618d 十五层同步、对照与流程测试
- fe7024d v0.27 开局轮回入口（提交信息写的 O-034，按唐僧改为 O-035）
- 合并 main（v0.27 登记）后 `检查.sh --oracle` 全部通过（xiyou_floor_run 四段 84/124/164/186，xiyou_opening_branches 16/16）
