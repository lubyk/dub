#ifndef SIMPLE_INCLUDE_MAP_H_
#define SIMPLE_INCLUDE_MAP_H_

#include <map>
#include <string>

/** This class is used to test
 *   * custom get/set suffix without public attributes.
 * 
 * @dub ignore: getVal, setVal
 */
class Map {
  typedef std::string Str;
  std::map<Str, Str> map_;
  typedef std::pair<Str, Str> Pair;
public:
  // Should create default ctor

  bool getVal(const char *key, std::string *lhs) {
    if (map_.count(key) > 0) {
      *lhs = map_[key];
      return true;
    } else {
      return false;
    }
  };

  void setVal(const char *key, const char *value) {
    map_.insert(Pair(key, value));
  }
  
  /** Test methods with lua_State parameter and LuaStackSize
   * return value.
   */
  LuaStackSize map(lua_State *L) {
    lua_newtable(L);
    std::map<std::string, std::string>::iterator it;
    for (it = map_.begin(); it != map_.end(); ++it) {
      lua_pushlstring(L, it->first.data(), it->first.length());
      lua_pushlstring(L, it->second.data(), it->second.length());
      // <res> 'key' 'value'
      lua_rawset(L, -3);
    }
    return 1;
  }
};

/** Should inherit pseudo accessor 'map'.
 */
class SubMap : public Map {
};
#endif // SIMPLE_INCLUDE_MAP_H_

