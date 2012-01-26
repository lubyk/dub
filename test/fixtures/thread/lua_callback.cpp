#include "Callback.h"

void Callback::call(const std::string &msg) {
  if (!dub_pushcallback("callback")) return;
  // <func> <self>
  lua_pushlstring(dub_L, msg.data(), msg.length());
  // <func> <self> <msg>
  dub_call(2, 0);
}
  
double Callback::getValue(const std::string &key) {
  lua_State *L = dub_L;
  double d = 0;
  dub_pushvalue(key.c_str());
  if (lua_isnumber(L, -1)) {
    // ... <nb>
    d = lua_tonumber(L, -1);
  }
  lua_pop(L, 1);
  return d;
}

int Callback::destroy_count = 0;
