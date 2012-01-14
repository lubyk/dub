#ifndef MEMORY_NOGC_H_
#define MEMORY_NOGC_H_

/** This class is used to test:
 *   * no gc optimization
 *
 * @dub destroy: 'free'
 */
struct Nogc {
  double x;
  double y;

  Nogc(double x_, double y_)
    : x(x_)
    , y(y_)
    {}

  double surface() {
    return x * y;
  }

  Nogc operator+(const Nogc &v) {
    return Nogc(x + v.x, y + v.y);
  }
};

#endif // MEMORY_NOGC_H_

