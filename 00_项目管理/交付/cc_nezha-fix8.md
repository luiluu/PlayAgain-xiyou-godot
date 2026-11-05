# 交付：cc/nezha-fix8

- 车道／工作者：BC 哪吒 fix8（cc；只改工具；基于 main，与 fix7 互不依赖）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·nezha·未经审查】云端选测：下载 Godot 遇 GitHub 下载服务故障多重试、报清楚（dev.待定）

- 依据：11-05 run 42045550417 的 prepare 挂在 `curl -fsSL --retry 3 …/SHA512-SUMS.txt` 退出 22（下载 CDN 临时 504；`--retry 3` 不重试 404／5xx 以外的 HTTP 错误）。
- ①缓存：Godot 二进制本来就在 actions/cache（`~/.cache/xiyou-godot`，键 `godot-v2-<环境登记.json 哈希>`，版本号在登记里，换版本键就变），命中不下载；本次不用改，只有缓存未命中才下载。
- ②`云端选测.py` 新增 `download()`：`curl -fsSL --retry 5 --retry-all-errors --retry-delay 10`（环境变量 XIYOU_DL_DELAY 可调间隔，测试用）；`cmd_godot` 的 zip 与 SHA512 清单都走它。`云端准备.sh` 同样加了重试参数。
- ③都失败时报「GitHub 下载暂不可用（下载服务临时故障，不是代码问题），稍后重跑即可：<地址>」，不再抛 curl 退出码。
- 回归：`测试云端准备.py` 加 `CloudDownloadTests`（假 curl 恒退 22，断言提示文字与三个重试参数）；`bash -n 云端准备.sh`、工具回归全过。未在真实 Actions 上跑。

## 优化登记草稿

无（只改云端工具）。
