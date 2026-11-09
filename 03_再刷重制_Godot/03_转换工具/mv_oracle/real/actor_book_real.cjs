'use strict';
// 【cc·白龙·未经审查】人物图鉴立绘逐个量（raven6；无头 Chrome 真跑冻结正式源，本地只读 http 与拦截同 actor_sv_real.cjs）：
// 新局、开 2494，把要量的角色都记进 ActorBookLite（图鉴「见过」），进 Scene_ActorBook，逐个选中，等图载完再等 0.6 秒，
// 记状态窗 _Sprite（Star_ActorsBook 的立绘：战斗图走路第 0 动作 0/1/2/1 循环，167 以后 Codex_MiraRavenMultiFrame 按档缩放、
// 168／173～177 换逐帧图）最终画的图名、图大小、可见帧、缩放、位置、锚点、平滑，和状态窗位置、内边距、内容宽。
// 帧号会随时间走，所以另记 _spriteFrameCount；对表时按可见帧的格号比。
// 用法：XIYOU_APP=…/v0.62.12/app.nw node real/actor_book_real.cjs [角色 id 列表 JSON 文件]（缺省读 generated/slice.json 的 actors）
// 产物只写 mv_oracle/.sandbox/sprite_real/actor_book/result.json；对表用 tests/xiyou_actor_book_compare（设 XIYOU_BOOK_REAL 才比）。
const fs = require('fs'), path = require('path'), http = require('http');
const PW = process.env.XIYOU_PLAYWRIGHT || '/Users/kyo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright';
const {chromium} = require(PW);
const ROOT = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const SLICE = path.resolve(__dirname, '../../../01_Godot工程/modes/xiyou/generated/slice.json');
const ids = process.argv[2] ? JSON.parse(fs.readFileSync(process.argv[2], 'utf8')) : JSON.parse(fs.readFileSync(SLICE, 'utf8')).actors;
const OUT = path.resolve(__dirname, '../.sandbox/sprite_real/actor_book');
fs.mkdirSync(OUT, {recursive: true});
const MIME = {'.js': 'text/javascript', '.json': 'application/json', '.html': 'text/html', '.css': 'text/css', '.png': 'image/png',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.ogg': 'audio/ogg', '.m4a': 'audio/mp4', '.webm': 'video/webm'};
const server = http.createServer((req, res) => {
  const rel = decodeURIComponent(new URL(req.url, 'http://localhost').pathname).slice(1) || 'index.html';
  const p = path.resolve(ROOT, rel);
  if (!p.startsWith(ROOT + '/') || req.method !== 'GET') { res.writeHead(403); return res.end(); }
  try {
    if (!fs.statSync(p).isFile()) throw Error();
    res.writeHead(200, {'Content-Type': MIME[path.extname(p)] || 'application/octet-stream'});
    fs.createReadStream(p).pipe(res);
  } catch { res.writeHead(404); res.end(); }
});
const log = [], result = {};
(async () => {
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  const port = server.address().port;
  const browser = await chromium.launch({headless: true, channel: 'chrome'});
  const page = await (await browser.newContext({viewport: {width: 1280, height: 720}})).newPage();
  page.on('pageerror', e => log.push('pageerror ' + e.message));
  await page.route('**/*', r => {
    const u = new URL(r.request().url());
    if (['/js/mac-preload.js', '/js/mac-integration.js'].includes(u.pathname)) return r.fulfill({status: 200, contentType: 'text/javascript', body: ''});
    return u.hostname === '127.0.0.1' ? r.continue() : r.abort();
  });
  const ev = (fn, arg) => page.evaluate(fn, arg);
  try {
    await page.goto('http://127.0.0.1:' + port + '/index.html');
    await page.waitForFunction(() => window.SceneManager && SceneManager._scene instanceof Scene_Title && SceneManager._sceneStarted && !SceneManager.isSceneChanging(), null, {timeout: 120000});
    await ev(async ids => {
      window.QA = {};
      QA.pause = ms => new Promise(r => setTimeout(r, ms));
      QA.ready = c => SceneManager._scene instanceof c && SceneManager._sceneStarted && !SceneManager.isSceneChanging() && ImageManager.isReady();
      QA.wait = async (f, l, ms) => { const u = Date.now() + (ms || 60000); while (!f()) { if (Date.now() > u) throw new Error('Timeout ' + l); await QA.pause(100); } await QA.pause(300); };
      QA.r = v => +(+v).toFixed(4);
      DataManager.setupNewGame(); $gameSwitches.setValue(2494, true);
      SceneManager.goto(Scene_Map); await QA.wait(() => QA.ready(Scene_Map), 'map');
      $gameParty.ActorBookLite = ids.slice();
      SceneManager.push(Scene_ActorBook); await QA.wait(() => QA.ready(Scene_ActorBook), 'book');
    }, ids);
    for (const id of ids) {
      try {
        result[id] = await ev(async id => {
          const sc = SceneManager._scene, iw = sc._indexWindow, w = sc._statusWindow;
          const idx = iw._list.findIndex(x => x && typeof x.actorId === 'function' && x.actorId() === id);
          if (idx < 0) return {error: '不在目录'};
          iw.select(idx);
          await QA.pause(200);
          await QA.wait(() => !w._Sprite.bitmap || w._Sprite.bitmap.isReady(), 'bmp', 20000);
          await QA.pause(600);
          const m = w._Sprite, b = m.bitmap, f = m._frame;
          if (!b) return {none: true, battler: $gameActors.actor(id).battlerName()};
          return {battler: $gameActors.actor(id).battlerName(), url: String(b.url).replace(/^.*\/img\//, 'img/'), bmp: [b.width, b.height],
            frame: [f.x, f.y, f.width, f.height], scale: [QA.r(m.scale.x), QA.r(m.scale.y)], pos: [QA.r(m.x), QA.r(m.y)], anchor: [m.anchor.x, m.anchor.y],
            smooth: !!b.smooth, visible: m.visible, alpha: QA.r(m.alpha), count: w._spriteFrameCount, multi: w._codexBookMulti || null,
            win: [w.x, w.y, w.width, w.height], padding: w.standardPadding(), contentsWidth: w.contentsWidth()};
        }, id);
      } catch (e) { result[id] = {error: String(e).slice(0, 300)}; }
    }
  } catch (e) {
    result.error = String(e && e.stack || e);
    await page.screenshot({path: path.join(OUT, 'failure.png')}).catch(() => {});
  }
  fs.writeFileSync(path.join(OUT, 'result.json'), JSON.stringify({app: ROOT, actors: ids, result, log: log.slice(0, 40)}, null, 1) + '\n');
  console.log(JSON.stringify({out: OUT, measured: Object.keys(result).length, errors: Object.entries(result).filter(([, v]) => v && v.error).map(([k]) => k).slice(0, 20), log: log.slice(0, 3)}));
  await browser.close(); server.close();
  process.exit(result.error ? 1 : 0);
})();
