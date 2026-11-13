# 交付：cc/sukuna-art

- 车道／工作者：宿傩新美术接入／cc（项目线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·未经审查】宿傩新美术接入：行走、常态战斗、完全体与两态锚点（dev.待定）

- 依据：Kyo 11-13 审过宿傩新美术，要求接入主工程并随 0.01.08 补丁发出（「这个也进0.01.08」）。素材来自 Codex 的 `Sukuna_Godot_Integration.zip`（隔离工程 101 项检查通过）。
- 新图放项目自有目录 `content/sukuna/img/`（u4 四方向三帧行走 144×192、常态战斗图 576×384、四手完全体 52 张 64×64），`XDB.img_path` 在 `XSukuna.ART` 开着时先读这里，重跑同步不会盖掉。八帧左走样段是独立预览，没进工程。
- 一并应用包里的 `宿傩战斗锚点.patch`：`XAppearance.PROFILES` 两档改成 Codex_Sukuna_SV [64,64,11,3,53,61]、Codex_Sukuna_QFull [64,64,11,3,52,61]，两态待机可见高都是 58、脚底都在第 61 行。旧档留在 `SUKUNA_OLD_PROFILES`，新加 `XAppearance.profile_of(key)` 按开关选；`actor_advanced.gd`、`actor_book.gd` 改用它。
- 回退：`XSukuna.ART = false`，旧图和旧档一起回来。
- 测试：新增 `tests/xiyou_sukuna_art.tscn`（24 项：路径、四向三帧、18 动作取图、52 帧全读、常态↔完全体切换、两态待机实测高 58／脚底 61／缩放一致、回退）；`xiyou_actor_looks` 宿傩缩放断言 72/56 改 72/58。
- 玩家可见：宿傩换上新画的行走图、战斗图和四手完全体动作。

## 交接板

- 下一步：0.01.08 补丁带上 `content/sukuna/`（不在发行 DENY 里，导出会带上）；宿傩特效包（神灶·开、伏魔御厨子展开、领域背景、五个状态图标）的游戏内接线另在 cc/sukuna-fx 做。
- 用户试玩说明：宿傩在地图上走路、战斗中常态和完全体（进阶 3）都换成新图，两态待机同高、脚底对齐。
- 需要用户决定：无

## 进度账

- 无（美术替换，不改完成度）

## 验证

- `语法检查.py`：815 个 .gd，0 个问题。
- 选测 `选测.py main --list` 因新增图片判「整轮」；按车道规矩不跑全量，手跑相关专项全过：xiyou_sukuna_art 24/24、xiyou_actor_looks 34/34、xiyou_sukuna_battle 700/700、xiyou_actor_book 28/28、xiyou_actor_book_review 6/6、xiyou_appearance 34/34、xiyou_actor_advanced 33/33、xiyou_advance_v108 9/9、xiyou_advance_reads 8/8、xiyou_battle_speed 34/34、xiyou_cat 1033/1033、xiyou_costumes 27/27、xiyou_change_clothes 32/32、xiyou_actor_modules 56/56、xiyou_black_flash_ui 16/16、xiyou_character_help_dyn 255/255。
- 待交叉核查：xdb.gd（img_path 前置分流）、appearance.gd（profile_of、PROFILES 两档）。

## 可优化（流程／工具／效率）

- 建议：`选测对照.json` 对 `content/<角色>/` 下的新图片判「整轮」，可以改成「引用该目录的专项＋外观专项」（省一次整轮，归工具车道）。

## 本分支提交

- 7359f7ef0 宿傩新美术接入：行走、常态战斗、完全体 52 帧与两态锚点（XSukuna.ART）
