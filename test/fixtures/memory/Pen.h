#ifndef MEMORY_PEN_H_
#define MEMORY_PEN_H_

#include "Owner.h"

#include "dub/dub.h"
#include <string>

/** This class is used to test:
 *   * when an object owned by the scripting language is deleted in C++.
 *   * when an object owned by C++ is deleted in the scripting language.
 */
class Pen : public DubObject {
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
};

#endif // MEMORY_PEN_H_
