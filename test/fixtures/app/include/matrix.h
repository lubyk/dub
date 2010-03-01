#ifndef DOXY_GENERATOR_TEST_FIXTURES_APP_MATRIX_H_
#define DOXY_GENERATOR_TEST_FIXTURES_APP_MATRIX_H_

/** @file */

namespace doxy {

class Matrix {
public:
  Matrix() : col_(0), row_(0) {}

  Matrix(int col, int row) : col_(col), row_(row) {
    data = (double*)malloc(size() * sizeof(double));
  }

  ~Matrix() {
    if (data) free(data);
  }

  /** Return size of matrix (rows * cols). */
  size_t size() {
    return col_ * row_;
  }

  double col() {
    return col_;
  }

  double row() {
    return row_;
  }

private:
  double *data;
};


} // doxy

#endif // DOXY_GENERATOR_TEST_FIXTURES_APP_MATRIX_H_
