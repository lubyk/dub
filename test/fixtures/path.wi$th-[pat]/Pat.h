#ifndef PATH_WITH_PAT_PAT_H_
#define PATH_WITH_PAT_PAT_H_

#include <map>
#include <string>

/** This class is used to test
 *   * header_base with Lua pattern characters in path.
 *
 */
class Pat {
  int value_;
public:
  Pat(int v)
    : value_(v)
  {}

  void setValue(int v) {
    value_ = v;
  }

  int value() {
    return value_;
  }
};

#endif // PATH_WITH_PAT_PAT_H_


