
#ifndef DOXY_GENERATOR_LIB_DOXY_GENERATOR_INCLUDE_LUA_DOXY_HELPER_H_
#define DOXY_GENERATOR_LIB_DOXY_GENERATOR_INCLUDE_LUA_DOXY_HELPER_H_

#include <stdlib.h> // malloc

#ifdef __cplusplus
extern "C" {
#endif
// We need C linkage because lua lib is compiled as C code
#include "lua.h"
#include "lauxlib.h"

#ifdef __cplusplus
}
#endif
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

/** Push a custom type on the stack and give it the pointer to the userdata.
 * Passing the userdata enables early deletion from some other thread (GUI)
 * that safely invalidates the userdatum.
 */
template<class T>
void lua_pushclass2(lua_State *L, T *ptr, const char *type_name) {
  T **userdata = (T**)lua_newuserdata(L, sizeof(T*));
  *userdata = ptr;

  // store pointer in class so that it can set it to NULL on destroy with
  // *userdata = NULL
  ptr->set_userdata_ptr(userdata);

  // the userdata is now on top of the stack

  // set metatable (contains methods)
  luaL_getmetatable(L, type_name);
  lua_setmetatable(L, -2);
}

/** Classes that can be deleted out of Lua should inherit from this class or
 * implement 'set_userdata_ptr' (and manage the userdata_ptr...)
 */
class DeletableOutOfLua {
  void **userdata_ptr_;
public:
  DeletableOutOfLua()
   : userdata_ptr_(NULL) {}
  virtual ~DeletableOutOfLua() {
    if (userdata_ptr_) {
      *userdata_ptr_ = NULL;
      userdata_ptr_ = NULL;
    }
  }

  virtual void dub_destroy() {
    dub_cleanup();
    delete this;
  }

  /** @internal
   */
  void set_userdata_ptr(void **ptr) {
    userdata_ptr_ = ptr;
  }

protected:
  /** MUST be called from the custom destructor.
   */
  void dub_cleanup() {
    // so that it is not changed in ~DeletableOutOfLua
    userdata_ptr_ = NULL;
  }
};

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

/** This class is a helper to provide pointer to data from
 * Lua to C (but maybe it's not a good idea).
 */
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
    return data;
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

inline bool is_userdata(lua_State *L, int index, const char *tname) {
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
} lua_constants_Reg;

inline int libsize (const lua_constants_Reg *l) {
  int size = 0;
  for (; l->name; l++) size++;
  return size;
}

inline void register_constants(lua_State *L, const char *name_space, const lua_constants_Reg *l) {
  if (name_space) {
    /* compute size hint for new table. */
    int size = libsize(l);

    /* try global variable (and create one if it does not exist) */
    if (luaL_findtable(L, LUA_GLOBALSINDEX, name_space, size) != NULL)
      luaL_error(L, "name conflict for module " LUA_QS, name_space);

    /* found name_space in global index ==> stack -1 */
  }
  for (; l->name; l++) {
    /* push each constant into the name_space (stack position = -1)*/
    lua_pushnumber(L, l->constant);
    lua_setfield(L, -2, l->name);
  }
  /* pop name_space */
  lua_pop(L, 1);
}

// The metatable lives in libname.ClassName_
inline void register_mt(lua_State *L, const char *libname, const char *class_name) {
  size_t len = strlen(class_name) + 2;
  char *buffer = (char*)malloc(sizeof(char) * len);
  snprintf(buffer, len, "%s_", class_name);

  // meta-table should be on top
  // <mt>
  lua_getglobal(L, libname);
  // <mt> <lib>
  lua_pushstring(L, buffer);
  // <mt> <lib> "Foobar_"
  lua_pushvalue(L, -3);
  // <mt> <lib> "Foobar" <mt>
  lua_settable(L, -3);
  // <mt> <lib>
  lua_pop(L, 1);
  // <mt>
}
#endif // DOXY_GENERATOR_LIB_DOXY_GENERATOR_INCLUDE_LUA_DOXY_HELPER_H_
