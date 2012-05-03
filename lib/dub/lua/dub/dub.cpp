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

#include <stdlib.h>  // malloc
#include <string.h>  // strlen strcmp
#include <assert.h>  // assert

#define DUB_EXCEPTION_BUFFER_SIZE 256  
#define TYPE_EXCEPTION_MSG "expected %s, found %s"
#define TYPE_EXCEPTION_SMSG "expected %s, found %s (using super)"
#define DEAD_EXCEPTION_MSG  "using deleted %s"
#define DUB_MAX_IN_SHIFT 4294967296
#define DUB_INIT_CODE "local class = %s.%s\nif class.new then\nsetmetatable(class, {\n __call = function(lib, ...)\n   return lib.new(...)\n end,\n})\nend\n"
#define DUB_INIT_ERR "[string \"Dub init code\"]"
#define DUB_ERRFUNC "local self = self\nlocal print = print\nreturn function(...)\nlocal err = self.error\nif err then\nerr(self,...)\nelse\nprint(...)\nend\nend"

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
// =============================================== dub::Object
// ======================================================================
void Object::pushobject(lua_State *L, void *ptr, const char *tname, bool gc) {
  DubUserdata *udata = (DubUserdata*)lua_newuserdata(L, sizeof(DubUserdata));
  udata->ptr = ptr;
  udata->gc  = gc;
  if (dub_userdata_) {
    // We already have a userdata. Push a new userdata (copy to this item,
    // should never gc).
    assert(!gc);
    udata->gc = false;
  } else {
    // First initialization.
    dub_userdata_ = udata;
  }
  // the userdata is now on top of the stack

  // set metatable (contains methods)
  lua_getfield(L, LUA_REGISTRYINDEX, tname);
  lua_setmetatable(L, -2);
  // <udata>
}

// ======================================================================
// =============================================== dub::Thread
// ======================================================================
void Thread::pushobject(lua_State *L, void *ptr, const char *tname, bool gc) {
  if (dub_L) {
    if (!strcmp(tname, dub_typename_)) {
      // Pushing same type again.

      // We do not care about gc being false here since we share the same userdata
      // object.
      // push self
      lua_pushvalue(dub_L, 1);
      lua_xmove(dub_L, L, 1);
      // <self>
    } else {
      // Type cast.
      assert(!gc);
      dub_pushudata(L, ptr, tname, gc);
      // <udata>
    }
    return;
  }

  // initialization

  //--=============================================== setup super
  lua_newtable(L);
  // <self>
  Object::pushobject(L, ptr, tname, gc);
  // <self> <udata>
  dub_typename_ = tname;
  lua_pushlstring(L, "super", 5);
  // <self> <udata> 'super'
  lua_pushvalue(L, -2);
  // <self> <udata> 'super' <udata>
  lua_rawset(L, -4); // <self>.super = <udata>
  // <self> <udata>

  //--=============================================== setup metatable on self
  lua_getfield(L, LUA_REGISTRYINDEX, tname);
  // <self> <udata> <mt>
  lua_setmetatable(L, -3); // setmetatable(self, mt)
  // <self> <udata>
  
  //--=============================================== setup lua thread
  // Create env table
  lua_newtable(L);
  // <self> <udata> <env>
  lua_pushvalue(L, -1);
  // <self> <udata> <env> <env>
  if (!lua_setfenv(L, -3)) { // setfenv(udata, env)
    // <self> <udata> <env>
    lua_pop(L, 3);
    // 
    throw Exception("Could not set userdata env on '%s'.", lua_typename(L, lua_type(L, -3)));
  }

  // <self> <udata> <env>
  dub_L = lua_newthread(L);
  // <self> <udata> <env> <thread>

  // Store the thread in the userdata environment table so it is not 
  // garbage collected too soon.
  luaL_ref(L, -2);
  // <self> <udata> <env>

  //--=============================================== prepare error function
  lua_pushlstring(L, "self", 4);
  lua_pushvalue(L, -4);
  // <self> <udata> <env>.self = <self>
  lua_rawset(L, -3);
  // <self> <udata> <env>
  lua_pushlstring(L, "print", 5);
  lua_getfield(L, LUA_GLOBALSINDEX, "print");
  lua_rawset(L, -3);
  // <self> <udata> <env>.print = <print>
  // <self> <udata> <env>
  int error = luaL_loadbuffer(L, DUB_ERRFUNC, strlen(DUB_ERRFUNC), "Dub error function");
  if (error) {
    throw Exception("Error evaluating error function code (%s).", lua_tostring(L, -1));
  }
  
  // <self> <udata> <env> <errloader>
  lua_pushvalue(L, -2);
  // <self> <udata> <env> <errloader> <env>
  if (!lua_setfenv(L, -2)) { // setfenv(errloader, env)
    // <self> <udata> <env> <errloader>
    lua_pop(L, 4);
    // 
    throw Exception("Could not set error function env on '%s'.", lua_typename(L, lua_type(L, -3)));
  }
  // <self> <udata> <env> <errloader>
  error = lua_pcall(L, 0, 1, 0);
  if (error) {
    throw Exception("Error executing error function code (%s).", lua_tostring(L, -1));
  }
  
  // <self> <udata> <env> <errfunc>

  // <self> <udata> <env> <errfunc>
  lua_remove(L, -2);
  lua_remove(L, -2);
  // <self> <errfunc>

  //--=============================================== prepare thread stack
  // Transfer a copy of <self> to thread stack
  lua_pushvalue(L, -2);
  // <self> <errfunc> <self>
  lua_pushvalue(L, -2);
  // <self> <errfunc> <self> <errfunc>
  lua_xmove(L, dub_L, 2);
  lua_pop(L, 1);
  // dub_L: <self> <errfunc>
  // L:     <self>
}

bool Thread::dub_pushcallback(const char *name) const {
  lua_State *L = const_cast<lua_State *>(dub_L);
  lua_getfield(L, 1, name);
  if (lua_isnil(L, -1)) {
    lua_pop(L, 1);
    return false;
  } else {
    lua_pushvalue(L, 1);
    // ... <func> <self>
    return true;
  }
}

void Thread::dub_pushvalue(const char *name) const {
  lua_State *L = const_cast<lua_State *>(dub_L);
  lua_getfield(L, 1, name);
}

bool Thread::dub_call(int param_count, int retval_count) const {
  lua_State *L = const_cast<lua_State *>(dub_L);
  int status = lua_pcall(L, param_count, retval_count, 2);
  if (status) {
    if (status == LUA_ERRRUN) {
      // failure properly handled by the error handler
    } else if (status == LUA_ERRMEM) {
      // memory allocation failure
      fprintf(stderr, "Memory allocation failure (%s).\n", lua_tostring(dub_L, -1));
    } else {
    // error in error handler
      fprintf(stderr, "Error in error handler (%s).\n", lua_tostring(dub_L, -1));
    }
    lua_pop(dub_L, 1);
    return false;
  }
  return true;
}




// ======================================================================
// =============================================== dub_error
// ======================================================================
// This calls lua_Error after preparing the error message with line
// and number.
int dub_error(lua_State *L) {
  // ... <msg>
  luaL_where(L, 1);
  // ... <msg> <where>
  // Does it match 'Dub init code' ?
  const char *w = lua_tostring(L, -1);
  if (!strncmp(w, DUB_INIT_ERR, strlen(DUB_INIT_ERR))) {
    // error in ctor, show calling place, not dub init code.
    lua_pop(L, 1);
    luaL_where(L, 2);
  }
  // ... <msg> <where>
  lua_pushvalue(L, -2);
  // ... <msg> <where> <msg>
  lua_remove(L, -3);
  // ... <where> <msg>
  lua_concat(L, 2);
  return lua_error(L);
}




// ======================================================================
// =============================================== dub_protect
// ======================================================================

// TODO: Can we make this faster ?
inline void push_own_env(lua_State *L, int ud) {
  lua_getfenv(L, ud);
  // ... <udata> ... <env>
  lua_pushstring(L, ".");
  // ... <udata> ... <env> "."
  lua_rawget(L, -2); // <env>["."]
  // ... <udata> ... <env> <??>
  if (!lua_rawequal(L, -1, ud)) {
    // ... <udata> ... <env> <nil>
    // does not have it's own env table
    lua_pop(L, 2);
    // ... <udata> ... 
    // Create env table
    lua_newtable(L);
    // ... <udata> ... <env>
    lua_pushstring(L, ".");
    // ... <udata> ... <env> "."
    lua_pushvalue(L, ud);
    // ... <udata> ... <env> "." <udata>
    lua_rawset(L, -3); // env["."] = udata
    // ... <udata> ... <env>
    lua_pushvalue(L, -1);
    // ... <udata> ... <env> <env>
    if (!lua_setfenv(L, ud)) {
      luaL_error(L, "Could not set userdata env on '%s'.", lua_typename(L, lua_type(L, ud)));
    }
    // ... <udata> ... <env>
  } else {
    // ... <udata> ... <env> <self>
    // has its own env table
    lua_pop(L, 1);
    // ... <udata> ... <env>
  }                            
}

void dub_protect(lua_State *L, int owner, int original, const char *key) {
  // Point to original to avoid original gc before owner.
  push_own_env(L, owner);
  // ... <env>
  lua_pushvalue(L, original);
  // ... <env> <original>
  lua_setfield(L, -2, key); // env["key"] = <original>
  // ... <env>
  lua_pop(L, 1);
  // ...
}

// ======================================================================
// =============================================== dub_pushudata
// ======================================================================

void dub_pushudata(lua_State *L, void *ptr, const char *tname, bool gc) {
  // If anything is changed here, it must be reflected in dub::Object::pushobject.
  DubUserdata *userdata = (DubUserdata*)lua_newuserdata(L, sizeof(DubUserdata));
  userdata->ptr = ptr;
  if (!gc) {
    // Point to original (self) to avoid original gc.
    dub_protect(L, lua_gettop(L), 1, "_");
  }

  userdata->gc = gc;

  // the userdata is now on top of the stack
  luaL_getmetatable(L, tname);
  if (lua_isnil(L, -1)) {
    lua_pop(L, 1);
    // create empty metatable on the fly for opaque types.
    luaL_newmetatable(L, tname);
  }
  // <udata> <mt>

  // set metatable (contains methods)
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

lua_Integer dub_checkint(lua_State *L, int narg) throw(TypeException) {
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

void **dub_checkudata(lua_State *L, int ud, const char *tname, bool keep_mt) throw(dub::Exception) {
  void **p = (void**)lua_touserdata(L, ud);
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
        if (!*p) {
          throw dub::Exception(DEAD_EXCEPTION_MSG, tname);
        }
        return p;
      }
    }
  }
  throw TypeException(L, ud, tname); /* else error */
  return NULL;  /* to avoid warnings */
}


static inline void **dub_cast_ud(lua_State *L, int ud, const char *tname) {
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
    void **p = (void**)lua_touserdata(L, -1);
    if (p != NULL) {
      // done
      return p;
    }
  }

  // ... <ud> ... <mt> nil
  // Does not change stack size (only last element).
  return NULL;
}

static inline void **getsdata(lua_State *L, int ud, const char *tname, bool keep_mt) throw() {
  void **p = (void**)lua_touserdata(L, ud);
  if (p != NULL) {  /* value is a userdata? */
    if (lua_getmetatable(L, ud)) {  /* does it have a metatable? */
      lua_getfield(L, LUA_REGISTRYINDEX, tname);  /* get correct metatable */
      if (lua_rawequal(L, -1, -2)) {
        // same (correct) metatable
        lua_pop(L, keep_mt ? 1 : 2);
      } else {
        p = dub_cast_ud(L, ud, tname);
        // ... <ud> ... <ud> <mt/nil>
        if (p && keep_mt) {
          lua_remove(L, -2);
        } else {
          lua_pop(L, 2);
        }
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
    // ... <ud> ... 'super'
    lua_rawget(L, ud);
    // ... <ud> ... <ud?>
    p = (void**)lua_touserdata(L, -1);
    if (p != NULL) {
      // ... <ud> ... <ud>
      if (lua_getmetatable(L, -1)) {  /* does it have a metatable? */
        // ... <ud> ... <ud> <mt>
        lua_getfield(L, LUA_REGISTRYINDEX, tname);  /* get correct metatable */
        // ... <ud> ... <ud> <mt> <mt>
        if (lua_rawequal(L, -1, -2)) {
          // same (correct) metatable
          lua_remove(L, -3);
          // ... <ud> ... <mt> <mt>
          lua_pop(L, keep_mt ? 1 : 2);
        } else {
          lua_remove(L, -3);
          // ... <ud> ... <mt> <mt>
          p = dub_cast_ud(L, ud, tname);
          // ... <ud> ... <ud> <mt/nil>
          if (p && keep_mt) {
            lua_remove(L, -2);
            // ... <ud> ... <mt>
          } else {
            lua_pop(L, 2);
            // ... <ud> ...
          }
        }
      } else {
        lua_pop(L, 1);
        // ... <ud> ...
      }
    } else {
      lua_pop(L, 1);
      // ... <ud> ...
    }
  }
  return p;
}

void **dub_checksdata_n(lua_State *L, int ud, const char *tname, bool keep_mt) {
  void **p = getsdata(L, ud, tname, keep_mt);
  if (!p) {
    luaL_error(L, TYPE_EXCEPTION_MSG, tname, luaL_typename(L, ud));
  } else if (!*p) {
    // dead object
    luaL_error(L, DEAD_EXCEPTION_MSG, tname);
  }
  return p;
}

void **dub_issdata(lua_State *L, int ud, const char *tname, int type) {
  if (type == LUA_TUSERDATA || type == LUA_TTABLE) {
    void **p = getsdata(L, ud, tname, false);
    if (!p) {
      return NULL;
    } else if (!*p) {
      // dead object
      throw dub::Exception(DEAD_EXCEPTION_MSG, tname);
    } else {
      return p;
    }
  } else {
    return NULL;
  }
}

void **dub_checksdata(lua_State *L, int ud, const char *tname, bool keep_mt) throw(dub::Exception) {
  void **p = getsdata(L, ud, tname, keep_mt);
  if (!p) {
    throw dub::TypeException(L, ud, tname);
  } else if (!*p) {
    // dead object
    throw dub::Exception(DEAD_EXCEPTION_MSG, tname);
  }
  return p;
}

void **dub_checksdata_d(lua_State *L, int ud, const char *tname) throw(dub::Exception) {
  void **p = getsdata(L, ud, tname, false);
  if (!p) {
    throw dub::TypeException(L, ud, tname);
  }
  // do not check for dead objects
  return p;
}

// ======================================================================
// =============================================== dub_register
// ======================================================================

void dub_register(lua_State *L, const char *libname, const char *reg_name, const char *type_name) {
  type_name = type_name ? type_name : reg_name;
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
    lua_pushfstring(L, "%s.%s", libname, type_name);
    // <mt>."type" = "libname.type_name"
  } else {
    lua_pushstring(L, type_name);
    // <mt>."type" = "type_name"
  }
  lua_settable(L, -3);


  // <mt>
  // get or create Foo.Bar.Baz table.
  const char *tbl_err = luaL_findtable(L, LUA_GLOBALSINDEX, libname, 1);
  if (tbl_err) {
    fprintf(stderr, "Could load '%s' into '%s' ('%s' is not a table).\n", reg_name, libname, tbl_err);
    return; // mt table not registered and not properly configured
  }
      
  if (lua_isnil(L, -1)) {
    // no global table called libname
    lua_pop(L, 1);
    // <mt> <lib>
    lua_pushvalue(L, -1);
    // <mt> <lib> <lib>
    // _G.libname = <lib>
    lua_setglobal(L, libname);
    // <mt> <lib>
  }

  // <mt> <lib>
  lua_pushstring(L, reg_name);
  // <mt> <lib> "Foobar"
  lua_pushvalue(L, -3);
  // <mt> <lib>.Foobar = <mt>
  lua_settable(L, -3);
  // <mt> <lib>
  lua_pop(L, 1);
  // <mt>

  // Setup the __call meta-table with an upvalue
  size_t sz = strlen(DUB_INIT_CODE) + strlen(reg_name) + strlen(libname) + 2;
  char *lua_code = (char*)malloc(sizeof(char) * sz);
  snprintf(lua_code, sz, DUB_INIT_CODE, libname, reg_name);
  //printf("%s\n", lua_code);
  /*
  local class = lib.Foobar
  -- new can be nil for abstract types
  if class.new then
    setmetatable(class, {
      __call = function(lib, ...)
        -- We could keep lib.new in an upvalue but this
        -- prevents rewriting class.new in Lua which is
        -- very useful.
        return lib.new(...)
      end,
    })
  end
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

// This is called whenever we ask for obj:deleted() in Lua
int dub_isDeleted(lua_State *L) {
  void **p = (void**)lua_touserdata(L, 1);
  if (p == NULL && lua_istable(L, 1)) {
    // get p from super
    // <ud>
    // TODO: optimize by storing key in registry ?
    lua_pushlstring(L, "super", 5);
    // <ud> 'super'
    lua_rawget(L, 1);
    // <ud> <ud?>
    p = (void**)lua_touserdata(L, 2);
    lua_pop(L, 1);
    // <ud>
  }
  lua_pushboolean(L, p && !*p);
  return 1;
}
