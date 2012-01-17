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

#endif // INHERIT_HIDDEN_MOTHER_H_

