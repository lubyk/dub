#ifndef MEMORY_PEN_H_
#define MEMORY_PEN_H_

#include "Owner.h"

#include "dub/dub.h"
#include <string>

#define SOME_FUNCTION_MACRO(x)
#define OTHER_FUNCTION_MACRO(x)

/** This class is used to test:
 *   * when an object owned by the scripting language is deleted in C++.
 *   * when an object owned by C++ is deleted in the scripting language.
 *   * macro expansion setting
 * 
 * @dub push: pushobject
 */
class Pen : public dub::Object {
  std::string name_;
  Owner *owner_;
public:
  Pen(const char *name)
    : name_(name)
    , owner_(NULL) {}

  void setOwner(Owner *owner) {
    owner_ = owner;
  }

  ~Pen() {
    if (owner_) {
      owner_->setMessage(std::string("Pen '").append(name_).append("' is dying..."));
    }
  }

  const std::string &name() {
    return name_;
  }

  SOME_FUNCTION_MACRO(int x);

  OTHER_FUNCTION_MACRO(x);

};

#endif // MEMORY_PEN_H_
