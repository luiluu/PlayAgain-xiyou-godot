# 全库游戏文字审查——批 17（`modes/xiyou/core/*.gd` 核心脚本 2/3）

> 所属总单：[xa_text-audit.md](xa_text-audit.md)
> 范围：`modes/xiyou/core/` 下按文件名排序从 `gear_upgrade.gd` 至 `rift_alien.gd` 共 51 个非天启篇核心脚本（其中 28 个含玩家可见文字或正则匹配中文，合计约 527 段）。

| 序号 | 位置 | 原文 | 问题 | 建议改成 | 级别 | 版本 |
| --- | --- | --- | --- | --- | --- | --- |
| 17-001 | `modes/xiyou/core/growth_forge.gd:233, 241` | `"选择: " + str(source.name)` / `"%s · %s:%d%s"` | 同文件 L232 已使用全角冒号（`%s：选择一件%s升级……`），而 L233 与 L241 却使用英文半角冒号 `:`（`"选择: "`、`"心钢层数:%d"`），标点不统一 | `"选择：" + str(source.name)` / `"%s · %s：%d%s"` | 建议 | 两边都有 |
| 17-002 | `modes/xiyou/core/hang_up_auto.gd:467` | `"%s 剩余: %d"` | 挂机恢复摘要向玩家展示药水余量时使用了英文半角冒号加空格 `: ` | `"%s 剩余：%d"` | 建议 | 两边都有 |
| 17-003 | `modes/xiyou/core/power_books.gd:60` | `"……请先用" + XTianqiTrumpet.forget_name() + "封上已有号卷"` | 与 1-022、2-008 同源，「封上已有号卷」读起来略生硬且易与「封上面」混淆 | `"……请先用" + XTianqiTrumpet.forget_name() + "封印已有号卷"`（或 `"封存已有号卷"`） | 建议 | 天启篇 |
| 17-004 | `modes/xiyou/core/power.gd:870, 878` | `"战力见状态"` vs `"战斗力 " + format(p.total)` | 主菜单同处混用简称「战力」与全称「战斗力」，略欠统一；但沿用原版 `CodexCombatPower` 既有显示 | 可保持；若统一简称可改为 `"战力 " + format(p.total)` | 可不改 | 两边都有 |
| 17-005 | `modes/xiyou/core/guyu.gd:869` | `"。\n转移不回复HP"` | 战斗内生命储备转移提示使用英文缩写 `HP`，其余文字为中文「生命」（同 14-007 属原版常见缩写） | 可保持；若统一中文口径可改为 `"。\n转移不回复生命"` | 可不改 | 两边都有 |

> 批 17 复核：本批共核对 `modes/xiyou/core/` 中段 51 个非天启篇脚本（含 `gear_upgrade.gd`、`gojo.gd`、`growth_forge.gd`、`guide.gd`、`guyu.gd`、`hang_up_auto.gd`、`heartsteel.gd`、`honghuang.gd`、`hubris.gd`、`item_bag_return.gd`、`item_marks.gd`、`liuying.gd`、`mira.gd`、`orbs.gd`、`passive_books.gd`、`pets.gd`、`pingbi.gd`、`power.gd`、`power_books.gd`、`race.gd`、`race_battle.gd`、`raven.gd`、`rift.gd`、`rift_alien.gd` 等）。其中五条悟（`gojo.gd`）、谷雨（`guyu.gd`）、宝珠（`orbs.gd`）、种族祝福（`race.gd`）、时空漩涡（`rift.gd`、`rift_alien.gd`）及引导页（`guide.gd`）文本整体通顺规范；`gojo.gd` 与 `module_registry.gd` 中的 `push_error` 为开发日志，不计入玩家可见文字。
