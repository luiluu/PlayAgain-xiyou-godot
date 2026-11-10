# 交付：cc/rules-battle-pixel

- 车道／工作者：C 规则·战斗画面／八戒（cc，GB10）
- 状态：可合并
- 车道路径：/private/tmp/claude-501/-Users-kyo-Documents--------/ca7bac3c-a521-4599-a8f1-267ef10631d8/scratchpad/bp

分支从 main c16afc841 切（gaps10／gaps11 都还没合，本分支不依赖它们）。会话没有自己的 worktree，在 scratchpad 的 `git clone --shared` 里做，已推回本库。

## 做了什么

接 gaps11「没做的」：状态图标、伤害数字、Boss 血条三个场面原版（v0.62.12）对 Godot 截图对照。

- 原版参照 `03_转换工具/ui_reference/battle_pixel_ref.cjs`：夹具同「战斗夹具 4 人」，敌群换 4（【守层者】里德，敌人 6 在 MOG_BossHP 名单里），背景涂黑（原版背景是上一场景快照，不能比）。截 Boss 血条（指令窗出现后 60 帧）、状态（Boss 沉默、1 号黑暗，回合定 4）、选敌名字旁图标、三个伤害数字（12345／321／暴击 4567）第 6／20／40 帧，记显示树矩形和字体读数。
  - 踩到的坑：无头 Chrome 一次 rAF 补跑好几次 updateScene，从外面 await 等帧会跳 10～30 帧（第一版「第 20 帧」截图其实是第 37 帧，伤害数字看着「飞得快、40 帧就没了」是假象）。现在动作和截图都排进 updateScene 包装里按帧做。
- Godot `tests/xiyou_battle_pixel.gd`（新场景，17 项）：同一场面，背景涂黑，TP 定 12（原版夹具 Math.random 恒 0.5），窗口模式出同名截图和 `bp_nodes.json`。
- 对照 `03_转换工具/ui_reference/battle_pixel_compare.py`：按区域裁图，出平均差、差 >32 占比、墨迹外接框四边差和上下对照图。

## 结论（逐区域，修后）

| 区域 | 结论 |
| --- | --- |
| Boss 血条框、头像、条 | 矩形一致（框 105,45 507×78；条 127,73；头像 55,37）。**修了**红色拖尾条的位置（见下）。剩下的差是彩虹条流动相位和原版左上挂机界面盖着 |
| Boss 血条数字 | 位置、字格一致。原版第 60 帧 497.6万、重制 500万：重制的追赶封顶（O-237）让数字更快到位，不算差 |
| Boss 名 | **修了**颜色：原版难度色（难度 3 天蓝 #4499ff），重制一直白字 |
| Boss 状态面板 | 矩形一致（105,131 440×96），行图标、回合字、常驻字一致。**修了**面板里 Boss 名的难度色。「详情 ▾」三角字形略不同（字体差，没改） |
| 右侧角色状态 | 一致（平均差 6～9，墨迹框差 ≤1px）。状态格 (1044,20) 36×36 位置一致；格里显示哪一个图标按 1.4 秒真实时间轮换，两边截图时刻不同，不逐像素比 |
| 选敌名字旁状态图标 | 位置一致（图标中心、回合数「4」右对齐到 x≈502）。原版截图里图标本体没画出来，只剩「4」；读数显示那个 Sprite_StateIcon 正常（IconSet_1 帧 448,1824、可见、不透明度 255、纹理有效），像是无头截图时的渲染问题，**没认定为原版 bug**，重制照画图标 |
| 伤害数字 | 动作轨迹、颜色、描边对上（原版逐帧读数 x 每帧 ±0.6、y＝0.2/x²＋5x；重制早半帧，是已知的出弹时机差，popup_multi 专项另有逐帧对照）。宽度差：原版字被横向压到约 74%，是原版缺陷，见下 |
| 「自动／变速」按钮压在黑幕之上 | **和原版一致**。原版层次读数：spriteset 里 flash → fade 之后还有 SSEP 加速按钮（Sprite_Button，Balloon.png，(10,10)，不透明度 80），场景里挂机界面 HangUp_Inter、Boss 状态面板也都在 spriteset 之上，淡出黑幕盖不住它们。重制的自动／变速按钮放在 ui 层、黑幕在其下，同一层次 |

## 改了什么

- `modes/xiyou/battle/boss_hp_bar.gd`：
  - 红条（拖尾）画回和蓝条同一行（原版 `_hp_meter_red` 与 `_hp_meter_blue` 同坐标，只取图的下半）。重制原来画到下一行（y＋半高），每场 Boss 战满血时也多一道紫红色带子。
  - Boss 名照 EnemyNameColorByDifficulty 画难度色（`name_color()`，复用 `XEnemy.name_color`）。
- `modes/xiyou/battle/boss_status_panel.gd`：折叠栏与详情标题里的 Boss 名同样画难度色（`name_ink()`，按截断后的字样匹配，同原版 drawText 钩子）。
- `modes/xiyou/battle/damage_popup.gd`：原版缺陷开关 `XDamagePopup.WIDE_TEXT`（默认 true＝修好）。原版 LGP `getTextWidth` 把字号写进 `bitmap._fontSize`（Bitmap 认 `fontSize`），量宽按默认 28 号，位图宽＝28 号字宽＋10，再用 38 号 `drawText(…, 位图宽)` 画，canvas 把整串字横向压窄到约 74%（读数：「1.23万」38 号实宽 117.4、位图宽 96）。重制一直是不压的画法，现在登记成修好；false 照原版按 28 号量宽并横向压缩。
- 新 `tests/xiyou_battle_pixel.gd/.tscn`、`ui_reference/battle_pixel_ref.cjs`、`ui_reference/battle_pixel_compare.py`，`ui_reference/README.md` 加一段用法。

## 优化登记（表格行草稿）

| O-待定 | `modes/xiyou/battle/damage_popup.gd` `XDamagePopup.WIDE_TEXT`、`bitmap_width()`、`squeeze()` | LGP_BetterDamagePopup `getTextWidth` 设的是 `bitmap._fontSize`，量宽仍按默认 28 号；位图宽＝28 号字宽＋10，38 号字用 `drawText(text, 0, 0, 位图宽, 38)` 画，canvas 按 maxWidth 把整串横向压到约 74%（「1.23万」实宽 117.4 压进 96） | 按 38 号量宽，字不压（重制一直这样画，本条补登记） | 原版代码笔误（下划线属性），数字被压扁不是有意设计；Kyo 11-07「原版 bug 要修」 | `XDamagePopup.WIDE_TEXT = false`（位图宽按 28 号量、横向压缩） | cc（八戒） | 待用户决定 |

## 验证

- 语法检查 660 个 .gd 0 问题；工具快速回归 80 秒全过。
- `xiyou_battle_pixel` 窗口模式 17/17（含两边截图、名字颜色、伤害数字位图宽对原版读数 96／60／192 差 ≤1、38 号「1.23万」宽对原版 117.41 差 ≤2）。
- 选测（`选测.py main --list` 列出的 13 个＋`xiyou_popup_multi`、`xiyou_battle_ui`）：15 个场景全部通过（并行 4，578 秒；四个 event_compare 各 500 秒左右，早就超过半上限，不是本条引起）。
- 回退开关 `WIDE_TEXT = false` 有字面量赋值测试（`xiyou_battle_pixel` 的 popup_squeeze_original）；只影响绘制，窗口模式才看得到画面。
- 截图对照数字（修后，`battle_pixel_compare.py`）：Boss 血条框墨迹框四边差 0、名字 ≤2px、状态面板 ≤1px、右侧状态 ≤1px、选敌名字 ≤3px；伤害数字宽度差就是上面的 74% 压缩。

## 变更记录草稿

## 2026-11-10 【cc·八戒·未经审查】战斗画面像素对照：Boss 血条、状态图标、伤害数字（dev.待定）

- 接 gaps11 没做的三个战斗场面，原版 v0.62.12 对 Godot 截图对照（敌群 4 里德，背景涂黑）：新参照 `battle_pixel_ref.cjs`、Godot `xiyou_battle_pixel`、对照 `battle_pixel_compare.py`。无头 Chrome 一次 rAF 补跑多次 updateScene，参照里的动作和截图都改成在 updateScene 包装里按帧做。
- 修：Boss 血条红色拖尾条画回和彩虹条同一行（原来画在下一行，满血也多一道紫红带子）；Boss 血条与 Boss 状态面板里的 Boss 名照原版画成难度色（原来白字）。
- 原版缺陷登记 O-待定 `XDamagePopup.WIDE_TEXT`：原版伤害数字量宽时按 28 号、画 38 号，字被横向压到约 74%；重制不压（默认），false 照原版压。
- 核了「自动／变速」按钮压在黑幕之上：原版加速按钮、挂机界面也都在淡出黑幕之上，一致。
- 玩家可见：Boss 血条下面不再多出一道紫红色的条，Boss 名字按难度显示颜色。
- 验证：语法检查 0 问题；工具回归全过；`xiyou_battle_pixel` 窗口模式 17/17；选测 15 个场景全过。
- 未完成／已知问题：选敌名字旁的状态图标在原版无头截图里没画出来（精灵读数正常），没认定为原版 bug；状态格图标按真实时间轮换，没做逐像素比；「详情 ▾」字形略不同没改。

## 交接板

- 下一步：无新增。gaps11 交付单「没做的」第一条（状态图标／伤害数字／Boss 血条截图对照）由本分支完成，合并 gaps11 时那条可划掉。
- 用户试玩说明：Boss 战顶上的血条下面不再有一道紫红色的带子；Boss 名字（血条和状态面板里）按难度上色，普通难度是天蓝。

## 进度账

- 战斗画面像素对照：Boss 血条、状态图标、伤害数字三个场面补齐对照（不改完成度百分比，只补依据）。

## 可优化（流程／工具／效率）

- 已做：参照脚本按帧排队执行（`battle_pixel_ref.cjs` 的 `at(k, fn)` 队列），避开无头 Chrome 一帧补跑多次 updateScene 带来的帧数漂移。别的用 `await until(()=>n>=t)` 等帧再截图的参照脚本（如 battle_screen_fx_ref.cjs 的消息截图）也有同样风险，建议后续顺手改成同样的队列（归八戒／界面车道，小活）。回退：删掉队列用回 await。
- 建议：轻量浏览器参照（几十秒）这次每次排槽都在 1 分钟内，没遇到 gaps11 说的长排队；保持现状。

## 本分支提交

- 9627f827e WIP：参照、Godot 截图测试、对照脚本、三处修
- （本交付单提交）
