#ifndef INHERIT_PARENT_H_
#define INHERIT_PARENT_H_

#include "GrandParent.h"

#include <string>

/** This class is used to test:
 *   * attribute inheritance
 *   * method inheritance
 */
class Parent : public GrandParent {
  // Private attribute
  std::string name_;
public:
  // public attribute (child should inherit this)
  bool married;

  Parent(const std::string &name, bool married_, int birth_year)
    : GrandParent(birth_year)
    , name_(name)
    , married(married_) {}

  /** Method that should be inherited by child.
   */
  std::string name() {
    return name_;
  }

  /** Static method that should not be inherited.
   */
  static std::string getName(Parent *parent) {
    return parent->name_;
  }
};

#endif // INHERIT_PARENT_H_


