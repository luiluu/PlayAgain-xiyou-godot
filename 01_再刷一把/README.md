# 再刷一把：Steam 原版

目标是 [Steam 原版《再刷一把 PlayAgain》](https://store.steampowered.com/app/2059790/)，AppID 2059790。用户已在 PD Windows 下载，安装目录为 `C:\Program Files (x86)\Steam\steamapps\common\再刷一把 PlayAgain`。

[原版调用说明](./03_原版分析/原版调用说明.md)提供只读访问入口。已核对 Steam AppID、BuildID 11735036、Depot manifest 8064319545780814456，并实际读取 rpg_core.js；其内容不是普通 UTF-8 脚本文本，完整封装/规则/纯净基准审计仍待完成。用户明确不制作原版 Mac 移植。

| 目录 | 用途 |
| --- | --- |
| [01_待接收原版](./01_待接收原版/README.md) | 从 PD 复制过来的安装目录与 Steam manifest |
| [02_已核对原版](./02_已核对原版/README.md) | 核对后固定的原版基准，保留原始内容 |
| [03_原版分析](./03_原版分析/README.md) | 版本、引擎、数据、插件与系统规则分析 |

来源与状态统一登记在 [来源登记](../00_项目管理/来源登记.json) 和 [当前状态](../00_项目管理/当前状态.json)。

西游魔改发布包与 `source-1.57` 是另一项目的资料，不作为此处的原版来源。
