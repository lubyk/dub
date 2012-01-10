#ifndef POINTERS_SIZE_H_
#define POINTERS_SIZE_H_

#include "types.h"

/** This class is used to test:
 *   * accessing public members
 */
struct Size {
  float x;
  float y;
  Size(float tx, float ty)
    : x(tx)
    , y(ty) {}
};

#endif // POINTERS_SIZE_H_

