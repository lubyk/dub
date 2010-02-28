require 'helper'

class ParserTest < Test::Unit::TestCase
  # cache parsing to speed things up
  @@xml = DoxyGenerator.parse(fixture('namespacecv.xml'))

  context 'Parsing a namespace' do
    setup do
      @parser = @@xml
    end

    should 'find cv namespace with namespace method' do
      assert_kind_of DoxyGenerator::Namespace, @parser.namespace(:cv)
    end

    should 'find namespace with array index' do
      assert_kind_of DoxyGenerator::Namespace, @parser[:cv]
    end
  end
end
