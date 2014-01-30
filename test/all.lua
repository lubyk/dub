local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

dub.warn_level = 4
dub_test = {}

PLAT = 'macosx'

for _, k in ipairs(arg) do
  if k == '--speed' then
    test_speed = true
  end
end

lut.Test.files(lub.path '|')

