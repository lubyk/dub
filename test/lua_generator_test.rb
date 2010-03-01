require 'helper'

class LuaGeneratorTest < Test::Unit::TestCase
  context 'A lua generator' do
    setup do
      @generator = DoxyGenerator::LuaGenerator.new
    end

    context 'with a function' do
      setup do
        # namespacecv_xml = DoxyGenerator.parse('fixtures/namespacecv.xml')
        @function = namespacecv_xml[:cv][:resize]
      end

      should 'return string content on bind' do
        assert_kind_of String, s = @generator.bind(@function)
      end

      should 'generate a static function returning an int' do
        assert_match %r{static int cv_resize}, @generator.bind(@function)
      end

      should 'insert code to check for an arguments on get_arg' do
        assert_match /Mat.*\*\s*src\s*=\s*luaL_checkudata\s*\(L,\s*1,\s*\"cv\.Mat\"\s*\)\s*;/,
                     @generator.get_arg(@function.arguments.first, 1) # 1 = first argument in Lua stack
      end

      context 'with default values' do
        should 'verify stack size' do
          # int interpolation    = top__ < 6 ? INTER_LINEAR : luaL_checkint(L, 6);
          assert_match /top__\s*<\s*6\s*\?/, @generator.get_arg(@function.arguments[5], 6)
        end

        should 'use default if stack is too small' do
          assert_match /\?\s*INTER_LINEAR/, @generator.get_arg(@function.arguments[5], 6)
        end
      end
    end

    context 'with a group of overloaded functions' do
      setup do
        # namespacecv_xml = DoxyGenerator.parse('fixtures/namespacecv.xml')
        @group = namespacecv_xml[:cv][:divide]
      end

      should 'return string content on bind' do
        assert_kind_of String, s = @generator.bind(@group)
      end

      should 'generate a static function returning an int' do
        assert_match %r{static int cv_divide}, @generator.bind(@group)
      end

      should 'generate a static function returning an int for each overloaded function' do
        bindings = @generator.bind(@group)
        assert_match %r{static int cv_divide1}, bindings
        assert_match %r{static int cv_divide2}, bindings
        assert_match %r{static int cv_divide3}, bindings
        assert_match %r{static int cv_divide4}, bindings
      end
    end

    context 'with a function with a custom class return value' do
      setup do
        # namespacecv_xml = DoxyGenerator.parse('fixtures/namespacecv.xml')
        @function = namespacecv_xml[:cv][:getRotationMatrix2D]
      end

      should 'call template push method' do
      puts @generator.bind(@function)
        assert_match %r{lua_pushclass<Mat>\(\s*L\s*,\s*retval__\s*,\s*"cv.Mat"\s*\)}, @generator.bind(@function)
      end
    end

    context 'with pointer parameters' do
      setup do
        @function = namespacecv_xml[:cv][:calcHist][0]
      end

      should 'use a DoxyGeneratorArgPointer with the given type' do
        assert_match %r{DoxyGeneratorArgPointer<int>}, @generator.bind(@function)
      end

      should 'free pointer data' do
      end
    end
  end
end
