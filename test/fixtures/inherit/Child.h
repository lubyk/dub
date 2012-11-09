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
 *   * unknown types
 *   * ignore methods from parent
 * 
 * Since Doxygen does not know that Mother is a Parent, we tell this. We also
 * use 'mixin' of custom bindings from ChildHelper.
 * @dub super: Parent, ChildHelper, Mother
 *      ignore: virtFunc
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

  /** Unknown Unk1 type.
   */
  Unk1 returnUnk1(double value) {
    return Unk1(value);
  }

  /** Unknown Unk2 type.
   */
  Unk2 returnUnk2(double value) {
    return Unk2(value);
  }

  /** Unknown arguments.
   */
  double methodWithUnknown(Unk1 x, Unk2 *y) {
    return x.value() + y->value();
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



