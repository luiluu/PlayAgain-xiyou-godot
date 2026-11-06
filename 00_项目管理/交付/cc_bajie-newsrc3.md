# 交付：cc/bajie-newsrc3

- 车道／工作者：A 内容·楼层／八戒（cc，第十四批 CZ）
- 状态：到 40% 线交接（集成分支用，不合 main，不标可合并）。②③④ 做完；① event_compare 本机全量跑通了、差异表拿到并分好类，**基线还没重出**（剩 2 例没查完，见下）。
- 从 `cc/newsrc-switch` 7520680b 切出；工作树 `.claude/worktrees/charming-chatterjee-a967ac`（generated 从集成分支树 `recursing-shamir-4cd3d8` 克隆，v0.62.12 新源产物＋新源 event_states）。

## 变更记录草稿

### 【cc·八戒·未经审查】换源追平续三：大厅漩涡过场不再挂住测试、号角店跟新源、升级文字、商店积分价

- **opening_branches 资源未释放**：原因是大厅 EV76 漩涡过场（新源，新档首次进大厅自动执行）还停在 223 色调等待（等 SceneTree 的帧）时测试就退出了；解释器和挂起的协程互相引用，宿主释放也收不回，退出时报「2 resources still in use」。试过把等帧改成等地图宿主转发的信号（宿主释放时一起断开），**没用**（Godot 4.7 里协程挂起在已断开的信号上也不释放），已撤回。改成测试等过场播完再退出（`c_rift_cutscene`：rift1 记过、EV76 独立开关 A 开、地图空闲），顺带把过场从头到尾走了一遍；不再预先记成看过。
- **其它进大厅的测试**（17 个逐个跑过，只看泄漏）：都没有「resources still in use」。但过场挡住了两个测试：`screen_fx`（色调被过场 223 改掉，tint_reached／save_kept 挂）、`floor_reach041`（过场占住地图，预约的公共事件 164 没跑，lamp_in_dungeon 挂）。两测都设了 `XConfig.path_override`，改成开头 `whisper_mark("rift1")`（只写本测的临时配置），现在全过。`platform` 退出时有 3 个 ObjectDB 泄漏警告（不是资源未释放，不算失败），没查。
- **号角店**（map132_shop 6 项）：`XItemMarks` 里另有一份旧的停用号角名单（5 个），改成直接用 `XImportedBalance.DISABLED_HORNS`（新源 10 个，多 245／274／359／456／494）；Map132 不朽号角货架（有 2788 的店）追加流萤号角 3063（installLiuyingRuntime v0.60.02，排在谷雨与云裳之间；库里 3063 名字是「伙伴号角：流萤」才加，旧源不加）。map132_shop 102/102。
- **shop_buy**（实测只挂 ui_list、ui_number0 两项，另外 3 项随停用号角名单一起好了）：界面参照是 MV 量的旧源数字，新源被动书 2230 的备注价从 1000 肝帝积分＋30 件 2201 改成 1300＋39（数据里乘了 1.3，不是 v0.41 商店规则的指定价×1.3），参照里的数字跟到新源，位置不变。8479/8479。
- **interp_review**（flush.225 两项）＋ event_compare 大厅 EV69 三例：**新源原版代码错误**。流萤运行时 `installLiuyingRuntime` 把 `Game_Actor.changeLevel` 包成 `function(level)`，316 增减等级勾的「显示升级」被丢掉，原版不再出「某某升到了 等级 N！／学会了…」（探针打桩实测 `changeExp` 收到 show=undefined；v0.28 有这段文字）。`MVEventCore.LEVEL_UP_SHOW_316`（默认 true，照旧显示）；设 false 回到新源原版。interp_review 在参照文字为空时按回退支比文字、时序用默认支比参照帧号。**O-待定·升级文字**，已登优化登记。
- **优化登记**：O-184 状态加注「只在旧源（v0.28）生效，新源原作已做活，正式源换定后可退役」；CE1370 拔剑再释放登「O-待定·拔剑再释放」（`XBattleEventRunner.O_PUSH_RECAST`）。两个 O-待定 编号合 main 时总装分。
- **事件预设**：`ce9039#n2`（麒麟 142）、`ce9026#n2`（147）加 `difficulty: 9`。原来预设加人时被「超强者仅限地狱及以上难度获取」拦下，参照多一条提示。已补跑事件状态探针（增量）。

## event_compare（本机全量，新源）

- 直接跑 godot（不套 perl alarm）**7 分 11 秒**跑完，没超时；上一单 rc=142 是外层 alarm 杀的。以后可以本机直接跑：`./07_开发环境/godot --headless --path 01_Godot工程 res://tests/xiyou_event_compare.tscn -- --out=<目录>`。
- 结果（改动前）：15565 例，15553 对上，不一致 12 例（3 例原登记在基线），退步 9 例，新增跳过 5 条。逐例：

| 用例 | 原因 | 处理 |
| --- | --- | --- |
| m4e69p1、#o4_2、#o4_3 | 新源 316 不出升级文字（上面） | 默认显示＝不一致，**进基线**，理由写 O-待定·升级文字 |
| ce9039#n2、ce9026#n2 | 预设加超强者被难度拦，参照多一条提示 | 预设已加 difficulty 9；补跑探针（增量）后参照里**还有这条提示**，补跑没输出，不确定是没重跑这两例还是 9 不够。要查：`node event_state_probe.cjs 'ce9039#n2'` 单跑看提示是否还在；在的话看 m213e2p0#w1_857 为什么 9 有效 |
| ce9043 | `CodexLiuying.recruit()` 没做（流萤，扩角色） | **进基线**；新增跳过同 |
| m4e71p0 | 更新日志：重制按 `PlayerChangelog`（v0.62 在前）；参照显示 v0.25～v0.36 那页在前 | 参照宿主读 `data/PlayerChangelog/v0.38.json` 起大概读不到（`readChangelog` 同步 XHR，读不到就停），真游戏读得到。我起的核对脚本（hboot 里调 `CodexGuide.changelogEntries()`）5 分钟没出结果，停掉了，**没核实**。核实后进基线（参照宿主问题）或修探针 |
| ce1370 新增跳过 4 条 | 新源 `actor._actions.push` 写法只在战斗里（O_PUSH_RECAST 在战斗事件里补了），地图对照里认不出 | **进跳过基线** |
| m148e38p0 | 战斗背景：参照 ["DirtField",""]，重制 null | **没查** |
| ce1434#o5_3 | 赌场第二把：参照 1197＝2160＋267（像是先取了 1195 新随机值），重制 0＋267；随机序列 0.9 | **没查完**：按指令顺序算应该是重制对（1197＝v1195 在 1195 取随机之前），要在探针里打桩看原版 122 的实际顺序 |

- 重出基线：等上面两例查完、ce9039／ce9026 重跑确认后 `-- --update-baseline`（只认全量）。

## 接续要点（给下一位）

- 工作树 `.claude/worktrees/charming-chatterjee-a967ac`（分支 `cc/bajie-newsrc3`），generated 是新源；补探针要显式设 `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`。
- 先跑一遍 event_compare 全量（7 分钟），看本单改动后的差异表，再查 m148e38p0、ce1434#o5_3，确认 m4e71p0，最后 `--update-baseline`。
- `reincarnation_entry` 本机挂 3 项（source：夹具 sourceIdentity 还是旧源；hard.*.skill8105：会 8105 的人多了 166／167），不在本单，没动。

## 交接板

- 下一步：见上「接续要点」。
- 用户试玩说明：无（集成分支）。
- 需要用户决定：O-待定·升级文字、O-待定·拔剑再释放 两项默认按修（显示升级文字、补再释放），可回退，等 Kyo 最后定。

## 可优化（流程／工具／效率）

- 进大厅的测试会被新源漩涡过场挡住：可以在测试宿主（或 `XSave.dir_override` 设了时）默认把 rift1 记成看过，只在 opening_branches 里放开。现在是逐个测试加，以后新加的进大厅测试还会踩到（工具车道）。
- event_compare 本机直接跑 7 分钟就完，`并行测试.py`／检查脚本给它的超时偏紧，可以单独放宽或给它单独一个槽。

## 待交叉核查

- `item_marks.gd`（停用名单引用、流萤号角）、`mv_event_core.gd`（LEVEL_UP_SHOW_316）、`xiyou_interp_review.gd`、`xiyou_shop_buy.gd`（参照数字）、`xiyou_opening_branches.gd`（等过场）、`xiyou_screen_fx.gd`、`xiyou_floor_reach041.gd`、`event_presets.json`（两个 difficulty）、`优化登记.md`（O-184 注、两条 O-待定）。

## 验证

- 本机新源：opening_branches 17/17（不再报资源未释放）、map132_shop 102/102、shop_buy 8479/8479、interp_review 13/13、screen_fx 28/28、floor_reach041 12/12；进大厅的另 15 个测试照旧全过（reincarnation_entry 56/59 不在本单）。
- `语法检查.py` 0 问题。
- `事件空绿扫描.py --check`：空绿 96 例均在基线内，理由齐 96 例。

## 本分支提交

- 见 `git log cc/newsrc-switch..cc/bajie-newsrc3`
