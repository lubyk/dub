#ifndef POINTERS_SIZE_H_
#define POINTERS_SIZE_H_

/** This class is used to test:
 *   * accessing public members
 *   * return value optimization
 */
struct Size {
  double x;
  double y;
  Size(double tx, double ty)
    : x(tx)
    , y(ty) {}
  double surface() {
    return x * y;
  }
};

#endif // POINTERS_SIZE_H_

