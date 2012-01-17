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
#ifndef DUB_BINDING_GENERATOR_DUB_H_
#define DUB_BINDING_GENERATOR_DUB_H_

#ifndef DUB_ASSERT_KEY
#define DUB_ASSERT_KEY(k, m) strcmp(k, m)
// Use this to avoid the overhead of strcmp in get/set of public attributes.
// if you avoid strcmp, bad keys can map to any other key.
//#define DUB_ASSERT_KEY(k, m) false
#endif
#define KEY_EXCEPTION_MSG "invalid key '%s'"

typedef int DubStackSize;

#ifdef __cplusplus
extern "C" {
#endif
// We need C linkage because lua lib is compiled as C code
#include "dub/lua.h"
#include "dub/lauxlib.h"
#ifdef __cplusplus
}
#endif

#include <stdlib.h>  // malloc
#include <string>    // std::string for Exception
#include <exception> // std::exception

// Rename macro
#define DubObject dub::LuaObject
#define DubThread dub::LuaThread
// ======================================================================
// =============================================== dub::Exception
// ======================================================================
namespace dub {

/** All exceptions raised by dub::check.. are instances of this class. All
 * exceptions deriving from std::exception have their message displayed
 * in Lua (through lua_error).
 */
class Exception : public std::exception {
  std::string message_;
public:
  explicit Exception(const char *format, ...);
  ~Exception() throw();
  const char* what() const throw();
};

class TypeException : public Exception {
public:
  explicit TypeException(lua_State *L, int narg, const char *type, bool is_super = false);
};

} // dub

// ======================================================================
// =============================================== dub_pushclass
// ======================================================================

struct DubUserdata {
  void *ptr;
  bool gc;
};

/** Push a custom type on the stack.
 * Since the value is passed as a pointer, we assume it has been created
 * using 'new' and Lua can safely call delete when it needs to garbage-
 * -collect it.
 */
void dub_pushudata(lua_State *L, void *ptr, const char *type_name, bool gc = true);

template<class T>
struct DubFullUserdata {
  T *ptr;
  T obj;
};

template<class T>
void dub_pushfulldata(lua_State *L, const T &obj, const char *type_name) {
  DubFullUserdata<T> *copy = (DubFullUserdata<T>*)lua_newuserdata(L, sizeof(DubFullUserdata<T>));
  copy->obj = obj;
  // now **copy gives back the object.
  copy->ptr = &copy->obj;

  // the userdata is now on top of the stack

  // set metatable (contains methods)
  luaL_getmetatable(L, type_name);
  lua_setmetatable(L, -2);
}

template<class T>
void dub_pushclass(lua_State *L, const T &obj, const char *type_name) {
  T *copy = new T(obj);
  dub_pushudata(L, (void*)copy, type_name);
}

// ======================================================================
// =============================================== dub_pushclass2
// ======================================================================

/** Push a custom type on the stack and give it the pointer to the userdata.
 * Passing the userdata enables early deletion from C++ that safely
 * invalidates the userdatum by calling 
 */
template<class T>
void dub_pushclass2(lua_State *L, T *ptr, const char *type_name) {
  T **userdata = (T**)lua_newuserdata(L, sizeof(T*));
  *userdata = ptr;

  // Store pointer in class so that it can set it to NULL on destroy with
  // *userdata = NULL
  ptr->luaInit((void**)userdata);
  // <udata>
  luaL_getmetatable(L, type_name);
  // <udata> <mt>
  lua_setmetatable(L, -2);
  // <udata>
}

// ======================================================================
// =============================================== constants
// ======================================================================

typedef struct dub_const_Reg {
  const char *name;
  double value;
} dub_const_Reg;

// register constants in the table at the top
void dub_register_const(lua_State *L, const dub_const_Reg *l);

// ======================================================================
// =============================================== dub_check ...
// ======================================================================

// These provide the same funcionality as their equivalent luaL_check... but they
// throw std::exception which can be caught (eventually to call lua_error).
lua_Number dub_checknumber(lua_State *L, int narg) throw(dub::TypeException);
lua_Integer dub_checkint(lua_State *L, int narg) throw(dub::TypeException);
const char *dub_checklstring(lua_State *L, int narg, size_t *len) throw(dub::TypeException);
lua_Integer dub_checkinteger(lua_State *L, int narg) throw(dub::TypeException);
void *dub_checkudata(lua_State *L, int ud, const char *tname, bool keep_mt = false) throw(dub::TypeException);

// Super aware userdata calls (finds userdata inside provided table with table.super).
void *dub_checksdata(lua_State *L, int ud, const char *tname, bool keep_mt = false) throw(dub::TypeException);
// Return true if the type is correct. Used to resolve overloaded functions when there
// is no other alternative (arg count, native types).
bool dub_issdata(lua_State *L, int ud, const char *tname, int type);
// Does not throw exceptions. This method behaves exactly like luaL_checkudata but searches
// for table.super before calling lua_error.
void *dub_checksdata_n(lua_State *L, int ud, const char *tname, bool keep_mt = false) throw();

#define dub_checkstring(L,n) (dub_checklstring(L, (n), NULL))
#define dub_checkint(L,n) ((int)dub_checkinteger(L, (n)))
#define luaL_checkboolean(L,n) (lua_toboolean(L,n))
#define dub_checkboolean(L,n) (lua_toboolean(L,n))

// ======================================================================
// =============================================== dub_register
// ======================================================================
void dub_register(lua_State *L, const char *libname, const char *class_name);

// ======================================================================
// =============================================== dub_hash
// ======================================================================
// sdbm function: taken from http://www.cse.yorku.ca/~oz/hash.html
// This version is slightly adapted to cope with different
// hash sizes (and to be easy to write in Lua).
int dub_hash(const char *str, int sz);
  
#endif // DUB_BINDING_GENERATOR_DUB_H_
