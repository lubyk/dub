#ifndef NAMESPACE_B_H_
#define NAMESPACE_B_H_

namespace Nem {

class A;

/** This class is used to test:
 *   * classes in namespace
 *   * nested classes
 *   * custom __tostring method
 *   * lua_State pseudo-parameter
 */
class B {
public:
  int nb_;
  A *a;

  /** Nested public class.
   */
  class C {
    int nb_;
    friend class B;
  public:
    C(int nb)
      : nb_(nb)
    {}

    LuaStackSize __tostring(lua_State *L) {
      lua_pushfstring(L, "<C %p (%i)>", this, nb_);
      return 1;
    }

    int nb() {
      return nb_;
    }
  };

  C *c;

  B(int nb)
    : nb_(nb)
    , a(NULL)
    , c(NULL)
  {}

  B(C *c_)
    : nb_(c_->nb_)
    , a(NULL)
    , c(c_)
  {}

  LuaStackSize __tostring(lua_State *L) {
    lua_pushfstring(L, "<B %p (%i)>", this, nb_);
    return 1;
  }

  C *getC() {
    return c;
  }
};

} // Nem
#endif // NAMESPACE_B_H_

