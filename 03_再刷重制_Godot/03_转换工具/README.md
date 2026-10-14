# 转换工具

【Claude·未经Codex检验】｜2026-10-12

只读取正式西游应用的当前版本，输出写入独立目录；不能覆盖原版、旧 MOD 或真实存档。每次转换记录输入 SHA、工具版本、输出清单、无法处理项与实际验证结果。

## mv_oracle：MV 参照引擎

无画面加载正式西游 `app.nw` 的完整 MV 引擎、165 个启用插件与全部 Codex 运行模块（Node + jsdom），作为 Godot 重写的「标准答案」：同一输入分别交给 MV 与 Godot 计算，逐项比对伤害、状态、掉落等结果。

- `hboot.cjs`：复制自 Louis 工程 `strength-recheck-20261010-210743/sim/hboot.cjs`（源 SHA256 `de6f861e…cbaf5b0`），新增文件系统守卫——写入只限 `.sandbox/`，屏蔽 Application Support、作者钥匙与真实存档路径。插件在加载数据库时会写自身缓存（如 `RpgJiban*.rpgsave`），一律落在沙盒内，不是玩家存档。
- `boot_check.cjs`：参照引擎启动检查。
- `slice_probe.cjs`：内存新游戏的三难度首期能力/伤害对照，只输出到 `.sandbox/slice/`；每份数据附原始数据库、版本与运行脚本指纹。验收后在资料库侧复制到 Godot 的 `generated/oracle/`。
- `equipment_rules.py`：将装备/强化备注、GT 套装与符文之语插件参数转成纯 JSON 规则，不执行来源备注代码。
- `equipment_probe.cjs`：在内存新游戏中固定随机数，测装备、强化材料、套装与符文之语；输出只写 `.sandbox/equipment.json`，验收后复制到 `generated/oracle/`。
- `help_probe.cjs`：在内存新游戏中对物品（1～200）、武器/防具（1～60）、切片角色技能、随机词缀装备实例调用正式版 `Sprite_ItemHelp.setItem`，记录实际画出的每一行（文字、字号、颜色、y、对齐）与卡片宽高；只写 `.sandbox/help_cards.json`，验收后复制到 `generated/oracle/`，供 Godot 说明卡（XHelpCard）对照。
- `hang_up_probe.cjs`：七个挂机子页窗口、技能次数/顺序、正常战后回血/回蓝/复活、七档卖出状态与 64 种品质星级；只写 `.sandbox/hang_up.json`，核验后复制到 `generated/oracle/`。固定能力值隔离不移植的 growth；初始化成就为已领取、绕过场景退出与死亡停止以单测吃药分支，实际战后调用另由 Godot 测试覆盖。与其余四探针一起重跑并核验来源。
- `source_identity.cjs`：两种探针共用的原始数据与运行脚本指纹。
- `验证西游来源.py`：只读核对正式来源、转换产物和三难度及装备参照；`检查.sh --oracle` 会调用。来源变化或产物损坏时报告失败，不自行覆盖。
- 依赖：`npm install`（jsdom 24.1.3、lz-string 1.5.0；`node_modules/` 与 `.sandbox/` 不入 Git）。

注意：正式版脚本文件名含形近的非拉丁字符（如 `rpg_managеrs.js` 中的西里尔字母 е），匹配文件名时不能手打。

- `options_probe.cjs`：正式引擎内存配置的默认值、33项顺序与文字、48组音量改值、4组跑步/Shift和角色指令/技能记忆，战斗显示/变速，消息提醒子页（notices）、核心杂项开关与遇敌抽签（misc）、屏蔽掉落子页与实际掉落过滤（pingbi）、队列跟随（follow）；只写 `.sandbox/options.json`，验收后复制到 `generated/oracle/`。来源同步需同其余六探针一起重跑。
- `sequence_probe.cjs`：YEP_BattleEngineCore 解析后全部技能/物品的五段行动序列（每项 SHA-1，另存少量全文样本）；只写 `.sandbox/sequences.json`，验收后复制到 `generated/oracle/`。`验证西游来源.py` 逐项核对转换器（v10 起）导出的 `yepSeq`。来源同步时与其余七探针一起重跑。
- `event_probe.cjs`：地图事件对照参照（效率改造第二步）。用正式 Game_Interpreter 逐个运行 Godot 导出的切片事件页（generated/maps）与切片公共事件，每个用例从同一内存新游戏开始（难度 3、队伍 1/8/10/9、所在地图为事件地图，公共事件用大厅），只跑该页指令；应答固定（选项默认项、同组第 4 次起取最后一项、数值 0、prompt「测试」、战斗胜利、Math.random 固定 0.5），场景/存档/商店只记录。输出每个用例的 trace（文字、选项、场所移动、战斗、商店、场景、存档、输入、提示、预约公共事件）与状态变化 delta；只写 `.sandbox/events.json`，复制到 `generated/oracle/`（同步正式西游.py 自动做）。读转换产物的位置可用环境变量 XIYOU_GENERATED 指定。Godot 侧对照见 `tests/xiyou_event_compare`。

## 同步正式西游.py：正式源更新后的一键重同步

备份 generated 的 oracle/db/maps/manifest/slice 到 `04_验证/本地结果/自动同步/<时间>_<旧版>-<新版>/`，重跑转换器与全部探针（PROBES 表），去掉来源身份比较全部参照，列出改动的来源文件、数据记录编号与地图，再运行 `验证西游来源.py`。测量全不变且核对 0 问题时写来源清单并更新来源登记与当前状态（`--no-register` 不写）；有变化时退出码 2，报告在备份目录 `同步报告.json`，交人工查看。`--generated` 可指向副本试跑。新增探针要加进 PROBES。

## 事件指令统计.py

统计正式全部 231 张地图、公共事件与敌群事件用到的事件指令，按次数排序并标出 Godot `MVInterpreter._execute` 已有/未有的指令；插件指令按首词、脚本按首行写法归类。报告写到 `04_验证/本地结果/事件指令统计/报告.json`。2026-10-14 首次结果：124,995 条指令中有处理分支的占 97%；缺口主要是脚本（355，约 1.4 万条，toaster 提示、成就奖励、按变量取角色等）、插件指令（Difficulty、crafting、ShopInventory 等）与敌群事件的强制行动（339）。用来决定先翻译什么。

