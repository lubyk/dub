/*
  ==============================================================================

   This file is part of the DUB bindings generator (http://lubyk.org/dub)
   Copyright (c) 2007-2012 by Gaspard Bucher (http://teti.ch).

  ------------------------------------------------------------------------------

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.

  ==============================================================================
*/
#include "dub/dub.h"

#define DUB_EXCEPTION_BUFFER_SIZE 256  
#define TYPE_EXCEPTION_MSG "%s expected, %s"
#define TYPE_EXCEPTION_SMSG "%s expected, %s (using super)"
#define DUB_MAX_IN_SHIFT 4294967296

using namespace dub;

// ======================================================================
// =============================================== dub::Exception
// ======================================================================
Exception::Exception(const char *format, ...) {
  char buffer[DUB_EXCEPTION_BUFFER_SIZE];
  va_list args;
  va_start(args, format);
    vsnprintf(buffer, DUB_EXCEPTION_BUFFER_SIZE, format, args);
  va_end(args);
  message_ = buffer;
}

Exception::~Exception() throw() {}

const char* Exception::what() const throw() {
  return message_.c_str();
}


TypeException::TypeException(lua_State *L, int narg, const char *type, bool is_super) :
  Exception(is_super ? TYPE_EXCEPTION_SMSG : TYPE_EXCEPTION_MSG, type, luaL_typename(L, narg)) {}

// ======================================================================
// =============================================== dub_pushudata
// ======================================================================
void dub_pushudata(lua_State *L, void *ptr, const char *type_name, bool gc) {
  DubUserdata *userdata = (DubUserdata*)lua_newuserdata(L, sizeof(DubUserdata));
  userdata->ptr = ptr;
  if (!gc) {
    // Point to owner to avoid owner gc.
    // <self> ... <obj>
    lua_newtable(L);
    // <self> .. <obj> <{}>
    lua_pushvalue(L, 1);
    // <self> .. <obj> <{}>._ = <self>
    lua_setfield(L, -2, "_");
    // <self> .. <obj> <{}>
    lua_setfenv(L, -2);
    // ... <obj>
  }

  userdata->gc = gc;

  // the userdata is now on top of the stack

  // set metatable (contains methods)
  luaL_getmetatable(L, type_name);
  lua_setmetatable(L, -2);
}

// ======================================================================
// =============================================== dub_check ...
// ======================================================================
// These methods are slight adaptations from luaxlib.c
// Copyright (C) 1994-2008 Lua.org, PUC-Rio.

lua_Number dub_checknumber(lua_State *L, int narg) throw(TypeException) {
  lua_Number d = lua_tonumber(L, narg);
  if (d == 0 && !lua_isnumber(L, narg))  /* avoid extra test when d is not 0 */
    throw TypeException(L, narg, lua_typename(L, LUA_TNUMBER));
  return d;
}

lua_Integer dub_checkinteger(lua_State *L, int narg) throw(TypeException) {
  lua_Integer d = lua_tointeger(L, narg);
  if (d == 0 && !lua_isnumber(L, narg))  /* avoid extra test when d is not 0 */
    throw TypeException(L, narg, lua_typename(L, LUA_TNUMBER));
  return d;
}

const char *dub_checklstring(lua_State *L, int narg, size_t *len) throw(TypeException) {
  const char *s = lua_tolstring(L, narg, len);
  if (!s) throw TypeException(L, narg, lua_typename(L, LUA_TSTRING));
  return s;
}

void *dub_checkudata(lua_State *L, int ud, const char *tname, bool keep_mt) throw(TypeException) {
  void *p = lua_touserdata(L, ud);
  if (p != NULL) {  /* value is a userdata? */
    if (lua_getmetatable(L, ud)) {  /* does it have a metatable? */
      lua_getfield(L, LUA_REGISTRYINDEX, tname);  /* get correct metatable */
      if (lua_rawequal(L, -1, -2)) {
        // same (correct) metatable
        if (!keep_mt) {
          lua_pop(L, 2);
        } else {
          // keep 1 metatable on top (needed by bindings)
          lua_pop(L, 1);
        }
        return p;
      }
    }
  }
  throw TypeException(L, ud, tname); /* else error */
  return NULL;  /* to avoid warnings */
}


static inline void *dub_cast_ud(lua_State *L, int ud, const char *tname) {
  // .. <ud> ... <mt> <mt>
  lua_pop(L, 1);
  // ... <ud> ... <mt>
  // TODO: optmize by putting this cast value in the registry.
  lua_pushlstring(L, "_cast_", 6);
  // ... <ud> ... <mt> "_cast_"
  lua_rawget(L, -2);
  if (lua_isfunction(L, -1)) {
    lua_pushvalue(L, ud);
    lua_pushstring(L, tname);
    // ... <ud> ... <mt> cast_func <ud> "OtherType"
    lua_call(L, 2, 1);
    // ... <ud> ... <mt> <ud>
    void *p = lua_touserdata(L, -1);
    if (p != NULL) {
      // done
      return p;
    }
  }

  // ... <ud> ... <mt> nil
  // Does not change stack size (only last element).
  return NULL;
}

static inline void*getsdata(lua_State *L, int ud, const char *tname, bool keep_mt) throw() {
  void *p = lua_touserdata(L, ud);
  if (p != NULL) {  /* value is a userdata? */
    if (lua_getmetatable(L, ud)) {  /* does it have a metatable? */
      lua_getfield(L, LUA_REGISTRYINDEX, tname);  /* get correct metatable */
      if (lua_rawequal(L, -1, -2)) {
        // same (correct) metatable
      } else {
        p = dub_cast_ud(L, ud, tname);
      }
    }
  } else if (lua_istable(L, ud)) {
    if (ud < 0) {
      ud = lua_gettop(L) + 1 + ud;
    }
    // get p from super
    // ... <ud> ...
    // TODO: optimize by storing key in registry ?
    lua_pushlstring(L, "super", 5);
    // ... <ud> ... <'super'>
    lua_rawget(L, ud);
    // ... <ud> ... <ud?>
    p = lua_touserdata(L, -1);
    if (p != NULL) {
      if (lua_getmetatable(L, -1)) {  /* does it have a metatable? */
        lua_getfield(L, LUA_REGISTRYINDEX, tname);  /* get correct metatable */
        if (lua_rawequal(L, -1, -2)) {
          // same (correct) metatable
          lua_remove(L, -3);
          // ... <ud> ... <mt> <mt>
        } else {
          p = dub_cast_ud(L, ud, tname);
        }
      }
    } else {
      lua_pop(L, -1);
      // ... <ud> ...
    }
  }
  if (p) {
    if (!keep_mt) {
      lua_pop(L, 2);
    } else {
      // keep 1 metatable on top (needed by bindings)
      lua_pop(L, 1);
    }
  }
  return p;
}

void *dub_checksdata_n(lua_State *L, int ud, const char *tname, bool keep_mt) throw() {
  void *p = getsdata(L, ud, tname, keep_mt);
  if (!p) {
    luaL_error(L, TYPE_EXCEPTION_MSG, tname, luaL_typename(L, ud));
  }
  return p;
}

void *dub_checksdata(lua_State *L, int ud, const char *tname, bool keep_mt) throw(TypeException) {
  void *p = getsdata(L, ud, tname, keep_mt);
  if (!p) {
    throw dub::TypeException(L, ud, tname);
  }
  return p;
}

// ======================================================================
// =============================================== dub_register
// ======================================================================

#define DUB_INIT_CODE "local class = %s.%s\nlocal new = class.new\nsetmetatable(class, {\n __call = function(_, ...)\n   return new(...)\n end,\n})\n"
// The metatable lives in libname.ClassName_
void dub_register(lua_State *L, const char *libname, const char *class_name) {
  // meta-table should be on top
  // <mt>
  lua_getfield(L, -1, "__index");
  if (lua_isnil(L, -1)) {
    lua_pop(L, 1);
    lua_pushvalue(L, -1);
    // <mt>.__index = <mt>
    lua_setfield(L, -2, "__index");
  } else {
    // We already have a custom __index metamethod.
    lua_pop(L, 1);
  }
  // <mt>
  lua_pushstring(L, "type");
  // <mt> "type"
  if (strcmp(libname, "_G")) {
    // not in _G
    lua_pushfstring(L, "%s.%s", libname, class_name);
    // <mt>."type" = "libname.class_name"
  } else {
    lua_pushstring(L, class_name);
    // <mt>."type" = "class_name"
  }
  lua_settable(L, -3);


  // <mt>
  lua_getfield(L, LUA_GLOBALSINDEX, libname);
  if (lua_isnil(L, -1)) {
    // no global table called libname
    lua_pop(L, 1);
    lua_newtable(L);
    // <mt> <lib>
    lua_pushvalue(L, -1);
    // <mt> <lib> <lib>
    // _G.libname = <lib>
    lua_setglobal(L, libname);
    // <mt> <lib>
  }

  // <mt> <lib>
  lua_pushstring(L, class_name);
  // <mt> <lib> "Foobar"
  lua_pushvalue(L, -3);
  // <mt> <lib>.Foobar = <mt>
  lua_settable(L, -3);
  // <mt> <lib>
  lua_pop(L, 1);
  // <mt>

  // Setup the __call meta-table with an upvalue
  size_t sz = strlen(DUB_INIT_CODE) + strlen(class_name) + strlen(libname) + 2;
  char *lua_code = (char*)malloc(sizeof(char) * sz);
  snprintf(lua_code, sz, DUB_INIT_CODE, libname, class_name);
  /*
  local class = lib.Foobar
  local new = class.new
  setmetatable(class, {
    __call = function(...)
      return new(...)
    end,
  })
  */
  int error = luaL_loadbuffer(L, lua_code, strlen(lua_code), "Dub init code") ||
              lua_pcall(L, 0, 0, 0);
  if (error) {
    fprintf(stderr, "%s", lua_tostring(L, -1));
    lua_pop(L, 1);  /* pop error message from the stack */
  }
  free(lua_code);
  // <mt>
}

int dub_hash(const char *str, int sz) {
  unsigned int h = 0;
  int c;

  while ( (c = *str++) ) {
    unsigned int h1 = (h << 6)  % DUB_MAX_IN_SHIFT;
    unsigned int h2 = (h << 16) % DUB_MAX_IN_SHIFT;
    h = c + h1 + h2 - h;
    h = h % DUB_MAX_IN_SHIFT;
  }
  return h % sz;
}

// register constants in the table at the top
void dub_register_const(lua_State *L, const dub_const_Reg*l) {
  for (; l->name; l++) {
    // push each constant into the table at top
    lua_pushnumber(L, l->value);
    lua_setfield(L, -2, l->name);
  }
}

