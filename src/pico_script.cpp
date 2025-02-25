#include "pico_script.h"

#include <assert.h>

#include <cstring>
#include <deque>
#include <functional>
#include <iostream>
#include <set>

#include "firmware.lua"
#include "hal_audio.h"
#include "hal_core.h"
#include "hal_fs.h"
#include "log.h"
#include "pico_audio.h"
#include "pico_cart.h"
#include "pico_core.h"
#include "z8lua/lauxlib.h"
#include "z8lua/lua.h"
#include "z8lua/lualib.h"

static lua_State* lstate = nullptr;

typedef std::function<void()> deferredAPICall_t;
static std::deque<deferredAPICall_t> deferredAPICalls;

static bool hook_funcs = false;

static void throw_error(int err) {
	if (err) {
		std::string msg = lua_tostring(lstate, -1);
		logr << LogLevel::err << msg;
		auto errlnstart = msg.find(":");
		auto errlnend = msg.find(":", errlnstart + 1);
		int errline = std::stoi(msg.substr(errlnstart + 1, errlnend - errlnstart - 1)) - 1;

		auto li = pico_cart::getLineInfo(pico_cart::getCart(), errline);

		std::stringstream ss;
		ss << li.filename << ":" << li.localLineNum << ":" << li.sourceLine << msg.substr(errlnend);

		pico_script::error e(ss.str());
		lua_pop(lstate, 1);
		throw e;
	}
}

static void dump_func(lua_State* ls, const char* funcname) {
	std::stringstream str;

	str << funcname + 5 << "(";
	int params = lua_gettop(ls);
	for (int n = 1; n <= params; n++) {
		auto s = luaL_tolstring(ls, n, nullptr);
		str << s << ",";
		lua_remove(ls, -1);
	}
	str << ")";
	logr << LogLevel::apitrace << str.str();
}

#define DEBUG_DUMP_FUNCTION                  \
	if (DEBUG_Trace()) {                     \
		/* pico_control::test_integrity();*/ \
		checkmem();                          \
		dump_func(ls, __FUNCTION__);         \
	}

static void register_cfuncs(lua_State* ls);

static void init_scripting() {
	lstate = luaL_newstate();
	luaL_openlibs(lstate);
	luaopen_debug(lstate);
	luaopen_string(lstate);

	hook_funcs = false;

	DEBUG_Trace(false);

	std::string fw = pico_cart::convert_emojis(firmware);

	throw_error(luaL_loadbuffer(lstate, fw.c_str(), fw.size(), "firmware"));
	throw_error(lua_pcall(lstate, 0, 0, 0));

	register_cfuncs(lstate);
	luaL_dostring(lstate, "__tac08__.make_api_list()");
}

// ------------------------------------------------------------------
// Lua accesable API
// ------------------------------------------------------------------

static int impl_load(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto s = luaL_checkstring(ls, 1);
	if (s) {
		deferredAPICalls.push_back([=]() { pico_api::load(s); });
	}
	return 0;
}

static int impl_run(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	deferredAPICalls.push_back([]() { pico_api::reloadcart(); });
	return 0;
}

static int impl_reload(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	if (lua_gettop(ls) == 0) {
		pico_api::reload(0, 0, 0x4300);
	} else {
		auto dest = luaL_checknumber(ls, 1).toInt();
		auto src = luaL_checknumber(ls, 2).toInt();
		auto len = luaL_checknumber(ls, 3).toInt();
		pico_api::reload(dest, src, len);
	}
	return 0;
}

static int impl_cartdata(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto s = luaL_checkstring(ls, 1);
	if (s) {
		pico_api::cartdata(s);
	}
	return 0;
}

static int impl_cls(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	if (lua_gettop(ls) == 0) {
		pico_api::cls();
	} else {
		auto n = lua_tonumber(ls, 1).toInt();
		pico_api::cls(n);
	}
	return 0;
}

static int impl_poke(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto a = luaL_checknumber(ls, 1).toInt();
	auto v = luaL_checknumber(ls, 2).toInt();
	pico_api::poke(a, v);
	return 0;
}

static int impl_peek(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto a = luaL_checknumber(ls, 1).toInt();
	uint32_t v = pico_api::peek(a);
	lua_pushnumber(ls, z8::fix32::frombits(v << 16));
	return 1;
}

static int impl_poke2(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto a = luaL_checknumber(ls, 1).toInt();
	auto v = luaL_checknumber(ls, 2);
	pico_api::poke2(a, v.toInt());
	return 0;
}

static int impl_peek2(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto a = luaL_checknumber(ls, 1).toInt();
	uint32_t v = pico_api::peek2(a);
	lua_pushnumber(ls, z8::fix32::frombits(v << 16));
	return 1;
}

static int impl_poke4(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto a = luaL_checknumber(ls, 1).toInt();
	auto v = luaL_checknumber(ls, 2);
	pico_api::poke4(a, v.bits());
	return 0;
}

static int impl_peek4(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto a = luaL_checknumber(ls, 1).toInt();
	uint32_t v = pico_api::peek4(a);
	lua_pushnumber(ls, z8::fix32::frombits(v));
	return 1;
}

static int impl_dget(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto a = luaL_checknumber(ls, 1).toInt();
	uint32_t v = pico_api::dget(a);
	lua_pushnumber(ls, z8::fix32::frombits(v));
	return 1;
}

static int impl_dset(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto a = luaL_checknumber(ls, 1).toInt();
	auto v = luaL_checknumber(ls, 2);
	pico_api::dset(a, v.bits());
	return 0;
}

static int impl_btn(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	if (lua_gettop(ls) == 0) {
		auto val = pico_api::btn();
		lua_pushnumber(ls, val);
		return 1;
	}

	auto n = luaL_checknumber(ls, 1).toInt();
	auto p = luaL_optnumber(ls, 2, 0).toInt();

	auto val = pico_api::btn(n, p);

	lua_pushboolean(ls, val);
	return 1;
}

static int impl_btnp(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	if (lua_gettop(ls) == 0) {
		auto val = pico_api::btnp();
		lua_pushnumber(ls, val);
		return 1;
	}

	auto n = luaL_checknumber(ls, 1).toInt();
	auto p = luaL_optnumber(ls, 2, 0).toInt();

	auto val = pico_api::btnp(n, p);

	lua_pushboolean(ls, val);
	return 1;
}

static int impl_mget(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto x = lua_tonumber(ls, 1).toInt();
	auto y = lua_tonumber(ls, 2).toInt();

	lua_pushnumber(ls, pico_api::mget(x, y));
	return 1;
}

static int impl_mset(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto x = lua_tonumber(ls, 1).toInt();
	auto y = lua_tonumber(ls, 2).toInt();
	auto v = lua_tonumber(ls, 3).toInt();

	pico_api::mset(x, y, v);
	return 0;
}

static int impl_fget(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto n = lua_tonumber(ls, 1).toInt();
	if (lua_gettop(ls) == 1) {
		lua_pushnumber(ls, pico_api::fget(n));
	} else {
		auto index = lua_tonumber(ls, 2).toInt();
		lua_pushboolean(ls, pico_api::fget(n, index));
	}
	return 1;
}

static int impl_fset(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto n = lua_tonumber(ls, 1).toInt();
	if (lua_gettop(ls) > 2) {
		auto index = lua_tonumber(ls, 2).toInt();
		auto val = lua_toboolean(ls, 3);
		pico_api::fset(n, index, val);
	} else {
		auto val = lua_tonumber(ls, 2).toInt();
		pico_api::fset(n, val);
	}

	return 0;
}

static int impl_palt(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	if (lua_gettop(ls) == 0) {
		pico_api::palt();
	} else {
		auto a = lua_tonumber(ls, 1).toInt();
		auto f = lua_toboolean(ls, 2);
		pico_api::palt(a, f);
	}
	return 0;
}

static int impl_map(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto count = lua_gettop(ls);

	auto cell_x = lua_tonumber(ls, 1).toInt();
	auto cell_y = lua_tonumber(ls, 2).toInt();
	if (count <= 2) {
		pico_api::map(cell_x, cell_y);
		return 0;
	}

	auto screen_x = lua_tonumber(ls, 3).toInt();
	auto screen_y = lua_tonumber(ls, 4).toInt();
	if (count <= 4) {
		pico_api::map(cell_x, cell_y, screen_x, screen_y);
		return 0;
	}

	auto cell_w = lua_tonumber(ls, 5).toInt();
	auto cell_h = lua_tonumber(ls, 6).toInt();
	if (count <= 6) {
		pico_api::map(cell_x, cell_y, screen_x, screen_y, cell_w, cell_h);
		return 0;
	}

	auto layer = lua_tonumber(ls, 7).toInt();
	pico_api::map(cell_x, cell_y, screen_x, screen_y, cell_w, cell_h, layer);
	return 0;
}

static int impl_pal(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto pcount = lua_gettop(ls);

	if (pcount == 0) {
		pico_api::pal();
	} else if (pcount < 3) {
		auto a = lua_tonumber(ls, 1).toInt();
		auto b = lua_tonumber(ls, 2).toInt();
		pico_api::pal(a, b);
	} else {
		auto a = lua_tonumber(ls, 1).toInt();
		auto b = lua_tonumber(ls, 2).toInt();
		auto c = lua_tonumber(ls, 3).toInt();
		pico_api::pal(a, b, c);
	}
	return 0;
}

static int impl_spr(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto n = lua_tonumber(ls, 1).toInt();
	auto x = lua_tonumber(ls, 2).toInt();
	auto y = lua_tonumber(ls, 3).toInt();

	if (lua_gettop(ls) <= 3) {
		pico_api::spr(n, x, y);
		return 0;
	}

	auto w = lua_tonumber(ls, 4).toInt();
	auto h = lua_tonumber(ls, 5).toInt();

	if (lua_gettop(ls) <= 5) {
		pico_api::spr(n, x, y, w, h);
		return 0;
	}

	auto flip_x = lua_toboolean(ls, 6);
	auto flip_y = lua_toboolean(ls, 7);

	pico_api::spr(n, x, y, w, h, flip_x, flip_y);

	return 0;
}

static int impl_sspr(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto sx = lua_tonumber(ls, 1).toInt();
	auto sy = lua_tonumber(ls, 2).toInt();
	auto sw = lua_tonumber(ls, 3).toInt();
	auto sh = lua_tonumber(ls, 4).toInt();
	auto dx = lua_tonumber(ls, 5).toInt();
	auto dy = lua_tonumber(ls, 6).toInt();

	if (lua_gettop(ls) <= 6) {
		pico_api::sspr(sx, sy, sw, sh, dx, dy);
		return 0;
	}

	auto dw = lua_tonumber(ls, 7).toInt();
	auto dh = lua_tonumber(ls, 8).toInt();
	auto flip_x = lua_toboolean(ls, 9);
	auto flip_y = lua_toboolean(ls, 10);
	pico_api::sspr(sx, sy, sw, sh, dx, dy, dw, dh, flip_x, flip_y);

	return 0;
}

static int impl_sset(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto x = lua_tonumber(ls, 1).toInt();
	auto y = lua_tonumber(ls, 2).toInt();

	if (lua_gettop(ls) <= 2) {
		pico_api::sset(x, y);
		return 0;
	}

	auto c = lua_tonumber(ls, 3).toInt();
	pico_api::sset(x, y, c);

	return 0;
}

static int impl_sget(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto x = lua_tonumber(ls, 1).toInt();
	auto y = lua_tonumber(ls, 2).toInt();

	lua_pushnumber(ls, pico_api::sget(x, y));
	return 1;
}

static int impl_print(lua_State* ls) {
	DEBUG_DUMP_FUNCTION

	if (lua_gettop(ls) == 1) {
		auto s = luaL_tolstring(ls, 1, nullptr);
		pico_api::print(s);
		lua_remove(ls, -1);
		return 0;
	}

	auto x = lua_tonumber(ls, 2).toInt();
	auto y = lua_tonumber(ls, 3).toInt();
	if (lua_gettop(ls) <= 3) {
		auto s = luaL_tolstring(ls, 1, nullptr);
		pico_api::print(s, x, y);
		lua_remove(ls, -1);
		return 0;
	}
	auto c = lua_tonumber(ls, 4).toInt();
	auto s = luaL_tolstring(ls, 1, nullptr);
	pico_api::print(s, x, y, c);
	lua_remove(ls, -1);
	return 0;
}

static int impl_cursor(lua_State* ls) {
	DEBUG_DUMP_FUNCTION

	auto x = lua_tonumber(ls, 1).toInt();
	auto y = lua_tonumber(ls, 2).toInt();
	if (lua_gettop(ls) <= 2) {
		pico_api::cursor(x, y);
	} else {
		auto c = lua_tonumber(ls, 3).toInt();
		pico_api::cursor(x, y, c);
	}
	return 0;
}

static int impl_pget(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto x = lua_tonumber(ls, 1).toInt();
	auto y = lua_tonumber(ls, 2).toInt();

	pico_api::colour_t p = pico_api::pget(x, y);
	lua_pushnumber(ls, p);
	return 1;
}

static int impl_pset(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto x = lua_tonumber(ls, 1).toInt();
	auto y = lua_tonumber(ls, 2).toInt();

	if (lua_gettop(ls) <= 2) {
		pico_api::pset(x, y);
		return 0;
	}

	auto c = lua_tonumber(ls, 3).bits();
	pico_api::pset(x, y, (c >> 16) & 0xffff, c & 0xffff);
	return 0;
}

static int impl_clip(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	if (lua_gettop(ls) == 0) {
		pico_api::clip();
	} else {
		auto x = lua_tonumber(ls, 1).toInt();
		auto y = lua_tonumber(ls, 2).toInt();
		auto w = lua_tonumber(ls, 3).toInt();
		auto h = lua_tonumber(ls, 4).toInt();

		pico_api::clip(x, y, w, h);
	}

	return 0;
}

static int impl_rectfill(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto x0 = lua_tonumber(ls, 1).toInt();
	auto y0 = lua_tonumber(ls, 2).toInt();
	auto x1 = lua_tonumber(ls, 3).toInt();
	auto y1 = lua_tonumber(ls, 4).toInt();

	if (lua_gettop(ls) <= 4) {
		pico_api::rectfill(x0, y0, x1, y1);
		return 0;
	}

	auto c = lua_tonumber(ls, 5).bits();
	pico_api::rectfill(x0, y0, x1, y1, (c >> 16) & 0xffff, c & 0xffff);

	return 0;
}

static int impl_rect(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto x0 = lua_tonumber(ls, 1).toInt();
	auto y0 = lua_tonumber(ls, 2).toInt();
	auto x1 = lua_tonumber(ls, 3).toInt();
	auto y1 = lua_tonumber(ls, 4).toInt();

	if (lua_gettop(ls) <= 4) {
		pico_api::rect(x0, y0, x1, y1);
		return 0;
	}
	auto c = lua_tonumber(ls, 5).bits();
	pico_api::rect(x0, y0, x1, y1, (c >> 16) & 0xffff, c & 0xffff);

	return 0;
}

static int impl_circfill(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto x = lua_tonumber(ls, 1).toInt();
	auto y = lua_tonumber(ls, 2).toInt();
	auto r = lua_tonumber(ls, 3).toInt();

	if (lua_gettop(ls) <= 3) {
		pico_api::circfill(x, y, r);
		return 0;
	}

	auto c = lua_tonumber(ls, 4).bits();
	pico_api::circfill(x, y, r, (c >> 16) & 0xffff, c & 0xffff);

	return 0;
}

static int impl_circ(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto x = lua_tonumber(ls, 1).toInt();
	auto y = lua_tonumber(ls, 2).toInt();
	auto r = lua_tonumber(ls, 3).toInt();

	if (lua_gettop(ls) <= 3) {
		pico_api::circ(x, y, r);
		return 0;
	}
	auto c = lua_tonumber(ls, 4).bits();
	pico_api::circ(x, y, r, (c >> 16) & 0xffff, c & 0xffff);

	return 0;
}

static int impl_line(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto x0 = lua_tonumber(ls, 1).toInt();
	auto y0 = lua_tonumber(ls, 2).toInt();

	if (lua_gettop(ls) <= 2) {
		pico_api::line(x0, y0);
		return 0;
	}

	auto x1 = lua_tonumber(ls, 3).toInt();
	auto y1 = lua_tonumber(ls, 4).toInt();

	if (lua_gettop(ls) <= 4) {
		pico_api::line(x0, y0, x1, y1);
		return 0;
	}

	auto c = lua_tonumber(ls, 5).bits();
	pico_api::line(x0, y0, x1, y1, (c >> 16) & 0xffff, c & 0xffff);
	return 0;
}

static int impl_fillp(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	if (lua_gettop(ls) == 0) {
		pico_api::fillp();
	} else {
		auto n = lua_tonumber(ls, 1);
		auto bits = n.bits();
		int pattern = (bits >> 16) & 0xffff;
		bool transparent = (bits & 0xffff) != 0;
		pico_api::fillp(pattern, transparent);
	}
	return 0;
}

static int impl_time(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	uint64_t t = TIME_GetTime_ms();
	t = (t << 16) / 1000;
	lua_pushnumber(ls, z8::fix32::frombits((uint32_t)t));
	return 1;
}

static int impl_color(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto c = luaL_optnumber(ls, 1, 0).toInt();
	pico_api::color(c);
	return 0;
}

static int impl_camera(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	if (lua_gettop(ls) == 0) {
		pico_api::camera();
	} else {
		auto x = lua_tonumber(ls, 1).toInt();
		auto y = lua_tonumber(ls, 2).toInt();
		pico_api::camera(x, y);
	}
	return 0;
}

static int impl_stat(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto k = luaL_checknumber(ls, 1).toInt();

	std::string s;
	int i;
	double f;

	auto v = pico_api::stat(k, s, i, f);

	if (v == 1)
		lua_pushstring(ls, s.c_str());
	else if (v == 2)
		lua_pushnumber(ls, i);
	else if (v == 3)
		lua_pushnumber(ls, f);
	else
		lua_pushnil(ls);

	return 1;
}

static int impl_music(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto nargs = lua_gettop(ls);
	auto n = lua_tonumber(ls, 1).toInt();
	auto fadems = lua_tonumber(ls, 2).toInt();
	auto channelmask = lua_tonumber(ls, 3).toInt();

	if (nargs == 1) {
		pico_api::music(n);
	} else if (nargs == 2) {
		pico_api::music(n, fadems);
	} else {
		pico_api::music(n, fadems, channelmask);
	}

	return 0;
}

static int impl_sfx(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto nargs = lua_gettop(ls);
	auto n = lua_tonumber(ls, 1).toInt();
	auto channel = lua_tonumber(ls, 2).toInt();
	auto offset = lua_tonumber(ls, 3).toInt();
	auto length = lua_tonumber(ls, 4).toInt();

	if (nargs == 1) {
		pico_api::sfx(n);
	} else if (nargs == 2) {
		pico_api::sfx(n, channel);
	} else if (nargs == 3) {
		pico_api::sfx(n, channel, offset);
	} else {
		pico_api::sfx(n, channel, offset, length);
	}
	return 0;
}

static int impl_memcpy(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto src_a = lua_tonumber(ls, 1).toInt();
	auto dest_a = lua_tonumber(ls, 2).toInt();
	auto len = lua_tonumber(ls, 3).toInt();
	pico_api::memory_cpy(src_a, dest_a, len);
	return 0;
}

static int impl_memset(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto a = lua_tonumber(ls, 1).toInt();
	auto val = lua_tonumber(ls, 2).toInt();
	auto len = lua_tonumber(ls, 3).toInt();
	pico_api::memory_set(a, val, len);
	return 0;
}

static int impl_ord(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	const char* msg = luaL_checkstring(lstate, 1);
	if (msg && strlen(msg)) {
		lua_pushnumber(ls, (lua_Number)msg[0]);
		return 1;
	}
	return 0;
}

static int impl_chr(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto n = luaL_checknumber(ls, 1).toInt();
	char buffer[] = "\0\0";
	if (n >= 0 && n <= 255) {
		buffer[0] = n & 0xff;
		lua_pushstring(ls, buffer);
		return 1;
	}
	return 0;
}

static int implx_wrclip(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto s = luaL_checkstring(ls, 1);
	if (s) {
		pico_apix::wrclip(s);
	}
	return 0;
}

static int implx_rdclip(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto s = pico_apix::rdclip();
	lua_pushstring(ls, s.c_str());
	return 1;
}

static int implx_rdstr(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto name = luaL_checkstring(ls, 1);
	std::string res;
	if (name) {
		res = pico_apix::rdstr(name);
	}
	lua_pushstring(ls, res.c_str());
	return 1;
}

static int implx_wrstr(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto name = luaL_checkstring(ls, 1);
	auto s = luaL_checkstring(ls, 2);
	if (name && s) {
		pico_apix::wrstr(name, s);
	}
	return 0;
}

// returns nil if sound could not be loaded.
static int implx_wavload(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto name = luaL_checkstring(ls, 1);
	int id = pico_apix::wavload(name);
	if (id < 0)
		lua_pushnil(ls);
	else
		lua_pushnumber(ls, id);

	return 1;
}

static int implx_wavplay(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto id = luaL_checknumber(ls, 1).toInt();
	auto chan = luaL_checknumber(ls, 2).toInt();
	if (lua_gettop(ls) == 3) {
		bool loop = lua_toboolean(ls, 3);
		AUDIO_Play(id, chan, loop);
		return 0;
	}
	auto loop_start = luaL_checknumber(ls, 3).toInt();
	auto loop_end = luaL_checknumber(ls, 4).toInt();
	AUDIO_Play(id, chan, loop_start, loop_end);
	return 0;
}

static int implx_wavstop(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto chan = luaL_checknumber(ls, 1).toInt();
	AUDIO_Stop(chan);
	return 0;
}

static int implx_wavstoploop(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto chan = luaL_checknumber(ls, 1).toInt();
	AUDIO_StopLoop(chan);
	return 0;
}

static int implx_wavplaying(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto chan = luaL_checknumber(ls, 1).toInt();
	bool b = AUDIO_isPlaying(chan);
	lua_pushboolean(ls, b);
	return 1;
}

static int implx_setpal(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto i = luaL_checknumber(ls, 1).toInt();
	auto r = luaL_checknumber(ls, 2).toInt();
	auto g = luaL_checknumber(ls, 3).toInt();
	auto b = luaL_checknumber(ls, 4).toInt();
	pico_apix::setpal(i, r, g, b);
	return 0;
}

static int implx_selpal(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto name = luaL_checkstring(ls, 1);
	pico_apix::selpal(name);
	return 0;
}

static int implx_resetpal(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	if (lua_gettop(ls) == 1) {
		auto i = luaL_checknumber(ls, 1).toInt();
		pico_apix::resetpal(i);
	} else {
		pico_apix::resetpal();
	}

	return 0;
}

static int implx_screen(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto w = luaL_checknumber(ls, 1).toInt();
	auto h = luaL_checknumber(ls, 2).toInt();
	pico_apix::screen(w, h);
	return 0;
}

static int implx_zoom(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	if (lua_gettop(ls) > 0) {
		auto x = luaL_checknumber(ls, 1).toInt();
		auto y = luaL_checknumber(ls, 2).toInt();
		double factor = luaL_checknumber(ls, 3);
		double rot = luaL_optnumber(ls, 4, 0);
		pico_apix::zoom(x, y, factor, rot);
	} else {
		pico_apix::zoom();
	}
	return 0;
}

static int implx_xpal(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto enable = lua_toboolean(ls, 1);
	pico_apix::xpal(enable);
	return 0;
}

static int implx_cursor(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto enable = lua_toboolean(ls, 1);
	pico_apix::cursor(enable);
	return 0;
}

static int implx_showmenu(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	pico_apix::menu();
	return 0;
}

static int implx_touchmask(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	uint8_t m = INP_GetTouchMask();
	lua_pushnumber(ls, m);
	return 1;
}

static int implx_touchavail(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	bool avail = INP_TouchAvailable();
	lua_pushboolean(ls, avail);
	return 1;
}

static int implx_touchstate(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto idx = luaL_checknumber(ls, 1).toInt();
	TouchInfo ti = INP_GetTouchInfo(idx);
	lua_pushnumber(ls, ti.x);
	lua_pushnumber(ls, ti.y);
	lua_pushnumber(ls, ti.state);
	return 3;
}

static int implx_siminput(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto state = luaL_checknumber(ls, 1).toInt();
	pico_apix::siminput((uint8_t)state);
	return 0;
}

static int implx_sprites(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	if (lua_gettop(ls) == 0) {
		pico_apix::sprites();
	}
	auto page = luaL_checknumber(ls, 1).toInt();
	pico_apix::sprites(page);
	return 0;
}

static int implx_maps(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	if (lua_gettop(ls) == 0) {
		pico_apix::maps();
	}
	auto page = luaL_checknumber(ls, 1).toInt();
	pico_apix::maps(page);
	return 0;
}

static int implx_fonts(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	if (lua_gettop(ls) == 0) {
		pico_apix::fonts();
	}
	auto page = luaL_checknumber(ls, 1).toInt();
	pico_apix::fonts(page);
	return 0;
}

static int implx_open_url(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto s = luaL_checkstring(ls, 1);
	if (s) {
		PLATFORM_OpenURL(s);
	}
	return 0;
}

static int implx_tron(lua_State* ls) {
	pico_script::tron();
	DEBUG_DUMP_FUNCTION
	return 0;
}

static int implx_troff(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	pico_script::troff();
	return 0;
}

static int implx_fullscreen(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto enable = lua_toboolean(ls, 1);
	pico_apix::fullscreen(enable);
	return 0;
}

static int implx_window(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	return 0;
}

static int implx_assetload(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto s = luaL_checkstring(ls, 1);
	if (s) {
		pico_apix::assetload(s);
	}
	return 0;
}

static int implx_gfxstate(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	int index = lua_tonumber(ls, 1).toInt();
	pico_apix::gfxstate(index);
	return 0;
}

// dbg_getsrc (source, line)
static int implx_dbg_getsrc(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto src = luaL_checkstring(ls, 1);
	auto line = luaL_checknumber(ls, 2).toInt();

	auto l = pico_apix::dbg_getsrc(src, line);
	if (l.second) {
		lua_pushstring(ls, l.first.c_str());
		return 1;
	}
	return 0;
}

static int implx_dbg_getsrclines(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto l = pico_apix::dbg_getsrclines();
	lua_pushnumber(ls, l);
	return 1;
}

static std::set<int> debug_breakpoints;
static bool debug_singlestep = false;
static int break_line_number = -1;

static void dbg_hookfunc(lua_State* ls, lua_Debug* ar) {
	//	logr << "dbg_hookfunc " << ar->currentline << ":"
	//<< pico_apix::dbg_getsrc("main", ar->currentline).first;

	break_line_number = -1;

	lua_Debug info;
	lua_getstack(ls, 0, &info);
	lua_getinfo(ls, "S", &info);

	if (info.source && strcmp(info.source, "main") != 0) {
		return;
	}

	if (debug_breakpoints.count(ar->currentline) || debug_singlestep) {
		debug_singlestep = false;
		break_line_number = ar->currentline;
		luaL_dostring(ls, "__tac08__.dbg.locals = __tac08__.dbg.dumplocals(3)");
		lua_yield(ls, 0);
	}
}

// dbg_cocreate (thread_func) -> coroutine
static int implx_dbg_cocreate(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	luaL_checktype(ls, 1, LUA_TFUNCTION);
	lua_State* co = lua_newthread(ls);
	lua_sethook(co, dbg_hookfunc, LUA_MASKLINE, 0);
	lua_pushvalue(ls, 1); /* move function to top */
	lua_xmove(ls, co, 1); /* move function from L to NL */

	return 1;
}

void dumpstack(lua_State* ls, const char* name) {
	TraceFunction();
	logr << "dumpstack: " << name << " items: " << lua_gettop(ls);
	for (int n = 1; n <= lua_gettop(ls); n++) {
		logr << lua_typename(ls, lua_type(ls, n)) << ": " << lua_tostring(ls, n);
	}
}

// dbg_coresume (thread, mode) -> status_str, (error_str|line_number)
// mode = "run" - runs till breakpoint hit
// 		  "step" - executes single line of code.
// status_str = "break" - code hit breakpoint/line stop/function stop
// 				"done" - code completed execution normally
//				"error" - code generated an error.
static int implx_dbg_coresume(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	luaL_checktype(ls, -2, LUA_TTHREAD);
	lua_State* co = lua_tothread(ls, -2);
	std::string mode = lua_tostring(ls, -1);

	debug_singlestep = (mode == "step");

	int status = lua_status(co);
	if (status == LUA_OK || status == LUA_YIELD) {
		status = lua_resume(co, 0, 0);
	}

	switch (status) {
		case LUA_OK:
			lua_pushstring(ls, "done");
			return 1;

		case LUA_YIELD:
			lua_pushstring(ls, "break");
			lua_pushnumber(ls, break_line_number);
			return 2;

		default:
			lua_pushstring(ls, "error");
			lua_pushstring(ls, lua_tostring(co, -1));

			lua_Debug info;
			lua_getstack(co, 0, &info);
			lua_getinfo(co, "l", &info);

			lua_pushnumber(ls, info.currentline);
			luaL_dostring(co, "__tac08__.dbg.locals = __tac08__.dbg.dumplocals(3)");
			return 3;
	}

	return 0;
}

// dbg_bpline (line, enabled)
static int implx_dbg_bpline(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	int line = luaL_checknumber(ls, 1).toInt();
	bool enabled = lua_toboolean(ls, 2);

	if (enabled) {
		debug_breakpoints.insert(line);
	} else {
		debug_breakpoints.erase(line);
	}
	return 0;
}

static int implx_dbg_hooks(lua_State* ls) {
	hook_funcs = true;
	return 0;
}

static int implx_getkey(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto s = pico_apix::getkey();
	if (s.length()) {
		lua_pushstring(ls, s.c_str());
		return 1;
	}
	return 0;
}

// printx(str, x, y, c) -> returns next x, y
static int implx_printx(lua_State* ls) {
	DEBUG_DUMP_FUNCTION

	auto s = luaL_checklstring(ls, 1, nullptr);
	auto x = luaL_checknumber(ls, 2).toInt();
	auto y = luaL_checknumber(ls, 3).toInt();
	auto c = luaL_checknumber(ls, 4).toInt();
	auto xy = pico_apix::printx(s, x, y, c);
	lua_remove(ls, -1);
	lua_pushnumber(ls, xy.first);
	lua_pushnumber(ls, xy.second);
	return 2;
}

static int implx_cwd(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto path = hal_fs::cwd();
	lua_pushstring(ls, path.c_str());
	return 1;
}

static int implx_files(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto fi = hal_fs::files();

	if (fi.name != "") {
		lua_pushstring(ls, fi.name.c_str());
		lua_pushboolean(ls, fi.dir);
		return 2;
	}
	return 0;
}

static int implx_cd(lua_State* ls) {
	DEBUG_DUMP_FUNCTION
	auto s = luaL_checkstring(ls, 1);
	hal_fs::cd(s);
	auto path = hal_fs::cwd();
	lua_pushstring(ls, path.c_str());
	return 1;
}

// ------------------------------------------------------------------

static const luaL_Reg pico8_api[] = {{"load", impl_load},         {"run", impl_run},
                                     {"reload", impl_reload},     {"cartdata", impl_cartdata},
                                     {"cls", impl_cls},           {"poke", impl_poke},
                                     {"peek", impl_peek},         {"poke2", impl_poke2},
                                     {"peek2", impl_peek2},       {"poke4", impl_poke4},
                                     {"peek4", impl_peek4},       {"dget", impl_dget},
                                     {"dset", impl_dset},         {"btn", impl_btn},
                                     {"btnp", impl_btnp},         {"mget", impl_mget},
                                     {"mset", impl_mset},         {"fget", impl_fget},
                                     {"fset", impl_fset},         {"palt", impl_palt},
                                     {"map", impl_map},           {"mapdraw", impl_map},
                                     {"pal", impl_pal},           {"sget", impl_sget},
                                     {"sset", impl_sset},         {"spr", impl_spr},
                                     {"sspr", impl_sspr},         {"print", impl_print},
                                     {"cursor", impl_cursor},     {"pget", impl_pget},
                                     {"pset", impl_pset},         {"clip", impl_clip},
                                     {"rectfill", impl_rectfill}, {"rect", impl_rect},
                                     {"circfill", impl_circfill}, {"circ", impl_circ},
                                     {"line", impl_line},         {"fillp", impl_fillp},
                                     {"time", impl_time},         {"t", impl_time},
                                     {"color", impl_color},       {"camera", impl_camera},
                                     {"stat", impl_stat},         {"music", impl_music},
                                     {"sfx", impl_sfx},           {"memcpy", impl_memcpy},
                                     {"memset", impl_memset},     {"ord", impl_ord},
                                     {"chr", impl_chr},           {NULL, NULL}};

static const luaL_Reg tac08_api[] = {{"wrclip", implx_wrclip},
                                     {"rdclip", implx_rdclip},
                                     {"wrstr", implx_wrstr},
                                     {"rdstr", implx_rdstr},
                                     {"wavload", implx_wavload},
                                     {"wavplay", implx_wavplay},
                                     {"wavstop", implx_wavstop},
                                     {"wavstoploop", implx_wavstoploop},
                                     {"wavplaying", implx_wavplaying},
                                     {"setpal", implx_setpal},
                                     {"selpal", implx_selpal},
                                     {"resetpal", implx_resetpal},
                                     {"screen", implx_screen},
                                     {"zoom", implx_zoom},
                                     {"xpal", implx_xpal},
                                     {"cursor", implx_cursor},
                                     {"showmenu", implx_showmenu},
                                     {"touchmask", implx_touchmask},
                                     {"touchstate", implx_touchstate},
                                     {"touchavail", implx_touchavail},
                                     {"siminput", implx_siminput},
                                     {"sprites", implx_sprites},
                                     {"maps", implx_maps},
                                     {"fonts", implx_fonts},
                                     {"open_url", implx_open_url},
                                     {"tron", implx_tron},
                                     {"troff", implx_troff},
                                     {"fullscreen", implx_fullscreen},
                                     {"window", implx_window},
                                     {"assetload", implx_assetload},
                                     {"gfxstate", implx_gfxstate},
                                     {"dbg_getsrc", implx_dbg_getsrc},
                                     {"dbg_getsrclines", implx_dbg_getsrclines},
                                     {"dbg_cocreate", implx_dbg_cocreate},
                                     {"dbg_coresume", implx_dbg_coresume},
                                     {"dbg_bpline", implx_dbg_bpline},
                                     {"dbg_hooks", implx_dbg_hooks},
                                     {"getkey", implx_getkey},
                                     {"printx", implx_printx},
                                     {"cwd", implx_cwd},
                                     {"files", implx_files},
                                     {"cd", implx_cd},
                                     {NULL, NULL}};

static void register_cfuncs(lua_State* ls) {
	lua_pushglobaltable(ls);
	luaL_setfuncs(ls, pico8_api, 0);

	lua_getglobal(ls, "__tac08__");
	luaL_setfuncs(ls, tac08_api, 0);
}

namespace pico_script {

	/* - not needed here
	    const char* buffer;
	    const char* buffer_reader(lua_State* L, void* ud, size_t* sz) {
	        logr << LogLevel::trace << char(*buffer);
	        if (*buffer) {
	            *sz = 1;
	        } else {
	            *sz = 0;
	        }
	        return buffer++;
	    }
	*/

	void load(const pico_cart::Cart& cart) {
		TraceFunction();
		unload_scripting();
		init_scripting();

		std::string code;

		for (size_t i = 0; i < cart.source.size(); i++) {
			code += cart.source[i].line + "\n";
		}
		throw_error(luaL_loadbuffer(lstate, code.c_str(), code.size(), "main"));
		throw_error(lua_pcall(lstate, 0, 0, 0));
	}

	void unload_scripting() {
		if (lstate) {
			lua_close(lstate);
			lstate = nullptr;
		}
		deferredAPICalls.clear();
	}

	bool symbolExist(const char* s) {
		lua_getglobal(lstate, s);
		bool exist = !lua_isnil(lstate, -1);
		lua_pop(lstate, 1);
		return exist;
	}

	bool simpleCall(std::string function, bool optional) {
		lua_getglobal(lstate, function.c_str());

		if (!lua_isfunction(lstate, -1)) {
			if (optional) {
				lua_pop(lstate, 1);
				return false;
			} else
				throw pico_script::error(function + " not found");
		}
		throw_error(lua_pcall(lstate, 0, 0, 0));
		return true;
	}

	static std::map<std::string, std::string> function_hooks = {
	    {"_init", "__tac08__dbg_init"},
	    {"_update", "__tac08__dbg_update"},
	    {"_update60", "__tac08__dbg_update60"},
	    {"_draw", "__tac08__dbg_draw"},
	};

	bool run(std::string function, bool optional, bool& restarted) {
		if (restarted) {
			return true;
		}

		if (hook_funcs) {
			auto f = function_hooks.find(function);
			if (f != function_hooks.end()) {
				function = f->second;
			}
		}

		auto ret = simpleCall(function, optional);

		while (!deferredAPICalls.empty()) {
			deferredAPICall_t apicall = deferredAPICalls.front();
			deferredAPICalls.pop_front();
			apicall();
			restarted = true;
		}
		return ret;
	}

	// returns true when menu finished
	bool do_menu() {
		lua_getglobal(lstate, "__tac08__");
		lua_getfield(lstate, -1, "do_menu");
		lua_remove(lstate, -2);
		throw_error(lua_pcall(lstate, 0, 1, 0));
		bool res = lua_toboolean(lstate, -1);
		lua_pop(lstate, 1);

		return res;
	}

	void tron() {
		DEBUG_Trace(true);
	}

	void troff() {
		DEBUG_Trace(false);
	}

}  // namespace pico_script
