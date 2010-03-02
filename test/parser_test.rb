require 'helper'

class ParserTest < Test::Unit::TestCase
  # cache parsing to speed things up
  @@namespace = Dub.parse(fixture('namespacecv.xml'))
  @@group = Dub.parse(fixture('group___magic_type.xml'))

  context 'Parsing a namespace' do
    setup do
      @parser = @@namespace
    end

    should 'find cv namespace with namespace method' do
      assert_kind_of Dub::Namespace, @parser.namespace(:cv)
    end

    should 'find namespace with array index' do
      assert_kind_of Dub::Namespace, @parser[:cv]
    end
  end

  context 'Parsing a group' do
    setup do
      @parser = @@group
    end

    should 'find MagicType group with group method' do
      assert_kind_of Dub::Namespace, @parser.group(:MagicType)
    end

    should 'find group with array index' do
      assert_kind_of Dub::Namespace, @parser[:MagicType]
    end
  end

end
