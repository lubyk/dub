#ifndef NAMESPACE_A_H_
#define NAMESPACE_A_H_

#include "TRect.h"
#include <string>

namespace Nem {

typedef TRect<int> Rect;

/** This class is used to test:
 *   * classes in namespace
 *   * custom __tostring method
 *   * lua_State pseudo-parameter
 *   * custom accessor
 */
class A {
public:
  std::string name;
  
  /** We will attach any Lua value to this by writing a custom
   * accessor (see A.yml).
   */
  void *userdata;

  A(const char *name_ = "")
    : name(name_)
    , userdata(NULL)
  {}

  DubStackSize __tostring(lua_State *L) {
    lua_pushfstring(L, "<B %p ('%s')>", this, name.c_str());
    return 1;
  }
};

} // Nem

#endif // NAMESPACE_A_H_
