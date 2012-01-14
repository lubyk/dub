#ifndef TEMPLATE_TVECT_H_
#define TEMPLATE_TVECT_H_

/** This class is used to test:
 *   * template resolution
 *   * = Should behave like the pointers/TVect class.
 */
template<class T>
struct TVect {
  T x;
  T y;
  TVect(T tx, T ty)
    : x(tx)
    , y(ty) {
      // TO TEST return value optimization
      //printf("     TVect(%f,%f)\n", x, y);
    }
  TVect(const TVect &sz)
    : x(sz.x)
    , y(sz.y) {
    // TO TEST return value optimization
    //printf("copy TVect(%f,%f)\n",x, y);
  }

  T surface() const {
    return x * y;
  }

  TVect operator+(const TVect &sz) {
    return TVect(x + sz.x, y + sz.y);
  }

  T addToX(T a) {
    return x + a;
  }

  static T addTwo(T a, T b) {
    return a + b;
  }

};

#endif // TEMPLATE_TVECT_H_


