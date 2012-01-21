#ifndef NAMESPACE_OUT_H_
#define NAMESPACE_OUT_H_

namespace Nem {

/** A typedef defined inside the namespace.
 */
typedef TRect<double> Rectf;

} // Nem

/** A typedef defined outside the namespace.
 */
typedef Nem::TRect<double> nmRectf;

#endif // NAMESPACE_OUT_H_
