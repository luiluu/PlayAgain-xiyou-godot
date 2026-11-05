'use strict';
// 【cc·ravenfx2·未经审查】战斗精灵画面量具：无头 Chrome（本机 Playwright）真跑冻结正式源，进一场战斗，按步骤改状态，
// 记指定角色 Sprite_Actor 最终画出来的样子（主精灵图名、图大小、可见帧、缩放、偏移、锚点、透明度、武器／影子显示、动作），可选截图。
// jsdom 量不了的「插件之间谁盖谁」（Mx_SuperSV 多帧、运行时静态大图）用它量。白龙 2026-11-05 量米拉黑龙手写过一次，这里整理成通用工具。
// 用法：node real/sprite_real.cjs real/<规格.json>（规格放在 real/ 下；量具在 real/ 里，不进探针缓存公共键）
//   规格 {name, party:[角色…], level?:60, troop?:1, actor:要量的角色, prep?:"开战前在页面里跑的 JS（角色已建好）",
//         steps:[{tag, js?:"页面里跑的 JS（可 await；变量 a＝该角色、s＝其精灵）", wait?:毫秒, shot?:true}]}
// 产物只写 mv_oracle/.sandbox/sprite_real/<name>/（result.json、<tag>.png）。本地 http 只读地提供冻结正式源，别的主机一律拦掉；
// 浏览器上下文不落盘，游戏的存档／配置写进页面内存的 localStorage，随浏览器关掉。
const fs = require('fs'), path = require('path'), http = require('http');
const PW = process.env.XIYOU_PLAYWRIGHT || '/Users/kyo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright';
const {chromium} = require(PW);
const ROOT = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const spec = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (!/^[\w.-]+$/.test(spec.name || '')) throw new Error('规格 name 只能是字母数字');
const OUT = path.resolve(__dirname, '../.sandbox/sprite_real', spec.name);
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
    await ev(() => {
      window.QA = {};
      QA.pause = ms => new Promise(r => setTimeout(r, ms));
      QA.ready = c => SceneManager._scene instanceof c && SceneManager._sceneStarted && !SceneManager.isSceneChanging() && ImageManager.isReady();
      QA.wait = async (f, l, ms) => { const u = Date.now() + (ms || 60000); while (!f()) { if (Date.now() > u) throw new Error('Timeout ' + l); await QA.pause(100); } await QA.pause(300); };
      QA.r = v => +(+v).toFixed(4);
      QA.snap = s => {
        const m = s._mainSprite, b = m.bitmap, f = m._frame;
        return {url: b ? String(b.url).replace(/^.*\/img\//, 'img/') : null, bmp: b ? [b.width, b.height] : null, frame: [f.x, f.y, f.width, f.height],
          scale: [QA.r(m.scale.x), QA.r(m.scale.y)], pos: [QA.r(m.x), QA.r(m.y)], anchor: [m.anchor.x, m.anchor.y], alpha: QA.r(m.alpha), visible: m.visible,
          weapon: !!(s._weaponSprite && s._weaponSprite.visible), shadow: !!(s._shadowSprite && s._shadowSprite.visible), spr: [QA.r(s.x), QA.r(s.y)],
          motion: Object.keys(Sprite_Actor.MOTIONS).find(k => Sprite_Actor.MOTIONS[k] === s._motion), smooth: b ? !!b.smooth : null,
          // 精灵下其余带图且可见的子节点（多帧插件若另挂一层，这里会出现）
          others: s.children.filter(c => c !== m && c.visible && c.bitmap && c.bitmap.width > 0).map(c => String(c.bitmap.url || '').replace(/^.*\/img\//, 'img/'))};
      };
    });
    await ev(async () => { DataManager.setupNewGame(); $gameSwitches.setValue(2494, true); SceneManager.goto(Scene_Map); await QA.wait(() => QA.ready(Scene_Map), 'map'); });
    await ev(async sp => {
      $dataActors.forEach(x => { if (x) x.maxLevel = 99; });
      sp.party.forEach(id => { const a = $gameActors.actor(id); a.changeLevel(sp.level || 60, false); a.recoverAll(); });
      if (sp.prep) await (0, eval)('(async () => {' + sp.prep + '})')();
      $gameParty._actors = sp.party.slice();
      if ($gameParty.initializeBattleMembers) $gameParty.initializeBattleMembers();
      $gamePlayer.refresh();
      BattleManager.update = function () {};  // 停住回合推进，只看画面
      BattleManager.setup(sp.troop || 1, false, true);
      SceneManager.push(Scene_Battle);
      await QA.wait(() => QA.ready(Scene_Battle) && SceneManager._scene._spriteset._actorSprites.filter(s => s._actor).every(s => s._mainSprite.bitmap && s._mainSprite.bitmap.isReady()), 'battle', 90000);
      $gameMessage.clear();
    }, spec);
    for (const st of spec.steps || []) {
      result[st.tag] = await ev(async ([id, js, wait]) => {
        const s = SceneManager._scene._spriteset._actorSprites.filter(x => x._actor && x._actor.actorId() === id)[0], a = $gameActors.actor(id);
        if (!s) return {error: '出战栏里没有角色 ' + id};
        if (js) await (0, eval)('(async (a, s) => {' + js + '})')(a, s);
        await QA.pause(wait || 800);
        await QA.wait(() => ImageManager.isReady(), 'img', 30000);
        return QA.snap(s);
      }, [spec.actor, st.js || '', st.wait || 800]);
      if (st.shot) await page.locator('canvas').first().screenshot({path: path.join(OUT, st.tag + '.png')});
    }
  } catch (e) {
    result.error = String(e && e.stack || e);
    await page.screenshot({path: path.join(OUT, 'failure.png')}).catch(() => {});
  }
  fs.writeFileSync(path.join(OUT, 'result.json'), JSON.stringify({spec, result, log: log.slice(0, 20)}, null, 1) + '\n');
  console.log(JSON.stringify({out: OUT, tags: Object.keys(result), error: result.error ? result.error.slice(0, 300) : null, log: log.slice(0, 3)}));
  await browser.close(); server.close();
  process.exit(result.error ? 1 : 0);
})();
