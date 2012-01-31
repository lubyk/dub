/** This is not a real C++ class. It is used to add custom methods to Child.
 *
 * This tells to not make bindings for this class and not try to cast.
 * @dub bind: false
 *      cast: false
 */
class ChildHelper {
public:
  // Special method with multiple return values.
  LuaStackSize position();
};
