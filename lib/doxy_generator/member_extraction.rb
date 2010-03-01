require 'doxy_generator/function'
require 'doxy_generator/group'
require 'doxy_generator/klass'

module DoxyGenerator
  class Klass
  end

  # This module is used by Namespace and Klass to extract member functions
  module MemberExtraction
    def members_prefix
      @name
    end

    def parse_members
      @members_hash   = {}
      (@xml/'memberdef').each do |member|
        name = (member/"name").innerHTML
        if @members_hash[name].kind_of?(Array)
          @members_hash[name] << member
        elsif first_member = @members_hash[name]
          @members_hash[name] = [first_member, member]
        else
          @members_hash[name] = member
        end
      end
    end

    def member(name)
      get_member(name.to_s)
    end

    def members
      @members ||= begin
        list = []
        @members_hash.each do |name, member|
          list << get_member(name)
        end
        list.compact!
        list.sort
      end
    end

    # Lazy construction of members
    def get_member(name)
      if member_or_group = @members_hash[name]
        if member_or_group.kind_of?(Array)
          if member_or_group.first.kind_of?(Hpricot::Elem)
            list = DoxyGenerator::Group.new(self)
            member_or_group.each_with_index do |m,i|
              list << make_member(name, m, i + 1)
            end
            member_or_group = list.compact
            member_or_group = nil if member_or_group == []
          end
        elsif member_or_group.kind_of?(Hpricot::Elem)
          @members_hash[name] = member_or_group = make_member(name, member_or_group)
        end
      end
      member_or_group
    end

    def make_member(name, member, overloaded_index = nil)
      case member[:kind]
      when 'function'
        Function.new(self, name, member, members_prefix, overloaded_index)
      when 'class'
        Klass.new(self, name, member, members_prefix)
      else
        # not supported: ignore
        nil
      end
    end
  end
end # DoxyGenerator