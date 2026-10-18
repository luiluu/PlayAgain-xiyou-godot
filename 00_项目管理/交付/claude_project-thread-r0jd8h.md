# 交付：claude/project-thread-r0jd8h

- 车道／工作者：数据与说明卡（不占 A/B 车道独占文件）／Claude 云端项目线程（用户 2026-10-18 派的第 2 项：特殊角色与专属装备数据）
- 状态：可合并

## 变更记录草稿

## 2026-10-18 【Claude·未经Codex检验】特殊角色技能与专属装备说明卡（dev.待定）

- 用户 2026-10-18 要求补齐特殊角色（技能 10122～10299，角色 167～178）与专属装备（心之钢、狂妄等）的数据，让切片能扩到这些角色、说明卡的动态描述做完。
- 新探针 `03_转换工具/mv_oracle/special_help_probe.cjs`：在冻结正式源的内存新游戏里，把这些角色删掉成未招募的图鉴预览态（初始等级、未学会、0 阶），对每个技能和专属装备调用 `Sprite_ItemHelp.setItem`，记录逐行文字、字号、颜色、y、对齐与卡片宽高；另记 12 名角色的图鉴技能表。共 222 个技能、1 件武器、37 件防具。已登记进 `同步正式西游.py` 的 PROBES 与 `oracle_additions.py`。
- 转换器 `xiyou_export.py` v17→v18：新增 `db/CharacterHelp.json`（`installDisplayPreferencesRuntime` 的 characterHelpCopies 24 组、DYN2_IDS 159 个，以及屠苏、璇的成长表 CFG.growth），并记录输入 SHA。
- 新模块 `modes/xiyou/ui/character_help.gd`（XCharacterHelp），照搬 characterHelpView、nowGrowthView 与 dyn2View，以及渡鸦、伏黑甚尔（CodexToji）、绑定（curve、bindGrowth）、屠苏、璇、哈基米（CodexCat）、魔冠（DemonCrown）、云裳法衣颜色等角色模块用到的说明卡算法。`help_card.gd` 接上这个模块：特殊目标走它，绑定武器的技能不画「伤害属性」行，`<HelpWidth: N>` 决定卡片宽度。
- 验证：新测试 `tests/xiyou_special_help` 逐行对照参照数据，共 276/276。技能 222/222、武器 1/1，防具 26/37 一致；其余 11 件列在测试的 PENDING 里，写明原因，一旦开始一致就会报错提醒移出。`xiyou_help_card` 仍是 428/428。云端 `检查.sh`（CHECK_JOBS=4）的 Godot 测试全部通过，只有文档段的 49 个失效链接未过，都指向只在 Mac 上的本地结果或外部路径，与本分支无关。
- 未完成：法宝 4001、4577、4580 的「法宝战力」要等 XPower 的法宝战力；饿狼形态 7904～7911 要等形态系统；云裳遗物 7935 的等级和经验行要等遗物系统。
- 是照原版搬，不改行为，所以不需要优化登记。

## 交接板

- 下一步：车道 A（悟空）把 `xiyou_slice.json` 扩到角色 167～178 时，技能表直接取 `generated/oracle/special_help_cards.json` 的 `actors[*].skills`，说明卡已经能用。本分支没动切片。
- 下一步：法宝、饿狼形态和云裳遗物系统做好后，把对应装备从 `tests/xiyou_special_help.gd` 的 PENDING 移出。
- 合并时：转换器升到 v18，又新增了探针，所以 `main` 要完整重跑一次 `同步正式西游.py --accept-additions`。本分支是在云端做的，没有车道指纹。
- 用户试玩说明：特殊角色的技能和专属装备，说明卡现在与正式版的图鉴预览一致。
- 需要用户决定：无

## 进度账

- 界面·说明卡：特殊角色部分从「未做」变为技能完成、专属装备 26/37；完成度由核查者复核，执行者不自评。

## 本分支提交

- b6858f3 WIP：特殊角色技能说明卡（characterHelpView）与正式版逐行一致
- cf2f828 法宝待做清单、云裳法衣颜色、探针登记进同步脚本
- （本交付单提交）
