--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Test header_base path with lua patterns.

--]]------------------------------------------------------
local lub = require 'lub'
local lut = require 'lut'
local should = lut.Test('dub.LuaBinder - pat', {coverage = false})

local dirname = 'path.wi$th-[pat]'
local Pat

local dub = require 'dub'
local binder = dub.LuaBinder()
local base = lub.path('|')
local ins = dub.Inspector {
  INPUT   = base .. '/fixtures/'..dirname,
  -- We use a path with lua pattern characters to test.
  doc_dir = base .. '/tmp-[foo]',
}

--=============================================== TESTS

function should.bindClass()
  local Pat = ins:find('Pat')
  local res
  assertPass(function()
    res = binder:bindClass(Pat, {
      header_base = lub.path('|fixtures/'..dirname),
    })
  end)
  assertMatch('luaopen_Pat', res)
  assertMatch('#include "Pat.h"', res)
end

--=============================================== Build

function should.bindCompileAndLoad()
  -- create tmp directory
  local tmp_path = base .. '/tmp-[foo]'
  lub.rmTree(tmp_path, true)
  os.execute("mkdir -p "..tmp_path)
  binder:bind(ins, {
    output_directory = tmp_path,
    header_base = lub.path('|fixtures/'..dirname),
  })
  
  local cpath_bak = package.cpath
  local s
  assertPass(function()
    binder:build {
      output   = base .. '/tmp-[foo]/Pat.so',
      inputs   = {
        base .. '/tmp-[foo]/dub/dub.cpp',
        base .. '/tmp-[foo]/Pat.cpp',
      },
      includes = {
        base .. '/tmp-[foo]',
        -- This is for lua.h
        base .. '/tmp-[foo]/dub',
        base .. '/fixtures/'..dirname,
      },
    }

    package.cpath = base .. '/tmp-[foo]/?.so'
    Pat = require 'Pat'
    assertType('table', Pat)
  end, function()
    -- teardown
    package.cpath = cpath_bak
    if not Pat then
      lut.Test.abort = true
    end
  end)
  lub.rmTree(tmp_path, true)
end

--=============================================== Pat tests

function should.buildObjectByCall()
  local s = Pat(4)
  assertType('userdata', s)
  assertEqual(4, s:value())
  assertEqual(Pat, getmetatable(s))
end

should:test()

