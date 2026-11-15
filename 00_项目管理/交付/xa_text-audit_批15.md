# 全库游戏文字审查——批 15（`modes/xiyou/ui/*.gd` 界面脚本 3/3，UI 完结）

> 所属总单：[xa_text-audit.md](xa_text-audit.md)
> 范围：`modes/xiyou/ui/` 下按文件名排序从 `orb_shop.gd` 至 `yunshang_shop.gd` 共 36 个非天启篇界面脚本（其中 27 个含玩家可见文字，合计约 570 段；至此 `modes/xiyou/ui/*.gd` 全部 82 个非天启篇界面脚本已全部审完）。

| 序号 | 位置 | 原文 | 问题 | 建议改成 | 级别 | 版本 |
| --- | --- | --- | --- | --- | --- | --- |
| 15-001 | `modes/xiyou/ui/party_status_panel.gd:269, 272, 274` | `_name_of(..., "undefined")` | 属性或特殊属性编号越界时，向玩家状态面板输出 JS 残留字样 `undefined`（同 13-006） | 兜底改为中文占位（如 `未知属性` 或 `属性#%d` % d） | 建议 | 两边都有 |
| 15-002 | `modes/xiyou/ui/power_panel.gd:146, 148` | `已穿装备` / `未穿装备，自身战力仍然有效。` | 口语「已穿／未穿」与全库统一口径「已装备／未装备」不一致（同 1-014、1-015、13-004） | `已装备` / `未装备，自身战力仍然有效。` | 建议 | 两边都有 |
| 15-003 | `modes/xiyou/ui/power_panel.gd:130, 143, 144, 150, 151, 154` | 战力胶囊、构成明细、评估说明与成长备注使用 `13` 号字 | 字号仅 `13`，在 1280×720 界面及手机端偏小难辨认（同 1-013、13-009） | 建议调大至 `15`～`16` | 建议 | 两边都有 |
| 15-004 | `modes/xiyou/ui/party_scene.gd:131, 133` | `"可击弱点:" + ...` / `"  高阶:有"` | 天启篇第 5 格助力位的新写提示使用了英文半角冒号 `:`，与其余新写界面全角冒号 `：` 不统一 | `"可击弱点：" + ...` / `"　高阶：有"` | 建议 | 天启篇 |
| 15-005 | `modes/xiyou/ui/status_page.gd:189` | `", \"%s\"" % nick` | 角色姓名与昵称之间使用了英文半角逗号与英文直引号（同 13-007） | `"，「%s」" % nick`（若严格对齐原版像素对照夹具则可维持） | 建议 | 两边都有 |
| 15-006 | `modes/xiyou/ui/test_mode_scene.gd:95, 100` | `"金币与角色"` / `"加钱"` | 将游戏货币「精魂」写为「金币／钱」；但本页仅在解锁 GM 调试模式时可见，普通玩家不可见 | 属内部 GM 调试面板，可不改；顺手统一可改为 `"精魂与角色"` / `"加精魂"` | 可不改 | 两边都有 |

> 批 15 复核：本批共核对 `modes/xiyou/ui/` 下后段 36 个非天启篇脚本（含 `pingbi_options.gd`、`scene_fade.gd`、`splash_screen.gd`、`tusu_forge.gd`、`xsound.gd`、`xtext.gd`、`xwindow_style.gd` 等无玩家直接文本或仅辅助转义脚本）。`orb_shop.gd`、`race_menu.gd`、`yunshang_shop.gd`、`update_page.gd`、`warning_screen.gd`、`power_forget.gd`、`touch_options.gd`、`shop.gd`、`save_scene.gd` 等新写或重构 UI 均口径一致、表达清晰。至此甲-05（`modes/xiyou/ui/*.gd`）批 13～15 全部收官。
