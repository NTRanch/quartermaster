// tools/lua-host.mjs — run the shipped Lua core under Fengari in node.
// Same VM package the single file inlines (fengari 0.1.4), same bootstrap,
// same module sources: the capture and conformance tools therefore measure
// the shipped artifact, not a port.
import { createRequire } from "node:module";
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const fengari = require("fengari");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari;

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..");

function loadSources() {
  const sources = {};
  for (const file of readdirSync(join(ROOT, "src"))) {
    if (file.endsWith(".lua")) {
      const name = "src." + file.slice(0, -4);
      sources[name] = readFileSync(join(ROOT, "src", file), "utf8");
    }
  }
  return sources;
}

function luaToJS(L, index) {
  const type = lua.lua_type(L, index);
  if (type === lua.LUA_TNIL) return undefined;
  if (type === lua.LUA_TBOOLEAN) return lua.lua_toboolean(L, index);
  if (type === lua.LUA_TNUMBER) return lua.lua_tonumber(L, index);
  if (type === lua.LUA_TSTRING) return to_jsstring(lua.lua_tostring(L, index));
  if (type === lua.LUA_TTABLE) {
    const entries = [];
    lua.lua_pushnil(L);
    while (lua.lua_next(L, index < 0 ? index - 1 : index) !== 0) {
      const key = luaToJS(L, -2);
      const value = luaToJS(L, -1);
      entries.push([key, value]);
      lua.lua_pop(L, 1);
    }
    // Fengari's lua_next walks the array part in reverse: order by key,
    // never by traversal order.
    const isArray = entries.every(([k]) => typeof k === "number");
    if (isArray) {
      const sorted = [...entries].sort((a, b) => a[0] - b[0]);
      if (sorted.every(([k], i) => k === i + 1)) {
        return sorted.map(([, v]) => v);
      }
    }
    const object = {};
    for (const [k, v] of entries) object[String(k)] = v;
    return object;
  }
  throw new Error("luaToJS: unsupported type " + type);
}

function pushValue(L, value) {
  if (value === null || value === undefined) lua.lua_pushnil(L);
  else if (typeof value === "number") lua.lua_pushnumber(L, value);
  else if (typeof value === "string") lua.lua_pushstring(L, to_luastring(value));
  else if (typeof value === "boolean") lua.lua_pushboolean(L, value);
  else throw new Error("pushValue: unsupported " + typeof value);
}

export function bootGame({ seed, demoLevel = null, save = null }) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const sources = loadSources();
  lua.lua_createtable(L, 0, Object.keys(sources).length);
  for (const [name, src] of Object.entries(sources)) {
    lua.lua_pushstring(L, to_luastring(src));
    lua.lua_setfield(L, -2, to_luastring(name));
  }
  lua.lua_setglobal(L, to_luastring("QM_SOURCES"));
  const bootstrap = readFileSync(join(ROOT, "web", "bootstrap.lua"), "utf8");
  if (lauxlib.luaL_dostring(L, to_luastring(bootstrap)) !== lua.LUA_OK) {
    throw new Error("bootstrap failed: " + to_jsstring(lua.lua_tostring(L, -1)));
  }
  lua.lua_getglobal(L, to_luastring("QM_BOOT"));
  pushValue(L, seed);
  pushValue(L, demoLevel);
  pushValue(L, save);
  if (lua.lua_pcall(L, 3, 0, 0) !== lua.LUA_OK) {
    throw new Error("QM_BOOT failed: " + to_jsstring(lua.lua_tostring(L, -1)));
  }
  return {
    step(input) {
      lua.lua_getglobal(L, to_luastring("QM_STEP"));
      if (input === null || input === undefined) {
        lua.lua_pushnil(L);
      } else {
        lua.lua_createtable(L, 0, 5);
        for (const field of ["x", "y", "key"]) {
          if (input[field] !== undefined) {
            pushValue(L, input[field]);
            lua.lua_setfield(L, -2, to_luastring(field));
          }
        }
        for (const field of ["pressed", "down"]) {
          if (input[field] !== undefined) {
            pushValue(L, input[field]);
            lua.lua_setfield(L, -2, to_luastring(field));
          }
        }
      }
      if (lua.lua_pcall(L, 1, 0, 0) !== lua.LUA_OK) {
        throw new Error("QM_STEP failed: " + to_jsstring(lua.lua_tostring(L, -1)));
      }
    },
    frame() {
      lua.lua_getglobal(L, to_luastring("QM_FRAME"));
      if (lua.lua_pcall(L, 0, 1, 0) !== lua.LUA_OK) {
        throw new Error("QM_FRAME failed: " + to_jsstring(lua.lua_tostring(L, -1)));
      }
      const frame = luaToJS(L, -1);
      lua.lua_pop(L, 1);
      return frame;
    },
  };
}
