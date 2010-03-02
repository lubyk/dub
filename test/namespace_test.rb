require 'helper'
require 'dub/lua'

class NamespaceTest < Test::Unit::TestCase
  context 'A Namespace' do
    setup do
      # namespacecv_xml = Dub.parse('fixtures/namespacecv.xml')
      @namespace = namespacecv_xml[:cv]
    end

    should 'find a function with functions method' do
      assert_kind_of Dub::Function, @namespace.function(:resize)
    end

    should 'find a function with array index' do
      assert_kind_of Dub::Function, @namespace[:resize]
    end

    should 'respond to name' do
      assert_equal 'cv', @namespace.name
    end


    context 'when bound' do
      setup do
        @generator = Dub::Lua.namespace_generator
      end

      should 'contain generator' do
        res = Dub::Lua.bind(@namespace)
        assert_equal res, @namespace
        assert_equal @generator, @namespace.gen
      end

    end

    context 'with overloaded functions' do
      setup do
        @function = namespacecv_xml[:cv][:divide]
      end

      should 'find a Dub::Group' do
        assert_kind_of Dub::Group, @function
      end

      should 'find a group of functions' do
        assert_kind_of Dub::Function, @function[0]
        assert_kind_of Dub::Function, @function[1]
      end

      should 'group functions by name' do
        assert_equal 'divide', @function[0].name
        assert_equal 'divide', @function[1].name
      end

      should 'assign an overloaded_index to grouped functions' do
        assert_equal 1, @function[0].overloaded_index
        assert_equal 2, @function[1].overloaded_index
      end
    end
  end

  context 'A namespace with class definitions' do
    setup do
      @namespace = Dub.parse(fixture('app/xml/namespacedoxy.xml'))[:doxy]
    end

    should 'find classes by array index' do
      assert_kind_of Dub::Klass, @namespace[:Matrix]
    end

    should 'find classes with klass' do
      assert_kind_of Dub::Klass, @namespace.klass('Matrix')
    end
    
    should 'return a list of classes with classes' do
      assert_kind_of Array, @namespace.classes
      assert_kind_of Dub::Klass, @namespace.classes.first
    end
  end
end
