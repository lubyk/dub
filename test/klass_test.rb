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

    should 'accept any attribute' do
      assert_nothing_raised do
        @class.foo = 'bar'
      end
    end

    should 'store special attributes in opts' do
      @class.foo = 'bar'
      assert_equal 'bar', @class.opts[:foo]
    end

    should 'return value from opts on method missing' do
      @class.foo = 'bar'
      assert_equal 'bar', @class.foo
    end

    should 'use name as default in lib_name' do
      @class.opts.delete(:lib_name)
      assert_equal 'Matrix', @class.lib_name
    end

    should 'use lib_name if set in lib_name' do
      @class.opts[:lib_name] = "dooMat"
      assert_equal 'dooMat', @class.lib_name
    end

    should 'get @dub options from header' do
      assert_equal 'dummy value', @class.var_from_dub
      assert_equal 'some other value', @class.other_from_dub
    end

    should 'use ignore @dub option from header' do
      list = @class.members.map(&:name)
      assert !list.include?('bad_method')
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
        @list = @class.members.map(&:name)
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
        assert_nil @class[:mul]
        assert !@list.include?("mul")
        assert_no_match %r{Matrix_mul}, @class.to_s
      end

      should 'ignore private members' do
        assert !@list.include?("private_method")
      end

      should 'ignore property members' do
        assert !@list.include?("foo_prop")
      end

      should 'not count property with same name as overloaded functions' do
        assert_kind_of Dub::Function, @class[:size]
      end

      should 'ignore protected members' do
        assert !@list.include?("protected_method")
      end

      should 'ignore operator methods in member list' do
        assert !@list.include?("operator size_t")
      end

      should 'ignore members returning native pointers' do
        assert !@list.include?("ptr")
      end

      should 'accept members returning const char pointers' do
        assert @list.include?("name")
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

      should 'build destructor' do
        result = @class.to_s
        assert_match %r{static int Matrix_Matrix1\s*\(}, result
        assert_match %r{static int Matrix_Matrix2\s*\(}, result
        assert_match %r{static int Matrix_Matrix\s*\(},  result
          assert_match %r{if \(\*userdata\) delete \*userdata;}, result
      end

      context 'with a custom destructor' do
        subject do
          namespacedub_xml[:dub][:CustomDestructor]
        end

        should 'respond true to custom_destructor?' do
          assert subject.custom_destructor?
        end

        should 'use custom destructor' do
          Dub::Lua.bind(subject)
          assert_match %r{if \(\*userdata\) \(\*userdata\)->dub_destroy\(\);}, subject.to_s
        end

        should 'secure calls' do
          function = subject[:do_this]
          Dub::Lua.bind(function)
          assert_match %r{if \(!self__\) return luaL_error\(L, "Using deleted dub\.CustomDestructor in do_this"\);}, function.to_s
        end

        should 'specialize to_string' do
          Dub::Lua.bind(subject)
          assert_match %r{if \(!\*userdata\) \{.*lua_pushstring\(L, "<dub.CustomDestructor: NULL>"\);}m, subject.to_s
        end

        should 'add deleted method' do
          Dub::Lua.bind(subject)
          assert_match %r{CustomDestructor_deleted.*lua_pushboolean\(L, \*userdata == NULL\);}m, subject.to_s
        end

        should 'not insert destructor in members' do
          assert !subject.members.map(&:name).include?('destroy')
        end

        should 'ignore set_userdata_ptr' do
          assert !subject.members.map(&:name).include?('set_userdata_ptr')
        end

        should 'set pointer to userdata on create' do
          function = subject[:CustomDestructor]
          Dub::Lua.bind(function)
          assert_match %r{lua_pushclass2}, function.to_s
        end
      end # with a custom destructor

      context 'with a custom destructor set to nothing' do
        subject do
          @klass = namespacedub_xml[:dub][:NoDestructor]
          Dub::Lua.bind(@klass)
          @klass.to_s
        end

        should 'not create destructor' do
          subject
          assert_no_match %r{#{@klass.destructor_name}}, subject
        end

        should 'not declare __gc' do
          assert_no_match %r{__gc}m, subject
        end
      end # with a custom destructor

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
        @list = @class.members.map(&:name)
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
        @list = @class.members.map(&:name)
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
        assert_equal %w{addref adjustROI assignTo channels clone col colRange convertTo copyTo create cross depth diag dot elemSize elemSize1 empty eye isContinuous locateROI ones release reshape row rowRange setTo size step1 type zeros}, @class.members.map(&:name)
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
