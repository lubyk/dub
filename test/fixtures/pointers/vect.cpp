#include "Vect.h"
size_t Vect::create_count = 0;
size_t Vect::copy_count = 0;
size_t Vect::destroy_count = 0;

double Vect::unamed(double d, int i) {
  return d + 2 * i;
}
