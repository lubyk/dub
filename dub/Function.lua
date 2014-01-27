--[[------------------------------------------------------
  # C++ Function definition.

  (internal) A public C++ function or method definition.

--]]------------------------------------------------------
local lub = require 'lub'
local dub = require 'dub'
local lib = lub.class 'dub.Function'
local private = {}

-- Create a new function object with `def` settings. Some important fields in
-- `def`:
--
-- + name          : Function name.
-- + db            : Storage engine (dub.MemoryStorage).
-- + parent        : Parent or storage engine if the function is defined in root.
-- + header        : Path to C++ header file where this function is declared.
-- + params_list   : List of dub.Param definitions for the function arguments.
-- + return_value  : Return type definition (see dub.MemoryStorage.makeType).
-- + definition    : Full function name as defined (used in comment).
-- + argsstring    : Arguments as a single string (used in comment).
-- + location      : A String representing the function source file and line.
-- + desc          : String description (will be used in a C++ comment in
--                   bindings).
-- + static        : True if the function is static (static class function or
--                   C function).
-- + xml           : An xml object representing the function definition.
-- + member        : True if the function is a member function (static or not).
-- + dtor          : True if the function is the destructor.
-- + ctor          : True if the function is a constructor.
-- + dub           : "dub" options as parsed from the "dub" C++ comment.
-- + pure_virtual  : True if the function is a pure virtual.
function lib.new(def)
  local self = def
  self.dub = self.dub or {}
  self.member = self.parent.is_class and not (self.static or self.ctor)
  self.has_defaults = self.params_list.first_default and true
  self.header = self.header or self.parent.header
  if self.has_defaults then
    self.first_default = self.params_list.first_default
    -- minimal number of arguments
    self.min_arg_size = self.first_default - 1
  else
    self.min_arg_size = #self.params_list
  end
  setmetatable(self, lib)
  if not self:setName(self.name) then
    -- invalid name (usually an unknown operator)
    return nil
  end
  
  if self.db:ignored(self:fullname()) or
     self.dub.ignore == true or
     (self.parent.is_class and self.parent:ignoreFunc(self.name)) then
    return nil
  end

  self.sign = private.makeSignature(self)
  return self
end

-- # Operator overloading
-- Read this table as 'operator[KEY]' translates into lua function '__[VALUE]'.
-- For example `operator+` becomes `__add`. This works for most methods except
-- for some operators which do not have a lua equivalent (+=, -=, etc).

lib.OP_TO_NAME = { -- doc
  --   local v = foo + bar
  ['+']  = 'add',
  --   local v = foo - bar
  ['-']  = 'sub',
  --   local bar = -foo
  ['- '] = 'unm',
  --   local v = foo * bar
  ['*']  = 'mul',
  --   local v = foo / bar
  ['/']  = 'div',
  --   if (foo == bar) ...
  ['=='] = 'eq',
  --   if (foo < bar) ...
  ['<']  = 'lt',
  --   if (foo <= bar) ...
  ['<='] = 'le',
  -- This is the call on the object itself. Example:
  --
  --   local foo = Foo()
  --   foo() --> call
  ['()'] = 'call',
  -- Table access. When binding this method, integer access is very fast but we
  -- must also hand-code metatable access (to get methods) and attribute access.
  --
  -- It is thus better to avoid this operator for it has a non-negligible cost.
  --
  --   local x = foo[4]
  ['[]'] = 'index',
  -- This is not supported in lua due to the fact that all variables are
  -- references to objects and the equal sign is used to assign reference. We
  -- must therefore use 'set':
  --
  --   local foo, bar = Simple('I am foo'), Simple('I am bar')
  --   -- foo = bar would make 'foo' a pointer to bar, not assign
  --   -- values of bar into foo. We must use:
  --   foo:set(bar)
  --   --> C++ foo.operator=(bar)
  ['=']  = 'sete',
  -- Mutable operator. No equivalent in Lua.
  --
  --   -- Add 50 into foo, mutating foo.
  --   foo:adde(50)
  ['+='] = 'adde',
  -- Mutable operator. No equivalent in Lua.
  --
  --   -- Remove 50 from foo, mutating foo.
  --   foo:sube(50)
  ['-='] = 'sube',
  -- Mutable operator. No equivalent in Lua.
  --
  --   -- Scale foo by 50, mutating foo.
  --   foo:mule(50)
  ['*='] = 'mule',
  -- Mutable operator. No equivalent in Lua.
  --
  --   -- Divide foo by 50, mutating foo.
  --   foo:dive(50)
  ['/='] = 'dive',
}

-- # Accessors

-- Return the full name of the function (with enclosing namespaces separated
-- by '::'. Example: `foo::Bar::drawLine`.
-- function lib:fullname()

-- nodoc
lib.fullname = dub.Class.fullname

-- Full C name for function. This is like #fullname but with the C names in
-- case binding names are different.
function lib:fullcname()
  if self.parent and self.parent.name then
    return self.parent:fullname() .. '::' .. self.cname
  else
    return self.cname
  end
end


-- String representation of the function name with arguments (used in comments).
-- Example: `drawLine(int x, int y, int x2, int y2, const foo.Pen &pen)`
function lib:nameWithArgs()
  return self.definition .. self.argsstring
end

-- Returns true if the function does not throw any C++ exception.
function lib:neverThrows()
  return self.throw == 'throw ()' or
         self.is_set_attr or
         self.is_get_attr or
         self.is_cast
end

-- Set function name and C name.
function lib:setName(name)
  self.name = name
  if string.match(self.name, '^~') then
    self.destructor = true
    self.cname = string.gsub(self.name, '~', '_')
  elseif string.match(name, '^operator') then
    local n = string.match(name, '^operator(.+)$')
    local op = self.OP_TO_NAME[n]
    if op then
      self.cname = 'operator_' .. op
    else
      return false
    end
  else
    self.cname = self.name
  end
  return true
end

-- # Iterators

-- Return an iterator over the parameters of this function.
function lib:params()
  local co = coroutine.create(private.paramsIterator)
  return function()
    local ok, value = coroutine.resume(co, self)
    if ok then
      return value
    end
  end
end

--=============================================== PRIVATE

function private:paramsIterator()
  for _, param in ipairs(self.params_list) do
    coroutine.yield(param)
  end
end

-- Create a string identifying the met type for overloading. This is just
-- a concatenation of param type names.
function private.makeSignature(met)
  local res = ''
  for param in met:params() do
    if res ~= '' then
      res = res .. ', '
    end
    res = res .. param.ctype.name
  end
  return res
end

return lib
