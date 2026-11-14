# 交付：cc/force-update

- 车道／工作者：B 界面＋自动更新／cc（Orca worker，Opus＋medium）
- 状态：可合并

## 做法

- **清单**（`core/update_check.gd`）：`channel.json` 加两项，schema 不变——`min_playable`（最低可玩的开发编号）、`download_url`（手动下载页，只认 https）。`XUpdateCheck.evaluate` 多返回 `forced`、`min_playable`、`download_url`：现在运行的号低于 `min_playable`、且清单真有更新的版本才算强制。老清单没有这项＝不强制；老客户端只看 schema 和 latest，多的字段读到不出错。
- **启动前门**（新 `modes/xiyou/ui/force_update.gd`，`XForceUpdate`）：西游标题 `_ready` 一开始就后台查一次清单（`XUpdateClient.check`，同一套源、验签和 10 秒超时，每次启动都查，不受每天一次限制）。片头动画和声明屏放的时候在查，出标题时（`_title`、`_tq_build_title` 末尾）按结果处理：
  - 强制 → 盖强制更新框，标题整个盖住、进不去；
  - 连不上、清单坏、验签不过 → 放行，标题左上角一行「未能检查更新」；
  - 没有 `min_playable`、版本够新 → 放行，照旧红点；
  - 出标题时还没查完 → 先盖「正在检查更新」（关不掉），查完再定；等满 15 秒（`WAIT_SEC`）还没回来就放行，结果晚到、人还在标题本页且要强制，再盖上来。
  - 只在发行构建、非无头时查（发行入口冒烟、云端无头都不联网、不拦；测试用 `allow_headless`）。
- **强制更新框**（`XUpdatePage.open_forced`，同一页的另一种样子）：底色不透明；取消键、点暗处都关不掉，右边按钮是「退出游戏」（安卓返回键照旧两下退出）。
  - 能装补丁：「更新」→ 下载（原来的多源、续传、校验）→ 备份存档、登记 →「立即重启」（安卓「退出游戏」，玩家再点开）。
  - 下载失败：一直留在框里，「再试一次」＋「手动下载」按钮，正文写出链接；不会失败几次就放行。
  - 底包太旧（只能换整包）或游戏内装补丁关着：只给「打开下载页」。
  - 清单没给 `download_url`：正文照旧写「请到 QQ 群 … 的群文件下载」，没有下载按钮（项目里没有现成的下载页地址，见「需要用户决定」）。
  - 打开下载页用 `OS.shell_open`（安卓打开系统浏览器），同时把链接复制到剪贴板。
  - 已经下好、只差重启（`pending_code` 够新）时直接是「已准备好」。
  - 上次的更新启动失败被自动退回时，框里照旧说明，并给「手动下载」。
- **发布工具**（`07_开发环境/发布补丁.py`）：加 `--min-playable <号>｜latest｜0`、`--download-url <https>｜none`。不给就沿用清单原值（默认不改）；`--min-playable` 比本次发布的号大会被拒（装到最新也进不去），`latest` 等于本次发布的号，`0` 取消强制；下载页不是 https 会被拒。README：`07_开发环境/README.md`、`05_发布/README.md`「强制更新」。
- **回退开关**：O-待定-1 `XForceUpdate.ENABLED = false` 启动不查、不拦，回到只有红点。

## 验证

- 新专项 `xiyou_force_update`（47 项，本机通过；`ReleaseEntry.simulate_release`＋假清单源＋本进程 127.0.0.1 小 HTTP 服务器，不连外网）：低于／等于／高于 `min_playable`、没有字段、字段不是数字、清单没有新版本、底包没有补丁只能整包、下载页不是 https；断网、清单坏、验签不过都放行并提示；强制框的文字和按钮、取消键和点暗处关不掉、回标题不重复盖；下载失败（404）→ 再试一次＋手动下载链接、点了打开下载页；重试成功 → 已准备好、补丁已登记（下次启动载入）；再启动直接「已准备好」；只能整包有／没有下载页；还没查完先盖「正在检查」、查完换成更新框或自己关掉；等太久放行、结果晚到再盖上；真 `entry.tscn` 发行模式进标题就盖上；开关关了不查不拦。调试构建、无头默认都不查。
- 选测（`选测.py main --list` 列的 18 个，本机全部通过）：ui_smoke、xiyou_entry_release、xiyou_event_compare、xiyou_event_compare_b、xiyou_event_compare_c、xiyou_event_compare_d、xiyou_flow、xiyou_force_update、xiyou_input_handled、xiyou_key_smoke、xiyou_platform、xiyou_reincarnation_entry、xiyou_save_page、xiyou_tianqi_e2e、xiyou_tianqi_title、xiyou_tianqi_title_flow、xiyou_update_check、xiyou_update_install。改了 `force_update.gd` 一处后又补跑 xiyou_force_update、xiyou_update_check、xiyou_entry_release，通过。
- 发行入口冒烟 `发行入口冒烟.py --keys`（macOS 发行模板，导出到临时目录、跑完删掉）：11/11 通过。发行包无头启动不查更新，所以冒烟只证明加了这段后发行模板照常进标题、按键开新游戏不崩；**发行模板＋有窗口＋真联网的强制路径没跑过**（不许连真实 Gitee，也没有测试用清单源）。
- `测试发布补丁.py` 21 项通过（新 2 项：默认不写不改、沿用原值；latest／0／none、比本次大被拒、不是数字被拒、http 被拒、dev.NNN 写法）；`工具回归.py` 全部通过；`语法检查.py` 通过。
- 没做：Windows、安卓实机（框是同一套 Control，下载、登记、重启沿用已在三平台验过的自动更新代码；安卓打开浏览器靠 `OS.shell_open`，反馈问卷已经用同一个调用在安卓上打开腾讯问卷）。没改线上清单、没推补丁、没出包。

## 上线步骤（Kyo 点名后由总装做）

**鸡生蛋问题**：`min_playable` 只有装了这段逻辑的客户端才认。现在玩家停在 v0.01.09，那一版没有它，调高 `min_playable` 对他们**没有任何作用**——他们照旧只看红点，而看不到红点正是这次要解决的问题。所以第一次只能靠红点或整包把这段逻辑送到玩家手里：

1. 合并后出一个**含强制更新逻辑的补丁**（`发布补丁.py --base <v0.01 底包> --old-tree … --stage`，不给 `--min-playable`），Kyo 回「推」再推。看到红点、手动点更新的玩家装上后就有了这段逻辑。
2. **同时建议出一个新整包**放 QQ 群群文件、群公告请大家换（新下载的玩家从第一天就有这段逻辑），公告里写一句「以后版本太旧会在启动时提示更新」。整包要不要出由 Kyo 定（能补丁就补丁的规矩下，这次是为了把「强制」送到看不到红点的人手里）。
3. 有了下载页的话先设 `--download-url`（不强制也可以先放进清单，不影响任何人）。
4. 等装上第 1 步补丁的人够多后，下一次发版需要强制时：`发布补丁.py … --min-playable latest`（或指定编号）。从这时起，**装过第 1 步补丁、版本低于它的**玩家进标题前必须更新；仍停在 v0.01.09 的玩家照旧只有红点，只能靠群公告或整包。
5. 小修小补不要调 `min_playable`（默认沿用原值，不动就不会多拦人）；想撤掉强制：`--min-playable 0`。

## 变更记录草稿

## 2026-11-14 【cc·force-update·未经审查】发行版强制更新：清单最低可玩版本、启动前查一次、关不掉的更新框（dev.待定）

- 背景：Kyo 11-14：很多玩家看不到检查更新的红点，一直停在旧版本，要「强制更新到最新版本才能进行游戏」。Kyo 同日定：连不上更新服务器时放行；只在清单标记的版本强制（最低可玩版本），小修小补照旧红点；更新失败一直卡在更新框、可以重试，同时给手动下载链接。
- `core/update_check.gd`：清单可带 `min_playable`（最低可玩的开发编号）和 `download_url`（https 手动下载页）。`evaluate` 多给 `forced`：现在运行的号低于 `min_playable`、且清单有更新的版本才算。schema 不变，老客户端读到不出错；老清单没有这项不强制。
- 新 `modes/xiyou/ui/force_update.gd`（`XForceUpdate`）：西游标题 `_ready` 时后台查一次（发行构建、非无头，每次启动都查），出标题时要强制就盖强制更新框；连不上、清单坏、验签不过放行，标题左上角提示「未能检查更新」；还没查完先盖「正在检查更新」，最多等 15 秒放行，结果晚到再盖。
- `modes/xiyou/ui/update_page.gd`：`open_forced` 强制更新框——不透明、取消键和点暗处关不掉、右边是「退出游戏」；能装补丁「更新」，失败「再试一次」＋「手动下载」，底包太旧只给「打开下载页」，没有下载页照旧指 QQ 群；打开下载页同时复制链接。
- `modes/xiyou/entry.gd`：`_ready` 开始查，两种标题建好后调 `XForceUpdate.on_title`。
- `07_开发环境/发布补丁.py`：`--min-playable <号>｜latest｜0`、`--download-url <https>｜none`，默认沿用原值；比本次发布的号大、下载页不是 https 会被拒。README 两处。
- 回退开关 O-待定-1 `XForceUpdate.ENABLED = false`。
- 测试：新专项 `xiyou_force_update` 47 项；`测试发布补丁.py` 新 2 项；选测 18 个、发行入口冒烟 `--keys` 11/11 通过。
- 上线：v0.01.09 及更早的客户端不认 `min_playable`，第一次只能靠红点或整包把这段逻辑送出去，见交付单「上线步骤」。没改线上清单、没推补丁、没出包。
- 玩家可见：装上这一版后，断网打开游戏标题左上角会显示「未能检查更新」；以后版本太旧时，打开游戏会先要求更新才能进入。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/ui/force_update.gd` `XForceUpdate.ENABLED`；`modes/xiyou/entry.gd`、`ui/update_page.gd` `open_forced` | （重制新功能）只有标题「检查更新」的红点，玩家不点就一直停在旧版 | 每次启动查清单，低于 `min_playable` 进标题前强制更新；连不上放行 | Kyo 11-14：很多玩家看不到红点 | `XForceUpdate.ENABLED` 设 false | cc | 保留 |

## 交接板

- 下一步：Kyo 点名后按「上线步骤」出含强制更新逻辑的补丁（不设 `min_playable`）；整包要不要出、下载页地址见下。
- 用户试玩说明：装上这一版后，断网打开游戏，片头放完进标题时左上角有一行「未能检查更新」，照常能玩；联网时和现在一样（清单里还没有 `min_playable`，不会拦人）。强制更新框要等清单设了 `min_playable` 才会出现；设之前可以看专项 `xiyou_force_update`。
- 需要用户决定：
  1. 手动下载页地址：项目里没有现成的下载页，现在没给 `download_url` 时强制框只写「请到 QQ 群…的群文件下载」、没有下载按钮。有网页（如网盘分享页、Gitee 发行页）就用 `发布补丁.py --download-url <https 地址>` 写进清单，不用改客户端。
  2. 第一次怎么把强制逻辑送到 v0.01.09 玩家手里：建议补丁＋新整包＋群公告一起（见上线步骤），整包出不出由 Kyo 定。
  3. 出标题时最多等 15 秒（网络很慢时玩家最多多看 15 秒「正在检查更新」），默认这样；要短可以改 `XForceUpdate.WAIT_SEC`。

## 可优化（流程／工具／效率）

- 建议：发版仓库加一个**测试用清单源**（另一个目录、另一把测试密钥只认调试构建），以后强制更新、撤回这类联网路径能在发行模板＋真窗口上走一遍，不用碰正式清单。预计收益：发版前少一类只能靠专项替身的盲区；归自动更新那条车道。

## 本分支提交

- 023eca6cb 强制更新：清单 min_playable/download_url、启动前门、强制更新框、专项
- 2666af145 发布补丁.py 加 --min-playable／--download-url、工具测试、README
- （本提交）交付单、`_wait` 不再碰已释放的标题节点
