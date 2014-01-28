#ifndef NAMESPACE_NEM_H_
#define NAMESPACE_NEM_H_

#include "B.h"
#include <string>

namespace Nem {

/** Function inside the namespace.
 */
double addTwo(const B &a, const B &b) {
  return a.nb_ + b.nb_;
}

/** Global function with custom bindings.
 */
LuaStackSize customGlobal(float a, float b);
} // Nem

/** Function outside the namespace.
 */
double addTwoOut(const Nem::B &a, const Nem::B &b) {
  return a.nb_ + b.nb_;
}

/** Function outside the namespace with custom bindings. The custom bindings
 * for global methods must live in [name of lib].yml
 */
LuaStackSize customGlobalOut(float a, float b);


#endif // NAMESPACE_NEM_H_

