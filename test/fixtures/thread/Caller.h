#ifndef THREAD_CALLER_H_
#define THREAD_CALLER_H_

#include "dub/dub.h"

#include <string>

/** This class is used to simulate a call from C++.
 */
class Caller {
public:
  Callback *clbk_;

  Caller() {}

  /** Simulate a call from C++
   */
  void call(const std::string &msg) {
    if (clbk_) {
      clbk_->call(msg);
    }
  }
};

#endif // THREAD_CALLER_H_


