# 交付：luiluu/t556

- 车道／工作者：T556 角色图鉴备注统一改写／小A（Hydrogen＋high，P7，文字主管）
- 状态：可合并

## 变更记录草稿

## 2026-11-27 【小A·T556·未经审查】天启篇人物图鉴全员 163 位备注统一补齐（dev.待定）

- 依据：Kyo 11-27 附图原话（事项 84 定稿：五人样稿通过，全员两行无前缀版式铺开；谷雨／屠苏／璇／哈基米按同样标准收束、去等级倍率；选 A 新建天启篇数据表＋只读模块，只在天启篇图鉴生效、西游档 `Actors.json` 零改动）。
- 根因与全员盘点：`modes/xiyou/generated/db/Actors.json` 中渡鸦、米拉、黄泉、镜流、伏黑甚尔、宿傩、饿狼、云裳 8 人及 `modes/xiyou/core/gojo.gd` 的五条悟，因 `<ActorNote>…</ActorNote>` 写成单行未被多行解析识别而图鉴无备注；其余旧备注普遍缺玩法特点、夹带内部数值或出戏元信息。天启篇人物图鉴可见全员共 163 位（167 有名 − 5 隐藏 + 180 五条悟）。
- 数据表 `modes/xiyou/tianqi_data/actor_notes.json`（version 1）：
  - 覆盖天启篇图鉴可见全员 163 位角色（1～180）；每名角色严格两行无前缀——`story`（一两句角色故事）＋`trait`（角色定位与天启篇真实玩法特点），依据 `Actors.json`、`Classes.json`、`Skills.json`、`tianqi_data/skill_rework.json`、`six_dim.json` 与 `gojo.gd` 核对撰写，不含任何内部数值、百分比、倍率、等级、编号或出戏元信息（玩家可见文字，小A 执笔，交付后派 cc Sonnet 文字审，D276）。
- 只读查询模块 `modes/xiyou/core/tianqi_actor_notes.gd`（`XTianqiActorNotes`）：
  - 提供 `ENABLED` 回退开关（默认 `true`，设 `false` 回退原版 `Actors.json` `<ActorNote>`）与 `lines_of(id)`；只认天启篇存档（`XTianqi.active`），西游档或发行空壳恒返回 `[]`，发行空壳 `发行空壳.py check` 退出码 0（规则 2 自动生成空壳，零天启篇文字泄漏）。
- 图鉴接线：
  - `modes/xiyou/ui/skin/skin_book_page.gd`（`actor_info`）与 `modes/xiyou/ui/actor_book.gd`（`status_ops`）在天启篇优先读取 `XTianqiActorNotes.lines_of(id)`，西游档或开关关闭时原样回退旧 `<ActorNote>` 逻辑，零改动。
- 校验与测试：
  - `03_转换工具/天启篇数据校验.py` 与 `03_转换工具/测试天启篇数据校验.py` 新增 `actor_notes_rules`／`check_actor_notes` 与 `ActorNotesT556` 单测（检查 163 人齐全、名字一致、非空、长度、中文句号、禁数字／倍率／禁词），`天启篇数据校验.py` 全过、单测 159/159 通过。
  - 新增专项 `tests/xiyou_tianqi_actor_notes.tscn`（14/14）：覆盖天启篇全员 163 人新旧图鉴两行读取、原无显示 9 人（167～174 与 180 五条悟）可见、五人样稿与 175～178 收束、`ENABLED = false` 回退与西游档零改动；并同步回归 `tests/xiyou_ui_skin_card_p.tscn`（106/106）、`tests/xiyou_tianqi_six_dim_radar.tscn`（33/33，同 T482 口径在比六维单开关时临时关闭 `XTianqiActorNotes.ENABLED`）、`tests/xiyou_actor_book.tscn`（28/28）。
  - 没跑云端：遵循附则 A 小A 仅前台单跑几秒检查、不后台不跑云端 watch；本机已前台单跑上述全部相关场景、数据校验与发行空壳 check 均退出码 0。
- 玩家可见：天启篇人物图鉴全员 163 位角色（含原无显示的宿傩、渡鸦、米拉、黄泉、镜流、伏黑甚尔、饿狼、云裳、五条悟）现均展示统一两行备注：第一行一两句角色故事，第二行角色定位与玩法特点，不含内部数值与编号；西游档保持原版不变。

## 交接板

- 下一步：总装合并 `luiluu/t556` 后，按 D276 派 cc Sonnet 审阅 `modes/xiyou/tianqi_data/actor_notes.json` 全员玩家可见文字。
- 用户试玩说明：在天启篇档打开「人物图鉴」，翻看任意角色（如小铃兰、宿傩、钟离、渡鸦、雪清寒、五条悟、谷雨等），牌底「备注」均为清爽两行「角色故事＋定位与特点」，不再出现缺备注、内部数值或测试元信息；西游档图鉴保持原样。
- 需要用户决定：无（事项 84 三项口径与 5 人样稿已由 Kyo 拍板通过）。

## 进度账

- T556 角色图鉴备注统一改写：0% → 100%（全员 163 位定稿、只读模块与新旧图鉴接线、数据校验与 4 项 Godot 测试全部通过）。

## 可优化（流程／工具／效率）

- 已做：在 `03_再刷重制_Godot/03_转换工具/天启篇数据校验.py` 增加 `actor_notes.json` 规则自检（覆盖全员 163 人、禁数字与禁用元词、长度与句号），防后续新增角色漏填备注或混入内部数值（回退：从 `CHECKS` 列表移除 `('actor_notes', check_actor_notes)`）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XSkinBookPage.actor_info` | 8 处调用（`git grep -nE '[^[:alnum:]_]actor_info[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/'`，共 9 处含 1 处定义） | 调用方 8 处逐处结论：`skin_book_page.gd:353` 刷新右大牌备注（天启篇取新两行、西游档原样不变）；`tests/xiyou_ui_skin_card_p.gd:187/240/252` 比对新旧图鉴字段与颜色，因旧页 `status_ops` 同步接线，实测 106/106 全过；`tests/xiyou_tianqi_actor_notes.gd:60/90/91/98` 为本单新增专项，实测 14/14 全过。 |
| `XActorBook.status_ops` | 13 处调用（`git grep -nE 'XActorBook\.status_ops[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/'` 12 处＋本文件 `actor_book.gd:571` 1 处） | 调用方 13 处逐处结论：`actor_book.gd:571` 旧图鉴窗口绘制（天启篇取新两行每 32 字切行，西游档零改动）；`tests/xiyou_actor_book.gd:160` 西游参照逐字比对，西游档返回空走原逻辑，实测 28/28 全过；`tests/xiyou_ui_skin_card_p.gd:186` 与新页逐段对齐，实测 106/106 全过；`tests/xiyou_tianqi_six_dim_radar.gd:88/94/96/99/111/119` 中第 119 行只测六维单开关，已按 T482 先例临时关 `XTianqiActorNotes.ENABLED` 后恢复，实测 33/33 全过；`tests/xiyou_tianqi_element_effects.gd:1390/1396` 只核「角色属性」行存在与否，不受备注段影响；`tests/xiyou_tianqi_actor_notes.gd:73/99` 为本单新增专项，14/14 全过。 |
| `XTianqiActorNotes.ENABLED` | 新增回退开关（`modes/xiyou/core/tianqi_actor_notes.gd:8`） | 默认 `true`；设 `false` 时 `active()` 恒 `false`、`lines_of()` 恒 `[]`，天启篇图鉴一键回退原版 `Actors.json` `<ActorNote>`。 |

## 本分支提交

- 72c92bd60 WIP: [T556] 角色图鉴备注 5 人样稿与盘点交付单
- d2aa23b4c [T556] 天启篇人物图鉴全员 163 位备注统一补齐与接线校验
