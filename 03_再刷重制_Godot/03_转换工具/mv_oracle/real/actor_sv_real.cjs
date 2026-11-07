'use strict';
// 【cc·悟空·未经审查】切片角色战斗图逐个量（无头 Chrome 真跑冻结正式源，同 sprite_real.cjs 的本地只读 http 与拦截）：
// 每 4 名一场战斗（敌群 1、等级 60、挑战开关 2494 开），开战后等图载完再等 1.5 秒，记每名角色 Sprite_Actor 主精灵最终画的
// 图名、图大小、可见帧、缩放、偏移、锚点、平滑、武器／影子、另挂的可见图层，和精灵本身位置。
// 用法：XIYOU_APP=…/v0.62.12/app.nw node real/actor_sv_real.cjs <角色 id 列表 JSON 文件>（缺省读 generated/slice.json 的 actors）
// 产物只写 mv_oracle/.sandbox/sprite_real/actor_sv/result.json；对表用 07_开发环境/形象逐张比.gd。
const fs = require('fs'), path = require('path'), http = require('http');
const PW = process.env.XIYOU_PLAYWRIGHT || '/Users/kyo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright';
const {chromium} = require(PW);
const ROOT = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const SLICE = path.resolve(__dirname, '../../../01_Godot工程/modes/xiyou/generated/slice.json');
const ids = process.argv[2] ? JSON.parse(fs.readFileSync(process.argv[2], 'utf8')) : JSON.parse(fs.readFileSync(SLICE, 'utf8')).actors;
const OUT = path.resolve(__dirname, '../.sandbox/sprite_real/actor_sv');
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
    const init = async () => {
    await page.goto('http://127.0.0.1:' + port + '/index.html');
    await page.waitForFunction(() => window.SceneManager && SceneManager._scene instanceof Scene_Title && SceneManager._sceneStarted && !SceneManager.isSceneChanging(), null, {timeout: 120000});
    await ev(() => {
      window.QA = {};
      QA.pause = ms => new Promise(r => setTimeout(r, ms));
      QA.ready = c => SceneManager._scene instanceof c && SceneManager._sceneStarted && !SceneManager.isSceneChanging() && ImageManager.isReady();
      QA.wait = async (f, l, ms) => { const u = Date.now() + (ms || 60000); while (!f()) { if (Date.now() > u) throw new Error('Timeout ' + l); await QA.pause(100); } await QA.pause(300); };
      QA.r = v => +(+v).toFixed(4);
      QA.snap = s => {
        const m = s._mainSprite, b = m.bitmap, f = m._frame;
        return {name: s._actor.battlerName(), url: b ? String(b.url).replace(/^.*\/img\//, 'img/') : null, bmp: b ? [b.width, b.height] : null,
          frame: [f.x, f.y, f.width, f.height], scale: [QA.r(m.scale.x), QA.r(m.scale.y)], pos: [QA.r(m.x), QA.r(m.y)], anchor: [m.anchor.x, m.anchor.y],
          alpha: QA.r(m.alpha), visible: m.visible, weapon: !!(s._weaponSprite && s._weaponSprite.visible), shadow: !!(s._shadowSprite && s._shadowSprite.visible),
          spr: [QA.r(s.x), QA.r(s.y)], sprScale: [QA.r(s.scale.x), QA.r(s.scale.y)], smooth: b ? !!b.smooth : null,
          motion: Object.keys(Sprite_Actor.MOTIONS).find(k => Sprite_Actor.MOTIONS[k] === s._motion),
          others: s.children.filter(c => c !== m && c.visible && c.bitmap && c.bitmap.width > 0).map(c => String(c.bitmap.url || '').replace(/^.*\/img\//, 'img/'))};
      };
    });
    await ev(async () => { DataManager.setupNewGame(); $gameSwitches.setValue(2494, true); $dataActors.forEach(x => { if (x) x.maxLevel = 99; }); });
    };
    await init();
    const measure = batch => ev(async party => {
        SceneManager.goto(Scene_Map); await QA.wait(() => QA.ready(Scene_Map), 'map');
        party.forEach(id => { const a = $gameActors.actor(id); a.changeLevel(60, false); a.recoverAll(); });
        $gameParty._actors = party.slice();
        if ($gameParty.initializeBattleMembers) $gameParty.initializeBattleMembers();
        $gamePlayer.refresh();
        BattleManager.update = function () {};  // 停住回合推进，只看画面
        BattleManager.setup(1, false, true);
        SceneManager.push(Scene_Battle);
        await QA.wait(() => QA.ready(Scene_Battle) && SceneManager._scene._spriteset._actorSprites.filter(s => s._actor).every(s => s._mainSprite.bitmap && s._mainSprite.bitmap.isReady()), 'battle', 45000);
        $gameMessage.clear();
        await QA.pause(1500);
        await QA.wait(() => ImageManager.isReady(), 'img', 30000);
        const got = {};
        for (const s of SceneManager._scene._spriteset._actorSprites) if (s._actor) got[s._actor.actorId()] = QA.snap(s);
        for (const id of party) if (!got[id]) got[id] = {error: '不在出战栏'};
        return got;
      }, batch);
    // 一批失败（某张图载不出、场景卡住）就重开页面，再把这批逐个重量，找出是哪一名
    const run = async batch => {
      try { return await measure(batch); }
      catch (e) {
        log.push('batch ' + batch.join(',') + ': ' + String(e).slice(0, 200));
        await init();
        if (batch.length === 1) return {[batch[0]]: {error: String(e).slice(0, 300)}};
        const out = {};
        for (const id of batch) Object.assign(out, await run([id]));
        return out;
      }
    };
    for (let i = 0; i < ids.length; i += 4) Object.assign(result, await run(ids.slice(i, i + 4)));
  } catch (e) {
    result.error = String(e && e.stack || e);
    await page.screenshot({path: path.join(OUT, 'failure.png')}).catch(() => {});
  }
  fs.writeFileSync(path.join(OUT, 'result.json'), JSON.stringify({app: ROOT, actors: ids, result, log: log.slice(0, 40)}, null, 1) + '\n');
  console.log(JSON.stringify({out: OUT, measured: Object.keys(result).length, errors: Object.entries(result).filter(([, v]) => v && v.error).map(([k]) => k).slice(0, 20), log: log.slice(0, 3)}));
  await browser.close(); server.close();
  process.exit(result.error ? 1 : 0);
})();
