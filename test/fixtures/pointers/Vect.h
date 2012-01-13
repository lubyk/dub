#ifndef POINTERS_VECT_H_
#define POINTERS_VECT_H_

/** This class is used to test:
 *   * accessing public members
 *   * return value optimization
 *   * operator overloading
 */
struct Vect {
  double x;
  double y;
  Vect(double tx, double ty)
    : x(tx)
    , y(ty) {
      // TO TEST return value optimization
      //printf("     Vect(%f,%f)\n", x, y);
    }
  Vect(const Vect &sz)
    : x(sz.x)
    , y(sz.y) {
    // TO TEST return value optimization
    //printf("copy Vect(%f,%f)\n",x, y);
  }

  double surface() const {
    return x * y;
  }

  // operator overloading

  Vect operator+(const Vect &sz) {
    return Vect(x + sz.x, y + sz.y);
  }

  Vect operator-(const Vect &sz) {
    return Vect(x - sz.x, y - sz.y);
  }

  /** Unary minus.
   */
  //Vect operator-() {
  //  return Vect(-x, -y);
  //}

  Vect operator*(double d) {
    return Vect(d*x, d*y);
  }

  Vect operator/(double d) {
    return Vect(x/d, y/d);
  }

  bool operator<(const Vect &s) {
    return surface() < s.surface();
  }

  bool operator<=(const Vect &s) {
    return surface() <= s.surface();
  }

  bool operator==(const Vect &s) {
    return s.x == x && s.y == y;
  }
};

#endif // POINTERS_VECT_H_

