--[[------------------------------------------------------

  dub.Template
  ------------

  Simplistic templating system inspired by Zed A. Shaw's
  minimal template for Tir (http://mongrel2.org/).

--]]------------------------------------------------------
local lib     = {}
local private = {}
lib.__index   = lib
dub.Template  = lib

--=============================================== dub.Template()
setmetatable(lib, {
  __call = function(lib, source)
    local self
    if type(source) == 'string' then
      self = {source = source}
    else
      self = source
      -- Grab source from path...
      local file = io.open(self.path, 'r')
      self.source = file:read('*a')
      file:close()
    end
    setmetatable(self, lib)
    self.lua = self:parse(self.source)
    self.func, self.err = loadstring(self.lua)
    if self.err then
      print(self.err)
      print(self.lua)
    end
    return self
  end
})

-- Create Lua code from the template string. 
function lib:parse(source)
  local eat_next_newline
  local res = "local buffer_ = ''\nlocal function _out_(str)\nbuffer_ = buffer_ .. str\nend\n"
  --for text, block in string.gmatch(tmpl, "([^{]-)(%b{})") do
  -- Find balanced {
  for text, block in string.gmatch(source .. '{{}}', '([^{]-)(%b{})') do
    if text ~= '' then
      if string.sub(text, 1, 1) == "\n" then
        if not eat_next_newline then
          -- Avoid multiline return removal
          text = "\n" .. text
        end
      end
      res = res .. string.format("_out_([=[%s]=])\n", text)
    end
    -- handle block
    eat_next_newline = false
    local block_type = string.sub(block, 1, 2)
    local content = string.sub(block, 3, -3)
    if block_type == '{{' then
      if content ~= '' then
        res = res .. string.format("_out_(%s)\n", content)
      end
    elseif block_type == '{%' then
      res = res .. content .. "\n"
      eat_next_newline = true
    else
      res = res .. block
    end
  end
  res = res .. 'return buffer_'
  return res
end

function lib:run(env)
  setmetatable(env, {__index = _G})
  setfenv(self.func, env)
  return self.func()
end
  
--=============================================== PRIVATE

