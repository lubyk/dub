#ifndef MEMORY_WITHGC_H_
#define MEMORY_WITHGC_H_

/** This class is used to compare execution with a __gc method
 * or without (Nogc version).
 *   * no gc optimization (this one has a __gc method)
 *
 */
struct Withgc {
  double x;
  double y;

  Withgc(double x_, double y_)
    : x(x_)
    , y(y_)
    {}

  double surface() {
    return x * y;
  }

  Withgc operator+(const Withgc &v) {
    return Withgc(x + v.x, y + v.y);
  }
};

#endif // MEMORY_WITHGC_H_


