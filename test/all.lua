local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

dub.warn_level = 4
dub_test = {}

if arg[1] == '--speed' then
  dub_test.speed = true
end

lut.Test.files(lub.path '|')


