# 交付：cc/update-check1

- 车道／工作者：自动更新（工具与平台）／cc（update-check1）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·update-check1·未经审查】自动更新第①批：版本清单验签、版本比较、检查更新页（dev.待定）

- 背景：方案 v0.2（私密仓库 `重制设定/重制版_自动更新方案_v0.2.md`）第 3.2、3.5 节。本分支叠在 `cc/update-spike0` 上（用它的 `core/boot_patch.gd` 读底包编号），**要在 spike0 之后合并**。
- 做了什么：
  - `core/update_check.gd`（`XUpdateCheck`，纯函数）：版本号按段比较；清单 `channel.json` 的 SHA256withRSA 验签（公钥内嵌，私钥在 Kyo 的 Mac 上仓库之外）；清单解析；多个源里取验签通过、版本最高的一份；按底包编号和当前运行编号判断「已是最新／有补丁／要换整包／读不到」，并标出当前补丁是否被撤回。补丁条目要求字节数、64 位 SHA-256、全部 https 地址，否则不当补丁。
  - `core/update_client.gd`（`XUpdateClient`，根节点下单例）：依次读各清单源（Gitee 为主，GitHub 更新仓库经 jsDelivr 与 raw 当镜像，照 MOD 的做法），超时 10 秒，只发普通 GET、不带玩家信息；`auto_check()` 一天最多静默查一次（只在发行构建、非无头时），`has_update()` 给按钮红点用，结果记在 `user://updates/check.json`。
  - `modes/xiyou/ui/update_page.gd`（`XUpdatePage`）：「检查更新」页，五种状态；确定／取消键、点关闭、点暗处都能关；这一页开着时按键不漏到标题菜单。有补丁但下载器没接（第②批）时照「要换整包」提示去 QQ 群；下载器经 `XUpdatePage.patch_installer` 接入后显示大小和「立即更新」。
  - `tests/xiyou_update_check`（54 项）＋样例清单 `tests/fixtures/update_channel_sample.json／.sig`（用真私钥签的，验内嵌公钥与 openssl 签名对得上）。
- 没接线（故意）：没改 `entry.gd`，也没给原版标题加按钮（交接单：原版标题不加）。天启标题（PR #29，`XTianqiTitle`）合并接线时加三处，见「交接板」。在那之前这批代码不会被游戏调用，玩家看不到变化。
- 清单地址里的 `godot/` 子目录是按「补丁放进 MOD 现有两个更新仓库」的默认方案写的（Kyo 还没回）；换仓库只改 `XUpdateClient.channel_urls`。现在这些地址上还没有文件，客户端读到的是「读不到」。
- 验证：`xiyou_update_check` 54/54；另用本地假服务器（`python3 -m http.server`）走了一遍真实 `HTTPRequest` 路径：第一个源连不上、第二个源读到样例清单，内嵌公钥验签通过，结果「要换整包 0.9999」。`xiyou_boot_patch`、`xiyou_entry_release`、`ui_smoke`、`xiyou_determinism` 全过；`工具回归.py`、`语法检查.py` 通过。真 Gitee／jsDelivr 地址、真机网络没验。
- 待交叉核查：`core/update_check.gd` 的验签与判断（安全相关，建议按甲档看）、`core/update_client.gd`。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 重制行为 | 理由 | 回退方式 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·检查更新 | `core/update_client.gd` `XUpdateClient.ENABLED`／`AUTO`；`core/update_check.gd`；`modes/xiyou/ui/update_page.gd` | 重制版没有联网功能；MOD 在标题有更新按钮、启动后自动查 | 「检查更新」页读带签名的版本清单，进标题每天静默查一次、有新版亮红点 | Kyo 2026-11-11 批准自动更新开工（Gitee 托管，照 MOD 改版的做法） | `XUpdateClient.ENABLED = false` 不联网；`AUTO = false` 只在点按钮时查 | cc（update-check1） | 保留 |

## 交接板

- 下一步：PR #29（天启标题）合并接线时，在 `entry.gd` 加三处：①传给 `XTianqiTitle.setup` 的回调里 `"check_update": func(): XUpdatePage.open(self)`；②建好新标题后调一次 `XUpdateClient.instance(get_tree()).auto_check()`；③按钮红点看 `XUpdateClient.instance(get_tree()).has_update()`，并连 `checked` 信号在查完后刷新（红点怎么画由标题那边定）。交接单原来写的「公开游戏仓库放 `最新版本.json`」不用做了，清单走 Gitee 更新仓库。
- 下一步：第②批补丁下载与回退，接 `XUpdatePage.patch_installer`；`XUpdateCheck.evaluate` 结果里的 `revoked` 给自动退回用。
- 用户试玩说明：本批玩家看不到变化（按钮在天启标题那个 PR 里，接线后才出现）。
- 需要用户决定：无新增（补丁放哪个仓库、keystore 第二份备份位置，见 spike0 交付单）。签名私钥在 `~/Library/Application Support/KYO/发版密钥/godot_update_private.pem`，请 Kyo 另备份一份，丢了以后的清单旧客户端都不认。

## 进度账

- Windows／安卓扩展账：自动更新 约 10% → 约 35%（清单、验签、检查页完成；下载回退、发版工具、真机未做）。

## 可优化（流程／工具／效率）

- 建议：`选测对照.json` 加一组 `update`（`core/update_*.gd`、`core/boot_patch.gd`、`modes/xiyou/ui/update_page.gd` → `xiyou_update_check`、`xiyou_boot_patch`、`xiyou_entry_release`）；归工具车道。

## 本分支提交

- （见 git log main..cc/update-check1，叠在 cc/update-spike0 的三个提交上）
