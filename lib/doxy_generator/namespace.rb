require 'doxy_generator/function'

module DoxyGenerator
  class Namespace
    attr_reader :name

    def initialize(name, xml)
      @name, @xml = name, xml
      parse_xml
    end

    def [](name)
      get_member(name.to_s)
    end

    def member(name)
      get_member(name.to_s)
    end

    def function(name)
      member = get_member(name.to_s)
      member.kind_of?(Function) ? member : nil
    end

    private
      def parse_xml
        @members   = {}
        (@xml/'memberdef').each do |member|
          name = (member/"name").innerHTML
          if @members[name].kind_of?(Array)
            @members[name] << member
          elsif first_member = @members[name]
            @members[name] = [first_member, member]
          else
            @members[name] = member
          end
        end
      end

      # Lazy construction of members
      def get_member(name)
        if member_or_group = @members[name]
          if member_or_group.kind_of?(Array)
            if member_or_group.first.kind_of?(Hpricot::Elem)
              list = []
              member_or_group.each_with_index do |m,i|
                list << make_member(name, m, i + 1)
              end
              member_or_group = list
            end
          elsif member_or_group.kind_of?(Hpricot::Elem)
            @members[name] = member_or_group = make_member(name, member_or_group)
          end
        end
        member_or_group
      end

      def make_member(name, member, overloaded_index = nil)
        case member[:kind]
        when 'function'
          Function.new(name, member, @name, overloaded_index)
        else
          # not supported: ignore
          nil
        end
      end
  end
end # Namespace
