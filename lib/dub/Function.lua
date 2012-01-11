--[[------------------------------------------------------

  dub.Function
  ------------

  A public class method or function definition.

--]]------------------------------------------------------
local lib     = {type = 'dub.Function'}
local private = {}
lib.__index   = lib
dub.Function  = lib

--=============================================== dub.Function()
setmetatable(lib, {
  __call = function(lib, self)
    setmetatable(self, lib)
    private.parseName(self)
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
  return false
end
--=============================================== PRIVATE

function private.paramsIterator(parent)
  for _, param in ipairs(parent.sorted_params) do
    coroutine.yield(param)
  end
end

function private:parseName()
  if string.match(self.name, '^~') then
    self.destructor = true
    self.name = string.gsub(self.name, '~', '_')
  end
end
