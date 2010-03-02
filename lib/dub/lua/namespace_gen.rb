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
    end
  end
end