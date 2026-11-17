# T160 云裳换皮首段 WIP

配置：gpt-6.1-sol＋medium，职级P6。使用内置 image_gen，共6次出图，上限50次；未使用API/CLI出图。只交四向12帧与wait三帧，未接入，未启动Godot，现行u2和yunshang.gd未改。待Kyo确认形象再补其余51格并讨论接线。

## 模板

三个候选已看，见 candidates.png：云霄长发宽袖长衣最接近，采用；碧霄衣裙偏短、发型不合；琼霄盘发及金饰接近，但服装短且辫发轮廓偏差大。模板从谷雨分支原样复制，云霄行走抽取第0人144×192，战斗576×384的wait为左列块第二行三格。五条悟只作渲染与比例参照。

## 流程与复现

逐方向/动作一行独立换皮，四向各三格，wait独立三格。每次模板＋云裳头像；下向加五条悟质感，侧向/背向/wait加新正面保持配色。prompt_*.txt保留全部原文，raw_*.png保留五条入选输出，rejected_down_01.png保留失败正面。第1次正面、第2左、第3右、第4背、第5wait、第6正面重出。正面首次腿区IoU 0.959失败，重新出图强调露踝和收脚/左右迈步差异后通过，无复制帧、镜像补帧或改阈值。

Python＋Pillow运行postprocess.py：逐格切图，清边缘连通近白底，alpha>=128二值化，最近邻按模板bbox高度缩格，水平中点/脚底对齐，共用32色无抖动调色板；输出Yunshang_Walk.png、Yunshang_Wait.png、alignment.json。review.py生成手机总览与两张对照GIF，底部保留五条悟、指定谷雨分支样板、云裳、模板的原生尺寸，不拉齐显示高度。

T156工具和阈值原样取自luiluu/cc-t156-sprite-check到/tmp/t160_check.py及/tmp/精灵自检阈值.json（不入库）。命令：`python /tmp/t160_check.py --name Yunshang_v3 --walk Yunshang_Walk.png --idle Yunshang_Wait.png --ref-walk template_walk.png --ref-battle template_battle.png --out check`。最终退出0，73项，0失败4警告；报告在check，日志final_check.log。警告是右向三帧头发区孔洞(15,11)/(13,12)/(13,11)和wait#1(41,16)，仍需人工判定发束负空间是否接受。自动通过不代表美术验收。

## 人工待看与限制

白发与白衣在原尺寸仍较密集，头部发束偏细碎；左右簪饰位置有镜像式差异，衣纹也非逐像素一致。待机有轻微头发造型变化，需看动图审手脚稳态。逐帧bbox对齐只能保外框与脚底，不证明人体关节点动作完全保真。指定谷雨分支README实际记录左向失败，与派单“已认可”口径不同，本单仅沿用工艺，未把该样板自检当合格证明。
