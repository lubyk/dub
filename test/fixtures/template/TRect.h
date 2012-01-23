#ifndef TEMPLATE_TRECT_H_
#define TEMPLATE_TRECT_H_

namespace Nem {

/** Test resolution of template inside a namespace.
 */
template <typename T>
class TRect {
  public:
  T x1;
  T y1;
  T x2;
  T y2;
};

} // Nem

typedef Nem::TRect<int32_t> nmRect32;

#endif // TEMPLATE_TRECT_H_
