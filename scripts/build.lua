--
-- Update build files for this project
--
local lut = require 'lut'
local lib = require 'dub'

lut.Builder(lib):make()
