# 交付：claude/bailong-fix0

- 车道／工作者：白龙·专属角色期零修／白龙（Claude，重制_白龙_4；接手白龙_3 现场 2449e4e1）
- 状态：可合并

## 变更记录草稿

## 2026-10-26 【Claude·白龙·未经Codex检验】期零修：专属角色技能说明卡走 characterHelpView、读 HelpWidth；人物图鉴立绘按原版（dev.待定）

- **起因**：白龙 #14（dev.180）合进 main 后全量 `--oracle` 剩两项失败：`xiyou_help_card`（167 渡鸦／168 米拉／173 饿狼等专属技能说明卡与正式版参照对不上）、`xiyou_actor_book`（168、173 画了参照没画的立绘）。
- **说明卡**：接手白龙_3 的 `ui/character_help.gd`（XCharacterHelp，installDisplayPreferencesRuntime 的 characterHelpView 移植，文件头写了次序与未移植项）与 `core/garou.gd` 的 `form()`／`FORM_NAMES`／`FORM_PASSIVES`；`help_card.gd` 对 10122～10299 技能改走 XCharacterHelp，其余技能仍走 genericHelpView。另补 HelpExtend `setItem` 的备注 `<HelpWidth: N>`：`XHelpCard.note_width` 按备注取卡宽（专属技能多为 520，全库 153 个技能带这个标签），`show_for` 用它；人物图鉴照原版先去掉标签、固定 727 宽，不受影响。
- **与原版不同（未登记 O 号，见「需要用户决定」）**：原版改的是同一个 Sprite 的 `width`，看过一张 520 宽的卡后，同一窗口里没有标签的卡也沿用 520；重制每张卡按自己的备注取。
- **人物图鉴立绘**：新 `XActorBook.sprite_path`：168 米拉、173 饿狼、174～177 在原版由运行模块（Codex_MiraRavenMultiFrame、installNativeGarouRuntime 等）换成多帧图（参照画 `UserSV_MiraHuman1_0`、`Codex_Garou_QHuman1_0`、`yunshang1_0`…），重制还没移植多帧图，先不画（画数据库 battlerName 那张会与原版不同）；其余照 battlerName，没导出的不画。
- **测试**：`xiyou_help_card` 夹具照探针补齐 10 级的所属角色（166／167／168／172／173，探针 `changeLevel` 后 characterHelpActor 取的就是它们），版面按 `note_width` 排——988／988；`xiyou_actor_book` 的 NO_SPRITE 移出已进切片的 167、172 与图已随别处导出的 160（参照都画数据库 battlerName），判定改用 `sprite_path`——22／22。参照数据没改。
- **选测**（`检查.sh --affected main --oracle`，35 个场景）：只有 `xiyou_event_compare` 失败（读不到 Map067／068／071／138／185）。原因是环境：本分支起点落后 main（7130c9b5，dev.182 stage-review-50-phase2 把这 5 张图加进切片），`--补齐` 从主工作区带来的事件参照已含这几张图，本工作树的转换产物没有。本分支没碰事件与切片；与 main 试合并（merge-tree）无冲突，合并后在 main 上应通过。其余全过；`xiyou_help_card`、`xiyou_actor_book` 另单跑全过。
- **注意**：单跑场景要用 `07_开发环境/并行测试.py`（隔离 HOME）；直接 `godot --headless` 会读本机开发配置 `options.json`（用户试玩时关了「战力显示与估算」），装备卡全缺战力行，误报 130 多项。

## 交接板

- 下一步：白龙期一 169 黄泉（总装合并本分支后再派）；168／173～177 多帧侧视图移植（人物图鉴立绘、战斗侧视图共用）待排期
- 用户试玩说明：渡鸦／米拉／饿狼等专属技能的说明卡显示当前数值（魄倍率、阶位系数、魔防穿透、形态系数等）且卡宽 520，长行不再折行；人物图鉴里米拉、饿狼的状态页暂不画立绘
- 需要用户决定：`<HelpWidth>` 宽度不沿用到下一张卡（原版沿用，属原版缺陷），需要的话总装分 O 号登记；回退＝无（沿用原版会让普通卡也变宽，不建议）

## 进度账

- 无变化（修全量失败）

## 可优化（流程／工具／效率）

- 建议：`检查.sh` 或 `07_开发环境/README.md` 写明「单跑一个场景」的命令（`python3 并行测试.py ./godot ../01_Godot工程 --full <场景名>`），本轮先用裸 godot 单跑被本机配置误导了一回（收益：少走弯路；归工具车道）

## 本分支提交

- 2449e4e1 WIP：白龙_3 期零修现场（help_card／garou／新 character_help）
- 4a1e4250 说明卡专属角色技能走 characterHelpView、读 `<HelpWidth>`，xiyou_help_card 全过
- 9c584f38 人物图鉴立绘按原版——多帧图角色不画、160 照画，xiyou_actor_book 全过
