# 交付：cc/tianqi-seven-seals-look

- 车道／工作者：天启篇七印外观与剩余美术接入／cc（七印美术线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·七印美术·未经审查】天启篇七印外观：头像框、战斗法阵；骑士遗物与徽记换新图（dev.待定）

- 接上一批（dev.515）没接的美术。Kyo 11-12「做接着做的」；素材还是 `新美术/TianqiQiyin_v1` 那一批，导出脚本重跑多出骑士徽记 128 母版（`content/tianqi/qiyin/badges_128/`）。
- 新类 `XTianqiQiyinLook`（`modes/xiyou/core/tianqi_qiyin_look.gd`），按七印祭坛方案 v0.4 第 6.5 节第 6 条：
  - 解锁：一印的套装六件都揭到过，就解锁这一印的外观，跨存档保留（配置新键 `codexTianqiQiyinParts`，记「印:部位」，同骑士徽记的做法，不带数值）。印库揭开时记；开祭坛时把本档印库里已经揭开的补记一遍（这功能之前揭的也算）；凑齐那一下在祭坛说一句。
  - 佩戴：祭坛菜单多一项「外观（七印头像框）」（有解锁才出），给出战的人挑一印或不戴，记在本档七印进度 `looks`。只是外观。
  - 头像框（P7）：主菜单这一行的头像缩进框的窗口（128 格里 x34 y38 宽高 60），框盖在上面；没戴的照原样画。
  - 战斗法阵（P8）：戴着的角色脚下一圈本印法阵（俯视正圆压成 42% 的椭圆，加色混合）。开场亮起转一圈，之后常驻淡光、慢慢转、呼吸闪烁，飘几颗本印颜色的光点；倒下熄掉，摘了就没。
- 骑士遗物（`XTianqiRewards.make_item` relic）用 O3 新图标，残缺版用残图；选线竖卡「已通关」那张卡右上角画本线骑士徽记。
- 截图看过：主菜单四人戴四印的框、战斗脚下法阵、选线卡两枚徽记。
- 没做：七套集齐给称号（方案同条后半句；还没有接得上的称号系统）；O1 规则、O2 效果状态图标仍只有图标号，战斗里还没有显示自定义层数的地方（疫、砝码等是七印效果模块内部的计数）。
- 专项 `tests/xiyou_tianqi_qiyin_art` 加到 62 项。
- 玩家可见：无（天启篇只在 Kyo 本地，发行开关照旧关）。

## 交接板

- 下一步：七套集齐的称号等称号系统；O1／O2 状态图标等战斗里有自定义层数显示时再接。
- 用户试玩说明：天启篇在七印祭坛把一印的六件都揭开后，祭坛菜单多「外观」，给人戴上：主菜单头像换成带框的，进战斗脚下亮本印法阵。骑士遗物（35 层影子给的残缺版、36 层骑士给的完整版）有新图标；通关过的线在选线卡上有骑士徽记。
- 需要用户决定：无。

## 优化登记

| 编号 | 位置 | 原版 | 重制 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_qiyin_look.gd` `XTianqiQiyinLook.ENABLED` | 没有七印外观 | 一套六件揭到过解锁本印外观（跨存档）；主菜单头像框、战斗脚下法阵；不加数值 | 七印祭坛方案 v0.4 第 6.5 节第 6 条，Kyo 11-11 23:47「战斗中再给个特效」 | `XTianqiQiyinLook.ENABLED = false`（记下的解锁和佩戴留着） | cc | 保留 |

## 进度账

- 无（天启篇不进重制主表）。

## 可优化（流程／工具／效率）

- 已做：在 `_draw` 里现取的贴图（`XUI.face_texture` 这类每次新建的 AtlasTexture）画完就被释放、画成白块，这次又碰到一次（上一批是七印徽记），本模块按键缓存。
- 建议：`XUI.face_texture` 自己缓存（同 `XMVCanvas.face` 的 `_cache`），以后谁在 `_draw` 里用都不会白块；改公共界面函数，归界面车道。

## 验证

- 语法检查通过；`xiyou_tianqi_qiyin_art` 62/62。
- 选测（`xconfig.gd`、`battler_sprite.gd`、`menu.gd` 和新图片让选测判整轮，车道不跑全量）：`xiyou_tianqi*` 全部 40 个、战斗精灵相关 8 个（`xiyou_appearance`、`xiyou_actor_looks`、`xiyou_actor_sv_compare`、`xiyou_battle_events`、`xiyou_battle_log`、`xiyou_battle_pixel`、`xiyou_battle_ui`、`xiyou_costume_battle`）、`xiyou_determinism`、主菜单与设置相关 16 个（`xiyou_actor_book`、`xiyou_flow`、`xiyou_hud`、`xiyou_panels`、`xiyou_options_misc`、`xiyou_notice_options`、`xiyou_hangup_options`、`xiyou_party`、`xiyou_ui_pixel`、`xiyou_ui_page_details`、`xiyou_save_page`、`xiyou_review135`、`xiyou_item_bag`、`xiyou_skill_page`、`xiyou_map_hotkeys`、`xiyou_list_paging`），65 个全过；`工具回归.py` 全过。
- 没跑：`xiyou_rules*`、事件对照四段（`xconfig.gd` 只多一个默认键和读档分支，`battler_sprite` 只对戴了外观的角色挂节点；请总装合并时按影响面补）。

## 本分支提交

- 7a08ee92b 天启篇七印外观：头像框、战斗法阵；骑士遗物与徽记新图
