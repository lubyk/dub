#ifndef NAMESPACE_T_RECT_H_
#define NAMESPACE_T_RECT_H_

#include <string>

namespace Nem {

/** This class is used to test:
 *   * template in namespace
 */
template<class T>
class TRect {
public:
  T w;
  T h;

  TRect(T w_, T h_)
    : w(w_)
    , h(h_)
  {}
};

}; // Nem
#endif // NAMESPACE_T_RECT_H_

