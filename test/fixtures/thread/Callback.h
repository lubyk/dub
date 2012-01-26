#ifndef THREAD_CALLBACK_H_
#define THREAD_CALLBACK_H_

#include "dub/dub.h"

#include <string>
class Caller;

/** This class is used to test:
 *   * read values defined in the scripting language (self access from C++).
 *   * execute callbacks from C++. 
 *
 * @dub push: pushobject
 */
class Callback : public dub::Thread {
public:
  static int destroy_count;

  Callback(const std::string &name_)
    : name(name_) {
  }

  ~Callback() {
    ++destroy_count;
  }
  /** Test C++ attributes mixed with Lua values.
   */
  std::string name;

  /** Read a value from the scripting language.
   */
  double getValue(const std::string &key);

  double anyMethod(double d) {
    return d + 100;
  }

  std::string getName() {
    return name;
  }

private:
  friend class Caller;
  /** Simulate a call from C++
   * Call implementation depends on scripting language (see [lang]_callback.cpp).
   */
  void call(const std::string &msg);
};

#endif // THREAD_CALLBACK_H_

