'use strict';
// dev.135 P2 regressions: live variable context, and the single Game_Temp slot
// used by both the real menu handler and maple return handler. Memory only.
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const cases = [];
cases.push(makeCase('preview.variables', {states: [1421, 1422, 1424, 1259, 1726, 1733], input: 100}, () => {
  newGame();
  const a = w.$gameActors.actor(1), e = new w.Game_Enemy(1, 0, 0);
  const action = new w.Game_Action(a); action.setSkill(1);
  const errors = [], rows = [], oldError = w.Yanfly.Util.displayError;
  w.Yanfly.Util.displayError = error => errors.push(String(error));
  try {
    for (const [state, variable] of [[1421, 1181], [1422, 1184], [1424, 206], [1259, 967], [1726, 965], [1733, 966]]) {
      for (const mode of ['zero', 'set', 'unset']) {
        if (mode === 'unset') delete w.$gameVariables._data[variable];
        else w.$gameVariables.setValue(variable, mode === 'set' ? 7 : 0);
        const after = action.customEffectEval(e, state, 'confirmState', a, 100);
        rows.push({state, variable, mode, getter: w.$gameVariables.value(variable),
          kind: Number.isNaN(after) ? 'nan' : Number.isFinite(after) ? 'finite' : 'infinite',
          value: Number.isFinite(after) ? after : null});
      }
    }
    if (errors.length) throw new Error(JSON.stringify(errors));
    return {rows};
  } finally { w.Yanfly.Util.displayError = oldError; }
}));
cases.push(makeCase('reservation.shared_slot', {menu: [1, 431], maple: 10}, () => {
  newGame();
  const rows = [], oldTrigger = w.TouchInput.isTriggered, oldSound = w.AudioManager.playSe;
  const menu = id => w.Scene_Menu.prototype.callCommonEvent.call({
    _commandWindow: {currentExt: () => String(id)}, popScene() { rows.push(['menu_closed', w.$gameTemp._commonEventId]); }});
  try {
    w.TouchInput.isTriggered = () => true;
    w.AudioManager.playSe = () => {};
    menu(1);
    rows.push(['save', w.$gameTemp._commonEventId]);
    w.Scene_Map.prototype.update_level_Sprite.call({_huicheng_Sprite: {containsPoint: () => true}});
    rows.push(['maple', w.$gameTemp._commonEventId]);
    menu(431);
    rows.push(['achievement', w.$gameTemp._commonEventId]);
    const interpreter = new w.Game_Interpreter(), setup = interpreter.setup;
    interpreter.setup = function (...args) {
      rows.push(['before_setup', w.$gameTemp._commonEventId]);
      return setup.apply(this, args);
    };
    const started = interpreter.setupReservedCommonEvent();
    rows.push(['after_setup', w.$gameTemp._commonEventId]);
    const listMatches = interpreter._list === w.$dataCommonEvents[431].list;
    w.$gameTemp.reserveCommonEvent(10);
    rows.push(['while_running', w.$gameTemp._commonEventId]);
    return {rows, started, listMatches, eventId: interpreter.eventId(), running: interpreter.isRunning()};
  } finally { w.TouchInput.isTriggered = oldTrigger; w.AudioManager.playSe = oldSound; }
}));
cases.push(makeCase('reservation.session_reset', {event: 431}, () => {
  newGame();
  w.$gameTemp.reserveCommonEvent(431);
  const saved = host.encode(), other = new w.Game_Temp();
  const before = w.$gameTemp._commonEventId;
  const independent = other._commonEventId;
  host.restore(saved);
  const loaded = w.$gameTemp._commonEventId;
  w.$gameTemp.reserveCommonEvent(10);
  newGame();
  return {before, independent, loaded, newGame: w.$gameTemp._commonEventId};
}));
process.exit(finish(host, 'review135.json', {cases}) ? 0 : 1);
