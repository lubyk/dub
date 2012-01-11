#ifndef POINTERS_SIZE_H_
#define POINTERS_SIZE_H_

#include "types.h"

/** This class is used to test:
 *   * accessing public members
 *   * return value optimization
 */
struct Size {
  float x;
  float y;
  Size(float tx, float ty)
    : x(tx)
    , y(ty) {}
  float surface() {
    return x * y;
  }
};

#endif // POINTERS_SIZE_H_

