# 交付：cc/nezha-xuan1

- 车道／工作者：C 规则／机制＋B 界面／哪吒（cc）
- 状态：可合并

## 盘点：原版璇的星谱页

来源：冻结正式源 `js/codex/runtime/installNativeXuanRuntime.js`（共 617 行；星谱相关约 90 行，下表按行号）。公共事件 9015 调 `CodexXuan.openStarchart()`，技能 10349「星谱」（场合＝菜单）只在战斗外可用（第 463 行）。星谱页没有自己的图和音效：全用云裳的选择窗 `CodexYunshang.choose`（Window_YunChoices）和菜单背景，别的页（屠苏器谱、种族祝福）同款。

| 项 | 原版（行） | 内容 | 重制现状 |
| --- | --- | --- | --- |
| 星谱状态 | 53～69 | `a._codexXuanChart = {sand, level{}, slots[3], partner, roster[], spent{}}`，三槽初值余辉／同调／移光各 1 级；`syncMarkSkills` 按槽学／忘星纹技能 | 已有（白龙 tusu1，`XTusuXuan.chart／sync_marks`，记 `s.flags._codexXuanChart`） |
| 熟练度 | 60 | `markLevel`：璇等级≥开槽等级（10／20／30）且槽里装的就是它才有 | **本期补**（`XXuanChart.mark_level`） |
| 星砂来源 | 434～441 | 璇在出战队、胜利一场＋3；敌群含 Boss ＋12 | **本期补**（`credit_victory`，接在 `battle_logic.grant`） |
| 学习／强化 | 514～519 | 3 级封顶，每级耗 10／15／25 星砂；强化（非首次学）的花费记入 `spent`；不够抛「星砂不足（需要N）」 | **本期补**（`learn`） |
| 回收 | 520 | 熟练>1 时退回 `spent` 星砂、降回 1 级（首次学习的不退） | **本期补**（`refund`） |
| 配槽 | 521 | 等级够且学过才能配进所属槽 | **本期补**（`equip`） |
| 星契自律 | 576～578、532 | 50 级＋进阶 3 阶才开放；手动／自动，只在战斗外改，存 `a._codexXuanControl` | **本期补开关**（`set_control`，记 `s.flags._codexXuanControl`）；自动战斗的行为属于璇的战斗机制，没做 |
| 命主名册 | 63、541 | 按进阶阶数 0～3 席，点人加入／移出，只留最后 N 人 | **本期补**（`toggle_roster`）；名册对战斗的影响（默契起手、保留）属战斗机制，没做 |
| 并轨副宿主、同调元素 | 533、535、542 | 队员里选一人／系统元素表里选一个，存 `partner`、`element` | **本期补**；效果属战斗机制，没做 |
| 星谱页 | 522～561 | 首页（说明 2 行＋7 行）→ 槽页 → 星纹页（配入／学习／回收）；队员页、元素页 | **本期补**（`ui/xuan_chart_page.gd`，照屠苏器谱 `XTusuForge` 的做法） |
| 地图入口 | CE9015 | 技能 10349 → CE9015 → 脚本 `CodexXuan.openStarchart()` | **本期补**（`mv_script`＋`map_scene.open_xuan_chart`），`skill_scene.MENU_UNBUILT` 清空 |
| 星纹的战斗效果 | 其余约 500 行 | 余辉、定星、先照、同调、分光、蚀辉、移光、并轨、留辉；回光／璃壁／棱光／列星；共宿、默契、星契调度 | **缺**，是璇的战斗机制（见「接续」） |

**对战斗的影响**：星谱页本身不动战斗数值。配进槽里的星纹通过 `markLevel` 被战斗机制读（如余辉熟练度 1/2/3 把回光溢出治疗按 20%/35%/50% 转护盾），所以本期的星谱页能配、能学、能攒星砂，但在重制里进了战斗暂时没有效果——璇的战斗机制还没做。星砂加成不进数值，只是学星纹的货币。
**存档字段**：`s.flags._codexXuanChart`（沿用）、`s.flags._codexXuanControl`（新增，自律开关）；`chart.element` 指定同调元素时才出现（同原版）；命主名册／副宿主存 `roster／partner`（沿用）。进阶阶数读 `s.actor_advance[177]`（原版 `_AdvancedNum`）。
**素材**：无专属图片、音效（选择窗、背景是公共的）。

## 变更记录草稿

## 2026-11-03 【cc·哪吒·未经审查】璇的星谱页期一：星砂、星纹学习与强化、名册／副宿主／元素、星谱页，技能「星谱」可用（dev.待定）

- 盘点：原版璇的星谱是 installNativeXuanRuntime.js 约 90 行（状态、星砂奖励、学习／回收／配槽、自律开关、云裳选择窗的三层页面），无专属素材。星纹的战斗效果在该文件其余约 500 行，重制还没有。
- 新增 `core/xuan_chart.gd`（`XXuanChart`）：`mark_level`、`learn`（3 级封顶，花费 10／15／25，不足抛「星砂不足（需要N）」，强化花费进 `spent`）、`refund`、`equip`（等级与学过的门槛）、自律开关 `set_control`（50 级＋进阶 3 阶，存 `s.flags._codexXuanControl`）、名册／副宿主／元素的改动、各页行文。
- 胜利星砂：`battle_logic.grant` 里 `XXuanChart.credit_victory`——璇在出战队、胜利一场＋3，敌群含 Boss ＋12；逃跑、失败、璇在后备都不加。
- 新增 `ui/xuan_chart_page.gd`（`XXuanChartPage`）：首页「星谱　星砂 n」→ 三槽 → 星纹（配入／学习／强化／回收）→ 队员页（并轨副宿主、命主名册）→ 元素页；取消逐层退回。`mv_script` 认 `CodexXuan.openStarchart()`，`map_scene.open_xuan_chart` 开页；`skill_scene.MENU_UNBUILT` 清空（星谱 10349 不再蜂鸣）。`script_census_known.json` 删 `CodexXuan.openStarchart();` 一条（E 类，已补好）。
- 参照：新探针 `mv_oracle/xuan_chart_probe.cjs`（25 例，产物 `xuan_chart.json`）→ `tests/fixtures/xuan_chart_oracle.json`；已登记 `同步正式西游.py` PROBES、`oracle_additions.py`。专项 `xiyou_xuan_chart` 128 项。
- 还没做：星纹和璇的战斗机制（附身、星契、回光／璃壁／棱光／列星、共宿、默契）——星谱页上配的星纹在战斗里暂时没有效果；自动战斗的行为；星砂的战斗外来源（原版也只有胜利）。

## 交接板

- 下一步：派璇的战斗机制（见下「接续」），先做 `CodexBinding` 里 xuan 的登记（`B.register('xuan', …)`，现在重制 `binding.gd` 只有框架），再逐个星纹。
- 用户试玩说明：玩家用璇（177）技能页的「星谱」不再蜂鸣，能打开星谱页配星纹、攒到的星砂可学习／强化／回收；星砂在战斗胜利后增加（普通＋3、Boss ＋12）。星纹战斗里的效果还没有。
- 需要用户决定：无

## 进度账

- 璇（177）：星谱页和星砂完成；战斗机制未做，璇整体完成度不变（依据：星纹战斗效果、附身等仍缺）。

## 可优化（流程／工具／效率）

- 建议：`并行测试.py` 对 battle_logic 一行改动选出 222 个场景（选测对照太宽），预计省 20～30 分钟；归工具车道，可按「改动只在 grant 内」收窄 `选测对照.json`。

## 验证

- 新探针 `xuan_chart_probe.cjs` 跑通（25 例，无 errors），产物拷到 `tests/fixtures/xuan_chart_oracle.json`；探针登记检查通过；`语法检查.py` 通过。
- 专项 `xiyou_xuan_chart` 128 项全过；反向验证：手改 Boss 星砂 12→13、回收不清 `spent`，专项当场报多项失败，已还原。
- 选测（`选测.py main --list` 因 `battle_logic.gd` 的一行改动列出 222 个场景，跑到 13/222 估计要几个小时，停掉了自己的任务，改跑相关的 27 个）：xiyou_xuan_chart、skill_menu_events（星谱改为可用，已改断言）、script_census（删一条已补好的已知项）、skill_page、determinism、battle、battle_drop、battle_ui、combat、settlement、tusu、tusu_ui、tusu_battle、binding、garou_battle、zhenqi、script、common_scripts、event_compare、race_battle、alien_battle、map、module_hooks、actor_modules、three_growth、help_card、rules_d1d，全部通过。
- 没跑另外约 195 个：`grant` 里新增的一行只在出战队有璇时才动星砂，其余场景（rules_*、smart_ai_*、floor_* 等）不碰；总装合并后按影响面再选测。

## 待交叉核查

- `battle_logic.gd`：`grant` 里新增一行 `XXuanChart.credit_victory`（战斗核心类文件，请沙僧／审查重点核）。
- 原版口径值得核：胜利星砂的 Boss 判定用 `boss_difficulty_boss`（对应 `CodexBossDifficulty.isBoss`），敌群含隐藏成员；璇「在队」按出战 `actors`（原版 `$gameParty.battleMembers()`）。

## 接续

- 璇的战斗机制：`B.register('xuan', …)`（附身、`onBind／onRoundStart／onRoundEnd`）、`cast`（回光／璃壁／棱光／列星）、共宿（gongsu）、默契（tacit）、命主名册读取（`isRoster`）、星纹各效果读 `XXuanChart.mark_level`。原版 `installNativeXuanRuntime.js` 第 77～512 行，约 430 行，建议拆 3 期。
- 星契自律开关只存在 `s.flags`，自动战斗读 `XXuanChart.control(s)`、`auto_qualified`。
- `meets`（`XTusuXuan.meets`）里璇的「寄星·附身」「列星」仍恒假，等璇的绑定期合进来再放开。

## 本分支提交

（填写）
