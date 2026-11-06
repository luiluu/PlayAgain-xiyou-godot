# 交付：cc/platform-mac2

- 车道／工作者：平台（cc，项目线程「完成再刷西游Godot引擎重制」；DQ 单）
- 状态：可合并
- 基于：`cc/platform-android5` 头 fd4c2b06（切分支时 DK、DP 都还没进 main；main 那时是 f08efa7c）。**排在 cc/platform-crash1、cc/platform-android5 之后合**（本单用到 DK 加的 `--keys`）。

## 变更记录草稿

## 2026-11-06 【cc·平台·未经审查】Mac 发行包 Intel 切片冒烟、发行包验收清单、签名公证准备清单（dev.待定）

- ① Intel：「macOS 发行」导出的包本来就是 universal（`lipo -info`：x86_64 arm64，预设没设架构，Godot 默认出通用包），不用改预设。`发行入口冒烟.py` 加 `--arch x86_64|arm64`：用 `arch -<架构>` 启动包里的可执行文件（x86_64 走 Rosetta）。`--arch x86_64 --keys` 10/10：x86_64 切片能进西游标题，空格／J／回车开新游戏和一串确认、取消键都不崩，没有新崩溃报告。Rosetta 不能代替 Intel 真机（帧率、声音不作数），清单里留了 Intel 真机那一步。
- ② 新文件 [Mac 发行包验收清单](../Mac发行包验收清单.md)：给 Kyo 照着点的 25 步，覆盖备份存档、版本号、11-06 闪退复测（空格／J／回车）、对话与选项、地图走路、菜单、存档与一键存档、存档位置（`~/Library/Application Support/KYO/再刷重制/`）、回到标题、读档、战斗、逃跑／全灭、商店、两个存档位、全屏三次来回、全屏切走再回来、窗口缩放、四路音量与记住设置、BGM 96k 听感、退出、查崩溃报告、Intel 真机、恢复存档；每步写了期望结果。原来那份 [Mac 实机验收清单](../Mac实机验收清单.md)（调试验收包、输入法、听音）不动，两份互相链着。
- ③ 签名公证只写了准备清单（下面一节），没有执行，没碰证书、钥匙串和密码。

## 签名公证准备清单（不执行）

现状：「macOS 发行」预设是 `codesign/codesign=1`、`codesign/identity="-"`（临时签名）、`notarization/notarization=0`（不公证）。所以别人的 Mac 下载后打开会被 Gatekeeper 拦，要右键「打开」或去「隐私与安全性」里放行。

### 需要 Kyo 准备的（在 Apple 开发者账号里）

1. Apple Developer Program 会员（个人或公司，每年 99 美元）；记下 **Team ID**（10 位，开发者网站「Membership」页）。
2. 一张 **Developer ID Application** 证书：在 Xcode → Settings → Accounts → Manage Certificates 里点「+」建，或在开发者网站上建好再导入钥匙串。装好后 `security find-identity -v -p codesigning` 能看到 `Developer ID Application: 名字 (TEAMID)`。
3. 公证用的凭据，两种选一种：
   - App Store Connect **API 密钥**（推荐）：Users and Access → Integrations → 生成 Key，拿到 Key ID、Issuer ID 和 `.p8` 文件（只能下载一次）；或
   - Apple ID ＋ **App 专用密码**（appleid.apple.com 生成）。
4. Kyo 自己在终端存一次凭据（密码只进钥匙串，不经过我、不进仓库）：`xcrun notarytool store-credentials 天启篇公证 --key <p8 路径> --key-id <Key ID> --issuer <Issuer ID>`（或 `--apple-id … --team-id … --password …`）。
5. 定一个正式的 **Bundle ID**：现在是 `local.kyo.remake`，能签能公证，但通常用反向域名，比如 `com.<你的名字>.tianqi`。改了以后系统会当成另一个应用，存档目录不受影响（存档目录按 `KYO/再刷重制` 走，不看 Bundle ID）。这条要 Kyo 定。

### 预设要改的（「macOS 发行」，按 Godot 4.7 编辑器导出窗口里显示的名字核对）

- `codesign/codesign`：从「内置（临时签名）」改成用 Xcode 的 codesign（或保持内置但指定证书）。
- `codesign/identity`：`"-"` 改成 `Developer ID Application: 名字 (TEAMID)`，或证书的 SHA-1。
- 加固运行时（Hardened Runtime）：公证必须开。Godot 4 的 macOS 导出在正式签名时默认开；entitlements 里先只保留默认值，有问题再按报错开（比如 JIT、动态库校验）。
- `notarization/notarization`：可以留 0，用下面的命令手动公证（推荐，凭据不进预设）；要让 Godot 导出时顺便公证，再改成 notarytool 并填 Team ID 和凭据。
- **注意仓库是公开的**：`export_presets.cfg` 进 Git。证书名和 Team ID 写进去问题不大，密码、API 密钥、`.p8` 路径都**不能**写进这个文件（Godot 会把敏感项放到不进 Git 的 `.godot/export_credentials.cfg`，填之前先确认）。最稳的做法是预设只填签名身份，公证一律走命令行。

### 命令顺序（Kyo 自己跑，或者到时候授权我跑签名以外的步骤）

1. 导出：`03_再刷重制_Godot/07_开发环境/godot --headless --path 03_再刷重制_Godot/01_Godot工程 --export-release "macOS 发行" <输出>.zip`（签名身份改好后，导出时就用正式证书签了）。
2. 解开并检查签名：`ditto -x -k <输出>.zip <目录>`；`codesign --verify --deep --strict --verbose=2 "<目录>/再刷一把：天启篇.app"`；`codesign -dvv` 看 Authority 是 Developer ID、有 `flags=0x10000(runtime)`。
3. 冒烟：`python3 03_再刷重制_Godot/07_开发环境/发行入口冒烟.py --keys-only --app "<目录>/再刷一把：天启篇.app"`（签名不能改坏包）。
4. 重新打包上传：`ditto -c -k --keepParent "<目录>/再刷一把：天启篇.app" 上传.zip`；`xcrun notarytool submit 上传.zip --keychain-profile 天启篇公证 --wait`。失败时 `xcrun notarytool log <提交 ID> --keychain-profile 天启篇公证` 看原因。
5. 钉票：`xcrun stapler staple "<目录>/再刷一把：天启篇.app"`，再 `xcrun stapler validate`。
6. 系统检查：`spctl -a -vv -t exec "<目录>/再刷一把：天启篇.app"`，期望 `accepted`、`source=Notarized Developer ID`。
7. 最后再打一次给玩家的 zip（或 dmg），在另一台 Mac 或新用户下载双击，确认不再被拦。

包有 500 MB 上下（size1 之后约 350 MB），公证上传和排队一般几分钟到十几分钟。

## 交接板

- 下一步：Kyo 照 [Mac 发行包验收清单](../Mac发行包验收清单.md) 点一遍；签名公证等 Kyo 准备好账号和凭据再做。
- 用户试玩说明：无（没改游戏）。
- 需要用户决定：①签名公证做不做、什么时候做；②正式 Bundle ID 用什么（现在是 `local.kyo.remake`）。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：`发行入口冒烟.py --arch`（不要了删掉那个参数即可）。
- 建议：导出正式包的流程里同时跑 `--keys` 和 `--arch x86_64 --keys`（各约 1 分钟），归总装／导出流程。

## 验证

- `发行入口冒烟.py --arch x86_64 --keys --keep`：10/10（导出包 `lipo -info` 为 x86_64 arm64）。
- `工具回归.py` 全部通过；只改了 Python 工具和文档，没有 Godot 改动。

## 待交叉核查

- `07_开发环境/发行入口冒烟.py`（`--arch`、`RUN_PREFIX`）、`00_项目管理/Mac发行包验收清单.md`。

## 本分支提交

- 见 `git log cc/platform-android5..cc/platform-mac2`
