#ifndef POINTERS_VECT_H_
#define POINTERS_VECT_H_

#include <cstring> // size_t

/** This class is used to test:
 *   * accessing public members
 *   * return value optimization
 *   * basic memory leakage
 *   * operator overloading
 */
struct Vect {
  double x;
  double y;

  // static member access
  static size_t create_count;
  static size_t copy_count;
  static size_t destroy_count;

  Vect(double tx, double ty)
    : x(tx)
    , y(ty) {
    // to test return value optimization.
    // and memory leakage.
    ++create_count;
  }
  Vect(const Vect &v)
    : x(v.x)
    , y(v.y) {
    // To test return value optimization.
    // and memory leakage.
    ++copy_count;
  }
  Vect(const Vect *v)
    : x(v->x)
    , y(v->y) {
    // To test return value optimization.
    // and memory leakage.
    ++copy_count;
  }

  ~Vect() {
    // To test return value optimization.
    // and memory leakage.
    ++destroy_count;
  }

  double surface() const {
    return x * y;
  }

  // operator overloading

  Vect operator+(const Vect &v) {
    return Vect(x + v.x, y + v.y);
  }

  Vect operator-(const Vect &v) {
    return Vect(x - v.x, y - v.y);
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

