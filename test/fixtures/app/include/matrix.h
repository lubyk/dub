#ifndef DOXY_GENERATOR_TEST_FIXTURES_APP_MATRIX_H_
#define DOXY_GENERATOR_TEST_FIXTURES_APP_MATRIX_H_

#include <cstring>
#include <stdlib.h> // malloc


/** @file */

namespace dub {

class Matrix {
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

private:
  double *data_;
  size_t rows_;
  size_t cols_;
};


template<class T>
class TMat {
public:
  TMat() : data_(NULL), rows_(0), cols_(0) {}

  TMat(int rows, int cols) : rows_(rows), cols_(cols) {
    data_ = (T*)malloc(size() * sizeof(T));
  }

  ~TMat() {
    if (data_) free(data_);
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
