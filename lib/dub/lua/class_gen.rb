
require 'dub/generator'
require 'erb'

module Dub
  module Lua
    class ClassGen < Dub::Generator
      attr_accessor :template_path

      def initialize
        load_erb
      end

      def template_path=(template_path)
        @template_path = template_path
        load_erb
      end

      def klass(klass)
        @class = klass
        @class_template.result(binding)
      end

      def function_generator
        Lua.function_generator
      end

      def method_registration(klass = @class)
        member_methods = (klass.members || []).map do |method|
          next if method.static?
          "{%-20s, #{method.method_name(0)}}" % method.name.inspect
        end.compact

        member_methods << "{%-20s, #{klass.tostring_name}}" % "__tostring".inspect
        member_methods << "{%-20s, #{klass.destructor_name}}" % "__gc".inspect

        member_methods.join(",\n")
      end

      def namespace_methods_registration(klass = @class)
        global_methods = klass.names.map do |name|
          "{%-20s, #{klass.constructor.method_name(0)}}" % name.inspect
        end

        (klass.members || []).map do |method|
          next unless method.static?
          global_methods << "{%-20s, #{method.method_name(0)}}" % "#{klass.name}_#{method.name}".inspect
        end

        global_methods.join(",\n")
      end

      def constants_registration(klass = @class)
        klass.enums.map do |name|
          "{%-20s, #{klass.full_type}::#{name}}" % name.inspect
        end.join(",\n")
      end

      def members_list(all_members)
        list = all_members.map do |member_or_group|
          if member_or_group.kind_of?(Array)
            members_list(member_or_group)
          elsif  ignore_member?(member_or_group)
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
           member.has_complex_arguments? || # no complex arguments or return values
           member.has_array_arguments? ||
           member.vararg? ||
           member.original_signature =~ /void\s+\*/ # used to detect return value and parameters
          true # ignore
        elsif return_value = member.return_value
          return_value.type =~ />$/    || # no complex return types
          return_value.is_native? && member.return_value.is_pointer?
        else
          false # ok, do not ignore
        end
      end

      def load_erb
        @class_template = ::ERB.new(File.read(@template_path || File.join(File.dirname(__FILE__), 'class.cpp.erb')))
      end
    end
  end
end
