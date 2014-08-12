dub [![Build Status](https://travis-ci.org/lubyk/dub.png)](https://travis-ci.org/lubyk/dub)
===

Doxygen based Lua binding generator.

[Documentation](http://doc.lubyk.org/dub.html).

install
-------

    luarocks install dub


Features
--------

Currently, the parser supports:

* public methods
* public attributes read/write
* pseudo-attributes read/write by calling getter/setter methods.
* custom bindings (for methods and global functions).
* custom read/write attributes (with void *userdata helper, union handling)
* public class methods
* public static attributes read/write
* pointer to member (gc protected)
* cast(default)/copy/disable const attribute
* member pointer assignment (gc protected)
* natural casting from std::string to string type (can include '\0')
* class instantiation from templates through typedefs
* class alias through typedefs
* bindings for superclass
* automatic casting to base class
* default argument values
* overloaded functions with optimized method selection from arguments
* operator overloading (even operator[], operator() and operator+= and such)
* return value optimization (no copy)
* simple type garbage collection optimization (no __gc method)
* namespace
* nested classes
* class enums
* global enums
* build system
* group multiple bindings in a single library
* rewrite class or library names
* native Lua table wrapping setmetatable({super = obj}, Vect)
* callback from C++ with error handling in Lua (with self.error).
* error function captures current 'print' function and can be used with self._errfunc.
* fully tested
* custom method binding name
