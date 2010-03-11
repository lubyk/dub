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

    def members
      if self.generator
        @gen_members ||= self.generator.members_list(super, @ignores)
      else
        super
      end
    end
  end
end