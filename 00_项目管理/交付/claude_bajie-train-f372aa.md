# 交付：claude/bajie-train-f372aa

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_60）
- 状态：进行中

## 变更记录草稿

## 2026-10-24 【Claude·八戒_60·未经Codex检验】修炼界面（Star_ActorAttributePlusPoints）与三处入口（dev.待定）

- **用户方向**：核查积压超限期间用户 2026-10-24 破例，八戒做修炼界面，与沙僧核查并行。
- **运行时 `XTraining`**（新 `core/training.gd`）：修炼表照插件参数「AttributePlusPoints 1～100」（第 N 项编号 N−1，现有 65 项：名称、满级、每级精魂、能力编号 0～7、每级加值）；入口脚本先设 `XiuLian`（本次列出的表编号，全局不存档，没设过时 0～7）。修炼（onConfirmOk）：等级 < 满级且精魂够时等级＋1、扣精魂、提示「修炼成功」，否则「等级已满」或「精魂不足」。指令行文（makeCommandList）照原版逐字拼，空格也照原版按能力编号补。
- **存档字段 `XState.training`**：`{"角色ID": {"表编号": 等级}}`。原版存 `actor.pushattribute[表编号] = [等级, 累计加值, 能力编号]`，表是固定的，累计加值＝等级×每级加值、能力编号＝表里的值，所以只存等级。没有这个字段的旧档读成空。
- **能力值加成 `XTraining.param_bonus(actor, i)`**：照原版 paramBaseBoost 算，加在 paramBase 上（被动之后、比率之前）。**还没接进角色能力**：要在 `actor.gd` 的 `param_base` 末尾读这一份，`actor.gd` 归沙僧独占，已停手请唐僧定接法（见「需要用户决定」）。
- **界面 `XTrainingScene`**（新 `ui/training_scene.gd`）：照冻结 v0.28 浏览器参照逐窗复现。队员目录 (0,0,426,720)；状态窗 (426,0,854,720)，SV 图 0-1-2-1 动、名字与「等级:N」、八项能力值照原版三列；精魂窗 (0,656,426,64)；底部「修炼」(426.67,656,854,64)；修炼项 (426.67,136,854,388) 一直显示。流程是目录 → 底部「修炼」→ 修炼项确定，修炼后留在修炼项；取消一级一级退回，目录取消关闭。
- **入口**：`mv_script.gd` 认 `Star.ActorAttributePlusPoints.XiuLian = [...]` 与 `SceneManager.push(Scene_ActorAttributePlusPoints)`（→ `map_scene.open_training`）。Map082 EV4、Map084 EV10（魔塔教师）已在切片；Map180 EV12（二十六层影照洞窟小萝莉：三页修炼列表＋「妹妹抽我」战斗敌群 515 与固定存档位存档）放进 keepEvents，敌群 515 由转换器随事件收进切片。Map119 EV15、Map046 EV1 的同一入口脚本也认得，但这两个事件本批不在切片里。
- **优化 O-082**（`XTrainingScene.ALIGN_COST`，可回退）：原版用空格补齐「下一级费用」，中文字宽不一，各行差 3～20 像素；这里把它画在同一列，文字不变。
- **参照**：新探针 `mv_oracle/training_probe.cjs` 在冻结源上跑真实插件，记下修炼表，以及七组流程（魔塔教师两处、小萝莉三页、默认列表、先被人物图鉴写过 `[0,0]` 的情形）每一步的行文、提示、精魂、pushattribute、八项能力值、paramBase，再加一次存档往返（产物 `training.json`）。界面参照 `tests/fixtures/training_ui_oracle.json` 在浏览器内存新局（1/8/9/10、精魂 1234567890、地图 82）上取：窗口几何、各窗逐条 drawText／图标、精灵位置、焦点流转。
- **事件对照**：`xiyou_event_compare` 的记录宿主加 `open_training`，基线撤掉 6 条不一致：m82e4p0、m84e10p0，另有 m180e12p0～p2、m119e15p0。
- 验证：见下「验证」节。
- 提交：见「本分支提交」。
- 未完成／已知问题：① 修炼加成没接进角色能力值（等 actor.gd 接法），接上前修炼会扣精魂、升等级，但能力值不变；② 精魂上限差异（下条）使 15 亿一级的小萝莉第三页在 Godot 里买不到；③ 底部「修炼」二字比原版偏左约 8 像素（原版用 44 个空格推到中间，空格宽两边不同）。

## 交接板

- 下一步：唐僧定 actor.gd 接法后，在 `XActor.param_base` 末尾加 `v += XTraining.param_bonus(self, i)`，再把 `tests/xiyou_training.gd` 的 `PARAMS_HOOKED` 改成 true，跑 `xiyou_training`。
- 用户试玩说明：勇者之塔魔塔教师「进行修炼」会打开修炼界面（选队员 → 修炼 → 选项目），扣精魂、等级加 1；能力值加成要等接进角色能力后才生效。
- 需要用户决定：
  - O-082 修炼项「下一级费用」对齐，是否保留。
  - 修炼加成接进 `actor.gd` 的方式（沙僧独占文件）：A 在 `param_base` 末尾加一行读 `XTraining.param_bonus`（推荐）；B 借 `XEquipSuits.value` 的 param 加值顺带加（数值相同，语义不对）；C 交给沙僧以后接（宠物 `war_param_plus` 也卡在同一步）。

## 修炼界面以外的发现（未做）

- **精魂上限**：原版 YEP_CoreEngine「Gold Max」为 999999999999（9999 亿），Godot `XState.gain_gold` 夹在 999999999（9.99 亿）。所以小萝莉第三页每级 15 亿的「命脉强化」在 Godot 里永远买不到，其他超过 9.99 亿的价格同理。修炼扣钱已改成直接扣、不经过 `gain_gold`，但收入仍受这个上限。HUD 与商店的数字宽度要一并核对，建议另派。
- **小萝莉第三页的提示**：输掉「妹妹抽我」后提示「所有训练项目价格提高2倍」，但第三页的价格本来就是表里写的 15 亿一级，没有翻倍。这是原版行文与数据不符，照原版保留。
- **修行页战力分区**：`installNativePowerZonesRuntime` 把 pushattribute 算进「外部」分区（剥离时清空）。Godot 的修行页（`power.gd`）还没有修炼这一项，接上能力值后应一并核对。
- `xiyou_slice.json` 的 keepEvents 说明文字没有提到 Map180 EV12（说明归悟空维护，本车道只改了 Map180 的事件列表）。

## 验证

- `xiyou_training` 新专项 158/158：修炼表 65 项；七组流程每一步的行文、提示、精魂、存档等级、八项加成（＝参照能力值 − 修炼前）；存读档往返；旧档无字段；五窗几何；目录／状态／精魂／底部／修炼项逐条绘制（坐标与宽差 ≤ 0.05，字号与颜色相同）；焦点流转、换队员、关闭；O-082 对齐；入口脚本；Map180 EV12 在切片。「含修炼的能力值」一项等 actor.gd 接上后打开（`PARAMS_HOOKED`）。
- `并行测试.py` 专项：`xiyou_training`、`xiyou_event_compare`（5/5，回归 0，撤 6 条）、`xiyou_floor_brave081`（66）、`xiyou_floor_brave083`（101）、`xiyou_floor_abyss174`（158，有传到 Map180 的出口）、`xiyou_save_page`（40）、`xiyou_battleback_save`（5）、`xiyou_script`（19）、`xiyou_pets`（27），全部通过。
- 工作树 `同步正式西游.py --accept-additions`：测量不变，新增修炼探针，0 问题。`内容覆盖检查.py`：new 0、resolved 0，覆盖基线不用更新。
- 非 headless 截图与原版截图对过（初始、底部激活、修炼后），差异只有上面「已知问题」③，以及没接加成造成的生命值不同。

## 进度账

- 界面·修炼：0% → 85%，界面、存档、入口与参照都已完成，只差能力值加成接进角色（actor.gd）。

## 本分支提交

- a2f535c1 修炼运行时 XTraining、存档字段 training、原版参照 training_probe
- a5429e40 修炼界面 XTrainingScene、三处入口接线、Map180 EV12 进切片、专项 xiyou_training
- 160cbbdb 事件对照基线撤掉修炼入口 6 条
