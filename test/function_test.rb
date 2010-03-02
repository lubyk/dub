require 'helper'

class FunctionTest < Test::Unit::TestCase

  context 'A Function' do
    setup do
      # namespacecv_xml = Dub.parse('fixtures/namespacecv.xml')
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
        assert_equal nil, @function.return_type
      end
    end

    context 'with a return value' do
      setup do
        @function = namespacecv_xml[:cv][:getRotationMatrix2D]
      end

      should 'know the type of a returned value' do
        assert_equal 'Mat', @function.return_type
      end
    end
  end

  context 'A method' do
    setup do
      # namespacecv_xml = Dub.parse(fixture('app/xml/namespacedoxy.xml'))
      @method = namespacedoxy_xml[:doxy][:Matrix][:size]
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
      # namespacecv_xml = Dub.parse(fixture('app/xml/namespacedoxy.xml'))
      @method = namespacedoxy_xml[:doxy][:Matrix][:Matrix].first
    end

    should 'know that it belongs to a class' do
      assert @method.member_method?
    end

    should 'know if it is a constructor' do
      assert @method.constructor?
    end

    should 'return class name on return_type_no_ptr' do
      assert_equal 'Matrix', @method.return_type_no_ptr
    end

    should 'return class name pointer on return_type' do
      assert_equal 'Matrix *', @method.return_type
    end
  end
end
