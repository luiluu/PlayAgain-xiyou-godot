# 交付：luiluu/t385

- 车道／工作者：T385 混合脚本里的天启篇玩法名字符串进包／cc（Opus 5.5＋medium；原车道额度用完停手，同工作树续做）
- 状态：可合并

## 变更记录草稿

## 2026-11-22 【cc·天启篇·未经审查】T385 发行空壳：混合脚本里的天启篇玩法名字符串在发行克隆里换成占位，check 能查到这一类（dev.待定）

- 起因：T381「可优化」——不换空壳、带真脚本进包的混合脚本里写着烙印、心魔、号卷等字，走不到但随真脚本进包、解包能看到；`suspects` 只看文件名、头注释和路径，查不到。
- 做法（协调批的方案 A，游戏脚本一字不改）：`发行空壳.py` 加 `TIANQI_WORDS`（天启篇独有说法）＋ `MIXED_STR` 登记表（路径 →（条数, 为什么走不到））。`make_tree`（发行出包、发布补丁都走它）在发行克隆里把登记文件命中的字符串字面量换成只剩格式符的同引号占位（`"%s 的烙印加深至「%s」"` → `"%s%s"`，`%` 运算照样不报错）；注释、三引号行不动。
- 查：`发行空壳.py check`／`make_tree` 遇到没登记的文件命中、或登记文件条数变多就报错（新写天启篇字进混合脚本会被拦，要么登记要么挪进 XTianqi* 模块）；条数变少只提示。`is_stub_tree`（`发行内容审计.py --tree` 用它）查登记文件在克隆里已换干净。
- 回退：`MIXED_STR` 清空即不换（`TIANQI_WORDS` 不命中就不报）。
- 玩家可见：无（发行包里这些分支本来就走不到；西游档、天启篇开发档都不变）。

### 清单（21 个说法，10 个文件 44 条，都登记、都换）

`号卷|封卷|七印|烙印|刻印|天启之路|天启篇词条|异化核|骑士遗物|毕业武器|炼狱、证道|证道难度|炼狱难度|装备重铸|重铸第|重铸哪件|已重铸|不能重铸|不会重铸|重铸词条|洗其余`

| 文件 | 条数 | 为什么发行走不到 |
| --- | --- | --- |
| modes/xiyou/core/zhenqi.gd | 11 | 闭关页烙印分支（961～1012），都在 `XTianqiBrand.on(s)` 后面，空壳恒 false |
| modes/xiyou/core/guide.gd | 2 | 354 烙印标题在 `XTianqiBrand.status_rows` 非空时（空壳给 []）；470 在 `_tianqi_milestone_on`（`XTianqi.active`） |
| modes/xiyou/core/power_books.gd | 4 | 号卷说法都是 `XTianqiTrumpet.on()` 真分支 |
| modes/xiyou/ui/power_forget.gd | 8 | 号卷／封卷说法都是 `tq＝XTianqiTrumpet.on()` 真分支 |
| modes/xiyou/ui/alien_workshop.gd | 13 | 216 tq_on 分支；265 confirming_core（只由天启篇取核钮置真）；379/381 `_core_section`（tq_on 才调）；399～422 `_reforge_section`、434/442 该节按钮回调（`XTianqiReforge.on` 才调） |
| modes/xiyou/ui/save_scene.gd | 1 | 「天启之路」行在 `save_line(d)` 非空时，`XTianqiLook.line_of_save` 空壳给 "" |
| modes/xiyou/ui/skin/skin_save_page.gd | 1 | 新界面，发行恒关（`XUiSkin.on` 要 `XTianqiLine.open_for`） |
| modes/xiyou/ui/skin/skin_main_menu.gd | 2 | 七印行在 `seal_states` 非空时＋新界面 |
| modes/xiyou/ui/skin/skin_options_page.gd | 1 | 环纹说明只在新界面设置页 |
| modes/xiyou/ui/skin/ui_skin.gd | 1 | 工坊菜单「异化工坊」说明，新界面才显示 |

### 保留（不换）和理由

- **心魔、骑士、炼狱、权能、异化**：原版就有（zhenqi.gd 的 `TRIAL_TROOP["心魔"]`、`"kind": "心魔"` 还是逻辑键，换了会坏）。
- **单独的「重铸」**：天启篇才有，但 `alien_workshop.gd:49` 按钮样式正则 `PRIMARY_RE` 里也有，整条换成 "" 西游档按钮会全变主色；所以只认带上下文的说法。
- **「天启篇」**：发行包应用名就是「再刷一把：天启篇」（core/release_entry.gd:9，Kyo 11-05 定）；fest_text.gd:120、save_transfer.gd:50（导出文件建议名）、map_scene.gd:193（日志）、skin_options_page.gd:60 只出这个词，不算外泄。
- **skin_showcase.gd:198「见习骑士」**：样例页假数据，不是玩法名。
- **查不到的（盲区）**：没有固定玩法名的天启篇规则长文——guide.gd `milestone_intro`／`milestone_texts` 的天启篇分支（452～498，按 `_tianqi_milestone_on`）讲高塔、难度、掉落，用的是通用词；要拦得把文字挪进 XTianqi* 模块，本单不动游戏脚本，没做。

## 交接板

- 下一步：下一次出补丁／整包时，这 10 个文件在发行克隆里内容变了（只换字），补丁会带上它们一次；推不推照旧等 Kyo 点名。
- 用户试玩说明：无（发行包、开发档都看不出变化）。
- 需要用户决定：无。

## 进度账

- 无（流程工具）。

## 可优化（流程／工具／效率）

- `发行内容审计.py` 审包时只查空壳标记，没解开混合脚本的 .gdc 查 `TIANQI_WORDS`；出包前 `make_tree` 已拦，包侧再查一道约 20 分钟，归工具车道。
- guide.gd 天启篇规则长文（见盲区）可挪进 `XTianqi*` 文字模块，那样换空壳就带不出去，归文字车道（玩家可见字过小A）。

## 验收（派单 4 条）

1. ✓ 清单见上（10 文件 44 条）。
2. ✓ 全部剥离（发行克隆里换占位），保留项写了理由；`check`／`make_tree` 能查到这一类。
3. ✓ 游戏脚本零改动（本分支只改 发行空壳.py、测试发行空壳.py、本交付单）；发行克隆里 10 个换过的脚本无头 `load()` 都编译过，`发行空壳.py smoke`（xiyou_battle、xiyou_battle_ui）通过，`发行内容审计.py --tree` 通过。
4. ✓ 交付自检结论「可以交付」；`测试发行空壳.py` 24/24（新增两条）；`工具回归.py` 全过；`发行空壳.py check` 通过；云端选测 14 场景 3 片通过（提交 89d036d16c，run 45032318521，gh run watch 前台等完；本单改动本身选 0 个 Godot 场景，14 个是基准差带来的）。

## 本分支提交

- 见 git log（T385）
