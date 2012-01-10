#ifndef MEMORY_OWNER_H_
#define MEMORY_OWNER_H_

#include <string>

/** This class is used to monitor:
 *   * Deletion from C++.
 *   * Deletion from the scripting language.
 */
class Owner {
  std::string pen_name_;
  Pen *pen_;
public:
  Owner()
    : pen_(NULL) {}

  ~Owner();

  void own(Pen *pen);

  void setMessage(const std::string &msg) {
    message_ = msg;
  }
};

#include "Pen.h"
Owner::own(Pen *pen) {
  pen_ = pen;
  pen_->setOwner(this);
}
Owner::~Owner() {
  if (pen_) {
    pen_->setOwner(NULL);
  }
}
#endif // MEMORY_OWNER_H_
