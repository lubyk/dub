
#ifndef DOXY_GENERATOR_LIB_DOXY_GENERATOR_INCLUDE_LUA_ARG_POINTER_H_
#define DOXY_GENERATOR_LIB_DOXY_GENERATOR_INCLUDE_LUA_ARG_POINTER_H_

template<class T>
class DoxyGeneratorArgPointer {
public:
  DoxyGeneratorArgPointer() : data(NULL) {}

  ~DoxyGeneratorArgPointer() {
    if (data) free(data);
  }

  // TODO: we should have a hint on required sizes !
  T *operator()(lua_State *L, int index) {
    if (!lua_istable(L, index)) throw std::exception;

    size_t size = lua_objlen(L, index);
    if (size == 0) return NULL;

    data = (T*)malloc(size * sizeof(T));
    if (!data) throw std::exception;

    for(size_t i=0; i < size; ++i) {
      data[i] = get_value_at(L, index, i+1);
    }
  }
private:
  T get_value_at(lua_State *L, int table_index, int index) {
    lua_pushinteger(L, i+1);
    lua_gettable(L, index);
    T value = luaL_checknumber(L, -1);
    lua_pop(L, 1);
    return value;
  }

  T *data;
};


#endif // DOXY_GENERATOR_LIB_INCLUDE_LUA_ARG_POINTER_H_