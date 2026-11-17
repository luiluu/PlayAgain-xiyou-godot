# 交付：luiluu/cc-t153-update-config

- 车道／工作者：T153 检查更新先走 Gitee＋gh-proxy、T154 设置导入／导出配置（cc，Opus＋medium，P8）
- 状态：进行中

## 变更记录草稿

## 2026-11-17 【cc·T153·未经审查】检查更新先走 Gitee，能用就不再等 GitHub；加 gh-proxy 镜像（dev.待定）

- `core/update_client.gd` `check()`：原来把所有清单源全读完再挑最高版本，国内玩家要等 GitHub 超时（每个 10 秒）。现在按顺序读，第一份拿到且验签、格式都过的就用，后面的源不再请求；读不到／超时／验签不过／格式坏才退到下一个。
- 清单源顺序（Kyo 11-17、项目经理cc 转 gh-proxy）：Gitee → gh-proxy 代理的 GitHub raw → jsDelivr → GitHub raw。gh-proxy 是第三方代理，只当镜像：清单照旧验 `channel.sig`、补丁照旧比字节数和 SHA-256，被篡改就换下一个；挂了删 `channel_urls` 里那一行即可。
- `core/update_check.gd`：新增 `GH_PROXY`、`order_urls`／`url_rank`；`evaluate` 给出的补丁地址按 Gitee → gh-proxy → jsDelivr → GitHub raw → 其它排（同类照清单先后），不靠清单的顺序。`pick_best` 保留（单份验签仍走它）。撤回、强制更新逻辑没动。
- `07_开发环境/发布补丁.py`：补丁地址在 Gitee 后、jsDelivr 前多写一条 gh-proxy（固定到包提交）；`--verify-online` 也核 gh-proxy 的清单和补丁。`GH_PROXY` 置空就不写。已发出去的旧客户端也能从清单里拿到 gh-proxy 补丁地址（旧客户端照清单顺序试）。
- 专项 `xiyou_update_check`：Gitee 正常（只问 Gitee 两次请求）、Gitee 签名坏（不信它的高版本，退到下一个就停）、Gitee 清单格式坏、Gitee 挂 gh-proxy 通、前两个都挂、补丁地址排序（含子域名、大小写、`gitee.com.evil.io` 不算）、正式源顺序；`测试发布补丁.py` 加 gh-proxy 排第二的断言。
- 玩家可见：检查更新在国内更快（Gitee 通时不再等 GitHub）；Gitee 不通时多一条 gh-proxy 退路。

## 2026-11-17 【cc·T154·未经审查】设置「导入／导出配置」（玩家建议）（dev.待定）

- 新增 `XConfigTransfer`（`modes/xiyou/core/xconfig_transfer.gd`）：导出成一行文本 `ZSCFG1:`＋base64(JSON)，JSON 里带 `format`（配置格式版本，现为 1）、`game`（玩家看到的版本号）、`code`（开发编号）、`settings`。导入时去掉聊天软件插的换行空格；直接粘 JSON 也认。
- 导入校验：格式不对给提示；版本不同（含更高的格式版本）照样导入认得的项，不认识的、类型不对的、本机专属和进度类跳过并计数告诉玩家；嵌套项（消息提醒、画质、字号、装备排序）按子项合并；导入后写盘再重读，范围外的值按读档规矩校正。
- 导入前把当前设置导出成备份 `options_before_import.json`（和 options.json 同目录），「撤回上次导入」一键换回；撤回只动设置项、不动导入后新拿的成就等进度，撤回后删备份。
- 设置页加一行「导入／导出配置」（状态「打开」，排在原版各项之后、画面类各项之前；新界面在「其他」类、确定进入），子页 `XConfigTransferScene` 五行：导出配置（剪贴板）、导出到文件（PC／Mac，存进「下载」文件夹）、从剪贴板导入、从文件导入（PC／Mac，系统选文件框）、撤回上次导入。导入要同一行再按一次确定（先显示「将导入几项、跳过几项、来自哪个版本」），按别的行、上下移动或取消就不导入。安卓不列两行文件，只走剪贴板。
- `XConfig.import_values`：合进当前配置、写盘、重读。回退：`XConfigTransfer.ENABLED = false` 设置页不列这一行。
- 专项 `xiyou_config_transfer`（57 项，测试用 `path_override`＋假剪贴板＋测试下载目录，不碰本机真实设置）；`xiyou_hangup_options` 的行数算上新一行。
- 玩家可见：设置里多了「导入／导出配置」，可以把设置复制给别人或从别人那里导入，导错了能撤回。

### 不导出、不导入的项（本机专属＋进度）

| 类 | 键 | 为什么 |
| --- | --- | --- |
| 本机专属 | `codexQuality` 里的 `window`（窗口大小／全屏）、`fps`（帧率上限）、`integer`（整数缩放）、`low`（省电） | 跟着屏幕和机器走 |
| 本机专属 | `codexScreenSmooth`（画面平滑，含「亲手选过」标记） | 按平台给默认、看屏幕分辨率 |
| 本机专属 | `user://touch_controls.json`（手机按键位置） | 不在设置文件里，本来就不导 |
| 本机专属 | 更新状态 `user://updates/`、存档路径、测试模式解锁文件 | 不在设置文件里，本来就不导 |
| 进度 | `SAchievementS`（成就）、`DesignationN`（称号）、`ChangeClothesLite`（换装解锁）、`codexWeakFiveClearV2`、`codexWhisperSeen`（过场看过）、`codexTianqiBadges`／`codexTianqiAliens`／`codexTianqiQiyinParts`／`codexTianqiGojo`（天启篇图鉴、解锁） | 导入别人的等于白拿 |
| 本次运行 | 只遇稀有等 `SESSION_FLAGS` | 不存配置 |

导出的设置项（30 个键）见 `XConfigTransfer.SETTINGS`；画质只导出 `crisp`（像素柔边）、`motion`（地图平滑移动）。专项会查 `XConfig.DEFAULTS` 每个键都归了类，以后新加设置忘了归类就挂。

### 新增玩家可见文字（请小A 文字审）

- 设置页行名：导入／导出配置；状态：打开
- 新界面说明：把当前设置导出成一段文本发给别人，或导入别人的配置，进入后操作。
- 子页标题：导入／导出配置
- 子页说明：导出的配置带游戏版本号，可以发给别人。窗口、帧率、手机按键位置等本机设置，以及成就、解锁记录不会导出。
- 行名／说明：导出配置／复制到剪贴板，可以直接粘贴发给别人。｜导出到文件／存进「下载」文件夹。｜从剪贴板导入／先复制别人发来的配置文本，再点这里。｜从文件导入／选一个导出的配置文件。｜撤回上次导入／换回导入前的设置。
- 结果提示：已复制到剪贴板（版本 X）。｜已存到：<路径>｜存文件失败，请改用「导出配置」复制到剪贴板。｜将导入 N 项设置（跳过 M 项不认识的），配置来自版本 X，本机是 Y。再按一次确定导入，导入前会自动备份当前设置。｜已导入 N 项设置，跳过 M 项本版本不认识的设置。可在「撤回上次导入」换回。｜已换回导入前的设置。｜撤回失败：没有找到导入前的备份。｜这台设备不能选文件，请用「从剪贴板导入」。
- 错误提示：没有读到配置文本。｜这不是本游戏导出的配置。｜配置文本不完整或已损坏，请重新复制。｜这份配置里没有本版本能用的设置。｜无法备份当前设置，没有导入。｜写入设置失败，没有导入。
- 系统选文件框标题：选择配置文件；过滤：配置文件（*.txt）；导出文件名：再刷一把配置_<日期时间>.txt
- 没用西游元素。

## 验证

- 专项（本机）：`xiyou_update_check` 94/94、`xiyou_update_install`、`xiyou_force_update`、`xiyou_whats_new`、`xiyou_config_transfer` 57/57；设置相关 24 个场景（options_basic／misc、notice／graphics／battle／hangup_options、ui_skin_3a／3b／4a／5c／offshot、costumes、test_mode、font_size、party_formation、screen_fx、platform、feedback_v001、power_hidden 等）全过（hangup_options 首轮因新一行挂，已改测试后通过）。`测试发布补丁.py` 21 项全过；语法检查 0 问题。
- 子页带窗口截图看过（`--audio-driver Dummy`）：说明两行折行正常、确认提示一行、灰显撤回行正常。
- `检查.sh --affected main --cloud`：见下（待填）。
- **补丁线 cc/v00300 试摘**（在 scratchpad 临时检出上 `git cherry-pick --no-commit`）：T153 提交 e5f153a88 干净（5 文件）；T154 提交 5f9f3e031 干净（10 文件，含 hangup 测试一行）；两个一起摘后语法检查 777 个 .gd 0 问题；在那棵树上跑 `xiyou_update_check` 94/94、`xiyou_config_transfer` 57/57 断言全过（那棵树没有转换产物，场景末尾 XDB 读不到数据的报错是环境问题，不是代码）。T154 的新界面那条（e5827732a，`skin_options_page.gd`）**只进 main**：补丁线没有新界面，不要摘。代码对补丁线做了兼容：`SETTINGS` 里补丁线没有的键自动跳过，不用 `XConfig.ui_skin_new()`、`to_map` 用 `"to_map" in self` 判断。

## 我不同意的地方／风险

- **Gitee 返回旧清单会错过新版**（派单点名的担心）：会。Gitee 推送失败或比 GitHub 慢时，国内玩家要等到 Gitee 跟上才看到新版。没做「Gitee 说已是最新时再问一次 GitHub」：那样国内玩家每次检查都要等 GitHub 超时，等于没改。兜底靠发布流程：`发布补丁.py --verify-online` 推完后逐源核清单和补丁（现在也核 gh-proxy），Gitee 没跟上会报 ✗。另外原来的「取最高版本」本来就被 jsDelivr @main 最长 12 小时的缓存拖着，旧做法也不是总能第一时间看到新版。
- **gh-proxy 是第三方**：被篡改能被验签／SHA 挡住，但它能看到请求（只有普通 GET、不带玩家信息）。挂了只是多等一次超时再换下一个。
- **挂机设置、屏蔽掉落不在导出里**：它们存在存档里（`XState.hang_up`、`pingbi_quality`），不是设置文件。玩家截图里「设置选项很多」多半也指这两页，如果要连它们一起导，要动存档、要进游戏后才能导，建议另开一单（要 Kyo 定要不要）。
- 导入文本用 base64 包了一层，聊天里看不懂内容；好处是 QQ／微信不会把引号、花括号改坏。直接粘 JSON 也认。

## 待交叉核查

- T153：`check()` 首个可用源即停的顺序与撤回／强制更新不受影响；`order_urls` 排序；`发布补丁.py` gh-proxy 地址（下次发补丁时 `--verify-online` 实测 gh-proxy 补丁能下、SHA 对）。
- T154：`XConfig.import_values` 合并＋重读；进度类、本机专属确实不进不出；撤回不动进度；安卓剪贴板实机（我没在安卓真机上试）。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- e5f153a88 T153 检查更新 Gitee 优先＋gh-proxy（补丁线可摘）
- 5f9f3e031 T154 导入／导出配置（补丁线可摘）
- e5827732a T154 新界面设置页一行（只 main）
