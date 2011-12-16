require 'helper'
require 'dub/lua'

class FunctionGroupTest < Test::Unit::TestCase

  context 'A FunctionGroup' do
    should 'keep its members sorted by overloaded_index' do
      @group = namespacecv_xml[:cv][:divide]
      assert_equal [1, 2, 3, 4], @group.map {|f| f.overloaded_index}
      
      assert_match %r{lua_type\(L, 1\)}, Dub::Lua.function_generator.chooser_body(@group)
    end

    should 'start getting type on first argument' do
      @group = namespacecv_xml[:cv][:divide]
      assert_match %r{lua_type\(L, 1\)}, Dub::Lua.function_generator.chooser_body(@group)
    end
    
    should 'not use top__ in chooser if all methods have same arg count' do
      @method = namespacecv_xml[:cv][:Mat][:diag]
      Dub::Lua.bind(@method)
      assert_no_match %r{top__}, Dub::Lua.function_generator.chooser_body(@method)
    end

    should 'use top__ in chooser if some methods have different arg count' do
      @method = namespacecv_xml[:cv][:Mat][:Mat]
      Dub::Lua.bind(@method)
      assert_match %r{top__}, Dub::Lua.function_generator.chooser_body(@method)
    end
    
    context 'from overloaded members' do
      subject do
        namespacedub_xml[:dub][:Matrix][:do_something]
      end

      should 'start getting type on second argument' do
        # Function selector should not be fooled by the first arg == self
        assert_no_match %r{lua_type\(L, 1\)}, Dub::Lua.function_generator.chooser_body(subject)
        assert_match %r{lua_type\(L, 2\)}, Dub::Lua.function_generator.chooser_body(subject)
      end
    end
  end
end