# 交付：cc/orb-fx-tiers

- 车道／工作者：T047 球框特效按档位分四种（cc 车道，Opus 5.5＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·天启篇·未经审查】装备球框特效按档位分四种：灵焰外溢、七印封缄、双星巡轨、微光扫框（dev.待定）

- 依据：D113（Kyo 11-16）；小o 小样 `gpt/orb-fx-dirs` 9bae3eea8（01 微光扫框、02 七印封缄、04 灵焰外溢、05 双星巡轨，03 金刃追光不用）；装备环样式设计 v0.2 第 1.1 节；在 T044（dev.648）的 `ORB_TIERS`／`ORB_FX` 上接着改。
- 新文件 `modes/xiyou/ui/skin/skin_orb_fx.gd`（`XSkinOrbFx`）：把小样 `generate.py` 的四种像素动效移植成程序绘制，64×64 原生像素画布、二值 alpha、半径 > 28 剪掉；每圈 36 帧（小样 12 帧，按小样建议升采样），按需生成一次缓存成贴图，每颗球每帧只多一次贴图绘制。相邻球错半周。
- `XTianqiRingStyle.ORB_FX` 默认改为 `"tiers"`，新函数 `fx_tier(装备, 槽位)` 判档，多档命中取高（灵焰 > 七印封缄 > 双星 > 微光）：
  - 灵焰外溢：刻过七印的专属武器、刻了终焉级异化核的武器；
  - 七印封缄：毕业武器；
  - 双星巡轨：传家宝、专属武器、独特物件，不论哪一栏（套中性旧金斜角框）；
  - 微光扫框：神话及以上武器，只槽位 0、1，叠在 T044 的淡框上（两像素宽亮弧骑在淡框描边上扫过）。
- 动效档不是「全部」时四档都停在一帧（小样静帧的相位），框和特效照画，辨识度不丢。
- `XSkinRingNav` 加 `_draw_orb_fx`，斜角框和淡框后面各接一次；`skin_equip_page.gd` 把淡框的 `fx` 也传给 nav。环纹指纹在 tiers 档带上特效档（同框同色换档也会刷新），sweep 档指纹与 T044 一字不差。
- 回退：`XTianqiRingStyle.ORB_FX = "sweep"` 就是 T044 原样（特殊武器同一微光、神话淡框无特效、传家宝／独特物件／终焉核武器不出框）；`ORB_TIERS = false` 回到 T044 之前。西游档不变（环纹只天启篇生效）。
- 玩家可见：天启篇装备页，刻了七印的专武和带终焉核的武器球外冒青紫焰舌；毕业武器的框上七枚小符印慢慢换位；传家宝、专属武器、独特物件不论在哪一栏都有两颗星沿斜轨绕球；神话武器的铜橙细边上有一段微光扫过。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_ring_style.gd` `ORB_FX`／`fx_tier`；`modes/xiyou/ui/skin/skin_orb_fx.gd`；`skin_ring_nav.gd` `_draw_orb_fx` | （天启篇，T044）特殊武器同一种微光扫过，神话淡框无特效，传家宝／独特物件／终焉核武器无框 | 球框特效按档位分四种（D113）：灵焰外溢（七印刻印专武、终焉核武器）＞七印封缄（毕业武器）＞双星巡轨（传家宝、专属、独特物件，任意栏）＞微光扫框（神话及以上武器，槽位 0、1，叠淡框）；多档取高；减动效停一帧 | D113（Kyo 11-16），小o 小样 T045 | `XTianqiRingStyle.ORB_FX = "sweep"` | cc | 保留 |

## 分档口径

项目经理cc 11-16 回复确认（Kyo 看截图时再一起确认）。代码在 `XTianqiRingStyle.fx_tier`：

| 档 | 认什么 | 代码判据 | 栏位 |
| --- | --- | --- | --- |
| 灵焰外溢 | 刻过七印的专属武器 | `qiyin.kind == "engrave"`（`XTianqiQiyinEffects.mark_of`） | 武器（七印标记本身只打在武器上） |
| 灵焰外溢 | 刻了终焉级异化核的武器（骑士／影子／鸿钧掉的核） | `alien.tq.level == "zhongyan"` 且 `XQuality.gear_kind == "weapon"`（`XTianqiAlienGear.attach` 写的字段）；防具刻了终焉核不算 | 武器 |
| 七印封缄 | 毕业武器（13 把） | `qiyin.kind == "weapon"` | 武器 |
| 双星巡轨 | 传家宝 | 旧档 `<quality:9>`（`XQuality.legacy == 9`，`XQuality` 头注释「9传家宝」） | 任意栏 |
| 双星巡轨 | 专属武器（未刻印的；刻了七印的被灵焰盖过） | `XEquipment.is_exclusive`（`<req_actors:>` 或装备要求里有角色） | 任意栏（专属只有武器） |
| 双星巡轨 | 独特物件 | 备注含 `<KyoUnique`（同 `XTianqiAffixRoll.general_artifact` 的口径） | 任意栏 |
| 微光扫框 | 神话及以上武器 | `XQuality.grade >= 6` 且是武器 | 只槽位 0、1 |

多档命中取高：灵焰 > 七印封缄 > 双星 > 微光（`XSkinOrbFx.RANK`）。

## 交接板

- 下一步：Kyo 看 `归档/交付截图/cc_orb-fx-tiers/` 截图确认四档效果和分档口径（尤其 13 栏混合那张花不花）；七印封缄、双星在原尺寸下偏弱的问题见下「我不同意的地方」第 1 条，要不要放大由 Kyo 定。
- 用户试玩说明：同上「玩家可见」。
- 需要用户决定：分档口径（上表）；七印封缄、双星是否加粗加亮。

## 进度账

- 环纹（球框）：D113 落地，完成度不变（无主表项）。

## 我不同意的地方

1. **七印封缄、双星在实际尺寸下偏弱**：小样 GIF 是 4 倍放大看的；接进游戏按原生像素画，3×3 的小符印和 1 像素的星轨落在亮色图标上（截图里的骷髅），静帧几乎看不出来，动起来好一些。灵焰最醒目，微光本来就该淡。我没改小o 的设计，只把微光改成两像素宽（一像素叠在 2px 淡框上完全看不见，实看截图后改的）。如果 Kyo 也觉得弱，建议让小o 出一版 2 倍像素（或加亮星轨、符印配色），我这边只要换 `XSkinOrbFx.image` 的画法，接口不动。
2. **双星不分栏位**：13 栏都放传家宝／独特物件时，会有很多颗球同时带双星（见 13 栏混合截图，6 颗）。现在全部剪在半径 28 以内，不压栏位名、不超出 T044 的框外沿；但「花不花」请 Kyo 看图定。
3. **七印封缄的符印颜色沿用小样**，没按七印 `seal_tints` 重映射：红印、震印、灰印的印色偏暗，3×3 的小符印在 1 倍下看不清。
4. `ring_styles.json` 里 `orb_tier._note` 写着「不加特效」，D113 后已不准；数据表不在本单独占范围，没改，请总装或下一张碰数据表的单子顺手改成「D113 起叠微光」。

## 可优化（流程／工具／效率）

- 已做：专项加了 `-- --fx-shots=<目录>` 截图模式（四档 × 16:9／20:9＋13 栏混合，带环区 2 倍放大图），下次调特效直接重出；删掉该分支即回退。
- 建议：`xiyou_tianqi_ring_style` 截图模式下一直有 `Invalid polygon data, triangulation failed`（T044 的 `--orb-shots` 也有，不是本单引入），归界面车道查一下哪块多边形退化。

## 验证

- `语法检查.py`：977 个 .gd，0 个问题。
- 专项 `xiyou_tianqi_ring_style`：166/166 通过（T044 时 116 项）。新增断言逐条对应验收：
  1. 分档：`fx_flame_engraved_exclusive`、`fx_flame_zhongyan_weapon`、`fx_seal7_graduation`、`fx_stars_exclusive`、`fx_stars_any_slot`（传家宝防具、神器栏独特物件）、`fx_glint_mythic_outline`；反例 `fx_zhongyan_armor_no_flame`、`fx_lower_alien_no_flame`。
  2. 多档取高：`fx_rank_order`；两档同时命中 `fx_two_tiers_flame_over_stars_glint`、`fx_two_tiers_seal7_over_glint`、`fx_two_tiers_flame_over_seal7`、`fx_two_tiers_seal7_over_stars`、`fx_two_tiers_stars_over_glint`、`fx_two_tiers_zhongyan_heirloom`。
  3. 栏位：`fx_glint_weapon_slots_only`、`fx_glint_not_on_armor_slot1`、`fx_tier_unit_glint_slot_gate`、`fx_stars_any_slot`；灵焰／七印封缄只认武器见 `fx_zhongyan_armor_no_flame`。
  4. 帧图：`fxframe_<档>_binary_alpha`／`_within_28`／`_no_red`／`_animates`，最大半径 灵焰 27.02、七印封缄 27.80、双星 25.55、微光 25.00（和小样 `验证.json` 对得上）；减动效静止 `fxnav_still_motion_0`（关）、`fxnav_still_motion_1`（简化）；`fxnav_full_animates`、`fxframe_cached`。
  5. 回退：`fx_sweep_rollback_t044`、`fx_sweep_rollback_zhongyan_none`、`tier_sweep_rollback_no_heirloom`，T044 原有的 `tier_*` 断言整段改在 `ORB_FX="sweep"` 下跑、全过；`fx_tiers_switch_off_empty`。
- 性能（无头、本机 M1 Pro，`_draw_layers` 每帧微秒、200 帧平均，同 T034 `LINK_CACHE_US` 的口径；13 栏全亮＝13 颗斜角框＋特效，动效全部）：无特效 142.6、T044 sweep 475.2、双星 279.5、灵焰 315.7、七印封缄 277.0、混合 230.0。四档都比 T044 的 sweep（每颗 6 条折线）便宜，因为每颗只多一次贴图绘制；帧贴图首次用到时生成（每档最多 36 张 64×64）。
- 截图（`00_项目管理/归档/交付截图/cc_orb-fx-tiers/`，动效全部、定相位；选中移到别处免得红框盖住；每张带 `_放大` 环区 2 倍图）：
  - `球框四档_灵焰外溢_16x9.png`／`_20x9_触屏130.png`（0 号刻印专武、1 号终焉核武器）
  - `球框四档_七印封缄_16x9.png`／`_20x9_触屏130.png`（两把毕业武器）
  - `球框四档_双星巡轨_16x9.png`／`_20x9_触屏130.png`（专武＋传家宝防具＋神器栏独特物件）
  - `球框四档_微光扫框_16x9.png`／`_20x9_触屏130.png`（两把神话武器）
  - `球框四档_13栏混合_20x9_触屏130.png`（13 栏都有东西：灵焰、微光、6 颗双星、其余普通件）
  - 复现：`godot --audio-driver Dummy --path 01_Godot工程 tests/xiyou_tianqi_ring_style.tscn -- --fx-shots=<目录>`
- `检查.sh --affected main --cloud`：通过，退出码 0（提交 0b0a0a5bb；云端基准 e776d9a3c8，391 个场景 16 片全过；守卫、发行空壳覆盖等非 Godot 检查全过）。
- 工具快速回归：第一次「选测替身与 检查.sh 解析」挂 1 项（当时与云端选测的 `检查.sh` 同时在跑），单独重跑全部通过（rc=0），记为偶发。

## 本分支提交

- 见 `git log main..cc/orb-fx-tiers`
