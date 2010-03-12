require 'helper'
require 'dub/lua'

class KlassTest < Test::Unit::TestCase

  context 'A Klass' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('app/xml/namespacedub.xml'))
      @class = namespacedub_xml[:dub][:Matrix]
    end

    should 'return a list of Functions with members' do
      assert_kind_of Array, @class.members
      assert_kind_of Dub::Function, @class.members.first
    end

    should 'return name with name' do
      assert_equal 'Matrix', @class.name
    end

    should 'have namespace prefix' do
      assert_equal 'dub', @class.prefix
    end

    should 'combine prefix and name in lib_name' do
      assert_equal 'dub_Matrix', @class.lib_name
    end

    should 'combine prefix and name in id_name' do
      assert_equal 'dub.Matrix', @class.id_name
    end

    should 'combine prefix and provided name in id_name' do
      assert_equal 'dub.Foobar', @class.id_name('Foobar')
    end

    should 'use parent namespace in full_type' do
      assert_equal 'dub::Matrix', @class.full_type
    end

    should 'return file and line on source' do
      assert_match %r{app/include/matrix\.h:\d+}, @class.source
    end

    should 'return a list of class methods' do
      assert_kind_of Array, @class.class_methods
    end

    context 'with a bound member list' do
      setup do
        Dub::Lua.bind(@class)
        @list = @class.members.map {|m| m.name}
      end

      should 'remove destructor from member list' do
        assert !@list.include?("~Matrix")
      end

      should 'remove constructor from member list' do
        assert !@list.include?("Matrix")
      end

      should 'ignore template methods in member list' do
        assert !@list.include?("give_me_tea")
      end

      should 'ignore members with templated arguments' do
        # at least for now
        assert @class[:mul].has_complex_arguments?
        assert !@list.include?("mul")
        assert_no_match %r{Matrix_mul}, @class.to_s
      end

      should 'ignore operator methods in member list' do
        assert !@list.include?("operator size_t")
      end

      should 'ignore members returning native pointers' do
        assert !@list.include?("ptr")
      end
    end

    should 'return constructor with constructor' do
      const = @class.constructor
      assert_kind_of Dub::Function, const.first
    end

    should 'respond to destructor_name' do
      assert_equal 'Matrix_destructor', @class.destructor_name
    end

    should 'respond to tostring_name' do
      assert_equal 'Matrix__tostring', @class.tostring_name
    end

    should 'respond to constructor.method_name' do
      assert_equal 'Matrix_Matrix', @class.constructor.method_name(0)
    end

    should 'find method with array index' do
      assert_kind_of Dub::Function, @class[:rows]
    end

    should 'find static methods with array index' do
      assert_kind_of Dub::Function, @class[:MakeMatrix]
    end

    should 'return header name on header' do
      assert_equal 'matrix.h', @class.header
    end

    should 'return defined header if changed' do
      klass = Dub.parse(fixture('app/xml/namespacedub.xml'))[:dub][:Matrix]
      klass.header = 'opencv/cv.h'
      assert_equal 'opencv/cv.h', klass.header
    end

    should 'know that it is not a template' do
      assert !@class.template?
    end

    context 'bound to a generator' do
      setup do
        Dub::Lua.bind(@class)
      end

      should 'bind each member' do
        assert_equal Dub::Lua.function_generator, @class.members.first.gen
      end

      should 'register constructor' do
        assert_match %r{\{\s*\"Matrix\"\s*,\s*Matrix_Matrix\s*\}}, @class.to_s
      end

      should 'build constructor' do
        result = @class.to_s
        assert_match %r{static int Matrix_Matrix1\s*\(}, result
        assert_match %r{static int Matrix_Matrix2\s*\(}, result
        assert_match %r{static int Matrix_Matrix\s*\(},  result
      end

      should 'return new objects in constructors' do
        @class = namespacecv_xml[:cv][:Mat]
        Dub::Lua.bind(@class)
        assert_match %r{lua_pushclass<Mat>.*"cv.Mat"}, @class.constructor.first.to_s
      end

      should 'include class header' do
        assert_match %r{#include\s+"matrix.h"}, @class.to_s
      end

      should 'include helper header' do
        assert_match %r{#include\s+"lua_cpp_helper.h"}, @class.to_s
      end

      should 'create Lua metatable with class name' do
        assert_match %r{luaL_newmetatable\(L,\s*"dub.Matrix"\)}, @class.to_s
      end

      should 'not build template methods' do
        assert_no_match %r{give_me_tea}, @class.to_s
      end

      should 'declare tostring' do
        assert_match %r{__tostring}, @class.to_s
      end

      should 'use custom format if provided for tostring' do
        @class.string_format = "%dx%d"
        @class.string_args   = "(*userdata)->rows, (*userdata)->cols"
        assert_match %r{\(\*userdata\)->rows, \(\*userdata\)->cols}, @class.to_s
      end

      should 'use a default method for tostring if no custom string_format is provided' do
        @class.string_format = nil
        assert_match %r{<dub.Matrix: %p>}, @class.to_s
      end

      should 'implement tostring' do
        assert_match %r{Matrix__tostring\(lua_State}, @class.to_s
      end

      context 'using a custom template' do
        setup do
          @class.gen.template_path = fixture('dummy_class.cpp.erb')
        end

        teardown do
          @class.gen.template_path = nil
        end

        should 'use custom template to render function' do
          assert_equal 'CLASS: Matrix', @class.to_s
        end
      end
    end
  end

  context 'A template class' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('app/xml/namespacedub.xml'))
      @class = namespacedub_xml[:dub].template_class(:TMat)
    end

    should 'know that it is a template' do
      assert @class.template?
    end

    should 'return template parameters' do
      assert_equal ['T'], @class.template_params
    end
  end

  context 'A class defined from a template' do
    setup do
      @class = namespacecv_xml[:cv][:Size]
    end

    should 'replace template parameter in method arguments' do
      Dub::Lua.bind(@class)
      assert_match %r{int *_width}, @class.to_s
    end

    should 'register in the template for these types' do
      @tclass = namespacecv_xml[:cv].template_class(:Size_)
      assert_equal @class, @tclass.instanciations[['int']]
    end

    context 'with a bound member list' do
      setup do
        @class = namespacedub_xml[:dub][:FMatrix]
        Dub::Lua.bind(@class)
        @list = @class.members.map {|m| m.name}
      end

      should 'ignore template methods in member list' do
        assert !@list.include?("give_me_tea")
      end

      should 'ignore template methods in member registration' do
        assert_no_match %r{give_me_tea}, @class.gen.method_registration(@class)
      end

      should 'ignore template methods in method istanciation' do
        assert_no_match %r{give_me_tea}, @class.to_s
      end
    end
  end

  # strangely, the bug does not show up with "FMatrix"
  context 'Another class defined from a template' do
    setup do
      @class = namespacecv_xml[:cv][:Scalar]
    end

    context 'with a bound member list' do
      setup do
        Dub::Lua.bind(@class)
        @list = @class.members.map {|m| m.name}
      end

      should 'ignore template methods in member list' do
        assert !@list.include?("convertTo")
      end

      should 'ignore template methods in member registration' do
        assert_no_match %r{convertTo}, @class.gen.method_registration(@class)
      end

      should 'ignore template methods in method istanciation' do
        assert_no_match %r{convertTo}, @class.to_s
      end
    end
  end

  context 'A class with alias names' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('app/xml/namespacedub.xml'))
      @class = namespacedub_xml[:dub][:FloatMat]
    end

    should 'return a list of these alias on alias_names' do
      assert_equal ['FloatMat'], @class.alias_names
      assert_equal 'FMatrix', @class.name
    end

    should 'find class from alias in namespace' do
      assert_equal @class, namespacedub_xml[:dub][:FMatrix]
    end

    should 'use the shortest alias as main name' do
      assert_equal 'Size', namespacecv_xml[:cv][:Size2i].name
    end

    should 'rename constructors to shortest name' do
      assert_equal 'Size', namespacecv_xml[:cv][:Size].constructor.name
    end

    should 'parse arguments and evaluate types by resolving template params' do
      size_class = namespacecv_xml[:cv][:Size]
      Dub::Lua.bind(size_class)
      assert_match %r{const Point \*pt}, size_class.constructor[5].to_s
    end

    context 'bound to a generator' do
      setup do
        Dub::Lua.bind(@class)
      end

      should 'register all alias_names' do
        result = @class.to_s
        assert_match %r{"FloatMat"\s*,\s*FMatrix_FMatrix}, result
        assert_match %r{"FMatrix"\s*,\s*FMatrix_FMatrix}, result
        assert_match %r{luaL_register\(L,\s*"dub".*FMatrix_namespace_methods}, result
      end

      should 'use the smallest name in method definition' do
        assert_match %r{int FMatrix_FMatrix}, @class.to_s
      end
    end
  end

  context 'A class with overloaded methods' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('app/xml/namespacedub.xml'))
      @class = namespacecv_xml[:cv][:Mat]
      Dub::Lua.bind(@class)
    end

    should 'declare chooser' do
      result = @class.gen.method_registration(@class)
      assert_match %r{"diag"\s*,\s*Mat_diag\}}, result
      assert_no_match %r{diag1}, result
    end
  end

  context 'A class with overloaded static methods' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('app/xml/namespacedub.xml'))
      @class = namespacecv_xml[:cv][:Mat]
      Dub::Lua.bind(@class)
    end

    should 'declare chooser' do
      result = @class.gen.namespace_methods_registration(@class)
      assert_match %r{"Mat_zeros"\s*,\s*Mat_zeros\}}, result
      assert_no_match %r{zeros1}, result
    end
  end

  context 'A complex class' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('app/xml/namespacedub.xml'))
      @class = namespacecv_xml[:cv][:Mat]
    end

    context 'bound to a generator' do
      setup do
        Dub::Lua.bind(@class)
      end

      should 'list all members on members' do
        assert_equal %w{addref adjustROI assignTo channels clone col colRange convertTo copyTo create cross depth diag dot elemSize elemSize1 empty eye isContinuous locateROI ones release reshape row rowRange setTo size step1 type zeros}, @class.members.map {|m| m.name}
      end
    end
  end

  context 'A class with enums' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('app/xml/namespacedub.xml'))
      @class = namespacecv_xml[:cv][:Mat]
    end

    should 'respond true to has_enums' do
      assert @class.has_constants?
    end

    should 'produce namespaced declarations' do
      assert_match %r{\{"AUTO_STEP"\s*,\s*cv::Mat::AUTO_STEP\}}, Dub::Lua.class_generator.constants_registration(@class)
    end

    should 'find a list of enums' do
      assert_equal %w{MAGIC_VAL AUTO_STEP CONTINUOUS_FLAG}, @class.enums
    end
  end

end
