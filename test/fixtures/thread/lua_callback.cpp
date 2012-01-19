#include "Callback.h"

void Callback::call(float value) {
  lua_State *L = lua_;
  if (!pushLuaCallback("callback")) return;
  // <func> <self>
  lua_pushnumber(L, value);
  // <func> <self> <number>
  int status = lua_pcall(L, 3, 0, 0);
  if (status) {
    fprintf(stderr, "Error in 'callback': %s\n", lua_tostring(L, -1));
  }
}
  
double Callback::getValue(const std::string &key) {
  lua_State *L = lua_;
  if (pushLuaValue(key.c_str())) {
    if (lua_isnumber(L, -1)) {
      // ... <nb>
      double d = lua_tonumber(L, -1);
      lua_pop(L, 1);
      // ...
      return d;
    }
  }
  return 0;
}
