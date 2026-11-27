# 交付：luiluu/t566

- 车道／工作者：T566 天启篇状态说明接通（cc，Sonnet＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-27 【cc·T566·未经审查】天启篇状态说明接进状态窗：150 个原来看不到的补上（dev.待定）

- 玩家可见：天启篇里 150 个状态的效果说明现在能在状态窗看到；原来有些状态连状态格都不显示，现在会显示。独奏风暴、野调终章的目标栏改为「敌方全体」，奥能轰炸改为「随机攻击四次，可重复命中同一敌人」。
- 起因：改写表写了 `state_note`，但原版记录没有 `<StateNote>` 块时替换不到，整句被丢掉（T528 只给 7 个贝吉特状态开了 `state_note_append`）。
- 改法（`core/tianqi_skills.gd` `rec_state`）：非空 `state_note` 在原记录没有该块时默认补一段；`state_note_append: false` 可单独关掉；空说明不补。T528 写的 7 个 `true` 保留。
- 数目（按 T528 合入后的表）：带 `state_note` 的状态 331 个，非空 301 个，其中 150 个接通前进不了运行时（把默认值改回 false 跑专项复现为 150）。派单写的「204」是 T528 当时的口径，和这里按「非空且进不了」数的不同。10801 起的新状态走 `new_state_rec` → `rec_state`，一并覆盖。
- 顺带修一处缓存（`battle/side_status.gd`）：状态格的「可见／类别」缓存原来只按状态号记。接通后一批原来隐藏的状态在天启篇变可见，同一次开游戏里换到西游档会沿用缓存、跟着显示。改成用现成的 `XTianqiSkills.state_key(id)` 分开记。撤掉这处修改时专项 `side_cell_cache_per_mode` 得 `[true,true,true,true]`（应为 `[true,false,true,false]`）。
- 追加两条（T528 复核遗留）：三招目标栏（`skill_rework.json`，段数和浮动仍在正文）；`天启篇数据校验.py` 加 `state_note_append` 布尔校验，字符串 `"false"`／`"true"`、0、1、null 都报错。T528 专项里认奥能轰炸旧目标栏的一条断言同步改。
- 西游档零改动：改写只在天启篇卡开着时生效；专项逐条比对西游档记录与原表一致，缓存分开后西游档状态格显示不受天启篇影响。

## 交接板

- 下一步：新接通说明清单待小A 文字审（见下「待小A 审」）。
- 用户试玩说明：天启篇战斗里点状态格，更多状态有效果说明。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：`天启篇数据校验.py` 或专项以后可直接查「写了 state_note 的状态，运行时记录里要有」（本单专项 `xiyou_tianqi_t566` 已覆盖，无需另做）。

## 待小A 审（本单没改句子）

- 清单：[新接通说明清单](../交付截图/luiluu_t566/新接通说明清单.md)（150 条）。三招目标栏的新字也要过。
- 看到的疑点（只按状态名里带数字筛过，不是通读）：2561 状态名「减伤90%」、说明「受到的伤害 −10%」；2564 状态名「追加攻击次数+3」、说明「攻击次数 +1」。
- 另见：1819「夜龙一炬」状态窗归在「增益」页签，说明是每回合受火焰伤害。分类来自记录的 BuffType／特性，本单没改。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqiSkills.rec_state` | 调用方 2 处（`git grep -nE '(^\|[^[:alnum:]_])rec_state[[:space:]]*\(' -- '*.gd'`） | `xdb.gd:222`（XDB.rec 包装）、`tianqi_skills.gd:436`（新状态）：签名不变，只是备注可能多一段说明块；`XTianqiGeneralBooks.rec_state` 是另一个函数，原本就会补块 |
| `XSideStatus._kind_cached` | 调用方 5 处（同上换函数名） | `side_status.gd:157` 与 `xiyou_side_status_order.gd` 4 处：签名不变，只换缓存键；该专项本机通过 |
| `XSideStatus._visible_cached` | 调用方 2 处（同上换函数名） | `side_status.gd:156`、`xiyou_tianqi_t566.gd`：签名不变，只换缓存键 |

## 验收

1. ✓ 非空说明全部进运行时记录，队员状态窗说明与改写表一致（专项逐个比对 301 个；派单的「204」口径见上）；抽 10 个带窗口静音截图。首领状态窗只查了记录里有说明块，没有另截图。
2. ✓ 西游档零改动（专项比对记录；缓存串档有回归）。
3. － 文字审：待小A。

截图（`00_项目管理/交付截图/luiluu_t566/`）：state_560、state_706、state_848、state_854、state_902、state_1099、state_1819、state_2554、state_2733、state_10808（.png）。重截命令见 `tests/t566_shots.gd` 文件头。

## 测试

- 本机：`xiyou_tianqi_t566` 10/10；同批跑过 `xiyou_tianqi_t528`、`xiyou_party_status_panel`、`xiyou_side_status_order`、`xiyou_boss_status`、`xiyou_tianqi_pool_text`、`xiyou_tianqi_qishi_states`、`xiyou_tianqi_skills` 均通过。
- `测试天启篇数据校验.py` 163/163；`天启篇数据校验.py` 退出码 0；`语法检查.py` 0 问题；`工具回归.py` 全部通过；`发行空壳.py check` 退出码 0。
- 云端选测：通过，提交 d420f0c842，95 个场景、16 片，`gh run watch` 前台等到完成，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45931241424

## 本分支提交

- c6b15e662 WIP：专项（先红）＋状态格缓存分模式＋截图工具
- d420f0c84 默认接通＋三招目标栏＋布尔校验＋截图
