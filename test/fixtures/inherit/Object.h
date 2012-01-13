#ifndef INHERIT_OBJECT_H_
#define INHERIT_OBJECT_H_

#include <string>

/** This class is used to test:
 *   * make sure non public inheritance is not followed.
 */
class Object {
public:
  // public attribute (all children should inherit this)
  double memory;

  void checkMemory() {
    if (!memory) {
      printf("None left!\n");
    }
  }
};

#endif // INHERIT_OBJECT_H_



