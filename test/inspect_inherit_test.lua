--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'inherit' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector - inherit')

local ins  = dub.Inspector {
  INPUT    = 'test/fixtures/inherit',
  doc_dir  = lk.dir() .. '/tmp',
}

--=============================================== TESTS

function should.listSuperClasses()
  local Child = ins:find 'Child'
  local res = {}
  for elem in Child:superclasses() do
    table.insert(res, elem.name)
  end
  assertValueEqual({
    'GrandParent',
    'Parent',
    'ChildHelper',
  }, res)
end

function should.listUnknownParents()
  local Orphan = ins:find 'Orphan'
  local res = {}
  for elem in Orphan:superclasses() do
    table.insert(res, elem.name)
  end
  assertValueEqual({
    'Foo< int >',
    'Bar',
  }, res)
end

function should.haveCastForUnknownParent()
  local Orphan = ins:find 'Orphan'
  local res = {}
  for elem in Orphan:methods() do
    table.insert(res, elem.name)
  end
  assertValueEqual({
    '~Orphan',
    '_cast_',
    'Orphan',
  }, res)
end

function should.listSuperMethods()
  local Child = ins:find 'Child'
  local res = {}
  for elem in Child:methods() do
    table.insert(res, elem.name)
  end
  assertValueEqual({
    '~Child',
    '_set_',
    '_get_',
    '_cast_',
    'Child',
    'x',
    'y',
    'name',
    'computeAge',
    'position',
  }, res)
end

function should.listSuperAttributes()
  local Child = ins:find 'Child'
  local res = {}
  for elem in Child:attributes() do
    table.insert(res, elem.name)
  end
  assertValueEqual({
    'teeth',
    'birth_year',
    'status',
    'happy',
  }, res)
end

function should.haveVariables()
  local GrandChild = ins:find 'GrandChild'
  assertTrue(GrandChild:hasVariables())
  local res = {}
  for elem in GrandChild:attributes() do
    table.insert(res, elem.name)
  end
  assertValueEqual({
    'birth_year',
    'status',
    'happy',
    'teeth',
  }, res)
end

function should.getDubInfoInHelper()
  local ChildHelper = ins:find 'ChildHelper'
  assertEqual(false, ChildHelper.dub.bind)
  assertEqual(false, ChildHelper.dub.cast)
end

function should.resolveEnumWithParent()
  local Child  = ins:find 'Child'
  local Parent = ins:find 'Parent'
  local b = ins.db:resolveType(Child, 'MaritalStatus')
  assertValueEqual({
    name        = 'int',
    def         = 'int',
    create_name = 'Parent::MaritalStatus ',
    cast        = 'Parent::MaritalStatus',
    -- This is used to output default enum values.
    scope       = 'Parent',
  }, b)
  local c = ins.db:resolveType(Parent, 'MaritalStatus')
  assertValueEqual(b, c)
end

test.all()



