#ifndef MEMORY_UNION_H_
#define MEMORY_UNION_H_

#include "dub/dub.h"
#include <string>

/** This class is used to test:
 *   * access to anonymous union members (custom bindings)
 */
class Union {
public:
  /** Anonymous union.
   */
  union {
    struct {
      uint8_t h;
      uint8_t s;
      uint8_t v;
      uint8_t a;
    };
    uint32_t c;
  };

  Union(uint8_t _h, uint8_t _s, uint8_t _v, uint8_t _a) {
    h = _h;
    s = _s;
    v = _v;
    a = _a;
  }
};

#endif // MEMORY_UNION_H_

