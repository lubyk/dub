require 'helper'

class GroupTest < Test::Unit::TestCase

  context 'A Group' do
    setup do
      # namespacecv_xml = Dub.parse('fixtures/namespacecv.xml')
      @group = namespacecv_xml[:cv][:divide]
    end

    should 'keep its members sorted by overloaded_index' do
      assert_equal [1, 2, 3, 4], @group.map {|f| f.overloaded_index}
    end
  end
end
