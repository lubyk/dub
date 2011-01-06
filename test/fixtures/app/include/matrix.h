#ifndef DOXY_GENERATOR_TEST_FIXTURES_APP_MATRIX_H_
#define DOXY_GENERATOR_TEST_FIXTURES_APP_MATRIX_H_

#include <cstring>
#include <stdlib.h> // malloc


/** @file */
typedef int LuaStackSize;

namespace dub {

/** Matrix class.
 *
 * @dub var_from_dub:'dummy value'
 *      other_from_dub: "some other value"
 *      ignore: 'bad_method'
 */
class Matrix {

  Q_PROPERTY(size_t foo_prop READ size)
  Q_PROPERTY(size_t size READ size WRITE setSize)
public:
  Matrix() : data_(NULL), rows_(0), cols_(0) {}

  Matrix(int rows, int cols) : rows_(rows), cols_(cols) {
    data_ = (double*)malloc(size() * sizeof(double));
  }

  ~Matrix() {
    if (data_) free(data_);
  }

  /** Return size of matrix (rows * cols). */
  size_t size() {
    return rows_ * cols_;
  }

  double cols() {
    return cols_;
  }

  double rows() {
    return rows_;
  }

  /** Dummy template based class method.
   */
  template<class T>
  T *give_me_tea() {
    return new T();
  }

  operator size_t() {
    return size();
  }

  void mul(TMat<int> other) {
    // dummy
  }

  void do_something(int i, bool fast=false) {

  }

  void do_something(int i, const char *baz) {
    // overloaded member method
  }

  void bad_method(int i) {
    // method should not exist in bindings
  }

  void use_other_lib(const std::string &name) {
    // dummy
  }

  int *ptr() {
    // dummy
  }

  bool true() {
    // dummy
    return true;
  }

  const char *name() {
    // should make method return string
  }

  int *lua_thing(int a, lua_State *L, int b) {
    // dummy
  }

  LuaStackSize work_with_lua(int a, int b) {
    // method that directly pushes lua values on the stack
    return 2;
  }

  /** Named constructor.
   */
  static Matrix *MakeMatrix(int rows, int cols) {
    return new Matrix(rows, cols);
  }

private:
  Matrix(int x) {
    // private constructor
  }

  int private_method() {
    // should not be implemented
    return 0;
  }

protected:

  int protected_method() {
    // should not be implemented
    return 0;
  }

  double *data_;
  size_t rows_;
  size_t cols_;
};


/** Test that private constructors are not used.
 */
class PrivateConstr {
public:

  PrivateConstr(int x) {}

  ~PrivateConstr() {}

private:
  // should not be used to build a FunctionGroup
  PrivateConstr(const char *name) {}
};

/** Test that custom destructors are used.
 * @dub destructor: 'dub_destroy'
 */
class CustomDestructor : public DeletableOutOfLua
{
public:

  CustomDestructor(int x) {}

  ~CustomDestructor() {}

  void do_this(int x) {

  }
};

/** Test that no destructor option is used.
 *
 * @dub destructor: ''
 */
class NoDestructor {
public:

  NoDestructor(int x) {}

  ~NoDestructor() {}
};

template<class T>
class TMat {
public:
  TMat() : data_(NULL), rows_(0), cols_(0) {}

  TMat(int rows, int cols) : rows_(rows), cols_(cols) {
    data_ = (T*)malloc(size() * sizeof(T));
  }

  // test constructor with T parameter
  TMat(T dummy) {

  }

  ~TMat() {
    if (data_) free(data_);
  }

  /** Dummy template based class method.
   */
  template<class T2>
  T2 *give_me_tea() {
    return new T2();
  }

  /** Return size of matrix (rows * cols). */
  size_t size() {
    return rows_ * cols_;
  }

  size_t cols() {
    return cols_;
  }

  size_t rows() {
    return rows_;
  }

  void fill(T value) {
    // dummy
  }

  void FunkyThing(double v[7]) {

  }

  T get(size_t row, size_t col) {
    return data_[row * cols_ + col];
  }

private:
  T *data_;
  size_t rows_;
  size_t cols_;
};

/** @var FloatMat
 */
typedef TMat<float> FloatMat;
typedef FloatMat FMatrix;

} // dub

#endif // DOXY_GENERATOR_TEST_FIXTURES_APP_MATRIX_H_
