#ifndef MEMORY_PRIVATE_DTOR_H_
#define MEMORY_PRIVATE_DTOR_H_

#include "dub/dub.h"

/** This class is used to test:
 *   * private destructors.
 */
class PrivateDtor {
public:
  PrivateDtor() {}

private:
  ~PrivateDtor() {}
};

#endif // MEMORY_PRIVATE_DTOR_H_

