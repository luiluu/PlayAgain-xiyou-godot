# 交付：cc/bailong-raven6

- 车道／工作者：B 界面／白龙（cc，chars-raven6；派单第十六批追加十八 GR1）
- 状态：进行中（同步留指纹在跑；跑完改可合并）

## 派单两项其实已做完（给下次进度核定销账）

进度核定 dev.411 第 102 行「角色与专属机制」还挂着「渡鸦 #3／#4、形象立绘逐张比」，前两项早就做完，只是核定表没跟上：

| 项 | 做在哪 | 证据 |
| --- | --- | --- |
| #4 神话静态大图 Raven_Mythic_Monster | dev.364（cc·ravenfx2） | 无头 Chrome 量具 `mv_oracle/real/sprite_real.cjs`＋规格 `real/raven_myth.json`，结果 `real/raven_myth.result.json`：实机最终画的是 UserSV_RavenMythic 逐帧图（缩放 0.4615、藏武器和影子），大图从不出现；只剩阵亡透明度 0.35 一条，已补（`XBattlerSprite._raven_myth_alpha`，O-198，专项 `xiyou_raven_visual` 的 `_myth_alpha`）。dev.398 又核过 v0.62.12 的两个运行时文件与 v0.28 逐字相同 |
| #3 施放特效屏蔽支 | dev.398（cc·悟空 newsrc10） | 探针 `mv_oracle/raven_fx_probe.cjs` 14 例（真实 BattleManager 行动序列）、专项 `xiyou_raven_fx` 54 项；顺带修了行动序列里不放羽毛特效 |
| 战斗图逐张比 | dev.398（cc·悟空 newsrc10） | `real/actor_sv_real.cjs`＋`tests/xiyou_actor_sv_compare.tscn`，切片 162 名几何与逐像素 |

真没做的只有人物图鉴立绘的逐张比（dev.361 核定第 42 行：「图鉴只比了图名，没逐张截图」），本期做。

## 接续（11-09 21:25，第二位白龙；额度紧，总装叫停）

- 分支头 0d17cb7f4（本条记录提交之后为新头），**本会话没改代码**：只切了分支、起了 `--补齐`，导入没跑完就被叫停中断（下一位重跑一次 `--补齐` 即可，不用清理）。
- 注意：分支之后 main 进了 9 笔，其中 `mv_oracle/hboot.cjs` 有改动（bajie-interp8），所以**先 `git merge main` 再 `--补齐`**，再重量 raven_visual 探针。
- 下一步照上一节第 1～4 条原样做，都还没验证：raven_visual 探针重量与 `xiyou_raven_visual`、图鉴对表场景 `xiyou_actor_book_compare`、修真差、语法检查／工具回归／选测、补各节。没有跑到一半的东西。

## 接续（11-09 20:45 额度 92% 停手，SUN 换账号；下一位照此接）

**分支 cc/bailong-raven6 已推回本库**（从 github/main eb6ab526 切；我在 scratchpad 的 clone 里做的，clone 会丢，接手在自己工作树 `git switch --ignore-other-worktrees cc/bailong-raven6` 再 `新建工作树.sh --补齐`）。

已做（都在最后一笔 WIP 提交里）：
1. **神话形态受击／濒死是真差异，已改**：无头 Chrome 量具 `real/raven_motion.json`（结果 `real/raven_motion.result.json`）实测：普通形态 damage→evade、dying→wait；**神话形态 damage、dying 照原样**（帧 UserSV_RavenMythic4_0／14_0），evade 照 evade。原因：Codex_MiraRavenMultiFrame 的 installVisualHooks 在 Scene_Boot.start 里装、包在最外层，神话这两个动作直接调开机前存的原生 startMotion，绕过 installNativeRavenRuntime 的替换。ravenfx 期 raven_visual 探针不走 Scene_Boot（hboot 不启动 SceneManager），量成了神话也换。
   - 改：`battle/battler_sprite.gd` `raven_motion` 神话形态（`XAppearance.sv_form == "RavenMythic"`）的 damage／dying 不换；`tests/xiyou_raven_visual.gd` `_motion` 按用例 setup.myth 设 `s.raven["myth"]=3`；探针 `raven_visual_probe.cjs` 开头加 `w.Scene_Boot.prototype.start.call({})`（同 achievement_probe）。
   - **还没跑**：改后的探针（排队时停手）。接手先 `占槽.py -- node raven_visual_probe.cjs`，确认 motion.167.myth 的 damage／dying 变成照原样、其余 6 例不变（168 有 quietIdle：walk 可能变 wait，若变了 raven_motion 不管 walk，专项会挂，届时 `_motion` 只比 damage／dying／evade 或让测试照新参照），把 `.sandbox/raven_visual.json` 放进工作树 generated/oracle 跑 `xiyou_raven_visual`；交付前按车道须知跑 `同步正式西游.py --accept-additions`（改了探针）。
   - 给总装：优化登记 O-196 的「普通、神话都换，探针实测」要改成「只换普通形态；神话照原样（raven6 实机量具）」，车道不改优化登记。
2. **图鉴立绘量具**：`real/actor_book_real.cjs`（无头 Chrome 进 Scene_ActorBook 逐个选中，记状态窗 _Sprite 图、帧、缩放、位置、锚点、平滑、窗口），结果快照 `real/actor_book.result.json`：切片 162 名量到 157，141、146、152、161、166 原版目录里没有（V029 隐藏，重制 XActorBook.index_ids 也滤掉，对表时确认）。原版 144 名普通角色 1 倍、锚点居中、**smooth=true**（画在 (93.2,71.69) 半像素上，线性取样）；167 以后 13 名按档缩放、smooth=false。
3. **对表场景** `tests/xiyou_actor_book_compare.tscn`（设 XIYOU_BOOK_REAL 才比，检查里记过）：选中同一角色、按原版那一刻的格号取同一格，比图名、整张图、取图范围、窗口坐标矩形、平滑、逐像素。**还没跑出结果**。跑法（工作树 01_Godot工程 下，外包占槽）：
   `XIYOU_BOOK_REAL=<mv_oracle>/real/actor_book.result.json XIYOU_APP=…/冻结正式源/v0.62.12/app.nw XIYOU_BOOK_OUT=<scratchpad>/book_cmp 占槽.py -- ../07_开发环境/godot --headless --path . tests/xiyou_actor_book_compare.tscn`，看 book_cmp.md。要留意：重制 project.godot 没设默认贴图过滤（Godot 默认线性），167 以后原版是最近邻，可能会报平滑差异——真差就在 actor_book 状态窗按原版 smooth 设 texture_filter（167 以后有档的 NEAREST）。
4. 剩：跑上面两项、修出来的真差、`语法检查.py`、`工具回归.py`、选测（`选测.py main --list`，至少 xiyou_raven_visual、xiyou_actor_book*、xiyou_actor_looks、xiyou_portrait1、xiyou_appearance），补完下面各节，状态改可合并。

## 本期结果（11-09 第三位白龙）

- **神话受击／濒死**：改后的 `raven_visual_probe.cjs` 重量（经占槽），7 例无错；跟主工作区旧参照比只 `motion.167.myth` 的 damage／dying 两项变（evade→damage、wait→dying），其余 6 例逐字相同；168 的 walk 没变。`xiyou_raven_visual` 原先挂在 motion.167.myth：测试先设 `s.raven["myth"]` 再 `s.actor(167)`，取角色会初始化渡鸦存档把神话回合清掉，改成取完再设，通过。
- **图鉴立绘逐张比**（`tests/xiyou_actor_book_compare.tscn`，原版 v0.62.12 实机量具 `real/actor_book.result.json`）：切片 162 名，两边都量到 157 名；141、146、152、161、166 两边都不在目录（V029 隐藏），一致。157 名的图名、整张图、取图范围、窗口坐标矩形、逐像素全对上，只剩：
  1. **173 饿狼位置是真差，已改**：原版代码 `installNativeGarouRuntime.garouBookPreview` 写的是竖向呼吸、脚底 y＝宽/13＋72，但实机被 `Codex_MiraRavenMultiFrame.updateBookVisual` 盖掉——它的图鉴 update 包装同在 Scene_Boot 才装、包在最外层，每帧最后按通用公式再摆一次（同神话动作那条装载次序）。实机量到锚点 (0.5,1)、不呼吸、脚底 y＝宽/13＋可见高/2。重制原来照 garou 代码摆，低 36 像素、带呼吸；`ui/actor_book.gd` 的 `sprite_rect` 去掉 garou 支（连同 `frame` 参数、spec 的 garou 键、每帧重画），`tests/xiyou_actor_book.gd` 几何断言同步。改后对表 173 无差。
  2. **144 名原生立绘平滑**：原版 bitmap.smooth=true、画在半像素 (93.2,71.69)，线性取样略糊；重制最近邻清晰。按 11-05 Kyo 定的胜利背景先例保持清晰，加回退开关 `XActorBook.BOOK_NATIVE_SMOOTH`（默认 false，true 时原生图线性取样），`xiyou_actor_book` 加 native_smooth_off／on 两项。见下面优化登记草稿。
- 对表报告在 scratchpad，没入库（工具场景，设 XIYOU_BOOK_REAL 才跑；跑法见上面接续第 3 条，XIYOU_APP 实际路径是 `03_再刷重制_Godot/02_内容与素材/冻结正式源/v0.62.12/app.nw`）。

## 变更记录草稿

## 2026-11-09 【cc·白龙·未经审查】渡鸦神话受击／濒死按实机、图鉴立绘逐张比（dev.待定）

- **渡鸦神话形态受击／濒死照原样**：无头 Chrome 实机量具 `mv_oracle/real/raven_motion.json` 实测，多帧插件的画面钩子在开机画面才装、包在最外层，神话形态的受击／濒死绕过渡鸦替换。`battle/battler_sprite.gd` `raven_motion` 只换普通形态；`raven_visual_probe.cjs` 先调一次 Scene_Boot.start 装钩子后重量，只 motion.167.myth 的 damage／dying 变。O-196 回退开关不变。
- **图鉴立绘逐张比**：新量具 `real/actor_book_real.cjs`（结果 `real/actor_book.result.json`）＋对表工具场景 `tests/xiyou_actor_book_compare.tscn`，切片 157 名逐张比图、取图、矩形、逐像素。
- **173 饿狼图鉴立绘按实机**：同一装载次序，`garouBookPreview` 的呼吸与脚底位置实机被多帧插件盖掉；`ui/actor_book.gd` 改成同通用公式、不呼吸。
- **原生立绘保持清晰**：原版 144 名原生立绘线性取样略糊，重制保持最近邻，回退开关 `XActorBook.BOOK_NATIVE_SMOOTH`（O-待定·图鉴立绘清晰）。
- 进度核定：渡鸦 #3／#4、战斗图逐张比早已做完（见本单开头表），图鉴立绘逐张比本期做完。

## 交接板

- 下一步：进度核定第 102 行「角色与专属机制」的渡鸦 #3／#4、形象立绘逐张比可以销掉（证据在本单开头表与「本期结果」）。
- 用户试玩说明：图鉴里看 173 饿狼，立绘比之前高一截、不再上下呼吸（跟正式版一样）；战斗里渡鸦变神话后挨打／濒死播自带的受击、濒死帧，不再换成闪避／待机。
- 需要用户决定：无（平滑按 11-05 胜利背景先例保持清晰，开关可回）

## 进度账

- 角色与专属机制：渡鸦 #3／#4、战斗图与图鉴立绘逐张比都已做完，待核定销账。

## 给总装

- 优化登记 O-196 的「普通、神话都换，探针实测」改成「只换普通形态；神话照原样（raven6 实机量具）」。车道不改优化登记。

## 优化登记草稿

| O-待定·图鉴立绘清晰 | `ui/actor_book.gd` 状态窗立绘 | 原版 144 名原生侧视图 bitmap.smooth=true、画在半像素 (93.2,71.69) 上，线性取样略糊（167 以后有档的 smooth=false） | 重制最近邻保持清晰 | 同 11-05 Kyo 定胜利背景「不照原版放大模糊」 | `XActorBook.BOOK_NATIVE_SMOOTH = true` 回到原版（原生图线性取样） | cc（白龙 raven6） | 编号待总装分配 |

## 可优化（流程／工具／效率）

- 渡鸦神话动作、饿狼图鉴两处都是同一个坑：Codex_MiraRavenMultiFrame 在 Scene_Boot.start 才装钩子、包在最外层。参照宿主 hboot 不走 Scene_Boot，凡是被这个插件包过的函数，探针都可能量成「没包」的样子。建议给 `shared/host.cjs` 的 `start()` 加个选项（或默认）调一次 `Scene_Boot.prototype.start.call({})`，再看哪些探针结果会变；会动大量参照，要整份重量，派单前先约槽。
- 交付单里图鉴对表跑法写的 XIYOU_APP 路径 `…/冻结正式源/v0.62.12/app.nw` 少了 `03_再刷重制_Godot/02_内容与素材/`，第一次跑因此像素全报差，本单已更正。

## 待交叉核查

- dffcc8b65（173 饿狼图鉴、BOOK_NATIVE_SMOOTH）、0d17cb7f4（神话受击／濒死、探针装 Scene_Boot 钩子）：甲档（显示、不碰战斗结算），重点看 173 的通用公式与原版 updateBookVisual 是否一致、native_smooth 条件跟 sprite_rect 原生支是否一致。
- e66b37d59（量具、对表场景）、2bfea2812（测试顺序）：丙档。

## 验证

- `raven_visual_probe.cjs` 重量（占槽）：7 例 0 错；跟主工作区旧参照逐例比只 motion.167.myth 的 damage／dying 变。
- `xiyou_actor_book_compare`（XIYOU_BOOK_REAL＋XIYOU_APP）：157 名量到，改后只剩 144 条平滑（有意保持清晰）与 5 名两边都不在目录。
- `语法检查.py`：660 个 .gd 0 问题。`工具回归.py` 全过（55 秒）。`回退开关覆盖.py` rc=0。
- 选测：`选测.py main --list` 列 95 个，本地跑了其中非 `xiyou_rules*` 的 30 个（含 xiyou_raven_visual、xiyou_actor_book*、xiyou_actor_looks、xiyou_appearance、xiyou_actor_sv_compare、xiyou_event_compare* 等），全部通过（409 秒）。没跑 65 个 `xiyou_rules*`：它们是因 battler_sprite.gd 被选上，本期只改了 `raven_motion`（纯显示，rg 确认只在 battler_sprite 自身调用），不进结算。
- `同步正式西游.py --accept-additions`：（跑完补）

## 本分支提交

- e66b37d59 WIP：图鉴立绘量具＋对表场景、神话动作量具规格、交付单
- 0d17cb7f4 WIP：神话受击／濒死不换、raven_visual 探针装 Scene_Boot 钩子、图鉴原版量测
- 2f3056c67 WIP：交付单接续
- c2637ad1c 合并 main
- 2bfea2812 WIP：xiyou_raven_visual 神话回合在取角色后设
- dffcc8b65 173 饿狼图鉴按实机、BOOK_NATIVE_SMOOTH
