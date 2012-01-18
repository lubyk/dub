#ifndef POINTERS_VECT_H_
#define POINTERS_VECT_H_

#include <cstdio>
#include <cstring> // size_t
#define MAX_DIM 3

/** This class is used to test:
 *   * accessing public members
 *   * return value optimization
 *   * basic memory leakage
 *   * operator overloading
 *   * C array attributes
 */
struct Vect {
  double x;
  double y;

  double d[MAX_DIM];

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
    for (size_t i=0; i<MAX_DIM; ++i)
      d[i] = i + 1 + tx + ty;
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

  void operator+=(const Vect &v) {
    x += v.x;
    y += v.y;
  }

  Vect operator-(const Vect &v) {
    return Vect(x - v.x, y - v.y);
  }

  void operator-=(const Vect &v) {
    x -= v.x;
    y -= v.y;
  }

  /** Unary minus. TODO
   */
  //Vect operator-() {
  //  return Vect(-x, -y);
  //}

  Vect operator*(double d) {
    return Vect(d*x, d*y);
  }

  // overloaded operators
  // cross product
  double operator*(const Vect &v) {
    return x*v.y - y*v.x;
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

  // return element at position i
  double operator()(int i) {
    if (i == 1) {
      return x;
    } else if (i == 2) {
      return y;
    } else {
      return 0;
    }
  }

  // return element at position i
  double operator[](int i) {
    if (i == 1) {
      return x;
    } else if (i == 2) {
      return y;
    } else {
      return 0;
    }
  }

  // unknown operator should be ignored.
  Vect& operator=( int px ) {
    x = px;
    return *this;
  }
};

#endif // POINTERS_VECT_H_

