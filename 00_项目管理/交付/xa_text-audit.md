# 全库游戏文字盘点与审查（小A / ag）

- 车道／工作者：文字盘点与审查（ag）
- 分支：`xa/text-audit`
- 状态：进行中（已完成全库盘点＋**批 1～批 16**，`ui/*.gd` 已收官，继续推进批 17～批 20）

## 三句话总结

本次在 `03_再刷重制_Godot/01_Godot工程` 盘出玩家可见文字总计约 **65,200 段**，其中甲类（重制／天启篇新写或改写）约 **11,080 段**、乙类（原版 MV 转换数据与地图对话）约 **54,140 段**，按每批 300～600 段拆为甲类 20 批、乙类约 108 批推进。目前已审完**批 1～批 16**（引擎入口、通用壳、全部 40 个 `tianqi*` GDScript、`tianqi_data/` 全部 28 个 JSON 含 `skill_rework.json` 全量 2,203 项技能与状态／装备、全部 `modes/xiyou/ui/*.gd` 界面脚本以及 `modes/xiyou/core/*.gd` 前 1/3；批 4～16 见 [批4](xa_text-audit_批4.md)～[批16](xa_text-audit_批16.md)，累计 175 条记录：**必改 50 条、建议 108 条、可不改 17 条**），最严重的问题包括 `skill_rework.json` 数百条直露「见待办」「半成品招」「去掉」「删掉」「并进」「照原版」「天启篇:……去掉」及脚本类名 `XTianqiQiyinEffects` 等内部研发批注、空占位描述（`1801`/`2223` 等）、多处将「精魂」误作「金钱／金币」（含 `alien_workshop.gd` 与 `gear_info.gd`）、`6915` 心法倍率与实际不符、天启篇残留「初入西行」「道号」「修炼」以及未开放路线直出「还没修好」。接下来尚余甲类批 17～20（共用 `core` 后 2/3、`battle`/`map`、`rift_alien.json`、`alienation.json`、`recipes.json`、`guide_atlas.json`）及乙类批 21～128（`generated/` 原版数据与地图），正在按甲类顺序推进每批一提交。

---

## 一、全库玩家可见文字盘点表

### 甲类：重制／天启篇新写或改写的文字（约 11,087 段）

| 序号 | 来源（文件或目录） | 大约段数 | 所属版本 | 说明 |
| --- | --- | --- | --- | --- |
| 甲-01 | `scenes/entry_menu.gd`、`core/*.gd`（不含纯排序表 `zh_collate_data.gd`）、`content/modes.json`、`content/build_info.json`、`project.godot`、`export_presets.cfg` | ~85 段 | 两边都有 | 入口菜单、平台提示、触屏按键、版本／反馈、打包应用名 |
| 甲-02 | `modes/xiyou/entry.gd` + 40 个天启篇专属 GDScript（`modes/xiyou/core/tianqi*.gd`、`modes/xiyou/ui/tianqi*.gd`、`modes/xiyou/battle/tianqi_meter.gd`、`modes/xiyou/map/tianqi_table.gd`） | ~657 段 | 只天启篇（`entry.gd` 两边都有） | 标题与开局选档／难度／阵容、四骑士、七印、号卷、元素、天平／重铸、试炼、异化战斗提示 |
| 甲-03 | `modes/xiyou/tianqi_data/*.json`（不含 `skill_rework.json`，共 27 个 JSON） | ~1,280 段 | 只天启篇 | 四线剧情与异化（`war_line`、`death_line`、`plague_line`、`famine_line`）、`horsemen`、`summit`、`trumpet`、`qiyin_*`（7 表）、`affix_table`/`affix_text`、`elements_table`、`rewards` 等 |
| 甲-04 | `modes/xiyou/tianqi_data/skill_rework.json` | ~5,030 段（含参考名与 `kind` 共 10,625 段） | 只天启篇 | 技能 `desc`/`header`（~3,980 段）、状态 `name`/`state_note`（~718 段）、专属装备 `desc`（~350 段） |
| 甲-05 | `modes/xiyou/ui/*.gd`（除 `tianqi_*` 外共 62 个文件） | ~1,577 段 | 两边都有（`pets.gd` 等仅重制版） | 角色／成长／流萤帮助、说明卡、宝珠坊、异化作坊、检索、设置、更新日志、图鉴、传送等 |
| 甲-06 | `modes/xiyou/core/*.gd`（除 `tianqi*` 外 102 个有中文文件）、`modes/xiyou/battle/*.gd`（12 文件）、`modes/xiyou/map/*.gd`（8 文件） | ~1,870 段 | 两边都有（`fest_*`、`lobby_corruption`、`gojo` 等为新写） | 真气、引导、庆典与大厅异变、五条悟／宿傩、玄图、三增长、屠苏、云裳、战力／状态面板、战斗 HUD 与脚本 |
| 甲-07 | `modes/xiyou/alienation.json`、`rift_alien.json`、`recipes.json`、`guide_atlas.json` | ~639 段 | 两边都有 | `rift_alien.json` 为重制版新写（11 段）；其余 3 个由原版提取的工坊词条（73）、配方（463）、引导区段（92） |

> 注：`content/*/*.md`、`content/app_icon/来源.json`、`core/zh_collate_data.gd`、`modes/xiyou/appearances.json`、`modes/xiyou/zh_collation.json` 属开发说明或内部索引数据，玩家不可见，不计入审查批。

### 乙类：从原版 MV 转换来的数据文字（`modes/xiyou/generated/`，约 54,145 段）

| 序号 | 来源（文件或目录） | 大约段数 | 所属版本 | 说明 |
| --- | --- | --- | --- | --- |
| 乙-01 | `generated/db/System.json`、`UnifiedQuality.json`、`CodexDamageElements.json`、`CodexMerchants.json`、`CodexOrbs.json`、`CodexRaces.json`、`PlayerChangelog.json`、`EquipSuits.json`、`Runewords.json`、`MapInfos.json` | ~1,400 段 | 两边都有（以重制版为主） | 系统用语、货币／属性／元素名、品质与套装／符文之语名、图鉴表、更新日志、地图名 |
| 乙-02 | `generated/db/Actors.json`、`Classes.json`、`Enemies.json` | ~1,274 段 | 两边都有 | 角色名／称号／简介（339）、职业名（39）、敌人名（896） |
| 乙-03 | `generated/db/States.json` | ~2,170 段 | 两边都有 | 状态名与施加／持续／解除提示语（`message1`～`4`） |
| 乙-04 | `generated/db/Weapons.json`、`Armors.json` | ~6,381 段 | 两边都有 | 武器名称与说明（2,051）、防具名称与说明（4,330） |
| 乙-05 | `generated/db/Items.json` | ~4,551 段 | 两边都有 | 消耗品／材料／被动书／宝珠等名称与说明 |
| 乙-06 | `generated/db/Skills.json` | ~17,977 段 | 重制版玩家可见（天启篇部分由 `skill_rework.json` 覆盖） | 技能名称、说明、施放消息（`message1`～`2`） |
| 乙-07 | `generated/db/CommonEvents.json`、`Troops.json` | ~1,427 段 | 两边都有 | 公共事件对话（840）与选项（512）、敌群战斗对话（75） |
| 乙-08 | `generated/maps/*.json`（211 张含中文地图） | ~18,965 段 | 两边都有（部分开局／教派／招募事件在天启篇跳过） | 地图显示名（198）、事件对话行（8,394）、事件选项（10,373） |

### 批次拆分计划（每批 300～600 段，甲类在前）

- **甲类共 20 批**（约 11,087 段）：
  - **批 1（已完成，见下文）**：甲-01＋甲-02（引擎入口、通用壳、打包配置、`entry.gd` 与全部 40 个 `XTianqi*` / `tianqi_*.gd` 模块，约 620 段可见文本）
  - **批 2**：甲-03 前半（`famine_line`、`death_line`、`plague_line`、`war_line`、`horsemen`、`seg_alien`、`alien_gear`、`gojo_trials`、`summit`、`trumpet`、`rewards`、`balance_table`、`money_table`、`drop_table`、`gear_table`、`abyss_shelves`、`reforge`，约 540 段）
  - **批 3**：甲-03 后半（`qiyin_altar`、`qiyin_gear`、`qiyin_drop`、`qiyin_equip`、`qiyin_dragon`、`qiyin_dragon_run`、`qiyin_show`、`affix_table`、`affix_text`、`elements_table`，约 560 段）
  - **批 4～批 12**：甲-04（`skill_rework.json`：批 4 为 `states`＋`gear` 约 700 条可见字段；批 5～批 12 为 `skills` 约 3,980 条 `desc`/`header`，每批约 500 条）
  - **批 13～批 15**：甲-05（`modes/xiyou/ui/*.gd` 62 个 UI 文件，每批 480～550 段）
  - **批 16～批 19**：甲-06＋`rift_alien.json`＋`alienation.json`（`core`/`battle`/`map` 非天启脚本与异化配置，每批 320～510 段）
  - **批 20**：甲-07 剩余（`recipes.json` 463 段＋`guide_atlas.json` 92 段，约 555 段）
- **乙类约 108 批**（批 21～批 128，每批 ~500 段，只挑明显错字、乱码、控制符漏转、HTML 实体、半截句子）：
  - 批 21～23：乙-01（`System`、`Codex*`、`PlayerChangelog`、`EquipSuits`、`Runewords`、`MapInfos` 等）
  - 批 24～26：乙-02（`Actors`、`Classes`、`Enemies`）
  - 批 27～30：乙-03（`States`）
  - 批 31～43：乙-04（`Weapons`、`Armors`）
  - 批 44～52：乙-05（`Items`）
  - 批 53～88：乙-06（`Skills`）
  - 批 89～91：乙-07（`CommonEvents`、`Troops`）
  - 批 92～128：乙-08（`maps/*.json`）

---

## 二、审查记录

### 批 1：引擎入口、通用壳与天启篇 GDScript（`entry_menu` / `core` / `entry.gd` / 全部 `tianqi_*.gd`）

> 范围：`scenes/entry_menu.gd`、`core/*.gd`（不含 `zh_collate_data.gd`）、`content/modes.json`、`content/build_info.json`、`project.godot`、`export_presets.cfg`、`modes/xiyou/entry.gd` 及全部 40 个 `tianqi*` GDScript 文件（共检视约 707 条中文字面量，覆盖全部可见字符串）。

| 序号 | 位置 | 原文 | 问题 | 建议改成 | 级别 | 版本 |
| --- | --- | --- | --- | --- | --- | --- |
| 1-001 | `modes/xiyou/core/tianqi.gd:39` | `初入西行，熟悉玩法` | 天启篇新难度「寻常」的说明仍带西游题材用语「西行」（11-15 约定：天启篇新内容不用西游题材） | `初入高塔，熟悉玩法`（或 `初入险境，熟悉玩法`） | 必改 | 天启篇 |
| 1-002 | `modes/xiyou/core/tianqi.gd:366` | `$gamePlayer.SaveActorName = prompt("请输入你的道号","");` | 天启篇开局起名提示仍用修仙／西游词汇「道号」，与「方桌大厅」「神魔之塔」新题材违和 | `请输入你的名字`（或 `请输入你的代号`） | 建议 | 天启篇 |
| 1-003 | `modes/xiyou/core/tianqi_money.gd:289` | `return "修炼成功"` | 精魂加点升级提示用「修炼」（修仙／西游味重，且 `文字审_小A.md` #016 已提示规避「修炼」） | `强化成功`（或 `精魂强化成功`） | 建议 | 天启篇 |
| 1-004 | `modes/xiyou/core/tianqi_reforge.gd:90` | `return {"error": "金钱不足（要 %d）" % price}` | 实际扣除的是 `s.gold`，游戏货币统称「精魂」（`System.json` `currencyUnit`），`tianqi_money.gd` 均读 `currencyUnit`，此处误写「金钱」 | `return {"error": "%s不足（要 %d）" % [str(XDB.system().get("currencyUnit", "精魂")), price]}` | 必改 | 天启篇 |
| 1-005 | `modes/xiyou/core/tianqi_reforge.gd:119` | `return {"error": "金钱不足（要 %d）" % price}` | 同 1-004，锁词条重铸校验提示把「精魂」误写为「金钱」 | `return {"error": "%s不足（要 %d）" % [str(XDB.system().get("currencyUnit", "精魂")), price]}` | 必改 | 天启篇 |
| 1-006 | `modes/xiyou/core/tianqi_famine_alien.gd:411` | `"%s顺手摸走了 %d 金钱。打倒它就能拿回来。" % [e.display_name(), n]` | 战斗内实际扣取并返还的货币单位为「精魂」，写「金钱」与全局口径不一致 | `"%s顺手摸走了 %d 精魂。打倒它就能拿回来。"` | 必改 | 天启篇 |
| 1-007 | `modes/xiyou/core/tianqi_famine_alien.gd:421` | `"%s倒下了，摸走的 %d 金钱回来了。"` | 同 1-006，货币单位误写「金钱」 | `"%s倒下了，摸走的 %d 精魂回来了。"` | 必改 | 天启篇 |
| 1-008 | `modes/xiyou/core/tianqi_rewards.gd:260` | `out.append("%d 金钱" % int(sv.gold))` | 通关／天外裂结算奖励把货币写为「金钱」，与全局「精魂」口径不一 | `out.append("%d %s" % [int(sv.gold), str(XDB.system().get("currencyUnit", "精魂"))])` | 必改 | 天启篇 |
| 1-009 | `modes/xiyou/core/tianqi_money.gd:413` | `第 %d 层　已买 %d／%d　下一样 %d%s　身上 %d` | 前半「下一样」带单位 `%s`（精魂），后半「身上 %d」漏了货币单位，读起来像两套单位 | `第 %d 层　已买 %d／%d　下一样 %d%s　身上 %d%s` | 建议 | 天启篇 |
| 1-010 | `modes/xiyou/core/tianqi_money.gd:424-425` | `全队承伤 −%d%%` / `全队出伤 ＋%d%%` | 同句内「＋」用了全角加号，与邻近半角数值及全篇 `+50%` 习惯不统一 | `全队承伤 -%d%%` / `全队出伤 +%d%%`（至少统一用半角 `+`） | 建议 | 天启篇 |
| 1-011 | `modes/xiyou/core/tianqi.gd:697` | `……这条路还没修好。换一条吧。` | 面向玩家的未开放路线提示带开发口吻「还没修好」，破坏沉浸感 | `……这条路暂未开放，换一条吧。` | 必改 | 天启篇 |
| 1-012 | `modes/xiyou/ui/tianqi_line_cards.gd:192` | `还没修好` | 同 1-011，四线选卡界面标签直接向玩家写「还没修好」 | `暂未开放` | 必改 | 天启篇 |
| 1-013 | `modes/xiyou/ui/tianqi_line_cards.gd:165` | `var rcap := XUI.label("骑士遗物", 13, ...)` | 字号仅 `13`，1280×720 界面及手机端偏小难辨认 | 建议调至 `15`～`16` | 建议 | 天启篇 |
| 1-014 | `modes/xiyou/core/tianqi_alien_gear.gd:395` | `只能刻到背包里没穿、没锁定、没被占用的武器或防具上` | 口语「没穿」与全游戏统一口径「未装备」（见 `alienation.gd:35` 及 `文字审_小A.md`）不一致 | `只能刻到背包里未装备、未锁定、未绑定的武器或防具上` | 建议 | 天启篇 |
| 1-015 | `modes/xiyou/core/tianqi_reforge.gd:81, 113` | `只能重铸背包里没穿、没锁定的装备` | 同 1-014，「没穿」口语过重且与全游「未装备」口径不一致 | `只能重铸背包里未装备、未锁定的装备` | 建议 | 天启篇 |
| 1-016 | `modes/xiyou/core/tianqi_alien_gear.gd:433` | `未生效：本线新词条的战斗效果关着。` | 「关着」属开发者开关口吻（`DEBUG`/功能开关感），玩家不易懂 | `未生效：本路线新词条的战斗效果暂未启用。` | 建议 | 天启篇 |
| 1-017 | `modes/xiyou/core/tianqi_sect.gd:114, 117, 127, 130, 131` | `借1800肝帝积分`…`钱都不够，还想糊弄我？` / `这些钱不够啊` | 借贷标的物是「肝帝积分」，但提醒和校验文案却写成「钱都不够」「借钱／还钱」（L211/L233 选项亦写「借钱」「还钱」），货币指代打架 | 对话与选项统一改写为「积分」（如 `积分都不够`／`借积分`／`还积分`），或若设定即指代钱款也建议把提示语对齐 | 建议 | 天启篇 |
| 1-018 | `modes/xiyou/core/tianqi_sect.gd:561` | `一个是去副本协会的传送阵控制器，一个是牛马关的指路灯。` | 「牛马关」为原版第 67 层地图与物品 #386 原名，非新造西游内容；仅提醒句子节奏可顺保留 | 保持原文（原版专有名词） | 可不改 | 天启篇 |
| 1-019 | `modes/xiyou/core/tianqi_summit.gd:378` | `挑战34层守层者 鸿钧` | 第 34 层守层者「鸿钧」虽为原版塔层首领，但在天启篇专属登顶入口文本中属于东方仙道色彩较重的旧名，需确认天启篇登顶是否沿用原版 34 层 Boss | 若 34 层暂沿用原版首领可保持；若天启篇后续重做 34 层，建议一并替换 | 可不改 | 天启篇 |
| 1-020 | `modes/xiyou/core/tianqi_horsemen.gd:522, 782, 784` | `今日方知我是我：领悟仙法·百亿仙剑。` / `仙法：百亿仙剑` / `仙法：破产一剑` | 饥荒骑士「小镇做题家」（出自原版 3 层吕茂）玩梗台词含「仙法」，属角色原有梗迁移 | 保持原文（角色玩梗，非新西游世界观设定） | 可不改 | 天启篇 |
| 1-021 | `modes/xiyou/core/tianqi_trumpet.gd:148` | `"号卷：" + str(sc.name)` | 同类道具名（`被动书:止戈`、`元素转换:火焰`）均用半角冒号 `:`，唯「号卷：」用全角冒号；与全角中文标点规则存在新旧混用 | 若按新写内容全面全角化可保持 `号卷：`（后续把 `元素转换:` 等一并改全角）；若与既有道具前缀对齐则统一为一种 | 建议 | 天启篇 |
| 1-022 | `modes/xiyou/core/tianqi_trumpet.gd:164` | `选择一名角色，封上一卷已学的号卷` | 「封上一卷」作为操作动词略生硬（易误读为「封上面一卷」） | `选择一名角色，封印一卷已学的号卷`（或 `封存一卷已学的号卷`） | 建议 | 天启篇 |
| 1-023 | `modes/xiyou/core/tianqi_gear.gd:40` | `茉蕾的“一袋米扛几楼”和“一桶油喝几斤”额外增加三段伤害，伤害+%d%%` | 新写天启文本混用了弯引号 `“”`，与全篇统一的直角引号 `「」` 不一致 | `茉蕾的「一袋米扛几楼」和「一桶油喝几斤」额外增加三段伤害，伤害+%d%%` | 建议 | 天启篇 |
| 1-024 | `modes/xiyou/core/tianqi_qiyin.gd:628` | `%s·毕业武器（%s）〔%s〕` | 使用了全项目仅见一次的六角括号 `〔〕` 标明光辉／成色 | `%s·毕业武器（%s）【%s】`（或 `「%s」`） | 建议 | 天启篇 |
| 1-025 | `modes/xiyou/core/tianqi_qiyin.gd:381` | `献一把本印毕业武器（这次毕业武器几率翻倍、必是同类）` | 概率用词在项目里混用「几率」与「概率」（如 `liuying_help.gd` 用「概率」）；「同类」可更明确 | `献一把本印毕业武器（本次毕业武器概率翻倍、必为同类型武器）` | 建议 | 天启篇 |
| 1-026 | `modes/xiyou/core/tianqi_elements.gd:849` | `"元素转换:" + ename` | 新写高阶元素转换书命名用了半角冒号 `:`，与 `号卷：`（全角）不一致 | `元素转换：` + `ename`（注：`<pos=APs text=\c[1]效果:...>` 的半角 `:` 为引擎正则解析锚点，**不可改**） | 建议 | 天启篇 |
| 1-027 | `modes/xiyou/core/tianqi_elements.gd:1184` | `当前阶段：P%d` | 面向玩家的战中提示里直接露出了英文缩写 `P1`/`P2` | `当前阶段：第 %d 阶段` | 建议 | 天启篇 |
| 1-028 | `modes/xiyou/entry.gd:284` | `继续切后台时自动存的档` | 对比 L274 按钮 `继续（切后台时自动存的档）`，标题去掉括号后「继续切后台时…」读起来有歧义 | `继续（切后台自动存档）`（或 `读取切后台自动存档`） | 必改 | 两边都有 |
| 1-029 | `export_presets.cfg:34` | `application/name="再刷重制"` | `[preset.1] macOS 发行` 的 `application/name` 仍是旧名「再刷重制」，而 Windows 发行、Android 发行及 `project.godot`（`config/name.tianqi_release`）均已改为「再刷一把：天启篇」 | `application/name="再刷一把：天启篇"`（若仅靠 `project.godot` 的 feature override 生效可确认导出产物名） | 必改 | 两边都有 |
| 1-030 | `core/touch_controls.gd:31-33, 726-730` | `确定`/`取消`/`跑步` vs `确认`/`返回`/`跑` | 虚拟按键默认文案写「确定／取消／跑步」，`full` 布局却映射成「确认／返回／跑」，同一控件两套叫法 | 统一为 `确认`／`取消`（或 `返回`）／`跑步` | 建议 | 两边都有 |
| 1-031 | `content/modes.json:5` | `"title": "西游改版"` | 仅在开发预览总入口（`entry_menu.gd`）可见，发行版跳过入口直进游戏；若后续保留模式选择页需与「天启篇」命名对齐 | 开发期可保持；若公开发布多模式入口再改 | 可不改 | 两边都有 |

> 批 1 复核：以上已逐条核对 `scenes/entry_menu.gd`、`core/*.gd`、`content/*.json`、`project.godot`、`export_presets.cfg`、`modes/xiyou/entry.gd` 及全部 40 个 `tianqi*` GDScript 文件。其中 `tianqi_elements.gd:869-886`、`tianqi_gear.gd:139`、`tianqi_trumpet.gd:139,150,164` 中的 `<pos=APs text=\c[1]效果:...>` 为 `honghuang.gd:47` 等正则表达式解析的格式标签，半角 `:` 属协议锚点，不判问题；`tianqi.gd:624` 的「莉co」与 `tianqi_horsemen.gd:496` 的「莉co特调」经查 `horsemen.json` 为策划原定角色名，不判错字。


---

### 批 2：天启篇配置表（一）——四线剧情、骑士、登顶、号卷、奖励与异化基础（17 个 JSON）

> 范围：`modes/xiyou/tianqi_data/` 下 `famine_line.json`、`death_line.json`、`plague_line.json`、`war_line.json`、`horsemen.json`、`seg_alien.json`、`alien_gear.json`、`gojo_trials.json`、`summit.json`、`trumpet.json`、`rewards.json`、`balance_table.json`、`money_table.json`、`drop_table.json`、`gear_table.json`、`abyss_shelves.json`、`reforge.json`（扣除 `_note`/`source` 等开发注释后约 535 段玩家可见文字）。

| 序号 | 位置 | 原文 | 问题 | 建议改成 | 级别 | 版本 |
| --- | --- | --- | --- | --- | --- | --- |
| 2-001 | `tianqi_data/famine_line.json` `scenes.omen_arrive[5][1]` | `不花东西的技能……也要交一份口粮。只有普通的攻击和防御不用。` | 「不花东西」过于口语，与代码日志 `tianqi_famine_alien.gd:223` 的「不花资源的技能」口径不一致 | `不消耗 MP 或 TP 的技能……也要交一份口粮。只有普通的攻击和防御不用。`（或 `不花资源的技能……`） | 建议 | 天启篇 |
| 2-002 | `tianqi_data/famine_line.json`、`death_line.json`、`plague_line.json`、`war_line.json` `scenes.final_win` 末行 | `已完成，已验证。（未经姐姐复核）` | 四线终战胜利均以这句收尾，属于小小鱼对开发流程玩梗的元叙事彩蛋；仅提醒普通玩家可能看不懂「姐姐」指谁 | 保持原文（剧情彩蛋）；若不想暴露元叙事可改回正常台词 | 可不改 | 天启篇 |
| 2-003 | 四线 JSON `scenes.choose[1][1]` | `这次的世界我想再改一次，你帮我验收。` | 「验收」同样带开发口吻元叙事彩蛋，和「像在看一个改东西的人」呼应 | 保持原文（或改为 `你帮我看着`） | 可不改 | 天启篇 |
| 2-004 | 四线 JSON `scenes.apostle30[1][1]`（`famine`/`plague`/`death`/`war`） | `玉皇大帝的身子干瘪了下去…` 等 | 点名 30 层原版既有首领「玉皇大帝」为使徒，属引用既有塔层 Boss 而非新造西游内容 | 保持原文（如后续 30 层换 Boss 再同步替换） | 可不改 | 天启篇 |
| 2-005 | `tianqi_data/summit.json` `scenes.not_ready[0][1]` | `……这条路还没修好。先回去吧。` | 与 1-011 同源，面向玩家直出开发口吻「还没修好」 | `……这条路暂未开放，先回去吧。` | 必改 | 天启篇 |
| 2-006 | `tianqi_data/summit.json` `scenes.honghuang_ask[0][1]` | `注意：保留存档，对话后只有一个新游戏可以获取洪荒通关奖励，后续要继续新游戏获取洪荒通关奖励得重新对话！\n是否保存了？` | 「只有一个新游戏可以…」语序略拗口，且两处重复「获取洪荒通关奖励」 | `注意：请先保留当前存档！对话后仅限下一个新游戏领取洪荒通关奖励；若之后还要新开档领取，需读档重新对话。\n确认继续吗？` | 建议 | 天启篇 |
| 2-007 | `tianqi_data/summit.json` `scenes.honghuang_done[0][1]` | `你已完美通关！后续新游戏可以获取1000人道碎片，18星神。\n20万肝帝积分，并且洪荒之家永久开启。` | `18星神。` 后用了句号导致清单被错误截断成两句，且「并且」前无主语断句生硬 | `你已完美通关！后续新游戏可获取 1000 人道碎片、18 星神、\n20 万肝帝积分，并永久开启洪荒之家。` | 必改 | 天启篇 |
| 2-008 | `tianqi_data/trumpet.json` `forget.desc` | `选择一名角色，封上一卷已学的号卷。每次消耗1枚，号卷不返还。` | 同 1-022，「封上一卷」易读成「封上面一卷」 | `选择一名角色，封印一卷已学的号卷。每次消耗 1 枚，号卷不返还。` | 建议 | 天启篇 |
| 2-009 | `tianqi_data/trumpet.json` `scrolls[0].lore` | `雹子与火搀着血落下，地的三分之一被烧` | 错别字：「搀着」意为搀扶，「混合」应为「掺着」 | `雹子与火掺着血落下，地的三分之一被烧` | 必改 | 天启篇 |
| 2-010 | `tianqi_data/trumpet.json` `scrolls[2].sweet` | `自己上的持续效果 +33%：持续伤害、持续回复的数值，减益的回合数` | 「自己上的」过于口语 | `自己施加的持续效果 +33%：持续伤害、持续回复的数值，减益的回合数` | 建议 | 天启篇 |
| 2-011 | `tianqi_data/trumpet.json` `scrolls[6].bitter` | `金钱掉落 −30%` | 游戏中货币统一叫「精魂」（`System.json`），写「金钱」与全局口径不符 | `精魂掉落 −30%` | 必改 | 天启篇 |
| 2-012 | `tianqi_data/rewards.json` `seal.lines.death.text`、`seal.lines.war.text`、`relic.lines.death.text` | `……有 %d%% 几率……` | 概率用词与其余系统「概率」不一致 | `……有 %d%% 概率……` | 建议 | 天启篇 |
| 2-013 | `tianqi_data/rewards.json` `relic.lines.war.text` | `满 %d 点对敌全体火焰轰炸一次` | 与 `tianqi_war_alien.gd`「我方全体」及 `tianqi_qiyin_effects.gd`「敌方全体」写法不统一 | `满 %d 点对敌方全体火焰轰炸一次` | 建议 | 天启篇 |
| 2-014 | `tianqi_data/alien_gear.json` `new_affixes.again.benefit` | `按级每 {every} 回合（侵染／蚀骨／化形／终焉）多行动一次。` | 回退文案中残留未替换模板占位符 `{every}`（且 `dying`/`thrift` 硬编码化形档数值，与分档数组不一致）；当 `TIER_TEXT=false` 或 `idx < 0` 时会直接显示给玩家 | 改为不带 `{every}` 的安全兜底文案（如 `按异化等级每数回合多行动一次。`），或确保所有调用走分档拼接 `tier_benefit` | 必改 | 天启篇 |


---

### 批 3：天启篇配置表（二）——七印体系、词条表与元素转换表（10 个 JSON）

> 范围：`modes/xiyou/tianqi_data/` 下 `qiyin_altar.json`、`qiyin_gear.json`、`qiyin_drop.json`、`qiyin_equip.json`、`qiyin_dragon.json`、`qiyin_dragon_run.json`、`qiyin_show.json`、`affix_table.json`、`affix_text.json`、`elements_table.json`（共约 560 段玩家可见文字）。

| 序号 | 位置 | 原文 | 问题 | 建议改成 | 级别 | 版本 |
| --- | --- | --- | --- | --- | --- | --- |
| 3-001 | `tianqi_data/affix_text.json` `affixes[28].line`、`affixes[28].detail` | `经验、金钱 +{v}%` / `战斗获得的经验、金钱 +{v}%。全队相加，助力位身上的也算。` | 词条面板与详情说明直接把游戏货币「精魂」写成了「金钱」（同 `affix_table.json` `affixes[28].effect`），属新写词条表与全局货币名冲突 | `经验、精魂 +{v}%` / `战斗获得的经验、精魂 +{v}%。全队相加，助力位身上的也算。` | 必改 | 天启篇 |
| 3-002 | `tianqi_data/affix_table.json` `affixes[14].effect` | `最终伤害 +%` | 内部表 `affixes[14]`（`final_damage`）写作「最终伤害」，但 `affix_text.json` 对玩家明确写明「造成的伤害 +{v}%。和其他伤害加成、先声、背水、猎首在同一个池里相加，不另乘一次」，且玩家界面不直接读该字段 | 仅同步内部表口径：`造成的伤害 +%`（`affix_text` 面向玩家的解释已准确） | 可不改 | 天启篇 |
| 3-003 | `tianqi_data/affix_text.json` `affixes[20,23,25,41]` | `……几率……` | 与游戏其他新写系统（「概率」）混用 | 统一为 `概率` | 建议 | 天启篇 |
| 3-004 | `tianqi_data/qiyin_gear.json` `schools.zhen.mark[0].text`、`artifacts[0].effects[0].text` | `……33% 几率……` | 同 3-003，「几率」与「概率」混用 | 统一为 `33% 概率` | 建议 | 天启篇 |
| 3-005 | `tianqi_data/qiyin_gear.json` `artifacts[3].effects[1].text` | `对首领生命低于 33% 时伤害 +33%` | 语序缺主谓结构（「对首领……时伤害」） | `对生命低于 33% 的首领伤害 +33%` | 必改 | 天启篇 |
| 3-006 | `tianqi_data/qiyin_gear.json` `weapons[6].effects[0].text` | `打倒敌人后对另一个敌人再斩一次（伤害 50%），能一直连下去` | 实际代码 `tianqi_qiyin_effects.gd:25` 设了防死循环上限 `chain_max = 9`（通常敌群不超过 9 只，玩家感知基本等同连斩，仅作核实记录） | 保持原文（或标注 `最多连斩 9 次`） | 可不改 | 天启篇 |
| 3-007 | `tianqi_data/qiyin_altar.json` `scenes.first_clear[0][1]` | `首通：多给了一件本印套装件。` | 「套装件」略生硬（同 `qiyin_equip.json` `exchange_set`），建议稍作顺口化 | `首通：多给了一件本印套装部位。`（或 `本印套装装备`） | 建议 | 天启篇 |
| 3-008 | `tianqi_data/qiyin_equip.json` `names.melt_none`、`names.exchange_set` | `……副件在背包里。` / `一件随机部位的套装件（%d 个）` | 「穿着的先卸下」（`dismantle_none`）用「穿着的」，而 `melt_none` 写「副件在背包里」，略欠统一；「套装件」同 3-007 | `dismantle_none` 建议改 `已装备的先卸下`；`套装件` 建议改 `套装部位` | 建议 | 天启篇 |
| 3-009 | `tianqi_data/elements_table.json` `conversion_books.*.name` | `元素转换:自然` / `元素转换:水` / `元素转换:风` / `元素转换:虚空` 等 | 新写道具名用了半角冒号 `:`（同 1-026），与 `号卷：`（全角）不统一 | `元素转换：自然` 等（全角冒号；若保留原版道具命名风格则全系统一） | 建议 | 天启篇 |
