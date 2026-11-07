# 交付：cc/bajie-interp1

- 车道／工作者：A 内容·地图事件解释器／八戒（cc，第十五批 FA）
- 状态：进行中

## 盘点（新源 v0.62.12，2026-11-07，静态，没跑 Godot）

口径：读 main 的 generated（v0.62.12 转换产物）里切片全部地图事件页与公共事件（去掉 `script_census_known.json` 的 unreachable 10 条），
按指令码、写法键（`事件写法覆盖.py` 的 key_of）、移动路线指令码、插件指令前两词逐项对 `mv_event_core.gd`／`mv_interpreter.gd`／`mv_script.gd`／`mv_character.gd`。
脚本在 scratchpad，没入库（census.py、newkeys.py、callers.py）。

**结论：指令层已经没有真缺。** 地图上出现的指令码除 333／334／337 外全部有实现（这三个只在战斗技能的公共事件里，见下）；
移动路线 26 种指令码全有；插件指令 21 种前两词全有；新源比旧覆盖表（250 种写法，11-06 events14 出）多出 24 种写法、约 190 处，
逐种 rg 过都已有翻译（各换源车道做的）。派单里点的几项现状：

| 派单点名 | 现状 | 依据 |
| --- | --- | --- |
| 条件分歧 9／10（武器／防具） | 已实现，按底材比；对过 YEP_ItemCore `hasItem`／`isAnyMemberEquipped`／`hasBaseItem`（插件 1075～1330 行）语义一致；旧覆盖 6/6、10/10 都执行到 | `mv_event_core.gd` `_condition` 9,10 |
| 载具图像 323、载具 BGM 140、载具位置 202 | 已实现且飞艇能上下、飞行（`map_scene.gd` get_on_vehicle 等）；核心里「上下与飞行还没做（甲二）」「重制还不能上载具」两句注释过时 | `map_scene.gd` 770 行起 |
| 电影 261 | 已做（dev.347 movie_player） | 进度核定 dev355 |
| 称号 | m4e1p2／p3 已与参照一致 | event_compare_baseline note |
| 专属号角路径 | 242 个号角都跑过（dev.347）；新源流萤 9043 `CodexLiuying.recruit();` 已接（悟空 newsrc9，`mv_script.gd` 616 行） | `xiyou_actor_p0` RECRUIT_9 |
| event_compare 已知不一致 | 登记现在 8 例（不是 3）：见下表 | `tests/event_compare_baseline.json` |

### 三类表

**真缺**（玩家可见）

| 项 | 位置 | 可见程度 | 打算 |
| --- | --- | --- | --- |
| （无指令／写法层真缺） | — | — | — |

**验证不足**

| 项 | 规模 | 打算 |
| --- | --- | --- |
| 新源新增 24 种写法没有换源后的覆盖证据（旧覆盖表是换源前出的）：ce1431 抽奖条件 `=== … \|\| …` 44 处、深渊商人字符串参数 31 处、`showRoster` 12 处、剑心秘籍 8 处、称号 `DesignationN` 2、`_kyoMaxLevel` 5、`CodexWhisper` 2、`CodexHeavenGaze`、`nonWeakIds` 4、`$dataEnemies…params` 1、更新日志 `injectChangelog` 1 等 | ~190 处 | 推送后跑 `xiyou_event_compare --coverage` 重出覆盖表，没执行到的进 `--missed` 簇 |
| 没执行到的实例（换源前 14721） | 14721 | 同上，新源重算后按玩家走得到、按簇大小挑一批补预设（`--suggest`） |
| 跳过登记 ce9043（流萤号角）、对照登记 ce9043 trace | 2 条 | 招募已接，登记大概过时；推送后单跑 `--only=ce9043` 看能不能销 |
| 地图对照里战斗技能公共事件的跳过（ce17～ce1370 再释放 `action.setSkill`、333 敌人状态、122 游戏数据·敌人 4,0,x） | 38 例 | 调用方全是战斗场合技能（occasion 1），战斗里 `battle_event_runner.gd` 有翻译（199、246、267、458、464 行）；地图上不会跑。不改代码，建议对照工具把只被战斗技能调用的公共事件标成「战斗里跑」（归工具车道） |

**不移植／别处管**

| 项 | 理由 |
| --- | --- |
| m4e73p0 商店向导「战力短板」 | CodexZones 五乘区预算，数值平衡不移植（O-044／O-050） |
| m4e60p0#g3／p2#g3 抽奖券不足 | 对照宿主不是地图场景，XCasinoBatch 不开；游戏里由 xiyou_casino_batch 自有参照管 |
| m4e69p1、#o4_2／o4_3 显示升级 | 新源流萤包 changeLevel 丢掉 316 的显示升级（原版缺陷），重制照旧显示，O-待定·LEVEL_UP_SHOW_316 |
| m4e71p0 更新日志 | 参照宿主 jsdom 读不到 PlayerChangelog，工具车道修宿主 |
| CE42 白胡子地震（337） | 全库没有调用方（117、效果、备注都没有）；337 战斗解释器也没认，真有调用时归战斗车道 |

## 变更记录草稿

待写

## 交接板

- 下一步：待写

## 进度账

- 待写

## 优化登记草稿

无

## 可优化（流程／工具／效率）

- 建议：`事件写法覆盖.py` 加「只被战斗场合技能调用」的公共事件分档（同 `battleRoots` 口径），地图对照里的这类跳过不再混在跳过登记里（约 38 例；归工具车道）。
- 建议：覆盖表 `04_验证/事件写法覆盖.md` 换源后要重出一次，现在那份是 v0.62.12 之前的口径。

## 本分支提交

- 待写
