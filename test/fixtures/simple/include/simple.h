#ifndef SIMPLE_INCLUDE_SIMPLE_H_
#define SIMPLE_INCLUDE_SIMPLE_H_

#include "types.h"

class Simple {

  float value_;
public:
  Simple(float v) : value_(v) {}
  
  ~Simple() {}

  float value() {
    return value_;
  }

  /** Test typedef resolution in methods.
   */
  MyFloat add(MyFloat v, float w) {
    return v + w;
  }

  void setValue(float v) {
    value_ = v;
  }
  /** To test simple static methods.
   */
  static double pi() {
    return 3.14;
  }
};

#endif // SIMPLE_INCLUDE_SIMPLE_H_
