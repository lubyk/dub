
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
        if klass.opts[:destructor] != ''
          member_methods << "{%-20s, #{klass.destructor_name}}" % "__gc".inspect
        end
        if klass.custom_destructor || klass.ancestors.detect{|a| a =~ /LuaObject/}
          member_methods << "{%-20s, #{klass.is_deleted_name}}" % "deleted".inspect
        end

        member_methods.join(",\n")
      end

      def namespace_methods_registration(klass = @class)
        if custom_ctor = klass.opts[:constructor]
          ctor = klass[custom_ctor.to_sym]
          raise "#{klass.name} custom constructor '#{custom_ctor}' not found !" unless ctor
          raise "#{klass.name} custom constructor '#{custom_ctor}' not a static function !" unless ctor.static?

          global_methods = klass.names.map do |name|
            "{%-20s, #{ctor.method_name(0)}}" % name.inspect
          end
        else
          global_methods = klass.names.map do |name|
            "{%-20s, #{(klass[klass.opts[:constructor]] || klass.constructor).method_name(0)}}" % name.inspect
          end
        end

        (klass.members || []).map do |method|
          next unless method.static?
          next if method.name == custom_ctor
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
        all_members
        #list = all_members.map do |member_or_group|
        #  if member_or_group.kind_of?(Array)
        #    members_list(member_or_group)
        #  elsif ignore_member?(member_or_group)
        #    nil
        #  else
        #    member_or_group
        #  end
        #end
        #
        #list.compact!
        #list == [] ? nil : list
      end

      def load_erb
        @class_template = ::ERB.new(File.read(@template_path || File.join(File.dirname(__FILE__), 'class.cpp.erb')))
      end
    end
  end
end
