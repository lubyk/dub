#ifndef SIMPLE_INCLUDE_SIMPLE_H_
#define SIMPLE_INCLUDE_SIMPLE_H_

#include "types.h"

class Simple {

  double value_;
public:
  Simple(double v) : value_(v) {}
  
  ~Simple() {}

  double value() {
    return value_;
  }

  /** Test typedef resolution in methods.
   */
  MyFloat add(MyFloat v, double w) {
    return v + w;
  }

  void setValue(double v) {
    value_ = v;
  }

  /** To test simple static methods.
   */
  static double pi() {
    return 3.14;
  }

  bool isZero() {
    return value_ == 0;
  }
};

#endif // SIMPLE_INCLUDE_SIMPLE_H_
