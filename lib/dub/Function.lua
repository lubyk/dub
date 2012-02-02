--[[------------------------------------------------------

  dub.Function
  ------------

  A public class method or function definition.

--]]------------------------------------------------------
local lib     = {
  type = 'dub.Function',
  -- C function names to use for the binding function.
  OP_TO_NAME = {
    ['+']  = 'add',
    ['-']  = 'sub',
    ['- '] = 'unm',
    ['*']  = 'mul',
    ['/']  = 'div',
    ['=='] = 'eq',
    ['<']  = 'lt',
    ['<='] = 'le',
    ['()'] = 'call',
    ['[]'] = 'index',
    -- add equal
    ['+='] = 'adde',
    -- sub equal
    ['-='] = 'sube',
    -- mul equal
    ['*='] = 'mule',
    -- div equal
    ['/='] = 'dive',
  }
}
local private = {}
lib.__index   = lib
dub.Function  = lib

--=============================================== dub.Function()
setmetatable(lib, {
  __call = function(lib, self)
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
})

--=============================================== PUBLIC METHODS

--- Return an iterator over the params of this function.
function lib:params()
  local co = coroutine.create(private.paramsIterator)
  return function()
    local ok, value = coroutine.resume(co, self)
    if ok then
      return value
    end
  end
end

function lib:nameWithArgs()
  return self.definition .. self.argsstring
end

-- Full name for function.
lib.fullname = dub.Class.fullname

-- Full C name for function.
function lib:fullcname()
  if self.parent and self.parent.name then
    return self.parent:fullname() .. '::' .. self.cname
  else
    return self.cname
  end
end

function lib:neverThrows()
  -- TODO: inspect xml
  return self.is_set_attr or
         self.is_get_attr or
         self.is_cast
end

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

