require 'dub/generator'
require 'erb'

module Dub
  module Lua
    class NamespaceGen < Dub::Generator
      def initialize
        @namespace_template = ::ERB.new(File.read(File.join(File.dirname(__FILE__), 'namespace.cpp.erb')))
      end

      def namespace(namespace)
        @namespace = namespace
        @namespace_template.result(binding)
      end

      def class_generator
        Lua.class_generator
      end

      def enums_registration(namespace = @namespace)
        namespace.enums.map do |name|
          "{%-32s, #{namespace.full_type}::#{name}}" % name.inspect
        end.join(",\n")
      end
    end
  end
end