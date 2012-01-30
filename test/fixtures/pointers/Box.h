#ifndef POINTERS_BOX_H_
#define POINTERS_BOX_H_

#include "Vect.h"
#include <string>

/** This class is used to test:
 *   * passing classes around as arguments.
 *   * casting script strings to std::string.
 *   * casting std::string to script strings.
 *   * accessing complex public members.
 *   * custom public member accessors.
 *   * pointer member types and gc.
 *   * complex default values.
 */
struct Box {

  std::string name_;
  Vect size_;
  /** Pointer to other type.
   */
  Vect *position;

  /** Const version (should return a copy)
   */
  const Vect *const_vect;

  Box(const std::string &name, const Vect &size = Vect(0,0))
    : name_(name)
    , size_(size)
    , position(NULL)
    , const_vect(NULL)
  {}

  /** Set gc to on. 
   *
   * @dub gc: true
   */
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

  // Should not gc either.
  Vect &sizeRef() {
    return size_;
  }

  // Should not gc.
  const Vect &constRef() {
    return size_;
  }

  /** Copy of size pointer. Should be garbage collected.
   * @dub gc: true
   */
  Vect *copySize() {
    return new Vect(size_);
  }
};

#endif // POINTERS_BOX_H_

