--[[------------------------------------------------------

  dub.Template
  ------------

  ...

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.Template')

--=============================================== TESTS
function should.autoload()
  assertType('table', dub.Template)
end

function should.transformToLua()
  local code = dub.Template [[
{% for h in self:headers() do %}
#include "{{h.path}}"
{% end %}
]]
  assertMatch('_out_.%[=%[.#include ".', code.lua)
end

function should.executeTemplate()
  local code = dub.Template [[
{% for _,l in ipairs(list) do %}
#include "{{l}}"
{% end %}
]]
  local res = code:run {list = {'foo/bar.h','baz.h','dingo.h'}}
  assertEqual([[
#include "foo/bar.h"
#include "baz.h"
#include "dingo.h"
]], res)
end

function should.properlyHandleEnlines()
  local code = dub.Template [[
Hello my name is {{foo}}
and I live here.
]]
  local res = code:run {foo = 'FOO'}
  assertEqual([[
Hello my name is FOO
and I live here.
]], res)
end
test.all()
