# 交付：luiluu/t278

- 车道／工作者：T278 六维④雷达图共用控件＋角色状态页／人物图鉴展示＋谷雨六维补（cc，Sonnet＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-21 【cc·天启篇·未经审查】六维雷达图共用控件、角色状态页与人物图鉴接入、谷雨输出改 S（dev.待定）

- 依据：T270 六维定稿（私密仓 重制设定/天启篇_角色六维_v0.3定稿.md 第四节、第六节卡 4）；Kyo D234；谷雨 Kyo 11-19 改口。
- **控件** `modes/xiyou/ui/skin/skin_six_dim_radar.gd`（`XSkinSixDimRadar`）：纯绘制，不读存档、不碰战斗。两种用法，T279 怪物图鉴／首领详情照用：
  - 静态 `XSkinSixDimRadar.paint(ci, center, radius, six, opts)`：在任意 CanvasItem 的 draw 回调里画；`six` 就是 `XTianqiSixDim.of_actor／of_enemy／of_knight／of_battler` 的返回。`opts`：`compact`（标签一行）、`font`／`text`／`dim`／`line`／`accent`／`gold`（换字体与色）、`fs`、`highlight`（SS／SSS 档字高光）。
  - 节点：`XSkinSixDimRadar.new()` ＋ `set_six(six, resist_pct)`，`compact`、`show_resist`；悬停给六行说明。
  - 辅助：`points()`（多边形顶点，半径＝档分/8）、`margin()`、`resist_text()`、`tip_text()`。
  - 网底四圈（D、B、S、SSS）＋六轴，顶点圆点；SS／SSS 档位字金色。
- **角色状态页**（新界面 `skin_status_page.gd`）：天启篇时左边角色牌里头像缩小（半径 62→44）、量条间距 46→40，腾出地方在量条下画紧凑雷达，最底一行「控制抗性 +x%」。西游档、`XTianqiSixDim.ENABLED=false` 一行不变。旧布局（皮肤关）不接：天启篇只走新界面。
- **人物图鉴**（`actor_book.gd`）：`status_ops` 天启篇时多一条 `["radar", 六维, x, y, r]`（`paint_ops` 画），位置在「其他」列上方（168／174 个角色没有「其他」技能，有的 6 个其他技能往下让开 `RADAR_H`）；渡鸦 167、173 与光环栏 10 人（56、75、78、80、86、96、102、117、127、142）四列占满放不下，改成抬头行右侧一行字「六维：输出 S·生存 A·…」。西游档与关开关时 ops 与改前一样。
- **谷雨（175）**（Kyo 11-19）：输出 A→S，生存已是 S（实测），辅助 S→A（Kyo 11-21 定降）。`six_dim.json` 加 `_note`；`六维打分.py` 加 `HAND_OVERRIDE` 与按人的 `HAND_REASONS`（重跑不丢）。辅助降 A 后她 2 项 S，过 R3，校验脚本里临时豁免已删。
- **玩家可见文字（全部，待小A 审）**：
  - 维度名：输出、生存、速度、战商、韧性、辅助。档位 E／D／C／B／A／S／SS／SSS。
  - 说明（节点用法悬停才显示，格式「输出 S：…」；小A 文字审定稿）：输出「杀伤与爆发能力（不区分物理与魔法）」；生存「抗击打与保命能力（生命、防御、护盾与回复）」；速度「出手快慢、再动频率与行动节奏」；战商「临战谋略与判断（仅敌方影响出招与选目标）」；韧性「心志稳度与抗控能力（影响控制抗性）」；辅助「团队支援能力（治疗、护盾、增益与援护）」。状态页、图鉴里没挂悬停，只有名字＋档位。
  - 状态页小字：状态页用宽的写法 `韧性·控制抗性 +7%`（C 档 `…0%`，负数用真减号 `…−10%`，U+2212；宽 272 够放）。`resist_text()` 本身仍返回 `控制抗性 +7%`，前缀「韧性·」只在状态页加。
  - 图鉴一行字：`六维：输出 S·生存 A·速度 B·战商 SS·韧性 C·辅助 E`（18 号，起点 x=400，右栏放得下，渡鸦 167、光环栏 127 已截图看过）。
- **截图**（真跑 Godot `--audio-driver Dummy`，工具 `tests/t278_six_dim_shots.tscn`，原尺寸 1280×720，在 `00_项目管理/归档/交付截图/T278_六维雷达/`）：`status_180／175／168／6.png`、`book_180／175／168／6.png`（五条悟、谷雨、米拉、吕布）。
- 偏离：定稿说「悬停或聚焦韧性」才显示控制抗性，我改成状态页常驻一行（验收 2 要「明确展示」，手机没有悬停）；人物图鉴不显示抗性。定稿「状态页：与八项硬属性并列」，新界面页 0 已被参数＋装备占满，改放左边角色牌下方（定稿也允许）。

- 小A 核 547ba5a1f 的 P2-1／P3-1 已修：节点用法 `six`／`show_resist`／`resist_pct`／`opts` 加 setter（重绘，`six` 同时更新悬停），`_draw` 经 `paint_opts()` 把 `compact` 传给 paint；两行模式注释与实际顺序对齐。专项加 5 条断言（radar 33/33）。

## 交接板

- 下一步：小A 文字审（上面一整节）；T279 怪物图鉴、首领详情复用 `XSkinSixDimRadar.paint`。
- 需要用户决定：无（谷雨辅助 Kyo 11-21 已定降 A）。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- 新专项 `xiyou_tianqi_six_dim_radar`（几何、文字、图鉴 ops 十人＋渡鸦＋光环＋「其他」列让位＋西游档＋开关关、状态页新界面两种存档能画）；改 `xiyou_tianqi_six_dim`（谷雨 S S C B B S、总分 29、输出 S、生存≥S）。本机直接跑（headless，并行测试排队太久改直跑）：radar 28/28、six_dim 69/69、six_dim_resist 69/69、actor_book 28/28、actor_book_review 6/6、ui_skin_1c 81/81、guyu_art 171/171、enemy_table 9/9（actor_book_compare 是工具场景跳过）。云端选测没跑，交总装。
- `语法检查.py` 过（1130 个 .gd 0 问题）；`天启篇数据校验.py` 全部通过。

## 本分支提交

- （见回执）
