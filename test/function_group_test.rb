require 'helper'
require 'dub/lua'

class FunctionGroupTest < Test::Unit::TestCase

  context 'A FunctionGroup' do
    should 'keep its members sorted by overloaded_index' do
      @group = namespacecv_xml[:cv][:divide]
      assert_equal [1, 2, 3, 4], @group.map {|f| f.overloaded_index}
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
  end
end
