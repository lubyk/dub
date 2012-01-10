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
#define TYPE_EXCEPTION_MSG "%s expected, got %s"
#define TYPE_EXCEPTION_SMSG "%s expected, got %s (using super)"
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
// =============================================== dub::pushudata
// ======================================================================
void pushudata(lua_State *L, void *ptr, const char *type_name) {
  void **userdata = (void**)lua_newuserdata(L, sizeof(void*));
  *userdata = ptr;

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

void *dub_checkudata(lua_State *L, int ud, const char *tname) throw(TypeException) {
  void *p = lua_touserdata(L, ud);
  if (p != NULL) {  /* value is a userdata? */
    if (lua_getmetatable(L, ud)) {  /* does it have a metatable? */
      lua_getfield(L, LUA_REGISTRYINDEX, tname);  /* get correct metatable */
      if (lua_rawequal(L, -1, -2)) {  /* does it have the correct mt? */
        lua_pop(L, 2);  /* remove both metatables */
        return p;
      }
    }
  }
  throw TypeException(L, ud, tname); /* else error */
  return NULL;  /* to avoid warnings */
}

void *dub_checksdata(lua_State *L, int ud, const char *tname) throw(TypeException) {
  void *p = lua_touserdata(L, ud);
  if (p != NULL) {  /* value is a userdata? */
    if (lua_getmetatable(L, ud)) {  /* does it have a metatable? */
      lua_getfield(L, LUA_REGISTRYINDEX, tname);  /* get correct metatable */
      if (lua_rawequal(L, -1, -2)) {  /* does it have the correct mt? */
        lua_pop(L, 2);  /* remove both metatables */
        return p;
      }
    }
  } else if (lua_istable(L, ud)) {
    if (ud < 0) {
      ud = lua_gettop(L) + 1 + ud;
    }
    // get p from super
    // ... <ud> ...
    // FIXME: OPTIMIZATION store 'super' in registry ?
    lua_pushlstring(L, "super", 5);
    // ... <ud> ... <'super'>
    lua_rawget(L, ud);
    // ... <ud> ... <ud?>
    p = lua_touserdata(L, -1);
    if (p != NULL) {
      if (lua_getmetatable(L, -1)) {  /* does it have a metatable? */
        lua_getfield(L, LUA_REGISTRYINDEX, tname);  /* get correct metatable */
        if (lua_rawequal(L, -1, -2)) {  /* does it have the correct mt? */
          lua_pop(L, 3);  /* remove both metatables and super */
          return p;
        }
        // remove both metatables
        lua_pop(L, 2);
      }
      throw dub::TypeException(L, -1, tname, true);
    }
  }
  throw dub::TypeException(L, ud, tname);
  return NULL;
}

void *dub_checksdata_n(lua_State *L, int ud, const char *tname) throw() {
  void *p = lua_touserdata(L, ud);
  if (p != NULL) {  /* value is a userdata? */
    if (lua_getmetatable(L, ud)) {  /* does it have a metatable? */
      lua_getfield(L, LUA_REGISTRYINDEX, tname);  /* get correct metatable */
      if (lua_rawequal(L, -1, -2)) {  /* does it have the correct mt? */
        lua_pop(L, 2);  /* remove both metatables */
        return p;
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
        if (lua_rawequal(L, -1, -2)) {  /* does it have the correct mt? */
          lua_pop(L, 3);  /* remove both metatables and super */
          return p;
        }
        // remove both metatables
        lua_pop(L, 2);
      }
      luaL_error(L, "%s expected, got %s (using super)", tname, luaL_typename(L, -1));
    }
  }
  luaL_error(L, "%s expected, got %s", tname, luaL_typename(L, ud));
  return NULL;
}

