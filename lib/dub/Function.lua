--[[------------------------------------------------------

  dub.Function
  ------------

  A public class method or function definition.

--]]------------------------------------------------------
local lib     = {type = 'dub.Function'}
local private = {}
lib.__index   = lib
dub.Function  = lib

--=============================================== dub.Object()
setmetatable(lib, {
  __call = function(lib, self)
    return setmetatable(self, lib)
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
  return 'TODO'
end

function lib:source()
  --def source
  --  loc = (@xml/'location').first.attributes
  --  "#{loc['file'].split('/')[-3..-1].join('/')}:#{loc['line']}"
  --end
  return 'TODO'
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

