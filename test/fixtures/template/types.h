#ifndef TEMPLATE_TYPES_H_
#define TEMPLATE_TYPES_H_

#include "TVect.h"

/** This should resolve as a complete Vect class
 * with float for element storage.
 */
typedef TVect<float> Vectf;

/** This should resolve as a complete Vect class
 * with int for element storage.
 */
typedef TVect<int> Vect2i;

/** Test chained typedef.
 */
typedef Vect2i Vi;

#endif // TEMPLATE_TYPES_H_

