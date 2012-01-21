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

} // Nem

/** Function outside the namespace.
 */
double addTwoOut(const Nem::B &a, const Nem::B &b) {
  return a.nb_ + b.nb_;
}

#endif // NAMESPACE_NEM_H_

