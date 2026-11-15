# 新界面皮肤素材（ui-skin-p0）

天启篇新界面（界面风格提案 v0.7「红乙」，代码在 `modes/xiyou/ui/skin/`，入口 `XUiSkin`）用到的素材。只在天启篇开，发行包排除（`07_开发环境/发行内容审计.py` 的 DENY 与三个发行预设）；对玩家开放时一起删掉那两处。

| 文件 | 是什么 | 来源 |
| --- | --- | --- |
| `circle_generic.svg` | 通用法阵（七芒星、同心环、七节点、刻度，中性金灰） | 私密设计仓 `重制设定/界面风格提案_v0.7/assets/`，cc 画的初稿 |
| `fonts/TianqiUiSans-Medium.otf` | 正文字体 | 思源黑体 CN Medium（Adobe，SIL OFL 1.1），裁字＋改名 |
| `fonts/TianqiUiSerif-Heavy.otf` | 标题字体（页名、牌上的名字） | 思源宋体 CN Heavy（Adobe，SIL OFL 1.1），裁字＋改名 |
| `fonts/TianqiUiNum-Medium.ttf` | 窄体数字字 | Barlow Condensed Medium（The Barlow Project Authors，SIL OFL 1.1），裁字＋改名 |
| `group_icons/{key}_{normal\|selected}_{64\|32}.png` | 主菜单组入口图标 u4（7 物件×常态／选中×64／32，共 28 张；alpha 只有 0/255，按原生大小最近邻画） | co 画，Kyo 2026-11-15 定稿；源在 gpt-tianqi-teaser 工作树 `local_art/UI_Icons/u4/`（审图件、源图、脚本不进工程） |
| `fonts/charset_*.txt` | 三款字各收了哪些字 | `裁字.py` 写出 |
| `fonts/OFL_*.txt` | 授权文本（OFL 要求随字体附上） | 原字体仓库 |

## 为什么改名

思源两款的授权保留了字名「Source」，裁过字的算改版，改版不能再用保留字名，所以内部名和文件名都换成 `Tianqi UI …`。

## 重新裁字（游戏里加了新字时）

缺的字游戏里会自动落回原字体，不会变方块；想补齐时：

1. 下载原字体（不入库，太大）：
   - `https://github.com/adobe-fonts/source-han-sans/raw/release/SubsetOTF/CN/SourceHanSansCN-Medium.otf`
   - `https://github.com/adobe-fonts/source-han-serif/raw/release/SubsetOTF/CN/SourceHanSerifCN-Heavy.otf`
   - `https://github.com/google/fonts/raw/main/ofl/barlowcondensed/BarlowCondensed-Medium.ttf`
2. 装 fontTools：`python3 -m venv <目录> && <目录>/bin/pip install fonttools`
3. 在补齐过的工作树里跑：`<目录>/bin/python 03_再刷重制_Godot/07_开发环境/裁字.py --hei <黑体> --song <宋体> --num <Barlow>`
4. 跑一次 `godot --import`，提交字体和 `charset_*.txt`。
