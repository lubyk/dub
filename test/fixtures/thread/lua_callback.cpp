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
  
