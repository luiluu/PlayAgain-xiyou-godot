# 全库游戏文字审查——批 18（`modes/xiyou/core/*.gd` 核心脚本 3/3，Core 完结）

> 所属总单：[xa_text-audit.md](xa_text-audit.md)
> 范围：`modes/xiyou/core/` 下按文件名排序从 `runewords.gd` 至 `zhenqi.gd` 共 40 个非天启篇核心脚本（其中 28 个含玩家可见文字或正则匹配中文，合计约 554 段；至此 `modes/xiyou/core/*.gd` 全部 148 个非天启篇脚本已全部审完）。

| 序号 | 位置 | 原文 | 问题 | 建议改成 | 级别 | 版本 |
| --- | --- | --- | --- | --- | --- | --- |
| 18-001 | `modes/xiyou/core/training.gd:52` | `PARAM_NAMES[i] + "修炼"` | 天启篇精魂加点页（`XTianqiMoney.training_on()`）的 8 项名称仍叫「最大生命修炼」「物理攻击修炼」等，与 1-003「修炼成功」同源，残留修仙／西游用词 | `PARAM_NAMES[i] + "强化"`（并与 1-003「强化成功」同步） | 建议 | 天启篇 |
| 18-002 | `modes/xiyou/core/training.gd:94, 104, 105` | `"下一级费用%sw"` / `_wan(...) + "w"` | 费用单位直接使用网络缩写字母 `w`（如 `10w`），而游戏其余大数均用中文「万／亿」（`guyu.gd`、`power.gd`、`guide.gd`） | `"下一级费用%s万"` / `_wan(...) + "万"` | 建议 | 两边都有 |
| 18-003 | `modes/xiyou/core/treasure_map.gd:100, 101, 162, 166, 170, 174, 178, 182, 186, 189` | `"%s 坐标:%d,%d"` / `"目标位置:%s %d,%d"` / `"获得物品:"` / `"获取物品失败: 请重新使用"` 等 10 处 | 藏宝图挖宝与奖励提示全部使用英文半角冒号 `:`，与全库全角冒号 `：` 规范不统一 | 统一改为全角冒号 `：`（如 `"%s 坐标：%d,%d"`、`"目标位置：%s %d,%d"`、`"获得物品："`） | 建议 | 两边都有 |
| 18-004 | `modes/xiyou/core/yomi_jingliu.gd:428-433` | `"特效:星魂 I：月犯天关：最大生命＋100%"` 等 6 条 | 同一行说明内「特效」后用半角冒号 `:`，后面「星魂 I：」又用全角冒号 `：`，标点混用（注：L441 过滤依赖 `contains("特效:星魂")`，改时需同步） | `"特效：星魂 I：月犯天关：最大生命＋100%"` 等（同步更新 L441 匹配条件） | 建议 | 两边都有 |
| 18-005 | `modes/xiyou/core/save_transfer.gd:44` | `"再刷重制存档%02d_%s.json"` | 天启篇应用名已改「再刷一把：天启篇」（见 1-029），默认导出存档文件名仍写死「再刷重制存档」 | 按版本分支改为 `"天启篇存档%02d_%s.json"`（或统一 `"再刷存档%02d_%s.json"`） | 建议 | 天启篇 |
| 18-006 | `modes/xiyou/core/xconfig.gd:203` | `["四倍", "三倍", "二倍", "OFF"]` | 战斗加速前三档为中文，关闭档沿用英文 `"OFF"`（同 14-007） | 可保持；若统一中文可改为 `"关闭"`（或 `"原速"`） | 可不改 | 两边都有 |
| 18-007 | `modes/xiyou/core/test_mode.gd:275` | `"已增加金币 %d，当前金币 %d。"` | 将货币「精魂」写作「金币」（同 15-006），但仅在解锁 GM 调试工具后可见，普通玩家不可见 | 属内部 GM 工具，可不改；顺手统一可改为 `"已增加精魂 %d，当前精魂 %d。"` | 可不改 | 两边都有 |

> 批 18 复核：本批共核对 `modes/xiyou/core/` 末段 40 个非天启篇脚本（含 `safe_sell.gd`、`save_transfer.gd`、`skill_share.gd`、`sukuna.gd`、`test_mode.gd`、`three_growth.gd`、`toji.gd`、`training.gd`、`treasure_batch.gd`、`treasure_map.gd`、`tusu.gd`、`vegeta_tune.gd`、`xconfig.gd`、`xsave.gd`、`xuan_battle.gd`、`xuan_chart.gd`、`yomi_jingliu.gd`、`yunshang.gd`、`yunshang_orders.gd`、`zhenqi.gd` 等）。`three_growth.gd`、`tusu.gd`、`xuan_battle.gd`、`xuan_chart.gd`、`yunshang_orders.gd`、`zhenqi.gd`、`safe_sell.gd`、`save_transfer.gd` 表达准确、口径统一（`xuan_chart.gd:188` 已通过 `MAX_LABEL_FIX` 兜底「已满级」，不会输出 `undefined`）；`save_slim.gd`、`skill_mastery.gd`、`xdb.gd`、`xsave.gd`、`zh_collation.gd` 的 `push_warning`/`push_error` 为开发日志，不计入玩家可见文字。至此 `modes/xiyou/core/*.gd` 全部审完。
