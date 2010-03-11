require 'dub/function'
require 'dub/function_group'
require 'dub/klass'

module Dub
  class Klass
  end

  # This module is used by Namespace and Klass to extract member functions
  module MemberExtraction
    def members_prefix
      @name
    end

    def parse_members
      @members_hash   = {}
      @t_members_hash = {}
      # TODO: template functions
      (@xml/'memberdef').each do |member|
        Dub.logger.info "Parsing #{(member/'name').innerHTML}"
        name = (member/"name").innerHTML
        if (member/'templateparamlist').first
          insert_member(member, name, @t_members_hash)
        else
          insert_member(member, name, @members_hash)
        end
      end
    end

    def insert_member(member, name, destination)
      if destination[name].kind_of?(Array)
        destination[name] << member
      elsif first_member = destination[name]
        destination[name] = [first_member, member]
      else
        destination[name] = member
      end
    end

    def member(name)
      get_member(name.to_s, @members_hash)
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

    def template_method(name)
      get_member(name.to_s, @t_members_hash)
    end

    # Lazy construction of members
    def get_member(name, source = @members_hash)
      if member_or_group = source[name]
        if member_or_group.kind_of?(Array)
          if member_or_group.first.kind_of?(Hpricot::Elem)
            list = Dub::FunctionGroup.new(self)
            member_or_group.each_with_index do |m,i|
              list << make_member(name, m, i + 1)
            end
            member_or_group = list.compact
            member_or_group = nil if member_or_group == []
          end
        elsif member_or_group.kind_of?(Hpricot::Elem)
          source[name] = member_or_group = make_member(name, member_or_group)
        end
      end
      member_or_group
    end

    def make_member(name, member, overloaded_index = nil)
      case member[:kind]
      when 'function'
        Dub.logger.info "Building #{members_prefix}::#{name}"
        Function.new(self, name, member, members_prefix, overloaded_index)
      when 'class'
        Dub.logger.info "Building #{members_prefix}::#{name}"
        Klass.new(self, name, member, members_prefix)
      else
        # not supported: ignore
        nil
      end
    end
  end
end # Dub