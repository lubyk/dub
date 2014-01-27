--[[------------------------------------------------------

  dub.Function
  ------------

  ...

--]]------------------------------------------------------
local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

local should = lut.Test 'dub.Function'

local ins = dub.Inspector {
  doc_dir = 'test/tmp',
  INPUT   = 'test/fixtures/simple/include',
}

local Simple = ins:find 'Simple'
local add    = Simple:method 'add'

function should.autoload()
  assertType('table', dub.Function)
end

function should.beAFunction()
  assertEqual('dub.Function', add.type)
end

function should.haveParams()
  local res = {}
  local i = 0
  for param in add:params() do
    i = i + 1
    table.insert(res, {i, param.name})
  end
  assertValueEqual({{1, 'v'}, {2, 'w'}}, res)
end

function should.haveMinArgSize()
  assertEqual('(MyFloat v, double w=10)', add.argsstring)
  assertTrue(add.has_defaults)
  assertEqual(1, add.min_arg_size)
end

function should.haveReturnValue()
  local ret = add.return_value
  assertEqual('MyFloat', ret.name)
end

function should.notHaveReturnValueForSetter()
  local func = Simple:method 'setValue'
  assertNil(func.return_value)
end

function should.haveLocation()
  assertMatch('test/fixtures/simple/include/simple.h:[0-9]+', add.location)
end

function should.haveDefinition()
  assertMatch('MyFloat Simple::add', add.definition)
end

function should.haveArgsString()
  assertMatch('%(MyFloat v, double w=10%)', add.argsstring)
end

function should.markConstructorAsStatic()
  local func = Simple:method 'Simple'
  assertTrue(func.static)
end

function should.haveSignature()
  assertEqual('MyFloat, double', add.sign)
end

function should.respondToNew()
  local f = dub.Function {
    name = 'hop',
    definition = 'hop',
    argsstring = '(int i)',
    db   = Simple.db,
    parent = Simple,
    params_list = {
      { type     = 'dub.Param',
        name     = 'i',
        position = 1,
        ctype    = {
          name = 'int',
        },
      }
    },
  }
  assertEqual('dub.Function', f.type)
  assertEqual('hop(int i)', f:nameWithArgs())
end

function should.respondToFullname()
  assertEqual('Simple::add', add:fullname())
end

function should.respondToNameWithArgs()
  assertEqual('MyFloat Simple::add(MyFloat v, double w=10)', add:nameWithArgs())
end

function should.respondToFullcname()
  assertEqual('Simple::add', add:fullcname())
end

function should.respondToNeverThrows()
  local value = Simple:method 'value'
  assertTrue(value:neverThrows())
  assertFalse(add:neverThrows())
end

function should.respondToSetName()
end

should:test()
