#ifndef POINTERS_BOX_H_
#define POINTERS_BOX_H_

#include "Size.h"
#include <string>

/** This class is used to test:
 *   * passing classes around as arguments.
 *   * casting script strings to std::string.
 *   * casting std::string to script strings.
 *   * accessing complex public members.
 */
struct Box {
  std::string name_;
  Size size_;
  Box(const std::string &name, const Size &size)
    : name_(name)
    , size_(size) {}

  static MakeBox(const char *name, Size *size) {
    Box *b = new Box(std::string(name), *size);
    return b;
  }

  /** Test cast from std::string to scripting language string.
   */
  std::string name() {
    return name_;
  }
  
};

#endif // POINTERS_BOX_H_

