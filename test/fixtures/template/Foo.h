#ifndef TEMPLATE_FOO_H_
#define TEMPLATE_FOO_H_

/** This class is used to test:
 *   * template member functions = ignored
 */
struct Foo {
  template<class T>
  void addOne(const T &a) {
    a += 1;
  }
};

#endif // TEMPLATE_FOO_H_

