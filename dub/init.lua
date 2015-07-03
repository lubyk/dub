--[[------------------------------------------------------
  # Lua C++ binding generator <a href="https://travis-ci.org/lubyk/dub"><img src="https://travis-ci.org/lubyk/dub.png" alt="Build Status"></a> 
  
  Create lua bindings by parsing C++ header files using [doxygen](http://doxygen.org).

  Generated lua bindings do not contain any external dependencies. Dub C++ files
  are copied along with the generated C++ bindings.

  <html><a href="https://github.com/lubyk/dub"><img style="position: absolute; top: 0; right: 0; border: 0;" src="https://s3.amazonaws.com/github/ribbons/forkme_right_green_007200.png" alt="Fork me on GitHub"></a></html>

  *MIT license* &copy Gaspard Bucher 2014.

  ## Installation
  
  With [luarocks](http://luarocks.org):

    $ luarocks install dub
  
  ## Speed

  We tried our best to make these bindings as safe and fast as possible,
  ensuring we do not break return value optimization and we execute as few lines
  of code between Lua and C++. Even if we did our best to keep the overhead
  between Lua and C++ as small as possible, calling between Lua and C++ prevents
  some of the optimizations LuaJIT is very good at.

  When needing very fast execution implying lots of Lua and C++ code, either
  push all data into C++ structures and work from there or push all data into
  Lua to avoid binding and function calls overhead.

  For example, it would be a bad idea to loop through all the pixels of an image
  using operator[](int i) to implement a filter in Lua. In such a case, use [LuaJIT FFI](http://luajit.org/ext_ffi.html)
  to build a buffer, copy content inside the buffer and work from there.
  
  ## Use Case

  Some of the main reasons for using this binding generator over other solutions
  such as 'LuaJIT FFI' are:
  
  + memory:        Some libraries put all the burden of memory management on
                   the end-user. Using FFI bindings, you still have to handle
                   memory management. By using 'dub', you get garbage
                   collection protection for pointers. We used this in our
                   bindings for [Bullet](http://bulletphysics.org/).
  + abstraction:   Sometime we want to write C++ wrapper code to keep an API
                   as simple as possible. We did this for custom zmq bindings.
                   See [callbacks](#Callbacks) for another example.
  + no magic:      The generated bindings are easy to read C++ files without needing
                   fancy runtime introspection or advanced C++ features.
  + customizable:  Method bindings can be customized with custom definitions or
                   even entire ".cpp" file templates.

  ## Installation
  
  Install with [luarocks](http://luarocks.org):

    $ luarocks install dub
  
--]]------------------------------------------------------
local lub = require 'lub'
local lib = lub.Autoload 'dub' 
local private = {}

-- nodoc
lib.private = private

-- Current version of 'dub' respecting [semantic versioning](http://semver.org).
lib.VERSION = '2.2.4'

lib.DEPENDS = { -- doc
  -- Compatible with Lua 5.1 to 5.3 and LuaJIT
  'lua >= 5.1, < 5.4',
  -- Uses [Lubyk base library](http://doc.lubyk.org/lub.html)
  'lub >= 1.0.4, < 2',
  -- Uses [Lubyk fast xml library](http://doc.lubyk.org/xml.html)
  'xml ~> 1',
  -- Uses [Lubyk yaml library](http://doc.lubyk.org/yaml.html)
  'yaml ~> 1',
}

-- nodoc
lib.DESCRIPTION = {
  summary = "Lua binding generator from C/C++ code (uses Doxygen to parse C++ comments).",
  detailed = [[
    A powerful binding generator for C/C++ code with support for attributes,
    callbacks, errors on callbacks, enums, nested classes, operators, public
    attributes, etc.
    
    Full documentation: http://doc.lubyk.org/dub.html
  ]],
  homepage = "http://doc.lubyk.org/"..lib.type..".html",
  author   = "Gaspard Bucher",
  license  = "MIT",
}

-- nodoc
lib.BUILD = {
  github   = 'lubyk',
  pure_lua = true,
}


--[[
  # Usage example

  The following code is used to generated bindings from all the headers located
  in `include/xml` and output generated files inside `src/bind`.

  First we must parse headers. To do this, we create a dub.Inspector which we
  could also use to query function names, classes and other information on the
  parsed C++ headers.
  
    local lub = require 'lub'
    local dub = require 'dub'

    local inspector = dub.Inspector {
      INPUT    = {
        lub.path '|include/xml',
      },
    }

  We can now generate Lua bindings with the dub.LuaBinder.

    local binder = dub.LuaBinder()

    binder:bind(inspector, {
      -- Mandatory library name. This is used as prefix for class types.
      lib_name = 'xml',

      output_directory = lub.path '|src/bind',

      -- Remove this part in included headers
      header_base = lub.path '|include',

      -- Open the library with require 'xml.core' (not 'xml') because
      -- we want to add some more Lua methods inside 'xml.lua'.
      luaopen    = 'xml_core',
    })
    
  The code above generates files such as:

  + xml_core.cpp:  This contains bindings for methods in the 'xml' namespace,
                   constants and also the main 'luaopen_xml_core' function.
  + xml_Parser.cpp:  This contains bindings for xml::Parser class.
  + dub/...:       Compile time dub C++ and header files.

  When building the library, make sure to include all C++ files (including those
  in the `dub` folder. You should also include the binding folder in the include
  path so that `#include "dub/dub.h"` is properly resolved.

  You can view the generated files on [xml lib on github](https://github.com/lubyk/xml/tree/master/src/bind).

  # Compatibility

  The bindings generated by dub are [heavily tested](https://github.com/lubyk/dub/tree/master/test) and are
  compatible with Lua 5.1, 5.2 and LuaJIT.

  There is no external library dependency.

  # Binding style

  Dub generates bindings so that using the library/class from Lua looks as familiar
  as possible for those knowing C++ code. For example, here is some code based on
  HelloWorld.cpp from Box2D.

  In C++:

    #C++
    // Define the dynamic body. We set its position and call the body factory.
    b2BodyDef bodyDef;
    bodyDef.type = b2_dynamicBody;
    bodyDef.position.Set(0.0f, 4.0f);
    b2Body* body = world.CreateBody(&bodyDef);
    
    // Define another box shape for our dynamic body.
    b2PolygonShape dynamicBox;
    dynamicBox.SetAsBox(1.0f, 1.0f);

  In Lua:

    -- Define the dynamic body. We set its position and call the body factory.
    local bodyDef = b2.BodyDef()
    bodyDef.type = b2.dynamicBody
    bodyDef.position:Set(0.0, 4.0)
    local body = world:CreateBody(bodyDef)

    -- Define another box shape for our dynamic body.
    local dynamicBox = b2.PolygonShape()
    dynamicBox:SetAsBox(1.0, 1.0)
    
  # Extra features

  Apart from supporting many advanced and complicated C++ features (such as
  inheritance, type casting, overloaded operators, etc). Dub has some nice
  additions to make working with C++ objects easier.

  ## super

  All C++ objects in Lua can be wrapped in a table and behave like the original
  objects with all the advantages of Lua tables. Simply set 'super' to the userdata
  in the wrapping class:

    local p = xml.Parser() --
    print(type(p))
    --> userdata

    -- Wrap userdata in a Lua table
    local t = setmetatable({super = p}, xml.Parser)
    t.info = 'some attached information'
    -- Methods works just like t.super:parse(some_string)
    t:parse(some_string)

  ## automatic cast to parent class

    local p = foo.SubClassOfBase()
    local b = foo.Base()

  If we have a `setFriend` method which expects `Base*` type. The following
  code will automatically check if `p` is sub-type of Base and cast it. The
  Base class knows nothing of SubClassOfBase (which could be defined in
  another module):

    -- Cast 'p' to foo.Base
    b:setFriend(p)

  # public class methods

  Example:

    #C++
    class Foo {
    public:
      static void sayHello() {
        printf("Hello\n");
      }
    };

  Lua code

    Foo.sayHello()
    --> Hello
  
  # public attributes read/write

  Example:

    #C++
    class Foo {
    public:
      std::string name;

      void printName() {
        printf("My name is '%s'\n", name.c_str());
      }
    };

  Lua code

    local foo = Foo()
    foo.name = 'Prometheus'
    foo:printName()
    --> My name is 'Prometheus'

  # Pointer assignment
  
  Pointer assignment is made possible because we use member pointer garbage
  collection protection. It is thus safer to use in Lua as it is in plain C++ !

  Example:

    #C++
    class Foo {
      std::string name;
    public:
      Foo(const char *n) : name(n) {}
      Foo *other;

      void printOther() {
        if (other) {
          printf("Other name is '%s'\n", other->name.c_str());
        } else {
          printf("No other\n");
        }
      }
    };

  Lua code

    local a = Foo 'Armand' 
    local b = Foo 'Bob'
    a.other = b
    a:printOther()
    --> Other name is 'Bob'

    b = nil
    collectgarbage 'collect'
    --> b is not destroyed because a references it
    a:printOther()
    --> Other name is 'Bob'
    
    a.other = nil
    a:printOther()
    --> No other

    collectgarbage 'collect'
    --> b is destroyed

  # Operator overloading
  
  All `operator[xx]()` functions in C++ are translated to native Lua operators
  when possible. See [operators](dub.Function.html#Operator-overloading) for a
  complete list.

  C++:

    #C++
    Foo x(4);
    Foo y(3);
    Foo z = x + y; // calls x.operator+(y)

  In Lua:

    local x, y = Foo(4), Foo(3)
    local z = x + y -- calls x:__add(y) which calls operator+()

  # Callbacks

  Calling Lua from C++ is made easy by deriving a class from dub::Thread, this
  class can then be used to call Lua methods on 'self' in an efficient way. For
  example, let's say we have a native QWidget class and we want to implement the
  'resized' callback:

    #C++
    class Widget : public QWidget, public dub::Thread {
      Q_OBJECT
    public:
      Widget(int window_flags)
      : QWidget(NULL, (Qt::WindowFlags)window_flags = 0) {}

      ~Widget() {}
      
    protected:
      virtual void resizeEvent(QResizeEvent *event) {
        // If your code is multi-threaded (i.e. no single event loop)
        // you need to use a mutex here or better yet, use a FIFO queue
        // and a pipe between threads.

        // Get 'resized' callback on Lua object
        if (!dub_pushcallback("resized")) return;
        // dub_L is our object's current thread
        lua_pushnumber(dub_L, width);
        lua_pushnumber(dub_L, height);

        // 3 arguments, no return value
        dub_call(3, 0);
      }    
    };

  Usage in Lua:

    win = gui.Widget()

    function win:resized(w, h)
      print('Hey why did you resize my window ?')
    end

  Note that the `resized` function defined on `win` object is a regular Lua
  function and this can be called from Lua as well:

    -- manual call to resized callback
    win:resized(win:width(), win:height())


  ## Errors in callbacks

  If some error occurs during a callback, this error does not disappear in limbo
  between C++ and Lua (and does not cause the C++ code to crash). The error is
  captured during the call and either printed out or handled by a custom `error`
  function defined on the called object.

  Example:
  
    win = gui.Widget()

    function win:error(msg)
      print('Something went wrong in my window.', msg)
    end

    function win:resized(w, h)
      if (w > 300) then
        error('Bird crash!')
      end
    end
  
  # Custom bindings

  Sometimes we need to write custom code either because 'dub' is cannot guess
  the proper way to call a function or because we want to make it more Lua-like
  (allowing multiple return values for example). To use custom bindings, pass
  the path to a folder containing yaml files (one per class). The yaml file for
  global functions should be named after the namespace (if any) or '_global.yml'
  if there is no namespace.

  Things to note when writing the bindings:

  + self: This variable is set before the custom binding code and corresponds
          to the C++ object the binding is called on. Static methods and plain
          functions do not have 'self' set.
  + arguments: Argument types and conversions are handled by dub. You can
          reference them by their names in the header declaration.
  + return: If you are returning a value, you must add the call to `return` with
          the number of values pushed on the stack.
  + arg count: If your method takes a varying number of arguments, you can use
          'arg0', 'arg1' to set bindings for each case (see 'showFullScreen'
          example below).
  + file name: The name of the YAML file should reflect the namespace or class
          being bound. For global functions, use "_global.yaml".
  + inline: You can define the custom bindings by passing a lua table instead
          of a path to dub.LuaBinder.bind. See below for the format.

  ## YAML file format

  For example, to define custom bindings for Rect::size, you need to create a
  'Rect.yml' file like this:

    #yaml
    lua:
      methods:
        size: |
          Point sz = self->size();
          lua_pushnumber(L, sz.x());
          lua_pushstring(L, sz.y());
          return 2;

  You do not have to do the arguments type checking. This is done by dub. You
  *do* need to return the number of Lua return values if there are any.

  You can also define your own methods by using custom headers instead of the
  original ones. This is what we did for Qt bindings to whitelist the bindings
  we wanted. We also chose to declare inexistant methods and bind them by hand:

    #yaml
    lua:
      methods:
        swapFullScreen: |
          if (!self->isFullScreen()) {
            self->showFullScreen();
          } else {
            self->showNormal();
          }            
        showFullScreen:
          # Varying custom binding on arg count for overloaded-functions.
          arg0: |
            self->showFullScreen();
          arg1: |
            if (enable) {
              self->showFullScreen();
            } else {
              self->showNormal();
            }                  
        globalMove: |
          self->move(
            self->mapToParent(
              self->mapFromGlobal(QPoint(x, y))
            )
          );   
  
  Note that we do not need to write the code testing argument.

  ## Inline custom bindings

  This is a quick and dirty solution when you only need to define a couple of
  custom bindings. In this case, you pass a table to the binder:

    local bind = dub.LuaBinder()

    binder:bind(inspector, {
      lib_name         = 'foo',
      output_directory = lub.path '|src/bind',
      custom_bindings  = {
        Rect = {
          methods = {
            size = [=[
              Point sz = self->size();
              lua_pushnumber(L, sz.x());
              lua_pushstring(L, sz.y());
              return 2; 
            ]=],
          },
        },
      },
    })

  The table format is exactly the same as the yaml files except for the 'lua'
  root key which is not needed.

  # Other features

  As time passes, the undocummented feature list below will shrink. Until then,
  it's better having an idea what Dub does.

  * pseudo-attributes read/write by calling getter/setter methods.
  * custom read/write attributes (with void *userdata helper, union handling)
  * public static attributes read/write
  * pointer to member (gc protected)
  * cast(default)/copy/disable const attribute
  * natural casting from std::string to string type (can include '\0')
  * class instantiation from templates through typedefs
  * class alias through typedefs
  * bindings for superclass
  * default argument values
  * overloaded functions with optimized method selection from arguments
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
  * fully tested
  * custom method binding name
  * remove exception catching if never throws


  # C++ exceptions

  The dub library catches all exceptions thrown during binding execution and
  passes the exceptions as lua errors. Internally, the library itself throws
  `dub::Exception` and `dub::TypeException`.

--]]
local DUB_MAX_IN_SHIFT = 4294967296

-- # Verbosity

-- Default warning level (anything below or equal to this level will be
-- notified). It is usually good to leave this warning level to 5 and fix
-- individual warning messages by explicitely ignoring the problematic function
-- during binding generation.
lib.warn_level = 5

-- Warning function. Can be overwriten. The `level` parameter is a value between
-- 1 and 10 (the higher the level the less important the message).
-- function lib.warn(level, format, ...)

-- # Classes

--========================================== PRIVATE

local shown_warnings = {}

-- nodoc
function lib.printWarn(level, fmt, ...)
  if level > lib.warn_level then
    return
  end
  local msg = string.format(fmt, ...)
  if not shown_warnings[msg] then
    print('warning:', msg)
    shown_warnings[msg] = true
  end
end

-- nodoc
lib.warn = lib.printWarn

-- nodoc
function lib.silentWarn(level, fmt, ...)
  local msg = string.format(fmt, ...)
  if not shown_warnings[msg] then
    shown_warnings[msg] = true
  end
end

local function shiftleft(v, nb)
  local r = v * (2^nb)
  -- simulate overflow with 32 bits
  r = r % DUB_MAX_IN_SHIFT
  return r
end

-- Find the minimal modulo value for the list of keys to
-- avoid collisions.

-- nodoc
function lib.minHash(list_or_obj, func)
  local list = {}
  if not func then
    for _, name in ipairs(list_or_obj) do
      if not list[name] then
        list[name] = true
        table.insert(list, name)
      end
    end
  else
    list = {}
    for name in func(list_or_obj) do
      if not list[name] then
        list[name] = true
        table.insert(list, name)
      end
    end
  end
  local list_sz = #list
  if list_sz == 0 then
    -- This is an error.
    return nil
  end

  local sz = 1
  while true do
    sz = sz + 1
    local hashes = {}
    for i, key in ipairs(list) do
      local h = lib.hash(key, sz)
      if hashes[h] then
        break
      elseif i == list_sz then
        return sz
      else
        hashes[h] = key
      end
    end
  end
end

-- nodoc
function lib.hash(str, sz)
  local h = 0
  for i=1,string.len(str) do
    local c = string.byte(str,i)
    h = c + shiftleft(h, 6) + shiftleft(h, 16) - h
    h = h % DUB_MAX_IN_SHIFT
  end
  return h % sz
end
return lib
