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

    def members(ignore_list = [])
      @members ||= begin
        list = []
        @members_hash.each do |name, member|
          next if ignore_list.include?(name)
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
            member_or_group.each do |m|
              list << make_member(name, m)
            end
            member_or_group = list.compact
            if member_or_group == []
              member_or_group = nil
            elsif member_or_group.size > 1
              # set overloaded_index
              member_or_group.each_with_index do |m, i|
                m.overloaded_index = i + 1
              end
            end
          end
        elsif member_or_group.kind_of?(Hpricot::Elem)
          source[name] = member_or_group = make_member(name, member_or_group)
        end
      end
      member_or_group
    end

    def make_member(name, member)
      member = case member[:kind]
      when 'function', 'slot'
        Dub.logger.info "Building #{members_prefix}::#{name}"
        Function.new(self, name, member, members_prefix)
      when 'class'
        Dub.logger.info "Building #{members_prefix}::#{name}"
        Klass.new(self, name, member, members_prefix)
      else
        # not supported: ignore
        return nil
      end

      ignore_member?(member) ? nil : member
    end

    def ignore_member?(member)
      return false if member.kind_of?(Klass)

      if !member.public? ||
         member.name =~ /^~/           || # do not build constructor
         member.name =~ /^operator/    || # no conversion operators
         member.has_complex_arguments? || # no complex arguments or return values
         member.has_array_arguments? ||
         member.vararg? ||
         member.original_signature =~ /void\s+\*/ # used to detect return value and parameters
        true # ignore
      elsif return_value = member.return_value
        if return_value.create_type == 'const char *'
          return false # do not ignore
        end
        return_value.type =~ />$/    || # no complex return types
        (return_value.is_native? && member.return_value.is_pointer?)
      else
        false # ok, do not ignore
      end
    end
  end
end # Dub