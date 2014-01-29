local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

dub.warn_level = 4
dub_test = {}

PLAT = 'macosx'

for _, k in ipairs(arg) do
  if k == '--speed' then
    test_speed = true
  elseif k == 'linux' then
    -- FIXME: Hack until lub.plat works
    PLAT = 'linux'
  end
end

-- FIXME when lub.elapsed() is fixed
function elapsed()
  return 0
end

lut.Test.files(lub.path '|')


