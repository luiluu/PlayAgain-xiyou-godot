# 交付：cc/wukong-honghuang1

- 车道／工作者：A 内容·楼层／悟空（cc，悟空 honghuang1，Opus）
- 状态：可合并

## 变更记录草稿

## 2026-11-03 【cc·悟空·未经审查】洪荒诅咒自选（公共事件 1442）移植（dev.待定）

- 缺口（gaps4 盘点第 2 行）：大厅破阵·投影 EV41 第 3／5 页开洪荒难度后，置变量 1482＝1 再调公共事件 1442；1442 的三段脚本（`_hhCurseOffer` 列候选、`_hhCursePicked` 连问、写变量 1468～1472）和 15 种紧凑写法的全员学诅咒循环重制都认不出，选了洪荒一个诅咒都不学。
- 原版做法（冻结 v0.28 读实）：**没有随机数**——15 种诅咒全列，连问 5 次「选择要承受的第 N 个诅咒（共选5个）」，每次去掉已选的，选项不可取消（`setChoices(…,0,-1)`）；选项文字是 `CodexHonghuang.curseLabel`（【档位·×系数】名字（技能备注效果，去零宽空格））；选完按顺序写变量 1468～1472，删掉临时候选；后半按五个变量各给所有有名字的角色 `learnSkill(7200+N)` 并提示「受到诅咒…」。变量 1482 不是 1 时整段不跑；再进一次会再选五种，已学的不忘，变量换成新选的。
- 移植：新 `XHonghuang`（`modes/xiyou/core/honghuang.gd`：档位表、`curse_label`、`curse_ids`、`curse_bonus`，候选与已选放静态变量，同原版 `$gameTemp` 不进存档）；`MVScript.run` 整段比对认三段脚本，选项窗走 `host.show_message`（和事件 102 同一个对话框）；全员学技能循环的名字检查改成正则，认不带空格的 `if($dataActors[j].name!='')`。
- 普查：`script_census_known.json` 删去 1442 这 18 种（已知认不出 141→123）。
- 原版参照：`mv_oracle/honghuang_curse_probe.cjs`（12 例：五种选法、门槛 0／2、重复进入、已会某诅咒、EV41 第 3／5 页选是／否／已开洪荒），产物手工复制为 `tests/fixtures/honghuang_curse_oracle.json`（同批量抽奖，不进同步 PROBES）。新专项 `xiyou_honghuang_curse` 逐例比文字、选项（含取消类型）、变量、开关、样本角色学到的诅咒、全员都学、临时候选清掉、`curseBonus`，全过；反向验证 5 项（档位文字、不去已选、变量错位、紧凑名字检查不认、可取消）都咬住。
- 不在本期（下期八戒）：诅咒倍率（发券 `grantTicketBonus`、权能掉率）、十大洪荒权能掉落、洪荒压制被动；接线点见交付单「接续」。

## 交接板

- 下一步：盘点表第 2 行（洪荒自选诅咒）划掉；第 4 行（洪荒倍率、权能掉落、洪荒压制被动）照本单「接续」派八戒。
- 用户试玩说明：大厅破阵·投影选「挑战灭世难度」（变量 20≥13 的洪荒页）选「是」后，会连问五次要承受的诅咒（15 种全列、带档位系数），选完全员学会这五个诅咒技能。诅咒的奖励倍率还没接（下期）。
- 需要用户决定：无

## 进度账

- 不改数（洪荒一簇两～三期，本期只是第一期；建议全簇完成时再记）。

## 可优化（流程／工具／效率）

- 无（普查已知清单的 18 条本期已删）。

## 接续（给下期八戒：洪荒倍率与权能）

- 路线判断：原版 `CodexHonghuang.isHonghuang` 认开关 2483 **或** 2463；重制 `mv_script.gd`「洪荒（难度 8）的诅咒加成券与不朽之力」那句按 `s.difficulty != 8` 判，两者口径不同，接的时候先对一下。
- 发券：CE1439 的 `CodexHonghuang.grantTicketBonus()`（`mv_script.gd` 同一处，现在洪荒下没认，落 skipped）：加发 `round(5×(curseBonus−1))` 张物品 1639，toaster「洪荒诅咒加成（×N.N）…」；倍率用 `XHonghuang.curse_bonus(持诅咒的第一个队员，没有取队首)`（原版 `curseHolder`）。
- 权能：`CodexHonghuang.rollPower`（同处）只在本场是不朽存在且胜利、每战一次；区段 `SEGMENTS`、`POWER_RATE 0.03×curseBonus×CodexEconomy.powerFactor(troop)`、`<CodexPower: 区段>` 物品；`orbs.gd:746` 注释的楼层来源 `XDungeon` 已有 `mapFloor`／`bossFloor`（`dungeon.gd:143／174`）；修行页 `guide.gd` 的 `_power_line` 现在返回空。
- 洪荒压制被动：EV41 第 3／5 页调的 CE1445 里 `var hh=$dataSkills.filter(…<CodexHonghuangSuppress>…)[0]; for(…)learnSkill(hh.id)` 这段重制没认（`xiyou_honghuang_curse` 里 `SUPPRESS_SKIPPED` 暂时放过，接上后删掉）；读档补学在 `xstate.gd:510` `sync_native_tier` 已有。
- 未核：15 个诅咒技能（7201～7215）本身的战斗效果（全属性×0.5、敌人免死、再动+1 等）在重制战斗里生不生效，本期没查。

## 验证

- `python3 07_开发环境/语法检查.py`：通过。
- 专项 `xiyou_honghuang_curse`：通过；`反向验证.py`（5 项）：都咬住。
- 选测 `选测.py main --list` 82 个场景（全名，`--names-file`，`--jobs 2`，提交 151b7ffe 上，4305 秒）：81 过；`xiyou_script_census` 挂「known_still_unknown」——正是这 18 种已认得，按测试要求从已知清单删掉后复跑通过。
- 合 main（60a1066e，带进 growth3：切片只多一张魔冠图片、两个探针）后 `--补齐`，复跑 `xiyou_script_census`（18/18）、`xiyou_honghuang_curse`（885/885）、`xiyou_script`（26/26）全过；其余 79 个场景改动后没再跑（之后只动了普查清单与 mv_script 里候选为空时的分支）。
- 没跑：全量（车道不跑）；同步（本期探针手工出 fixture，不进 PROBES，产物不变）。

## 本分支提交

- d6387658 WIP：原版参照探针与 fixture
- 151b7ffe WIP：三段脚本认得、专项 xiyou_honghuang_curse
- 7933dad2 普查已知清单删 18 种；认法不依赖候选状态
- ad83be57 合 main
- （本提交）交付单
