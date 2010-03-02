
#ifndef DOXY_GENERATOR_LIB_DOXY_GENERATOR_INCLUDE_LUA_DOXY_HELPER_H_
#define DOXY_GENERATOR_LIB_DOXY_GENERATOR_INCLUDE_LUA_DOXY_HELPER_H_

#include <stdlib.h> // malloc

#include "lua.h"
#include "lauxlib.h"

/** ======================================== lua_pushclass          */

/** Push a custom type on the stack.
 * Since the value is passed as a pointer, we assume it has been created
 * using 'new' and Lua can safely call delete when it needs to garbage-
 * -collect it.
 */
template<class T>
void lua_pushclass(lua_State *L, T *ptr, const char *type_name) {
  T **userdata = (T**)lua_newuserdata(L, sizeof(T*));
  *userdata = ptr;

  // the userdata is now on top of the stack

  // set metatable (contains methods)
  luaL_getmetatable(L, type_name);
  lua_setmetatable(L, -2);
}

/** Push a custom type on the stack.
 * Since the value is passed by value, we have to allocate a copy
 * using 'new' so that Lua can keep it.
 */
template<class T>
void lua_pushclass(lua_State *L, T &val, const char *type_name) {
  T *val_ptr = new T(val);
  lua_pushclass<T>(L, val_ptr, type_name);
}

/** ======================================== DubArgPointer */

template<class T>
class DubArgPointer {
public:
  DubArgPointer() : data(NULL) {}

  ~DubArgPointer() {
    if (data) free(data);
  }

  // TODO: we should have a hint on required sizes !
  T *operator()(lua_State *L, int index) {
    if (!lua_istable(L, index)) throw 1;

    size_t size = lua_objlen(L, index);
    if (size == 0) return NULL;

    data = (T*)malloc(size * sizeof(T));
    if (!data) throw 1;

    for(size_t i=0; i < size; ++i) {
      data[i] = get_value_at(L, index, i+1);
    }
  }
private:
  T get_value_at(lua_State *L, int table_index, int index) {
    lua_pushinteger(L, index + 1);
    lua_gettable(L, index);
    T value = luaL_checknumber(L, -1);
    lua_pop(L, 1);
    return value;
  }

  T *data;
};

/** ======================================== is_userdata */

static bool is_userdata(lua_State *L, int index, const char *tname) {
  void *p = lua_touserdata(L, index);
  if (p != NULL) {  /* value is a userdata? */
    if (lua_getmetatable(L, index)) {  /* does it have a metatable? */
      lua_getfield(L, LUA_REGISTRYINDEX, tname);  /* get correct metatable */
      if (lua_rawequal(L, -1, -2)) {  /* does it have the correct mt? */
        lua_pop(L, 2);  /* remove both metatables */
        // type match
        return true;
      }
    }
  }
  // type does not match
  return false;
}

/** ======================================== register_constants */


typedef struct lua_constants_Reg {
  const char *name;
  double constant;
} luaL_Reg;

LUALIB_API void register_constants(lua_State *L, const char *name_space, const lua_constants_Reg *l) {
  if (name_space) {
    int size = libsize(l);
      /* try global variable (and create one if it does not exist) */
      if (luaL_findtable(L, LUA_GLOBALSINDEX, name_space, size) != NULL)
        luaL_error(L, "name conflict for module " LUA_QS, name_space);
      /* found name_space in global index */
    }
  }
  for (; l->name; l++) {
    /* push each constant into the name_space */
    lua_pushnumber(L, l->constant);
    lua_setfield(L, l->name);
  }
  /* pop name_space */
  lua_pop(L, 1);
}

#endif // DOXY_GENERATOR_LIB_DOXY_GENERATOR_INCLUDE_LUA_DOXY_HELPER_H_
