#ifndef INHERIT_CHILD_H_
#define INHERIT_CHILD_H_

// Simulate complex inclusion (think external lib)
#include "../inherit_hidden/Mother.h"

#include <string>

/** This class is used to test:
 *   * attribute inheritance
 *   * method inheritance
 *   * custom bindings
 * 
 * Since Doxygen does not know that Mother is a Parent, we tell this. We also
 * use 'mixin' of custom bindings from ChildHelper.
 * @dub super: 'Parent,ChildHelper'
 */
class Child : public Mother {
  // Private attribute
  double pos_x_;
  double pos_y_;
public:
  // public attribute (child should inherit this)
  double teeth;

  Child(const std::string &name, MaritalStatus s, int birth_year, double x, double y)
    : Mother(name, s, birth_year)
    , pos_x_(x)
    , pos_y_(y) {}

  double x() {
    return pos_x_;
  }

  double y() {
    return pos_y_;
  }

};

#endif // INHERIT_CHILD_H_



