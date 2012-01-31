#ifndef SIMPLE_INCLUDE_SIMPLE_H_
#define SIMPLE_INCLUDE_SIMPLE_H_

#include "types.h"

#include <cstring>

/** This class is used to test
 *   * simple bindings
 *   * default parameters
 *   * overloaded methods.
 *   * char/ const char* types
 * 
 * @dub ignore: shouldBeIgnored, publicButInternal
 */
class Simple {

  double value_;
public:
  Simple(double v) : value_(v) {}
  
  ~Simple() {}

  double value() {
    return value_;
  }

  /** Test typedef resolution in methods and
   * default values in arguments.
   */
  MyFloat add(MyFloat v, double w = 10) {
    return v + w;
  }

  /** Test method overloading with default parameters.
   */
  Simple add(const Simple &o) {
    return Simple(value_ + o.value_);
  }

  /** Method overloading without default parameters.
   */
  Simple mul(const Simple &o) {
    return Simple(value_ + o.value_);
  }

  double mul(double d, const char* c) {
    return value_ + d + strlen(c);
  }

  double mul(double d, double d2) {
    return d * d2;
  }

  double mul() {
    return 0;
  }

  /** Overloaded method that can be decided by arg size.
   */
  int testA(Foo *f) {
    return 1;
  }

  int testA(Bar *b, double d) {
    return 2;
  }

  /** Overloaded method that can be only be decided by arg type.
   */
  int testB(Foo *f, double d) {
    return 1;
  }

  int testB(Bar *b, double d) {
    return 2;
  }

  int testB(Bar *b, const char *c) {
    return 3;
  }

  // to test deep nesting overloaded decision tree
  double addAll(double d, double d2, double d3) {
    return d + d2 + d3;
  }

  // to test deep nesting overloaded decision tree
  double addAll(double d, double d2, double d3, const char *msg) {
    return d + d2 + d3 + strlen(msg);
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

  struct MyBuf {
    double d;
  };

  /** Struct by value parameter.
   */
  double showBuf(MyBuf buf) {
    return buf.d;
  }

  /** Class by value.
   */
  double showSimple(Simple p) {
    return p.value_;
  }

  void shouldBeIgnored() {
  }

  void publicButInternal() {
  }

  // ignored in inspector
  void ignoreInInspector() {
  }

protected:
  bool somethingNotToBind(double d) {
    return false;
  }

private:
  bool someOtherThingNotToBind() {
    return false;
  }
};

void badFuncToIgnore(const char *foo) {
}

#endif // SIMPLE_INCLUDE_SIMPLE_H_
