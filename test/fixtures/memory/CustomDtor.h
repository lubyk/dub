#ifndef MEMORY_CUSTOM_DTOR_H_
#define MEMORY_CUSTOM_DTOR_H_

#include "dub/dub.h"

/** This class is used to test:
 *   * Custom destructors.
 *
 * @dub push: pushobject
 *      destructor: finalize
 */
class CustomDtor : public dub::Thread {
public:
  CustomDtor() {}

  ~CustomDtor() {}

  void finalize() {
    if (dub_pushcallback("callback")) {
      // <func> <self>
      dub_call(1, 0);
    }
    delete this;
  }
};
#endif // MEMORY_CUSTOM_DTOR_H_
