#ifndef INHERIT_HIDDEN_MOTHER_H_
#define INHERIT_HIDDEN_MOTHER_H_

#include "Parent.h"

#include <string>

/** This class is not seen by Doxygen and is used to 'explain' inheritance
 * of Parent by Child through the 'super' key in dub header doc.
 */
class Mother : public Parent {
public:
  Mother(const std::string &name, MaritalStatus s, int birth_year)
    : Parent(name, s, birth_year) {}
};


/** This class is not seed by Doxygen or Dub. Instances of this class
 * are passed around as opaque types.
 */
class Unk1 {
  double v_;
public:
  Unk1(double v) : v_(v) {}
  double value() {
    return v_;
  }
};

typedef Unk1 Unk2;

#endif // INHERIT_HIDDEN_MOTHER_H_

