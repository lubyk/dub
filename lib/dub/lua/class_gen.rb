
require 'dub/generator'
require 'erb'

module Dub
  module Lua
    class ClassGen < Dub::Generator
      def initialize
        @class_template = ::ERB.new(File.read(File.join(File.dirname(__FILE__), 'class.cpp.erb')))
      end

      def klass(klass)
        @class = klass
        @class_template.result(binding)
      end

      def function_generator
        Lua.function_generator
      end

      def method_registration(klass = @class)
        member_methods = klass.members.map do |method|
          "{%-20s, #{method.method_name(0)}}" % method.name.inspect
        end

        member_methods << "{%-20s, #{klass.tostring_name}}" % "__tostring".inspect
        member_methods << "{%-20s, #{klass.destructor_name}}" % "__gc".inspect

        member_methods.join(",\n")
      end

      def namespace_methods_registration
        ([@class.name] + @class.alias_names).map do |name|
          "{%-20s, #{@class.constructor.method_name(0)}}" % name.inspect
        end.join(",\n")
      end

      def class_enums_registration(klass = @class)
        klass.enums.map do |name|
          "{%-20s, #{klass.full_type}::#{name}}" % name.inspect
        end.join(",\n")
      end

      def members_list(all_members)
        list = all_members.map do |member_or_group|
          if member_or_group.kind_of?(Array)
            members_list(member_or_group)
          elsif ignore_member?(member_or_group)
            nil
          else
            member_or_group
          end
        end

        list.compact!
        list == [] ? nil : list
      end

      def ignore_member?(member)
        if member.name =~ /^~/           || # do not build constructor
           member.name =~ /^operator/    || # no conversion operators
           member.original_signature =~ />/ # no complex types in signature
          true # ignore
        elsif return_value = member.return_value
          return_value.type =~ />$/    || # no complex return types
          return_value.is_native? && member.return_value.is_pointer?
        else
          false # ok, do not ignore
        end
      end
    end
  end
end
