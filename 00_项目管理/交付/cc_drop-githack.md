# 交付：cc/drop-githack

- 车道／工作者：总装四十一（cc）
- 状态：可合并

Kyo 2026-11-13「删掉备用源」：0.01.09 上线时 githack 地址返回 403。发布补丁.py 写清单时不再给补丁带 githack 地址；线上 0.479 清单已手工去掉并重新签名推送。

## 变更记录草稿

## 2026-11-13 【cc·总装四十一】发布补丁清单去掉 githack 备用源（dev.待定）

- Kyo 原话「删掉备用源」。`package_urls` 不再产出 rawcdn.githack.com 地址；测试发布补丁 19/19。
- 线上：0.479 清单两个发版仓库都已去掉 githack 并重签（github 04a4b26、gitee 97f7f0b）。
