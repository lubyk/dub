#include "../inherit_hidden/Mother.h"
#include "Child.h"
#include <string>

Child::Child(const std::string &name, MaritalStatus s, int birth_year, double x, double y)
  : Mother(name, s, birth_year)
  , pos_x_(x)
  , pos_y_(y) {}

std::string Child::name() {
  return std::string("Child ").append(Parent::name());
}
