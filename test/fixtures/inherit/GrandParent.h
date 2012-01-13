#ifndef INHERIT_GRAND_PARENT_H_
#define INHERIT_GRAND_PARENT_H_

#include "Object.h"
#include <string>

/** This class is used to test:
 *   * attribute inheritance
 *   * method inheritance
 */
class GrandParent : protected Object {
public:
  // public attribute (all children should inherit this)
  double birth_year;

  GrandParent(int y)
    : birth_year(y) {}

  /** Method that should be inherited by all children.
   */
  int computeAge(int current_year) {
    return current_year - birth_year;
  }
};

#endif // INHERIT_GRAND_PARENT_H_


