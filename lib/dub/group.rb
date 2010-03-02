require 'dub/namespace'

module Dub
  class Group < Namespace
    def parse_xml
      super
      parse_defines
    end
  end
end