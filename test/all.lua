local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

dub.warn_level = 4
dub_test = {}

-- if arg[1] == '--speed' then
--   dub_test.speed = true
-- elseif arg[1] == 'linux' then
--   lub.plat = 'linux'
-- end

if arg[1] == 'linux' then
  PLAT = 'linux'
else
  PLAT = 'macosx'
end

lut.Test.files(lub.path '|')


