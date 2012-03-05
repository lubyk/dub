#ifndef SIMPLE_INCLUDE_REG_H_
#define SIMPLE_INCLUDE_REG_H_

#include <map>
#include <string>

/** This class is used to test
 *   * custom registration name: require registers Reg_core
 *     instead of Reg (but metatable is 'Reg').
 * 
 * @dub register: Reg_core
 */
class Reg {
  std::string name_;
public:
  Reg(const char *name) : name_(name) {}
  Reg(const Reg &reg) : name_(reg.name_) {}
  

  const std::string name() const {
    return name_;
  }
};

#endif // SIMPLE_INCLUDE_REG_H_


