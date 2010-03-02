require 'helper'

class ArgumentTest < Test::Unit::TestCase
  context 'An const ref argument' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('namespacecv.xml'))
      @argument = namespacecv_xml[:cv][:resize].arguments.first
    end

    should 'return type with type' do
      assert_equal 'Mat', @argument.type
    end

    should 'return name with name' do
      assert_equal 'src', @argument.name
    end

    should 'know if argument is const' do
      assert @argument.is_const?
    end

    should 'know if argument is passed by ref' do
      assert @argument.is_ref?
    end

    should 'know that it is a pointer' do
      assert !@argument.is_pointer?
    end

    should 'know if argument type is a native type' do
      assert !@argument.is_native?
    end

    should 'create a pointer' do
      assert_equal 'const Mat *', @argument.create_type
    end

    should 'keep a link to the function' do
      assert_kind_of Dub::Function, @argument.function
    end

    should 'not return true on has_default if it does not have a default value' do
      assert !@argument.has_default?
    end

    should 'return signature' do
      assert_equal 'const Mat&', @argument.signature
    end

    should 'return signature on inspect' do
      assert_equal 'const Mat&', @argument.inspect
    end
  end

  context 'A double argument' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('namespacecv.xml'))
      @argument = namespacecv_xml[:cv][:resize].arguments[3]
    end

    should 'return type with type' do
      assert_equal 'double', @argument.type
    end

    should 'return name with name' do
      assert_equal 'fx', @argument.name
    end

    should 'know if argument is const' do
      assert !@argument.is_const?
    end

    should 'know if argument is passed by ref' do
      assert !@argument.is_ref?
    end

    should 'know that it is a pointer' do
      assert !@argument.is_pointer?
    end

    should 'know if argument type is a native type' do
      assert @argument.is_native?
    end

    should 'return double on create_type' do
      assert_equal 'double ', @argument.create_type
    end

    should 'return signature' do
      assert_equal 'double', @argument.signature
    end
  end


  context 'A bool argument' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('namespacecv.xml'))
      @argument = namespacedub_xml[:dub][:Matrix][:do_something].arguments[1]
    end

    should 'return type with type' do
      assert_equal 'bool', @argument.type
    end

    should 'return name with name' do
      assert_equal 'fast', @argument.name
    end

    should 'know if argument is const' do
      assert !@argument.is_const?
    end

    should 'know if argument is passed by ref' do
      assert !@argument.is_ref?
    end

    should 'know that it is a pointer' do
      assert !@argument.is_pointer?
    end

    should 'know if argument type is a native type' do
      assert @argument.is_native?
    end

    should 'return bool on create_type' do
      assert_equal 'bool ', @argument.create_type
    end

    should 'return signature' do
      assert_equal 'bool', @argument.signature
    end

    should 'return default value if it has one' do
      assert_equal 'false', @argument.default
    end
  end


  context 'An argument with a default value' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('namespacecv.xml'))
      @argument = namespacecv_xml[:cv][:resize].arguments[5]
    end

    should 'return type with type' do
      assert_equal 'int', @argument.type
    end

    should 'return name with name' do
      assert_equal 'interpolation', @argument.name
    end

    should 'return default value' do
      assert_equal 'cv::INTER_LINEAR', @argument.default
    end

    should 'know if it has a default value' do
      assert @argument.has_default?
    end

    context 'that is an enum' do
      setup do
        @argument = namespacecv_xml[:cv][:Mat].constructor[6].arguments[4]
      end

      should 'use full namespace signature if default is an enum' do
        assert_equal 'cv::Mat::AUTO_STEP', @argument.default
      end
    end
  end

  context 'A group of overloaded functions' do
    setup do
      @group = namespacecv_xml[:cv][:divide]
    end

    should 'be ordered into a decision tree' do
      f1 = @group.detect {|f| f.arguments[0].type == 'Mat'}
      f2 = @group.detect {|f| f.arguments[0].type == 'MatND'}
      f3 = @group.detect {|f| f.arguments[0].type == 'double' && f.arguments[1].type == 'Mat'}
      f4 = @group.detect {|f| f.arguments[0].type == 'double' && f.arguments[1].type == 'MatND'}
      hash = {'cv.Mat'=>f1, 'cv.MatND'=>f2, :number=> {'cv.Mat' => f3, 'cv.MatND' => f4}}
      assert_equal hash, Dub::Argument.decision_tree(@group)
    end
  end

  context 'A group of overloaded member methods' do
    setup do
      @group = namespacecv_xml[:cv][:Mat][:zeros]
    end

    should 'be ordered into a decision tree' do
      f1 = @group.detect {|f| f.arguments[0].type == 'Size'}
      f2 = @group.detect {|f| f.arguments[0].type == 'int'}
      hash = {'cv.Size'=>f1, :number=> f2}
      assert_equal hash, Dub::Argument.decision_tree(@group)
    end
  end

  class MockArgument
    attr_reader :type, :full_type
    def initialize(type, full_type=nil, is_pointer=false)
      @type = type
      @full_type = full_type || type
      @is_pointer = is_pointer
    end
    def is_pointer?
      @is_pointer
    end
  end
  context 'An int argument' do
    should 'belong to the :number group' do
      assert_equal :number, Dub::Argument.type_group(MockArgument.new('int'))
    end
  end

  context 'A float argument' do
    should 'belong to the :number group' do
      assert_equal :number, Dub::Argument.type_group(MockArgument.new('float'))
    end
  end

  context 'A double argument' do
    setup do
      @argument = namespacecv_xml[:cv][:resize].arguments[3]
    end

    should 'belong to the :number group' do
      assert_equal :number, Dub::Argument.type_group(MockArgument.new('double'))
    end

    should 'create double type' do
      assert_equal 'double ', @argument.create_type
    end

    should 'pass by value in call' do
      assert_equal 'fx', @argument.in_call_type
    end
  end

  context 'A custom class by ref' do
    setup do
      @argument = namespacecv_xml[:cv][:resize].arguments[0]
    end

    should 'belong to its own group' do
      assert_equal 'cv.Mat', Dub::Argument.type_group(@argument)
    end

    should 'create a const pointer' do
      assert_equal 'const Mat *', @argument.create_type
    end

    should 'pass by ref in call' do
      assert_equal '*src', @argument.in_call_type
    end

    should 'know if argument is const' do
      assert @argument.is_const?
    end

    should 'know if argument is passed by ref' do
      assert @argument.is_ref?
    end

    should 'know that it is a pointer' do
      assert !@argument.is_pointer?
    end
  end

  context 'A pointer to a class' do
    setup do
      @argument = namespacecv_xml[:cv][:calcHist][0].arguments[0]
    end

    should 'belong to its own group' do
      assert_equal 'cv.Mat', Dub::Argument.type_group(@argument)
    end

    should 'return type with namespace on id_name' do
      assert_equal 'cv.Mat', @argument.id_name
    end

    should 'pass by value in call' do
      assert_equal 'images', @argument.in_call_type
    end

    should 'know if argument is const' do
      assert @argument.is_const?
    end

    should 'know if argument is passed by ref' do
      assert !@argument.is_ref?
    end

    should 'know that it is a pointer' do
      assert @argument.is_pointer?
    end

    should 'create a pointer' do
      assert_equal 'const Mat *', @argument.create_type
    end
  end

  context 'A pointer to a native type' do
    setup do
      @argument = namespacecv_xml[:cv][:calcHist][0].arguments[2]
    end

    should 'belong to the number_pointer group' do
      assert_equal :number_ptr, Dub::Argument.type_group(MockArgument.new('int', 'int', true))
    end

    should 'pass by value in call' do
      assert_equal 'channels', @argument.in_call_type
    end

    should 'know if argument is const' do
      assert @argument.is_const?
    end

    should 'know if argument is passed by ref' do
      assert !@argument.is_ref?
    end

    should 'know that it is a pointer' do
      assert @argument.is_pointer?
    end

    should 'return the type without star' do
      assert_equal 'int', @argument.type
    end

    should 'create a native type' do
      assert_equal 'const int *', @argument.create_type
    end
  end
end
