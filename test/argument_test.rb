require 'helper'

class ArgumentTest < Test::Unit::TestCase
  context 'An const ref argument' do
    setup do
      # namespacecv_xml = DoxyGenerator.parse('fixtures/namespacecv.xml')
      @argument = namespacecv_xml[:cv][:resize].arguments.first
    end

    should 'return type with type' do
      assert_equal 'Mat', @argument.type
    end

    should 'return name with name' do
      assert_equal 'src', @argument.name
    end

    should 'return true if argument is const' do
      assert @argument.is_const?
    end

    should 'know if argument is passed by ref' do
      assert @argument.is_ref?
    end

    should 'know if argument type is a native type' do
      assert !@argument.is_native?
    end

    should 'return a pointer on create_type' do
      assert_equal 'Mat *', @argument.create_type
    end

    should 'keep a link to the function' do
      assert_kind_of DoxyGenerator::Function, @argument.function
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
      # namespacecv_xml = DoxyGenerator.parse('fixtures/namespacecv.xml')
      @argument = namespacecv_xml[:cv][:resize].arguments[3]
    end

    should 'return type with type' do
      assert_equal 'double', @argument.type
    end

    should 'return name with name' do
      assert_equal 'fx', @argument.name
    end

    should 'return true if argument is const' do
      assert !@argument.is_const?
    end

    should 'know if argument is passed by ref' do
      assert !@argument.is_ref?
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

  context 'An argument with a default value' do
    setup do
      # namespacecv_xml = DoxyGenerator.parse('fixtures/namespacecv.xml')
      @argument = namespacecv_xml[:cv][:resize].arguments[5]
    end

    should 'return type with type' do
      assert_equal 'int', @argument.type
    end

    should 'return name with name' do
      assert_equal 'interpolation', @argument.name
    end

    should 'return default value' do
      assert_equal 'INTER_LINEAR', @argument.default
    end

    should 'return true on has_default' do
      assert @argument.has_default?
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
      assert_equal hash, DoxyGenerator::Argument.decision_tree(@group)
    end
  end

  context 'An int type' do
    should 'belong to the :number group' do
      assert_equal :number, DoxyGenerator::Argument.type_group('int')
    end
  end

  context 'A float type' do
    should 'belong to the :number group' do
      assert_equal :number, DoxyGenerator::Argument.type_group('float')
    end
  end

  context 'A double type' do
    setup do
      @type = namespacecv_xml[:cv][:resize].arguments[3]
    end

    should 'belong to the :number group' do
      assert_equal :number, DoxyGenerator::Argument.type_group('double')
    end

    should 'pass by value in call' do
      assert_equal 'fx', @type.in_call_type
    end
  end

  context 'A custom class by ref' do
    setup do
      @type = namespacecv_xml[:cv][:resize].arguments[0]
    end

    should 'belong to its own group' do
      assert_equal 'Mat', DoxyGenerator::Argument.type_group('Mat')
    end

    should 'pass by ref in call' do
      assert_equal '*src', @type.in_call_type
    end
  end

  context 'A pointer to a class' do
    setup do
      @type = namespacecv_xml[:cv][:resize].arguments[0]
    end

    should 'belong to its own group' do
      assert_equal 'Mat', DoxyGenerator::Argument.type_group('Mat')
    end

    should 'pass by ref in call' do
      assert_equal '*src', @type.in_call_type
    end
  end
end
