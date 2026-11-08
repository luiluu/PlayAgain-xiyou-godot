# 交付：cc/bajie-interp6

- 车道／工作者：A 内容／八戒（cc，接 cc/bajie-interp5 六期）
- 分支起点：cc/bajie-interp5 末端 f11c9180，已合 main。**合并时先合 interp4、interp5 再合本分支**。
- 状态：未完成，周额度 96% 收工交接（11-08 第二棒，接续要点见「验证」第二棒）
- 预设变了：合并时总装要补跑事件状态探针（增量，SHARDS=2，不加 --force）。本分支没改 event_state_probe.cjs。

## 本期（跳标签型，地图 1～80；81 层以后归分段乙，它已出过见面礼两层选单 b 系列）

- **标签补记执行**（`事件写法覆盖.py` 新 `label_reached`，`main` 读覆盖后先补）：119 跳到标签时解释器从标签下一条接着走，118 本身不记执行，于是被跳到的标签永远算「没执行到」。同页有执行到的 119 跳向它的，补记为执行到。只改统计口径：4163→4102（61 个标签）。
- **标签段里没走到的 411 当门**（`gate_of`）：原来顶层 411 没执行到时一路爬到顶，记成「整页没进」；现在标签段里的 411 记成门（open_preset 给「条件不成立」的预设）。只在标签段里生效，别处口径不动（分段车道在用）。
- **i7 变体**：地图 1～80 里在标签段的簇 96 个（330 实例），出 76 个变体；其中 48 个在 m4e71p0（更新日志，对照宿主问题，interp5 那 26 个全退步）先删掉，留 28 个：m30／32／33／45／46／47／64 七层见面礼各 4 个（交物品 182 两层选单＋841 随机分支）。

## 待交叉核查

- 丙档（工具）：`03_转换工具/事件写法覆盖.py`（label_reached、gate_of 里 411 那行）。
- 乙档（内容）：`event_presets.json` i7 变体、`tests/event_compare_baseline.json`、`04_验证/事件写法覆盖.md`。

## 优化登记草稿

优化登记草稿：无

## 变更记录草稿

## 2026-11-08 【cc·八戒·未经审查】地图事件对照：标签补记执行、标签段 411 当门、七层见面礼两层选单（dev.待定）

- 覆盖统计：被 119 跳到的标签算执行到；标签段里没走到的「否则」当门出预设。
- 新变体 i7（地图 1～80 七层见面礼）。
- 玩家可见：无（只加对照与工具门）。

## 交接板

- 下一步：地图 1～80 跳标签型剩下的大头是 m4e71p0「更新日志」（约 211 个实例，多层选单翻页）：interp5、interp6 在这页出的变体对照多数退步，根因已查实（hboot.cjs 的 file:// XHR 不解码中文路径，见「第二棒」），修宿主要整份重量、须约夜里，修好后这一页能一次压下 200 左右。其次 m4e60p1 自定义单抽、角色状态 actors.N.states（要改探针、整份重量，先约夜里）。
- 用户试玩说明：无
- 需要用户决定：无

## 进度账

- 地图事件解释器与脚本翻译：六期只加对照与工具门；完成度由审查核定。

## 可优化（流程／工具／效率）

- 建议（同 interp5）：`补跑事件状态探针.py` 开跑前发现探针文件改过就提示「整份重量约数小时、先约槽」。

## 验证

- 已做：增量探针补跑（i7 28 个，先于合 main）；`git merge main`（main 改了 xiyou_slice.json、troop_event_probe.cjs）后 `--补齐` 已跑完，但它报：参照来自主工作区切片 8b18cbdb、本分支切片 82e7a6ee（main 又前进了、总装当时正合 wukong-floor8），event_states.json 混批。
- **接续要点**（新会话同分支：`git switch --ignore-other-worktrees cc/bajie-interp6` 再 `新建工作树.sh --补齐`）：
  1. 等总装合完，再 `git merge main`、`--补齐`，直到不再报「不同批」。
  2. `XIYOU_STATE_SHARDS=2 python3 07_开发环境/补跑事件状态探针.py`（增量，不加 --force，不改探针）。
  3. 对照：`占槽.py --weight 1 -- godot --headless --path 01_Godot工程 tests/xiyou_event_compare.tscn -- --coverage=<cov.json>`；退步的 i7 删掉，`事件祖先预设.py --prune --cur <cov> --tag i7 --targets t7.json --states generated/oracle/event_states.json`（t7.json 在本交付单末尾「附：i7 目标位置」，拷成文件再用），`事件空绿扫描.py --check`。
  4. 删过变体就再补跑一次探针，然后对照加 `--update-baseline`、`事件写法覆盖.py --coverage <cov> --out 04_验证/事件写法覆盖.md`；写法键用 `事件写法覆盖.analyse` 的全部首词，`--missed` 数字填进上面。
  5. `工具回归.py`、`云端选测.py run`，交付单改「可合并」。


## 第二棒（11-08，周额度 96% 停）

- 已做：`git merge main`（ef489a59，wukong-floor8、rules-gaps4 都已在内）＋`--补齐`，**不再报混批**；补齐末尾自动补跑了事件状态探针（增量，4 段，23414 例，含 i7 28 个）。
- 对照：29373 例，一致 29365，不一致 8（都是基线登记过的），regressions 空。比基线多 28 例＝i7 全部一致，**不用剪枝**。
- `事件空绿扫描.py --check` 通过（空绿 92 例都在基线内；ce1604 已补上，可随 --update-baseline 销）。
- **没做**（额度停）：对照 `--update-baseline`、`事件写法覆盖.py --coverage … --out 04_验证/事件写法覆盖.md`、`工具回归.py`、`云端选测.py run`。下一棒从这里接：重跑一次对照加 `--update-baseline`（占槽 weight 1，约 11 分钟），再出覆盖报告、工具回归、云端选测，改「可合并」。

### m4e71p0（更新日志）退步的根因（已查实）

不是「jsdom 同步读文件不行」：参照宿主 `hboot.cjs` 用 `url: 'file://' + root + '/index.html'` 建 JSDOM，工程路径里有中文（再刷项目资料库、冻结正式源），URL 被百分号转义，**jsdom 的 file:// XHR 不解码就直接拿 pathname 开文件 → ENOENT**。所以 `CodexGuide.releaseInfo()` 为 null、`changelogEntries()` 为空，参照只剩 Map004 里 v0.36 以前的页。实测：同一个 app 经 ASCII 路径的软链读，ContentVersion.json 与 PlayerChangelog/v0.62.json 都是 200。

修法草案（已实测：boot 后装上，releaseInfo＝v0.62.12，changelogEntries 12 版、v0.62 打头）：在 `hboot.cjs` 的 `const w = dom.window;` 后，给 `w.XMLHttpRequest.prototype` 包 open／send——同步 GET 且 file: 协议时用 `url.fileURLToPath` 解码后 `fs.readFileSync` 直接给 status 200／404、readyState 4、responseText（不走 jsdom 的文件读取）。草案代码见下。

**为什么没直接改**：`hboot.cjs` 在 event_state_probe.cjs 的 coreFingerprint 文件清单里，改它＝事件状态探针整份重量（数小时、占满槽），而且所有用 hboot 的探针参照都会变。要总装约夜里（或并进下一次整份重量）、归工具车道改；改完 m4e71p0 本体与 #o 系列应能一致，再出这一页的变体（约 200 实例）。会影响别的探针结果的只有经 XHR 读文件的地方（工程里只有 installNativeGuidanceRuntime 这两处同步读，数据库读已被 hboot 改成 fs）。

```js
// 草案：hboot.cjs，const w = dom.window; 之后
const {fileURLToPath} = require('url');
{ const P = w.XMLHttpRequest.prototype, open = P.open, send = P.send;
  P.open = function (method, url, async) {
    this.__fileSync = null;
    try { const u = new w.URL(url, w.location.href);
      if (u.protocol === 'file:' && async === false && String(method).toUpperCase() === 'GET') this.__fileSync = fileURLToPath(u.href); } catch (e) {}
    return open.apply(this, arguments); };
  P.send = function () {
    if (this.__fileSync === null) return send.apply(this, arguments);
    let t = null; try { t = fs.readFileSync(this.__fileSync, 'utf8'); } catch (e) {}
    Object.defineProperties(this, {status: {value: t === null ? 404 : 200, configurable: true}, readyState: {value: 4, configurable: true},
      responseText: {value: t || '', configurable: true}, response: {value: t || '', configurable: true}}); }; }
```

## 附：i7 目标位置（t7.json）

```json
{
"m30e8p0#i7_4": "m30e8p0:69",
"m32e1p0#i7_5": "m32e1p0:86",
"m33e3p0#i7_6": "m33e3p0:68",
"m45e1p0#i7_7": "m45e1p0:69",
"m46e1p0#i7_8": "m46e1p0:82",
"m47e13p0#i7_9": "m47e13p0:66",
"m64e1p0#i7_11": "m64e1p0:68",
"m30e8p0#i7_15": "m30e8p0:52",
"m30e8p0#i7_16": "m30e8p0:109",
"m32e1p0#i7_17": "m32e1p0:69",
"m32e1p0#i7_18": "m32e1p0:126",
"m33e3p0#i7_19": "m33e3p0:51",
"m33e3p0#i7_20": "m33e3p0:108",
"m45e1p0#i7_21": "m45e1p0:52",
"m45e1p0#i7_22": "m45e1p0:109",
"m46e1p0#i7_23": "m46e1p0:65",
"m46e1p0#i7_24": "m46e1p0:122",
"m47e13p0#i7_25": "m47e13p0:49",
"m47e13p0#i7_26": "m47e13p0:106",
"m64e1p0#i7_39": "m64e1p0:51",
"m64e1p0#i7_40": "m64e1p0:108",
"m30e8p0#i7_56": "m30e8p0:78",
"m32e1p0#i7_57": "m32e1p0:95",
"m33e3p0#i7_58": "m33e3p0:77",
"m45e1p0#i7_59": "m45e1p0:78",
"m46e1p0#i7_60": "m46e1p0:91",
"m47e13p0#i7_61": "m47e13p0:75",
"m64e1p0#i7_70": "m64e1p0:77"
}
```
