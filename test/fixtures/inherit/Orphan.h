#ifndef INHERIT_UNKNOWN_PARENT_H_
#define INHERIT_UNKNOWN_PARENT_H_

// Simulate complex inclusion (think external lib)
#include "../inherit_hidden/Mother.h"

#include <string>

template<class T>
class Foo {
};

class Bar {
};
/** This class is used to test:
 *   * unresolved super class (no typedef).
 *   * multiple super classes.
 * 
 */
class Orphan : public Foo<int>, public Bar {
public:
  Orphan() {}
};

#endif // INHERIT_UNKNOWN_PARENT_H_

