# 交付：cc/update-whatsnew

- 车道／工作者：B 界面·自动更新（cc，Orca worker task_47a9a596d030，claude-opus-5-5＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·自动更新·未经审查】更新装好、重启进游戏后弹一次「本次更新内容」；设置页可再看；旧检查记录也存更新说明（dev.待定）

- 背景：Kyo 11-15 定：更新说明原来只在「有新版本」框（`XUpdatePage.texts`）里出现，装完重启就看不到了。要更新装好、重启进游戏后弹一次「本次更新内容」，以后每个补丁都这样。
- 记录 `XWhatsNew`（新，`core/whats_new.gd`）：`user://updates/whatsnew.json` 存 `{code, version, date, notes, seen}`。两处写：
  - 游戏内装补丁登记成功后（`XUpdatePage._install`，页面中途关了也照记）记清单 `latest` 的版本、日期、说明；**补丁号和清单最新号不一样时不记**（说明讲的是最新那一版）。
  - 查清单（`XUpdateClient.check`）结果「已是最新」且最新号＝现在运行的号、记录里还不是这个号时补记（`FROM_CHECK`）。覆盖**整包首次启动**和**旧客户端装的补丁**（0.477 底包装 0.481 时还没有这段代码；装好重启后启动检查会补记，当场弹）。同一个号已有记录不动，已读不会变回未读。
  - 弹的条件：开关开、记录的号＝现在运行的号（`XUpdateClient.current_code`，补丁里的 build_info）、没看过、说明不空。弹出来就记已读（关掉、或开着时退出都不再弹）。号对不上（还没重启、被退回）不弹。
  - 不改补丁格式和清单格式：只读清单本来就有的 `latest.version／code／date／notes`；已推的 0.481 清单直接能用。清单没有 notes 的不记不弹。
- 弹窗 `XWhatsNewPage`（新，`modes/xiyou/ui/whats_new_page.gd`）：标题、「已更新到 版本（日期）」、说明逐条、「知道了」；说明长了框里滚动。确定、取消、点按钮、点框外都关；开着时按键不漏到下面。独立 CanvasLayer 89（比检查更新／强制更新框 90 低一层）。样式两套：天启篇新标题（`XTianqiTitle`）与新界面设置页走新皮肤（XUiSkin 黑面板、思源字、`XSkinButton` 红乙选中条），重制版旧标题与旧设置页走旧样式（同检查更新框）。
- 标题接线（`entry.gd`）：两种标题建好、强制更新门之后调 `_whats_new_hook`：有就弹；检查更新／强制更新框开着时不弹（也不记已读，下回进标题再弹）。查清单的结果回来（强制更新的启动检查、每天一次静默检查）时人还在标题就再试一次（隔两帧，等「正在检查」框关掉；用一次性连接，不用 await）。
- 设置页入口：现在运行的这一版有说明时，设置页列「本次更新内容」（状态「查看」，确定再弹一次；新界面归「其他」类，说明「再看一次这次更新了哪些内容。」）。没有说明或开关关着不列。
- 顺带修（派单）：`update_client.gd` 从旧记录（`check.json`）恢复的结果说明恒为空。旧记录现在也存 `notes`、恢复时带回；更早写的旧记录没有 notes 照旧是空，`XUpdatePage.texts` 本来就只在说明不空时列「更新内容」一节，不会出现空标题。（实际上更新框打开时总会现查一次清单，旧记录只给红点用，没有玩家可见的问题；按派单做成记录里也存，最稳。）
- 回退开关（O-待定，默认开）：`XWhatsNew.ENABLED = false`：不记、不弹、设置页不列入口。`XWhatsNew.FROM_CHECK = false`：只认游戏内装补丁时记下的（不管整包首次启动、旧客户端装的补丁）。
- 顺带修（冷启动发现，main 上已有的发行阻断）：`07_开发环境/发行空壳.py` 把 `XTianqiTable` 的 `var chip: _Chip`（ui-skin-3b 加的方桌提示胶囊）照抄进空壳，内部类 `_Chip` 却整块不进空壳，发行包里 `tianqi_table.gd` 编译失败，连带 `map_scene.gd`、`xsave.gd`、`xconfig.gd` 等 36 个脚本「Failed to compile depended scripts」——**现在 main 出的整包或补丁进不了地图**（底包 477＋本分支补丁冷启动实测，修前 36 条脚本错误）。修法：空壳里类型标注用到内部类的一律换成 `Variant`（变量、函数签名都管；现有 XTianqiTable、XTianqiQiyinShow、XTianqiLineCards 三个带内部类）。`测试发行空壳.py` 加一条用例。
- 玩家可见：游戏内更新、重启进标题后弹一次「本次更新内容」，看过不再弹；设置里多一行「本次更新内容」可以再看。整包首次启动、联网查到这一版就是最新版时也弹一次。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `core/whats_new.gd` `XWhatsNew.ENABLED`、`FROM_CHECK`；`modes/xiyou/ui/whats_new_page.gd`；`entry.gd` `_whats_new_hook`；`options_scene.gd` 「本次更新内容」；`update_page.gd` `_install`；`update_client.gd` `check`／旧记录 | 重制新增（原版 MOD 无游戏内补丁）：更新说明只在「有新版本」框里，装完重启看不到 | 装补丁／查清单时记下这一版说明，重启进标题弹一次「本次更新内容」，设置页可再看；旧检查记录也存说明 | Kyo 11-15 定 | `XWhatsNew.ENABLED = false`（全关）；`XWhatsNew.FROM_CHECK = false`（只关查清单补记） | cc | 保留 |

## 新增文字表（交小A审）

| 位置 | 文字 |
| --- | --- |
| 弹窗标题 | 本次更新内容 |
| 弹窗正文首行 | 已更新到 {版本}（{日期}）／没有日期时：已更新到 {版本} |
| 说明每条 | · {清单 notes 一条}（照清单原文） |
| 弹窗按钮 | 知道了 |
| 说明长时提示 | ↑↓ 滚动查看全部内容（同检查更新框） |
| 设置页一行 | 本次更新内容　状态：查看 |
| 新界面设置页说明 | 再看一次这次更新了哪些内容。 |

文字都集中在 `XWhatsNewPage.texts`、`XOptionsScene.WHATS_NEW_OPTION`／`status_text`、`XSkinOptionsPage.DESC`；小A改了只动这几处，专项 `xiyou_whats_new` 有两条按原文比的断言要一起改。

## 交接板

- 下一步：进哪个补丁由协调问 Kyo（重制版玩家可见）。小A审上面的文字表。
- 用户试玩说明：
  1. 游戏内「检查更新」装一个补丁、重启：进标题弹「本次更新内容」，列出清单里的说明；点「知道了」关掉。再重启不弹。
  2. 设置 → 「本次更新内容」（列表靠后；新界面在「其他」）→ 再看一次。
  3. 旧客户端（0.01.07 等，没有这段代码）装好新补丁、重启后，联网的启动检查查到这一版就是最新时补弹一次。
- 需要用户决定：无。

## 进度账

- 无（自动更新附属功能）

## 可优化（流程／工具／效率）

- 建议：清单 `latest.notes` 现在同时给「有新版本」框和「本次更新内容」用；以后若想给整包首次启动也写说明，可在发版时把说明写进 build_info（本单没改出包工具，不改格式）。归发版工具车道，收益小。

## 待交叉核查

- 甲档（碰更新链路，co 核）：`core/update_client.gd`（check 后补记、旧记录存／取 notes）、`modes/xiyou/ui/update_page.gd`（登记成功后记说明）、新 `core/whats_new.gd`、新 `modes/xiyou/ui/whats_new_page.gd`、`modes/xiyou/entry.gd`（两种标题接线）、`modes/xiyou/ui/options_scene.gd`／`skin/skin_options_page.gd`（入口）。重点：`boot_patch.gd` 没动（补丁载入仍在第一个自动加载 `_init`，不引用任何 class_name）；新脚本只在标题／设置页之后用到；清单与补丁格式没改；强制更新框开着时不弹、不抢键；标题节点被换掉时不留悬空协程。
- 新专项 `tests/xiyou_whats_new.gd`。
- 乙档（工具）：`07_开发环境/发行空壳.py` 内部类类型换 Variant（`de_inner`）、`测试发行空壳.py` 新用例。请核：换成 Variant 后空壳里有没有别处还引用内部类（函数体是空壳规则生成的，不照抄真代码）；出补丁／整包前建议总装用 main 再跑一次底包＋补丁冷启动。

## 验证

- 专项 `xiyou_whats_new` 57/57（无脚本错误）：装补丁记／号不对不记／清单无说明不记／说明非字符串不记；查清单补记、同号不覆盖、旧版不补记、有更新版不补记、FROM_CHECK 关不补记、坏记录；开关关（不记、不弹、设置页不列、真标题不弹）；文字；检查更新框开着不弹不记已读；旧样式弹一次记已读、焦点、确定关、新皮肤样式、取消关、长说明滚动；旧记录 check.json 存／取说明、更早的旧记录无说明不出空标题；真 `client.check` 补记、老格式清单（无 notes）不记；`XUpdatePage._install` 本进程 HTTP 真装一次 → 记下说明、未重启不弹；真西游标题开发模式（新标题、新皮肤）与发行模拟（`ReleaseEntry.simulate_release`）各：弹一次→记已读→确定关、留在标题→再启动不弹→号不对不弹。
- 选测（`选测.py main --list` 给的 51 个全跑，含 xiyou_update_check、update_install、force_update、entry_release、flow、tianqi_title／title_flow、options_basic／misc、ui_skin_5c／3b、input_handled、key_smoke、event_compare a～d、smart_ai 全部段等）：51/51 通过（并行 2，1407 秒）。之后合了 main（mira-dragon-art，没碰本车道文件），没重跑。
- 冷启动（dev477 Windows 底包＋本分支发行空壳工程 `--export-patch` 的补丁 4.2 MB、code 618，macOS 发行模板替身、隔离 HOME，`--headless --quit-after 600`）：a 登记补丁＋未读说明 → `BOOT_PATCH loaded=true reason=已载入 base=477 code=618`、进标题、`WHATS_NEW shown code=618`、无脚本错误、记录变已读；b 同一 HOME 再启动 → 仍载入、进标题、不弹；c 记录号不对 → 不弹；d 不放补丁 → 照常进标题。9/9。修发行空壳之前 a～c 各 36 条脚本错误（见上「顺带修」）。
- 发行空壳 check：62 个脚本 534 个函数都有；`测试发行空壳.py` 12/12；语法检查 937 个 .gd 0 问题；工具回归全过。
- 没验到：真窗口下两种样式的观感（只在无头里断言了样式对象）；真 Windows／安卓机。

## 本分支提交

- d17fd1985 WIP：XWhatsNew／XWhatsNewPage、旧记录存说明、设置页入口、专项
- b08046f10 WIP：弹窗打印一行给冷启动验证；交付单初稿
- 58bbebaed 发行空壳：内部类类型标注换成 Variant＋单测
- 51c1b523a 合并 main


## co 甲档核查

- 核查者：co；对象 cc/update-whatsnew 至 d5abf4b1d（含 58bbebaed）；2026-11-15。
- **58bbebaed：通过，可单独挑入**，已优先回报协调。实跑 `测试发行空壳.py` 12/12；调用 `build_all` 实际生成 62 份空壳，missing=[]。逐个检查所有目标的内部类：XTianqiQiyinShow.Overlay、XTianqiTable._Chip、XTianqiLineCards._Card 在生成物均无残留。全工程搜 `: _`／`-> _` 后，另一个真正的内部类标注为 screen_fx_view._WeatherCanvas，此文件不换空壳，类本体仍在，不受影响。新增单测确实覆盖标量、Array 元素、参数、返回值，但它只检查生成文本，不是引擎编译测试；下述发行冷启动补足当前实际工程编译覆盖。未发现当前代码漏网；不据此承诺未来任意嵌套／限定内部类语法也支持。
- **整体不通过：P1 0，P2 1，P3 0**（只读核查，未修改实现）。

### P2：坏记录缺少字段／字段类型错误没有统一拒绝

位置：`core/whats_new.gd:81,91,97,109`。`_read` 只验证 JSON 顶层是字典，之后直接 `int(code)`、`seen == true`。独立 Godot 实测：写入 `{"code":618,"notes":["hello"]}` 后 `pending(618)` 返回非空（缺少 version/date/seen 仍会弹）；写入 code 为 `[618]` 时 current 第 91 行报 `Invalid call. Nonexistent 'int' constructor`；seen 为字符串时第 97 行报 `Invalid operands 'String' and 'bool'`。这是脚本错误，未观察到进程退出，不能称为整游戏崩溃。同号损坏记录还会被 note_check 的同号早退保留。现有 57 条专项只覆盖截断 JSON，没覆盖合法 JSON 的缺字段／错类型；应由执行轨补统一字段及类型校验并加上述回归，再复核。

### 已实测

- 原专项 `xiyou_whats_new` 57/57，退出 0（此次独立复跑，日志 `04_验证/本地结果/并行测试/20261115_185337_al360pvo/`）。包括两种样式对象、真标题开发／发行模拟、ENABLED/FROM_CHECK、真 HTTP 安装登记、check.json notes 往返；原断言通过不覆盖上述新反例。
- 独立复制车道冷启动脚本到 `/tmp/co_whatsnew_review/` 后重新出补丁并运行，未复用旧冷启动结果：底包 477＋本树发行空壳补丁 619（5.3 MB），macOS 发行模板替身、隔离 HOME。首次载入补丁→进标题→弹出→记已读；再次启动不弹；记录号错不弹；无补丁底包进标题，脚本全部检查通过，无 SCRIPT ERROR／Parse Error。脚本为四次启动、8 个具名 check（车道此前写 9/9，不沿用这个计数）。
- 新反例与冷启动摘要／四次日志：`04_验证/本地结果/co_whatsnew_review/`（本地证据，不入 Git）。

### 只看代码的结论与边界

- boot_patch.gd 未改；project.godot 仅随 main 合并改变开发编号，BootPatch 仍为首个自动加载，其 `_init` 载补丁、不引用 class_name 的做法未动。新增 XWhatsNew 在后续更新客户端／标题／设置页使用。
- 未改 update_check 的清单解析、补丁下载／校验／登记格式；新增只消费原 latest.notes 等字段，check.json 仅加可缺省 notes。因此 0.481 原格式清单可直接消费；未联网重新拉取实际线上 0.481 清单或签名。
- FROM_CHECK 明确允许无补丁、整包首次启动也弹：仅清单结果 LATEST 且 code 等于当前运行号时补记。底包号低于清单最新号不会误记最新说明；若产品要求“只有装过补丁才弹”，当前行为不满足，但本单交付已明确把整包首次启动列作预期，不另报缺陷。
- 两种标题分别传入旧样式／新皮肤标识，设置页按 skin 选择。ENABLED=false 阻断记录、自动弹出和设置入口；check.json 新增 notes 仍会写入，这是旁路缓存修复，玩家流程恢复旧行为。
- 未核到：真实窗口观感及遮挡／手柄体验、真实 Windows／安卓机、线上清单实时请求；没有重跑车道 51 个选测（此次为只读核查，复跑专项＋发行冷启动，相关报告边界如上）。
