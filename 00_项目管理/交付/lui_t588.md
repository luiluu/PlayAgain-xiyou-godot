# 交付：lui/t588

- 车道／工作者：T588 界面小修（cc，Sonnet 5.5＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-28 【cc·未经审查】西游法宝说明卡：等级只写 a/b、属性不重复；吞噬升级写最低装备品级（dev.待定）

- 玩家可见：法宝说明里原来的两行绿字（当前累计、满级累计）换成一行绿字「法宝等级：当前/本层上限」和一行当前加成；不再显示满级数值。吞噬升级（喂装备）时能看到当前这一级最低要吃什么品级的装备。
- 改动（`modes/xiyou/ui/help_card.gd`，开关 `XHelpCard.FABAO_BRIEF_T588`，设 `false` 回原写法）：
  - 一般法宝：「法宝等级：a/b」（绿）＋「法宝加成：…」（白）。a＝`XMagicWeapon.effective_level`，b＝`XMagicWeapon.max_level`（含楼层上限）。
  - 织神天梭：顶部八项已含成长，不另写加成行（原来和「当前累计」重复）；原「当前等级」行换成同一写法。
  - 破限之心：原「当前等级：…；经验：…」拆成「法宝等级：a/b」＋「经验：…」；形态行里的「等级上限」去掉。
  - 同时不再显示「保留 N 级」「已满级」「60 级进化后加成翻倍」（翻倍说明并进进化行，见下条返工）。
- 返工（小o 核查 P2×3、P3×2，P0／P1 无）：
  - P2-1：法宝实例自带平加（补天石强化、原件基础属性）时，成长并进顶部八项，不另写「法宝加成」行，同一项只出现一次；没有平加的法宝照旧写加成行。独立百分比特效照旧单列。只改显示，实例属性不动。
  - P2-2：装备详情缓存键里的等级、经验只在非天启篇存档加，另一种存档的缓存键与改动前相同。
  - P2-3：打开法宝操作菜单时给底部两行提示留位置，强化记录多到放不下时分 2～4 栏排（一条不少）；没有提示行时照原版一栏。分栏时 `XMVText` 换行宽传 0（它拿绝对 x 比整窗宽，传栏宽会一直换行卡死，专项跑出来过）。
  - P3-1：三件专属法宝的进化行写成「…级时进化为…，每级成长翻倍，并获得…」（只改显示，实例备注不动）。
  - P3-2：存档等级超过本层上限时，等级行后写「超出本层上限的等级会在推进楼层后恢复生效」。
- 吞噬升级最低品级（开关 `XHelpCard.FABAO_FEED_GRADE_T588`）：门槛读喂入判定用的 `XFabaoFeed.min_grade(当前等级)`，品级名和颜色用现有七档品质。写在法宝说明卡上；打开法宝操作菜单（「喂入」几行）时，右侧信息窗底部另写等级和品级两行（`item_scene.gd` `_paint_fabao_feed`）。法宝到本层上限时不写（喂不进去）。
- 顺带：装备详情页的重排判断加上法宝等级、经验（`gear_detail.gd` `set_item`），喂升级后详情不会停在旧等级。
- 只对非天启篇存档生效；天启篇卡面开关开、关逐行相同（专项 `tianqi.unchanged.*`、`tianqi.menu_lines.*`）。
- 冒号照游戏说明卡的写法用全角「：」。

## 交接板

- 下一步：进下个西游补丁；新增的玩家可见文字（等级行、最低品级行、超上限提示、进化行）待小A 审。
- 用户试玩说明：背包里选一件法宝看说明；按确定打开操作菜单，右下角能看到吞噬升级的最低品级。
- 需要用户决定：见下「偏离与待定」。

## 偏离与待定

- 属性怎么留：Kyo 原话只说不重复写。一般法宝除那两行外没有别处写成长属性，所以保留一行「法宝加成」（只写当前值，白字）。若 Kyo 要连这行也去掉，删 `_apply_fabao_scale_rows` 里 `法宝加成` 那一行即可。
- 织神天梭的「法宝经验」行照旧保留（不是等级信息）。
- 新界面（只给启封用）没动版式；对照图是原版界面的物品页。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 建议：`新建工作树.sh --补齐` 本次在「godot --import 等槽」上等了约 29 分钟（别的车道本机跑测试占满共用槽）；界面小单可考虑导入不占测试槽或优先排队（归工具车道）。

## 动了的共用函数和开关

无（只改 `modes/xiyou/ui/` 下的界面脚本和测试）。

## 截图（`00_项目管理/交付/luiluu_t588_shots/`）

- `xiyou_zhuxian_before／after.png`、`xiyou_yunshang_before／after.png`、`xiyou_feed_menu_before／after.png`
- 返工新增：`xiyou_reinforced_card_after.png`（装 3 块补天石的卡，八项各一次）、`xiyou_feed_menu_12records_after.png`（12 条强化记录的操作菜单，不重叠）
- 对照组（另一种存档，应无变化）：`other_*_before／after.png`。菜单背景有飘动光点，不做逐像素比；卡面逐行相同由专项断言。
- 出图工具：`tests/t588_shots.tscn`（带 `--audio-driver Dummy`）。

## 验证

- 本机：`xiyou_fabao_card_t588`、`xiyou_fabao_99_scale`、`xiyou_gear_detail`、`xiyou_fabao_rework`、`xiyou_character_gear_help`、`xiyou_yunshang_shop`、`xiyou_help_card` 全部通过；语法检查、工具回归、`发行空壳.py check` 通过。
- 旧测试调整：`xiyou_fabao_99_scale` 的卡面段关两个新开关量原写法；`xiyou_character_gear_help`、`xiyou_yunshang_shop`、`xiyou_cat_help` 和原版逐行比，关掉品级行。
- `xiyou_fabao_card_t588` 返工后 127/127（原 62 条＋返工断言）。
- 返工后本机复跑：`xiyou_fabao_card_t588`、`xiyou_fabao_99_scale`、`xiyou_gear_detail`、`xiyou_fabao_rework`、`xiyou_magic_level`、`xiyou_orb_ui`、`xiyou_help_card` 7/7 通过；语法检查、`发行空壳.py check`、工具回归通过。
- 以下云端两条是返工前的记录；返工后的结果见本节末尾。
- 云端选测通过：93 个场景、2 片，提交 ee21f81366，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/46102257227
- 前一轮 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/46098581733 挂 1 个：`xiyou_cat_help`（和原版逐行比，多了品级行），已在对照里关掉品级行；同轮 `xiyou_tianqi_deck_phys_amp` 偶发一次（并行失败、单跑通过）。

## 本分支提交

- 9eb155e1d 实现、专项、截图
- ee21f8136 小猫说明卡对照、交付单
