
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

      def method_registration
        member_methods = @class.members.map do |method|
          "{%-20s, #{method.method_name}}" % method.name.inspect
        end

        member_methods << "{%-20s, #{@class.destructor_name}}" % "__gc".inspect

        member_methods.join(",\n")
      end

      def class_method_registration
        "{%-20s, #{@class.constructor.method_name(0)}}" % "new".inspect
      end
    end
  end
end
