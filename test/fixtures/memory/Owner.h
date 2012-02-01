#ifndef MEMORY_OWNER_H_
#define MEMORY_OWNER_H_

#include <string>
class Pen;

/** This class is used to monitor:
 *   * Deletion from C++.
 *   * Deletion from the scripting language.
 */
class Owner {
  Pen *pen_;
public:
  std::string message_;

  Owner(Pen *pen = NULL);

  ~Owner();

  void own(Pen *pen);

  void setMessage(const std::string &msg) {
    message_ = msg;
  }

  void destroyPen();
};
#endif // MEMORY_OWNER_H_
