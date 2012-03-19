#ifndef MEMORY_NO_DTOR_H_
#define MEMORY_NO_DTOR_H_

#include "dub/dub.h"

class NoDtor;

/** @dub push: pushobject
 *       ignore: dead
 */
class NoDtorCleaner : public dub::Thread {
  NoDtor *ndt_;
public:
  NoDtorCleaner(NoDtor *ndt);

  ~NoDtorCleaner() {
    cleanup();
  }

  void cleanup();

  void dead(NoDtor *obj);
};

/** This class is used to test:
 *   * Removing destructor.
 *
 * @dub destructor: false
 *      ignore: s_
 */
class NoDtor {
  friend class NoDtorCleaner;
  NoDtorCleaner *cleaner_;
public:
  std::string s_;

  NoDtor(const char *s)
    : cleaner_(NULL)
    , s_(s) {
  }

  ~NoDtor() {
    if (cleaner_) {
      cleaner_->dead(this);
    }
  }
};

inline NoDtorCleaner::NoDtorCleaner(NoDtor *ndt)
  : ndt_(ndt) {
  ndt->cleaner_ = this;
}

inline void NoDtorCleaner::dead(NoDtor *obj) {
  if (dub_pushcallback("callback")) {
    lua_pushstring(dub_L, obj->s_.c_str());
    // <func> <self> <str>
    dub_call(2, 0);
  }
}

inline void NoDtorCleaner::cleanup() {
  if (ndt_) {
    delete ndt_;
    ndt_ = NULL;
  }
}

#endif // MEMORY_NO_DTOR_H_

