--[[------------------------------------------------------

  dub.Function
  ------------

  A public class method or function definition.

--]]------------------------------------------------------
local lib     = {
  type = 'dub.Function',
  OP_TO_NAME = {
    ['+']  = 'add',
    ['-']  = 'sub',
    ['*']  = 'mul',
    ['/']  = 'div',
    ['=='] = 'eq',
    ['<']  = 'lt',
    ['<='] = 'le',
  }
}
local private = {}
lib.__index   = lib
dub.Function  = lib

--=============================================== dub.Function()
setmetatable(lib, {
  __call = function(lib, self)
    self.dub = self.dub or {}
    self.static = self.static or self.ctor or self.dtor
    setmetatable(self, lib)
    self:setName(self.name)
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

function lib:fullname()
  return self.definition .. self.argsstring
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
    if n == '-' and #self.sorted_params == 0 then
      -- Special case for '-' (minus/unary minus).
      op = 'unm'
    end
    if op then
      self.cname = 'operator_' .. op
    else
      print(name)
    end
  else
    self.cname = self.name
  end
end
--=============================================== PRIVATE

function private.paramsIterator(parent)
  for _, param in ipairs(parent.sorted_params) do
    coroutine.yield(param)
  end
end

