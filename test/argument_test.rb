require 'helper'
require 'dub/lua'

class ArgumentTest < Test::Unit::TestCase
  context 'An Argument' do
    context 'parsing types' do
      {
        "CV_EXPORT const Foo"                  => ["CV_EXPORT ", "const ", "Foo", "", nil, ""],
        "CV_EXPORT const Foo<blah, blah>"      => ["CV_EXPORT ", "const ", "Foo", "", nil, ""],
        "CV_EXPORT Foo"                        => ["CV_EXPORT ", ""      , "Foo", "", nil, ""],
        "const Foo"                            => ["const "    , ""      , "Foo", "", nil, ""],
        "Foo"                                  => [""          , ""      , "Foo", "", nil, ""],
        "CV_EXPORT const Foo &"                => ["CV_EXPORT ", "const ", "Foo", "", nil, " &"],
        "CV_EXPORT const Foo&"                 => ["CV_EXPORT ", "const ", "Foo", "", nil, "&"],
        "CV_EXPORT Foo &"                      => ["CV_EXPORT ", ""      , "Foo", "", nil, " &"],
        "const Foo &"                          => ["const "    , ""      , "Foo", "", nil, " &"],
        "Foo &"                                => [""          , ""      , "Foo", "", nil, " &"],
        "CV_EXPORT const Foo *"                => ["CV_EXPORT ", "const ", "Foo", "", nil, " *"],
        "CV_EXPORT const Foo*"                 => ["CV_EXPORT ", "const ", "Foo", "", nil, "*"],
        "CV_EXPORT Foo *"                      => ["CV_EXPORT ", ""      , "Foo", "", nil, " *"],
        "const Foo *"                          => ["const "    , ""      , "Foo", "", nil, " *"],
        "Foo *"                                => [""          , ""      , "Foo", "", nil, " *"],
        "void *"                               => [""          , ""      , "void","", nil, " *"],
        "..."                                  => [""          , ""      , "...", "", nil, ""],

        "CV_EXPORT const Foo < blah, blah >"   => ["CV_EXPORT ", "const ", "Foo", " < blah, blah >", " blah, blah ", ""],
        "CV_EXPORT const Foo<blah, blah>"      => ["CV_EXPORT ", "const ", "Foo", "<blah, blah>"   , "blah, blah"  , ""],
        "CV_EXPORT Foo < blah, blah >"         => ["CV_EXPORT ", ""      , "Foo", " < blah, blah >", " blah, blah ", ""],
        "const Foo < blah, blah >"             => ["const "    , ""      , "Foo", " < blah, blah >", " blah, blah ", ""],
        "Foo < blah, blah >"                   => [""          , ""      , "Foo", " < blah, blah >", " blah, blah ", ""],
        "CV_EXPORT const Foo < blah, blah > &" => ["CV_EXPORT ", "const ", "Foo", " < blah, blah >", " blah, blah ", " &"],
        "CV_EXPORT const Foo<blah, blah> &"    => ["CV_EXPORT ", "const ", "Foo", "<blah, blah>"   , "blah, blah"  , " &"],
        "CV_EXPORT Foo < blah, blah > &"       => ["CV_EXPORT ", ""      , "Foo", " < blah, blah >", " blah, blah ", " &"],
        "const Foo < blah, blah > &"           => ["const "    , ""      , "Foo", " < blah, blah >", " blah, blah ", " &"],
        "Foo < blah, blah > &"                 => [""          , ""      , "Foo", " < blah, blah >", " blah, blah ", " &"],
        "CV_EXPORT const Foo < blah, blah > *" => ["CV_EXPORT ", "const ", "Foo", " < blah, blah >", " blah, blah ", " *"],
        "CV_EXPORT const Foo<blah, blah> *"    => ["CV_EXPORT ", "const ", "Foo", "<blah, blah>"   , "blah, blah"  , " *"],
        "CV_EXPORT Foo < blah, blah > *"       => ["CV_EXPORT ", ""      , "Foo", " < blah, blah >", " blah, blah ", " *"],
        "const Foo < blah, blah > *"           => ["const "    , ""      , "Foo", " < blah, blah >", " blah, blah ", " *"],
        "Foo < blah, blah > *"                 => [""          , ""      , "Foo", " < blah, blah >", " blah, blah ", " *"],
      }.each do |type, result|
        should "parse #{type}" do
          type =~ Dub::Argument::TYPE_REGEXP
          assert_equal result, $~.to_a[1..-1]
        end
      end
    end
  end

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

  context 'An argument without name' do
    setup do
      @argument = namespacecv_xml[:cv][:fastMalloc].arguments.first
    end

    should 'choose a name from its position' do
      assert_equal 'arg1', @argument.name
    end
  end

  context 'A vararg argument' do
    setup do
      @argument = namespacecv_xml[:cv][:format].arguments[1]
    end

    should 'know it is a vararg' do
      assert @argument.vararg?
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

  context 'An argument with the same name as the function' do
    setup do
      @function = namespacecv_xml[:cv][:magnitude]
      @argument = @function.arguments[2]
    end

    should 'be prefixed with arg_' do
      assert_equal 'arg_magnitude', @argument.name
    end
  end

  context 'An argument with a type from another namespace' do
    setup do
      @function = namespacedub_xml[:dub][:Matrix][:use_other_lib]
      @argument = @function.arguments.first
    end

    should 'not nest own namespace in id_name' do
      assert_equal "std.string", @argument.id_name
    end

    context 'bound to a generator' do
      setup do
        Dub::Lua.bind(@function)
      end

      should 'not nest own namespace in type' do
        assert_match %r{luaL_checkudata\(L,\s*1,\s*\"std\.string\"}, @function.to_s
      end
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

    context 'that is a class' do
      setup do
        @method = namespacecv_xml[:cv][:accumulate]
        @argument = @method.arguments[2]
      end

      should 'know that it has a default value' do
        assert @argument.has_default?
      end

      should 'return default value' do
        assert_equal 'Mat()', @argument.default
      end

      context 'bound to a generator' do
        setup do
          Dub::Lua.bind(@method)
        end

        should 'use if then else for default' do
          assert_match %r{if\s*\(top__ < 3\) \{\s*accumulate\(\*src, \*dst\);}m,
                       @method.to_s
        end
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

  context 'An array of C types' do
    setup do
      @argument = namespacedub_xml[:dub][:FMatrix][:FunkyThing].arguments.first
    end

    should 'return array count on array_count' do
      assert_equal '[7]', @argument.array_suffix
    end

    should 'be passed as is' do
      assert_equal 'v', @argument.name
    end

    should 'respond true to has_array_argumetns in method' do
      assert namespacedub_xml[:dub][:FMatrix][:FunkyThing].has_array_arguments?
    end

    context 'bound to a generator' do
      setup do
        @method = namespacedub_xml[:dub][:FMatrix][:FunkyThing]
        Dub::Lua.bind(@method)
      end

      should 'append array when creating receiver' do
        assert_match %r{double\s+v\[7\]}, @method.to_s
      end
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

  context 'In a class defined from a template' do
    setup do
      @class = namespacecv_xml[:cv][:Scalar]
    end

    context 'an argument in a constructor' do
      setup do
        @argument = @class[:Scalar][3].arguments.first
      end

      should 'replace template params' do
        assert_equal 'double', @argument.type
      end
    end

    context 'a return value' do
      setup do
        @argument = @class[:all].return_value
      end

      should 'replace template params and resolve' do
        assert_equal 'Scalar', @argument.type
      end
    end
  end
end
