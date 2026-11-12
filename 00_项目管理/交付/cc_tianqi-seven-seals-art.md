# 交付：cc/tianqi-seven-seals-art

- 车道／工作者：天启篇七印祭坛美术接入／cc（七印美术线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-12 【cc·七印美术·未经审查】天启篇七印祭坛美术接入：首领新图、装备图标、徽记与演出（dev.待定）

- 素材：Kyo 11-12 交付的七印祭坛美术 26 项定稿（源 `03_再刷重制_Godot/02_内容与素材/新美术/TianqiQiyin_v1/`，Git 排除）。新导出脚本 `03_再刷重制_Godot/03_转换工具/天启七印美术导出.py`（自己解 zip，用 ffmpeg 裁基线、缩尺寸）把 130 张成品图写进 `content/tianqi/qiyin/`（来源、尺寸、谁读见同目录 README）。
- 新类 `XTianqiQiyinArt`（`modes/xiyou/core/tianqi_qiyin_art.gd`）：
  - 首领战斗图：殉印里副本 Boss「白衣的魂」、默印 Boss「守默者」、七首之龙不再借原版敌人的图（`qiyin_altar.json` 各印 `boss.battler`、`qiyin_dragon_run.json` `fight.battler`；`XDB.img_path` 认 `sv_enemies/Tianqi_Qiyin_*`）。母版按规格裁到脚底基线、缩到逻辑尺寸（M 档 256×232、L 档 512×464），1 倍画；白衣的魂悬浮不画影子（`appearances.json`）。七首之龙躯干一层、七个头各一层，每断一首藏一个头（按揭印顺序，`XTianqiQiyinDragonRun._check_cuts` 记）；守默者单数回合（默印不寂静、放大招的回合）换「香炉燃起」那张。借来的敌人掷到神话时的偏色对新图不生效。
  - 装备图标：七印套装 42 件、毕业武器 12 类、「不立文字」（那类武器左下角叠一卷空白卷轴，叠层从母版缩到 16 格）12 个、神器 5 件，图标号 310000 段（`XUI.icon_texture` 分流），新做出来的七印装备不再借底子装备的图标。物品状态页 128 大图标走通用最近邻放大。
  - 小图标编号：道具（印钥、印屑、残页、龙血、封着的装备）、里副本规则 7、套装武器效果 8、骑士遗物（完整／残）与徽记，310300 起；祭坛「印钥／印屑」、印屑、龙血几句台词带 `\I[号]`。
- `XTianqiQiyinShow`：七印徽记、神器大图、龙隙叠层走原来留好的 art 路径；七道印的灯改画徽记（暗着去色压暗，亮起渐变回原色）。顺手修两处：`art()` 取过的图留着（在 `_draw` 里现取的贴图画完就被释放，徽记画成白块）；套装件掉落时没设本印，中间那枚印一直画成没颜色的白圆。
- 实机截图看过：七首之龙满头、断三首；白衣的魂；守默者两态；神器、龙隙、掉落演出；全部图标表。
- 没接：头像框 P7、战斗法阵 P8（方案 6.5 节第 6 条的「外观」系统还没做：集齐一套解锁、跨存档保留、开场脚下法阵），图先放在 `content/tianqi/qiyin/frames/`、`circles/`；规则、效果状态图标和骑士遗物只编了号，没有显示它们的界面（遗物数据也还没定）。
- 新专项 `tests/xiyou_tianqi_qiyin_art`（43 项）。
- 玩家可见：无（天启篇只在 Kyo 本地，发行开关照旧关）。

## 交接板

- 下一步：七印「外观」系统（集齐一套六件解锁本印头像框，跨存档保留；装着的角色开场脚下亮本印法阵、转一圈、常驻淡光），接上 P7、P8；O1／O2 状态图标等战斗里有显示自定义层数的地方再接。
- 用户试玩说明：天启篇进殉印、默印里副本打到 Boss，看新画的白衣的魂、守默者（单数回合香炉燃起）；进龙隙打七首之龙，每断一首少一个头。新掉的七印装备有自己的图标；掉落、神器、龙隙演出用上徽记、神器大图、裂缝图。
- 需要用户决定：无。

## 优化登记

| 编号 | 位置 | 原版 | 重制 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_qiyin_art.gd` `XTianqiQiyinArt.ENABLED` | 七印装备借底子装备的图标，里副本 Boss 与七首之龙借原版敌人（普拉顿等）的战斗图 | 换成 11-12 定稿的新画：装备 59 枚图标，三个首领新图（龙断首藏头、守默者两态） | 七印祭坛美术交付清单（Kyo 11-12 定稿） | `XTianqiQiyinArt.ENABLED = false`（已经做出来的装备图标号存在存档里，照样画新图） | cc | 保留 |

## 进度账

- 无（天启篇不进重制主表）。

## 可优化（流程／工具／效率）

- 已做：美术成品图由导出脚本一次生成（裁基线、缩尺寸、改名都在脚本里），美术重出只要重跑脚本再 `godot --import`。
- 建议：战斗精灵现在只认「裁到基线的 1 倍图」；规格 v0.6 想要的「2 倍图＋scale 0.5＋平滑采样」引擎还没支持（`battler_sprite` 非归一档一律最近邻）。给 `appearances.json` 加一个 `smooth` 选项就能用 2 倍图，Retina 上更清楚；归画面车道。

## 验证

- 语法检查通过；`xiyou_tianqi_qiyin_art` 43/43；`工具回归.py` 全过。
- 选测（`xdb.gd`、`battler_sprite.gd`、`xui.gd` 和新图片让选测判整轮，车道不跑全量）：`xiyou_tianqi*` 全部 40 个、`xiyou_appearance`、`xiyou_actor_looks`、`xiyou_actor_sv_compare`、`xiyou_battle_events`、`xiyou_battle_log`、`xiyou_battle_pixel`、`xiyou_battle_ui`、`xiyou_costume_battle`、`xiyou_quality_icons`、`xiyou_item_list`、`xiyou_determinism`、`xiyou_enemy_book`、`xiyou_enemy_state_icon`，53 个全过（合 main 之后跑的）。
- 没跑：`xiyou_rules*`、事件对照四段（`xdb.gd` 只在 `sv_enemies` 找不到图时多一次前缀判断，`battler_sprite` 只对 `Tianqi_Qiyin_*` 图名的敌人做事；请总装合并时按影响面选测）。

## 本分支提交

- 18f20646d 天启篇七印祭坛美术接入（一）：首领新图、装备图标、徽记神器大图龙隙
- 158fc67fb 天启篇七印祭坛美术接入（二）：小图标编号、祭坛台词图标、演出七道印换徽记
