require 'helper'
require 'dub/lua'

class LuaFunctionGenTest < Test::Unit::TestCase
  context 'A Lua generator' do
    setup do
      @generator = Dub::Lua
    end

    context 'with a function' do
      setup do
        # namespacecv_xml = Dub.parse('fixtures/namespacecv.xml')
        @function = namespacecv_xml[:cv][:resize]
      end

      should 'return Function on bind' do
        assert_kind_of Dub::Function, @generator.bind(@function)
      end
    end
  end

  context 'A Function' do
    setup do
      @function = namespacecv_xml[:cv][:resize]
    end

    context 'bound to a Lua generator' do
      setup do
        Dub::Lua.bind(@function)
        @generator = Dub::Lua.function_generator
      end


      should 'return string on to_s' do
        assert_kind_of String, @function.to_s
      end

      should 'generate a static function returning an int' do
        assert_match %r{static int cv_resize}, @function.to_s
      end

      should 'insert code to check for an arguments on get_arg' do
        assert_match /Mat.*\*\s*src\s*=\s*\(const\s+Mat\s+\*\)\s*luaL_checkudata\s*\(L,\s*1,\s*\"cv\.Mat\"\s*\)\s*;/,
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
  end

  context 'A group of overloaded functions' do
    setup do
      # namespacecv_xml = Dub.parse('fixtures/namespacecv.xml')
      @group = namespacecv_xml[:cv][:divide]
    end

    context 'bound to a Lua generator' do
      setup do
        Dub::Lua.bind(@group)
      end

      should 'return string content on to_s' do
        assert_kind_of String, @group.to_s
      end

      should 'generate a static function returning an int' do
        assert_match %r{static int cv_divide}, @group.to_s
      end

      should 'generate a static function returning an int for each overloaded function' do
        bindings = @group.to_s
        assert_match %r{static int cv_divide1}, bindings
        assert_match %r{static int cv_divide2}, bindings
        assert_match %r{static int cv_divide3}, bindings
        assert_match %r{static int cv_divide4}, bindings
      end
    end
  end

  context 'A function with a custom class return value' do
    setup do
      # namespacecv_xml = Dub.parse('fixtures/namespacecv.xml')
      @function = namespacecv_xml[:cv][:getRotationMatrix2D]
    end

    context 'bound to a Lua generator' do
      setup do
        Dub::Lua.bind(@function)
      end

      should 'call template push method' do
        assert_match %r{lua_pushclass<Mat>\(\s*L\s*,\s*retval__\s*,\s*"cv.Mat"\s*\)}, @function.to_s
      end
    end
  end

  context 'A function with pointer parameters' do
    setup do
      # namespacecv_xml = Dub.parse('fixtures/namespacecv.xml')
      @function = namespacecv_xml[:cv][:calcHist][0]
    end

    context 'bound to a Lua generator' do
      setup do
        Dub::Lua.bind(@function)
      end

      should 'use a DubArgPointer with the given type' do
        assert_match %r{DubArgPointer<int>}, @function.to_s
      end
    end
  end

  context 'A member function bound to a Lua generator' do
    setup do
      @member = namespacedoxy_xml[:doxy][:Matrix][:rows]
      Dub::Lua.bind(@member)
    end

    should 'start by getting self' do
      assert_match %r{self__\s*=\s*\*\(\(Matrix\*\*\)luaL_checkudata}, @member.to_s
    end

    should 'prefix call with self' do
      assert_match %r{self__->rows\(}, @member.to_s
    end
  end

  context 'A constructor bound to a Lua generator' do
    setup do
      @constructor = namespacedoxy_xml[:doxy][:Matrix][:Matrix].first
      Dub::Lua.bind(@constructor)
    end

    should 'use pushclass in constructor' do
      result = @constructor.to_s
      assert_match %r{lua_pushclass<Matrix>\s*\(L, retval__, \"doxy.Matrix\"\s*\)}, result
    end
  end
end




