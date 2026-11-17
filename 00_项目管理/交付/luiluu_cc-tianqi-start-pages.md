# 交付：luiluu/cc-tianqi-start-pages

- 车道／工作者：T102 开局三页红乙（T098 卡1）（cc，Opus＋medium；原会话 WIP 后额度满，换会话续接）
- 状态：可合并

## 变更记录草稿

## 2026-11-17 【cc·T102·未经审查】天启篇开局三页换红乙新界面：存档位一列 10 格＋详情牌、难度五张竖卡讲阵容规则、随机阵容五张角色卡标上场位／助力位；标题与三页共用「界面风格」开关（dev.待定）

- 依据：私密仓 `重制设定/开局界面提案_v0.1/README.md`（v0.2 定稿）第一节、第四节「卡1」；小A 复核 `协作交接/T098_复核_小A.md`；拍板 D153～D156。
- 新文件 `ui/tianqi_start_page.gd`（`XTianqiStartPage`）：三页的画和焦点；流程（下一步、取消退到哪、开局）仍在 `entry.gd` 的 `_tq_slot`／`_tq_difficulty`／`_tq_lineup`，门开时改由它画，门关时照旧 MV 窗口一行不动；`_tq_start` 没动（留给卡 2）。顶栏「新的游戏」＋步骤条（`XSkinTabStrip.set_steps`）、左上「‹」返回、底部按键提示（触屏变胶囊，阵容页触屏不挂）、整页进 `FULLSCREEN_GROUP`、宽屏五张卡整体居中。
- ① 存档位：一列 10 格（编号、1 号位头像、名字、等级、难度徽记＋名或「原版存档」胶囊、月-日 时:分），右边详情牌；光标默认第一个空格（全满停 1 号）。空格按确定直接进难度页；有存档的格按确定焦点跳进牌里停「覆盖它」，左右换「换一格」（节点名 `WindowBack`），牌里取消或「换一格」回列表、焦点留在刚才那格。确认页并进牌里，不再跳页。
- ② 难度：五张竖卡（大徽记、名、说明、「随机阵容」三行：能抽到、超强者最多上阵、弱者至少，证道多一行小注「助力位可再放 1 名超强者」）；选中上浮＋红框；证道不设 `disabled`（`meta locked`），能拿焦点，按确定抖一下、页面下方正中出「「证道」暂未开放」，不进下一步。
- ③ 阵容：上场位四张＋助力位一张（隔开 30），1 号位红标，称号同名不画、长名缩字，档位胶囊（超强者金边），战斗小人待机；底部计数＋规则句；重抽整页重建、新卡依次翻进（动效简化只淡入、关直接换）。
- `XSave.summary_dict(slot)`：只读摘要字典（state empty／ok／failed／invalid、1 号位、等级、地名、存档时间、游戏时间、是否天启篇、难度、阵容），`summary()` 字符串不动。
- 开关：`XTianqiTitle.skin_on()` 最后一行改成 `XTianqi.new_game_enabled() and XConfig.ui_skin_new()`，标题和开局三页共用；设置「界面风格」选原版时标题和三页都回旧框，发行构建跟游戏内新皮肤同一道发行门（`RELEASE_OPEN`）。
- `XSkinLayout.request_wide(node, force := false)`：标题和开局页还没有天启篇存档，`XUiSkin.on()` 恒 false，加强开参数，开局页传 true。
- 测试：`xiyou_tianqi_opening` 新界面分支（徽记、证道 meta locked、证道能拿焦点但停在难度页、一列 10 格、默认第一个空格、动效关不翻牌、设置原版三页回旧框），`xiyou_tianqi_title_flow`（一列用下键、覆盖并进牌、回列表焦点留 2 号）、`xiyou_newgame_back`（同上口径）、`xiyou_ui_skin_3b`（设置原版时标题 `skin_on()` 关）、`virtual_player`（不按 meta locked 的按钮）、`xiyou_tianqi_e2e`（删过时注释）。
- 玩家可见：新开一局的三页换成新界面：选存档位一列看得全、每格都有光标，有存档的格直接在右边牌里确认覆盖；选难度时就能看到这一档能抽到谁；阵容页标明哪 4 个直接参战、第 5 个是助力位。设置里选「原版」界面时标题和这三页也回原样。

## 验证

- 开工对齐（验收 1）：`xiyou_tianqi_title_flow.gd:244` 与 `xiyou_newgame_back.gd:192` 统一成**回列表后焦点停在刚才那格（2 号）**。理由：①玩家是看完 2 号的牌才按「换一格」／取消，焦点留在原处最不打断；②这时列表根本没重建（牌和列表同页），没有理由把光标拽回 1 号；③跟「难度页退回存档位页时停在刚才那格」（`_tq_slot(focus_slot)`）同一口径。旧框（门关）照旧重建页面停第一个，测试按 `skin_on()` 分两支。
- README 第四节「测试」列的场景本机全过：`xiyou_tianqi_opening`（49/49）、`xiyou_tianqi_title_flow`（44/44）、`xiyou_newgame_back`（68/68）、`xiyou_tianqi_e2e`、`xiyou_ui_skin_3b`、`xiyou_virtual_player`。新加的「动效关不翻牌」若翻牌会先把 scale.x 置 0，断言能咬住。
- `xiyou_tianqi_title_flow` 并行跑时偶发：44/44 过、但退出时「ObjectDB instances were leaked / resources still in use」被判失败，重跑过；串行连跑 8 次都过。加 CPU 负载＋`--verbose` 复现到一次，泄漏的全是音效回放（`Save.ogg`、`Load.ogg`、`Decision1.ogg`、`Saint5.ogg` 的 `AudioStreamPlaybackOggVorbis`）：退出时音效还在放，跟开局页无关；flaky 记录里 11-12（本分支之前）就有同场景一次。建议另开小单：测试 quit 前停掉 XiyouSE 播放器（归工具／测试车道）。
- 截图（真窗口，`--audio-driver Dummy`）：`附图/luiluu_cc-tianqi-start-pages/`，`new_*`＝天启篇新界面（修后），`old_*`＝设置「原版」／修前（门关时三页代码路径与 main 相同，所以原版档截图即修前样子）；`new_7_lineup_wide1600.jpg` 是 1600×720 宽屏。截图时看出证道卡规则行换行压到下一行、出卡底，已改成定行距＋小注（`new_6` 为修后）。
- `检查.sh --affected main --cloud`（提交 2ef3c3499，选 243 个场景，本机沿用 5 个、云端 238 个，运行 43996540681）：237 过、1 挂 `xiyou_input_handled`：阵容页 Y 键重抽直接调了 `get_viewport().set_input_as_handled()`，改成 `XKeyMap.handled(self)`（同 T095 那次），本机重跑 `xiyou_input_handled`、`xiyou_tianqi_title_flow`、`xiyou_tianqi_opening` 都过；只改这一行，没再整轮上云。其余非 Godot 检查（文档登记、随机守卫、参照工具守卫、发行空壳覆盖、切场景后调用扫描等）全过。
- `语法检查.py`、`工具回归.py` 通过。

## 我不同意的地方

- 无原则分歧。README 写「三页都加进 FULLSCREEN_GROUP」「`request_wide` 加参数」照做。只提一点：README 估「三页手工排 0.08」偏低，单是三页版面＋触屏＋宽屏就占了本单大半；卡 2 的过场（同样手工排＋三档动效＋时序锁）建议按 ≥ 本单工作量估。

## 交接板

- 下一步：卡 2（进大厅过场「落印」＋时序锁）等本单合进主干后开。
- 用户试玩说明：同「玩家可见」。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：开局三页截图脚本（本单临时写在 scratchpad，没提交）可做成正式工具场景，卡 2 过场截图也能用（归卡 2）。

## 本分支提交

- 359f2f46c WIP: 开局三页红乙（T102）：XTianqiStartPage、summary_dict、skin_on 改门、request_wide 强开、测试
- 2ef3c3499 难度卡规则行定行距＋证道小注；开局测试补四条；修前修后截图
- （本提交）Y 键重抽改用 XKeyMap.handled；交付单
