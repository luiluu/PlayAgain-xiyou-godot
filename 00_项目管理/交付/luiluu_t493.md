# 交付：luiluu/t493

- 车道／工作者：T493 洪荒首通奖励②（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-25 【cc·T493·未经审查】洪荒三款称号＋一次性绑存档兑换码（dev.待定）

- 新文件 `modes/xiyou/core/honghuang_titles.gd`（XHonghuangTitles）：西游档称号表末尾接 51 洪荒证道（紫 #b44dff）、52 洪荒首证（曙光流光）、53 洪荒·阿夜（极夜流光）。
  - 洪荒证道：洪荒开关（2483／2463）开着且层数变量 20 ≥ 34（打赢 33 层最终守层者）就自动解锁，记全局配置（同其他称号）；地图空闲每 30 帧查一次（`XMapScene._check_honghuang_clear`），所以已通关的老存档读进来也补发，新解锁弹提示「通关洪荒难度！获得称号：洪荒证道」。用阿夜存档副本核过：层数 34、2483／2463 都开，能补发。
  - 洪荒首证、洪荒·阿夜：只能兑换码解锁，记在存档 `flags.honghuang_titles`（不进全局配置，换档就没有）。洪荒·阿夜所有人在「更换称号」列表里都看得到，显示「洪荒·阿夜（阿夜专属，不可获得）」，选了不变；洪荒首证没拿到显示 ???。
- 兑换码：存档身份用 orb_seed（新游戏随机、随存档走，导出导入、换存档位不变，存档封存签名后玩家改不了）；仓库只放 `sha256("honghuang-redeem-v1|码|存档身份")`（`modes/xiyou/honghuang_redeem.json`），码原文不进仓库。换一份存档哈希对不上 →「兑换码不对，或者不是给这份存档的。」；同一存档第二次 →「这个兑换码在这份存档已经用过了。」、不再发。封存开着时，没签名的明文导入、补签旧明文存档都去掉洪荒首证／洪荒·阿夜的记号和佩戴；名牌、侧栏戴着这两款却没记号的不显示（返修 R2）。入口：大厅洪荒碑调查后选「输入兑换码」。生成工具 `07_开发环境/洪荒兑换码.py`（本机跑，读存档取身份、写哈希、码写进权限 600 的本机文件）。
- 流光：头顶名牌按称号名逐字渐变并随时间流动（`XDesignationPlate._flow_line`，新旧界面都有）；首证＝赤金→玫红→白金＋一道白亮带扫过＋明暗起伏的暖色光晕描边（比阿夜更显眼）；阿夜＝月银→冰蓝→暮紫循环。画面特效关着（或省电）时停在一帧、不每帧重画。存档结构不变（称号仍只存名字、图标、颜色，流光按名字查）。
- 图标：T492 定稿 A 版三张 128×128 拷进 `content/honghuang/Honghuang_Title_*.png`，导入设置同庆典图标，图标号 6426 洪荒证道（紫山印）、6427 洪荒首证（曙光日轮）、6428 洪荒·阿夜（极夜弦月），32 显示最近邻（`XQualityIcons.HONGHUANG`）。
- 回退开关 `XHonghuangTitles.ENABLED`（O-待定）：false 时三款不列、不自动解锁、碑上没有兑换选项、名牌不流光；存档里已有的记号原样留着。天启篇存档（XTianqi.active）不列、不解锁、不能兑换，天启篇零改动。
- 顺手清 T460 合核 P2：`map_scene.gd` 修行指引里程碑的文档注释挪回 `_check_milestone` 头上；`honghuang_monument_view.gd` 文件头改成现状（T487 定稿贴图、程序绘制只是兜底），用贴图时不再每帧重画碑。
- 玩家可见：方桌大厅「更换称号」多了洪荒证道、洪荒·阿夜（阿夜专属）；通关洪荒难度自动获得称号「洪荒证道」；洪荒碑可以输入兑换码。

## 玩家可见文字（待小A 文字审，cc Sonnet 审）

| 位置 | 文字 |
| --- | --- |
| 称号名 | 洪荒证道／洪荒首证／洪荒·阿夜 |
| 称号列表（没获得时） | 洪荒·阿夜（阿夜专属，不可获得） |
| 自动解锁提示 | 通关洪荒难度！获得称号：洪荒证道 |
| 洪荒碑选项 | 输入兑换码／离开 |
| 输入框提示 | 请输入兑换码： |
| 兑换成功 | 兑换成功！获得称号：洪荒首证、洪荒·阿夜。（换行）在大厅找奥尔夫尼选「更换称号」即可佩戴。（R2 按小A 文字审改） |
| 已兑换过 | 这个兑换码在这份存档已经用过了。（R2 按小A 文字审改） |
| 码不对／别的存档 | 兑换码不对，或者不是给这份存档的。 |
| 天启篇／开关关 | 现在无法兑换。（正常走不到：天启档没有洪荒碑） |

## 截图

- 名牌三款（新界面，每款放大 3 倍；首证、阿夜各两帧看流光）：`00_项目管理/归档/交付截图/luiluu_t493/t493_plates_new_skin.png`
- 名牌三款（旧界面）：`00_项目管理/归档/交付截图/luiluu_t493/t493_plates_old_skin.png`
- 别的存档看到的称号列表（洪荒证道已解锁、首证 ???、阿夜专属不可获得）：`00_项目管理/归档/交付截图/luiluu_t493/t493_choice_list_other_save.png`

## 测试

- **返修 R2（小A 核查 P1-1＋P2×4，`00_项目管理/核查/T493_小A核.md`）**：`xiyou_honghuang_titles` 63/63（新增 13 项：封存开着时封存格式导出再导入保留 52／53 与佩戴；旧 v1 明文导出、直接明文存档、只改佩戴三种明文导入都清掉；洪荒证道不受影响；补签 save_3.json 后 .ksv 里没有；封存关着时明文原样；展示侧 worn_ok 三种），xiyou_designation 24/24，xiyou_honghuang_monument 67/67，xiyou_save_seal 127/127，xiyou_designation_plate 2/2；发行空壳 check 0、语法检查 0 问题、发行预设排除检查过、回退开关覆盖无本单缺口。云端选测见下。
- 新专项 `xiyou_honghuang_titles` 50/50（称号表与选项、天启篇与开关、自动解锁含老存档真地图补发、兑换码一次性／换档无效／错码／天启篇／开关关、存档往返、与 Python 工具同一算法的固定向量、仓库配置只有哈希、真地图碑前兑换两次、图标三张 32 互不相同、流光样式与特效关停帧）。
- 相关专项本机全过：xiyou_designation 24/24（加了一行关 T493 开关，只比原版表）、xiyou_designation_plate 2/2、xiyou_fest_road 66/66、xiyou_fest_lobby 155/155、xiyou_fest_reward 56/56、xiyou_honghuang_monument 67/67、xiyou_quality_icons 7/7、xiyou_ui_skin_4b 123/123、xiyou_airship_view 63/63、xiyou_script_gaps 73/73、xiyou_floor_odds 173/173。
- 语法检查 0 问题；发行空壳 check 0；回退开关覆盖无新报错。
- 云端选测：整轮 811 场景 16 片全过，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45593319682 （提交 8ab3c3b7f）。第一轮 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45585275897 挂了 3 个场景，全是本单引起的：xiyou_event_compare／_d 比原版称号选项（Map4 EV1）时多出洪荒三款 → 测试里关 T493 开关；xiyou_ui_skin 不许裸 draw_string → 流光逐字改走 XUiSkin.ds。修完本机这 5 个场景全过，第二轮云端全绿。

## 兑换码（不在这里写码）

- 阿夜那份存档（私密仓 玩家存档/阿夜/ 11-23 导出，复制到临时目录读，原件没动）的身份算出一条码，给 52＋53；码原文只在本机文件里，回执里写路径，交协调。用 `洪荒兑换码.py --check` 核过：这份存档对、换身份不对。
- 如果阿夜实际在玩的不是这份档（换了新档），用工具对新档重出一条即可（`--save <导出 json> --write --out <本机文件>`）。

## 交接板

- 下一步：小A 审本单玩家可见文字（cc Sonnet 复审）；协调把兑换码交 Kyo 转给阿夜。
- 用户试玩说明：大厅洪荒碑调查 → 输入兑换码；方桌「更换称号」看三款；通关洪荒的档进地图自动得「洪荒证道」。
- 需要用户决定：无（口径见下「偏离与说明」）。

## 偏离与说明

- R2 清洗只在封存开着（`XSaveSeal.active_now()`，即发行包）时做：开发版存档本来就是明文、能改，清了反而让开发版导入导出丢记号。补签只清 `save_*` 存档文件。删掉记号文件再改留底明文的老路子（核查 P1-1 第 2 条）同样被清。
- R2 展示侧用 `XHonghuangTitles.worn_ok`：戴着首证／阿夜但存档没有兑换记号时，名牌、侧栏都当没戴称号；不改存档里的 designation（回退开关关时也不删不改）。
- R2 P2：补发节流改用 `_honghuang_clear_tick` 独立计数器；名牌 `_sig` 加 ENABLED、fx_on、worn_ok；重复称号兑换 ok 改为 false；兑换码工具 `--out` 覆写时 fchmod 600。
- 「通关洪荒」口径我定为：洪荒开关开着且层数变量 ≥ 34（打赢第 33 层鸿蒙老祖）。依据：阿夜存档 firsts 记到 primordial:33、层数 34。若 Kyo 认 30 层就算通关，把 `CLEAR_FLOOR` 改 31 即可。
- 一次性的口径：按存档记已兑换。同一份存档在兑换前另存过的副本（身份相同）也能再兑一次——副本本来就是阿夜自己的档，不另做全局记录（全局配置重装就丢，防不住，还要动配置字段）。
- 流光只在头顶名牌做动画；称号选项列表是原版消息选项窗，只显示图标＋名字，没做动态颜色。「T068 的动态做法」在代码里没有现成的（T068 只是静态图标），流光是本单新做的。
- 洪荒证道和别的称号一样是全局解锁（同一台机器的所有存档都能戴）；首证、阿夜只在兑换的那份存档。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/honghuang_titles.gd` `XHonghuangTitles.ENABLED` | （西游档新增，原版没有）原版称号只有 1～30 | 洪荒证道（通关洪荒自动解锁）、洪荒首证／洪荒·阿夜（一次性绑存档兑换码）、名牌流光、碑前兑换入口 | Kyo 11-24／11-25 洪荒首通奖励（T493） | `XHonghuangTitles.ENABLED = false` | cc（T493） | 保留 |

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：`XState.new_game` 会顺手把 `XState.current` 换成新档，写专项时多个存档交错容易踩（本单踩了一次）；可在 xiyou_test_env 加个注释提醒。归文档车道，收益小。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XDesignation.table` | 调用方 9 处，全在 tests（`git grep -n 'XDesignation.table()' -- '*.gd'`）；游戏内只经 choices／apply_choice 用 | 末尾多三行只在西游档且开关开；比原版表的 xiyou_designation 已关 T493 开关，fest 各专项按 id 找、全过 |
| `XDesignation.unlocked` | 调用方 36 处，游戏代码 6 处、其余 tests（`git grep -n 'XDesignation.unlocked(' -- '*.gd'`） | 只对 52、53 改走存档记号，其余 id 原样；52、53 以前不存在 |
| `XDesignation.choices` | 调用方 6 处，全在 tests；游戏内经 choose 用 | 没解锁时只有 53 改显示名字＋说明，其余仍 ??? |
| `XDesignationPlate._paint／refresh` | 地图名牌 2 处（玩家、飞艇） | 只有称号名是首证／阿夜时走流光，其余画法一行不变；xiyou_designation_plate、xiyou_airship_view 过 |
| `XQualityIcons.info` | 调用方游戏内 2 处（xui.gd、item_status_painter.gd） | 只多认 6426～6428 三个号，原有号段不变；xiyou_quality_icons 过 |
| `XSaveTransfer.parse_import` | 导入存档 1 处（title 页）＋tests | R2：只在封存开着、明文分支多一步 strip_unsealed；封存格式分支不动；xiyou_save_seal 127/127 |
| `XSaveSeal._migrate_dir` | ensure_dir 1 处 | R2：只对 save_* 且确有 52／53 时重写文本，其余原文照封；xiyou_save_seal 过 |
| `SkinSideStatus.title_text` | 侧栏队长行 1 处 | R2：多判 worn_ok，只影响戴着无记号的 52／53 |
| `XHonghuangMonument.inspect` | 洪荒碑 1 处 | 碑文后接兑换选项；xiyou_honghuang_monument 67/67 |

## 本分支提交

- 9288caf1e T493：三款称号＋兑换码＋T460 P2
- f2ae47f2c 交付单
- 8ab3c3b7f 修云端三项、截图改仓内路径
