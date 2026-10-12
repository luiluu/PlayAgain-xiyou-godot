# PD 下载与原版接收

【Codex·未经Claude检验】｜2026-10-12

**当前采用方式：**用户已在 PD Windows 下载完成，并明确只需调用原版、不做 Mac 移植。已建立[原版只读调用入口](../01_再刷一把/03_原版分析/原版调用说明.md)。下面的复制接收流程保留作以后固定快照时使用，不再要求用户重复复制整套游戏。

建议在已有 PD 虚拟机的 Windows Steam 正常下载原版，再复制一份文件到 Mac 的待接收目录。原版可在 PD 运行作规则对照；Godot 在 Mac 独立开发。

| 方式 | 优点 | 额外工作 | 本轮建议 |
| --- | --- | --- | --- |
| PD 内 Windows Steam 下载 | 使用常规安装流程，可通过 Steam 启动原版作对照 | 下载后复制到 Mac | 首选，用户已有 PD |
| Mac 使用 DepotDownloader 获取 Windows 内容 | 可以直接保存 Windows 游戏内容到 Mac | 安装工具、账户认证、选择目标平台和输出目录；仍需 Windows 环境作运行对照 | 备用方式，本轮未安装或执行 |
| 下载后先把原版做成 Mac 兼容应用 | 可在 Mac 运行原版 | 原版平台适配与独立验证 | 按需旁支，Godot 重制无需先做此项 |

这里的“PD 最省事”为基于用户现有环境的判断。PD 虚拟机的 Steam 登录、下载与实际原版运行本轮未代操作。

## 用户接收操作

1. 在 PD 的 Windows Steam 安装《再刷一把 PlayAgain》（AppID 2059790），保持未安装 MOD。
2. 在 Steam 的游戏属性中找到“已安装文件”，打开游戏文件夹。
3. **复制**整份游戏安装目录到 Mac 的下列目录，不移动 Steam 安装原件：

   `/Users/kyo/Documents/再刷项目资料库/01_再刷一把/01_待接收原版/`

4. 如方便，同时复制该 Steam 库的 `steamapps/appmanifest_2059790.acf` 到同一接收目录，并保留原文件名。找不到时先交付游戏目录，由核对记录标明缺失。
5. 告知复制完成及实际文件夹路径。开发核对负责生成来源登记、数据/插件清单和逐文件校验。

PD 支持 Mac/Windows 之间的文件夹共享。若当前 Windows 能访问 Mac“文稿”，在文件管理器中进入该目录复制；如果没有开启共享，先配置一个专用共享文件夹。无需把整个 Mac 磁盘开放给虚拟机。[Parallels 官方共享说明](https://docs.parallels.cn/pdfm-20-ug-zh_cn/parallels-desktop-for-mac-20-yong-hu-zhi-nan/zai-mac-shang-shi-yong-windows/she-ding-windows-ru-he-yu-macos-xie-tong-gong-zuo/zai-macos-yu-windows-zhi-jian-gong-xiang-xiang-mu/gong-xiang-wen-jian-he-wen-jian-jia)

备用工具提供 macOS 安装说明、账户认证和下载目标操作系统参数；下载得到 Windows 文件不等于它们能在 macOS 原生运行。[DepotDownloader 项目说明](https://github.com/SteamRE/DepotDownloader)

## 开发核对的完成条件

- 记录来源、复制时间、Steam AppID、可取得的 BuildID、分支及文件清单。
- 核对游戏身份、引擎版本、数据、插件、额外文件和 MOD 痕迹；不能仅因 manifest 或文件夹名正确而认定纯净。
- 已有保存文件若随安装目录交付，只作为来源记录，不导入正式游戏或重制工程。
- 用逐文件 SHA-256 固定已核对基准；分析和转换使用工作副本。
- 原版运行对照有实际记录。PD 是虚拟化环境；未来 Godot 的 Windows 发布仍须注明实际验证环境。
- 核对结果写入来源登记、当前状态与变更记录，未确认项继续保留。
