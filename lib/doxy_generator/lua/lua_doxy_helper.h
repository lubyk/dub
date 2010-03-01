
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

/** ======================================== DoxyGeneratorArgPointer */

template<class T>
class DoxyGeneratorArgPointer {
public:
  DoxyGeneratorArgPointer() : data(NULL) {}

  ~DoxyGeneratorArgPointer() {
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


#endif // DOXY_GENERATOR_LIB_DOXY_GENERATOR_INCLUDE_LUA_DOXY_HELPER_H_
