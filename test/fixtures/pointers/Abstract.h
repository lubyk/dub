#ifndef POINTERS_ABSTRACT_H_
#define POINTERS_ABSTRACT_H_

/** This class is used to make sure abstract types are not
 * instanciated and that we can cast to abstract types
 * and call methods on them.
 */
struct Abstract {
  Abstract() {}
  virtual double pureVirtual(double d) = 0;
};

class AbstractSub : public Abstract {
  double n_;
public:
  AbstractSub(double n)
    : n_(n) {}
  virtual double pureVirtual(double d) {
    return n_ + d;
  }
};

class AbstractHolder {
  Abstract *a_ptr_;
public:
  AbstractHolder(Abstract *a)
    : a_ptr_(a) {}

  Abstract *getPtr() {
    return a_ptr_;
  }
};

#endif // POINTERS_ABSTRACT_H_


