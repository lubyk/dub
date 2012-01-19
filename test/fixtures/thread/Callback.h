#ifndef THREAD_CALLBACK_H_
#define THREAD_CALLBACK_H_

#include "dub/dub.h"

#include <string>
class Caller;

/** This class is used to test:
 *   * read values defined in the scripting language (self access from C++).
 *   * execute callbacks from C++. 
 */
class Callback : public DubThread {
public:
  Callback(const std::string &name_)
    : name(name_) {}

  /** Test C++ attributes mixed with Lua values.
   */
  std::string name;

  /** Read a value from the scripting language.
   */
  double getValue(const std::string key);

private:
  friend class Caller;
  /** Simulate a call from C++
   * Call implementation depends on scripting language (see [lang]_callback.cpp).
   */
  void call(const std::string &msg);
};

#endif // THREAD_CALLBACK_H_

