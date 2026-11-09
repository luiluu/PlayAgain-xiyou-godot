# 交付：cc/bailong-raven6

- 车道／工作者：B 界面／白龙（cc，chars-raven6；派单第十六批追加十八 GR1）
- 状态：进行中

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

## 变更记录草稿

待写

## 交接板

- 下一步：待写
- 用户试玩说明：待写
- 需要用户决定：无

## 进度账

待写

## 可优化（流程／工具／效率）

待写

## 待交叉核查

待写

## 验证

待写

## 本分支提交

待写
