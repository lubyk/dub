#ifndef DOXY_GENERATOR_TEST_FIXTURES_APP_MATRIX_H_
#define DOXY_GENERATOR_TEST_FIXTURES_APP_MATRIX_H_

#include <cstring>
#include <stdlib.h> // malloc


/** @file */

namespace doxy {

class Matrix {
public:
  Matrix() : rows_(0), cols_(0) {}

  Matrix(int rows, int cols) : rows_(rows), cols_(cols) {
    data = (double*)malloc(size() * sizeof(double));
  }

  ~Matrix() {
    if (data) free(data);
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

private:
  double *data;
  size_t rows_;
  size_t cols_;
};


template<class T>
class TMat {
public:
  TMat() : rows_(0), cols_(0) {}

  TMat(int rows, int cols) : rows_(rows), cols_(cols) {
    data = (T*)malloc(size() * sizeof(T));
  }

  ~TMat() {
    if (data) free(data);
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
    return data[row * cols_ + col];
  }

private:
  T *data;
  size_t rows_;
  size_t cols_;
};

/** @var FloatMat
 */
typedef TMat<float> FloatMat;

} // doxy

#endif // DOXY_GENERATOR_TEST_FIXTURES_APP_MATRIX_H_
