#ifndef POINTERS_SIZE_H_
#define POINTERS_SIZE_H_

/** This class is used to test:
 *   * accessing public members
 *   * return value optimization
 *   * operator overloading
 */
struct Size {
  double x;
  double y;
  Size(double tx, double ty)
    : x(tx)
    , y(ty) {
      // TO TEST return value optimization
      //printf("     Size(%f,%f)\n", x, y);
    }
  Size(const Size &sz)
    : x(sz.x)
    , y(sz.y) {
    // TO TEST return value optimization
    //printf("copy Size(%f,%f)\n",x, y);
  }

  double surface() const {
    return x * y;
  }

  // operator overloading

  Size operator+(const Size &sz) {
    return Size(x + sz.x, y + sz.y);
  }

  Size operator-(const Size &sz) {
    return Size(x - sz.x, y - sz.y);
  }

  /** Unary minus.
   */
  //Size operator-() {
  //  return Size(-x, -y);
  //}

  Size operator*(double d) {
    return Size(d*x, d*y);
  }

  Size operator/(double d) {
    return Size(x/d, y/d);
  }

  bool operator<(const Size &s) {
    return surface() < s.surface();
  }

  bool operator<=(const Size &s) {
    return surface() <= s.surface();
  }

  bool operator==(const Size &s) {
    return s.x == x && s.y == y;
  }
};

#endif // POINTERS_SIZE_H_

