#ifndef THREAD_CALLBACK_H_
#define THREAD_CALLBACK_H_

#include "dub/dub.h"

/** This class is used to test:
 *   * read values defined in the scripting language (self access from C++).
 *   * execute callbacks from C++. 
 */
class Callback : public DubThread {
  /** Simulate a call from C++
   * Call implementation depends on scripting language (see [lang]_callback.cpp).
   */
  void call(float value);
};

#endif // THREAD_CALLBACK_H_

