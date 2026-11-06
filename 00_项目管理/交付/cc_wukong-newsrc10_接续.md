# 交付：cc/wukong-newsrc10（EB 角色旧账二）

- 车道／工作者：EB 角色旧账二（cc，悟空）；接 DW（`cc_wukong-newsrc10.md`），同分支。代码提交在工作树 competent-ishizaka-ae6e7c 做的，本交付单提交在另一会话工作树里接在 605d1a9c 上推的（那棵工作树要先 `git pull` 才跟得上）。
- 状态：可合并（①②③ 都交了；交回换源集成分支，不合 main）
- 基线：ce1fddf3。探针、量具、选测都显式设 `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`。

## 变更记录草稿

## 2026-11-06 【cc·悟空·未经审查】角色旧账二：SV 归一平滑、停用／隐藏角色、162 诛仙战斗图、人物图鉴跟 v0.62（dev.待定）

- **① SV 归一平滑**（`battle/battler_sprite.gd` `_apply_smooth`，O-待定·SV 归一平滑，`XBattlerSprite.SV_NORM_SMOOTH`）：照 v0.62 `Codex_MiraRavenMultiFrame` v1.06 applyVisual（`bitmap.smooth = !crispScaling || scale<1`，CrispScaling 默认开）：167 号以后有归一档的角色，归一缩放×SvPngFd 小于 1 时身体改 LINEAR，否则最近邻。量具 v0.62 实测正好 168、174、175、179 平滑（0.55～0.72 倍），其余（167、169～173、176～178 放大或原尺寸）不平滑。关掉开关回 v0.28（一律最近邻）。重跑逐张比 `xiyou_actor_sv_compare`：平滑四条差异清零。
- **② 没进出战栏的 5 名定性**（见下表）：不是漏实现，出战栏两边一致。顺带跟进同一批新源插件里重制没做的两处（O-待定·V029 隐藏角色，`XImportedBalance.V029_HIDE_ACTORS`）：人物图鉴目录、角色仓库列表滤掉 V029 隐藏的 7 名（仓库只滤显示，编号留着不丢）；读档时照 `B.migrateParty` 把停用角色挪出队伍与出战栏（`XImportedBalance.migrate_party`，`XState.from_dict` 调）。图鉴目录改成按行取角色（`XActorBook.row_ids`／`cur_id`），仓库取出改按编号删（列表滤过后行号不等于仓库下标）。
- **162 诛仙战斗图是空的（查出来的）**：原版 `guanxi7_1.png`、`小诛仙.png`、`characters/guanxi7_1 (1).png` 是扩展名 .png 的 JPEG，早年原样复制时导入失败留下 `valid=false` 的 `.import`；转换器后来转成真 PNG 了，但 Godot 认旧记录不重导，战斗里 162 没有身体贴图、脸图也空。`xiyou_export.py` 复制图时遇到 `valid=false` 的 `.import` 就删掉（记 issue `resetInvalidImport`），下次导入重做；专项查 generated/img 下没有坏导入。EB 工作树已删掉重导：162 逐张比几何与逐像素都对上（比对场景按内容读原版伪 PNG）。主工作区、集成树那 3 个 .import 由总装处理。
- **③ 零星清单**：DW 交付单末尾的候选（审查 40 P3-11、41 P3-4、42 P3-1～3、45 raven.gd 头注释）**全部已销账**（变更记录 4517、4562、dev.334、dev.336，审查 48 第 36 行）。另找真缺的，做了前 5 条：
  1. 人物图鉴状态页「光环独立栏」（v0.29，Star_ActorsBook drawAllContents）：有 `<CodexAura>` 技能的角色四栏「主动／被动／光环／其他」、栏宽 floor(932/4)、22 号行高 30、超出写「确认查看全部」，武器掌握接在最长一栏下（`status_ops`）。
  2. 技能详情类型「【光环】」（`skillTypeName`，`XActorBook.is_aura`）。
  3. 流萤 179 详情专属段（10622～10632＋全库 `<CodexLiuyingPassive:>`）与「未解锁」灰字（PREVIEW_ACTORS 加 179）。
  4. 流萤图鉴立绘：179 归一档登记 `[128,128,19,12,111,128]`（与战斗 inferProfile 量出的一致）＋图鉴 bookScale 0.8（v1.07，`XAppearance.BOOK_SCALE`，只作用于图鉴）；actor_book 立绘名改按参照记的战斗图名比（参照 `review_actor_book.js` 记的是 `battlerName()`，168、173～177 图鉴画逐帧图）。
  5. `xiyou_actor_p0`：参照 slice_d2 没有 179 时第②段 `d.actors[str(id)]` 脚本出错、测试停住不出结果（基线就这样）；改成跳过，oracle_row_179 两条照记挂，等整份同步。
  - actor_book 从 17/22（CV 重取参照后挂的 5 项：光环标签、主动列宽、新角色立绘、179 技能表、目录名单）到 26/26。

## ② 定性表

| 角色 | 原版为什么不在出战栏 | 重制 | 结论 |
| --- | --- | --- | --- |
| 141 女儿国王、146 苍龙破晓、152 徐凤年、161 胡桃、166 利姆露 | **数据开关（停用名单）**，不是解锁条件或事件：v0.62 `installImportedBalanceRuntime` `disabledActorIds`（10 人：141、143～146、152、157、160、161、166）；量具设 `_actors=[id]` 后调 `initializeBattleMembers`，包装先跑 `B.migrateParty`，停用的挪进仓库、出战栏清 0。另 `installIntegratedV029Runtime`（v0.30）`hiddenActors` 7 名（141、146、152、157、160、161、166）新局／读档从队伍和仓库移走，图鉴目录、仓库列表滤掉 | `XImportedBalance.DISABLED_ACTORS` 同 10 人，`add_actor` 拦（rules-newsrc1 已跟）；逐张比里重制也没让它们出战 | 出战栏一致，不是漏实现。缺的图鉴目录、仓库列表隐藏与读档迁移本单补上 |
| 143～145、157、160 | 同上停用（157、160 还隐藏） | 不在切片里（没导出），逐张比不量 | — |
| 162 诛仙 | 正常进栏（guanxi7_1，9×6 64px，×0.75，不平滑） | 外观本来就是普通侧视图；量不到是因为图导入坏了，身体没贴图 | 已修（见上），逐张比对上 |

## 优化登记

已直接写进 `03_再刷重制_Godot/00_设计/优化登记.md` 末尾两行（总装通知要求），编号待总装分配：
- O-待定·SV 归一平滑：`XBattlerSprite.SV_NORM_SMOOTH = false` 回 v0.28。
- O-待定·V029 隐藏角色：`XImportedBalance.V029_HIDE_ACTORS = false` 回 v0.28（图鉴、仓库列全部）。读档迁移没挂开关（照新源；停用角色本来就进不了队）。
`回退开关覆盖.py`：两条都认到、有回退支测试。

## 交接板

- 下一步：③ 剩下的真缺（下面「剩余清单」）；整份同步给 slice_d2 加 179 后 actor_p0 两条自然过。
- 用户试玩说明：米拉、云裳、谷雨、流萤的战斗图边缘变柔（跟 v0.62）；人物图鉴里女儿国王等 7 名停用角色不再出现，角色仓库也不列；有光环技能的角色图鉴状态页多一栏「光环」；流萤图鉴立绘小一些（×0.8）；诛仙战斗图能看到了（之前是空的）。
- 需要用户决定：无（两条 O-待定照「冻结后改动逐项跟进」默认开）。

## 剩余清单（③ 没做的真缺）

- v0.62 v1.08 进阶窗口：格子大于 64px 的 9×6 图（流萤）在进阶界面按图鉴同尺寸、平滑、脚底中线对齐 64px 格（`Window_ActorAdvancedStatus.update` 包装）；重制 actor_advanced 没跟（没逐行核，先列）。
- v1.06 `<CodexSVNativeSize>`：v0.62.12 数据里没有角色带这个标签，暂不用做。
- V029 读档把隐藏角色挪进 `_codexHiddenActors29`（记原位置）：重制只滤显示、编号留在仓库；以后要「恢复隐藏角色」再补。

## 验证

- 专项：xiyou_sv_smooth 144/144（开、关各一组：采样方式；画的那帧与源 PNG 逐像素比（alpha 全比、alpha≥20 比 RGB，fix_alpha_border 改过 alpha<20 的 RGB）；变大装备推到 ≥1 回最近邻；无坏 .import，守卫先挂后过已验）；xiyou_hidden_actors 24/24；xiyou_actor_book 26/26（改前 17/22）。
- 邻近（本机）：actor_book_review 6、actor_warehouse 26、appearance 34、autosave 10、imported_balance 233、pets 29、raven_visual 55、save_events 31、save_page 42、svpngfd 33、sve_visual 31、sequence_visual 70、actor_advanced 33、advance_reads 8、liuying 144、liuying2 188、liuying3 50，全过。actor_p0 改前基线就脚本出错停住（参照缺 179）。
- 逐张比工具场景重跑：平滑差异清零；162 几何与像素对上。
- 云端选测（15 个场景，--scenes 带 .tscn）：[运行页](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42295374006)，结果在回报里。
- `事件空绿扫描.py --check`：挂 5 条 m234 状态没量，同 newsrc9（克隆产物没有新地图 234 的状态探针，不是本单）。语法检查通过。没跑全量。

## 可回退

- 两个开关见上；162 的转换器守卫要撤就撤 cfa4db94 里 xiyou_export.py 那段（只删坏 .import，不改产物）。

## 可优化（流程／工具／效率）

- 已做：`xiyou_export.py` 遇到 valid=false 的 .import 自动删掉重导；`xiyou_sv_smooth` 里加了全 generated/img 坏导入扫描。
- 建议：`新建工作树.sh --补齐` 克隆 generated 时也扫一遍 `valid=false` 的 .import（这次三棵树都带着坏导入），归工具车道。

## EC′（接 EB，同分支；在工作树 priceless-hofstadter-fa63e4 做，generated／.godot 从 competent-ishizaka 克隆）

### 变更记录草稿

## 2026-11-06 【cc·悟空·未经审查】actor_p0 只在云端挂的 recruit_11 查清；179 切片参照在新源上补跑（dev.待定）

- **① recruit_11 的根**：大厅 Map004 有漩涡过场（`CodexWhisper.seen('rift1')` 为假时自动播，播完 `mark`），配置 `codexWhisperSeen` 存在测试目录的 options.json 里、不跟存档。本机 `user://test_xiyou_actor_p0/options.json` 留着上次运行记下的 rift1，所以不播；云端每次全新目录，过场占住地图 600 帧以上，测试等满 600 帧后照样调第一个招募公共事件 13，`run_common_event` 见地图忙直接返回 → 里德没进队。属于测试依赖残留状态（不是环境或工具差异）。复现：本机把测试目录挪开再跑，挂同一条；改后：测试开头删掉旧 options.json、按默认值重读、标记 rift1 已看（只验招募），并在每次调事件前加 `map_idle_before_<id>` 断言，地图还忙时明确记挂，不再算成「没招进来」。反向验证：去掉标记那行 → `map_idle_before_11 [13,600]` 与 recruit_11 一起挂。没加豁免。
- **③ 179 两条缺参照**：探针本来就有（`mv_oracle/slice_probe.cjs`，`xiyou_slice.json` 已含 179，dev 之前流萤第一期加的），缺的只是参照没在新源上重跑。在新源上 `XIYOU_PROBE_ACTORS=179 node slice_probe.cjs 2`（14 秒，1264 行伤害，0 错误）跑出 179，并进本分支 generated/oracle/slice_d2.json（本机与云端快照 refs/ci/generated/cc/wukong-newsrc10），actor_p0 本机 3680/3680。集成那边整份同步跑新源时会自然带上 179，不用另改探针。

### 验证（EC′）

- actor_p0 本机 3680/3680（179 并进参照后；只改测试时 3676/3678，剩两条 179）；清空测试目录连跑两次都过。
- 云端（actor_p0、actor_book、hidden_actors、sv_smooth，运行 42298148899，带并进 179 的快照）：4 个全过。

### 可优化

- 建议：别的在 Map004 起跑、用 `XSave.dir_override` 的测试也会吃同一个过场（首跑与再跑结果不同）；可以在测试公共初始化里统一标记 rift1，或让云端与本机一样每次清测试目录。归工具车道。

## 本分支提交（EB）

- 73dfc8ca v0.62 SV 归一平滑＋专项 xiyou_sv_smooth
- cfa4db94 162 诛仙坏导入：转换器守卫、专项扫描、逐张比按内容读图
- 8cba908b V029 隐藏角色、读档停用角色迁移、专项 xiyou_hidden_actors、优化登记两条
- 72955961 人物图鉴光环栏／光环标签／179 详情；actor_p0 不再停住
- 605d1a9c 流萤图鉴立绘档与 bookScale；actor_book 26/26
- （本提交）交付单
