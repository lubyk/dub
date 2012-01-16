#ifndef CONSTANTS_CAR_H_
#define CONSTANTS_CAR_H_

#include <string>

/** This class is used to test:
 *   * class constants (enums).
 *   * enum attributes read/write.
 *   * alternate binding definition (using Car.new instead of Car())
 */
class Car {
public:

  /** List of Car brands.
   */
  enum Brand {
    Smoky,
    Polluty,
    Noisy,
    Dangerous,
  };

  /** Accessors should understand that Brand is an integer.
   */
  Brand brand;

  std::string name;

  Car(const char * n, Brand b = Polluty)
    : brand(b)
    , name(n) {
  }

  void setBrand(Brand b) {
    brand = b;
  }

  const char *brandName() {
    switch(brand) {
      case Smoky:
        return "Smoky";
      case Polluty:
        return "Polluty";
      case Noisy:
        return "Noisy";
      case Dangerous:
        return "Dangerous";
      default:
        return "???";
    }
  }
};

#endif // CONSTANTS_CAR_H_

