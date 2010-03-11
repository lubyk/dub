require 'helper'
require 'dub/lua'

class FunctionTest < Test::Unit::TestCase

  context 'A Function' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('namespacecv.xml'))
      @function = namespacecv_xml[:cv][:resize]
    end

    should 'return a list of Arguments with arguments' do
      assert_kind_of Array, @function.arguments
      assert_kind_of Dub::Argument, @function.arguments.first
    end

    should 'return name with name' do
      assert_equal 'resize', @function.name
    end

    should 'have namespace prefix' do
      assert_equal 'cv', @function.prefix
    end

    should 'display original_signature' do
      assert_equal 'CV_EXPORTS void cv::resize(const Mat &src, Mat &dst, Size dsize, double fx=0, double fy=0, int interpolation=INTER_LINEAR)', @function.original_signature
    end

    should 'return file and line on source' do
      assert_equal 'include/opencv/cv.hpp:343', @function.source
    end

    should 'know if it has default arguments' do
      assert @function.has_default_arguments?
    end

    context 'without default arguments' do
      setup do
        @function = namespacecv_xml[:cv][:getRotationMatrix2D]
      end

      should 'know if it has default arguments' do
        assert !@function.has_default_arguments?
      end
    end

    context 'without a return value' do
      should 'know the type of a returned value' do
        assert_equal nil, @function.return_value
      end
    end

    context 'with a return value' do
      setup do
        @function = namespacecv_xml[:cv][:getRotationMatrix2D]
      end

      should 'return an Argument on return_value' do
        assert_kind_of Dub::Argument, @function.return_value
      end

      should 'know the type of a returned value' do
        assert_equal 'Mat', @function.return_value.type
      end

      should 'not use a pointer for create_type' do
        assert_equal 'Mat ', @function.return_value.create_type
      end
    end

    context 'with a pointer to native type return value' do
      setup do
        @function = namespacecv_xml[:cv][:Mat][:ptr].first
      end

      should 'know the type of the returned value' do
        assert_equal 'uchar *', @function.return_value.create_type
      end

      should 'know that the type is a native pointer' do
        assert @function.return_value.is_pointer?
      end
    end

    context 'with a reference return value' do
      setup do
        @function = namespacecv_xml[:cv][:Mat][:adjustROI]
      end

      should 'strip ref in the create type' do
        assert_equal 'Mat ', @function.return_value.create_type
      end

      should 'know that the type is a not native pointer' do
        assert !@function.return_value.is_pointer?
      end
    end

    context 'with a void pointer return value' do
      setup do
        @function = namespacecv_xml[:cv][:fastMalloc]
        #Dub::Lua.bind(@function)
      end

      should 'strip ref in the create type' do
        assert_equal 'void *', @function.return_value.create_type
      end

      should 'be ignored by generator' do
        assert Dub::Lua.namespace_generator.ignore_member?(@function)
      end
    end

    context 'with a class return value' do
      setup do
        @function = namespacecv_xml[:cv][:Mat][:row]
      end

      should 'return new objects in constructors' do
        Dub::Lua.bind(@function)
        assert_match %r{lua_pushclass<Mat>.*"cv.Mat"}, @function.to_s
      end
    end
  end

  context 'A vararg method' do
    setup do
      @function = namespacecv_xml[:cv][:format]
    end

    should 'know it is a vararg' do
      assert @function.vararg?
    end

    should 'be ignored by generator' do
      assert Dub::Lua.namespace_generator.ignore_member?(@function)
    end
  end

  context 'A constructor with void pointer argument' do
    setup do
      @function = namespacecv_xml[:cv][:Mat].constructor[6]
    end

    should 'be ignored by generator' do
      assert Dub::Lua.class_generator.ignore_member?(@function)
    end

    should 'not have array arguments' do
      assert !namespacecv_xml[:cv][:Mat].constructor[2].has_array_arguments?
    end

    should 'not be listed in group members if bound' do
      klass = namespacecv_xml[:cv][:Mat]
      Dub::Lua.bind(klass)
      assert !klass.constructor.members.include?(@function)
    end

    should 'be removed from group list on to_s' do
      klass = namespacecv_xml[:cv][:Mat]
      Dub::Lua.bind(klass)
      assert_no_match %r{void\s*\*_data,\s*size_t}, klass.constructor.to_s
    end
  end

  context 'A function with void pointer argument' do
    setup do
      @function = namespacecv_xml[:cv][:fastFree]
    end

    should 'be ignored by generator' do
      assert Dub::Lua.namespace_generator.ignore_member?(@function)
    end

    should 'be removed from members list' do
      Dub::Lua.bind(namespacecv_xml[:cv])
      assert !namespacecv_xml[:cv].members.include?(@function)
    end
  end

  context 'A function with list arguments' do
    setup do
      @namespace = namespacecv_xml[:cv]
      Dub::Lua.bind(@namespace)
      @group = @namespace[:calcHist]
      @function = @group[1]
    end

    # should 'mark argument as list on arg_is_list' do
    #   @function.arg_is_list(0, 1)
    #   assert @function.arguments[0].is_list?
    #   assert !@function.arguments[0].is_list_count?
    #   assert @function.arguments[1].is_list_count?
    # end

    should 'respond true to has_class_pointer_arguments' do
      assert @function.has_class_pointer_arguments?
    end

    should 'be removed from group list' do
      assert_nil @group.members
    end

    should 'remove group from member declaration' do
      assert_no_match %r{cv_calcHist}, @namespace.gen.functions_registration(@namespace)
    end

    should 'not be instanciated' do
      assert_equal '', @group.to_s
    end
  end

  context 'A method without arguments' do
    setup do
      @function = namespacecv_xml[:cv][:getCPUTickCount]
    end

    should 'parse return value' do
      assert_equal 'int64', @function.return_value.type
    end

    should 'produce a one liner to call function' do
      Dub::Lua.bind(@function)
      assert_match %r{int64\s*retval__\s*=\s*getCPUTickCount\(\);}, @function.to_s
    end
  end

  context 'A method' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('app/xml/namespacedub.xml'))
      @method = namespacedub_xml[:dub][:Matrix][:size]
    end

    should 'know that it belongs to a class' do
      assert @method.member_method?
    end

    should 'know if it is a constructor' do
      assert !@method.constructor?
    end

    should 'return klass on klass' do
      assert_kind_of Dub::Klass, @method.klass
    end
  end

  context 'A constructor' do
    setup do
      @method = namespacedub_xml[:dub][:Matrix][:Matrix].first
    end

    should 'know that it belongs to a class' do
      assert @method.member_method?
    end

    should 'know if it is a constructor' do
      assert @method.constructor?
    end

    should 'return class name on return_value create_type' do
      assert_equal 'Matrix', @method.return_value.type
    end

    should 'return class name pointer on return_value create_type' do
      assert_equal 'Matrix *', @method.return_value.create_type
    end

    context 'from a typedef bound to a generator' do
      setup do
        @method = namespacecv_xml[:cv][:Size].constructor.first
        Dub::Lua.bind(@method)
      end

      should 'know that it is a constructor' do
        assert @method.constructor?
      end

      should 'push new userdata on new' do
        assert_match %r{lua_pushclass<Size>.*"cv.Size".*return 1}m, @method.generator.return_value(@method)
      end
    end
  end

  context 'A static method in a class' do
    setup do
      @method = namespacedub_xml[:dub][:Matrix][:MakeMatrix]
    end

    should 'know it is static' do
      assert @method.static?
    end

    should 'append class in call_name' do
      assert_equal 'Matrix::MakeMatrix', @method.call_name
    end

    should 'parse return type' do
      assert_equal 'Matrix', @method.return_value.type
    end

    context 'bound to a generator' do
      setup do
        Dub::Lua.bind(@method)
      end

      should 'not try to find self' do
        assert_no_match %r{self__}, @method.to_s
      end

      should 'insert the function into the namespace' do
        @class = namespacedub_xml[:dub][:Matrix]
        Dub::Lua.bind(@class)
        result = @class.to_s
        member_methods_registration = result[/Matrix_member_methods([^;]*);/,1]
        namespace_methods_registration = result[/Matrix_namespace_methods([^;]*);/,1]
        assert_no_match %r{Matrix_MakeMatrix}, member_methods_registration
        assert_match %r{Matrix_MakeMatrix.*Matrix_MakeMatrix}, namespace_methods_registration
      end

      should 'use class name in call' do
        assert_match %r{Matrix::MakeMatrix\(}, @method.gen.call_string(@method)
      end
    end
  end

  # This is something like template<typename T2> foo() inside a templated class
  context 'A template method' do
    setup do
      @class = namespacecv_xml[:cv][:Scalar]
      @method = @class.template_method(:convertTo)
    end

    should 'know it is a template' do
      assert @method.template?
    end

    context 'bound to a generator' do
      setup do
        Dub::Lua.bind(@class)
      end

      should 'be ignored in class members' do
        assert !@class.members.include?(@method)
      end
    end
  end

  context 'A method in a class defined from a template' do
    setup do
      @class = namespacecv_xml[:cv][:Scalar]
      @method = @class[:all]
    end

    should 'resolve its arguments' do
      assert_equal 'double', @method.arguments[0].type
      assert_equal 'Scalar', @method.return_value.type
    end

    should 'not be seen as a template' do
      assert !@method.template?
    end

    should 'not be seen as having complex types' do
      assert !@method.has_complex_arguments?
    end

    context 'bound to a generator' do
      setup do
        Dub::Lua.bind(@class)
      end

      should 'not be ignored in class members' do
        assert @class.members.include?(@method)
      end
    end
  end


end
