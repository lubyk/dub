#ifndef POINTERS_BOX_H_
#define POINTERS_BOX_H_

#include "Vect.h"
#include <string>

/** This class is used to test:
 *   * passing classes around as arguments.
 *   * casting script strings to std::string.
 *   * casting std::string to script strings.
 *   * accessing complex public members.
 */
struct Box {
  std::string name_;
  Vect size_;
  Box(const std::string &name, const Vect &size)
    : name_(name)
    , size_(size) {}

  static Box *MakeBox(const char *name, Vect *size) {
    Box *b = new Box(std::string(name), *size);
    return b;
  }

  /** Test cast from std::string to scripting language string.
   */
  std::string name() {
    return name_;
  }

  double surface() {
    return size_.surface();
  }

  // Should not gc.
  Vect *size() {
    return &size_;
  }

  /** Copy of size pointer. Should be garbage collected.
   * @dub gc: true
   */
  Vect *copySize() {
    return new Vect(size_);
  }
};

#endif // POINTERS_BOX_H_

