require 'helper'
require 'dub/lua'

class GroupTest < Test::Unit::TestCase
  context 'A Namespace' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('namespacecv.xml'))
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

    should 'respond to lib_name' do
      # nested namespace could be cv_more
      assert_equal 'cv', @namespace.lib_name
    end

    should 'respond to id_name' do
      # nested namespace could be cv.more
      assert_equal 'cv', @namespace.id_name
    end

    should 'return header name on header' do
      assert_equal 'cv.hpp', @namespace.header
    end

    should 'return defined header if changed' do
      namespace = Dub.parse(fixture('namespacecv.xml'))[:cv]
      namespace.header = 'opencv/cv.h'
      assert_equal 'opencv/cv.h', namespace.header
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
      subject do
        namespacecv_xml[:cv][:divide]
      end

      should 'find a Dub::FunctionGroup' do
        assert_kind_of Dub::FunctionGroup, subject
      end

      should 'find a group of functions' do
        assert_kind_of Dub::Function, subject[0]
        assert_kind_of Dub::Function, subject[1]
      end

      should 'group functions by name' do
        assert_equal 'divide', subject[0].name
        assert_equal 'divide', subject[1].name
      end

      should 'assign an overloaded_index to grouped functions' do
        assert_equal 1, subject[0].overloaded_index
        assert_equal 2, subject[1].overloaded_index
      end

      should 'build chooser body' do
        Dub::Lua.bind(subject)
        assert_match %r{cv_divide1.*cv_divide2.*cv_divide3.*cv_divide\(}m, subject.to_s
      end
    end

    context 'with overloaded members' do
      subject do
        namespacedub_xml[:dub][:Matrix][:do_something]
      end

      should 'find a Dub::FunctionGroup' do
        assert_kind_of Dub::FunctionGroup, subject
      end

      should 'find a group of functions' do
        assert_kind_of Dub::Function, subject[0]
        assert_kind_of Dub::Function, subject[1]
      end

      should 'group functions by name' do
        assert_equal 'do_something', subject[0].name
        assert_equal 'do_something', subject[1].name
      end

      should 'assign an overloaded_index to grouped functions' do
        assert_equal 1, subject[0].overloaded_index
        assert_equal 2, subject[1].overloaded_index
      end

      should 'build chooser body' do
        Dub::Lua.bind(subject)
        assert_match %r{Matrix_do_something1.*Matrix_do_something2.*Matrix_do_something\(}m, subject.to_s
      end
    end

    context 'with overloaded constructors' do
      subject do
        namespacedub_xml[:dub][:Matrix][:Matrix]
      end

      should 'find a Dub::FunctionGroup' do
        assert_kind_of Dub::FunctionGroup, subject
      end

      should 'find a group of functions' do
        assert_kind_of Dub::Function, subject[0]
        assert_kind_of Dub::Function, subject[1]
      end

      should 'group functions by name' do
        assert_equal 'Matrix', subject[0].name
        assert_equal 'Matrix', subject[1].name
      end

      should 'assign an overloaded_index to grouped functions' do
        assert_equal 1, subject[0].overloaded_index
        assert_equal 2, subject[1].overloaded_index
      end

      should 'build chooser body' do
        Dub::Lua.bind(subject)
        assert_match %r{Matrix_Matrix1.*Matrix_Matrix2.*Matrix_Matrix\(}m, subject.to_s
      end
    end

    context 'with overloaded containing private members' do
      subject do
        namespacedub_xml[:dub][:PrivateConstr][:PrivateConstr]
      end

      should 'find a Dub::Function' do
        assert_kind_of Dub::Function, subject
      end

      should 'not set overloaded_index' do
        assert_nil subject.overloaded_index
        Dub::Lua.bind(subject)
        assert_no_match %r{PrivateConstr_PrivateConstr1}, subject.to_s
      end
    end
  end

  context 'A namespace with class definitions' do
    setup do
      @namespace = namespacedub_xml[:dub]
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

  context 'A namespace with template class definitions' do
    setup do
      @namespace = namespacedub_xml[:dub]
    end

    should 'ignore template classes in class list' do
      assert !@namespace.classes.map{|m| m.name}.include?("TMat")
    end

    should 'return template class with template_class' do
      assert_kind_of Dub::Klass, @namespace.template_class('TMat')
    end

    should 'build a full classes for template typedefs' do
      assert_kind_of Dub::Klass, @namespace.klass(:FloatMat)
    end

    context 'bound to a generator' do
      setup do
        Dub::Lua.bind(@namespace)
      end

      should 'generate a valid class' do
        # TODO: rerun all tests for lua class generation
        assert_match %r{luaL_register\(L,\s*"dub".*FMatrix}, @namespace[:FloatMat].to_s
      end
    end
  end

  context 'A namespace with enums' do
    setup do
      @namespace = namespacecv_xml[:cv]
    end

    should 'respond true to has_enums' do
      assert @namespace.has_constants?
    end

    should 'produce namespaced declarations' do
      assert_match %r{\{"INTER_LINEAR"\s*,\s*cv::INTER_LINEAR\}}, Dub::Lua.namespace_generator.constants_registration(@namespace)
    end

    context 'bound to a generator' do
      setup do
        Dub::Lua.bind(@namespace)
      end

      should 'produce enums registration' do
        result = @namespace.to_s
        assert_match %r{\{"INTER_LINEAR"\s*,\s*cv::INTER_LINEAR\}}, result
        assert_match %r{register_constants\(L,\s*"cv",\s*cv_namespace_constants\)}, result
      end
    end
  end
end
