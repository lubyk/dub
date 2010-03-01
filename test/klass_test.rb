require 'helper'
require 'doxy_generator/lua'

class KlassTest < Test::Unit::TestCase

  context 'A Klass' do
    setup do
      # namespacecv_xml = DoxyGenerator.parse(fixture('app/xml/namespacedoxy.xml'))
      @class = namespacedoxy_xml[:doxy][:Matrix]
    end

    should 'return a list of Functions with members' do
      assert_kind_of Array, @class.members
      assert_kind_of DoxyGenerator::Function, @class.members.first
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

    should 'return file and line on source' do
      assert_equal 'app/include/matrix.h:33', @class.source
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
      assert_kind_of DoxyGenerator::Function, const.first
    end

    should 'respond to destructor_name' do
      assert_equal 'Matrix_destructor', @class.destructor_name
    end

    should 'respond to constructor.method_name' do
      assert_equal 'doxy_Matrix_constructor', @class.constructor.method_name(0)
    end

    should 'find method with array index' do
      assert_kind_of DoxyGenerator::Function, @class[:row]
    end

    context 'bound to a generator' do
      setup do
        DoxyGenerator::Lua.bind(@class)
      end

      should 'bind each member' do
        assert_equal DoxyGenerator::Lua.function_generator, @class.members.first.gen
      end

      should 'register constructor' do
        assert_match %r{\{\s*\"new\"\s*,\s*Matrix_Matrix\s*\}}, @class.to_s
      end

      should 'build constructor' do
        result = @class.to_s
        puts result
        assert_match %r{static int Matrix_Matrix1\s*\(}, result
        assert_match %r{static int Matrix_Matrix2\s*\(}, result
        assert_match %r{static int Matrix_Matrix\s*\(},  result
      end
    end
  end
end
