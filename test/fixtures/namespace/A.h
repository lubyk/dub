#ifndef NAMESPACE_A_H_
#define NAMESPACE_A_H_

#include "TRect.h"
#include "B.h"
#include <string>

namespace Nem {

/** When resolving TRect to Rect, we remember the header where this
 * resolution happened.
 */
typedef TRect<int> Rect;

/** This class is used to test:
 *   * classes in namespace
 *   * custom __tostring method
 *   * lua_State pseudo-parameter
 *   * custom accessor
 *   * overwriten methods
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

  LuaStackSize __tostring(lua_State *L) {
    lua_pushfstring(L, "<B %p ('%s')>", this, name.c_str());
    return 1;
  }

  std::string over(A *a) {
    return "A";
  }

  std::string over(B *b) {
    return "B";
  }

};

  /** Nested namespace. Ignored for now.
   */
  namespace SubNem {
    class X {};
  } // SubNem
} // Nem

#endif // NAMESPACE_A_H_
