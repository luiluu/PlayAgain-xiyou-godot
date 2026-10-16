# 交付：claude/bajie-mv-anim

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_12，中等努力）
- 状态：进行中

## 变更记录草稿

## 2026-10-17 【Claude·八戒·未经Codex检验】战斗技能动画按 Sprite_Animation 逐帧：色相、目标闪光、屏幕闪光、隐藏、移除时机（dev.待定）

- `MVAnimation`（`battle/mv_animation.gd`）改成 Sprite_Animation 原样逐帧：`_duration`／`_delay`／`currentFrameIndex`，每帧 updateMain、updateFlash、updateScreenFlash、updateHiding；animation1Hue／animation2Hue 转色相（`HUE_SHADER`、`cell_material` 从 `XDropPopup` 上移到这里）；flashScope 1 目标闪光（目标混合色，不透明度每帧 ×(d−1)/d）、2 屏幕闪光（子节点画满画面、盖住之前画的东西）、3 隐藏目标；播完（`_duration` 到 0）的下一帧才移除（原来早一帧），移除时还原目标混合色与显示再发 `done`。动画音效不随动画移除截断（正式版 AudioManager.playSe 独立播放；原来四倍速下 6 帧就被切掉）。
- `XDropPopup.DhAnimation` 变成薄子类：只剩「位置取图标上一帧坐标」与「由 step 逐帧推进」，色相、闪光、移除都走 `MVAnimation`；dev.069 的两组 240 帧对照照常全过。
- 战斗：`XBattleScene._start_animation` 给动画设目标（被打的 `XBattlerSprite`）并每帧跟随目标位置（updatePosition）；头上／中心按目标未缩放的帧高（Sprite_Animation 用 `_mainSprite.height`，角色身体缩放 0.75 不算：角色中心原来偏低 8 像素）。`XBattlerSprite` 加 `set_anim_blend`／`set_anim_hidden`：身体材质合并成 `BODY_SHADER`（神话敌人色相＋Sprite.setBlendColor 混合色，用到时才建），`otb_bar` 跟着改名。删去无人用的 `_center`。
- Animations.json 里 132 条 MZ 格式（Effekseer，无 frames/timings）没有技能／物品／武器用到；`MVAnimation.usable` 挡掉，不再可能因缺字段报错（地图经 `MVAnimation.play` 同样受挡）。
- 地图：`map_scene.show_animation` 不设目标，flashScope 1/3 不作用（正式版会闪／隐藏地图角色，见遗留）；rate 4 与「播完下一帧移除」同战斗，事件 212 等待完成随之晚一帧（同正式版 isAnimationPlaying）。
- 参照：`ui_reference` 战斗工具加 `__animRef`（`suite()` 五组：动画 3 目标＋屏幕闪光、四倍速版；14 转色相 135；24 隐藏目标，敌人与角色），`serve.py` 加 `POST /__ref_json/<名字>`（只写截图目录）。读数存 `tests/fixtures/mv_anim_oracle.json`。
- 测试：新 `tests/xiyou_mv_animation`（19 项）在真实战斗画面经 `_start_animation` 逐帧比：已移除、相对目标位置、剩余时长、帧序、可见格数、目标混合色、目标显示、屏幕闪光，五组全部逐帧一致；另查转色相材质与地图无目标动画播完时机。`xiyou_battle_options` 的动画时长改成「_duration 帧后不再播放、下一帧才移除」；`xiyou_drop_dh` 改用 `MVAnimation.cell_material`，退出前停音效等 0.5 秒。
- 工程规则检查（框架维护约定「随重制照做的工程规则」）：结算只在规则层——动画只改画面与演出时长，`xiyou_battle_options` 的不同显示／变速结算一致仍通过；动画不用随机数；无缓存失效问题（格子材质按色相＋混合方式共用，不依赖存档数据）。
- 验证：见下「状态」。
- 遗留：①地图动画的目标闪光／隐藏没接（要改 `map_scene` 与地图角色，属车道 A 文件）；②敌人目标闪光与隐藏只作用在身体上（正式版作用于整个 Sprite_Enemy，含其子精灵）；③动画 24 的图没导出（没有技能用到），只对照了时序与隐藏，没对照格子；④未复现正式版首次载入动画图的异步等待（同 dev.069）。

## 交接板

- 下一步：删掉八戒技能动画这一行；可选后续——地图动画目标闪光／隐藏（车道 A 的 `map_scene`，正式版 Sprite_Character 也是 Sprite_Animation 目标）
- 用户试玩说明：战斗技能动画的颜色（转色相）、受击者闪色、全屏闪光、隐藏目标与正式版逐帧一致；角色身上的动画位置上移到正确处；四倍速下动画音效不再被截断
- 需要用户决定：无

## 进度账

- 战斗画面：小幅（动画细节对齐），由沙僧复核

## 本分支提交

- deff48d MVAnimation 按 Sprite_Animation 逐帧，DhAnimation 改薄子类
- 7eec888 目标闪光与隐藏作用在战斗者、跟随目标；__animRef 读数与 xiyou_mv_animation
