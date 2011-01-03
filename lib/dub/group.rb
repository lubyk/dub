require 'dub/namespace'

module Dub
  class Group < Namespace
    def parse_xml
      super
      parse_defines
    end

    def arg_is_list(argument_pos, count_pos)
      each do |f|
        f.arg_is_list(argument_pos, count_pos)
      end
    end

    def constructor?
      f.first.constructor?
    end
  end
end