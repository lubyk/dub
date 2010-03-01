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

private:
  double *data;
  size_t rows_;
  size_t cols_;
};


} // doxy

#endif // DOXY_GENERATOR_TEST_FIXTURES_APP_MATRIX_H_
