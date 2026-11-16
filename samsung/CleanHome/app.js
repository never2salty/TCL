// CleanHome: a plain start screen for a Samsung TV (Tizen web app).
// Lists the installed apps, favourites first, and opens them with the remote.
// Written in ES5 on purpose: a 2018 TV (Tizen 4.0) runs an old Chromium.
(function () {
  'use strict';

  var KEY = { LEFT: 37, UP: 38, RIGHT: 39, DOWN: 40, ENTER: 13, BACK: 10009 };
  var SELF = 'CleanHm001.CleanHome';

  var list = document.getElementById('list');
  var tiles = [];      // every focusable tile, in reading order
  var focused = 0;
  var allApps = [];    // what the TV reported, for the Diagnose view
  var diagOpen = false;

  // ---------------------------------------------------------------- clock

  var DAYS = ['Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag'];
  var MONTHS = ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August',
    'September', 'Oktober', 'November', 'Dezember'];

  function two(n) { return n < 10 ? '0' + n : '' + n; }

  function tick() {
    var d = new Date();
    document.getElementById('clock').textContent = two(d.getHours()) + ':' + two(d.getMinutes());
    document.getElementById('date').textContent =
      DAYS[d.getDay()] + ', ' + d.getDate() + '. ' + MONTHS[d.getMonth()];
  }

  // ---------------------------------------------------------------- apps

  function lower(s) { return (s || '').toString().toLowerCase(); }

  function has(text, parts) {
    for (var i = 0; i < parts.length; i++) {
      if (text.indexOf(lower(parts[i])) >= 0) return true;
    }
    return false;
  }

  function isHidden(app) {
    return has(lower(app.name), HIDDEN) || has(lower(app.id), HIDDEN);
  }

  function matchesPin(app, pin) {
    var name = lower(app.name), id = lower(app.id);
    if (pin.not && has(name, pin.not)) return false;
    for (var i = 0; i < pin.match.length; i++) {
      var m = lower(pin.match[i]);
      if (pin.exact ? (name === m || id === m) : (name.indexOf(m) >= 0 || id === m)) return true;
    }
    return false;
  }

  /** Splits the installed apps into the pinned ones, in PINNED order, and the rest by name. */
  function arrange(apps) {
    var pinned = [], rest = [], used = {};
    for (var p = 0; p < PINNED.length; p++) {
      for (var i = 0; i < apps.length; i++) {
        if (used[apps[i].id] || !matchesPin(apps[i], PINNED[p])) continue;
        used[apps[i].id] = true;
        pinned.push({ id: apps[i].id, name: PINNED[p].label, icon: apps[i].iconPath, color: PINNED[p].color });
        break;
      }
    }
    for (var j = 0; j < apps.length; j++) {
      if (!used[apps[j].id]) rest.push({ id: apps[j].id, name: apps[j].name, icon: apps[j].iconPath });
    }
    rest.sort(function (a, b) { return lower(a.name) < lower(b.name) ? -1 : 1; });
    return { pinned: pinned, rest: rest };
  }

  function load() {
    if (typeof tizen === 'undefined' || !tizen.application) {
      render({ pinned: fallback(), rest: [] });
      return;
    }
    try {
      tizen.application.getAppsInfo(function (infos) {
        allApps = infos;
        var shown = [];
        for (var i = 0; i < infos.length; i++) {
          var a = infos[i];
          // show === false marks services and helpers that have no screen of their own.
          if (a.id === SELF || a.show === false || !a.name || isHidden(a)) continue;
          shown.push(a);
        }
        var parts = arrange(shown);
        if (!parts.pinned.length && !parts.rest.length) parts.pinned = fallback();
        render(parts);
      }, function () {
        render({ pinned: fallback(), rest: [] });
      });
    } catch (e) {
      render({ pinned: fallback(), rest: [] });
    }
  }

  function fallback() {
    var out = [];
    for (var i = 0; i < FALLBACK.length; i++) {
      out.push({ ids: FALLBACK[i].ids, name: FALLBACK[i].label, color: FALLBACK[i].color });
    }
    return out;
  }

  // ---------------------------------------------------------------- drawing

  // A steady colour per app name, for tiles without a usable icon.
  function colorFor(name) {
    var h = 0;
    for (var i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) % 360;
    return 'hsl(' + h + ', 38%, 26%)';
  }

  function tile(app) {
    var el = document.createElement('div');
    el.className = 'tile text';
    el.style.background = app.color || colorFor(app.name || '');
    var name = document.createElement('div');
    name.className = 'name';
    name.textContent = app.name;
    el.appendChild(name);
    if (app.icon) {
      var img = document.createElement('img');
      // The icon belongs to another app; if the TV refuses the file, the name stays.
      img.onload = function () {
        el.className = el.className.replace(' text', '');
        el.insertBefore(img, name);
      };
      img.src = app.icon.indexOf('/') === 0 ? 'file://' + app.icon : app.icon;
    }
    el.app = app;
    tiles.push(el);
    return el;
  }

  function section(title, apps) {
    if (!apps.length) return;
    var head = document.createElement('div');
    head.className = 'section';
    head.textContent = title;
    list.appendChild(head);
    var row = document.createElement('div');
    row.className = 'row';
    for (var i = 0; i < apps.length; i++) row.appendChild(tile(apps[i]));
    list.appendChild(row);
  }

  function render(parts) {
    var keep = tiles[focused] && tiles[focused].app ? tiles[focused].app.id : null;
    list.innerHTML = '';
    tiles = [];
    section('Favoriten', parts.pinned);
    section('Alle Apps', parts.rest);
    section('CleanHome', [{ name: 'Diagnose', action: 'diag', color: '#2a2d34' }]);
    focused = 0;
    for (var i = 0; i < tiles.length; i++) {
      if (keep && tiles[i].app.id === keep) focused = i;
    }
    focus(focused);
  }

  // ---------------------------------------------------------------- remote

  function focus(i) {
    if (!tiles.length) return;
    if (tiles[focused]) tiles[focused].className = tiles[focused].className.replace(' focus', '');
    focused = Math.max(0, Math.min(tiles.length - 1, i));
    var el = tiles[focused];
    el.className += ' focus';
    // Keep the focused line in view: move the whole list up by the tile's offset.
    var view = list.parentNode.clientHeight;
    var bottom = el.offsetTop + el.offsetHeight * 1.3;
    var shift = bottom > view ? bottom - view : 0;
    list.style.transform = 'translateY(' + (-shift) + 'px)';
  }

  /** The tile above or below: the nearest one on the next line in that direction. */
  function vertical(dir) {
    var cur = tiles[focused];
    var curX = cur.offsetLeft + cur.offsetWidth / 2;
    var best = -1, bestLine = null, bestGap = Infinity;
    for (var i = 0; i < tiles.length; i++) {
      var t = tiles[i];
      var dy = (t.offsetTop - cur.offsetTop) * dir;
      if (dy <= 1) continue;
      if (bestLine !== null && dy > bestLine + 1) continue;
      var gap = Math.abs(t.offsetLeft + t.offsetWidth / 2 - curX);
      if (bestLine === null || dy < bestLine - 1 || gap < bestGap) {
        best = i; bestLine = dy; bestGap = gap;
      }
    }
    if (best >= 0) focus(best);
  }

  function toast(text) {
    var el = document.getElementById('toast');
    el.textContent = text;
    el.className = 'show';
    clearTimeout(toast.timer);
    toast.timer = setTimeout(function () { el.className = ''; }, 2500);
  }

  function launch(app) {
    if (app.action === 'diag') { showDiag(true); return; }
    if (typeof tizen === 'undefined') { toast('Nur auf dem TV möglich'); return; }
    var ids = app.ids || [app.id];
    var n = 0;
    (function next() {
      if (n >= ids.length) { toast(app.name + ' lässt sich nicht öffnen'); return; }
      var id = ids[n++];
      try {
        tizen.application.launch(id, function () {}, next);
      } catch (e) {
        next();
      }
    })();
  }

  function showDiag(on) {
    diagOpen = on;
    document.getElementById('diag').className = on ? 'show' : '';
    if (!on) return;
    var lines = [];
    for (var i = 0; i < allApps.length; i++) {
      lines.push((allApps[i].show === false ? '  (versteckt) ' : '') + allApps[i].name + '   ' + allApps[i].id);
    }
    lines.sort();
    document.getElementById('diagText').textContent =
      lines.length ? lines.join('\n') : 'Der TV hat keine App-Liste geliefert.';
  }

  document.addEventListener('keydown', function (e) {
    if (diagOpen) { showDiag(false); e.preventDefault(); return; }
    switch (e.keyCode) {
      case KEY.LEFT: focus(focused - 1); break;
      case KEY.RIGHT: focus(focused + 1); break;
      case KEY.UP: vertical(-1); break;
      case KEY.DOWN: vertical(1); break;
      case KEY.ENTER: if (tiles[focused]) launch(tiles[focused].app); break;
      // Back never closes the start screen; it jumps to the first tile.
      case KEY.BACK: focus(0); break;
      default: return;
    }
    e.preventDefault();
  });

  // Coming back from an app: fresh clock and a fresh list (newly installed apps show up).
  document.addEventListener('visibilitychange', function () {
    if (!document.hidden) { tick(); load(); }
  });

  tick();
  setInterval(tick, 10000);
  load();
})();
