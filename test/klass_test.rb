require 'helper'
require 'dub/lua'

class KlassTest < Test::Unit::TestCase

  context 'A Klass' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('app/xml/namespacedoxy.xml'))
      @class = namespacedoxy_xml[:doxy][:Matrix]
    end

    should 'return a list of Functions with members' do
      assert_kind_of Array, @class.members
      assert_kind_of Dub::Function, @class.members.first
    end

    should 'return name with name' do
      assert_equal 'Matrix', @class.name
    end

    should 'have namespace prefix' do
      assert_equal 'doxy', @class.prefix
    end

    should 'combine prefix and name in lib_name' do
      assert_equal 'doxy_Matrix', @class.lib_name
    end

    should 'combine prefix and name in id_name' do
      assert_equal 'doxy.Matrix', @class.id_name
    end

    should 'return file and line on source' do
      assert_equal 'app/include/matrix.h:38', @class.source
    end

    should 'return a list of class methods' do
      assert_kind_of Array, @class.class_methods
    end

    should 'remove destructor from member list' do
      assert !@class.members.map{|m| m.name}.include?("~Matrix")
    end

    should 'remove constructor from member list' do
      assert !@class.members.map{|m| m.name}.include?("Matrix")
    end

    should 'return constructor with constructor' do
      const = @class.constructor
      assert_kind_of Dub::Function, const.first
    end

    should 'respond to destructor_name' do
      assert_equal 'Matrix_destructor', @class.destructor_name
    end

    should 'respond to constructor.method_name' do
      assert_equal 'Matrix_Matrix', @class.constructor.method_name(0)
    end

    should 'find method with array index' do
      assert_kind_of Dub::Function, @class[:rows]
    end

    should 'return header name on header' do
      assert_equal 'matrix.h', @class.header
    end

    context 'bound to a generator' do
      setup do
        Dub::Lua.bind(@class)
      end

      should 'bind each member' do
        assert_equal Dub::Lua.function_generator, @class.members.first.gen
      end

      should 'register constructor' do
        assert_match %r{\{\s*\"new\"\s*,\s*Matrix_Matrix\s*\}}, @class.to_s
      end

      should 'build constructor' do
        result = @class.to_s
        assert_match %r{static int Matrix_Matrix1\s*\(}, result
        assert_match %r{static int Matrix_Matrix2\s*\(}, result
        assert_match %r{static int Matrix_Matrix\s*\(},  result
      end

      should 'include class header' do
        assert_match %r{#include\s+"matrix.h"}, @class.to_s
      end

      should 'include helper header' do
        assert_match %r{#include\s+"lua_doxy_helper.h"}, @class.to_s
      end

      should 'create Lua metatable with class name' do
        assert_match %r{luaL_newmetatable\(L,\s*"doxy.Matrix"\)}, @class.to_s
      end
    end
  end
end
