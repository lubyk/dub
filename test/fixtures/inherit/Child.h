#ifndef INHERIT_CHILD_H_
#define INHERIT_CHILD_H_

// Simulate complex inclusion (think external lib)
// This class needs the "../inherit_hidden/Mother.h" header to compile.
class Mother;

#include "Parent.h"

#include <string>

/** This class is used to test:
 *   * attribute inheritance
 *   * method inheritance
 *   * custom bindings
 * 
 * Since Doxygen does not know that Mother is a Parent, we tell this. We also
 * use 'mixin' of custom bindings from ChildHelper.
 * @dub super: Parent, ChildHelper
 */
class Child : public Mother {
  // Private attribute
  double pos_x_;
  double pos_y_;
public:
  // public attribute (child should inherit this)
  double teeth;

  Child(const std::string &name, MaritalStatus s, int birth_year, double x, double y);

  double x() {
    return pos_x_;
  }

  double y() {
    return pos_y_;
  }

  /** Should not inherit overloaded/virtuals twice.
   */
  std::string name();
};

/** This class should have set/get methods defined
 * because it inherits attributes from its parents.
 */
class GrandChild : public Child {
public:
};
#endif // INHERIT_CHILD_H_



