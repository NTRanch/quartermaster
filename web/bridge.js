// web/bridge.js — Quartermaster browser shell (inlined into index.html).
// Owns exactly four things: the canvas, input, WebAudio cues, and the
// save slot. Every decision lives in the Lua core; this file forwards.
(function () {
  "use strict";

  var SAVE_KEY = "quartermaster.save.v1";
  var STEP_MS = 1000 / 60;
  var STEPS_MAX = 4;

  function fail(message) {
    var el = document.getElementById("err");
    if (el) el.textContent = "Quartermaster failed to start: " + message;
    throw new Error(message);
  }

  var F = window.Fengari;
  if (!F) fail("Lua VM missing");
  var lua = F.lua, lauxlib = F.lauxlib, lualib = F.lualib;
  var toLuastring = F.to_luastring, toJsstring = F.to_jsstring;

  var L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);

  function luaToJS(index) {
    var type = lua.lua_type(L, index);
    if (type === lua.LUA_TNIL) return undefined;
    if (type === lua.LUA_TBOOLEAN) return lua.lua_toboolean(L, index);
    if (type === lua.LUA_TNUMBER) return lua.lua_tonumber(L, index);
    if (type === lua.LUA_TSTRING) return toJsstring(lua.lua_tostring(L, index));
    if (type === lua.LUA_TTABLE) {
      var entries = [];
      lua.lua_pushnil(L);
      while (lua.lua_next(L, index < 0 ? index - 1 : index) !== 0) {
        entries.push([luaToJS(-2), luaToJS(-1)]);
        lua.lua_pop(L, 1);
      }
      var isArray = entries.every(function (e) { return typeof e[0] === "number"; });
      if (isArray) {
        var sorted = entries.slice().sort(function (a, b) { return a[0] - b[0]; });
        if (sorted.every(function (e, i) { return e[0] === i + 1; })) {
          return sorted.map(function (e) { return e[1]; });
        }
      }
      var object = {};
      entries.forEach(function (e) { object[String(e[0])] = e[1]; });
      return object;
    }
    fail("unsupported Lua type " + type);
  }

  function pushValue(value) {
    if (value === null || value === undefined) lua.lua_pushnil(L);
    else if (typeof value === "number") lua.lua_pushnumber(L, value);
    else if (typeof value === "string") lua.lua_pushstring(L, toLuastring(value));
    else if (typeof value === "boolean") lua.lua_pushboolean(L, value);
    else fail("unsupported value " + typeof value);
  }

  function callGlobal(name, args) {
    lua.lua_getglobal(L, toLuastring(name));
    args.forEach(pushValue);
    if (lua.lua_pcall(L, args.length, 0, 0) !== lua.LUA_OK) {
      fail(name + ": " + toJsstring(lua.lua_tostring(L, -1)));
    }
  }

  // Boot: register the readable Lua sources, run the shared bootstrap.
  var sources = window.QM_SOURCES_JS;
  var names = Object.keys(sources);
  lua.lua_createtable(L, 0, names.length);
  names.forEach(function (name) {
    lua.lua_pushstring(L, toLuastring(sources[name]));
    lua.lua_setfield(L, -2, toLuastring(name));
  });
  lua.lua_setglobal(L, toLuastring("QM_SOURCES"));
  if (lauxlib.luaL_dostring(L, toLuastring(window.QM_BOOTSTRAP)) !== lua.LUA_OK) {
    fail("bootstrap: " + toJsstring(lua.lua_tostring(L, -1)));
  }

  var params = new URLSearchParams(window.location.search);
  var demoLevel = params.get("demo") ? Number(params.get("demo")) : null;
  var seed = params.get("seed")
    ? Number(params.get("seed"))
    : (Date.now() % 2147483646) + 1;
  var save = null;
  try {
    save = window.localStorage.getItem(SAVE_KEY);
  } catch (ignored) {
    save = null; // storage unavailable: the session simply does not persist
  }
  callGlobal("QM_BOOT", [seed, demoLevel, save]);

  // Input -----------------------------------------------------------------
  var canvas = document.getElementById("game");
  var ctx = canvas.getContext("2d");
  var pointerDown = false;
  var spaceDown = false;
  var pendingPress = null;
  var pendingKey = null;

  function logicalPos(event) {
    var rect = canvas.getBoundingClientRect();
    return {
      x: Math.round(((event.clientX - rect.left) / rect.width) * 960),
      y: Math.round(((event.clientY - rect.top) / rect.height) * 960),
    };
  }

  canvas.addEventListener("pointerdown", function (event) {
    ensureAudio();
    var pos = logicalPos(event);
    pendingPress = pos;
    pointerDown = true;
    canvas.setPointerCapture(event.pointerId);
  });
  canvas.addEventListener("pointerup", function () { pointerDown = false; });
  canvas.addEventListener("pointercancel", function () { pointerDown = false; });
  window.addEventListener("keydown", function (event) {
    if (event.key === " ") {
      spaceDown = true;
      event.preventDefault();
    } else if (!event.repeat && (event.key === "Escape" || /^[1-8]$/.test(event.key))) {
      pendingKey = event.key === "Escape" ? "escape" : event.key;
    }
  });
  window.addEventListener("keyup", function (event) {
    if (event.key === " ") spaceDown = false;
  });

  function nextInput(firstStep) {
    var input = null;
    if (firstStep && pendingPress) {
      input = { x: pendingPress.x, y: pendingPress.y, pressed: true };
      pendingPress = null;
    }
    if (firstStep && pendingKey) {
      input = input || {};
      input.key = pendingKey;
      pendingKey = null;
    }
    if (pointerDown || spaceDown) {
      input = input || {};
      input.down = true;
    }
    return input;
  }

  function stepCore(input) {
    lua.lua_getglobal(L, toLuastring("QM_STEP"));
    if (input === null) {
      lua.lua_pushnil(L);
    } else {
      lua.lua_createtable(L, 0, 5);
      ["x", "y", "key"].forEach(function (field) {
        if (input[field] !== undefined) {
          pushValue(input[field]);
          lua.lua_setfield(L, -2, toLuastring(field));
        }
      });
      ["pressed", "down"].forEach(function (field) {
        if (input[field] !== undefined) {
          pushValue(input[field]);
          lua.lua_setfield(L, -2, toLuastring(field));
        }
      });
    }
    if (lua.lua_pcall(L, 1, 0, 0) !== lua.LUA_OK) {
      fail("step: " + toJsstring(lua.lua_tostring(L, -1)));
    }
  }

  function readFrame() {
    lua.lua_getglobal(L, toLuastring("QM_FRAME"));
    if (lua.lua_pcall(L, 0, 1, 0) !== lua.LUA_OK) {
      fail("frame: " + toJsstring(lua.lua_tostring(L, -1)));
    }
    var frame = luaToJS(-1);
    lua.lua_pop(L, 1);
    return frame;
  }

  // Audio (generated, no assets; starts only after a user gesture) --------
  var audioCtx = null;
  var master = null;
  function ensureAudio() {
    if (audioCtx !== null) {
      if (audioCtx.state === "suspended") audioCtx.resume();
      return;
    }
    var AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    audioCtx = new AC();
    master = audioCtx.createGain();
    master.gain.value = 0.14;
    master.connect(audioCtx.destination);
  }

  function tone(freq, dur, type, delay, slideTo) {
    if (audioCtx === null || master === null) return;
    var t0 = audioCtx.currentTime + (delay || 0);
    var osc = audioCtx.createOscillator();
    var gain = audioCtx.createGain();
    osc.type = type || "sine";
    osc.frequency.setValueAtTime(freq, t0);
    if (slideTo) osc.frequency.exponentialRampToValueAtTime(slideTo, t0 + dur);
    gain.gain.setValueAtTime(0.5, t0);
    gain.gain.exponentialRampToValueAtTime(0.001, t0 + dur);
    osc.connect(gain);
    gain.connect(master);
    osc.start(t0);
    osc.stop(t0 + dur + 0.02);
  }

  var CUES = {
    click: function () { tone(700, 0.03, "square"); },
    call: function () { tone(392, 0.09, "sine"); tone(523, 0.1, "sine", 0.08); },
    good: function () { tone(784, 0.08, "sine"); },
    bad: function () { tone(147, 0.16, "sawtooth"); },
    appraise: function () {
      tone(523, 0.08, "sine"); tone(659, 0.08, "sine", 0.07);
      tone(784, 0.12, "sine", 0.14);
    },
    recall: function () { tone(440, 0.1, "triangle"); },
    done: function () {
      tone(523, 0.25, "sine"); tone(659, 0.25, "sine", 0.02);
      tone(784, 0.3, "sine", 0.04);
    },
  };

  // Render ------------------------------------------------------------------
  function render(frame) {
    var pal = frame.palette;
    ctx.fillStyle = pal[0];
    ctx.fillRect(0, 0, 960, 960);
    for (var i = 0; i < frame.ops.length; i++) {
      var op = frame.ops[i];
      var color = pal[op[op.length - 1]] || "#ff2e88";
      if (op[0] === "t") color = pal[op[4]];
      if (op[0] === "r") {
        ctx.fillStyle = color;
        ctx.fillRect(op[1], op[2], op[3], op[4]);
      } else if (op[0] === "c") {
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.arc(op[1], op[2], op[3], 0, Math.PI * 2);
        ctx.fill();
      } else if (op[0] === "l") {
        ctx.strokeStyle = color;
        ctx.lineWidth = op[5];
        ctx.lineCap = "round";
        ctx.beginPath();
        ctx.moveTo(op[1], op[2]);
        ctx.lineTo(op[3], op[4]);
        ctx.stroke();
      } else if (op[0] === "p") {
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.moveTo(op[1], op[2]);
        ctx.lineTo(op[3], op[4]);
        ctx.lineTo(op[5], op[6]);
        ctx.closePath();
        ctx.fill();
      } else if (op[0] === "t") {
        ctx.fillStyle = color;
        ctx.font = "bold " + op[3] + "px 'Courier New', monospace";
        ctx.textBaseline = "top";
        ctx.fillText(op[5], op[1], op[2]);
      }
    }
    if (master !== null && typeof frame.volume === "number") {
      master.gain.value = (frame.volume / 100) * 0.2;
    }
    if (frame.cues) {
      frame.cues.forEach(function (cue) {
        if (CUES[cue]) CUES[cue]();
      });
    }
    if (typeof frame.save === "string") {
      try {
        window.localStorage.setItem(SAVE_KEY, frame.save);
      } catch (ignored) {
        // Storage full/blocked: play continues, the record does not persist.
      }
    }
  }

  // Main loop: fixed-step accumulator, capped catch-up.
  var last = performance.now();
  var acc = 0;
  function loop(now) {
    acc += Math.min(now - last, 250);
    last = now;
    var steps = Math.floor(acc / STEP_MS);
    if (steps > 0) {
      steps = Math.min(steps, STEPS_MAX);
      acc -= steps * STEP_MS;
      for (var i = 0; i < steps; i++) stepCore(nextInput(i === 0));
      render(readFrame());
    }
    requestAnimationFrame(loop);
  }
  requestAnimationFrame(loop);
})();
